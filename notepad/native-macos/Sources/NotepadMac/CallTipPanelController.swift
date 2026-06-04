import AppKit
import NotepadMacCore

@MainActor
final class CallTipPanelController: NSObject {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
        styleMask: [.titled, .closable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let summaryField = NSTextField(labelWithString: "")
    private let detailView = NSTextView()

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

    func show(callTip: AutoCompletionCallTip, languageDisplayName: String, documentName: String) {
        summaryField.stringValue = String(
            format: Localization.string(.callTipSummary, default: "%@ call tip for %@: %@"),
            languageDisplayName,
            documentName,
            callTip.keyword.name
        )
        detailView.string = detailText(for: callTip)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        summaryField.translatesAutoresizingMaskIntoConstraints = false
        summaryField.lineBreakMode = .byTruncatingMiddle
        summaryField.setAccessibilityLabel(
            Localization.string(.callTipSummaryAccessibilityLabel, default: "Call-tip summary")
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
            Localization.string(.callTipDetailAccessibilityLabel, default: "Call-tip details")
        )
        scrollView.documentView = detailView

        root.addSubview(summaryField)
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            summaryField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            summaryField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            summaryField.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: summaryField.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.callTipPanelTitle, default: "Function Call Tip")
        summaryField.setAccessibilityLabel(
            Localization.string(.callTipSummaryAccessibilityLabel, default: "Call-tip summary")
        )
        detailView.setAccessibilityLabel(
            Localization.string(.callTipDetailAccessibilityLabel, default: "Call-tip details")
        )
    }

    private func detailText(for callTip: AutoCompletionCallTip) -> String {
        var lines = [
            String(
                format: Localization.string(.callTipActiveParameter, default: "Active parameter: %d"),
                callTip.activeParameterIndex + 1
            ),
            ""
        ]
        for (index, signature) in callTip.signatures.enumerated() {
            lines.append(signature)
            if index < callTip.details.count {
                lines.append(callTip.details[index])
            }
            if index < callTip.signatures.count - 1 {
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }
}
