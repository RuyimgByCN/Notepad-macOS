import AppKit
import UniformTypeIdentifiers

enum DocumentListAction {
    case activate
    case close
    case closeOthers
    case save
    case copyFilename
    case copyPath
    case togglePin
    // Multi-select actions (operate on all selected items)
    case closeSelected
    case saveSelected
}

struct DocumentListItem: Equatable {
    let title: String
    let detail: String
    let isActive: Bool
    let isDirty: Bool
    let isPinned: Bool
    let representedObject: AnyObject?

    init(
        title: String,
        detail: String,
        isActive: Bool,
        isDirty: Bool = false,
        isPinned: Bool = false,
        representedObject: AnyObject? = nil
    ) {
        self.title = title
        self.detail = detail
        self.isActive = isActive
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.representedObject = representedObject
    }

    static func detailText(forPath path: String?, unsavedFallback: String) -> String {
        guard let path, !path.isEmpty else {
            return unsavedFallback
        }
        return path
    }

    static func == (lhs: DocumentListItem, rhs: DocumentListItem) -> Bool {
        lhs.title == rhs.title
            && lhs.detail == rhs.detail
            && lhs.isActive == rhs.isActive
            && lhs.isDirty == rhs.isDirty
            && lhs.isPinned == rhs.isPinned
    }
}

@MainActor
final class DocumentListPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    static let titleColumnInitialWidth: CGFloat = 200
    private static let detailColumnInitialWidth: CGFloat = 260
    private static let panelInitialWidth: CGFloat = 500
    private static let titleCellIdentifier = NSUserInterfaceItemIdentifier("documentListTitleCell")
    private static let detailCellIdentifier = NSUserInterfaceItemIdentifier("documentListDetailCell")
    private static let documentIconSize = NSSize(width: 16, height: 16)

    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: DocumentListPanelController.panelInitialWidth, height: 420),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let titleField = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
    private let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
    private let activateButton = NSButton(title: "", target: nil, action: nil)
    private let closeSelectedButton = NSButton(title: "", target: nil, action: nil)
    private let saveSelectedButton = NSButton(title: "", target: nil, action: nil)
    private var items: [DocumentListItem] = []
    private var sortedItems: [DocumentListItem] = []
    private enum SortKey { case title, detail, dirty }
    private var sortKey: SortKey = .title
    private var sortAscending: Bool = true
    private var onSelect: ((DocumentListItem) -> Void)?
    private var onAction: ((DocumentListItem, DocumentListAction) -> Void)?
    private var onMultiAction: (([DocumentListItem], DocumentListAction) -> Void)?

    static func titleText(for item: DocumentListItem) -> String {
        let prefix = item.isDirty ? "● " : (item.isPinned ? "📌 " : "")
        return prefix + item.title
    }

    static func documentIconSymbolName(for item: DocumentListItem) -> String {
        item.isDirty ? "doc.badge.ellipsis" : "doc.text"
    }

    static func documentIcon(for item: DocumentListItem) -> NSImage {
        let symbolName = documentIconSymbolName(for: item)
        let description = item.isDirty ? "Modified document" : "Document"
        let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        let sourceImage = symbolImage ?? NSWorkspace.shared.icon(for: .plainText)
        let image = (sourceImage.copy() as? NSImage) ?? sourceImage
        image.size = documentIconSize
        image.isTemplate = symbolImage != nil || sourceImage.isTemplate
        return image
    }

    var window: NSWindow? {
        panel
    }

    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        configureContent()
        refreshLocalizedStrings()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localizationDidChange(_:)),
            name: Localization.localizationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show(
        items: [DocumentListItem],
        onSelect: @escaping (DocumentListItem) -> Void,
        onAction: ((DocumentListItem, DocumentListAction) -> Void)? = nil,
        onMultiAction: (([DocumentListItem], DocumentListAction) -> Void)? = nil
    ) {
        self.items = items
        self.onSelect = onSelect
        self.onAction = onAction
        self.onMultiAction = onMultiAction
        rebuildSortedItems()
        refreshLocalizedStrings()
        tableView.reloadData()
        if let activeIndex = sortedItems.firstIndex(where: \.isActive) {
            tableView.selectRowIndexes(IndexSet(integer: activeIndex), byExtendingSelection: false)
        } else if !sortedItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateMultiSelectButtons()
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(items: [DocumentListItem]) {
        guard items != self.items else { return }
        self.items = items
        rebuildSortedItems()
        tableView.reloadData()
        refreshLocalizedStrings()
        updateMultiSelectButtons()
    }

    private func rebuildSortedItems() {
        sortedItems = items.sorted {
            switch sortKey {
            case .title:
                let cmp = $0.title.localizedStandardCompare($1.title)
                return sortAscending ? cmp == .orderedAscending : cmp == .orderedDescending
            case .detail:
                let cmp = $0.detail.localizedStandardCompare($1.detail)
                return sortAscending ? cmp == .orderedAscending : cmp == .orderedDescending
            case .dirty:
                return sortAscending ? ($0.isDirty && !$1.isDirty) : (!$0.isDirty && $1.isDirty)
            }
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first else { return }
        sortAscending = descriptor.ascending
        switch descriptor.key {
        case "detail": sortKey = .detail
        default: sortKey = .title
        }
        rebuildSortedItems()
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sortedItems.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < sortedItems.count else { return nil }
        let item = sortedItems[row]
        switch tableColumn?.identifier.rawValue {
        case "detail":
            return item.detail
        default:
            return Self.titleText(for: item)
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < sortedItems.count else { return nil }
        let item = sortedItems[row]

        switch tableColumn?.identifier.rawValue {
        case "detail":
            let cell = tableView.makeView(withIdentifier: Self.detailCellIdentifier, owner: self) as? NSTableCellView
                ?? makeDetailCell()
            cell.textField?.stringValue = item.detail
            return cell
        default:
            let cell = tableView.makeView(withIdentifier: Self.titleCellIdentifier, owner: self) as? NSTableCellView
                ?? makeTitleCell()
            cell.textField?.stringValue = Self.titleText(for: item)
            cell.imageView?.image = Self.documentIcon(for: item)
            return cell
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        row >= 0 && row < items.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateMultiSelectButtons()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.setAccessibilityLabel(
            Localization.string(.documentListSummaryAccessibilityLabel, default: "Document list summary")
        )

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(activateSelectedDocument(_:))
        tableView.target = self
        tableView.menu = buildPlaceholderMenu()
        titleColumn.width = Self.titleColumnInitialWidth
        titleColumn.minWidth = 180
        titleColumn.sortDescriptorPrototype = NSSortDescriptor(key: "title", ascending: true)
        detailColumn.width = Self.detailColumnInitialWidth
        detailColumn.sortDescriptorPrototype = NSSortDescriptor(key: "detail", ascending: true)
        tableView.addTableColumn(titleColumn)
        tableView.addTableColumn(detailColumn)
        scrollView.documentView = tableView

        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .rounded
        activateButton.target = self
        activateButton.action = #selector(activateSelectedDocument(_:))

        closeSelectedButton.translatesAutoresizingMaskIntoConstraints = false
        closeSelectedButton.bezelStyle = .rounded
        closeSelectedButton.target = self
        closeSelectedButton.action = #selector(closeSelectedDocuments(_:))

        saveSelectedButton.translatesAutoresizingMaskIntoConstraints = false
        saveSelectedButton.bezelStyle = .rounded
        saveSelectedButton.target = self
        saveSelectedButton.action = #selector(saveSelectedDocuments(_:))

        root.addSubview(titleField)
        root.addSubview(scrollView)
        root.addSubview(saveSelectedButton)
        root.addSubview(closeSelectedButton)
        root.addSubview(activateButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            titleField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: activateButton.topAnchor, constant: -12),

            saveSelectedButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            saveSelectedButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            closeSelectedButton.leadingAnchor.constraint(equalTo: saveSelectedButton.trailingAnchor, constant: 8),
            closeSelectedButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            activateButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            activateButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    private func makeTitleCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.titleCellIdentifier

        let imageView = NSImageView()
        let textField = NSTextField(labelWithString: "")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle

        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: Self.documentIconSize.width),
            imageView.heightAnchor.constraint(equalToConstant: Self.documentIconSize.height),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func makeDetailCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.detailCellIdentifier

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle

        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.documentListPanelTitle, default: "Document List")
        titleField.setAccessibilityLabel(
            Localization.string(.documentListSummaryAccessibilityLabel, default: "Document list summary")
        )
        titleField.stringValue = String(
            format: Localization.string(.documentListSummary, default: "%d open document(s)"),
            items.count
        )
        tableView.setAccessibilityLabel(
            Localization.string(.documentListTableAccessibilityLabel, default: "Open documents")
        )
        titleColumn.title = Localization.string(.documentListColumnTitle, default: "Document")
        detailColumn.title = Localization.string(.documentListColumnPath, default: "Path")
        activateButton.title = Localization.string(.documentListActivate, default: "Activate")
        activateButton.setAccessibilityLabel(
            Localization.string(.documentListActivateAccessibilityLabel, default: "Activate selected document")
        )
        updateMultiSelectButtons()
    }

    private func updateMultiSelectButtons() {
        let count = tableView.selectedRowIndexes.count
        let isMulti = count > 1
        closeSelectedButton.isHidden = !isMulti
        saveSelectedButton.isHidden = !isMulti
        if isMulti {
            closeSelectedButton.title = String(
                format: Localization.string(.documentListCloseSelected, default: "Close (%d)"),
                count
            )
            saveSelectedButton.title = String(
                format: Localization.string(.documentListSaveSelected, default: "Save (%d)"),
                count
            )
        }
    }

    private func selectedItems() -> [DocumentListItem] {
        tableView.selectedRowIndexes.compactMap { row in
            guard row < sortedItems.count else { return nil }
            return sortedItems[row]
        }
    }

    @objc private func activateSelectedDocument(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < sortedItems.count else { return }
        onSelect?(sortedItems[row])
    }

    @objc private func closeSelectedDocuments(_ sender: Any?) {
        let selected = selectedItems()
        guard !selected.isEmpty else { return }
        if selected.count == 1 {
            onAction?(selected[0], .close)
        } else {
            onMultiAction?(selected, .closeSelected)
        }
    }

    @objc private func saveSelectedDocuments(_ sender: Any?) {
        let selected = selectedItems()
        guard !selected.isEmpty else { return }
        if selected.count == 1 {
            onAction?(selected[0], .save)
        } else {
            onMultiAction?(selected, .saveSelected)
        }
    }

    // MARK: - Context menu (NSMenuDelegate)

    private func buildPlaceholderMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0, clickedRow < sortedItems.count else { return }

        // If the clicked row is not in the current selection, select only it.
        if !tableView.selectedRowIndexes.contains(clickedRow) {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }

        let selectionCount = tableView.selectedRowIndexes.count

        if selectionCount > 1 {
            // Multi-select context menu
            let selected = selectedItems()
            menu.addItem(contextMenuItem(
                String(format: Localization.string(.documentListCloseSelected, default: "Close (%d)"), selectionCount),
                action: { [weak self] in self?.onMultiAction?(selected, .closeSelected) }
            ))
            menu.addItem(contextMenuItem(
                String(format: Localization.string(.documentListSaveSelected, default: "Save (%d)"), selectionCount),
                action: { [weak self] in self?.onMultiAction?(selected, .saveSelected) }
            ))
        } else {
            // Single-item context menu
            let item = sortedItems[clickedRow]
            menu.addItem(contextMenuItem(
                Localization.string(.documentListActivate, default: "Activate"),
                action: { [weak self] in self?.onAction?(item, .activate) }
            ))
            menu.addItem(contextMenuItem(
                Localization.string(.documentListClose, default: "Close"),
                action: { [weak self] in self?.onAction?(item, .close) }
            ))
            menu.addItem(contextMenuItem(
                Localization.string(.documentListCloseOthers, default: "Close Others"),
                action: { [weak self] in self?.onAction?(item, .closeOthers) }
            ))
            menu.addItem(.separator())
            menu.addItem(contextMenuItem(
                Localization.string(.documentListSave, default: "Save"),
                action: { [weak self] in self?.onAction?(item, .save) }
            ))
            menu.addItem(.separator())
            menu.addItem(contextMenuItem(
                Localization.string(.documentListCopyFilename, default: "Copy Filename"),
                action: { [weak self] in self?.onAction?(item, .copyFilename) }
            ))
            menu.addItem(contextMenuItem(
                Localization.string(.documentListCopyPath, default: "Copy Full Path"),
                action: { [weak self] in self?.onAction?(item, .copyPath) }
            ))
            menu.addItem(.separator())
            let pinTitle = item.isPinned
                ? Localization.string(.documentListUnpin, default: "Unpin")
                : Localization.string(.documentListPin, default: "Pin")
            menu.addItem(contextMenuItem(pinTitle, action: { [weak self] in self?.onAction?(item, .togglePin) }))
        }
    }

    private func contextMenuItem(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        DocListMenuItem(title: title, action: action)
    }
}

private final class DocListMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, action: @escaping () -> Void) {
        self.handler = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
    }
    @available(*, unavailable) required init(coder: NSCoder) { fatalError() }
    @objc private func invoke() { handler() }
}
