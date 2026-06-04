import AppKit

/// Lightweight Ctrl+Tab document switcher, shown as a floating HUD panel.
/// The panel appears when Ctrl+Tab is pressed, cycles items on repeated Tab,
/// and activates the selected document when Ctrl is released.
@MainActor
final class TabSwitcherController: NSObject {
    struct Item {
        let title: String
        let isDirty: Bool
        let representedObject: AnyObject?
    }

    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
        styleMask: [.titled, .nonactivatingPanel, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let tableView = NSTableView()
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))

    private var items: [Item] = []
    private var selectedIndex = 0

    var window: NSWindow? { panel }

    var onConfirm: ((Item) -> Void)?

    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.title = "Documents"
        panel.minSize = NSSize(width: 200, height: 100)
        configureContent()
    }

    func show(items: [Item], selectedIndex: Int) {
        self.items = items
        self.selectedIndex = max(0, min(selectedIndex, items.count - 1))
        tableView.reloadData()
        if self.selectedIndex < items.count {
            tableView.selectRowIndexes(IndexSet(integer: self.selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(self.selectedIndex)
        }
        if !panel.isVisible {
            panel.center()
            panel.orderFront(nil)
        }
    }

    func selectNext() {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % items.count
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    func selectPrevious() {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + items.count) % items.count
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    func confirmAndHide() {
        let idx = tableView.selectedRow
        if idx >= 0, idx < items.count {
            onConfirm?(items[idx])
        }
        panel.orderOut(nil)
    }

    func cancel() {
        panel.orderOut(nil)
    }

    var isVisible: Bool { panel.isVisible }

    // MARK: - Private

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        root.addSubview(scroll)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self

        nameCol.isEditable = false
        nameCol.minWidth = 100
        tableView.addTableColumn(nameCol)

        scroll.documentView = tableView

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
        ])
    }
}

extension TabSwitcherController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < items.count else { return nil }
        let item = items[row]
        return (item.isDirty ? "● " : "  ") + item.title
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }
}
