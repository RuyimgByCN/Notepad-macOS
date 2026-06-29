import AppKit
import NotepadMacCore

/// Modal panel for file-compare matching rules (aligned with Notepad-- FileCmpRuleWin).
@MainActor
final class CompareOptionsPanel: NSWindowController {

    var onApply: ((FileDiff.CompareOptions) -> Void)?

    private var options: FileDiff.CompareOptions
    private let leadingWhitespaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let trailingWhitespaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let allWhitespaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)

    init(options: FileDiff.CompareOptions) {
        self.options = options
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = DiffStrings.optionsTitle
        window.isFloatingPanel = true
        window.hidesOnDeactivate = true
        configureContent()
        syncFromOptions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        leadingWhitespaceButton.title = DiffStrings.optionsIgnoreLeadingWhitespace
        trailingWhitespaceButton.title = DiffStrings.optionsIgnoreTrailingWhitespace
        allWhitespaceButton.title = DiffStrings.optionsIgnoreAllWhitespace
        trailingWhitespaceButton.isEnabled = false
        allWhitespaceButton.isEnabled = false
        trailingWhitespaceButton.toolTip = DiffStrings.optionsComingSoon
        allWhitespaceButton.toolTip = DiffStrings.optionsComingSoon

        for button in [leadingWhitespaceButton, trailingWhitespaceButton, allWhitespaceButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.target = self
            button.action = #selector(whitespaceOptionChanged(_:))
        }

        let compareGroup = NSBox()
        compareGroup.translatesAutoresizingMaskIntoConstraints = false
        compareGroup.title = DiffStrings.optionsCompareGroup
        compareGroup.boxType = .primary

        let compareStack = NSStackView(views: [
            leadingWhitespaceButton, trailingWhitespaceButton, allWhitespaceButton
        ])
        compareStack.translatesAutoresizingMaskIntoConstraints = false
        compareStack.orientation = .vertical
        compareStack.alignment = .leading
        compareStack.spacing = 4
        compareGroup.addSubview(compareStack)

        let applyButton = NSButton(title: DiffStrings.optionsApply, target: self, action: #selector(applyClicked))
        let cancelButton = NSButton(title: DiffStrings.optionsCancel, target: self, action: #selector(cancelClicked))
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"

        let buttonRow = NSStackView(views: [NSView(), applyButton, cancelButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        root.addSubview(compareGroup)
        root.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            compareGroup.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            compareGroup.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            compareGroup.topAnchor.constraint(equalTo: root.topAnchor),

            compareStack.leadingAnchor.constraint(equalTo: compareGroup.leadingAnchor, constant: 12),
            compareStack.trailingAnchor.constraint(equalTo: compareGroup.trailingAnchor, constant: -12),
            compareStack.topAnchor.constraint(equalTo: compareGroup.topAnchor, constant: 18),
            compareStack.bottomAnchor.constraint(equalTo: compareGroup.bottomAnchor, constant: -10),

            buttonRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            buttonRow.topAnchor.constraint(equalTo: compareGroup.bottomAnchor, constant: 16),
        ])
    }

    private func syncFromOptions() {
        if options.ignoreLeadingWhitespace {
            leadingWhitespaceButton.state = .on
        } else {
            allWhitespaceButton.state = .on
        }
    }

    @objc private func whitespaceOptionChanged(_ sender: NSButton) {
        if sender === leadingWhitespaceButton {
            options.ignoreLeadingWhitespace = true
        }
    }

    @objc private func applyClicked() {
        onApply?(options)
        close()
    }

    @objc private func cancelClicked() {
        close()
    }
}
