import AppKit
import NotepadMacCore

@MainActor
final class AutoCompletionPanelController: NSObject {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
        styleMask: [.titled, .closable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let prefixField = NSTextField(labelWithString: "")
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let detailView = NSTextView()
    private var completions: [AutoCompletionKeyword] = []
    private var onInsert: ((AutoCompletionKeyword) -> Void)?

    override init() {
        super.init()
        panel.title = Localization.string(.autoCompletionPanelTitle, default: "Auto Completion")
        panel.isReleasedWhenClosed = false
        configureContent()
    }

    func show(
        catalog: AutoCompletionCatalog,
        prefix: String,
        documentName: String,
        onInsert: @escaping (AutoCompletionKeyword) -> Void
    ) {
        self.completions = catalog.completions(prefix: prefix)
        self.onInsert = onInsert

        let prefixDisplay = prefix.isEmpty ? Localization.string(.autoCompletionAllPrefix, default: "(all)") : prefix
        prefixField.stringValue = String(
            format: Localization.string(.autoCompletionSummary, default: "%@ suggestions for %@: %@"),
            catalog.languageDisplayName,
            documentName,
            prefixDisplay
        )
        popup.removeAllItems()
        for keyword in completions {
            popup.addItem(withTitle: keyword.name)
        }

        popup.isEnabled = !completions.isEmpty
        updateDetail()
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        prefixField.translatesAutoresizingMaskIntoConstraints = false
        prefixField.lineBreakMode = .byTruncatingMiddle
        prefixField.setAccessibilityLabel(
            Localization.string(.autoCompletionSummaryAccessibilityLabel, default: "Auto-completion summary")
        )

        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = self
        popup.action = #selector(selectionChanged(_:))
        popup.setAccessibilityLabel(
            Localization.string(.autoCompletionSuggestionsAccessibilityLabel, default: "Completion suggestions")
        )

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        detailView.isEditable = false
        detailView.isRichText = false
        detailView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        detailView.textContainerInset = NSSize(width: 8, height: 8)
        detailView.setAccessibilityLabel(
            Localization.string(.autoCompletionDetailAccessibilityLabel, default: "Completion details")
        )
        scrollView.documentView = detailView

        let insertButton = NSButton(
            title: Localization.string(.autoCompletionInsert, default: "Insert"),
            target: self,
            action: #selector(insertSelected(_:))
        )
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.bezelStyle = .rounded

        root.addSubview(prefixField)
        root.addSubview(popup)
        root.addSubview(scrollView)
        root.addSubview(insertButton)

        NSLayoutConstraint.activate([
            prefixField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            prefixField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            prefixField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            popup.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            popup.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            popup.topAnchor.constraint(equalTo: prefixField.bottomAnchor, constant: 10),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: popup.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: insertButton.topAnchor, constant: -12),

            insertButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            insertButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    @objc private func selectionChanged(_ sender: Any?) {
        updateDetail()
    }

    @objc private func insertSelected(_ sender: Any?) {
        guard popup.indexOfSelectedItem >= 0, popup.indexOfSelectedItem < completions.count else { return }
        onInsert?(completions[popup.indexOfSelectedItem])
    }

    private func updateDetail() {
        guard !completions.isEmpty else {
            detailView.string = Localization.string(.autoCompletionNoCompletions, default: "No completions found.")
            return
        }

        let keyword = completions[max(0, popup.indexOfSelectedItem)]
        var lines = [keyword.name]
        if keyword.isFunction {
            lines.append(Localization.string(.autoCompletionDetailFunction, default: "Function"))
        }

        for overload in keyword.overloads {
            let parameters = overload.parameters.map(\.name).joined(separator: ", ")
            let signature = "\(keyword.name)(\(parameters))"
            lines.append("")
            lines.append(signature)
            if let returnValue = overload.returnValue {
                lines.append(
                    String(
                        format: Localization.string(.autoCompletionDetailReturns, default: "Returns: %@"),
                        returnValue
                    )
                )
            }
            if let description = overload.description {
                lines.append(description)
            }
        }

        detailView.string = lines.joined(separator: "\n")
    }
}
