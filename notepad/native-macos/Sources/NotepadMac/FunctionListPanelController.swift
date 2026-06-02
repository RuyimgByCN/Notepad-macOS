import AppKit
import NotepadMacCore

@MainActor
final class FunctionListPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let titleField = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private var symbols: [FunctionListSymbol] = []
    private var onSelect: ((FunctionListSymbol) -> Void)?

    override init() {
        super.init()
        panel.title = Localization.string(.functionListPanelTitle, default: "Function List")
        panel.isReleasedWhenClosed = false
        configureContent()
    }

    func show(
        symbols: [FunctionListSymbol],
        languageDisplayName: String,
        documentName: String,
        onSelect: @escaping (FunctionListSymbol) -> Void
    ) {
        self.symbols = symbols
        self.onSelect = onSelect
        titleField.stringValue = String(
            format: Localization.string(.functionListSummary, default: "%@    %@    %d symbols"),
            documentName,
            languageDisplayName,
            symbols.count
        )
        tableView.reloadData()
        if !symbols.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        symbols.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < symbols.count else { return nil }
        let symbol = symbols[row]

        switch tableColumn?.identifier.rawValue {
        case "line":
            return symbol.line
        case "kind":
            return localizedKind(symbol.kind)
        default:
            return symbol.name
        }
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.setAccessibilityLabel(
            Localization.string(.functionListSummaryAccessibilityLabel, default: "Function-list summary")
        )

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.setAccessibilityLabel(
            Localization.string(.functionListTableAccessibilityLabel, default: "Function symbols")
        )
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(selectCurrentSymbol(_:))
        tableView.target = self
        tableView.addTableColumn(column(
            identifier: "line",
            title: Localization.string(.functionListColumnLine, default: "Line"),
            width: 62
        ))
        tableView.addTableColumn(column(
            identifier: "kind",
            title: Localization.string(.functionListColumnKind, default: "Kind"),
            width: 88
        ))
        tableView.addTableColumn(column(
            identifier: "name",
            title: Localization.string(.functionListColumnName, default: "Name"),
            width: 220
        ))
        scrollView.documentView = tableView

        let goButton = NSButton(
            title: Localization.string(.functionListGoTo, default: "Go To"),
            target: self,
            action: #selector(selectCurrentSymbol(_:))
        )
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.bezelStyle = .rounded
        goButton.setAccessibilityLabel(
            Localization.string(.functionListGoToAccessibilityLabel, default: "Go to selected symbol")
        )

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

    private func column(identifier: String, title: String, width: CGFloat) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        return column
    }

    private func localizedKind(_ kind: FunctionListSymbolKind) -> String {
        switch kind {
        case .function:
            Localization.string(.functionListKindFunction, default: "function")
        case .type:
            Localization.string(.functionListKindType, default: "type")
        }
    }

    @objc private func selectCurrentSymbol(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < symbols.count else { return }
        onSelect?(symbols[row])
    }
}
