import AppKit
import NotepadMacCore

@MainActor
final class FindCharRangePanelController: NSWindowController {
    private weak var editor: EditorWindowController?

    private let startLabel = NSTextField(labelWithString: "")
    private let endLabel = NSTextField(labelWithString: "")
    private let startField = NSTextField(string: "")
    private let endField = NSTextField(string: "")
    private let findButton = NSButton(title: "", target: nil, action: nil)
    private let statusField = NSTextField(labelWithString: "")

    init(editor: EditorWindowController) {
        self.editor = editor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

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
        window?.makeFirstResponder(startField)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.findCharRangeTitle, default: "Find Characters in Range")
        startLabel.stringValue = Localization.string(.findCharRangeStartLabel, default: "Start (code point):")
        endLabel.stringValue = Localization.string(.findCharRangeEndLabel, default: "End (code point):")
        findButton.title = Localization.string(.findCharRangeFindButton, default: "Find")
        startField.placeholderString = "0"
        endField.placeholderString = "127"
        startField.setAccessibilityLabel(Localization.string(.findCharRangeStartLabel, default: "Start (code point):"))
        endField.setAccessibilityLabel(Localization.string(.findCharRangeEndLabel, default: "End (code point):"))
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        findButton.target = self
        findButton.action = #selector(performFind(_:))
        findButton.keyEquivalent = "\r"

        let allViews: [NSView] = [startLabel, startField, endLabel, endField, findButton, statusField]
        for view in allViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            startLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            startLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            startLabel.widthAnchor.constraint(equalToConstant: 130),

            startField.leadingAnchor.constraint(equalTo: startLabel.trailingAnchor, constant: 8),
            startField.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            startField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            endLabel.leadingAnchor.constraint(equalTo: startLabel.leadingAnchor),
            endLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 12),
            endLabel.widthAnchor.constraint(equalToConstant: 130),

            endField.leadingAnchor.constraint(equalTo: endLabel.trailingAnchor, constant: 8),
            endField.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            findButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            findButton.topAnchor.constraint(equalTo: endLabel.bottomAnchor, constant: 16),

            statusField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statusField.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
        ])
    }

    @objc private func performFind(_ sender: Any?) {
        guard let startValue = UInt32(startField.stringValue),
              let endValue = UInt32(endField.stringValue)
        else {
            statusField.stringValue = Localization.string(.findCharRangeInvalidRange, default: "Invalid range. Start must be ≤ End.")
            return
        }

        guard startValue <= endValue else {
            statusField.stringValue = Localization.string(.findCharRangeInvalidRange, default: "Invalid range. Start must be ≤ End.")
            return
        }

        if editor?.performFindCharRange(start: startValue, end: endValue) == true {
            statusField.stringValue = ""
        } else {
            statusField.stringValue = Localization.string(.findCharRangeNoMatch, default: "No characters found in range.")
        }
    }
}
