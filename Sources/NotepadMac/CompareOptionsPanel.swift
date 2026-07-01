import AppKit
import NotepadMacCore

/// Modal panel for file-compare matching rules (aligned with Notepad-- FileCmpRuleWin).
@MainActor
final class CompareOptionsPanel: NSWindowController {

    var onApply: ((FileDiff.CompareOptions) -> Void)?

    private var options: FileDiff.CompareOptions
    private let whitespaceNoneButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let leadingWhitespaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let trailingWhitespaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let allWhitespaceButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)

    private let modeQuickButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let modeDeepButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)

    init(options: FileDiff.CompareOptions) {
        self.options = options
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
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

        whitespaceNoneButton.title = Localization.string("diff.options.whitespace.none", default: "Do not ignore whitespace")
        leadingWhitespaceButton.title = DiffStrings.optionsIgnoreLeadingWhitespace
        trailingWhitespaceButton.title = DiffStrings.optionsIgnoreTrailingWhitespace
        allWhitespaceButton.title = DiffStrings.optionsIgnoreAllWhitespace
        modeQuickButton.title = Localization.string("diff.options.mode.quick", default: "Quick (no inline highlights)")
        modeDeepButton.title = Localization.string("diff.options.mode.deep", default: "Deep (inline highlights)")

        for button in [whitespaceNoneButton, leadingWhitespaceButton, trailingWhitespaceButton, allWhitespaceButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.target = self
            button.action = #selector(whitespaceOptionChanged(_:))
        }
        for button in [modeQuickButton, modeDeepButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.target = self
            button.action = #selector(modeOptionChanged(_:))
        }

        let compareGroup = NSBox()
        compareGroup.translatesAutoresizingMaskIntoConstraints = false
        compareGroup.title = DiffStrings.optionsCompareGroup
        compareGroup.boxType = .primary

        let compareStack = NSStackView(views: [
            whitespaceNoneButton, leadingWhitespaceButton, trailingWhitespaceButton, allWhitespaceButton
        ])
        compareStack.translatesAutoresizingMaskIntoConstraints = false
        compareStack.orientation = .vertical
        compareStack.alignment = .leading
        compareStack.spacing = 4
        compareGroup.addSubview(compareStack)

        let modeGroup = NSBox()
        modeGroup.translatesAutoresizingMaskIntoConstraints = false
        modeGroup.title = Localization.string("diff.options.mode.title", default: "Compare Mode")
        modeGroup.boxType = .primary
        let modeStack = NSStackView(views: [modeQuickButton, modeDeepButton])
        modeStack.translatesAutoresizingMaskIntoConstraints = false
        modeStack.orientation = .vertical
        modeStack.alignment = .leading
        modeStack.spacing = 4
        modeGroup.addSubview(modeStack)

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
        root.addSubview(modeGroup)
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

            modeGroup.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            modeGroup.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            modeGroup.topAnchor.constraint(equalTo: compareGroup.bottomAnchor, constant: 12),

            modeStack.leadingAnchor.constraint(equalTo: modeGroup.leadingAnchor, constant: 12),
            modeStack.trailingAnchor.constraint(equalTo: modeGroup.trailingAnchor, constant: -12),
            modeStack.topAnchor.constraint(equalTo: modeGroup.topAnchor, constant: 18),
            modeStack.bottomAnchor.constraint(equalTo: modeGroup.bottomAnchor, constant: -10),

            buttonRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            buttonRow.topAnchor.constraint(equalTo: modeGroup.bottomAnchor, constant: 16),
        ])
    }

    private func syncFromOptions() {
        switch options.whitespaceMode {
        case .none:
            whitespaceNoneButton.state = .on
        case .leading:
            leadingWhitespaceButton.state = .on
        case .trailing:
            trailingWhitespaceButton.state = .on
        case .all:
            allWhitespaceButton.state = .on
        }
        switch options.mode {
        case .quick:
            modeQuickButton.state = .on
        case .deep:
            modeDeepButton.state = .on
        }
    }

    @objc private func whitespaceOptionChanged(_ sender: NSButton) {
        if sender === whitespaceNoneButton {
            options.whitespaceMode = .none
        }
        if sender === leadingWhitespaceButton {
            options.whitespaceMode = .leading
        }
        if sender === trailingWhitespaceButton {
            options.whitespaceMode = .trailing
        }
        if sender === allWhitespaceButton {
            options.whitespaceMode = .all
        }
    }

    @objc private func modeOptionChanged(_ sender: NSButton) {
        if sender === modeQuickButton {
            options.mode = .quick
        }
        if sender === modeDeepButton {
            options.mode = .deep
        }
    }

    @objc private func applyClicked() {
        onApply?(options)
        dismiss()
    }

    @objc private func cancelClicked() {
        dismiss()
    }

    private func dismiss() {
        guard let sheet = window else { return }
        if let parent = sheet.sheetParent {
            parent.endSheet(sheet)
            sheet.orderOut(nil)
        } else {
            sheet.close()
        }
    }
}
