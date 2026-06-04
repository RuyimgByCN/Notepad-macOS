import AppKit

@MainActor
final class ClipboardHistoryPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let statusField = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
    private let insertButton = NSButton(title: "", target: nil, action: nil)
    private let store = ClipboardHistoryStore()
    private var onInsert: ((String) -> Void)?
    private var pollTimer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        configureContent()
        refreshLocalizedStrings()
        refreshStatus()
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

    func show(onInsert: @escaping (String) -> Void) {
        self.onInsert = onInsert
        capturePasteboard(force: true)
        tableView.reloadData()
        if !store.entries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        startPolling()
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        stopPolling()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < store.entries.count else { return nil }
        return previewText(for: store.entries[row])
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        statusField.translatesAutoresizingMaskIntoConstraints = false
        statusField.setAccessibilityLabel(
            Localization.string(.clipboardHistoryStatusAccessibilityLabel, default: "Clipboard history status")
        )

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(insertSelectedEntry(_:))
        tableView.target = self
        contentColumn.width = 400
        tableView.addTableColumn(contentColumn)
        scrollView.documentView = tableView

        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.bezelStyle = .rounded
        insertButton.target = self
        insertButton.action = #selector(insertSelectedEntry(_:))

        root.addSubview(statusField)
        root.addSubview(scrollView)
        root.addSubview(insertButton)

        NSLayoutConstraint.activate([
            statusField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            statusField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            statusField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: statusField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: insertButton.topAnchor, constant: -12),

            insertButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            insertButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.clipboardHistoryPanelTitle, default: "Clipboard History")
        statusField.setAccessibilityLabel(
            Localization.string(.clipboardHistoryStatusAccessibilityLabel, default: "Clipboard history status")
        )
        tableView.setAccessibilityLabel(
            Localization.string(.clipboardHistoryTableAccessibilityLabel, default: "Clipboard history items")
        )
        contentColumn.title = Localization.string(.clipboardHistoryColumnContent, default: "Content")
        insertButton.title = Localization.string(.clipboardHistoryInsert, default: "Insert")
        insertButton.setAccessibilityLabel(
            Localization.string(.clipboardHistoryInsertAccessibilityLabel, default: "Insert selected clipboard item")
        )
        refreshStatus()
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.capturePasteboard()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func capturePasteboard(force: Bool = false) {
        let pasteboard = NSPasteboard.general
        if !force, pasteboard.changeCount == lastChangeCount {
            return
        }

        lastChangeCount = pasteboard.changeCount
        guard let value = pasteboard.string(forType: .string) else {
            refreshStatus()
            return
        }

        store.record(value)
        tableView.reloadData()
        if !store.entries.isEmpty, tableView.selectedRow < 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        refreshStatus()
    }

    private func refreshStatus() {
        if store.entries.isEmpty {
            statusField.stringValue = Localization.string(
                .clipboardHistoryEmpty,
                default: "Clipboard history is empty."
            )
        } else {
            statusField.stringValue = String(
                format: Localization.string(
                    .clipboardHistorySummary,
                    default: "%d clipboard item(s)"
                ),
                store.entries.count
            )
        }
    }

    private func previewText(for entry: String) -> String {
        let singleLine = entry.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if singleLine.count <= 120 {
            return singleLine
        }
        let prefix = singleLine.prefix(117)
        return "\(prefix)..."
    }

    @objc private func insertSelectedEntry(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < store.entries.count else { return }
        onInsert?(store.entries[row])
    }
}
