import AppKit

struct DocumentMapEntry: Equatable {
    let line: Int
    let utf16Location: Int
    let preview: String

    static func entries(in text: String) -> [DocumentMapEntry] {
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return [DocumentMapEntry(line: 1, utf16Location: 0, preview: "")]
        }

        var entries: [DocumentMapEntry] = []
        var line = 1
        var lineStart = 0
        var location = 0

        while location < nsText.length {
            let codeUnit = nsText.character(at: location)
            if codeUnit == 13 || codeUnit == 10 {
                entries.append(
                    DocumentMapEntry(
                        line: line,
                        utf16Location: lineStart,
                        preview: nsText.substring(with: NSRange(location: lineStart, length: location - lineStart))
                    )
                )

                if codeUnit == 13, location + 1 < nsText.length, nsText.character(at: location + 1) == 10 {
                    location += 2
                } else {
                    location += 1
                }

                line += 1
                lineStart = location
                continue
            }

            location += 1
        }

        entries.append(
            DocumentMapEntry(
                line: line,
                utf16Location: lineStart,
                preview: nsText.substring(with: NSRange(location: lineStart, length: nsText.length - lineStart))
            )
        )

        return entries
    }
}

@MainActor
final class DocumentMapPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let titleField = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let lineColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("line"))
    private let previewColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
    private let goButton = NSButton(title: "", target: nil, action: nil)
    private var entries: [DocumentMapEntry] = []
    private var onSelect: ((DocumentMapEntry) -> Void)?
    private var currentDocumentName = ""

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

    func show(documentName: String, text: String, currentLine: Int, onSelect: @escaping (DocumentMapEntry) -> Void) {
        currentDocumentName = documentName
        self.entries = DocumentMapEntry.entries(in: text)
        self.onSelect = onSelect
        refreshLocalizedStrings()
        tableView.reloadData()
        let selectedIndex = max(0, min(entries.count - 1, currentLine - 1))
        if !entries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < entries.count else { return nil }
        switch tableColumn?.identifier.rawValue {
        case "line":
            return entries[row].line
        default:
            return entries[row].preview
        }
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
            Localization.string(.documentMapSummaryAccessibilityLabel, default: "Document map summary")
        )

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(selectCurrentLine(_:))
        tableView.target = self
        lineColumn.width = 62
        previewColumn.width = 300
        tableView.addTableColumn(lineColumn)
        tableView.addTableColumn(previewColumn)
        scrollView.documentView = tableView

        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.bezelStyle = .rounded
        goButton.target = self
        goButton.action = #selector(selectCurrentLine(_:))

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
            goButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.documentMapPanelTitle, default: "Document Map")
        titleField.setAccessibilityLabel(
            Localization.string(.documentMapSummaryAccessibilityLabel, default: "Document map summary")
        )
        titleField.stringValue = String(
            format: Localization.string(.documentMapSummary, default: "%@    %d lines"),
            currentDocumentName,
            entries.count
        )
        tableView.setAccessibilityLabel(
            Localization.string(.documentMapTableAccessibilityLabel, default: "Document map lines")
        )
        lineColumn.title = Localization.string(.documentMapColumnLine, default: "Line")
        previewColumn.title = Localization.string(.documentMapColumnPreview, default: "Preview")
        goButton.title = Localization.string(.documentMapGoTo, default: "Go To")
        goButton.setAccessibilityLabel(
            Localization.string(.documentMapGoToAccessibilityLabel, default: "Go to selected line")
        )
    }

    private func column(identifier: String, title: String, width: CGFloat) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        return column
    }

    @objc private func selectCurrentLine(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count else { return }
        onSelect?(entries[row])
    }
}
