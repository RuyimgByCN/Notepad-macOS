import AppKit
import NotepadMacCore

// NSPanel with .utilityWindow does not become key on click by default, so
// Cmd+C/Cmd+A would be routed to the editor instead of this results list.
// Overriding canBecomeKey lets the panel take key focus when clicked so that
// keyboard shortcuts reach the outline view's responder-chain actions.
private final class FoundResultsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class FoundResultsPanelController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    // NSOutlineView hashes its items. Reference identity avoids bridging and
    // comparing the contents of entire groups and distinguishes duplicate hits.
    private final class FileRow: NSObject {
        let filePath: String
        var matches: [MatchRow] = []

        init(filePath: String) {
            self.filePath = filePath
        }
    }

    private final class MatchRow: NSObject {
        let index: Int
        let match: FindInFilesMatch
        weak var file: FileRow?

        init(index: Int, match: FindInFilesMatch, file: FileRow) {
            self.index = index
            self.match = match
            self.file = file
        }
    }

    private let store: FindInFilesResultsStore
    private let scrollView = NSScrollView()
    private let outlineView = CopyableOutlineView()
    private let statusField = NSTextField(labelWithString: "")
    private var fileRows: [FileRow] = []
    private var matchRows: [MatchRow] = []
    private var isReloading = false

    var onNavigateToMatch: ((FindInFilesMatch) -> Void)?
    var onFindInSearchResults: (() -> Void)?

    init(store: FindInFilesResultsStore) {
        self.store = store
        let panel = FoundResultsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.minSize = NSSize(width: 480, height: 240)
        super.init(window: panel)
        configureContent()
        refreshLocalizedStrings()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localizationDidChange(_:)),
            name: Localization.localizationDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        reload()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        isReloading = true
        defer { isReloading = false }

        fileRows.removeAll()
        var filesByPath: [String: FileRow] = [:]
        matchRows = store.matches.enumerated().map { index, match in
            let file: FileRow
            if let existing = filesByPath[match.filePath] {
                file = existing
            } else {
                file = FileRow(filePath: match.filePath)
                filesByPath[match.filePath] = file
                fileRows.append(file)
            }
            let row = MatchRow(index: index, match: match, file: file)
            file.matches.append(row)
            return row
        }
        outlineView.reloadData()
        for file in fileRows {
            outlineView.expandItem(file)
        }
        updateStatus()
        revealSelectedMatch()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
        outlineView.reloadData()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.foundResultsPanelTitle, default: "Found Results")
        updateStatus()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.title = ""
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.rowSizeStyle = .small
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(resultDoubleClicked(_:))
        outlineView.allowsMultipleSelection = true
        outlineView.onCopy = { [weak self] in self?.copySelectedResults() ?? false }
        outlineView.menu = buildContextMenu()

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        statusField.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusField)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            statusField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statusField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            statusField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            scrollView.topAnchor.constraint(equalTo: statusField.bottomAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        let copyItem = menu.addItem(
            withTitle: Localization.string(.foundResultsCopySelected, default: "Copy"),
            action: #selector(copySelected(_:)),
            keyEquivalent: "c"
        )
        copyItem.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: Localization.string(.foundResultsOpenAll, default: "Open All Files"), action: #selector(openAllResultFiles(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.foundResultsCopyPathnames, default: "Copy Pathnames"), action: #selector(copyResultPathnames(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.foundResultsCopyAll, default: "Copy All"), action: #selector(copyAllResults(_:)), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: Localization.string(.foundResultsFindInFinder, default: "Find in Search Results..."), action: #selector(findInSearchResults(_:)), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: Localization.string(.foundResultsDeleteSelected, default: "Delete Selected"), action: #selector(deleteSelected(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.foundResultsClearAll, default: "Clear All"), action: #selector(clearAll(_:)), keyEquivalent: "").target = self
        return menu
    }

    private func updateStatus() {
        if store.matches.isEmpty {
            statusField.stringValue = Localization.string(.foundResultsEmpty, default: "No search results")
        } else {
            statusField.stringValue = String(
                format: Localization.string(.foundResultsSummary, default: "%1$d result(s) in %2$d file(s)"),
                store.matches.count,
                fileRows.count
            )
        }
    }

    func revealSelectedMatch() {
        guard matchRows.indices.contains(store.selectedIndex) else { return }
        let item = matchRows[store.selectedIndex]
        if let file = item.file, !outlineView.isItemExpanded(file) {
            outlineView.expandItem(file)
        }
        let row = outlineView.row(forItem: item)
        guard row >= 0 else { return }
        let selection = IndexSet(integer: row)
        if outlineView.selectedRowIndexes != selection {
            outlineView.selectRowIndexes(selection, byExtendingSelection: false)
        }
        outlineView.scrollRowToVisible(row)
    }

    @objc private func resultDoubleClicked(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? MatchRow else { return }
        store.select(index: item.index)
        revealSelectedMatch()
        onNavigateToMatch?(item.match)
    }

    @objc private func openAllResultFiles(_ sender: Any?) {
        let paths = Set(store.matches.map(\.filePath))
        for path in paths.sorted() {
            NotificationCenter.default.post(
                name: .findInFilesOpenFile,
                object: nil,
                userInfo: ["filePath": path, "line": 1]
            )
        }
    }

    @objc private func copyResultPathnames(_ sender: Any?) {
        let paths = Array(Set(store.matches.map(\.filePath))).sorted()
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    @objc private func copyAllResults(_ sender: Any?) {
        let text = store.matches
            .map { "\($0.filePath):\($0.line):\($0.column): \($0.lineText)" }
            .joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func copySelected(_ sender: Any?) {
        if !copySelectedResults() {
            NSSound.beep()
        }
    }

    /// Copies the selected rows (file rows expand to all of their matches);
    /// with no selection, copies every result. Returns false when there is
    /// nothing to copy.
    @discardableResult
    func copySelectedResults() -> Bool {
        var lines: [String] = []
        let selection = outlineView.selectedRowIndexes
        if selection.isEmpty {
            lines = store.matches.map { "\($0.filePath):\($0.line):\($0.column): \($0.lineText)" }
        } else {
            for row in selection {
                let item = outlineView.item(atRow: row)
                if let file = item as? FileRow {
                    lines.append(file.filePath)
                    lines.append(contentsOf: file.matches.map { row in
                        let match = row.match
                        return "\(match.filePath):\(match.line):\(match.column): \(match.lineText)"
                    })
                } else if let row = item as? MatchRow {
                    let match = row.match
                    lines.append("\(match.filePath):\(match.line):\(match.column): \(match.lineText)")
                }
            }
        }
        guard !lines.isEmpty else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        return true
    }

    /// Test hook: clears the outline selection.
    func deselectAllResultsForTesting() {
        outlineView.deselectAll(nil)
    }

    @objc private func findInSearchResults(_ sender: Any?) {
        onFindInSearchResults?()
    }

    @objc private func deleteSelected(_ sender: Any?) {
        let row = outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) else { return }
        if let file = item as? FileRow {
            store.removeFile(file.filePath)
        } else if let match = item as? MatchRow {
            store.remove(at: match.index)
        }
        reload()
    }

    @objc private func clearAll(_ sender: Any?) {
        store.clear()
        reload()
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return fileRows.count
        }
        return (item as? FileRow)?.matches.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is FileRow
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return fileRows[index]
        }
        if let file = item as? FileRow {
            return file.matches[index]
        }
        fatalError("Unexpected outline item")
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("FoundResultCell")
        let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView ?? {
            let newCell = NSTableCellView()
            newCell.identifier = cellIdentifier
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingMiddle
            textField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            newCell.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor),
            ])
            newCell.textField = textField
            return newCell
        }()

        if let file = item as? FileRow {
            let name = (file.filePath as NSString).lastPathComponent
            cell.textField?.font = .boldSystemFont(ofSize: 11)
            cell.textField?.stringValue = "\(name)  (\(file.matches.count))"
            cell.toolTip = file.filePath
        } else if let row = item as? MatchRow {
            let match = row.match
            cell.textField?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textField?.stringValue = "  \(match.line):\(match.column): \(match.lineText)"
            cell.toolTip = match.filePath
        }
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard !isReloading, row >= 0, let match = outlineView.item(atRow: row) as? MatchRow else { return }
        store.select(index: match.index)
    }
}
