import AppKit

enum DocumentListAction {
    case activate
    case close
    case closeOthers
    case copyFilename
    case copyPath
    case togglePin
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
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let titleField = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
    private let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
    private let activateButton = NSButton(title: "", target: nil, action: nil)
    private var items: [DocumentListItem] = []
    private var onSelect: ((DocumentListItem) -> Void)?
    private var onAction: ((DocumentListItem, DocumentListAction) -> Void)?

    var window: NSWindow? {
        panel
    }

    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
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
        onAction: ((DocumentListItem, DocumentListAction) -> Void)? = nil
    ) {
        self.items = items
        self.onSelect = onSelect
        self.onAction = onAction
        refreshLocalizedStrings()
        tableView.reloadData()
        if let activeIndex = items.firstIndex(where: \.isActive) {
            tableView.selectRowIndexes(IndexSet(integer: activeIndex), byExtendingSelection: false)
        } else if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(items: [DocumentListItem]) {
        guard items != self.items else { return }
        self.items = items
        tableView.reloadData()
        refreshLocalizedStrings()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < items.count else { return nil }
        let item = items[row]
        switch tableColumn?.identifier.rawValue {
        case "detail":
            return item.detail
        default:
            let prefix = item.isDirty ? "● " : (item.isPinned ? "📌 " : "")
            return prefix + item.title
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        row >= 0 && row < items.count
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
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(selectCurrentDocument(_:))
        tableView.target = self
        tableView.menu = buildPlaceholderMenu()
        titleColumn.width = 160
        detailColumn.width = 260
        tableView.addTableColumn(titleColumn)
        tableView.addTableColumn(detailColumn)
        scrollView.documentView = tableView

        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .rounded
        activateButton.target = self
        activateButton.action = #selector(selectCurrentDocument(_:))

        root.addSubview(titleField)
        root.addSubview(scrollView)
        root.addSubview(activateButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            titleField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: activateButton.topAnchor, constant: -12),

            activateButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            activateButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
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
    }

    private func column(identifier: String, title: String, width: CGFloat) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        return column
    }

    @objc private func selectCurrentDocument(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < items.count else { return }
        onSelect?(items[row])
    }

    // MARK: - Context menu (NSMenuDelegate)

    private func buildPlaceholderMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow
        guard row >= 0, row < items.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        let item = items[row]
        menu.addItem(contextMenuItem("Activate", action: { [weak self] in self?.onAction?(item, .activate) }))
        menu.addItem(contextMenuItem("Close", action: { [weak self] in self?.onAction?(item, .close) }))
        menu.addItem(contextMenuItem("Close Others", action: { [weak self] in self?.onAction?(item, .closeOthers) }))
        menu.addItem(.separator())
        menu.addItem(contextMenuItem("Copy Filename", action: { [weak self] in self?.onAction?(item, .copyFilename) }))
        menu.addItem(contextMenuItem("Copy Full Path", action: { [weak self] in self?.onAction?(item, .copyPath) }))
        menu.addItem(.separator())
        let pinTitle = item.isPinned ? "Unpin" : "Pin"
        menu.addItem(contextMenuItem(pinTitle, action: { [weak self] in self?.onAction?(item, .togglePin) }))
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
