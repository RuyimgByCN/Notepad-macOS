import AppKit
import NotepadMacCore

@MainActor
final class TaskListPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let titleField = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let lineColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("line"))
    private let tagColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tag"))
    private let messageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
    private var entries: [TaskListEntry] = []
    private var onSelect: ((TaskListEntry) -> Void)?
    private var currentDocumentName = ""
    private var activeTags: [String] = TaskListScanner.defaultTags
    private weak var goButton: NSButton?

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

    var isVisible: Bool { panel.isVisible }

    func show(
        documentName: String,
        text: String,
        customTagsPreference: String = "",
        onSelect: @escaping (TaskListEntry) -> Void
    ) {
        currentDocumentName = documentName
        self.onSelect = onSelect
        activeTags = TaskListScanner.tags(fromPreference: customTagsPreference)
        update(documentName: documentName, text: text, customTagsPreference: customTagsPreference)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(documentName: String, text: String, customTagsPreference: String = "") {
        currentDocumentName = documentName
        if !customTagsPreference.isEmpty {
            activeTags = TaskListScanner.tags(fromPreference: customTagsPreference)
        }
        entries = TaskListScanner.scan(text: text, tags: activeTags)
        refreshLocalizedStrings()
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < entries.count else { return nil }
        let entry = entries[row]
        switch tableColumn?.identifier.rawValue {
        case "line":    return entry.line
        case "tag":     return entry.tag
        case "message": return entry.message.isEmpty ? entry.preview : entry.message
        default:        return nil
        }
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count else { return }
        onSelect?(entries[row])
    }

    // MARK: - Private

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    @objc private func goToSelectedEntry(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count else { return }
        onSelect?(entries[row])
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(goToSelectedEntry(_:))
        tableView.target = self

        lineColumn.width = 50
        lineColumn.minWidth = 40
        tagColumn.width = 60
        tagColumn.minWidth = 50
        messageColumn.width = 300

        tableView.addTableColumn(lineColumn)
        tableView.addTableColumn(tagColumn)
        tableView.addTableColumn(messageColumn)
        scrollView.documentView = tableView

        let goButton = NSButton(title: Localization.string(.taskListGoTo, default: "Go To"), target: self, action: #selector(goToSelectedEntry(_:)))
        self.goButton = goButton
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.bezelStyle = .rounded

        root.addSubview(titleField)
        root.addSubview(scrollView)
        root.addSubview(goButton)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            titleField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: goButton.topAnchor, constant: -12),

            goButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            goButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
        ])
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.taskListPanelTitle, default: "Task List")
        let count = entries.count
        if count == 0 {
            titleField.stringValue = "\(currentDocumentName)    \(Localization.string(.taskListNoTasks, default: "No tasks found"))"
        } else {
            titleField.stringValue = String(
                format: Localization.string(.taskListSummary, default: "%@    %d task(s)"),
                currentDocumentName, count
            )
        }
        lineColumn.title = Localization.string(.taskListColumnLine, default: "Line")
        tagColumn.title = Localization.string(.taskListColumnTag, default: "Tag")
        messageColumn.title = Localization.string(.taskListColumnMessage, default: "Message")
        goButton?.title = Localization.string(.taskListGoTo, default: "Go To")
    }
}
