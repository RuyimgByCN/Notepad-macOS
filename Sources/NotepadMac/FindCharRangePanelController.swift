import AppKit
import NotepadMacCore

@MainActor
final class FindCharRangePanelController: NSWindowController {
    private weak var editor: EditorWindowController?

    private enum RangeChoice: Int {
        case nonASCII = 0
        case ascii = 1
        case custom = 2
    }

    private let nonASCIIButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let asciiButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let customButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let startLabel = NSTextField(labelWithString: "")
    private let endLabel = NSTextField(labelWithString: "")
    private let startField = NSTextField(string: "")
    private let endField = NSTextField(string: "")
    private let directionDownButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let directionUpButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let wrapButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let findButton = NSButton(title: "", target: nil, action: nil)
    private let statusField = NSTextField(labelWithString: "")

    init(editor: EditorWindowController) {
        self.editor = editor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 280),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true

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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        refreshLocalizedStrings()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(findButton)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.findCharRangeTitle, default: "Find Characters in Range")
        nonASCIIButton.title = Localization.string(.findCharRangeNonASCII, default: "Non-ASCII characters (128-255)")
        asciiButton.title = Localization.string(.findCharRangeASCII, default: "ASCII characters (0-127)")
        customButton.title = Localization.string(.findCharRangeCustom, default: "My range in 0-255:")
        startLabel.stringValue = Localization.string(.findCharRangeStartLabel, default: "Start:")
        endLabel.stringValue = Localization.string(.findCharRangeEndLabel, default: "End:")
        directionDownButton.title = Localization.string(.findCharRangeDirectionDown, default: "Down")
        directionUpButton.title = Localization.string(.findCharRangeDirectionUp, default: "Up")
        wrapButton.title = Localization.string(.findCharRangeWrap, default: "Wrap around")
        findButton.title = Localization.string(.findCharRangeFindButton, default: "Find")
        startField.placeholderString = "0"
        endField.placeholderString = "255"
        updateCustomRangeEnabled()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        nonASCIIButton.state = .on
        asciiButton.state = .off
        customButton.state = .off
        directionDownButton.state = .on
        directionUpButton.state = .off
        wrapButton.state = .on

        for button in [nonASCIIButton, asciiButton, customButton] {
            button.target = self
            button.action = #selector(rangeChoiceChanged(_:))
        }

        startField.isEnabled = false
        endField.isEnabled = false
        startField.stringValue = "0"
        endField.stringValue = "255"

        findButton.target = self
        findButton.action = #selector(performFind(_:))
        findButton.keyEquivalent = "\r"

        let allViews: [NSView] = [
            nonASCIIButton, asciiButton, customButton,
            startLabel, startField, endLabel, endField,
            directionDownButton, directionUpButton, wrapButton,
            findButton, statusField
        ]
        for view in allViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            nonASCIIButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            nonASCIIButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),

            asciiButton.leadingAnchor.constraint(equalTo: nonASCIIButton.leadingAnchor),
            asciiButton.topAnchor.constraint(equalTo: nonASCIIButton.bottomAnchor, constant: 8),

            customButton.leadingAnchor.constraint(equalTo: nonASCIIButton.leadingAnchor),
            customButton.topAnchor.constraint(equalTo: asciiButton.bottomAnchor, constant: 8),

            startLabel.leadingAnchor.constraint(equalTo: customButton.leadingAnchor, constant: 20),
            startLabel.topAnchor.constraint(equalTo: customButton.bottomAnchor, constant: 10),
            startLabel.widthAnchor.constraint(equalToConstant: 44),

            startField.leadingAnchor.constraint(equalTo: startLabel.trailingAnchor, constant: 8),
            startField.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startField.widthAnchor.constraint(equalToConstant: 56),

            endLabel.leadingAnchor.constraint(equalTo: startField.trailingAnchor, constant: 16),
            endLabel.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            endLabel.widthAnchor.constraint(equalToConstant: 36),

            endField.leadingAnchor.constraint(equalTo: endLabel.trailingAnchor, constant: 8),
            endField.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endField.widthAnchor.constraint(equalToConstant: 56),

            directionDownButton.leadingAnchor.constraint(equalTo: nonASCIIButton.leadingAnchor),
            directionDownButton.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 14),

            directionUpButton.leadingAnchor.constraint(equalTo: directionDownButton.trailingAnchor, constant: 20),
            directionUpButton.centerYAnchor.constraint(equalTo: directionDownButton.centerYAnchor),

            wrapButton.leadingAnchor.constraint(equalTo: directionUpButton.trailingAnchor, constant: 20),
            wrapButton.centerYAnchor.constraint(equalTo: directionDownButton.centerYAnchor),

            findButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            findButton.topAnchor.constraint(equalTo: directionDownButton.bottomAnchor, constant: 16),

            statusField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statusField.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
        ])
    }

    @objc private func rangeChoiceChanged(_ sender: Any?) {
        if sender as AnyObject? === nonASCIIButton {
            nonASCIIButton.state = .on
            asciiButton.state = .off
            customButton.state = .off
        } else if sender as AnyObject? === asciiButton {
            nonASCIIButton.state = .off
            asciiButton.state = .on
            customButton.state = .off
        } else if sender as AnyObject? === customButton {
            nonASCIIButton.state = .off
            asciiButton.state = .off
            customButton.state = .on
        }
        updateCustomRangeEnabled()
    }

    private func updateCustomRangeEnabled() {
        let isCustom = customButton.state == .on
        startField.isEnabled = isCustom
        endField.isEnabled = isCustom
    }

    private func currentPreset() -> CharRangePreset? {
        if nonASCIIButton.state == .on {
            return .nonASCII
        }
        if asciiButton.state == .on {
            return .ascii
        }
        guard let startValue = UInt8(startField.stringValue),
              let endValue = UInt8(endField.stringValue),
              startValue <= endValue
        else {
            return nil
        }
        return .custom(startValue, endValue)
    }

    @objc private func performFind(_ sender: Any?) {
        guard let preset = currentPreset() else {
            statusField.stringValue = Localization.string(
                .findCharRangeInvalidRange,
                default: "Enter values between 0 and 255, with start ≤ end."
            )
            return
        }

        let direction: TextSearch.Direction = directionUpButton.state == .on ? .up : .down
        let options = CharRangeSearchOptions(
            preset: preset,
            direction: direction,
            wraps: wrapButton.state == .on
        )

        if editor?.performFindCharRange(options: options) == true {
            statusField.stringValue = ""
        } else {
            statusField.stringValue = Localization.string(.findCharRangeNoMatch, default: "No characters found in range.")
        }
    }
}
