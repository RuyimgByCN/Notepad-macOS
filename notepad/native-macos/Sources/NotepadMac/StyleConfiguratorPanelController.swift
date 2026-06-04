import AppKit
import NotepadMacCore

@MainActor
final class StyleConfiguratorPanelController: NSWindowController {
    private var styleCatalog: StyleCatalog
    private let preferencesStore: StylePreferencesStore
    private let onChange: (StylePreferences) -> Void

    private var preferences: StylePreferences
    private var isLoadingControls = false
    private let languageLabel = NSTextField(labelWithString: "")
    private let styleLabel = NSTextField(labelWithString: "")
    private let foregroundLabel = NSTextField(labelWithString: "")
    private let backgroundLabel = NSTextField(labelWithString: "")
    private let fontLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")

    private let languagePopup = NSPopUpButton()
    private let stylePopup = NSPopUpButton()
    private let foregroundWell = NSColorWell()
    private let backgroundWell = NSColorWell()
    private let fontNameField = NSTextField(string: "")
    private let fontSizeField = NSTextField(string: "")
    private let fontSizeStepper = NSStepper()
    private let boldButton = NSButton(
        checkboxWithTitle: Localization.string(.styleConfiguratorBold, default: "Bold"),
        target: nil,
        action: nil
    )
    private let italicButton = NSButton(
        checkboxWithTitle: Localization.string(.styleConfiguratorItalic, default: "Italic"),
        target: nil,
        action: nil
    )
    private let resetButton = NSButton(
        title: Localization.string(.styleConfiguratorResetStyle, default: "Reset Style"),
        target: nil,
        action: nil
    )
    init(
        styleCatalog: StyleCatalog,
        preferencesStore: StylePreferencesStore,
        onChange: @escaping (StylePreferences) -> Void
    ) {
        self.styleCatalog = styleCatalog
        self.preferencesStore = preferencesStore
        self.onChange = onChange
        self.preferences = preferencesStore.load()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 292),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        configureContent()
        refreshLocalizedStrings()
        populateLanguages()
        loadSelectedStyle()
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
        preferences = preferencesStore.load()
        populateLanguages()
        loadSelectedStyle()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func updateStyleCatalog(_ styleCatalog: StyleCatalog) {
        self.styleCatalog = styleCatalog
        populateLanguages()
        loadSelectedStyle()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.styleConfiguratorPanelTitle, default: "Style Configurator")
        languageLabel.stringValue = Localization.string(.styleConfiguratorLanguage, default: "Language")
        styleLabel.stringValue = Localization.string(.styleConfiguratorStyle, default: "Style")
        foregroundLabel.stringValue = Localization.string(.styleConfiguratorForeground, default: "Foreground")
        backgroundLabel.stringValue = Localization.string(.styleConfiguratorBackground, default: "Background")
        fontLabel.stringValue = Localization.string(.styleConfiguratorFont, default: "Font")
        sizeLabel.stringValue = Localization.string(.styleConfiguratorSize, default: "Size")
        boldButton.title = Localization.string(.styleConfiguratorBold, default: "Bold")
        italicButton.title = Localization.string(.styleConfiguratorItalic, default: "Italic")
        resetButton.title = Localization.string(.styleConfiguratorResetStyle, default: "Reset Style")
        languagePopup.setAccessibilityLabel(
            Localization.string(.styleConfiguratorLanguagePopupAccessibilityLabel, default: "Language selector")
        )
        stylePopup.setAccessibilityLabel(
            Localization.string(.styleConfiguratorStylePopupAccessibilityLabel, default: "Style selector")
        )
        foregroundWell.setAccessibilityLabel(
            Localization.string(.styleConfiguratorForegroundAccessibilityLabel, default: "Foreground color")
        )
        backgroundWell.setAccessibilityLabel(
            Localization.string(.styleConfiguratorBackgroundAccessibilityLabel, default: "Background color")
        )
        fontNameField.setAccessibilityLabel(
            Localization.string(.styleConfiguratorFontNameAccessibilityLabel, default: "Font name")
        )
        fontSizeField.setAccessibilityLabel(
            Localization.string(.styleConfiguratorFontSizeFieldAccessibilityLabel, default: "Font size")
        )
        fontSizeStepper.setAccessibilityLabel(
            Localization.string(.styleConfiguratorFontSizeStepperAccessibilityLabel, default: "Font size stepper")
        )
        boldButton.setAccessibilityLabel(
            Localization.string(.styleConfiguratorBoldAccessibilityLabel, default: "Bold style")
        )
        italicButton.setAccessibilityLabel(
            Localization.string(.styleConfiguratorItalicAccessibilityLabel, default: "Italic style")
        )
        resetButton.setAccessibilityLabel(
            Localization.string(.styleConfiguratorResetAccessibilityLabel, default: "Reset selected style")
        )
    }

    @objc private func languageChanged(_ sender: Any?) {
        populateStyles()
        loadSelectedStyle()
    }

    @objc private func styleChanged(_ sender: Any?) {
        loadSelectedStyle()
    }

    @objc private func controlChanged(_ sender: Any?) {
        saveSelectedStyle(sender: sender)
    }

    @objc private func resetSelectedStyle(_ sender: Any?) {
        guard let key = selectedOverrideKey else { return }
        preferences = preferences.removingOverride(for: key)
        preferencesStore.save(preferences)
        loadSelectedStyle()
        onChange(preferences)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged(_:))

        fontSizeField.formatter = integerFormatter
        fontSizeStepper.minValue = 6
        fontSizeStepper.maxValue = 48
        fontSizeStepper.increment = 1

        [foregroundWell, backgroundWell, fontNameField, fontSizeField, fontSizeStepper, boldButton, italicButton].forEach {
            $0.target = self
            $0.action = #selector(controlChanged(_:))
        }

        resetButton.target = self
        resetButton.action = #selector(resetSelectedStyle(_:))

        [
            languageLabel,
            languagePopup,
            styleLabel,
            stylePopup,
            foregroundLabel,
            foregroundWell,
            backgroundLabel,
            backgroundWell,
            fontLabel,
            fontNameField,
            sizeLabel,
            fontSizeField,
            fontSizeStepper,
            boldButton,
            italicButton,
            resetButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            languageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            languageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            languageLabel.widthAnchor.constraint(equalToConstant: 92),

            languagePopup.leadingAnchor.constraint(equalTo: languageLabel.trailingAnchor, constant: 12),
            languagePopup.centerYAnchor.constraint(equalTo: languageLabel.centerYAnchor),
            languagePopup.widthAnchor.constraint(equalToConstant: 360),

            styleLabel.leadingAnchor.constraint(equalTo: languageLabel.leadingAnchor),
            styleLabel.topAnchor.constraint(equalTo: languageLabel.bottomAnchor, constant: 24),
            styleLabel.widthAnchor.constraint(equalTo: languageLabel.widthAnchor),

            stylePopup.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
            stylePopup.centerYAnchor.constraint(equalTo: styleLabel.centerYAnchor),
            stylePopup.widthAnchor.constraint(equalTo: languagePopup.widthAnchor),

            foregroundLabel.leadingAnchor.constraint(equalTo: languageLabel.leadingAnchor),
            foregroundLabel.topAnchor.constraint(equalTo: styleLabel.bottomAnchor, constant: 24),
            foregroundLabel.widthAnchor.constraint(equalTo: languageLabel.widthAnchor),

            foregroundWell.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
            foregroundWell.centerYAnchor.constraint(equalTo: foregroundLabel.centerYAnchor),

            backgroundLabel.leadingAnchor.constraint(equalTo: foregroundWell.trailingAnchor, constant: 48),
            backgroundLabel.centerYAnchor.constraint(equalTo: foregroundLabel.centerYAnchor),

            backgroundWell.leadingAnchor.constraint(equalTo: backgroundLabel.trailingAnchor, constant: 12),
            backgroundWell.centerYAnchor.constraint(equalTo: foregroundLabel.centerYAnchor),

            fontLabel.leadingAnchor.constraint(equalTo: languageLabel.leadingAnchor),
            fontLabel.topAnchor.constraint(equalTo: foregroundLabel.bottomAnchor, constant: 24),
            fontLabel.widthAnchor.constraint(equalTo: languageLabel.widthAnchor),

            fontNameField.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
            fontNameField.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontNameField.widthAnchor.constraint(equalToConstant: 180),

            sizeLabel.leadingAnchor.constraint(equalTo: fontNameField.trailingAnchor, constant: 20),
            sizeLabel.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),

            fontSizeField.leadingAnchor.constraint(equalTo: sizeLabel.trailingAnchor, constant: 8),
            fontSizeField.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontSizeField.widthAnchor.constraint(equalToConstant: 54),

            fontSizeStepper.leadingAnchor.constraint(equalTo: fontSizeField.trailingAnchor, constant: 8),
            fontSizeStepper.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),

            boldButton.leadingAnchor.constraint(equalTo: languagePopup.leadingAnchor),
            boldButton.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: 22),

            italicButton.leadingAnchor.constraint(equalTo: boldButton.trailingAnchor, constant: 20),
            italicButton.centerYAnchor.constraint(equalTo: boldButton.centerYAnchor),

            resetButton.trailingAnchor.constraint(equalTo: languagePopup.trailingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: boldButton.centerYAnchor)
        ])
    }

    private func populateLanguages() {
        let previousSelection = selectedLanguageName

        languagePopup.removeAllItems()
        for lexer in styleCatalog.lexers.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) {
            languagePopup.addItem(withTitle: lexer.displayName)
            languagePopup.lastItem?.representedObject = lexer.name
        }

        if let previousSelection,
           let index = languagePopup.itemArray.firstIndex(where: { $0.representedObject as? String == previousSelection }) {
            languagePopup.selectItem(at: index)
        } else {
            languagePopup.selectItem(at: 0)
        }

        populateStyles()
    }

    private func populateStyles() {
        let previousSelection = selectedStyleID

        stylePopup.removeAllItems()
        guard let lexer = selectedLexer else { return }

        for style in lexer.styles.sorted(by: { $0.styleID < $1.styleID }) {
            stylePopup.addItem(withTitle: "\(style.name) (\(style.styleID))")
            stylePopup.lastItem?.representedObject = style.styleID
        }

        if let previousSelection,
           let index = stylePopup.itemArray.firstIndex(where: { $0.representedObject as? Int == previousSelection }) {
            stylePopup.selectItem(at: index)
        } else {
            stylePopup.selectItem(at: 0)
        }
    }

    private func loadSelectedStyle() {
        guard let key = selectedOverrideKey, let baseStyle = selectedBaseStyle else {
            setControlsEnabled(false)
            return
        }

        isLoadingControls = true
        defer { isLoadingControls = false }

        setControlsEnabled(true)
        let style = preferences.resolvedStyle(for: key, base: baseStyle)
        foregroundWell.color = NSColor(styleColor: style.foreground ?? StyleColor(red: 0, green: 0, blue: 0))
        backgroundWell.color = NSColor(styleColor: style.background ?? StyleColor(red: 255, green: 255, blue: 255))
        fontNameField.stringValue = style.fontName ?? ""
        fontSizeField.integerValue = style.fontSize ?? Int(AppPreferences.defaultValue.editorFontSize)
        fontSizeStepper.integerValue = fontSizeField.integerValue
        boldButton.state = style.isBold ? .on : .off
        italicButton.state = style.isItalic ? .on : .off
    }

    private func saveSelectedStyle(sender: Any?) {
        guard !isLoadingControls, let key = selectedOverrideKey else { return }

        if sender as? NSTextField === fontSizeField {
            fontSizeStepper.integerValue = fontSizeField.integerValue
        } else if fontSizeStepper.integerValue != fontSizeField.integerValue {
            fontSizeField.integerValue = fontSizeStepper.integerValue
        }

        let fontStyle = (boldButton.state == .on ? 1 : 0) + (italicButton.state == .on ? 2 : 0)
        let override = StyleOverride(
            foreground: foregroundWell.color.styleColor,
            background: backgroundWell.color.styleColor,
            fontName: fontNameField.stringValue,
            fontSize: fontSizeField.integerValue,
            fontStyle: fontStyle
        )

        preferences = preferences.setting(override, for: key)
        preferencesStore.save(preferences)
        onChange(preferences)
    }

    private func setControlsEnabled(_ isEnabled: Bool) {
        [
            stylePopup,
            foregroundWell,
            backgroundWell,
            fontNameField,
            fontSizeField,
            fontSizeStepper,
            boldButton,
            italicButton,
            resetButton
        ].forEach { $0.isEnabled = isEnabled }
    }

    private var selectedLanguageName: String? {
        languagePopup.selectedItem?.representedObject as? String
    }

    private var selectedLexer: StyleLexer? {
        selectedLanguageName.flatMap(styleCatalog.lexer(named:))
    }

    private var selectedStyleID: Int? {
        stylePopup.selectedItem?.representedObject as? Int
    }

    private var selectedBaseStyle: LexerStyle? {
        guard let styleID = selectedStyleID else { return nil }
        return selectedLexer?.style(id: styleID)
    }

    private var selectedOverrideKey: StyleOverrideKey? {
        guard let languageName = selectedLanguageName, let styleID = selectedStyleID else { return nil }
        return StyleOverrideKey(languageName: languageName, styleID: styleID)
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 6
        formatter.maximum = 48
        return formatter
    }
}

private extension NSColor {
    convenience init(styleColor: StyleColor) {
        self.init(
            calibratedRed: CGFloat(styleColor.red) / 255,
            green: CGFloat(styleColor.green) / 255,
            blue: CGFloat(styleColor.blue) / 255,
            alpha: 1
        )
    }

    var styleColor: StyleColor? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        return StyleColor(
            red: UInt8((min(max(rgb.redComponent, 0), 1) * 255).rounded()),
            green: UInt8((min(max(rgb.greenComponent, 0), 1) * 255).rounded()),
            blue: UInt8((min(max(rgb.blueComponent, 0), 1) * 255).rounded())
        )
    }
}
