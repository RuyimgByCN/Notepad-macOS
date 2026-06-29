import AppKit

struct WindowsDialogItem {
    let title: String
    let path: String
    let fileType: String
    let fileSize: String
    let modifiedDate: String
    let isDirty: Bool
    let isActive: Bool
    let representedObject: AnyObject?

    static func fileSizeString(_ characterCount: Int) -> String {
        let bytes = characterCount  // approximate 1 char ≈ 1 byte for display
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }
}

enum WindowsDialogAction {
    case activate
    case save
    case close
    case copyFilename
    case copyPath
}

@MainActor
final class WindowsDialogController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )

    private let tableView = NSTableView()
    private let dirtyCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("dirty"))
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    private let pathCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
    private let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
    private let sizeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
    private let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))

    private let activateButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let copyNameButton = NSButton(title: "", target: nil, action: nil)
    private let copyPathButton = NSButton(title: "", target: nil, action: nil)

    private var items: [WindowsDialogItem] = []
    private var sortDescriptors: [NSSortDescriptor] = []
    private var sortedItems: [WindowsDialogItem] = []
    private var onAction: ((WindowsDialogAction, [WindowsDialogItem]) -> Void)?

    var window: NSWindow? { panel }

    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.minSize = NSSize(width: 500, height: 260)
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
        items: [WindowsDialogItem],
        onAction: @escaping (WindowsDialogAction, [WindowsDialogItem]) -> Void
    ) {
        self.items = items
        self.onAction = onAction
        applySortAndReload()
        if let activeIndex = sortedItems.firstIndex(where: \.isActive) {
            tableView.selectRowIndexes(IndexSet(integer: activeIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(activeIndex)
        }
        refreshLocalizedStrings()
        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(items: [WindowsDialogItem]) {
        self.items = items
        applySortAndReload()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        sortedItems.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < sortedItems.count else { return nil }
        let item = sortedItems[row]
        switch tableColumn?.identifier.rawValue {
        case "dirty":  return item.isDirty ? "●" : ""
        case "name":   return item.title
        case "path":   return item.path
        case "type":   return item.fileType
        case "size":   return item.fileSize
        case "date":   return item.modifiedDate
        default:       return nil
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { nil }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        row >= 0 && row < sortedItems.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        sortDescriptors = tableView.sortDescriptors
        applySortAndReload()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }

    // MARK: - Actions

    @objc private func activateClicked(_ sender: Any?) {
        let selected = selectedItems()
        guard let first = selected.first else { return }
        onAction?(.activate, [first])
    }

    @objc private func saveClicked(_ sender: Any?) {
        let selected = selectedItems()
        guard !selected.isEmpty else { return }
        onAction?(.save, selected)
    }

    @objc private func closeClicked(_ sender: Any?) {
        let selected = selectedItems()
        guard !selected.isEmpty else { return }
        onAction?(.close, selected)
    }

    @objc private func copyNameClicked(_ sender: Any?) {
        let selected = selectedItems()
        guard !selected.isEmpty else { return }
        onAction?(.copyFilename, selected)
    }

    @objc private func copyPathClicked(_ sender: Any?) {
        let selected = selectedItems()
        guard !selected.isEmpty else { return }
        onAction?(.copyPath, selected)
    }

    @objc private func tableViewDoubleClicked(_ sender: Any?) {
        let selected = selectedItems()
        guard let first = selected.first else { return }
        onAction?(.activate, [first])
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    // MARK: - Private helpers

    private func selectedItems() -> [WindowsDialogItem] {
        tableView.selectedRowIndexes.compactMap { row in
            guard row < sortedItems.count else { return nil }
            return sortedItems[row]
        }
    }

    private func updateButtonStates() {
        let count = tableView.selectedRowIndexes.count
        activateButton.isEnabled = count == 1
        saveButton.isEnabled = count > 0
        closeButton.isEnabled = count > 0
        copyNameButton.isEnabled = count > 0
        copyPathButton.isEnabled = count > 0
    }

    private func applySortAndReload() {
        if sortDescriptors.isEmpty {
            sortedItems = items
        } else {
            sortedItems = items.sorted { lhs, rhs in
                for descriptor in sortDescriptors {
                    let lhsVal: String
                    let rhsVal: String
                    switch descriptor.key {
                    case "name":  lhsVal = lhs.title;         rhsVal = rhs.title
                    case "path":  lhsVal = lhs.path;          rhsVal = rhs.path
                    case "type":  lhsVal = lhs.fileType;      rhsVal = rhs.fileType
                    case "size":  lhsVal = lhs.fileSize;      rhsVal = rhs.fileSize
                    case "date":  lhsVal = lhs.modifiedDate;  rhsVal = rhs.modifiedDate
                    default:      continue
                    }
                    if lhsVal != rhsVal {
                        let ascending = descriptor.ascending
                        return ascending ? lhsVal < rhsVal : lhsVal > rhsVal
                    }
                }
                return false
            }
        }
        tableView.reloadData()
        updateButtonStates()
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.windowWindowsDialog, default: "Windows")
        activateButton.title = Localization.string(.windowWindowsActivate, default: "Activate")
        saveButton.title = Localization.string(.windowWindowsSave, default: "Save")
        closeButton.title = Localization.string(.windowWindowsClose, default: "Close")
        copyNameButton.title = Localization.string(.windowWindowsCopyName, default: "Copy Name")
        copyPathButton.title = Localization.string(.windowWindowsCopyPath, default: "Copy Path")
        dirtyCol.headerCell.stringValue = Localization.string(.windowWindowsColDirty, default: "")
        nameCol.headerCell.stringValue = Localization.string(.windowWindowsColName, default: "Name")
        pathCol.headerCell.stringValue = Localization.string(.windowWindowsColPath, default: "Path")
        typeCol.headerCell.stringValue = Localization.string(.windowWindowsColType, default: "Type")
        sizeCol.headerCell.stringValue = Localization.string(.windowWindowsColSize, default: "Size")
        dateCol.headerCell.stringValue = Localization.string(.windowWindowsColDate, default: "Modified")
        tableView.headerView?.setNeedsDisplay(tableView.headerView?.bounds ?? .zero)
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        // Table
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        root.addSubview(scroll)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.target = self

        dirtyCol.width = 20
        dirtyCol.minWidth = 14
        dirtyCol.maxWidth = 24
        dirtyCol.isEditable = false

        nameCol.width = 180
        nameCol.minWidth = 80
        nameCol.isEditable = false
        nameCol.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)

        pathCol.width = 220
        pathCol.minWidth = 80
        pathCol.isEditable = false
        pathCol.sortDescriptorPrototype = NSSortDescriptor(key: "path", ascending: true)

        typeCol.width = 60
        typeCol.minWidth = 40
        typeCol.maxWidth = 100
        typeCol.isEditable = false
        typeCol.sortDescriptorPrototype = NSSortDescriptor(key: "type", ascending: true)

        sizeCol.width = 70
        sizeCol.minWidth = 50
        sizeCol.maxWidth = 120
        sizeCol.isEditable = false
        sizeCol.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: true)

        dateCol.width = 140
        dateCol.minWidth = 80
        dateCol.isEditable = false
        dateCol.sortDescriptorPrototype = NSSortDescriptor(key: "date", ascending: true)

        for col in [dirtyCol, nameCol, pathCol, typeCol, sizeCol, dateCol] {
            tableView.addTableColumn(col)
        }

        scroll.documentView = tableView

        // Button row
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .rounded
        activateButton.target = self
        activateButton.action = #selector(activateClicked(_:))
        activateButton.isEnabled = false

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveClicked(_:))
        saveButton.isEnabled = false

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeClicked(_:))
        closeButton.isEnabled = false

        copyNameButton.translatesAutoresizingMaskIntoConstraints = false
        copyNameButton.bezelStyle = .rounded
        copyNameButton.target = self
        copyNameButton.action = #selector(copyNameClicked(_:))
        copyNameButton.isEnabled = false

        copyPathButton.translatesAutoresizingMaskIntoConstraints = false
        copyPathButton.bezelStyle = .rounded
        copyPathButton.target = self
        copyPathButton.action = #selector(copyPathClicked(_:))
        copyPathButton.isEnabled = false

        for btn in [activateButton, saveButton, closeButton, copyNameButton, copyPathButton] {
            root.addSubview(btn)
        }

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: activateButton.topAnchor, constant: -12),

            activateButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            activateButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            activateButton.widthAnchor.constraint(equalToConstant: 90),

            saveButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            saveButton.leadingAnchor.constraint(equalTo: activateButton.trailingAnchor, constant: 8),
            saveButton.widthAnchor.constraint(equalToConstant: 70),

            closeButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            closeButton.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 70),

            copyNameButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            copyNameButton.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 8),
            copyNameButton.widthAnchor.constraint(equalToConstant: 95),

            copyPathButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            copyPathButton.leadingAnchor.constraint(equalTo: copyNameButton.trailingAnchor, constant: 8),
            copyPathButton.widthAnchor.constraint(equalToConstant: 90),
        ])
    }
}
