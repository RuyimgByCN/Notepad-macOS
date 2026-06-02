import AppKit
import NotepadMacCore

@MainActor
final class PreferencesPanelController: NSWindowController {
    private let preferencesStore: PreferencesStore
    private let onChange: (AppPreferences) -> Void

    private let fontSizeField = NSTextField(string: "")
    private let fontSizeStepper = NSStepper()
    private let wrapsLinesButton = NSButton(
        checkboxWithTitle: Localization.string(.preferencesWrapLines),
        target: nil,
        action: nil
    )
    private let searchMatchCaseButton = NSButton(
        checkboxWithTitle: Localization.string(.preferencesMatchCase),
        target: nil,
        action: nil
    )
    private let searchWholeWordButton = NSButton(
        checkboxWithTitle: Localization.string(.preferencesWholeWord),
        target: nil,
        action: nil
    )

    init(preferencesStore: PreferencesStore, onChange: @escaping (AppPreferences) -> Void) {
        self.preferencesStore = preferencesStore
        self.onChange = onChange

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 190),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = Localization.string(.preferencesPanelTitle)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        configureContent()
        loadPreferences()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        loadPreferences()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func controlChanged(_ sender: Any?) {
        savePreferences(sender: sender)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let editorLabel = NSTextField(
            labelWithString: Localization.string(.preferencesEditorSection)
        )
        let fontSizeLabel = NSTextField(
            labelWithString: Localization.string(.preferencesFontSize)
        )
        let searchLabel = NSTextField(
            labelWithString: Localization.string(.preferencesFindDefaults)
        )

        fontSizeStepper.minValue = AppPreferences.minimumEditorFontSize
        fontSizeStepper.maxValue = AppPreferences.maximumEditorFontSize
        fontSizeStepper.increment = 1

        [fontSizeField, fontSizeStepper, wrapsLinesButton, searchMatchCaseButton, searchWholeWordButton].forEach {
            $0.target = self
            $0.action = #selector(controlChanged(_:))
        }

        fontSizeField.formatter = integerFormatter
        fontSizeField.setAccessibilityLabel(Localization.string(.preferencesFontSizeFieldAccessibilityLabel))
        fontSizeStepper.setAccessibilityLabel(Localization.string(.preferencesFontSizeStepperAccessibilityLabel))

        [editorLabel, fontSizeLabel, fontSizeField, fontSizeStepper, wrapsLinesButton, searchLabel, searchMatchCaseButton, searchWholeWordButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        editorLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        searchLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        NSLayoutConstraint.activate([
            editorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            editorLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),

            fontSizeLabel.leadingAnchor.constraint(equalTo: editorLabel.leadingAnchor),
            fontSizeLabel.topAnchor.constraint(equalTo: editorLabel.bottomAnchor, constant: 14),
            fontSizeLabel.widthAnchor.constraint(equalToConstant: 80),

            fontSizeField.leadingAnchor.constraint(equalTo: fontSizeLabel.trailingAnchor, constant: 12),
            fontSizeField.centerYAnchor.constraint(equalTo: fontSizeLabel.centerYAnchor),
            fontSizeField.widthAnchor.constraint(equalToConstant: 58),

            fontSizeStepper.leadingAnchor.constraint(equalTo: fontSizeField.trailingAnchor, constant: 8),
            fontSizeStepper.centerYAnchor.constraint(equalTo: fontSizeField.centerYAnchor),

            wrapsLinesButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            wrapsLinesButton.topAnchor.constraint(equalTo: fontSizeField.bottomAnchor, constant: 14),

            searchLabel.leadingAnchor.constraint(equalTo: editorLabel.leadingAnchor),
            searchLabel.topAnchor.constraint(equalTo: wrapsLinesButton.bottomAnchor, constant: 20),

            searchMatchCaseButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            searchMatchCaseButton.centerYAnchor.constraint(equalTo: searchLabel.centerYAnchor),

            searchWholeWordButton.leadingAnchor.constraint(equalTo: searchMatchCaseButton.trailingAnchor, constant: 20),
            searchWholeWordButton.centerYAnchor.constraint(equalTo: searchMatchCaseButton.centerYAnchor)
        ])
    }

    private func loadPreferences() {
        let preferences = preferencesStore.load()
        fontSizeField.doubleValue = preferences.editorFontSize
        fontSizeStepper.doubleValue = preferences.editorFontSize
        wrapsLinesButton.state = preferences.wrapsLines ? .on : .off
        searchMatchCaseButton.state = preferences.searchMatchCase ? .on : .off
        searchWholeWordButton.state = preferences.searchWholeWord ? .on : .off
    }

    private func savePreferences(sender: Any?) {
        if sender as? NSTextField === fontSizeField {
            fontSizeStepper.doubleValue = fontSizeField.doubleValue
        } else if fontSizeStepper.doubleValue != fontSizeField.doubleValue {
            fontSizeField.doubleValue = fontSizeStepper.doubleValue
        }

        let preferences = AppPreferences(
            editorFontSize: fontSizeField.doubleValue,
            wrapsLines: wrapsLinesButton.state == .on,
            searchMatchCase: searchMatchCaseButton.state == .on,
            searchWholeWord: searchWholeWordButton.state == .on
        )
        preferencesStore.save(preferences)
        loadPreferences()
        onChange(preferences)
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: AppPreferences.minimumEditorFontSize)
        formatter.maximum = NSNumber(value: AppPreferences.maximumEditorFontSize)
        return formatter
    }
}
