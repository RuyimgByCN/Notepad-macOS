import AppKit
import NotepadMacCore

@MainActor
final class HashTextPanelController: NSObject, NSTextViewDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let inputLabel = NSTextField(labelWithString: "")
    private let resultLabel = NSTextField(labelWithString: "")
    private let inputTextView = NSTextView()
    private let resultTextView = NSTextView()
    private lazy var eachLineCheckbox = NSButton(
        checkboxWithTitle: Localization.string(.toolsHashTreatEachLine, default: "Treat each line as a separate string"),
        target: self,
        action: #selector(refreshDigest(_:))
    )
    private lazy var copyButton = NSButton(
        title: Localization.string(.toolsHashCopyToClipboard, default: "Copy to Clipboard"),
        target: self,
        action: #selector(copyDigestToPasteboard(_:))
    )
    private var algorithm: HashAlgorithm = .md5
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

    func show(algorithm: HashAlgorithm) {
        self.algorithm = algorithm
        refreshLocalizedStrings()
        refreshDigest(nil)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func textDidChange(_ notification: Notification) {
        refreshDigest(nil)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        panel.title = String(
            format: Localization.string(.toolsHashGenerateTitleFormat, default: "Generate %@ digest"),
            locale: Locale.current,
            algorithm.displayName
        )
        inputLabel.stringValue = Localization.string(.toolsHashInputLabel, default: "Text")
        resultLabel.stringValue = Localization.string(.toolsHashResultLabel, default: "Digest")
        eachLineCheckbox.title = Localization.string(.toolsHashTreatEachLine, default: "Treat each line as a separate string")
        eachLineCheckbox.setAccessibilityLabel(
            Localization.string(.toolsHashEachLineAccessibilityLabel, default: "Treat each line as a separate string")
        )
        copyButton.title = Localization.string(.toolsHashCopyToClipboard, default: "Copy to Clipboard")
        copyButton.setAccessibilityLabel(
            Localization.string(.toolsHashCopyAccessibilityLabel, default: "Copy digest to clipboard")
        )
        inputTextView.setAccessibilityLabel(
            Localization.string(.toolsHashInputAccessibilityLabel, default: "Hash input text")
        )
        resultTextView.setAccessibilityLabel(
            Localization.string(.toolsHashResultAccessibilityLabel, default: "Hash digest result")
        )
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        inputLabel.translatesAutoresizingMaskIntoConstraints = false
        inputLabel.stringValue = Localization.string(.toolsHashInputLabel, default: "Text")

        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.stringValue = Localization.string(.toolsHashResultLabel, default: "Digest")

        let inputScrollView = NSScrollView()
        inputScrollView.translatesAutoresizingMaskIntoConstraints = false
        inputScrollView.borderType = .bezelBorder
        inputScrollView.hasVerticalScroller = true

        inputTextView.isRichText = false
        inputTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        inputTextView.isAutomaticQuoteSubstitutionEnabled = false
        inputTextView.isAutomaticDashSubstitutionEnabled = false
        inputTextView.delegate = self
        inputTextView.setAccessibilityLabel(
            Localization.string(.toolsHashInputAccessibilityLabel, default: "Hash input text")
        )
        inputScrollView.documentView = inputTextView

        eachLineCheckbox.translatesAutoresizingMaskIntoConstraints = false
        eachLineCheckbox.setAccessibilityLabel(
            Localization.string(.toolsHashEachLineAccessibilityLabel, default: "Treat each line as a separate string")
        )

        let resultScrollView = NSScrollView()
        resultScrollView.translatesAutoresizingMaskIntoConstraints = false
        resultScrollView.borderType = .bezelBorder
        resultScrollView.hasVerticalScroller = true

        resultTextView.isEditable = false
        resultTextView.isSelectable = true
        resultTextView.isRichText = false
        resultTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        resultTextView.setAccessibilityLabel(
            Localization.string(.toolsHashResultAccessibilityLabel, default: "Hash digest result")
        )
        resultScrollView.documentView = resultTextView

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .rounded
        copyButton.setAccessibilityLabel(
            Localization.string(.toolsHashCopyAccessibilityLabel, default: "Copy digest to clipboard")
        )

        root.addSubview(inputLabel)
        root.addSubview(inputScrollView)
        root.addSubview(eachLineCheckbox)
        root.addSubview(resultLabel)
        root.addSubview(resultScrollView)
        root.addSubview(copyButton)

        NSLayoutConstraint.activate([
            inputLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            inputLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            inputScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            inputScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            inputScrollView.topAnchor.constraint(equalTo: inputLabel.bottomAnchor, constant: 8),
            inputScrollView.heightAnchor.constraint(equalToConstant: 150),

            eachLineCheckbox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            eachLineCheckbox.topAnchor.constraint(equalTo: inputScrollView.bottomAnchor, constant: 10),

            resultLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            resultLabel.topAnchor.constraint(equalTo: eachLineCheckbox.bottomAnchor, constant: 12),

            resultScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            resultScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            resultScrollView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 8),
            resultScrollView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -12),

            copyButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            copyButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    @objc private func refreshDigest(_ sender: Any?) {
        let text = inputTextView.string
        if text.isEmpty {
            resultTextView.string = ""
            return
        }

        resultTextView.string = eachLineCheckbox.state == .on
            ? HashToolSupport.digestPerLine(of: text, using: algorithm)
            : HashToolSupport.digest(of: text, using: algorithm)
    }

    @objc private func copyDigestToPasteboard(_ sender: Any?) {
        guard !resultTextView.string.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(resultTextView.string, forType: .string)
    }
}
