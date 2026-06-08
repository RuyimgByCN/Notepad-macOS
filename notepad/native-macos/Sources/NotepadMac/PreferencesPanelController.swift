import AppKit
import NotepadMacCore

@MainActor
final class PreferencesPanelController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    private let preferencesStore: PreferencesStore
    private let localizationOptions: [AppLocalizationOption]
    private let onChange: (AppPreferences) -> Void

    private let localizationSectionLabel = NSTextField(labelWithString: "")
    private let localizationChoiceLabel = NSTextField(labelWithString: "")
    private let editorSectionLabel = NSTextField(labelWithString: "")
    private let fontSizeLabel = NSTextField(labelWithString: "")
    private let editorFeaturesSectionLabel = NSTextField(labelWithString: "")
    private let newDocumentSectionLabel = NSTextField(labelWithString: "")
    private let newDocEncodingLabel = NSTextField(labelWithString: "")
    private let newDocLineEndingLabel = NSTextField(labelWithString: "")
    private let rememberSessionButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let newDocumentOnLaunchButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let useFirstLineAsTabNameButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let recentFilesMaxLabel = NSTextField(labelWithString: "")
    private let recentFilesMaxField = NSTextField(string: "20")
    private let recentFilesMaxStepper = NSStepper()
    private let recentFilesShowFullPathButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let recentFilesInSubmenuButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let recentFilesCustomLengthLabel = NSTextField(labelWithString: "")
    private let recentFilesCustomLengthField = NSTextField(string: "0")
    private let recentFilesCustomLengthStepper = NSStepper()
    private let noCheckRecentAtLaunchButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let keepAbsentFilesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoReloadButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let snapshotModeButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let periodicBackupLabel = NSTextField(labelWithString: "")
    private let periodicBackupField = NSTextField(string: "7")
    private let periodicBackupStepper = NSStepper()
    private let backupOnSaveLabel = NSTextField(labelWithString: "")
    private let backupOnSavePopup = NSPopUpButton()
    private let useCustomBackupDirButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let customBackupDirField = NSTextField(string: "")
    private let customBackupDirBrowseButton = NSButton(title: "", target: nil, action: nil)
    private let printLineNumbersButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Print section
    private let printSectionLabel = NSTextField(labelWithString: "")
    private let printHeaderSectionLabel = NSTextField(labelWithString: "")
    private let printHeaderLeftField = NSTextField(string: "")
    private let printHeaderCenterField = NSTextField(string: "$(FILE_NAME)")
    private let printHeaderRightField = NSTextField(string: "")
    private let printFooterSectionLabel = NSTextField(labelWithString: "")
    private let printFooterLeftField = NSTextField(string: "")
    private let printFooterCenterField = NSTextField(string: "")
    private let printFooterRightField = NSTextField(string: "$(PAGE) / $(PAGES)")
    private let printColorModeLabel = NSTextField(labelWithString: "")
    private let printColorModePopup = NSPopUpButton()
    private let printFontSizeLabel = NSTextField(labelWithString: "")
    private let printFontSizeField = NSTextField(string: "0")
    private let printFontSizeStepper = NSStepper()
    private let printMarginsLabel = NSTextField(labelWithString: "")
    private let printMarginTopLabel = NSTextField(labelWithString: "")
    private let printMarginTopField = NSTextField(string: "36")
    private let printMarginBottomLabel = NSTextField(labelWithString: "")
    private let printMarginBottomField = NSTextField(string: "36")
    private let printMarginLeftLabel = NSTextField(labelWithString: "")
    private let printMarginLeftField = NSTextField(string: "36")
    private let printMarginRightLabel = NSTextField(labelWithString: "")
    private let printMarginRightField = NSTextField(string: "36")
    // Delimiter section (in Window tab)
    private let delimiterSectionLabel = NSTextField(labelWithString: "")
    private let delimiterLeftLabel = NSTextField(labelWithString: "")
    private let delimiterLeftField = NSTextField(string: "")
    private let delimiterRightLabel = NSTextField(labelWithString: "")
    private let delimiterRightField = NSTextField(string: "")
    // General section (in Window tab)
    private let generalSectionLabel = NSTextField(labelWithString: "")
    private let statusBarVisibleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let shortTitleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveAllConfirmButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteIgnoreNumbersButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let reloadScrollToLastCaretButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let openDirFollowsDocButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let openAnsiAsUtf8Button = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let xmlTagAttributeHighlightButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let highlightNonHtmlZoneButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let defaultSaveDirLabel = NSTextField(labelWithString: "")
    private let defaultSaveDirField = NSTextField(string: "")
    private let folderDropAsWorkspaceButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let folderDropRecursiveOpenButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let defaultLangLabel = NSTextField(labelWithString: "")
    private let defaultLangPopup = NSPopUpButton()
    private let additionalEdgeColumnsLabel = NSTextField(labelWithString: "")
    private let additionalEdgeColumnsField = NSTextField(string: "")
    private let findDefaultsSectionLabel = NSTextField(labelWithString: "")
    private let dateTimeSectionLabel = NSTextField(labelWithString: "")
    private let dateTimeFormatLabel = NSTextField(labelWithString: "")
    private let searchEngineSectionLabel = NSTextField(labelWithString: "")
    private let searchEngineChoiceLabel = NSTextField(labelWithString: "")
    private let searchEngineCustomURLLabel = NSTextField(labelWithString: "")

    private let localizationPopup = NSPopUpButton()
    private let fontSizeField = NSTextField(string: "")
    private let fontSizeStepper = NSStepper()
    private let editorFontNameLabel = NSTextField(labelWithString: "")
    private let editorFontNameField = NSTextField(string: "")
    private let editorFontBoldButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wrapsLinesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabSizeLabel = NSTextField(labelWithString: "")
    private let tabSizeField = NSTextField(string: "")
    private let tabSizeStepper = NSStepper()
    private let insertSpacesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairParenthesesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairBracketsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairCurlyBracketsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairSingleQuotesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairDoubleQuotesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let customPairsTableView = NSTableView()
    private let customPairsScrollView = NSScrollView()
    private var customPairsData: [[String]] = []
    private let customPairsAddButton = NSButton(title: "+", target: nil, action: nil)
    private let customPairsRemoveButton = NSButton(title: "−", target: nil, action: nil)
    private let xmlTagMatchButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let clickableLinksButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smartHighlightMatchCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smartHighlightWholeWordButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let markAllMatchCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let markAllWholeWordButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let langMenuCompactButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let caretWidthLabel = NSTextField(labelWithString: "")
    private let caretWidthSegmented = NSSegmentedControl()
    private let caretNoBlinkButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let caretBlinkRateLabel = NSTextField(labelWithString: "")
    private let caretBlinkRateField = NSTextField(string: "")
    private let caretBlinkRateStepper = NSStepper()
    private let caretStickyModeLabel = NSTextField(labelWithString: "")
    private let caretStickyModePopup = NSPopUpButton()
    private let currentLineFrameLabel = NSTextField(labelWithString: "")
    private let currentLineFrameSegmented = NSSegmentedControl()
    private let lineWrapIndentLabel = NSTextField(labelWithString: "")
    private let lineWrapIndentPopup = NSPopUpButton()
    private let enableCodeFoldingButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let foldMarginStyleLabel = NSTextField(labelWithString: "")
    private let foldMarginStylePopup = NSPopUpButton()
    private let virtualSpaceButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let backspaceUnindentsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoIndentButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoIndentModeLabel = NSTextField(labelWithString: "")
    private let autoIndentModePopup = NSPopUpButton()
    private let fileAutoDetectionLabel = NSTextField(labelWithString: "")
    private let fileAutoDetectionPopup = NSPopUpButton()
    private let updateSilentlyButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let zoomSyncToAllTabsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hideMenuShortcutsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let scrollToLastLineOnMonitorReloadButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let scrollBeyondLastLineButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let selectedTextDragDropButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let lineNumberDynamicWidthButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let columnSelectionToMultiEditingButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showBookmarkMarginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showEdgeLineButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Display Defaults section
    private let displayDefaultsSectionLabel = NSTextField(labelWithString: "")
    private let showLineNumberMarginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showWhitespaceButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let whitespaceDisplayModeLabel = NSTextField(labelWithString: "")
    private let whitespaceDisplayModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let bidiModeLabel = NSTextField(labelWithString: "")
    private let bidiModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let showEOLButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showIndentGuidesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let highlightCurrentLineButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showNpcCharactersButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showWrapSymbolButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showChangeHistoryButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let edgeLineColumnLabel = NSTextField(labelWithString: "")
    private let edgeLineColumnField = NSTextField(string: "80")
    private let edgeLineColumnStepper = NSStepper()
    private let autoCompleteLabel = NSTextField(labelWithString: "")
    private let autoCompleteField = NSTextField(string: "3")
    private let autoCompleteStepper = NSStepper()
    private let autoCompleteModeLabel = NSTextField(labelWithString: "")
    private let autoCompleteModePopup = NSPopUpButton()
    private let autoCompleteChooseSingleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteTABFillupButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteEnterCommitButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteBriefButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteIgnoreCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let htmlXmlCloseTagButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let muteAllSoundsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let trimTrailingSpacesOnSaveButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let pasteConvertEndingsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smoothFontButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let multiEditEnabledButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let multiPasteModeLabel = NSTextField(labelWithString: "")
    private let multiPasteModePopup = NSPopUpButton()
    private let indentGuideModeLabel = NSTextField(labelWithString: "")
    private let indentGuideModePopup = NSPopUpButton()
    private let wordWrapModeLabel = NSTextField(labelWithString: "")
    private let wordWrapModePopup = NSPopUpButton()
    // Multi-select appearance
    private let additionalSelAlphaLabel = NSTextField(labelWithString: "")
    private let additionalSelAlphaField = NSTextField(string: "256")
    private let additionalSelAlphaStepper = NSStepper()
    private let additionalCaretsBlinkButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let additionalCaretsVisibleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let caretLineVisibleAlwaysButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Whitespace & selection display
    private let whitespaceSizeLabel = NSTextField(labelWithString: "")
    private let whitespaceSizeField = NSTextField(string: "1")
    private let whitespaceSizeStepper = NSStepper()
    private let selectionAlphaLabel = NSTextField(labelWithString: "")
    private let selectionAlphaField = NSTextField(string: "256")
    private let selectionAlphaStepper = NSStepper()
    private let controlCharDisplayLabel = NSTextField(labelWithString: "")
    private let controlCharDisplayPopup = NSPopUpButton()
    private let linePaddingLabel = NSTextField(labelWithString: "")
    private let linePaddingSegmented = NSSegmentedControl()
    private let largeFileSectionLabel = NSTextField(labelWithString: "")
    private let largeFileMBLabel = NSTextField(labelWithString: "")
    private let largeFileMBField = NSTextField(string: "50")
    private let largeFileMBStepper = NSStepper()
    private let largeFileSuppressAutoCompleteButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let largeFileSuppressSmartHighlightButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let largeFileSuppressBraceMatchButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let largeFileSuppressWordWrapButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let largeFileSuppressSyntaxHighlightButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let newDocEncodingPopup = NSPopUpButton()
    private let newDocLineEndingPopup = NSPopUpButton()
    private let searchMatchCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let searchWholeWordButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dateTimeFormatField = NSTextField(string: "")
    private let searchEnginePopup = NSPopUpButton()
    private let searchEngineCustomURLField = NSTextField(string: "")
    private let extraURLSchemesLabel = NSTextField(labelWithString: "")
    private let extraURLSchemesField = NSTextField(string: "")
    // Find & Tools tab extras
    private let inSelectionSectionLabel = NSTextField(labelWithString: "")
    private let inSelectionThresholdLabel = NSTextField(labelWithString: "")
    private let inSelectionThresholdField = NSTextField(string: "1024")
    private let inSelectionThresholdStepper = NSStepper()
    private let keepFindDialogOpenButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let replaceDoesNotMoveButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let findDialogMonospaceButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fillFindFromSelectionButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoSelectWordUnderCaretButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let findInFilesIgnoreUnsavedButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let confirmReplaceInAllDocsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let maxFindHistoryLabel = NSTextField(labelWithString: "")
    private let maxFindHistoryField = NSTextField(string: "")
    private let maxFindHistoryStepper = NSStepper()
    private let findTransparencyLabel = NSTextField(labelWithString: "")
    private let findTransparencySlider = NSSlider()
    // File change detection (in Session & Files tab)
    private let fileChangeDetectionButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Copy/cut line behavior (in Editor tab)
    private let copyLineWithoutSelectionButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Smart highlight settings (in Editor tab)
    private let smartHighlightUseFindSettingsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // URL indicator style (in Editor tab)
    private let urlIndicatorStyleLabel = NSTextField(labelWithString: "")
    private let urlIndicatorStyleSegmented = NSSegmentedControl()
    // Per-language tab overrides (in Editor tab)
    private let langTabOverridesLabel = NSTextField(labelWithString: "")
    private let langTabOverridesField = NSTextField(string: "")
    // Task List custom tags (in Editor tab)
    private let taskListTagsLabel = NSTextField(labelWithString: "")
    private let taskListTagsField = NSTextField(string: "")
    // Tabbar section (in Window tab)
    private let tabbarSectionLabel = NSTextField(labelWithString: "")
    private let tabbarHideButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarDoubleClickCloseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarLockDragDropButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarExitOnLastTabButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarShowCloseButtonButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarCompactButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarShowIndexNumbersButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let toolbarIconSizeLabel = NSTextField(labelWithString: "")
    private let toolbarIconSizeSegmented = NSSegmentedControl()
    private let scintillaRenderingLabel = NSTextField(labelWithString: "")
    private let scintillaRenderingPopup = NSPopUpButton()
    private let disableAdvancedScrollingButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rightClickKeepSelectionButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let edgeModeLabel = NSTextField(labelWithString: "")
    private let edgeModePopup = NSPopUpButton()
    private let foldFlagsLabel = NSTextField(labelWithString: "")
    private let foldFlagsPopup = NSPopUpButton()
    private let foldCompactButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let showDocSwitcherButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let perLineResultButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarMaxLabelLengthLabel = NSTextField(labelWithString: "")
    private let tabbarMaxLabelLengthField = NSTextField(string: "0")
    private let tabbarMaxLabelLengthStepper = NSStepper()
    // Appearance (Dark Mode) section in Window tab
    private let appearanceSectionLabel = NSTextField(labelWithString: "")
    private let appearanceModeLabel = NSTextField(labelWithString: "")
    private let appearanceModeSegmented = NSSegmentedControl()
    // Post-It Mode section in Window tab
    private let postItSectionLabel = NSTextField(labelWithString: "")
    private let postItAlphaLabel = NSTextField(labelWithString: "")
    private let postItAlphaSlider = NSSlider()

    typealias LanguageEntry = (name: String, displayName: String)
    private var languageEntries: [LanguageEntry] = []

    init(
        preferencesStore: PreferencesStore,
        localizationOptions: [AppLocalizationOption],
        languageEntries: [LanguageEntry] = [],
        onChange: @escaping (AppPreferences) -> Void
    ) {
        self.preferencesStore = preferencesStore
        self.localizationOptions = localizationOptions
        self.languageEntries = languageEntries
        self.onChange = onChange

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 440, height: 480)

        super.init(window: panel)
        configureContent()
        refreshLocalizedStrings()
        loadPreferences()
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
        loadPreferences()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshLocalizedStrings() {
        window?.title = Localization.string(.preferencesPanelTitle)

        localizationSectionLabel.stringValue = Localization.string(.preferencesLocalizationSection)
        localizationChoiceLabel.stringValue = Localization.string(.preferencesLocalization)
        editorSectionLabel.stringValue = Localization.string(.preferencesEditorSection)
        fontSizeLabel.stringValue = Localization.string(.preferencesFontSize)
        editorFontNameLabel.stringValue = "Font name:"
        editorFontBoldButton.title = "Bold"
        findDefaultsSectionLabel.stringValue = Localization.string(.preferencesFindDefaults)
        dateTimeSectionLabel.stringValue = Localization.string(.preferencesDateTimeSection)
        dateTimeFormatLabel.stringValue = Localization.string(.preferencesDateTimeFormat)
        searchEngineSectionLabel.stringValue = Localization.string(.preferencesSearchEngineSection)
        searchEngineChoiceLabel.stringValue = Localization.string(.preferencesSearchEngine)
        searchEngineCustomURLLabel.stringValue = Localization.string(.preferencesSearchEngineCustomURL)
        extraURLSchemesLabel.stringValue = Localization.string(.preferencesExtraURLSchemes, default: "Extra URL schemes:")

        wrapsLinesButton.title = Localization.string(.preferencesWrapLines)
        tabSizeLabel.stringValue = Localization.string(.preferencesTabSize)
        insertSpacesButton.title = Localization.string(.preferencesInsertSpaces)
        editorFeaturesSectionLabel.stringValue = Localization.string(.preferencesEditorFeaturesSection, default: "Editor Features")
        autoPairButton.title = Localization.string(.preferencesAutoPair, default: "Auto-insert matching pairs")
        autoPairParenthesesButton.title = "  ( ) Parentheses"
        autoPairBracketsButton.title = "  [ ] Brackets"
        autoPairCurlyBracketsButton.title = "  { } Curly brackets"
        autoPairSingleQuotesButton.title = "  ' ' Single quotes"
        autoPairDoubleQuotesButton.title = "  \" \" Double quotes"
        customPairsAddButton.bezelStyle = .smallSquare
        customPairsAddButton.target = self
        customPairsAddButton.action = #selector(addCustomPair(_:))
        customPairsRemoveButton.bezelStyle = .smallSquare
        customPairsRemoveButton.target = self
        customPairsRemoveButton.action = #selector(removeCustomPair(_:))
        let openCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Open"))
        openCol.title = "Open"
        openCol.width = 50
        openCol.isEditable = true
        let closeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Close"))
        closeCol.title = "Close"
        closeCol.width = 50
        closeCol.isEditable = true
        customPairsTableView.addTableColumn(openCol)
        customPairsTableView.addTableColumn(closeCol)
        customPairsTableView.delegate = self
        customPairsTableView.dataSource = self
        customPairsTableView.rowSizeStyle = .small
        customPairsScrollView.documentView = customPairsTableView
        customPairsScrollView.hasVerticalScroller = true
        customPairsScrollView.borderType = .bezelBorder
        xmlTagMatchButton.title = Localization.string(.preferencesXmlTagMatch, default: "Highlight matching XML tags")
        clickableLinksButton.title = Localization.string(.preferencesClickableLinks, default: "Highlight clickable links")
        smartHighlightMatchCaseButton.title = Localization.string(.preferencesSmartHighlightMatchCase, default: "Smart highlight: match case")
        smartHighlightWholeWordButton.title = Localization.string(.preferencesSmartHighlightWholeWord, default: "Smart highlight: whole word only")
        markAllMatchCaseButton.title = "Mark All: match case"
        markAllWholeWordButton.title = "Mark All: whole word only"
        langMenuCompactButton.title = "Compact Language menu (hide rarely-used entries)"
        caretWidthLabel.stringValue = Localization.string(.preferencesCaretWidth, default: "Caret width:")
        if caretWidthSegmented.segmentCount == 3 {
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthThin, default: "Thin"), forSegment: 0)
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthMedium, default: "Medium"), forSegment: 1)
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthThick, default: "Thick"), forSegment: 2)
        }
        caretNoBlinkButton.title = Localization.string(.preferencesCaretNoBlink, default: "Disable caret blinking")
        caretBlinkRateLabel.stringValue = "Blink rate (ms):"
        caretBlinkRateField.placeholderString = "100-2000"
        caretBlinkRateStepper.minValue = 100
        caretBlinkRateStepper.maxValue = 2000
        caretBlinkRateStepper.increment = 50
        caretStickyModeLabel.stringValue = "Caret sticky mode:"
        currentLineFrameLabel.stringValue = Localization.string(.preferencesCurrentLineFrame, default: "Current line highlight:")
        if currentLineFrameSegmented.segmentCount == 4 {
            currentLineFrameSegmented.setLabel(Localization.string(.preferencesCurrentLineFrameFill, default: "Fill"), forSegment: 0)
            currentLineFrameSegmented.setLabel("1px", forSegment: 1)
            currentLineFrameSegmented.setLabel("2px", forSegment: 2)
            currentLineFrameSegmented.setLabel("3px", forSegment: 3)
        }
        lineWrapIndentLabel.stringValue = Localization.string(.preferencesLineWrapIndent, default: "Wrap indent:")
        enableCodeFoldingButton.title = "Enable code folding"
        foldMarginStyleLabel.stringValue = Localization.string(.preferencesFoldMarginStyle, default: "Fold margin style:")
        virtualSpaceButton.title = Localization.string(.preferencesVirtualSpace, default: "Enable virtual space")
        backspaceUnindentsButton.title = Localization.string(.preferencesBackspaceUnindents, default: "Backspace key unindents")
        autoIndentButton.title = Localization.string(.preferencesAutoIndent, default: "Auto-indent new lines")
        autoIndentModeLabel.stringValue = "Auto-indent mode:"
        autoIndentModePopup.removeAllItems()
        autoIndentModePopup.addItems(withTitles: ["None", "Basic", "Advanced (bracket-aware)"])
        fileAutoDetectionLabel.stringValue = "File change detection:"
        fileAutoDetectionPopup.removeAllItems()
        fileAutoDetectionPopup.addItems(withTitles: ["Disabled", "On tab activate", "Real-time monitoring"])
        updateSilentlyButton.title = "Auto-reload changed files without confirmation"
        zoomSyncToAllTabsButton.title = "Sync zoom level to all tabs when zooming"
        hideMenuShortcutsButton.title = "Hide keyboard shortcuts in menu items"
        scrollToLastLineOnMonitorReloadButton.title = "Scroll to last line after monitoring reload"
        scrollBeyondLastLineButton.title = Localization.string(.preferencesScrollBeyondLastLine, default: "Scroll beyond last line")
        selectedTextDragDropButton.title = "Allow dragging selected text within editor"
        lineNumberDynamicWidthButton.title = "Dynamic line number margin width"
        columnSelectionToMultiEditingButton.title = "Column selection converts to multi-cursor editing"
        showBookmarkMarginButton.title = "Show bookmark margin"
        showEdgeLineButton.title = "Show edge line"
        displayDefaultsSectionLabel.stringValue = "Display Defaults"
        showLineNumberMarginButton.title = "Show line number margin"
        showWhitespaceButton.title = "Show whitespace"
        whitespaceDisplayModeLabel.stringValue = "Whitespace mode:"
        whitespaceDisplayModePopup.removeAllItems()
        whitespaceDisplayModePopup.addItems(withTitles: ["Don't show", "Always", "After indent", "Only in indent"])
        bidiModeLabel.stringValue = "Text direction:"
        bidiModePopup.removeAllItems()
        bidiModePopup.addItems(withTitles: ["Default", "Left to right", "Right to left"])
        showEOLButton.title = "Show EOL characters"
        showIndentGuidesButton.title = "Show indent guides"
        highlightCurrentLineButton.title = "Highlight current line"
        showNpcCharactersButton.title = "Show non-printable characters"
        showWrapSymbolButton.title = "Show wrap symbol"
        showChangeHistoryButton.title = "Show change history margin"
        edgeLineColumnLabel.stringValue = "Edge column:"
        edgeLineColumnField.stringValue = "80"
        edgeLineColumnField.isEditable = true
        edgeLineColumnField.isBordered = true
        edgeLineColumnField.bezelStyle = .roundedBezel
        edgeLineColumnStepper.minValue = 1
        edgeLineColumnStepper.maxValue = 999
        edgeLineColumnStepper.increment = 1
        edgeLineColumnStepper.valueWraps = false
        linePaddingLabel.stringValue = Localization.string(.preferencesLinePadding, default: "Line padding:")
        autoCompleteLabel.stringValue = Localization.string(.preferencesAutoCompleteFrom, default: "Auto-complete from Nth character (0=off):")
        largeFileSectionLabel.stringValue = Localization.string(.preferencesLargeFileSection, default: "Large File")
        largeFileMBLabel.stringValue = Localization.string(.preferencesLargeFileMB, default: "Large file threshold (MB):")
        largeFileSuppressAutoCompleteButton.title = Localization.string(.preferencesLargeFileSuppressAutoComplete, default: "Disable auto-complete for large files")
        largeFileSuppressSmartHighlightButton.title = Localization.string(.preferencesLargeFileSuppressSmartHighlight, default: "Disable smart highlighting for large files")
        largeFileSuppressBraceMatchButton.title = Localization.string(.preferencesLargeFileSuppressBraceMatch, default: "Disable brace matching for large files")
        largeFileSuppressWordWrapButton.title = Localization.string(.preferencesLargeFileSuppressWordWrap, default: "Disable word wrap for large files")
        largeFileSuppressSyntaxHighlightButton.title = Localization.string(.preferencesLargeFileSuppressSyntaxHighlight, default: "Disable syntax highlighting for large files")
        newDocumentSectionLabel.stringValue = Localization.string(.preferencesNewDocumentSection, default: "New Document")
        newDocEncodingLabel.stringValue = Localization.string(.preferencesNewDocEncoding, default: "Encoding:")
        newDocLineEndingLabel.stringValue = Localization.string(.preferencesNewDocLineEnding, default: "Line Ending:")
        rememberSessionButton.title = Localization.string(.preferencesRememberSession, default: "Remember last session on launch")
        newDocumentOnLaunchButton.title = "Create a new document on launch when session is empty"
        useFirstLineAsTabNameButton.title = "Use first line as tab name for untitled files"
        recentFilesMaxLabel.stringValue = "Max recent files:"
        noCheckRecentAtLaunchButton.title = "Don't check recent files at launch"
        keepAbsentFilesButton.title = "Keep absent files in session"
        autoReloadButton.title = "Auto-reload file when changed externally"
        fileChangeDetectionButton.title = "Enable file change detection (monitor for external changes)"
        snapshotModeButton.title = "Enable session snapshot and periodic backup"
        periodicBackupLabel.stringValue = "Periodic backup interval (seconds):"
        backupOnSaveLabel.stringValue = "Backup on save:"
        useCustomBackupDirButton.title = "Use custom backup directory"
        customBackupDirBrowseButton.title = Localization.string(.findInFilesBrowse, default: "Browse...")
        populateBackupOnSavePopup()
        autoCompleteModeLabel.stringValue = "Auto-complete source:"
        autoCompleteChooseSingleButton.title = "Auto-accept when only one match"
        autoCompleteTABFillupButton.title = "Tab key commits auto-complete selection"
        autoCompleteEnterCommitButton.title = "Enter key also commits auto-complete selection"
        autoCompleteBriefButton.title = "Brief mode (hide function prototypes in list)"
        autoCompleteIgnoreCaseButton.title = "Ignore case when matching completions"
        htmlXmlCloseTagButton.title = "Auto-close HTML/XML tags when typing '>'"
        muteAllSoundsButton.title = "Mute all sounds"
        trimTrailingSpacesOnSaveButton.title = "Trim trailing whitespace on save"
        pasteConvertEndingsButton.title = "Convert line endings when pasting"
        smoothFontButton.title = "Smooth font rendering (antialiased)"
        multiEditEnabledButton.title = "Enable multiple selections"
        multiPasteModeLabel.stringValue = "Multi-paste mode:"
        multiPasteModePopup.removeAllItems()
        multiPasteModePopup.addItems(withTitles: ["Paste once (main selection)", "Paste into each selection"])
        indentGuideModeLabel.stringValue = "Indent guide mode:"
        indentGuideModePopup.removeAllItems()
        indentGuideModePopup.addItems(withTitles: ["None", "Real", "Look forward", "Look both"])
        wordWrapModeLabel.stringValue = "Word wrap mode:"
        wordWrapModePopup.removeAllItems()
        wordWrapModePopup.addItems(withTitles: ["None", "Word", "Whitespace", "Character"])
        additionalSelAlphaLabel.stringValue = "Additional selection alpha:"
        additionalSelAlphaField.formatter = integerFormatter
        whitespaceSizeField.formatter = integerFormatter
        selectionAlphaField.formatter = integerFormatter
        additionalSelAlphaStepper.minValue = 0
        additionalSelAlphaStepper.maxValue = 256
        additionalSelAlphaStepper.increment = 16
        additionalSelAlphaStepper.valueWraps = false
        additionalCaretsBlinkButton.title = "Additional carets blink"
        additionalCaretsVisibleButton.title = "Show additional carets"
        caretLineVisibleAlwaysButton.title = "Highlight current line when unfocused"
        whitespaceSizeLabel.stringValue = "Whitespace dot size (px):"
        whitespaceSizeStepper.minValue = 1
        whitespaceSizeStepper.maxValue = 5
        whitespaceSizeStepper.increment = 1
        whitespaceSizeStepper.valueWraps = false
        selectionAlphaLabel.stringValue = "Selection alpha:"
        selectionAlphaStepper.minValue = 0
        selectionAlphaStepper.maxValue = 256
        selectionAlphaStepper.increment = 16
        selectionAlphaStepper.valueWraps = false
        controlCharDisplayLabel.stringValue = "Control char display:"
        controlCharDisplayPopup.removeAllItems()
        controlCharDisplayPopup.addItems(withTitles: ["Show as glyph", "Arrow", "Dot", "Small circle", "Large circle", "Space", "Nbsp"])
        inSelectionSectionLabel.stringValue = "In-Selection Search"
        inSelectionThresholdLabel.stringValue = "Auto-check In Selection threshold (chars):"
        keepFindDialogOpenButton.title = "Keep Find dialog open after Replace All"
        replaceDoesNotMoveButton.title = "After Replace, don't move caret to replaced range"
        findDialogMonospaceButton.title = "Use monospaced font in Find / Replace fields"
        fillFindFromSelectionButton.title = "Fill Find field with selected text when opening Find dialog"
        autoSelectWordUnderCaretButton.title = "Auto-select word under caret when no selection"
        findInFilesIgnoreUnsavedButton.title = "Find in Files: ignore unsaved changes in open documents"
        confirmReplaceInAllDocsButton.title = "Confirm before Replace All in Open Documents"
        maxFindHistoryLabel.stringValue = "Max find/replace history:"
        copyLineWithoutSelectionButton.title = "Copy / Cut whole line when nothing is selected"
        smartHighlightUseFindSettingsButton.title = "Smart highlight uses Find dialog Match Case / Whole Word settings"
        urlIndicatorStyleLabel.stringValue = "URL style:"
        langTabOverridesLabel.stringValue = "Lang tabs:"
        langTabOverridesField.placeholderString = "python:4s, html:2s, c:8t  (langname:sizeS/T)"
        taskListTagsLabel.stringValue = "Task List tags:"
        taskListTagsField.placeholderString = "TODO, FIXME, NOTE, HACK, BUG, XXX"
        findTransparencyLabel.stringValue = "Find dialog transparency when unfocused:"
        tabbarSectionLabel.stringValue = "Tab Bar"
        tabbarHideButton.title = "Hide tab bar"
        tabbarDoubleClickCloseButton.title = "Double-click tab to close"
        tabbarLockDragDropButton.title = "Lock tab bar (disable drag-drop reordering)"
        tabbarShowCloseButtonButton.title = "Show close button on tabs"
        tabbarCompactButton.title = "Compact (reduced) tab bar"
        tabbarShowIndexNumbersButton.title = "Show tab index numbers (1-9)"
        toolbarIconSizeLabel.stringValue = "Toolbar icon size:"
        scintillaRenderingLabel.stringValue = "Scintilla rendering:"
        disableAdvancedScrollingButton.title = "Disable advanced scrolling"
        rightClickKeepSelectionButton.title = "Keep selection on right-click"
        edgeModeLabel.stringValue = "Edge line style:"
        foldFlagsLabel.stringValue = "Fold indicators:"
        foldCompactButton.title = "Compact fold (no extra lines around folded regions)"
        showDocSwitcherButton.title = "Show document switcher on Ctrl+Tab"
        perLineResultButton.title = "Show only one result per line in Find in Files"
        tabbarExitOnLastTabButton.title = "Exit app when last tab is closed"
        tabbarMaxLabelLengthLabel.stringValue = "Max tab label length (0 = unlimited):"
        printSectionLabel.stringValue = "Print"
        printHeaderSectionLabel.stringValue = "Header (Left / Center / Right):"
        printFooterSectionLabel.stringValue = "Footer (Left / Center / Right):"
        printColorModeLabel.stringValue = "Color:"
        printFontSizeLabel.stringValue = "Font size (0=auto):"
        delimiterSectionLabel.stringValue = "Delimiter"
        delimiterLeftLabel.stringValue = "Left char (empty=whitespace):"
        delimiterRightLabel.stringValue = "Right char:"
        appearanceSectionLabel.stringValue = "Appearance"
        appearanceModeLabel.stringValue = "Color mode:"
        appearanceModeSegmented.setLabel("System", forSegment: 0)
        appearanceModeSegmented.setLabel("Light", forSegment: 1)
        appearanceModeSegmented.setLabel("Dark", forSegment: 2)
        postItSectionLabel.stringValue = "Post-It Mode"
        postItAlphaLabel.stringValue = "Window opacity:"
        postItAlphaSlider.minValue = 0.2
        postItAlphaSlider.maxValue = 1.0
        postItAlphaSlider.isContinuous = true
        postItAlphaSlider.target = self
        postItAlphaSlider.action = #selector(controlChanged(_:))
        generalSectionLabel.stringValue = "General"
        statusBarVisibleButton.title = "Show status bar"
        shortTitleButton.title = "Short title (filename only in title bar)"
        saveAllConfirmButton.title = "Confirm before Save All"
        autoCompleteIgnoreNumbersButton.title = "Auto-complete: ignore words starting with digits"
        reloadScrollToLastCaretButton.title = "Scroll to last caret position after external file reload"
        openAnsiAsUtf8Button.title = "Open ANSI files as UTF-8 (auto-reinterpret ANSI/Windows encodings as UTF-8)"
        xmlTagAttributeHighlightButton.title = "Highlight tag attributes in XML/HTML matching"
        highlightNonHtmlZoneButton.title = "Apply XML tag matching in non-HTML/PHP/ASP zones"
        defaultSaveDirLabel.stringValue = "Default save directory (empty = system default):"
        printLineNumbersButton.title = "Print line numbers"
        openDirFollowsDocButton.title = Localization.string(.preferencesOpenDirFollowsDoc, default: "Open dialog starts in the current document's directory")
        folderDropAsWorkspaceButton.title = Localization.string(.preferencesFolderDropAsWorkspace, default: "Open dropped folder as workspace")
        folderDropRecursiveOpenButton.title = "Recursively open all files when dropping a folder"
        defaultLangLabel.stringValue = Localization.string(.preferencesDefaultLanguage, default: "Default language for new documents:")
        additionalEdgeColumnsLabel.stringValue = "Extra vertical edges (columns):"
        recentFilesShowFullPathButton.title = "Show full path in recent files menu"
        recentFilesInSubmenuButton.title = "Show recent files in a submenu"
        recentFilesCustomLengthLabel.stringValue = "Path display length (0=full):"
        populateNewDocEncodingPopup(selected: preferencesStore.load().defaultNewDocumentEncoding)
        populateNewDocLineEndingPopup(selected: preferencesStore.load().defaultNewDocumentLineEnding)
        populateDefaultLangPopup(selected: preferencesStore.load().defaultNewDocumentLanguageName)
        searchMatchCaseButton.title = Localization.string(.preferencesMatchCase)
        searchWholeWordButton.title = Localization.string(.preferencesWholeWord)

        localizationPopup.setAccessibilityLabel(
            Localization.string(.preferencesLocalizationPopupAccessibilityLabel)
        )
        fontSizeField.setAccessibilityLabel(Localization.string(.preferencesFontSizeFieldAccessibilityLabel))
        fontSizeStepper.setAccessibilityLabel(Localization.string(.preferencesFontSizeStepperAccessibilityLabel))
        dateTimeFormatField.setAccessibilityLabel(Localization.string(.preferencesDateTimeFormatFieldAccessibilityLabel))
        searchEnginePopup.setAccessibilityLabel(Localization.string(.preferencesSearchEnginePopupAccessibilityLabel))
        searchEngineCustomURLField.setAccessibilityLabel(Localization.string(.preferencesSearchEngineCustomURLFieldAccessibilityLabel))

        let selectedSearchEngine = selectedSearchEngineChoice
        configureSearchEnginePopup()
        selectSearchEngine(selectedSearchEngine)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
        loadPreferences()
    }

    @objc private func controlChanged(_ sender: Any?) {
        savePreferences(sender: sender)
    }

    private func makeTabScrollContent() -> (NSScrollView, NSView) {
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        let cv = NSView()
        cv.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = cv
        NSLayoutConstraint.activate([
            cv.leadingAnchor.constraint(equalTo: sv.contentView.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: sv.contentView.trailingAnchor),
            cv.topAnchor.constraint(equalTo: sv.contentView.topAnchor),
            cv.widthAnchor.constraint(equalTo: sv.contentView.widthAnchor)
        ])
        return (sv, cv)
    }

    private func configureContent() {
        guard let outerView = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        outerView.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: outerView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: outerView.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: outerView.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: outerView.bottomAnchor)
        ])

        let (editSV, editCV) = makeTabScrollContent()
        let (sessionSV, sessionCV) = makeTabScrollContent()
        let (toolsSV, toolsCV) = makeTabScrollContent()
        let (windowSV, windowCV) = makeTabScrollContent()  // windowCV used in Tab 4 layout

        let editorTab = NSTabViewItem(); editorTab.label = "Editor"; editorTab.view = editSV
        let sessionTab = NSTabViewItem(); sessionTab.label = "Session & Files"; sessionTab.view = sessionSV
        let toolsTab = NSTabViewItem(); toolsTab.label = "Find & Tools"; toolsTab.view = toolsSV
        let windowTab = NSTabViewItem(); windowTab.label = "Window"; windowTab.view = windowSV
        tabView.addTabViewItem(editorTab)
        tabView.addTabViewItem(sessionTab)
        tabView.addTabViewItem(toolsTab)
        tabView.addTabViewItem(windowTab)

        fontSizeStepper.minValue = AppPreferences.minimumEditorFontSize
        fontSizeStepper.maxValue = AppPreferences.maximumEditorFontSize
        fontSizeStepper.increment = 1

        tabSizeStepper.minValue = 1
        tabSizeStepper.maxValue = 8
        tabSizeStepper.increment = 1

        [localizationPopup, fontSizeField, fontSizeStepper, wrapsLinesButton, tabSizeField, tabSizeStepper, insertSpacesButton, autoPairButton, xmlTagMatchButton, clickableLinksButton, smartHighlightMatchCaseButton, smartHighlightWholeWordButton, caretWidthSegmented, caretNoBlinkButton, currentLineFrameSegmented, lineWrapIndentPopup, enableCodeFoldingButton, foldMarginStylePopup, virtualSpaceButton, backspaceUnindentsButton, autoIndentButton, scrollBeyondLastLineButton, linePaddingSegmented, autoCompleteField, autoCompleteStepper, autoCompleteModePopup, autoCompleteChooseSingleButton, autoCompleteTABFillupButton, autoCompleteIgnoreCaseButton, additionalEdgeColumnsField, largeFileMBField, largeFileMBStepper, rememberSessionButton, newDocumentOnLaunchButton, useFirstLineAsTabNameButton, recentFilesMaxField, recentFilesMaxStepper, recentFilesShowFullPathButton, noCheckRecentAtLaunchButton, keepAbsentFilesButton, autoReloadButton, snapshotModeButton, periodicBackupLabel, periodicBackupField, periodicBackupStepper, backupOnSaveLabel, backupOnSavePopup, useCustomBackupDirButton, customBackupDirField, customBackupDirBrowseButton, printLineNumbersButton, openDirFollowsDocButton, folderDropAsWorkspaceButton, defaultLangPopup, newDocEncodingPopup, newDocLineEndingPopup, searchMatchCaseButton, searchWholeWordButton, dateTimeFormatField, searchEnginePopup, searchEngineCustomURLField, extraURLSchemesField, inSelectionThresholdField, inSelectionThresholdStepper, keepFindDialogOpenButton, replaceDoesNotMoveButton, findDialogMonospaceButton, fillFindFromSelectionButton, autoSelectWordUnderCaretButton, findInFilesIgnoreUnsavedButton, confirmReplaceInAllDocsButton, maxFindHistoryField, maxFindHistoryStepper, findTransparencySlider, fileChangeDetectionButton, copyLineWithoutSelectionButton, smartHighlightUseFindSettingsButton, urlIndicatorStyleSegmented, langTabOverridesField, tabbarHideButton, tabbarDoubleClickCloseButton, tabbarLockDragDropButton, tabbarMaxLabelLengthField, tabbarMaxLabelLengthStepper, statusBarVisibleButton, shortTitleButton, saveAllConfirmButton, autoCompleteIgnoreNumbersButton, reloadScrollToLastCaretButton, editorFontNameField, editorFontBoldButton, tabbarShowCloseButtonButton, caretBlinkRateField, caretBlinkRateStepper,
         whitespaceDisplayModePopup, bidiModePopup, caretStickyModePopup, trimTrailingSpacesOnSaveButton, pasteConvertEndingsButton, smoothFontButton, multiEditEnabledButton, multiPasteModePopup, indentGuideModePopup, wordWrapModePopup, additionalSelAlphaField, additionalSelAlphaStepper, additionalCaretsBlinkButton, additionalCaretsVisibleButton, caretLineVisibleAlwaysButton, whitespaceSizeField, whitespaceSizeStepper, selectionAlphaField, selectionAlphaStepper, controlCharDisplayPopup, autoIndentModePopup, fileAutoDetectionPopup, updateSilentlyButton, zoomSyncToAllTabsButton, hideMenuShortcutsButton, scrollToLastLineOnMonitorReloadButton, printHeaderLeftField, printHeaderCenterField, printHeaderRightField, printFooterLeftField, printFooterCenterField, printFooterRightField, printColorModePopup, printFontSizeField, printFontSizeStepper,
         printMarginTopField, printMarginBottomField, printMarginLeftField, printMarginRightField,
         delimiterLeftField, delimiterRightField,
         openAnsiAsUtf8Button, xmlTagAttributeHighlightButton, highlightNonHtmlZoneButton, defaultSaveDirField,
         toolbarIconSizeSegmented, scintillaRenderingPopup, disableAdvancedScrollingButton, rightClickKeepSelectionButton,
         edgeModePopup, foldFlagsPopup, foldCompactButton, showDocSwitcherButton, perLineResultButton].forEach {
            $0.target = self
            $0.action = #selector(controlChanged(_:))
        }
        autoCompleteStepper.minValue = 0
        autoCompleteStepper.maxValue = 20
        autoCompleteStepper.increment = 1
        autoCompleteField.formatter = integerFormatter
        autoCompleteModePopup.removeAllItems()
        autoCompleteModePopup.addItems(withTitles: ["Disabled", "Function API only", "Document words only", "Function + words (default)"])
        printColorModePopup.removeAllItems()
        printColorModePopup.addItems(withTitles: ["Color (as displayed)", "Force black text"])
        printFontSizeStepper.minValue = 0
        printFontSizeStepper.maxValue = 32
        printFontSizeStepper.increment = 1
        printFontSizeField.formatter = integerFormatter
        printMarginsLabel.stringValue = "Margins (pt):"
        printMarginTopLabel.stringValue = "Top:"
        printMarginBottomLabel.stringValue = "Bottom:"
        printMarginLeftLabel.stringValue = "Left:"
        printMarginRightLabel.stringValue = "Right:"
        for field in [printMarginTopField, printMarginBottomField, printMarginLeftField, printMarginRightField] {
            field.formatter = integerFormatter
        }
        inSelectionThresholdStepper.minValue = 1
        inSelectionThresholdStepper.maxValue = 10000
        inSelectionThresholdStepper.increment = 64
        inSelectionThresholdField.formatter = integerFormatter
        maxFindHistoryStepper.minValue = 1
        maxFindHistoryStepper.maxValue = 50
        maxFindHistoryStepper.increment = 1
        maxFindHistoryField.formatter = integerFormatter
        tabbarMaxLabelLengthStepper.minValue = 0
        tabbarMaxLabelLengthStepper.maxValue = 200
        tabbarMaxLabelLengthStepper.increment = 5
        tabbarMaxLabelLengthField.formatter = integerFormatter
        findTransparencySlider.minValue = 0
        findTransparencySlider.maxValue = 0.9
        findTransparencySlider.numberOfTickMarks = 10
        findTransparencySlider.allowsTickMarkValuesOnly = false
        largeFileMBStepper.minValue = Double(AppPreferences.minimumLargeFileMB)
        largeFileMBStepper.maxValue = Double(AppPreferences.maximumLargeFileMB)
        largeFileMBStepper.increment = 10
        largeFileMBField.formatter = integerFormatter
        largeFileSuppressAutoCompleteButton.target = self
        largeFileSuppressAutoCompleteButton.action = #selector(controlChanged(_:))
        largeFileSuppressSmartHighlightButton.target = self
        largeFileSuppressSmartHighlightButton.action = #selector(controlChanged(_:))
        largeFileSuppressBraceMatchButton.target = self
        largeFileSuppressBraceMatchButton.action = #selector(controlChanged(_:))
        largeFileSuppressWordWrapButton.target = self
        largeFileSuppressWordWrapButton.action = #selector(controlChanged(_:))
        largeFileSuppressSyntaxHighlightButton.target = self
        largeFileSuppressSyntaxHighlightButton.action = #selector(controlChanged(_:))
        caretWidthSegmented.segmentCount = 3
        caretWidthSegmented.setLabel("Thin", forSegment: 0)
        caretWidthSegmented.setLabel("Medium", forSegment: 1)
        caretWidthSegmented.setLabel("Thick", forSegment: 2)
        caretWidthSegmented.trackingMode = .selectOne

        caretStickyModePopup.removeAllItems()
        caretStickyModePopup.addItems(withTitles: ["Disabled", "Enabled", "Enabled for whitespace"])

        currentLineFrameSegmented.segmentCount = 4
        currentLineFrameSegmented.setLabel("Fill", forSegment: 0)
        currentLineFrameSegmented.setLabel("1px", forSegment: 1)
        currentLineFrameSegmented.setLabel("2px", forSegment: 2)
        currentLineFrameSegmented.setLabel("3px", forSegment: 3)
        currentLineFrameSegmented.trackingMode = .selectOne

        lineWrapIndentPopup.removeAllItems()
        lineWrapIndentPopup.addItems(withTitles: ["Fixed", "Same indent", "Indent", "Deep indent"])

        foldMarginStylePopup.removeAllItems()
        foldMarginStylePopup.addItems(withTitles: ["Simple arrows", "Box tree", "Circle tree"])

        edgeLineColumnField.formatter = integerFormatter
        edgeLineColumnStepper.target = self
        edgeLineColumnStepper.action = #selector(controlChanged(_:))

        linePaddingSegmented.segmentCount = 6
        for i in 0...5 { linePaddingSegmented.setLabel("\(i)px", forSegment: i) }
        linePaddingSegmented.trackingMode = .selectOne

        urlIndicatorStyleSegmented.segmentCount = 3
        urlIndicatorStyleSegmented.setLabel("Underline", forSegment: 0)
        urlIndicatorStyleSegmented.setLabel("Box", forSegment: 1)
        urlIndicatorStyleSegmented.setLabel("Full Box", forSegment: 2)
        urlIndicatorStyleSegmented.trackingMode = .selectOne

        appearanceModeSegmented.segmentCount = 3
        appearanceModeSegmented.trackingMode = .selectOne

        toolbarIconSizeSegmented.segmentCount = 2
        toolbarIconSizeSegmented.setLabel("Regular", forSegment: 0)
        toolbarIconSizeSegmented.setLabel("Small", forSegment: 1)
        toolbarIconSizeSegmented.trackingMode = .selectOne

        scintillaRenderingPopup.removeAllItems()
        scintillaRenderingPopup.addItems(withTitles: ["Default", "Direct (better quality)"])

        edgeModePopup.removeAllItems()
        edgeModePopup.addItems(withTitles: ["None", "Line", "Background highlight"])

        foldFlagsPopup.removeAllItems()
        foldFlagsPopup.addItems(withTitles: ["None", "Line before expanded", "Line before contracted", "Line after expanded", "Line after contracted"])

        recentFilesMaxField.formatter = integerFormatter
        recentFilesMaxStepper.minValue = 1
        recentFilesMaxStepper.maxValue = 50
        recentFilesMaxStepper.increment = 1
        recentFilesCustomLengthField.formatter = integerFormatter
        recentFilesCustomLengthStepper.minValue = 0
        recentFilesCustomLengthStepper.maxValue = 500
        recentFilesCustomLengthStepper.increment = 10

        periodicBackupField.formatter = integerFormatter
        periodicBackupStepper.minValue = 1
        periodicBackupStepper.maxValue = 3600
        periodicBackupStepper.increment = 1
        periodicBackupStepper.target = self
        periodicBackupStepper.action = #selector(controlChanged(_:))

        useCustomBackupDirButton.target = self
        useCustomBackupDirButton.action = #selector(controlChanged(_:))
        customBackupDirBrowseButton.target = self
        customBackupDirBrowseButton.action = #selector(browseCustomBackupDirectory(_:))

        fontSizeField.formatter = integerFormatter
        tabSizeField.formatter = tabSizeFormatter

        // Tab 1 – Editor
        [editorSectionLabel, fontSizeLabel, fontSizeField, fontSizeStepper,
         wrapsLinesButton, tabSizeLabel, tabSizeField, tabSizeStepper, insertSpacesButton,
         editorFeaturesSectionLabel,
         autoPairButton, autoPairParenthesesButton, autoPairBracketsButton,
         autoPairCurlyBracketsButton, autoPairSingleQuotesButton, autoPairDoubleQuotesButton,
         customPairsScrollView, customPairsAddButton, customPairsRemoveButton,
         xmlTagMatchButton, clickableLinksButton,
         smartHighlightMatchCaseButton, smartHighlightWholeWordButton,
         markAllMatchCaseButton, markAllWholeWordButton, langMenuCompactButton,
         caretWidthLabel, caretWidthSegmented, caretNoBlinkButton,
         caretBlinkRateLabel, caretBlinkRateField, caretBlinkRateStepper,
         caretStickyModeLabel, caretStickyModePopup,
         currentLineFrameLabel, currentLineFrameSegmented,
         lineWrapIndentLabel, lineWrapIndentPopup,
         enableCodeFoldingButton,
         foldMarginStyleLabel, foldMarginStylePopup,
         virtualSpaceButton, backspaceUnindentsButton, autoIndentButton, scrollBeyondLastLineButton,
         selectedTextDragDropButton, lineNumberDynamicWidthButton, columnSelectionToMultiEditingButton,
         showBookmarkMarginButton,
         showEdgeLineButton, edgeLineColumnLabel, edgeLineColumnField, edgeLineColumnStepper,
         displayDefaultsSectionLabel,
         showLineNumberMarginButton, showWhitespaceButton,
         whitespaceDisplayModeLabel, whitespaceDisplayModePopup,
         bidiModeLabel, bidiModePopup,
         showEOLButton,
         showIndentGuidesButton, highlightCurrentLineButton,
         showNpcCharactersButton, showWrapSymbolButton, showChangeHistoryButton,
         linePaddingLabel, linePaddingSegmented,
         autoCompleteLabel, autoCompleteField, autoCompleteStepper,
         largeFileSectionLabel, largeFileMBLabel, largeFileMBField, largeFileMBStepper,
         largeFileSuppressAutoCompleteButton, largeFileSuppressSmartHighlightButton, largeFileSuppressBraceMatchButton, largeFileSuppressWordWrapButton, largeFileSuppressSyntaxHighlightButton,
         additionalEdgeColumnsLabel, additionalEdgeColumnsField,
         autoCompleteModeLabel, autoCompleteModePopup,
         autoCompleteChooseSingleButton, autoCompleteTABFillupButton,
         autoCompleteEnterCommitButton, autoCompleteBriefButton,
         autoCompleteIgnoreCaseButton,
         htmlXmlCloseTagButton, muteAllSoundsButton, trimTrailingSpacesOnSaveButton,
         pasteConvertEndingsButton,
         smoothFontButton, multiEditEnabledButton, multiPasteModeLabel, multiPasteModePopup,
         indentGuideModeLabel, indentGuideModePopup,
         wordWrapModeLabel, wordWrapModePopup,
         additionalSelAlphaLabel, additionalSelAlphaField, additionalSelAlphaStepper,
         additionalCaretsBlinkButton, additionalCaretsVisibleButton, caretLineVisibleAlwaysButton,
         whitespaceSizeLabel, whitespaceSizeField, whitespaceSizeStepper,
         selectionAlphaLabel, selectionAlphaField, selectionAlphaStepper,
         controlCharDisplayLabel, controlCharDisplayPopup,
         autoIndentModeLabel, autoIndentModePopup,
         fileAutoDetectionLabel, fileAutoDetectionPopup,
         updateSilentlyButton,
         zoomSyncToAllTabsButton, hideMenuShortcutsButton, scrollToLastLineOnMonitorReloadButton,
         copyLineWithoutSelectionButton, smartHighlightUseFindSettingsButton,
         urlIndicatorStyleLabel, urlIndicatorStyleSegmented,
         langTabOverridesLabel, langTabOverridesField,
         taskListTagsLabel, taskListTagsField,
         editorFontNameLabel, editorFontNameField, editorFontBoldButton,
         xmlTagAttributeHighlightButton, highlightNonHtmlZoneButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; editCV.addSubview($0) }

        // Tab 2 – Session & Files
        [newDocumentSectionLabel, newDocEncodingLabel, newDocEncodingPopup,
         newDocLineEndingLabel, newDocLineEndingPopup,
         rememberSessionButton, newDocumentOnLaunchButton, useFirstLineAsTabNameButton,
         recentFilesMaxLabel, recentFilesMaxField, recentFilesMaxStepper,
         recentFilesShowFullPathButton, recentFilesInSubmenuButton,
         recentFilesCustomLengthLabel, recentFilesCustomLengthField, recentFilesCustomLengthStepper,
         noCheckRecentAtLaunchButton,
         keepAbsentFilesButton, autoReloadButton, snapshotModeButton, periodicBackupLabel,
         periodicBackupField, periodicBackupStepper, backupOnSaveLabel, backupOnSavePopup,
         useCustomBackupDirButton, customBackupDirField, customBackupDirBrowseButton,
         printLineNumbersButton, printSectionLabel,
         printHeaderSectionLabel, printHeaderLeftField, printHeaderCenterField, printHeaderRightField,
         printFooterSectionLabel, printFooterLeftField, printFooterCenterField, printFooterRightField,
         printColorModeLabel, printColorModePopup, printFontSizeLabel, printFontSizeField, printFontSizeStepper,
         printMarginsLabel, printMarginTopLabel, printMarginTopField,
         printMarginBottomLabel, printMarginBottomField,
         printMarginLeftLabel, printMarginLeftField,
         printMarginRightLabel, printMarginRightField,
         openDirFollowsDocButton, folderDropAsWorkspaceButton, folderDropRecursiveOpenButton,
         defaultLangLabel, defaultLangPopup,
         fileChangeDetectionButton,
         openAnsiAsUtf8Button,
         defaultSaveDirLabel, defaultSaveDirField
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; sessionCV.addSubview($0) }

        // Tab 3 – Find & Tools
        [findDefaultsSectionLabel, searchMatchCaseButton, searchWholeWordButton,
         dateTimeSectionLabel, dateTimeFormatLabel, dateTimeFormatField,
         searchEngineSectionLabel, searchEngineChoiceLabel, searchEnginePopup,
         searchEngineCustomURLLabel, searchEngineCustomURLField,
         extraURLSchemesLabel, extraURLSchemesField,
         localizationSectionLabel, localizationChoiceLabel, localizationPopup,
         inSelectionSectionLabel, inSelectionThresholdLabel,
         inSelectionThresholdField, inSelectionThresholdStepper,
         keepFindDialogOpenButton, replaceDoesNotMoveButton,
         findDialogMonospaceButton, fillFindFromSelectionButton,
         autoSelectWordUnderCaretButton, findInFilesIgnoreUnsavedButton,
         confirmReplaceInAllDocsButton, perLineResultButton,
         maxFindHistoryLabel, maxFindHistoryField, maxFindHistoryStepper,
         findTransparencyLabel, findTransparencySlider
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; toolsCV.addSubview($0) }

        // Tab 4 – Window
        [tabbarSectionLabel, tabbarHideButton, tabbarDoubleClickCloseButton, tabbarLockDragDropButton,
         tabbarExitOnLastTabButton, tabbarShowCloseButtonButton, tabbarCompactButton,
         tabbarMaxLabelLengthLabel, tabbarMaxLabelLengthField, tabbarMaxLabelLengthStepper,
         delimiterSectionLabel, delimiterLeftLabel, delimiterLeftField,
         delimiterRightLabel, delimiterRightField,
         generalSectionLabel, statusBarVisibleButton, shortTitleButton,
         saveAllConfirmButton, autoCompleteIgnoreNumbersButton, reloadScrollToLastCaretButton,
         toolbarIconSizeLabel, toolbarIconSizeSegmented,
         scintillaRenderingLabel, scintillaRenderingPopup,
         disableAdvancedScrollingButton, rightClickKeepSelectionButton,
         edgeModeLabel, edgeModePopup,
         foldFlagsLabel, foldFlagsPopup, foldCompactButton, showDocSwitcherButton,
         appearanceSectionLabel, appearanceModeLabel, appearanceModeSegmented,
         postItSectionLabel, postItAlphaLabel, postItAlphaSlider
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; windowCV.addSubview($0) }

        [localizationSectionLabel, editorSectionLabel, editorFeaturesSectionLabel, displayDefaultsSectionLabel, largeFileSectionLabel, newDocumentSectionLabel, findDefaultsSectionLabel, dateTimeSectionLabel, searchEngineSectionLabel, inSelectionSectionLabel, tabbarSectionLabel, printSectionLabel, delimiterSectionLabel, generalSectionLabel, appearanceSectionLabel, postItSectionLabel].forEach {
            $0.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        }
        // Convenience anchors for tabs 2 and 3
        let lead: CGFloat = 18
        let indent: CGFloat = 18 + 80 + 12  // matches fontSizeField.leadingAnchor in tab1

        // ── Tab 1: Editor ──────────────────────────────────────
        NSLayoutConstraint.activate([
            editorSectionLabel.leadingAnchor.constraint(equalTo: editCV.leadingAnchor, constant: lead),
            editorSectionLabel.topAnchor.constraint(equalTo: editCV.topAnchor, constant: 20),

            fontSizeLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            fontSizeLabel.topAnchor.constraint(equalTo: editorSectionLabel.bottomAnchor, constant: 14),
            fontSizeLabel.widthAnchor.constraint(equalToConstant: 80),

            fontSizeField.leadingAnchor.constraint(equalTo: fontSizeLabel.trailingAnchor, constant: 12),
            fontSizeField.centerYAnchor.constraint(equalTo: fontSizeLabel.centerYAnchor),
            fontSizeField.widthAnchor.constraint(equalToConstant: 58),

            fontSizeStepper.leadingAnchor.constraint(equalTo: fontSizeField.trailingAnchor, constant: 8),
            fontSizeStepper.centerYAnchor.constraint(equalTo: fontSizeField.centerYAnchor),

            editorFontNameLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            editorFontNameLabel.topAnchor.constraint(equalTo: fontSizeField.bottomAnchor, constant: 14),
            editorFontNameLabel.widthAnchor.constraint(equalToConstant: 80),

            editorFontNameField.leadingAnchor.constraint(equalTo: editorFontNameLabel.trailingAnchor, constant: 12),
            editorFontNameField.centerYAnchor.constraint(equalTo: editorFontNameLabel.centerYAnchor),
            editorFontNameField.widthAnchor.constraint(equalToConstant: 180),

            editorFontBoldButton.leadingAnchor.constraint(equalTo: editorFontNameField.leadingAnchor),
            editorFontBoldButton.topAnchor.constraint(equalTo: editorFontNameLabel.bottomAnchor, constant: 8),

            wrapsLinesButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            wrapsLinesButton.topAnchor.constraint(equalTo: editorFontBoldButton.bottomAnchor, constant: 14),

            tabSizeLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            tabSizeLabel.topAnchor.constraint(equalTo: wrapsLinesButton.bottomAnchor, constant: 14),
            tabSizeLabel.widthAnchor.constraint(equalToConstant: 80),

            tabSizeField.leadingAnchor.constraint(equalTo: tabSizeLabel.trailingAnchor, constant: 12),
            tabSizeField.centerYAnchor.constraint(equalTo: tabSizeLabel.centerYAnchor),
            tabSizeField.widthAnchor.constraint(equalToConstant: 58),

            tabSizeStepper.leadingAnchor.constraint(equalTo: tabSizeField.trailingAnchor, constant: 8),
            tabSizeStepper.centerYAnchor.constraint(equalTo: tabSizeField.centerYAnchor),

            insertSpacesButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            insertSpacesButton.topAnchor.constraint(equalTo: tabSizeLabel.bottomAnchor, constant: 14),

            editorFeaturesSectionLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            editorFeaturesSectionLabel.topAnchor.constraint(equalTo: insertSpacesButton.bottomAnchor, constant: 20),

            autoPairButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            autoPairButton.topAnchor.constraint(equalTo: editorFeaturesSectionLabel.bottomAnchor, constant: 14),

            autoPairParenthesesButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            autoPairParenthesesButton.topAnchor.constraint(equalTo: autoPairButton.bottomAnchor, constant: 6),

            autoPairBracketsButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            autoPairBracketsButton.topAnchor.constraint(equalTo: autoPairParenthesesButton.bottomAnchor, constant: 4),

            autoPairCurlyBracketsButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            autoPairCurlyBracketsButton.topAnchor.constraint(equalTo: autoPairBracketsButton.bottomAnchor, constant: 4),

            autoPairSingleQuotesButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            autoPairSingleQuotesButton.topAnchor.constraint(equalTo: autoPairCurlyBracketsButton.bottomAnchor, constant: 4),

            autoPairDoubleQuotesButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            autoPairDoubleQuotesButton.topAnchor.constraint(equalTo: autoPairSingleQuotesButton.bottomAnchor, constant: 4),

            customPairsScrollView.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            customPairsScrollView.topAnchor.constraint(equalTo: autoPairDoubleQuotesButton.bottomAnchor, constant: 8),
            customPairsScrollView.widthAnchor.constraint(equalToConstant: 160),
            customPairsScrollView.heightAnchor.constraint(equalToConstant: 80),

            customPairsAddButton.leadingAnchor.constraint(equalTo: customPairsScrollView.leadingAnchor),
            customPairsAddButton.topAnchor.constraint(equalTo: customPairsScrollView.bottomAnchor, constant: 4),
            customPairsAddButton.widthAnchor.constraint(equalToConstant: 26),

            customPairsRemoveButton.leadingAnchor.constraint(equalTo: customPairsAddButton.trailingAnchor, constant: 4),
            customPairsRemoveButton.topAnchor.constraint(equalTo: customPairsScrollView.bottomAnchor, constant: 4),
            customPairsRemoveButton.widthAnchor.constraint(equalToConstant: 26),

            xmlTagMatchButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            xmlTagMatchButton.topAnchor.constraint(equalTo: customPairsAddButton.bottomAnchor, constant: 10),

            xmlTagAttributeHighlightButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            xmlTagAttributeHighlightButton.topAnchor.constraint(equalTo: xmlTagMatchButton.bottomAnchor, constant: 6),

            highlightNonHtmlZoneButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            highlightNonHtmlZoneButton.topAnchor.constraint(equalTo: xmlTagAttributeHighlightButton.bottomAnchor, constant: 6),

            clickableLinksButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            clickableLinksButton.topAnchor.constraint(equalTo: highlightNonHtmlZoneButton.bottomAnchor, constant: 10),

            smartHighlightMatchCaseButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            smartHighlightMatchCaseButton.topAnchor.constraint(equalTo: clickableLinksButton.bottomAnchor, constant: 10),

            smartHighlightWholeWordButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            smartHighlightWholeWordButton.topAnchor.constraint(equalTo: smartHighlightMatchCaseButton.bottomAnchor, constant: 10),

            markAllMatchCaseButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            markAllMatchCaseButton.topAnchor.constraint(equalTo: smartHighlightWholeWordButton.bottomAnchor, constant: 10),

            markAllWholeWordButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            markAllWholeWordButton.topAnchor.constraint(equalTo: markAllMatchCaseButton.bottomAnchor, constant: 6),

            langMenuCompactButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            langMenuCompactButton.topAnchor.constraint(equalTo: markAllWholeWordButton.bottomAnchor, constant: 10),

            caretWidthLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            caretWidthLabel.topAnchor.constraint(equalTo: langMenuCompactButton.bottomAnchor, constant: 14),
            caretWidthLabel.widthAnchor.constraint(equalToConstant: 92),

            caretWidthSegmented.leadingAnchor.constraint(equalTo: caretWidthLabel.trailingAnchor, constant: 12),
            caretWidthSegmented.centerYAnchor.constraint(equalTo: caretWidthLabel.centerYAnchor),

            caretNoBlinkButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            caretNoBlinkButton.topAnchor.constraint(equalTo: caretWidthLabel.bottomAnchor, constant: 10),

            caretBlinkRateLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            caretBlinkRateLabel.topAnchor.constraint(equalTo: caretNoBlinkButton.bottomAnchor, constant: 10),
            caretBlinkRateLabel.widthAnchor.constraint(equalToConstant: 110),

            caretBlinkRateField.leadingAnchor.constraint(equalTo: caretBlinkRateLabel.trailingAnchor, constant: 8),
            caretBlinkRateField.centerYAnchor.constraint(equalTo: caretBlinkRateLabel.centerYAnchor),
            caretBlinkRateField.widthAnchor.constraint(equalToConstant: 60),

            caretBlinkRateStepper.leadingAnchor.constraint(equalTo: caretBlinkRateField.trailingAnchor, constant: 4),
            caretBlinkRateStepper.centerYAnchor.constraint(equalTo: caretBlinkRateLabel.centerYAnchor),

            caretStickyModeLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            caretStickyModeLabel.topAnchor.constraint(equalTo: caretBlinkRateLabel.bottomAnchor, constant: 10),
            caretStickyModeLabel.widthAnchor.constraint(equalToConstant: 120),

            caretStickyModePopup.leadingAnchor.constraint(equalTo: caretStickyModeLabel.trailingAnchor, constant: 8),
            caretStickyModePopup.centerYAnchor.constraint(equalTo: caretStickyModeLabel.centerYAnchor),
            caretStickyModePopup.widthAnchor.constraint(equalToConstant: 180),

            currentLineFrameLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            currentLineFrameLabel.topAnchor.constraint(equalTo: caretStickyModeLabel.bottomAnchor, constant: 10),
            currentLineFrameLabel.widthAnchor.constraint(equalToConstant: 140),

            currentLineFrameSegmented.leadingAnchor.constraint(equalTo: currentLineFrameLabel.trailingAnchor, constant: 8),
            currentLineFrameSegmented.centerYAnchor.constraint(equalTo: currentLineFrameLabel.centerYAnchor),

            lineWrapIndentLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            lineWrapIndentLabel.topAnchor.constraint(equalTo: currentLineFrameLabel.bottomAnchor, constant: 10),
            lineWrapIndentLabel.widthAnchor.constraint(equalToConstant: 140),

            lineWrapIndentPopup.leadingAnchor.constraint(equalTo: lineWrapIndentLabel.trailingAnchor, constant: 8),
            lineWrapIndentPopup.centerYAnchor.constraint(equalTo: lineWrapIndentLabel.centerYAnchor),

            enableCodeFoldingButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            enableCodeFoldingButton.topAnchor.constraint(equalTo: lineWrapIndentLabel.bottomAnchor, constant: 10),

            foldMarginStyleLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            foldMarginStyleLabel.topAnchor.constraint(equalTo: enableCodeFoldingButton.bottomAnchor, constant: 10),
            foldMarginStyleLabel.widthAnchor.constraint(equalToConstant: 140),

            foldMarginStylePopup.leadingAnchor.constraint(equalTo: foldMarginStyleLabel.trailingAnchor, constant: 8),
            foldMarginStylePopup.centerYAnchor.constraint(equalTo: foldMarginStyleLabel.centerYAnchor),

            virtualSpaceButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            virtualSpaceButton.topAnchor.constraint(equalTo: foldMarginStyleLabel.bottomAnchor, constant: 10),

            backspaceUnindentsButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            backspaceUnindentsButton.topAnchor.constraint(equalTo: virtualSpaceButton.bottomAnchor, constant: 10),

            autoIndentButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            autoIndentButton.topAnchor.constraint(equalTo: backspaceUnindentsButton.bottomAnchor, constant: 10),

            scrollBeyondLastLineButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            scrollBeyondLastLineButton.topAnchor.constraint(equalTo: autoIndentButton.bottomAnchor, constant: 10),

            selectedTextDragDropButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            selectedTextDragDropButton.topAnchor.constraint(equalTo: scrollBeyondLastLineButton.bottomAnchor, constant: 10),

            lineNumberDynamicWidthButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            lineNumberDynamicWidthButton.topAnchor.constraint(equalTo: selectedTextDragDropButton.bottomAnchor, constant: 10),

            columnSelectionToMultiEditingButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            columnSelectionToMultiEditingButton.topAnchor.constraint(equalTo: lineNumberDynamicWidthButton.bottomAnchor, constant: 10),

            showBookmarkMarginButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showBookmarkMarginButton.topAnchor.constraint(equalTo: columnSelectionToMultiEditingButton.bottomAnchor, constant: 10),

            showEdgeLineButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showEdgeLineButton.topAnchor.constraint(equalTo: showBookmarkMarginButton.bottomAnchor, constant: 10),

            edgeLineColumnLabel.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            edgeLineColumnLabel.topAnchor.constraint(equalTo: showEdgeLineButton.bottomAnchor, constant: 8),

            edgeLineColumnField.leadingAnchor.constraint(equalTo: edgeLineColumnLabel.trailingAnchor, constant: 8),
            edgeLineColumnField.centerYAnchor.constraint(equalTo: edgeLineColumnLabel.centerYAnchor),
            edgeLineColumnField.widthAnchor.constraint(equalToConstant: 60),

            edgeLineColumnStepper.leadingAnchor.constraint(equalTo: edgeLineColumnField.trailingAnchor, constant: 4),
            edgeLineColumnStepper.centerYAnchor.constraint(equalTo: edgeLineColumnField.centerYAnchor),

            displayDefaultsSectionLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            displayDefaultsSectionLabel.topAnchor.constraint(equalTo: edgeLineColumnLabel.bottomAnchor, constant: 20),

            showLineNumberMarginButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showLineNumberMarginButton.topAnchor.constraint(equalTo: displayDefaultsSectionLabel.bottomAnchor, constant: 10),

            showWhitespaceButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showWhitespaceButton.topAnchor.constraint(equalTo: showLineNumberMarginButton.bottomAnchor, constant: 6),

            whitespaceDisplayModeLabel.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            whitespaceDisplayModeLabel.topAnchor.constraint(equalTo: showWhitespaceButton.bottomAnchor, constant: 6),

            whitespaceDisplayModePopup.leadingAnchor.constraint(equalTo: whitespaceDisplayModeLabel.trailingAnchor, constant: 8),
            whitespaceDisplayModePopup.centerYAnchor.constraint(equalTo: whitespaceDisplayModeLabel.centerYAnchor),
            whitespaceDisplayModePopup.widthAnchor.constraint(equalToConstant: 150),

            bidiModeLabel.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            bidiModeLabel.topAnchor.constraint(equalTo: whitespaceDisplayModeLabel.bottomAnchor, constant: 6),

            bidiModePopup.leadingAnchor.constraint(equalTo: bidiModeLabel.trailingAnchor, constant: 8),
            bidiModePopup.centerYAnchor.constraint(equalTo: bidiModeLabel.centerYAnchor),
            bidiModePopup.widthAnchor.constraint(equalToConstant: 130),

            showEOLButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showEOLButton.topAnchor.constraint(equalTo: bidiModeLabel.bottomAnchor, constant: 6),

            showIndentGuidesButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showIndentGuidesButton.topAnchor.constraint(equalTo: showEOLButton.bottomAnchor, constant: 6),

            highlightCurrentLineButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            highlightCurrentLineButton.topAnchor.constraint(equalTo: showIndentGuidesButton.bottomAnchor, constant: 6),

            showNpcCharactersButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showNpcCharactersButton.topAnchor.constraint(equalTo: highlightCurrentLineButton.bottomAnchor, constant: 6),

            showWrapSymbolButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showWrapSymbolButton.topAnchor.constraint(equalTo: showNpcCharactersButton.bottomAnchor, constant: 6),

            showChangeHistoryButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            showChangeHistoryButton.topAnchor.constraint(equalTo: showWrapSymbolButton.bottomAnchor, constant: 6),

            linePaddingLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            linePaddingLabel.topAnchor.constraint(equalTo: showChangeHistoryButton.bottomAnchor, constant: 14),

            linePaddingSegmented.leadingAnchor.constraint(equalTo: linePaddingLabel.trailingAnchor, constant: 12),
            linePaddingSegmented.centerYAnchor.constraint(equalTo: linePaddingLabel.centerYAnchor),

            autoCompleteLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            autoCompleteLabel.topAnchor.constraint(equalTo: linePaddingLabel.bottomAnchor, constant: 14),

            autoCompleteField.leadingAnchor.constraint(equalTo: autoCompleteLabel.trailingAnchor, constant: 12),
            autoCompleteField.centerYAnchor.constraint(equalTo: autoCompleteLabel.centerYAnchor),
            autoCompleteField.widthAnchor.constraint(equalToConstant: 50),

            autoCompleteStepper.leadingAnchor.constraint(equalTo: autoCompleteField.trailingAnchor, constant: 8),
            autoCompleteStepper.centerYAnchor.constraint(equalTo: autoCompleteField.centerYAnchor),

            largeFileSectionLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileSectionLabel.topAnchor.constraint(equalTo: autoCompleteLabel.bottomAnchor, constant: 20),

            largeFileMBLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileMBLabel.topAnchor.constraint(equalTo: largeFileSectionLabel.bottomAnchor, constant: 14),
            largeFileMBLabel.widthAnchor.constraint(equalToConstant: 180),

            largeFileMBField.leadingAnchor.constraint(equalTo: largeFileMBLabel.trailingAnchor, constant: 12),
            largeFileMBField.centerYAnchor.constraint(equalTo: largeFileMBLabel.centerYAnchor),
            largeFileMBField.widthAnchor.constraint(equalToConstant: 58),

            largeFileMBStepper.leadingAnchor.constraint(equalTo: largeFileMBField.trailingAnchor, constant: 8),
            largeFileMBStepper.centerYAnchor.constraint(equalTo: largeFileMBField.centerYAnchor),

            largeFileSuppressAutoCompleteButton.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileSuppressAutoCompleteButton.topAnchor.constraint(equalTo: largeFileMBLabel.bottomAnchor, constant: 10),

            largeFileSuppressSmartHighlightButton.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileSuppressSmartHighlightButton.topAnchor.constraint(equalTo: largeFileSuppressAutoCompleteButton.bottomAnchor, constant: 8),

            largeFileSuppressBraceMatchButton.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileSuppressBraceMatchButton.topAnchor.constraint(equalTo: largeFileSuppressSmartHighlightButton.bottomAnchor, constant: 8),

            largeFileSuppressWordWrapButton.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileSuppressWordWrapButton.topAnchor.constraint(equalTo: largeFileSuppressBraceMatchButton.bottomAnchor, constant: 8),

            largeFileSuppressSyntaxHighlightButton.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            largeFileSuppressSyntaxHighlightButton.topAnchor.constraint(equalTo: largeFileSuppressWordWrapButton.bottomAnchor, constant: 8),

            additionalEdgeColumnsLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            additionalEdgeColumnsLabel.topAnchor.constraint(equalTo: largeFileSuppressSyntaxHighlightButton.bottomAnchor, constant: 14),
            additionalEdgeColumnsLabel.widthAnchor.constraint(equalToConstant: 200),

            additionalEdgeColumnsField.leadingAnchor.constraint(equalTo: additionalEdgeColumnsLabel.trailingAnchor, constant: 8),
            additionalEdgeColumnsField.centerYAnchor.constraint(equalTo: additionalEdgeColumnsLabel.centerYAnchor),
            additionalEdgeColumnsField.widthAnchor.constraint(equalToConstant: 100),

            autoCompleteModeLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            autoCompleteModeLabel.topAnchor.constraint(equalTo: additionalEdgeColumnsLabel.bottomAnchor, constant: 14),
            autoCompleteModeLabel.widthAnchor.constraint(equalToConstant: 180),

            autoCompleteModePopup.leadingAnchor.constraint(equalTo: autoCompleteModeLabel.trailingAnchor, constant: 8),
            autoCompleteModePopup.centerYAnchor.constraint(equalTo: autoCompleteModeLabel.centerYAnchor),
            autoCompleteModePopup.trailingAnchor.constraint(equalTo: editCV.trailingAnchor, constant: -18),

            autoCompleteChooseSingleButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            autoCompleteChooseSingleButton.topAnchor.constraint(equalTo: autoCompleteModeLabel.bottomAnchor, constant: 10),

            autoCompleteTABFillupButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            autoCompleteTABFillupButton.topAnchor.constraint(equalTo: autoCompleteChooseSingleButton.bottomAnchor, constant: 10),

            autoCompleteEnterCommitButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            autoCompleteEnterCommitButton.topAnchor.constraint(equalTo: autoCompleteTABFillupButton.bottomAnchor, constant: 8),

            autoCompleteBriefButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            autoCompleteBriefButton.topAnchor.constraint(equalTo: autoCompleteEnterCommitButton.bottomAnchor, constant: 8),

            autoCompleteIgnoreCaseButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            autoCompleteIgnoreCaseButton.topAnchor.constraint(equalTo: autoCompleteBriefButton.bottomAnchor, constant: 8),

            htmlXmlCloseTagButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            htmlXmlCloseTagButton.topAnchor.constraint(equalTo: autoCompleteIgnoreCaseButton.bottomAnchor, constant: 10),

            muteAllSoundsButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            muteAllSoundsButton.topAnchor.constraint(equalTo: htmlXmlCloseTagButton.bottomAnchor, constant: 10),

            trimTrailingSpacesOnSaveButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            trimTrailingSpacesOnSaveButton.topAnchor.constraint(equalTo: muteAllSoundsButton.bottomAnchor, constant: 10),

            pasteConvertEndingsButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            pasteConvertEndingsButton.topAnchor.constraint(equalTo: trimTrailingSpacesOnSaveButton.bottomAnchor, constant: 10),

            smoothFontButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            smoothFontButton.topAnchor.constraint(equalTo: pasteConvertEndingsButton.bottomAnchor, constant: 10),

            multiEditEnabledButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            multiEditEnabledButton.topAnchor.constraint(equalTo: smoothFontButton.bottomAnchor, constant: 10),

            multiPasteModeLabel.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            multiPasteModeLabel.topAnchor.constraint(equalTo: multiEditEnabledButton.bottomAnchor, constant: 10),
            multiPasteModeLabel.widthAnchor.constraint(equalToConstant: 130),

            multiPasteModePopup.leadingAnchor.constraint(equalTo: multiPasteModeLabel.trailingAnchor, constant: 8),
            multiPasteModePopup.centerYAnchor.constraint(equalTo: multiPasteModeLabel.centerYAnchor),
            multiPasteModePopup.widthAnchor.constraint(equalToConstant: 200),

            indentGuideModeLabel.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            indentGuideModeLabel.topAnchor.constraint(equalTo: multiPasteModeLabel.bottomAnchor, constant: 10),
            indentGuideModeLabel.widthAnchor.constraint(equalToConstant: 130),

            indentGuideModePopup.leadingAnchor.constraint(equalTo: indentGuideModeLabel.trailingAnchor, constant: 8),
            indentGuideModePopup.centerYAnchor.constraint(equalTo: indentGuideModeLabel.centerYAnchor),
            indentGuideModePopup.widthAnchor.constraint(equalToConstant: 200),

            wordWrapModeLabel.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            wordWrapModeLabel.topAnchor.constraint(equalTo: indentGuideModeLabel.bottomAnchor, constant: 10),
            wordWrapModeLabel.widthAnchor.constraint(equalToConstant: 130),

            wordWrapModePopup.leadingAnchor.constraint(equalTo: wordWrapModeLabel.trailingAnchor, constant: 8),
            wordWrapModePopup.centerYAnchor.constraint(equalTo: wordWrapModeLabel.centerYAnchor),
            wordWrapModePopup.widthAnchor.constraint(equalToConstant: 200),

            // Additional selection alpha
            additionalSelAlphaLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            additionalSelAlphaLabel.topAnchor.constraint(equalTo: wordWrapModeLabel.bottomAnchor, constant: 14),
            additionalSelAlphaLabel.widthAnchor.constraint(equalToConstant: 180),

            additionalSelAlphaField.leadingAnchor.constraint(equalTo: additionalSelAlphaLabel.trailingAnchor, constant: 8),
            additionalSelAlphaField.centerYAnchor.constraint(equalTo: additionalSelAlphaLabel.centerYAnchor),
            additionalSelAlphaField.widthAnchor.constraint(equalToConstant: 50),

            additionalSelAlphaStepper.leadingAnchor.constraint(equalTo: additionalSelAlphaField.trailingAnchor, constant: 4),
            additionalSelAlphaStepper.centerYAnchor.constraint(equalTo: additionalSelAlphaLabel.centerYAnchor),

            additionalCaretsBlinkButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            additionalCaretsBlinkButton.topAnchor.constraint(equalTo: additionalSelAlphaLabel.bottomAnchor, constant: 10),

            additionalCaretsVisibleButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            additionalCaretsVisibleButton.topAnchor.constraint(equalTo: additionalCaretsBlinkButton.bottomAnchor, constant: 10),

            caretLineVisibleAlwaysButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            caretLineVisibleAlwaysButton.topAnchor.constraint(equalTo: additionalCaretsVisibleButton.bottomAnchor, constant: 10),

            // Whitespace size
            whitespaceSizeLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            whitespaceSizeLabel.topAnchor.constraint(equalTo: caretLineVisibleAlwaysButton.bottomAnchor, constant: 14),
            whitespaceSizeLabel.widthAnchor.constraint(equalToConstant: 160),

            whitespaceSizeField.leadingAnchor.constraint(equalTo: whitespaceSizeLabel.trailingAnchor, constant: 8),
            whitespaceSizeField.centerYAnchor.constraint(equalTo: whitespaceSizeLabel.centerYAnchor),
            whitespaceSizeField.widthAnchor.constraint(equalToConstant: 40),

            whitespaceSizeStepper.leadingAnchor.constraint(equalTo: whitespaceSizeField.trailingAnchor, constant: 4),
            whitespaceSizeStepper.centerYAnchor.constraint(equalTo: whitespaceSizeLabel.centerYAnchor),

            // Selection alpha
            selectionAlphaLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            selectionAlphaLabel.topAnchor.constraint(equalTo: whitespaceSizeLabel.bottomAnchor, constant: 14),
            selectionAlphaLabel.widthAnchor.constraint(equalToConstant: 160),

            selectionAlphaField.leadingAnchor.constraint(equalTo: selectionAlphaLabel.trailingAnchor, constant: 8),
            selectionAlphaField.centerYAnchor.constraint(equalTo: selectionAlphaLabel.centerYAnchor),
            selectionAlphaField.widthAnchor.constraint(equalToConstant: 50),

            selectionAlphaStepper.leadingAnchor.constraint(equalTo: selectionAlphaField.trailingAnchor, constant: 4),
            selectionAlphaStepper.centerYAnchor.constraint(equalTo: selectionAlphaLabel.centerYAnchor),

            // Control char display
            controlCharDisplayLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            controlCharDisplayLabel.topAnchor.constraint(equalTo: selectionAlphaLabel.bottomAnchor, constant: 14),
            controlCharDisplayLabel.widthAnchor.constraint(equalToConstant: 160),

            controlCharDisplayPopup.leadingAnchor.constraint(equalTo: controlCharDisplayLabel.trailingAnchor, constant: 8),
            controlCharDisplayPopup.centerYAnchor.constraint(equalTo: controlCharDisplayLabel.centerYAnchor),
            controlCharDisplayPopup.widthAnchor.constraint(equalToConstant: 200),

            // Auto-indent mode
            autoIndentModeLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            autoIndentModeLabel.topAnchor.constraint(equalTo: controlCharDisplayLabel.bottomAnchor, constant: 14),
            autoIndentModeLabel.widthAnchor.constraint(equalToConstant: 130),

            autoIndentModePopup.leadingAnchor.constraint(equalTo: autoIndentModeLabel.trailingAnchor, constant: 8),
            autoIndentModePopup.centerYAnchor.constraint(equalTo: autoIndentModeLabel.centerYAnchor),
            autoIndentModePopup.widthAnchor.constraint(equalToConstant: 200),

            // File auto-detection
            fileAutoDetectionLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            fileAutoDetectionLabel.topAnchor.constraint(equalTo: autoIndentModeLabel.bottomAnchor, constant: 14),
            fileAutoDetectionLabel.widthAnchor.constraint(equalToConstant: 160),

            fileAutoDetectionPopup.leadingAnchor.constraint(equalTo: fileAutoDetectionLabel.trailingAnchor, constant: 8),
            fileAutoDetectionPopup.centerYAnchor.constraint(equalTo: fileAutoDetectionLabel.centerYAnchor),
            fileAutoDetectionPopup.widthAnchor.constraint(equalToConstant: 200),

            updateSilentlyButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            updateSilentlyButton.topAnchor.constraint(equalTo: fileAutoDetectionLabel.bottomAnchor, constant: 10),

            zoomSyncToAllTabsButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            zoomSyncToAllTabsButton.topAnchor.constraint(equalTo: updateSilentlyButton.bottomAnchor, constant: 10),

            hideMenuShortcutsButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            hideMenuShortcutsButton.topAnchor.constraint(equalTo: zoomSyncToAllTabsButton.bottomAnchor, constant: 10),

            scrollToLastLineOnMonitorReloadButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            scrollToLastLineOnMonitorReloadButton.topAnchor.constraint(equalTo: hideMenuShortcutsButton.bottomAnchor, constant: 10),

            copyLineWithoutSelectionButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            copyLineWithoutSelectionButton.topAnchor.constraint(equalTo: scrollToLastLineOnMonitorReloadButton.bottomAnchor, constant: 10),

            smartHighlightUseFindSettingsButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            smartHighlightUseFindSettingsButton.topAnchor.constraint(equalTo: copyLineWithoutSelectionButton.bottomAnchor, constant: 10),

            urlIndicatorStyleLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            urlIndicatorStyleLabel.topAnchor.constraint(equalTo: smartHighlightUseFindSettingsButton.bottomAnchor, constant: 14),
            urlIndicatorStyleLabel.widthAnchor.constraint(equalToConstant: 80),

            urlIndicatorStyleSegmented.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            urlIndicatorStyleSegmented.centerYAnchor.constraint(equalTo: urlIndicatorStyleLabel.centerYAnchor),

            langTabOverridesLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            langTabOverridesLabel.topAnchor.constraint(equalTo: urlIndicatorStyleLabel.bottomAnchor, constant: 14),
            langTabOverridesLabel.widthAnchor.constraint(equalToConstant: 80),

            langTabOverridesField.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            langTabOverridesField.trailingAnchor.constraint(equalTo: editCV.trailingAnchor, constant: -18),
            langTabOverridesField.centerYAnchor.constraint(equalTo: langTabOverridesLabel.centerYAnchor),

            taskListTagsLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            taskListTagsLabel.topAnchor.constraint(equalTo: langTabOverridesLabel.bottomAnchor, constant: 14),
            taskListTagsLabel.widthAnchor.constraint(equalToConstant: 80),

            taskListTagsField.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            taskListTagsField.trailingAnchor.constraint(equalTo: editCV.trailingAnchor, constant: -18),
            taskListTagsField.centerYAnchor.constraint(equalTo: taskListTagsLabel.centerYAnchor),

            // Pin Tab1 content bottom
            editCV.bottomAnchor.constraint(equalTo: taskListTagsLabel.bottomAnchor, constant: 24)
        ])

        // ── Tab 2: Session & Files ──────────────────────────────
        NSLayoutConstraint.activate([
            newDocumentSectionLabel.leadingAnchor.constraint(equalTo: sessionCV.leadingAnchor, constant: lead),
            newDocumentSectionLabel.topAnchor.constraint(equalTo: sessionCV.topAnchor, constant: 20),

            newDocEncodingLabel.leadingAnchor.constraint(equalTo: newDocumentSectionLabel.leadingAnchor),
            newDocEncodingLabel.topAnchor.constraint(equalTo: newDocumentSectionLabel.bottomAnchor, constant: 14),
            newDocEncodingLabel.widthAnchor.constraint(equalToConstant: 92),

            newDocEncodingPopup.leadingAnchor.constraint(equalTo: newDocEncodingLabel.trailingAnchor, constant: 12),
            newDocEncodingPopup.centerYAnchor.constraint(equalTo: newDocEncodingLabel.centerYAnchor),
            newDocEncodingPopup.trailingAnchor.constraint(equalTo: sessionCV.trailingAnchor, constant: -18),

            newDocLineEndingLabel.leadingAnchor.constraint(equalTo: newDocumentSectionLabel.leadingAnchor),
            newDocLineEndingLabel.topAnchor.constraint(equalTo: newDocEncodingLabel.bottomAnchor, constant: 14),
            newDocLineEndingLabel.widthAnchor.constraint(equalToConstant: 92),

            newDocLineEndingPopup.leadingAnchor.constraint(equalTo: newDocLineEndingLabel.trailingAnchor, constant: 12),
            newDocLineEndingPopup.centerYAnchor.constraint(equalTo: newDocLineEndingLabel.centerYAnchor),
            newDocLineEndingPopup.trailingAnchor.constraint(equalTo: sessionCV.trailingAnchor, constant: -18),

            rememberSessionButton.leadingAnchor.constraint(equalTo: sessionCV.leadingAnchor, constant: indent),
            rememberSessionButton.topAnchor.constraint(equalTo: newDocLineEndingLabel.bottomAnchor, constant: 10),

            newDocumentOnLaunchButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            newDocumentOnLaunchButton.topAnchor.constraint(equalTo: rememberSessionButton.bottomAnchor, constant: 10),

            useFirstLineAsTabNameButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            useFirstLineAsTabNameButton.topAnchor.constraint(equalTo: newDocumentOnLaunchButton.bottomAnchor, constant: 10),

            recentFilesMaxLabel.leadingAnchor.constraint(equalTo: newDocumentSectionLabel.leadingAnchor),
            recentFilesMaxLabel.topAnchor.constraint(equalTo: useFirstLineAsTabNameButton.bottomAnchor, constant: 10),
            recentFilesMaxLabel.widthAnchor.constraint(equalToConstant: 120),

            recentFilesMaxField.leadingAnchor.constraint(equalTo: recentFilesMaxLabel.trailingAnchor, constant: 8),
            recentFilesMaxField.centerYAnchor.constraint(equalTo: recentFilesMaxLabel.centerYAnchor),
            recentFilesMaxField.widthAnchor.constraint(equalToConstant: 50),

            recentFilesMaxStepper.leadingAnchor.constraint(equalTo: recentFilesMaxField.trailingAnchor, constant: 6),
            recentFilesMaxStepper.centerYAnchor.constraint(equalTo: recentFilesMaxField.centerYAnchor),

            recentFilesShowFullPathButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            recentFilesShowFullPathButton.topAnchor.constraint(equalTo: recentFilesMaxLabel.bottomAnchor, constant: 10),

            recentFilesInSubmenuButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            recentFilesInSubmenuButton.topAnchor.constraint(equalTo: recentFilesShowFullPathButton.bottomAnchor, constant: 10),

            recentFilesCustomLengthLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            recentFilesCustomLengthLabel.topAnchor.constraint(equalTo: recentFilesInSubmenuButton.bottomAnchor, constant: 10),

            recentFilesCustomLengthField.leadingAnchor.constraint(equalTo: recentFilesCustomLengthLabel.trailingAnchor, constant: 8),
            recentFilesCustomLengthField.centerYAnchor.constraint(equalTo: recentFilesCustomLengthLabel.centerYAnchor),
            recentFilesCustomLengthField.widthAnchor.constraint(equalToConstant: 60),

            recentFilesCustomLengthStepper.leadingAnchor.constraint(equalTo: recentFilesCustomLengthField.trailingAnchor, constant: 6),
            recentFilesCustomLengthStepper.centerYAnchor.constraint(equalTo: recentFilesCustomLengthField.centerYAnchor),

            noCheckRecentAtLaunchButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            noCheckRecentAtLaunchButton.topAnchor.constraint(equalTo: recentFilesCustomLengthLabel.bottomAnchor, constant: 10),

            keepAbsentFilesButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            keepAbsentFilesButton.topAnchor.constraint(equalTo: noCheckRecentAtLaunchButton.bottomAnchor, constant: 10),

            autoReloadButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            autoReloadButton.topAnchor.constraint(equalTo: keepAbsentFilesButton.bottomAnchor, constant: 10),

            fileChangeDetectionButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            fileChangeDetectionButton.topAnchor.constraint(equalTo: autoReloadButton.bottomAnchor, constant: 10),

            openAnsiAsUtf8Button.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            openAnsiAsUtf8Button.topAnchor.constraint(equalTo: fileChangeDetectionButton.bottomAnchor, constant: 10),

            defaultSaveDirLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            defaultSaveDirLabel.topAnchor.constraint(equalTo: openAnsiAsUtf8Button.bottomAnchor, constant: 14),
            defaultSaveDirLabel.widthAnchor.constraint(equalToConstant: 260),

            defaultSaveDirField.leadingAnchor.constraint(equalTo: defaultSaveDirLabel.trailingAnchor, constant: 8),
            defaultSaveDirField.centerYAnchor.constraint(equalTo: defaultSaveDirLabel.centerYAnchor),
            defaultSaveDirField.widthAnchor.constraint(equalToConstant: 160),

            snapshotModeButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            snapshotModeButton.topAnchor.constraint(equalTo: defaultSaveDirLabel.bottomAnchor, constant: 10),

            periodicBackupLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            periodicBackupLabel.topAnchor.constraint(equalTo: snapshotModeButton.bottomAnchor, constant: 10),

            periodicBackupField.leadingAnchor.constraint(equalTo: periodicBackupLabel.trailingAnchor, constant: 8),
            periodicBackupField.centerYAnchor.constraint(equalTo: periodicBackupLabel.centerYAnchor),
            periodicBackupField.widthAnchor.constraint(equalToConstant: 56),

            periodicBackupStepper.leadingAnchor.constraint(equalTo: periodicBackupField.trailingAnchor, constant: 4),
            periodicBackupStepper.centerYAnchor.constraint(equalTo: periodicBackupField.centerYAnchor),

            backupOnSaveLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            backupOnSaveLabel.topAnchor.constraint(equalTo: periodicBackupLabel.bottomAnchor, constant: 10),

            backupOnSavePopup.leadingAnchor.constraint(equalTo: backupOnSaveLabel.trailingAnchor, constant: 8),
            backupOnSavePopup.centerYAnchor.constraint(equalTo: backupOnSaveLabel.centerYAnchor),

            useCustomBackupDirButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            useCustomBackupDirButton.topAnchor.constraint(equalTo: backupOnSaveLabel.bottomAnchor, constant: 10),

            customBackupDirField.leadingAnchor.constraint(equalTo: useCustomBackupDirButton.trailingAnchor, constant: 8),
            customBackupDirField.centerYAnchor.constraint(equalTo: useCustomBackupDirButton.centerYAnchor),
            customBackupDirField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),

            customBackupDirBrowseButton.leadingAnchor.constraint(equalTo: customBackupDirField.trailingAnchor, constant: 8),
            customBackupDirBrowseButton.centerYAnchor.constraint(equalTo: customBackupDirField.centerYAnchor),

            openDirFollowsDocButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            openDirFollowsDocButton.topAnchor.constraint(equalTo: useCustomBackupDirButton.bottomAnchor, constant: 10),

            folderDropAsWorkspaceButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            folderDropAsWorkspaceButton.topAnchor.constraint(equalTo: openDirFollowsDocButton.bottomAnchor, constant: 10),

            folderDropRecursiveOpenButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            folderDropRecursiveOpenButton.topAnchor.constraint(equalTo: folderDropAsWorkspaceButton.bottomAnchor, constant: 8),

            defaultLangLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            defaultLangLabel.topAnchor.constraint(equalTo: folderDropRecursiveOpenButton.bottomAnchor, constant: 14),

            defaultLangPopup.leadingAnchor.constraint(equalTo: defaultLangLabel.trailingAnchor, constant: 10),
            defaultLangPopup.centerYAnchor.constraint(equalTo: defaultLangLabel.centerYAnchor),
            defaultLangPopup.widthAnchor.constraint(equalToConstant: 160),

            printSectionLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printSectionLabel.topAnchor.constraint(equalTo: defaultLangLabel.bottomAnchor, constant: 20),

            printLineNumbersButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printLineNumbersButton.topAnchor.constraint(equalTo: printSectionLabel.bottomAnchor, constant: 10),

            printHeaderSectionLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printHeaderSectionLabel.topAnchor.constraint(equalTo: printLineNumbersButton.bottomAnchor, constant: 10),

            printHeaderLeftField.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printHeaderLeftField.topAnchor.constraint(equalTo: printHeaderSectionLabel.bottomAnchor, constant: 6),
            printHeaderLeftField.widthAnchor.constraint(equalToConstant: 120),

            printHeaderCenterField.leadingAnchor.constraint(equalTo: printHeaderLeftField.trailingAnchor, constant: 6),
            printHeaderCenterField.centerYAnchor.constraint(equalTo: printHeaderLeftField.centerYAnchor),
            printHeaderCenterField.widthAnchor.constraint(equalToConstant: 120),

            printHeaderRightField.leadingAnchor.constraint(equalTo: printHeaderCenterField.trailingAnchor, constant: 6),
            printHeaderRightField.centerYAnchor.constraint(equalTo: printHeaderLeftField.centerYAnchor),
            printHeaderRightField.widthAnchor.constraint(equalToConstant: 120),

            printFooterSectionLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printFooterSectionLabel.topAnchor.constraint(equalTo: printHeaderLeftField.bottomAnchor, constant: 10),

            printFooterLeftField.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printFooterLeftField.topAnchor.constraint(equalTo: printFooterSectionLabel.bottomAnchor, constant: 6),
            printFooterLeftField.widthAnchor.constraint(equalToConstant: 120),

            printFooterCenterField.leadingAnchor.constraint(equalTo: printFooterLeftField.trailingAnchor, constant: 6),
            printFooterCenterField.centerYAnchor.constraint(equalTo: printFooterLeftField.centerYAnchor),
            printFooterCenterField.widthAnchor.constraint(equalToConstant: 120),

            printFooterRightField.leadingAnchor.constraint(equalTo: printFooterCenterField.trailingAnchor, constant: 6),
            printFooterRightField.centerYAnchor.constraint(equalTo: printFooterLeftField.centerYAnchor),
            printFooterRightField.widthAnchor.constraint(equalToConstant: 120),

            printColorModeLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printColorModeLabel.topAnchor.constraint(equalTo: printFooterLeftField.bottomAnchor, constant: 10),
            printColorModeLabel.widthAnchor.constraint(equalToConstant: 80),

            printColorModePopup.leadingAnchor.constraint(equalTo: printColorModeLabel.trailingAnchor, constant: 8),
            printColorModePopup.centerYAnchor.constraint(equalTo: printColorModeLabel.centerYAnchor),
            printColorModePopup.widthAnchor.constraint(equalToConstant: 180),

            printFontSizeLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printFontSizeLabel.topAnchor.constraint(equalTo: printColorModeLabel.bottomAnchor, constant: 10),
            printFontSizeLabel.widthAnchor.constraint(equalToConstant: 130),

            printFontSizeField.leadingAnchor.constraint(equalTo: printFontSizeLabel.trailingAnchor, constant: 8),
            printFontSizeField.centerYAnchor.constraint(equalTo: printFontSizeLabel.centerYAnchor),
            printFontSizeField.widthAnchor.constraint(equalToConstant: 50),

            printFontSizeStepper.leadingAnchor.constraint(equalTo: printFontSizeField.trailingAnchor, constant: 6),
            printFontSizeStepper.centerYAnchor.constraint(equalTo: printFontSizeField.centerYAnchor),

            printMarginsLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printMarginsLabel.topAnchor.constraint(equalTo: printFontSizeLabel.bottomAnchor, constant: 10),
            printMarginsLabel.widthAnchor.constraint(equalToConstant: 80),

            printMarginTopLabel.leadingAnchor.constraint(equalTo: printMarginsLabel.trailingAnchor, constant: 8),
            printMarginTopLabel.centerYAnchor.constraint(equalTo: printMarginsLabel.centerYAnchor),
            printMarginTopLabel.widthAnchor.constraint(equalToConstant: 32),

            printMarginTopField.leadingAnchor.constraint(equalTo: printMarginTopLabel.trailingAnchor, constant: 4),
            printMarginTopField.centerYAnchor.constraint(equalTo: printMarginsLabel.centerYAnchor),
            printMarginTopField.widthAnchor.constraint(equalToConstant: 50),

            printMarginBottomLabel.leadingAnchor.constraint(equalTo: printMarginTopField.trailingAnchor, constant: 10),
            printMarginBottomLabel.centerYAnchor.constraint(equalTo: printMarginsLabel.centerYAnchor),
            printMarginBottomLabel.widthAnchor.constraint(equalToConstant: 48),

            printMarginBottomField.leadingAnchor.constraint(equalTo: printMarginBottomLabel.trailingAnchor, constant: 4),
            printMarginBottomField.centerYAnchor.constraint(equalTo: printMarginsLabel.centerYAnchor),
            printMarginBottomField.widthAnchor.constraint(equalToConstant: 50),

            printMarginLeftLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            printMarginLeftLabel.topAnchor.constraint(equalTo: printMarginsLabel.bottomAnchor, constant: 8),
            printMarginLeftLabel.widthAnchor.constraint(equalToConstant: 80),

            printMarginLeftField.leadingAnchor.constraint(equalTo: printMarginLeftLabel.trailingAnchor, constant: 8),
            printMarginLeftField.centerYAnchor.constraint(equalTo: printMarginLeftLabel.centerYAnchor),
            printMarginLeftField.widthAnchor.constraint(equalToConstant: 50),

            printMarginRightLabel.leadingAnchor.constraint(equalTo: printMarginLeftField.trailingAnchor, constant: 10),
            printMarginRightLabel.centerYAnchor.constraint(equalTo: printMarginLeftLabel.centerYAnchor),
            printMarginRightLabel.widthAnchor.constraint(equalToConstant: 40),

            printMarginRightField.leadingAnchor.constraint(equalTo: printMarginRightLabel.trailingAnchor, constant: 4),
            printMarginRightField.centerYAnchor.constraint(equalTo: printMarginLeftLabel.centerYAnchor),
            printMarginRightField.widthAnchor.constraint(equalToConstant: 50),

            sessionCV.bottomAnchor.constraint(equalTo: printMarginLeftLabel.bottomAnchor, constant: 24)
        ])

        // ── Tab 3: Find & Tools ────────────────────────────────
        NSLayoutConstraint.activate([
            findDefaultsSectionLabel.leadingAnchor.constraint(equalTo: toolsCV.leadingAnchor, constant: lead),
            findDefaultsSectionLabel.topAnchor.constraint(equalTo: toolsCV.topAnchor, constant: 20),

            searchMatchCaseButton.leadingAnchor.constraint(equalTo: toolsCV.leadingAnchor, constant: indent),
            searchMatchCaseButton.centerYAnchor.constraint(equalTo: findDefaultsSectionLabel.centerYAnchor),

            searchWholeWordButton.leadingAnchor.constraint(equalTo: searchMatchCaseButton.trailingAnchor, constant: 20),
            searchWholeWordButton.centerYAnchor.constraint(equalTo: searchMatchCaseButton.centerYAnchor),

            dateTimeSectionLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            dateTimeSectionLabel.topAnchor.constraint(equalTo: findDefaultsSectionLabel.bottomAnchor, constant: 20),

            dateTimeFormatLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            dateTimeFormatLabel.topAnchor.constraint(equalTo: dateTimeSectionLabel.bottomAnchor, constant: 14),
            dateTimeFormatLabel.widthAnchor.constraint(equalToConstant: 92),

            dateTimeFormatField.leadingAnchor.constraint(equalTo: dateTimeFormatLabel.trailingAnchor, constant: 12),
            dateTimeFormatField.centerYAnchor.constraint(equalTo: dateTimeFormatLabel.centerYAnchor),
            dateTimeFormatField.trailingAnchor.constraint(equalTo: toolsCV.trailingAnchor, constant: -18),

            searchEngineSectionLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            searchEngineSectionLabel.topAnchor.constraint(equalTo: dateTimeFormatLabel.bottomAnchor, constant: 20),

            searchEngineChoiceLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            searchEngineChoiceLabel.topAnchor.constraint(equalTo: searchEngineSectionLabel.bottomAnchor, constant: 14),
            searchEngineChoiceLabel.widthAnchor.constraint(equalToConstant: 92),

            searchEnginePopup.leadingAnchor.constraint(equalTo: searchEngineChoiceLabel.trailingAnchor, constant: 12),
            searchEnginePopup.centerYAnchor.constraint(equalTo: searchEngineChoiceLabel.centerYAnchor),
            searchEnginePopup.trailingAnchor.constraint(equalTo: toolsCV.trailingAnchor, constant: -18),

            searchEngineCustomURLLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            searchEngineCustomURLLabel.topAnchor.constraint(equalTo: searchEngineChoiceLabel.bottomAnchor, constant: 14),
            searchEngineCustomURLLabel.widthAnchor.constraint(equalToConstant: 92),

            searchEngineCustomURLField.leadingAnchor.constraint(equalTo: searchEngineCustomURLLabel.trailingAnchor, constant: 12),
            searchEngineCustomURLField.centerYAnchor.constraint(equalTo: searchEngineCustomURLLabel.centerYAnchor),
            searchEngineCustomURLField.trailingAnchor.constraint(equalTo: toolsCV.trailingAnchor, constant: -18),

            extraURLSchemesLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            extraURLSchemesLabel.topAnchor.constraint(equalTo: searchEngineCustomURLLabel.bottomAnchor, constant: 14),
            extraURLSchemesLabel.widthAnchor.constraint(equalToConstant: 160),

            extraURLSchemesField.leadingAnchor.constraint(equalTo: extraURLSchemesLabel.trailingAnchor, constant: 12),
            extraURLSchemesField.centerYAnchor.constraint(equalTo: extraURLSchemesLabel.centerYAnchor),
            extraURLSchemesField.trailingAnchor.constraint(equalTo: toolsCV.trailingAnchor, constant: -18),

            localizationSectionLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            localizationSectionLabel.topAnchor.constraint(equalTo: extraURLSchemesLabel.bottomAnchor, constant: 20),

            localizationChoiceLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            localizationChoiceLabel.topAnchor.constraint(equalTo: localizationSectionLabel.bottomAnchor, constant: 14),
            localizationChoiceLabel.widthAnchor.constraint(equalToConstant: 92),

            localizationPopup.leadingAnchor.constraint(equalTo: localizationChoiceLabel.trailingAnchor, constant: 12),
            localizationPopup.centerYAnchor.constraint(equalTo: localizationChoiceLabel.centerYAnchor),
            localizationPopup.trailingAnchor.constraint(equalTo: toolsCV.trailingAnchor, constant: -18),

            inSelectionSectionLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            inSelectionSectionLabel.topAnchor.constraint(equalTo: localizationPopup.bottomAnchor, constant: 20),

            inSelectionThresholdLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            inSelectionThresholdLabel.topAnchor.constraint(equalTo: inSelectionSectionLabel.bottomAnchor, constant: 14),
            inSelectionThresholdLabel.widthAnchor.constraint(equalToConstant: 220),

            inSelectionThresholdField.leadingAnchor.constraint(equalTo: inSelectionThresholdLabel.trailingAnchor, constant: 8),
            inSelectionThresholdField.centerYAnchor.constraint(equalTo: inSelectionThresholdLabel.centerYAnchor),
            inSelectionThresholdField.widthAnchor.constraint(equalToConstant: 70),

            inSelectionThresholdStepper.leadingAnchor.constraint(equalTo: inSelectionThresholdField.trailingAnchor, constant: 6),
            inSelectionThresholdStepper.centerYAnchor.constraint(equalTo: inSelectionThresholdField.centerYAnchor),

            keepFindDialogOpenButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            keepFindDialogOpenButton.topAnchor.constraint(equalTo: inSelectionThresholdLabel.bottomAnchor, constant: 10),

            replaceDoesNotMoveButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            replaceDoesNotMoveButton.topAnchor.constraint(equalTo: keepFindDialogOpenButton.bottomAnchor, constant: 10),

            findDialogMonospaceButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            findDialogMonospaceButton.topAnchor.constraint(equalTo: replaceDoesNotMoveButton.bottomAnchor, constant: 10),

            fillFindFromSelectionButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            fillFindFromSelectionButton.topAnchor.constraint(equalTo: findDialogMonospaceButton.bottomAnchor, constant: 10),

            autoSelectWordUnderCaretButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            autoSelectWordUnderCaretButton.topAnchor.constraint(equalTo: fillFindFromSelectionButton.bottomAnchor, constant: 10),

            findInFilesIgnoreUnsavedButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            findInFilesIgnoreUnsavedButton.topAnchor.constraint(equalTo: autoSelectWordUnderCaretButton.bottomAnchor, constant: 10),

            confirmReplaceInAllDocsButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            confirmReplaceInAllDocsButton.topAnchor.constraint(equalTo: findInFilesIgnoreUnsavedButton.bottomAnchor, constant: 10),

            perLineResultButton.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            perLineResultButton.topAnchor.constraint(equalTo: confirmReplaceInAllDocsButton.bottomAnchor, constant: 10),

            maxFindHistoryLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            maxFindHistoryLabel.topAnchor.constraint(equalTo: perLineResultButton.bottomAnchor, constant: 10),
            maxFindHistoryLabel.widthAnchor.constraint(equalToConstant: 200),

            maxFindHistoryField.leadingAnchor.constraint(equalTo: maxFindHistoryLabel.trailingAnchor, constant: 8),
            maxFindHistoryField.centerYAnchor.constraint(equalTo: maxFindHistoryLabel.centerYAnchor),
            maxFindHistoryField.widthAnchor.constraint(equalToConstant: 50),

            maxFindHistoryStepper.leadingAnchor.constraint(equalTo: maxFindHistoryField.trailingAnchor, constant: 4),
            maxFindHistoryStepper.centerYAnchor.constraint(equalTo: maxFindHistoryLabel.centerYAnchor),

            findTransparencyLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            findTransparencyLabel.topAnchor.constraint(equalTo: maxFindHistoryLabel.bottomAnchor, constant: 14),
            findTransparencyLabel.widthAnchor.constraint(equalToConstant: 240),

            findTransparencySlider.leadingAnchor.constraint(equalTo: findTransparencyLabel.trailingAnchor, constant: 8),
            findTransparencySlider.centerYAnchor.constraint(equalTo: findTransparencyLabel.centerYAnchor),
            findTransparencySlider.widthAnchor.constraint(equalToConstant: 120),

            toolsCV.bottomAnchor.constraint(equalTo: findTransparencyLabel.bottomAnchor, constant: 24)
        ])

        // ── Tab 4: Window ──────────────────────────────────────
        NSLayoutConstraint.activate([
            tabbarSectionLabel.leadingAnchor.constraint(equalTo: windowCV.leadingAnchor, constant: lead),
            tabbarSectionLabel.topAnchor.constraint(equalTo: windowCV.topAnchor, constant: 20),

            tabbarHideButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarHideButton.topAnchor.constraint(equalTo: tabbarSectionLabel.bottomAnchor, constant: 14),

            tabbarDoubleClickCloseButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarDoubleClickCloseButton.topAnchor.constraint(equalTo: tabbarHideButton.bottomAnchor, constant: 10),

            tabbarLockDragDropButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarLockDragDropButton.topAnchor.constraint(equalTo: tabbarDoubleClickCloseButton.bottomAnchor, constant: 10),

            tabbarExitOnLastTabButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarExitOnLastTabButton.topAnchor.constraint(equalTo: tabbarLockDragDropButton.bottomAnchor, constant: 10),

            tabbarShowCloseButtonButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarShowCloseButtonButton.topAnchor.constraint(equalTo: tabbarExitOnLastTabButton.bottomAnchor, constant: 10),
            tabbarCompactButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarCompactButton.topAnchor.constraint(equalTo: tabbarShowCloseButtonButton.bottomAnchor, constant: 10),

            tabbarMaxLabelLengthLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarMaxLabelLengthLabel.topAnchor.constraint(equalTo: tabbarCompactButton.bottomAnchor, constant: 14),
            tabbarMaxLabelLengthLabel.widthAnchor.constraint(equalToConstant: 200),

            tabbarMaxLabelLengthField.leadingAnchor.constraint(equalTo: tabbarMaxLabelLengthLabel.trailingAnchor, constant: 8),
            tabbarMaxLabelLengthField.centerYAnchor.constraint(equalTo: tabbarMaxLabelLengthLabel.centerYAnchor),
            tabbarMaxLabelLengthField.widthAnchor.constraint(equalToConstant: 60),

            tabbarMaxLabelLengthStepper.leadingAnchor.constraint(equalTo: tabbarMaxLabelLengthField.trailingAnchor, constant: 6),
            tabbarMaxLabelLengthStepper.centerYAnchor.constraint(equalTo: tabbarMaxLabelLengthField.centerYAnchor),

            delimiterSectionLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            delimiterSectionLabel.topAnchor.constraint(equalTo: tabbarMaxLabelLengthLabel.bottomAnchor, constant: 20),

            delimiterLeftLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            delimiterLeftLabel.topAnchor.constraint(equalTo: delimiterSectionLabel.bottomAnchor, constant: 10),
            delimiterLeftLabel.widthAnchor.constraint(equalToConstant: 180),

            delimiterLeftField.leadingAnchor.constraint(equalTo: delimiterLeftLabel.trailingAnchor, constant: 8),
            delimiterLeftField.centerYAnchor.constraint(equalTo: delimiterLeftLabel.centerYAnchor),
            delimiterLeftField.widthAnchor.constraint(equalToConstant: 60),

            delimiterRightLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            delimiterRightLabel.topAnchor.constraint(equalTo: delimiterLeftLabel.bottomAnchor, constant: 10),
            delimiterRightLabel.widthAnchor.constraint(equalToConstant: 180),

            delimiterRightField.leadingAnchor.constraint(equalTo: delimiterRightLabel.trailingAnchor, constant: 8),
            delimiterRightField.centerYAnchor.constraint(equalTo: delimiterRightLabel.centerYAnchor),
            delimiterRightField.widthAnchor.constraint(equalToConstant: 60),

            generalSectionLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            generalSectionLabel.topAnchor.constraint(equalTo: delimiterRightLabel.bottomAnchor, constant: 20),

            statusBarVisibleButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            statusBarVisibleButton.topAnchor.constraint(equalTo: generalSectionLabel.bottomAnchor, constant: 10),

            shortTitleButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            shortTitleButton.topAnchor.constraint(equalTo: statusBarVisibleButton.bottomAnchor, constant: 10),

            saveAllConfirmButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            saveAllConfirmButton.topAnchor.constraint(equalTo: shortTitleButton.bottomAnchor, constant: 10),

            autoCompleteIgnoreNumbersButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            autoCompleteIgnoreNumbersButton.topAnchor.constraint(equalTo: saveAllConfirmButton.bottomAnchor, constant: 10),

            toolbarIconSizeLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            toolbarIconSizeLabel.topAnchor.constraint(equalTo: autoCompleteIgnoreNumbersButton.bottomAnchor, constant: 10),
            toolbarIconSizeLabel.widthAnchor.constraint(equalToConstant: 120),

            toolbarIconSizeSegmented.leadingAnchor.constraint(equalTo: toolbarIconSizeLabel.trailingAnchor, constant: 8),
            toolbarIconSizeSegmented.centerYAnchor.constraint(equalTo: toolbarIconSizeLabel.centerYAnchor),

            scintillaRenderingLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            scintillaRenderingLabel.topAnchor.constraint(equalTo: toolbarIconSizeLabel.bottomAnchor, constant: 10),
            scintillaRenderingLabel.widthAnchor.constraint(equalToConstant: 150),

            scintillaRenderingPopup.leadingAnchor.constraint(equalTo: scintillaRenderingLabel.trailingAnchor, constant: 8),
            scintillaRenderingPopup.centerYAnchor.constraint(equalTo: scintillaRenderingLabel.centerYAnchor),
            scintillaRenderingPopup.widthAnchor.constraint(equalToConstant: 180),

            disableAdvancedScrollingButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            disableAdvancedScrollingButton.topAnchor.constraint(equalTo: scintillaRenderingLabel.bottomAnchor, constant: 10),

            rightClickKeepSelectionButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            rightClickKeepSelectionButton.topAnchor.constraint(equalTo: disableAdvancedScrollingButton.bottomAnchor, constant: 6),

            edgeModeLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            edgeModeLabel.topAnchor.constraint(equalTo: rightClickKeepSelectionButton.bottomAnchor, constant: 10),
            edgeModeLabel.widthAnchor.constraint(equalToConstant: 120),

            edgeModePopup.leadingAnchor.constraint(equalTo: edgeModeLabel.trailingAnchor, constant: 8),
            edgeModePopup.centerYAnchor.constraint(equalTo: edgeModeLabel.centerYAnchor),
            edgeModePopup.widthAnchor.constraint(equalToConstant: 180),

            foldFlagsLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            foldFlagsLabel.topAnchor.constraint(equalTo: edgeModeLabel.bottomAnchor, constant: 10),
            foldFlagsLabel.widthAnchor.constraint(equalToConstant: 120),

            foldFlagsPopup.leadingAnchor.constraint(equalTo: foldFlagsLabel.trailingAnchor, constant: 8),
            foldFlagsPopup.centerYAnchor.constraint(equalTo: foldFlagsLabel.centerYAnchor),
            foldFlagsPopup.widthAnchor.constraint(equalToConstant: 220),

            foldCompactButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            foldCompactButton.topAnchor.constraint(equalTo: foldFlagsLabel.bottomAnchor, constant: 10),

            reloadScrollToLastCaretButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            reloadScrollToLastCaretButton.topAnchor.constraint(equalTo: foldCompactButton.bottomAnchor, constant: 10),

            appearanceSectionLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            appearanceSectionLabel.topAnchor.constraint(equalTo: reloadScrollToLastCaretButton.bottomAnchor, constant: 18),

            appearanceModeLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            appearanceModeLabel.topAnchor.constraint(equalTo: appearanceSectionLabel.bottomAnchor, constant: 12),
            appearanceModeLabel.widthAnchor.constraint(equalToConstant: 100),

            appearanceModeSegmented.leadingAnchor.constraint(equalTo: appearanceModeLabel.trailingAnchor, constant: 10),
            appearanceModeSegmented.centerYAnchor.constraint(equalTo: appearanceModeLabel.centerYAnchor),

            postItSectionLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            postItSectionLabel.topAnchor.constraint(equalTo: appearanceModeLabel.bottomAnchor, constant: 20),

            postItAlphaLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            postItAlphaLabel.topAnchor.constraint(equalTo: postItSectionLabel.bottomAnchor, constant: 12),
            postItAlphaLabel.widthAnchor.constraint(equalToConstant: 120),

            postItAlphaSlider.leadingAnchor.constraint(equalTo: postItAlphaLabel.trailingAnchor, constant: 10),
            postItAlphaSlider.centerYAnchor.constraint(equalTo: postItAlphaLabel.centerYAnchor),
            postItAlphaSlider.widthAnchor.constraint(equalToConstant: 160),

            windowCV.bottomAnchor.constraint(equalTo: postItAlphaLabel.bottomAnchor, constant: 24)
        ])
    }

    private func loadPreferences() {
        let preferences = preferencesStore.load()
        fontSizeField.doubleValue = preferences.editorFontSize
        fontSizeStepper.doubleValue = preferences.editorFontSize
        editorFontNameField.stringValue = preferences.editorFontName
        editorFontBoldButton.state = preferences.editorFontBold ? .on : .off
        wrapsLinesButton.state = preferences.wrapsLines ? .on : .off
        tabSizeField.intValue = Int32(preferences.tabSize)
        tabSizeStepper.intValue = Int32(preferences.tabSize)
        insertSpacesButton.state = preferences.insertSpacesInsteadOfTabs ? .on : .off
        autoPairButton.state = preferences.enableAutoPair ? .on : .off
        autoPairParenthesesButton.state = preferences.autoPairParentheses ? .on : .off
        autoPairBracketsButton.state = preferences.autoPairBrackets ? .on : .off
        autoPairCurlyBracketsButton.state = preferences.autoPairCurlyBrackets ? .on : .off
        autoPairSingleQuotesButton.state = preferences.autoPairSingleQuotes ? .on : .off
        autoPairDoubleQuotesButton.state = preferences.autoPairDoubleQuotes ? .on : .off
        customPairsData = preferences.customMatchedPairs
        customPairsTableView.reloadData()
        xmlTagMatchButton.state = preferences.enableXmlTagMatch ? .on : .off
        xmlTagAttributeHighlightButton.state = preferences.xmlTagAttributeHighlight ? .on : .off
        highlightNonHtmlZoneButton.state = preferences.highlightNonHtmlZone ? .on : .off
        clickableLinksButton.state = preferences.enableClickableLinks ? .on : .off
        smartHighlightMatchCaseButton.state = preferences.smartHighlightMatchCase ? .on : .off
        smartHighlightWholeWordButton.state = preferences.smartHighlightWholeWord ? .on : .off
        markAllMatchCaseButton.state = preferences.markAllMatchCase ? .on : .off
        markAllWholeWordButton.state = preferences.markAllWholeWord ? .on : .off
        langMenuCompactButton.state = preferences.langMenuCompact ? .on : .off
        caretWidthSegmented.selectedSegment = max(0, min(2, preferences.caretWidth - 1))
        caretNoBlinkButton.state = preferences.caretNoBlink ? .on : .off
        caretBlinkRateField.intValue = Int32(preferences.caretBlinkRate)
        caretBlinkRateStepper.intValue = Int32(preferences.caretBlinkRate)
        caretStickyModePopup.selectItem(at: max(0, min(2, preferences.caretStickyMode)))
        currentLineFrameSegmented.selectedSegment = max(0, min(3, preferences.currentLineFrameWidth))
        lineWrapIndentPopup.selectItem(at: max(0, min(3, preferences.lineWrapIndent)))
        enableCodeFoldingButton.state = preferences.enableCodeFolding ? .on : .off
        foldMarginStylePopup.selectItem(at: max(0, min(2, preferences.foldMarginStyle)))
        useFirstLineAsTabNameButton.state = preferences.useFirstLineAsTabName ? .on : .off
        recentFilesMaxField.intValue = Int32(preferences.recentFilesMaxCount)
        recentFilesMaxStepper.intValue = Int32(preferences.recentFilesMaxCount)
        recentFilesShowFullPathButton.state = preferences.recentFilesShowFullPath ? .on : .off
        recentFilesInSubmenuButton.state = preferences.recentFilesInSubmenu ? .on : .off
        recentFilesCustomLengthField.intValue = Int32(preferences.recentFilesCustomDisplayLength)
        recentFilesCustomLengthStepper.intValue = Int32(preferences.recentFilesCustomDisplayLength)
        noCheckRecentAtLaunchButton.state = preferences.noCheckRecentAtLaunch ? .on : .off
        keepAbsentFilesButton.state = preferences.keepAbsentFilesInSession ? .on : .off
        autoReloadButton.state = preferences.autoReloadOnExternalChange ? .on : .off
        fileChangeDetectionButton.state = preferences.fileChangeDetectionEnabled ? .on : .off
        openAnsiAsUtf8Button.state = preferences.openAnsiAsUtf8 ? .on : .off
        defaultSaveDirField.stringValue = preferences.defaultSaveDirectory
        snapshotModeButton.state = preferences.snapshotModeEnabled ? .on : .off
        periodicBackupField.intValue = Int32(preferences.periodicBackupIntervalSeconds)
        periodicBackupStepper.intValue = Int32(preferences.periodicBackupIntervalSeconds)
        selectBackupOnSaveMode(preferences.backupOnSaveMode)
        useCustomBackupDirButton.state = preferences.useCustomBackupDirectory ? .on : .off
        customBackupDirField.stringValue = preferences.customBackupDirectory
        updateCustomBackupDirEnabled()
        printLineNumbersButton.state = preferences.printLineNumbers ? .on : .off
        openDirFollowsDocButton.state = preferences.openDirectoryFollowsDocument ? .on : .off
        folderDropAsWorkspaceButton.state = preferences.folderDropOpensAsWorkspace ? .on : .off
        folderDropRecursiveOpenButton.state = preferences.folderDropRecursiveOpen ? .on : .off
        populateDefaultLangPopup(selected: preferences.defaultNewDocumentLanguageName)
        virtualSpaceButton.state = preferences.enableVirtualSpace ? .on : .off
        backspaceUnindentsButton.state = preferences.backspaceUnindents ? .on : .off
        autoIndentButton.state = preferences.autoIndent ? .on : .off
        scrollBeyondLastLineButton.state = preferences.scrollBeyondLastLine ? .on : .off
        selectedTextDragDropButton.state = preferences.selectedTextDragDrop ? .on : .off
        lineNumberDynamicWidthButton.state = preferences.lineNumberDynamicWidth ? .on : .off
        columnSelectionToMultiEditingButton.state = preferences.columnSelectionToMultiEditing ? .on : .off
        showBookmarkMarginButton.state = preferences.showBookmarkMargin ? .on : .off
        showEdgeLineButton.state = preferences.showEdgeLine ? .on : .off
        edgeLineColumnField.intValue = Int32(preferences.edgeLineColumn)
        edgeLineColumnStepper.intValue = Int32(preferences.edgeLineColumn)
        showLineNumberMarginButton.state = preferences.showLineNumberMargin ? .on : .off
        showWhitespaceButton.state = preferences.whitespaceDisplayMode > 0 ? .on : .off
        whitespaceDisplayModePopup.selectItem(at: max(0, min(3, preferences.whitespaceDisplayMode)))
        bidiModePopup.selectItem(at: max(0, min(2, preferences.bidiMode)))
        showEOLButton.state = preferences.showEOL ? .on : .off
        showIndentGuidesButton.state = preferences.showIndentGuides ? .on : .off
        highlightCurrentLineButton.state = preferences.highlightCurrentLine ? .on : .off
        showNpcCharactersButton.state = preferences.showNpcCharacters ? .on : .off
        showWrapSymbolButton.state = preferences.showWrapSymbol ? .on : .off
        showChangeHistoryButton.state = preferences.showChangeHistory ? .on : .off
        linePaddingSegmented.selectedSegment = max(0, min(5, preferences.linePadding))
        autoCompleteField.intValue = Int32(preferences.autoCompleteFromNthChar)
        autoCompleteStepper.intValue = Int32(preferences.autoCompleteFromNthChar)
        autoCompleteModePopup.selectItem(at: max(0, min(3, preferences.autoCompleteMode)))
        autoCompleteChooseSingleButton.state = preferences.autoCompleteChooseSingle ? .on : .off
        autoCompleteTABFillupButton.state = preferences.autoCompleteTABFillup ? .on : .off
        autoCompleteEnterCommitButton.state = preferences.autoCompleteEnterCommit ? .on : .off
        autoCompleteBriefButton.state = preferences.autoCompleteBrief ? .on : .off
        autoCompleteIgnoreCaseButton.state = preferences.autoCompleteIgnoreCase ? .on : .off
        htmlXmlCloseTagButton.state = preferences.htmlXmlCloseTagEnabled ? .on : .off
        muteAllSoundsButton.state = preferences.muteAllSounds ? .on : .off
        trimTrailingSpacesOnSaveButton.state = preferences.trimTrailingSpacesOnSave ? .on : .off
        pasteConvertEndingsButton.state = preferences.pasteConvertEndings ? .on : .off
        smoothFontButton.state = preferences.smoothFont ? .on : .off
        multiEditEnabledButton.state = preferences.multiEditEnabled ? .on : .off
        multiPasteModePopup.selectItem(at: preferences.multiPasteMode)
        indentGuideModePopup.selectItem(at: preferences.indentGuideMode)
        wordWrapModePopup.selectItem(at: preferences.wordWrapMode)
        additionalSelAlphaField.intValue = Int32(preferences.additionalSelAlpha)
        additionalSelAlphaStepper.intValue = Int32(preferences.additionalSelAlpha)
        additionalCaretsBlinkButton.state = preferences.additionalCaretsBlink ? .on : .off
        additionalCaretsVisibleButton.state = preferences.additionalCaretsVisible ? .on : .off
        caretLineVisibleAlwaysButton.state = preferences.caretLineVisibleAlways ? .on : .off
        whitespaceSizeField.intValue = Int32(preferences.whitespaceSize)
        whitespaceSizeStepper.intValue = Int32(preferences.whitespaceSize)
        selectionAlphaField.intValue = Int32(preferences.selectionAlpha)
        selectionAlphaStepper.intValue = Int32(preferences.selectionAlpha)
        controlCharDisplayPopup.selectItem(at: preferences.controlCharDisplay)
        autoIndentModePopup.selectItem(at: preferences.autoIndentMode)
        fileAutoDetectionPopup.selectItem(at: preferences.fileAutoDetection)
        updateSilentlyButton.state = preferences.updateSilently ? .on : .off
        zoomSyncToAllTabsButton.state = preferences.zoomSyncToAllTabs ? .on : .off
        hideMenuShortcutsButton.state = preferences.hideMenuShortcuts ? .on : .off
        scrollToLastLineOnMonitorReloadButton.state = preferences.scrollToLastLineOnMonitorReload ? .on : .off
        inSelectionThresholdField.intValue = Int32(preferences.inSelectionThreshold)
        inSelectionThresholdStepper.intValue = Int32(preferences.inSelectionThreshold)
        keepFindDialogOpenButton.state = preferences.keepFindDialogOpen ? .on : .off
        replaceDoesNotMoveButton.state = preferences.replaceDoesNotMove ? .on : .off
        findDialogMonospaceButton.state = preferences.findDialogMonospace ? .on : .off
        fillFindFromSelectionButton.state = preferences.fillFindFromSelection ? .on : .off
        autoSelectWordUnderCaretButton.state = preferences.autoSelectWordUnderCaret ? .on : .off
        findInFilesIgnoreUnsavedButton.state = preferences.findInFilesIgnoreUnsaved ? .on : .off
        confirmReplaceInAllDocsButton.state = preferences.confirmReplaceInAllDocs ? .on : .off
        perLineResultButton.state = preferences.perLineResultInFind ? .on : .off
        maxFindHistoryField.intValue = Int32(preferences.maxFindHistoryCount)
        maxFindHistoryStepper.intValue = Int32(preferences.maxFindHistoryCount)
        copyLineWithoutSelectionButton.state = preferences.copyLineWithoutSelection ? .on : .off
        smartHighlightUseFindSettingsButton.state = preferences.smartHighlightUseFindSettings ? .on : .off
        urlIndicatorStyleSegmented.selectedSegment = max(0, min(2, preferences.urlIndicatorStyle))
        langTabOverridesField.stringValue = preferences.languageTabOverrides
        taskListTagsField.stringValue = preferences.taskListCustomTags
        findTransparencySlider.doubleValue = preferences.findDialogTransparency
        tabbarHideButton.state = preferences.tabbarHide ? .on : .off
        tabbarDoubleClickCloseButton.state = preferences.tabbarDoubleClickClose ? .on : .off
        tabbarLockDragDropButton.state = preferences.tabbarLockDragDrop ? .on : .off
        tabbarExitOnLastTabButton.state = preferences.tabbarExitOnLastTab ? .on : .off
        tabbarShowCloseButtonButton.state = preferences.tabbarShowCloseButton ? .on : .off
        tabbarCompactButton.state = preferences.tabbarCompact ? .on : .off
        tabbarMaxLabelLengthField.intValue = Int32(preferences.tabbarMaxLabelLength)
        tabbarMaxLabelLengthStepper.intValue = Int32(preferences.tabbarMaxLabelLength)
        let ps = preferences.printSettings
        printHeaderLeftField.stringValue = ps.header.left
        printHeaderCenterField.stringValue = ps.header.center
        printHeaderRightField.stringValue = ps.header.right
        printFooterLeftField.stringValue = ps.footer.left
        printFooterCenterField.stringValue = ps.footer.center
        printFooterRightField.stringValue = ps.footer.right
        printColorModePopup.selectItem(at: max(0, min(1, ps.colorMode)))
        printFontSizeField.intValue = Int32(ps.fontSize)
        printFontSizeStepper.intValue = Int32(ps.fontSize)
        printMarginTopField.intValue = Int32(ps.marginTop)
        printMarginBottomField.intValue = Int32(ps.marginBottom)
        printMarginLeftField.intValue = Int32(ps.marginLeft)
        printMarginRightField.intValue = Int32(ps.marginRight)
        delimiterLeftField.stringValue = preferences.delimiterLeft
        delimiterRightField.stringValue = preferences.delimiterRight
        statusBarVisibleButton.state = preferences.statusBarVisible ? .on : .off
        shortTitleButton.state = preferences.shortTitle ? .on : .off
        saveAllConfirmButton.state = preferences.saveAllConfirm ? .on : .off
        autoCompleteIgnoreNumbersButton.state = preferences.autoCompleteIgnoreNumbers ? .on : .off
        toolbarIconSizeSegmented.selectedSegment = preferences.toolbarIconSizeStyle
        scintillaRenderingPopup.selectItem(at: preferences.scintillaRenderingTechnology)
        disableAdvancedScrollingButton.state = preferences.disableAdvancedScrolling ? .on : .off
        rightClickKeepSelectionButton.state = preferences.rightClickKeepSelection ? .on : .off
        edgeModePopup.selectItem(at: max(0, min(2, preferences.edgeMode)))
        foldFlagsPopup.selectItem(at: preferences.foldFlags == 0 ? 0 : min(preferences.foldFlags / 2, 4))
        foldCompactButton.state = preferences.foldCompact ? .on : .off
        showDocSwitcherButton.state = preferences.showDocSwitcher ? .on : .off
        reloadScrollToLastCaretButton.state = preferences.reloadScrollToLastCaret ? .on : .off
        appearanceModeSegmented.selectedSegment = max(0, min(2, preferences.appearanceMode))
        postItAlphaSlider.doubleValue = max(0.2, min(1.0, preferences.postItAlpha))
        largeFileMBField.intValue = Int32(preferences.largeFileSizeMB)
        largeFileMBStepper.intValue = Int32(preferences.largeFileSizeMB)
        largeFileSuppressAutoCompleteButton.state = preferences.largeFileSuppressAutoComplete ? .on : .off
        largeFileSuppressSmartHighlightButton.state = preferences.largeFileSuppressSmartHighlight ? .on : .off
        largeFileSuppressBraceMatchButton.state = preferences.largeFileSuppressBraceMatch ? .on : .off
        largeFileSuppressWordWrapButton.state = preferences.largeFileSuppressWordWrap ? .on : .off
        largeFileSuppressSyntaxHighlightButton.state = preferences.largeFileSuppressSyntaxHighlight ? .on : .off
        additionalEdgeColumnsField.stringValue = preferences.additionalEdgeColumns
        selectNewDocEncodingPopup(preferences.defaultNewDocumentEncoding)
        selectNewDocLineEndingPopup(preferences.defaultNewDocumentLineEnding)
        rememberSessionButton.state = preferences.rememberLastSession ? .on : .off
        newDocumentOnLaunchButton.state = preferences.newDocumentOnLaunch ? .on : .off
        searchMatchCaseButton.state = preferences.searchMatchCase ? .on : .off
        searchWholeWordButton.state = preferences.searchWholeWord ? .on : .off
        dateTimeFormatField.stringValue = preferences.customDateTimeFormat
        populateLocalizationPopup(selectedFileName: preferences.localizationFileName)
        selectSearchEngine(preferences.searchEngineChoice)
        searchEngineCustomURLField.stringValue = preferences.customSearchEngineURL
        extraURLSchemesField.stringValue = preferences.extraURLSchemes
        updateSearchEngineFieldState()
    }

    private func savePreferences(sender: Any?) {
        if sender as? NSTextField === fontSizeField {
            fontSizeStepper.doubleValue = fontSizeField.doubleValue
        } else if fontSizeStepper.doubleValue != fontSizeField.doubleValue {
            fontSizeField.doubleValue = fontSizeStepper.doubleValue
        }

        if sender as? NSTextField === tabSizeField {
            tabSizeStepper.intValue = tabSizeField.intValue
        } else if tabSizeStepper.intValue != tabSizeField.intValue {
            tabSizeField.intValue = tabSizeStepper.intValue
        }

        if sender as? NSTextField === autoCompleteField {
            autoCompleteStepper.intValue = autoCompleteField.intValue
        } else if autoCompleteStepper.intValue != autoCompleteField.intValue {
            autoCompleteField.intValue = autoCompleteStepper.intValue
        }

        if sender as? NSTextField === edgeLineColumnField {
            edgeLineColumnStepper.intValue = edgeLineColumnField.intValue
        } else if edgeLineColumnStepper.intValue != edgeLineColumnField.intValue {
            edgeLineColumnField.intValue = edgeLineColumnStepper.intValue
        }

        if sender as? NSTextField === largeFileMBField {
            largeFileMBStepper.intValue = largeFileMBField.intValue
        } else if largeFileMBStepper.intValue != largeFileMBField.intValue {
            largeFileMBField.intValue = largeFileMBStepper.intValue
        }

        if sender as? NSTextField === recentFilesMaxField {
            recentFilesMaxStepper.intValue = recentFilesMaxField.intValue
        } else if recentFilesMaxStepper.intValue != recentFilesMaxField.intValue {
            recentFilesMaxField.intValue = recentFilesMaxStepper.intValue
        }

        if sender as? NSTextField === recentFilesCustomLengthField {
            recentFilesCustomLengthStepper.intValue = recentFilesCustomLengthField.intValue
        } else if sender as? NSStepper === recentFilesCustomLengthStepper {
            recentFilesCustomLengthField.intValue = recentFilesCustomLengthStepper.intValue
        } else if recentFilesCustomLengthStepper.intValue != recentFilesCustomLengthField.intValue {
            recentFilesCustomLengthStepper.intValue = recentFilesCustomLengthField.intValue
        }

        if sender as? NSTextField === periodicBackupField {
            periodicBackupStepper.intValue = periodicBackupField.intValue
        } else if sender as? NSStepper === periodicBackupStepper {
            periodicBackupField.intValue = periodicBackupStepper.intValue
        } else if periodicBackupStepper.intValue != periodicBackupField.intValue {
            periodicBackupStepper.intValue = periodicBackupField.intValue
        }

        if sender as? NSTextField === inSelectionThresholdField {
            inSelectionThresholdStepper.intValue = inSelectionThresholdField.intValue
        } else if inSelectionThresholdStepper.intValue != inSelectionThresholdField.intValue {
            inSelectionThresholdField.intValue = inSelectionThresholdStepper.intValue
        }

        if sender as? NSTextField === maxFindHistoryField {
            maxFindHistoryStepper.intValue = maxFindHistoryField.intValue
        } else if maxFindHistoryStepper.intValue != maxFindHistoryField.intValue {
            maxFindHistoryField.intValue = maxFindHistoryStepper.intValue
        }

        if sender as? NSTextField === tabbarMaxLabelLengthField {
            tabbarMaxLabelLengthStepper.intValue = tabbarMaxLabelLengthField.intValue
        } else if tabbarMaxLabelLengthStepper.intValue != tabbarMaxLabelLengthField.intValue {
            tabbarMaxLabelLengthField.intValue = tabbarMaxLabelLengthStepper.intValue
        }

        if sender as? NSTextField === printFontSizeField {
            printFontSizeStepper.intValue = printFontSizeField.intValue
        } else if printFontSizeStepper.intValue != printFontSizeField.intValue {
            printFontSizeField.intValue = printFontSizeStepper.intValue
        }

        if sender as? NSButton === useCustomBackupDirButton {
            updateCustomBackupDirEnabled()
        }

        updateSearchEngineFieldState()

        // Load existing preferences to preserve fields not shown in this panel
        let existing = preferencesStore.load()
        let preferences = AppPreferences(
            editorFontSize: fontSizeField.doubleValue,
            wrapsLines: wrapsLinesButton.state == .on,
            searchMatchCase: searchMatchCaseButton.state == .on,
            searchWholeWord: searchWholeWordButton.state == .on,
            customDateTimeFormat: dateTimeFormatField.stringValue,
            searchEngineChoice: selectedSearchEngineChoice,
            customSearchEngineURL: searchEngineCustomURLField.stringValue,
            localizationFileName: selectedLocalizationFileName,
            showWhitespace: whitespaceDisplayModePopup.indexOfSelectedItem > 0,
            showEOL: showEOLButton.state == .on,
            showIndentGuides: showIndentGuidesButton.state == .on,
            highlightCurrentLine: highlightCurrentLineButton.state == .on,
            showWrapSymbol: showWrapSymbolButton.state == .on,
            showChangeHistory: showChangeHistoryButton.state == .on,
            tabSize: Int(tabSizeField.intValue),
            insertSpacesInsteadOfTabs: insertSpacesButton.state == .on,
            showLineNumberMargin: showLineNumberMarginButton.state == .on,
            showEdgeLine: showEdgeLineButton.state == .on,
            edgeLineColumn: max(1, Int(edgeLineColumnField.intValue)),
            enableAutoPair: autoPairButton.state == .on,
            autoPairParentheses: autoPairParenthesesButton.state == .on,
            autoPairBrackets: autoPairBracketsButton.state == .on,
            autoPairCurlyBrackets: autoPairCurlyBracketsButton.state == .on,
            autoPairSingleQuotes: autoPairSingleQuotesButton.state == .on,
            autoPairDoubleQuotes: autoPairDoubleQuotesButton.state == .on,
            customMatchedPairs: customPairsData,
            enableXmlTagMatch: xmlTagMatchButton.state == .on,
            enableClickableLinks: clickableLinksButton.state == .on,
            defaultNewDocumentEncoding: selectedNewDocEncoding,
            defaultNewDocumentLineEnding: selectedNewDocLineEnding,
            rememberLastSession: rememberSessionButton.state == .on,
            showNpcCharacters: showNpcCharactersButton.state == .on,
            smartHighlightMatchCase: smartHighlightMatchCaseButton.state == .on,
            smartHighlightWholeWord: smartHighlightWholeWordButton.state == .on,
            markAllMatchCase: markAllMatchCaseButton.state == .on,
            markAllWholeWord: markAllWholeWordButton.state == .on,
            langMenuCompact: langMenuCompactButton.state == .on,
            caretWidth: caretWidthSegmented.selectedSegment + 1,
            enableVirtualSpace: virtualSpaceButton.state == .on,
            backspaceUnindents: backspaceUnindentsButton.state == .on,
            autoIndent: autoIndentButton.state == .on,
            autoIndentMode: autoIndentModePopup.indexOfSelectedItem,
            fileAutoDetection: fileAutoDetectionPopup.indexOfSelectedItem,
            updateSilently: updateSilentlyButton.state == .on,
            largeFileSizeMB: Int(largeFileMBField.intValue),
            largeFileSuppressAutoComplete: largeFileSuppressAutoCompleteButton.state == .on,
            largeFileSuppressSmartHighlight: largeFileSuppressSmartHighlightButton.state == .on,
            largeFileSuppressBraceMatch: largeFileSuppressBraceMatchButton.state == .on,
            largeFileSuppressWordWrap: largeFileSuppressWordWrapButton.state == .on,
            largeFileSuppressSyntaxHighlight: largeFileSuppressSyntaxHighlightButton.state == .on,
            scrollBeyondLastLine: scrollBeyondLastLineButton.state == .on,
            autoCompleteFromNthChar: Int(autoCompleteField.intValue),
            caretNoBlink: caretNoBlinkButton.state == .on,
            caretBlinkRate: Int(caretBlinkRateField.intValue),
            currentLineFrameWidth: currentLineFrameSegmented.selectedSegment,
            lineWrapIndent: lineWrapIndentPopup.indexOfSelectedItem,
            foldMarginStyle: foldMarginStylePopup.indexOfSelectedItem,
            useFirstLineAsTabName: useFirstLineAsTabNameButton.state == .on,
            recentFilesMaxCount: Int(recentFilesMaxField.intValue),
            recentFilesShowFullPath: recentFilesShowFullPathButton.state == .on,
            recentFilesInSubmenu: recentFilesInSubmenuButton.state == .on,
            recentFilesCustomDisplayLength: Int(recentFilesCustomLengthField.intValue),
            noCheckRecentAtLaunch: noCheckRecentAtLaunchButton.state == .on,
            keepAbsentFilesInSession: keepAbsentFilesButton.state == .on,
            autoReloadOnExternalChange: autoReloadButton.state == .on,
            backupOnSaveMode: selectedBackupOnSaveMode(),
            snapshotModeEnabled: snapshotModeButton.state == .on,
            periodicBackupIntervalSeconds: Int(periodicBackupField.intValue),
            useCustomBackupDirectory: useCustomBackupDirButton.state == .on,
            customBackupDirectory: customBackupDirField.stringValue,
            additionalEdgeColumns: additionalEdgeColumnsField.stringValue,
            linePadding: linePaddingSegmented.selectedSegment,
            openDirectoryFollowsDocument: openDirFollowsDocButton.state == .on,
            defaultNewDocumentLanguageName: selectedDefaultLangName,
            folderDropOpensAsWorkspace: folderDropAsWorkspaceButton.state == .on,
            folderDropRecursiveOpen: folderDropRecursiveOpenButton.state == .on,
            extraURLSchemes: extraURLSchemesField.stringValue,
            newDocumentOnLaunch: newDocumentOnLaunchButton.state == .on,
            postItAlpha: postItAlphaSlider.doubleValue,
            printLineNumbers: printLineNumbersButton.state == .on,
            autoCompleteMode: autoCompleteModePopup.indexOfSelectedItem,
            autoCompleteChooseSingle: autoCompleteChooseSingleButton.state == .on,
            autoCompleteTABFillup: autoCompleteTABFillupButton.state == .on,
            autoCompleteEnterCommit: autoCompleteEnterCommitButton.state == .on,
            autoCompleteBrief: autoCompleteBriefButton.state == .on,
            inSelectionThreshold: Int(inSelectionThresholdField.intValue),
            tabbarDoubleClickClose: tabbarDoubleClickCloseButton.state == .on,
            tabbarMaxLabelLength: Int(tabbarMaxLabelLengthField.intValue),
            keepFindDialogOpen: keepFindDialogOpenButton.state == .on,
            findDialogTransparency: findTransparencySlider.doubleValue,
            printSettings: PrintSettings(
                header: PrintBand(
                    left: printHeaderLeftField.stringValue,
                    center: printHeaderCenterField.stringValue,
                    right: printHeaderRightField.stringValue
                ),
                footer: PrintBand(
                    left: printFooterLeftField.stringValue,
                    center: printFooterCenterField.stringValue,
                    right: printFooterRightField.stringValue
                ),
                colorMode: printColorModePopup.indexOfSelectedItem,
                fontSize: Double(printFontSizeField.intValue),
                marginTop: Double(printMarginTopField.intValue),
                marginBottom: Double(printMarginBottomField.intValue),
                marginLeft: Double(printMarginLeftField.intValue),
                marginRight: Double(printMarginRightField.intValue)
            ),
            delimiterLeft: delimiterLeftField.stringValue,
            delimiterRight: delimiterRightField.stringValue,
            statusBarVisible: statusBarVisibleButton.state == .on,
            shortTitle: shortTitleButton.state == .on,
            saveAllConfirm: saveAllConfirmButton.state == .on,
            autoCompleteIgnoreNumbers: autoCompleteIgnoreNumbersButton.state == .on,
            replaceDoesNotMove: replaceDoesNotMoveButton.state == .on,
            fileChangeDetectionEnabled: fileChangeDetectionButton.state == .on,
            findDialogMonospace: findDialogMonospaceButton.state == .on,
            copyLineWithoutSelection: copyLineWithoutSelectionButton.state == .on,
            fillFindFromSelection: fillFindFromSelectionButton.state == .on,
            autoSelectWordUnderCaret: autoSelectWordUnderCaretButton.state == .on,
            findInFilesIgnoreUnsaved: findInFilesIgnoreUnsavedButton.state == .on,
            smartHighlightUseFindSettings: smartHighlightUseFindSettingsButton.state == .on,
            urlIndicatorStyle: urlIndicatorStyleSegmented.selectedSegment,
            languageTabOverrides: langTabOverridesField.stringValue,
            tabbarLockDragDrop: tabbarLockDragDropButton.state == .on,
            tabbarExitOnLastTab: tabbarExitOnLastTabButton.state == .on,
            htmlXmlCloseTagEnabled: htmlXmlCloseTagButton.state == .on,
            muteAllSounds: muteAllSoundsButton.state == .on,
            selectedTextDragDrop: selectedTextDragDropButton.state == .on,
            lineNumberDynamicWidth: lineNumberDynamicWidthButton.state == .on,
            columnSelectionToMultiEditing: columnSelectionToMultiEditingButton.state == .on,
            appearanceMode: appearanceModeSegmented.selectedSegment,
            taskListCustomTags: taskListTagsField.stringValue,
            toolbarVisible: existing.toolbarVisible,
            showBookmarkMargin: showBookmarkMarginButton.state == .on,
            confirmReplaceInAllDocs: confirmReplaceInAllDocsButton.state == .on,
            maxFindHistoryCount: Int(maxFindHistoryField.intValue),
            tabbarHide: tabbarHideButton.state == .on,
            reloadScrollToLastCaret: reloadScrollToLastCaretButton.state == .on,
            editorFontName: editorFontNameField.stringValue,
            editorFontBold: editorFontBoldButton.state == .on,
            tabbarShowCloseButton: tabbarShowCloseButtonButton.state == .on,
            trimTrailingSpacesOnSave: trimTrailingSpacesOnSaveButton.state == .on,
            pasteConvertEndings: pasteConvertEndingsButton.state == .on,
            caretStickyMode: caretStickyModePopup.indexOfSelectedItem,
            enableCodeFolding: enableCodeFoldingButton.state == .on,
            autoCompleteIgnoreCase: autoCompleteIgnoreCaseButton.state == .on,
            whitespaceDisplayMode: whitespaceDisplayModePopup.indexOfSelectedItem,
            bidiMode: bidiModePopup.indexOfSelectedItem,
            smoothFont: smoothFontButton.state == .on,
            multiEditEnabled: multiEditEnabledButton.state == .on,
            multiPasteMode: multiPasteModePopup.indexOfSelectedItem,
            indentGuideMode: indentGuideModePopup.indexOfSelectedItem,
            wordWrapMode: wordWrapModePopup.indexOfSelectedItem,
            tabbarCompact: tabbarCompactButton.state == .on,
            zoomSyncToAllTabs: zoomSyncToAllTabsButton.state == .on,
            hideMenuShortcuts: hideMenuShortcutsButton.state == .on,
            scrollToLastLineOnMonitorReload: scrollToLastLineOnMonitorReloadButton.state == .on,
            additionalSelAlpha: Int(additionalSelAlphaField.intValue),
            additionalCaretsBlink: additionalCaretsBlinkButton.state == .on,
            additionalCaretsVisible: additionalCaretsVisibleButton.state == .on,
            caretLineVisibleAlways: caretLineVisibleAlwaysButton.state == .on,
            whitespaceSize: Int(whitespaceSizeField.intValue),
            selectionAlpha: Int(selectionAlphaField.intValue),
            controlCharDisplay: controlCharDisplayPopup.indexOfSelectedItem,
            openAnsiAsUtf8: openAnsiAsUtf8Button.state == .on,
            xmlTagAttributeHighlight: xmlTagAttributeHighlightButton.state == .on,
            highlightNonHtmlZone: highlightNonHtmlZoneButton.state == .on,
            defaultSaveDirectory: defaultSaveDirField.stringValue,
            toolbarIconSizeStyle: toolbarIconSizeSegmented.selectedSegment,
            scintillaRenderingTechnology: scintillaRenderingPopup.indexOfSelectedItem,
            disableAdvancedScrolling: disableAdvancedScrollingButton.state == .on,
            rightClickKeepSelection: rightClickKeepSelectionButton.state == .on,
            edgeMode: edgeModePopup.indexOfSelectedItem,
            foldFlags: foldFlagsPopup.indexOfSelectedItem == 0 ? 0 : foldFlagsPopup.indexOfSelectedItem * 2,
            foldCompact: foldCompactButton.state == .on,
            showDocSwitcher: showDocSwitcherButton.state == .on,
            perLineResultInFind: perLineResultButton.state == .on
        )
        preferencesStore.save(preferences)
        loadPreferences()
        onChange(preferences)
    }

    private func populateLocalizationPopup(selectedFileName: String) {
        localizationPopup.removeAllItems()

        for option in localizationOptions {
            localizationPopup.addItem(withTitle: option.displayName)
            localizationPopup.lastItem?.representedObject = option.fileName
        }

        if let index = localizationPopup.itemArray.firstIndex(where: {
            ($0.representedObject as? String)?.caseInsensitiveCompare(selectedFileName) == .orderedSame
        }) {
            localizationPopup.selectItem(at: index)
        } else {
            localizationPopup.selectItem(at: 0)
        }
    }

    private func configureSearchEnginePopup() {
        searchEnginePopup.removeAllItems()
        searchEnginePopup.addItem(withTitle: Localization.string(.preferencesSearchEngineCustom))
        searchEnginePopup.addItem(withTitle: Localization.string(.preferencesSearchEngineDuckDuckGo))
        searchEnginePopup.addItem(withTitle: Localization.string(.preferencesSearchEngineGoogle))
        searchEnginePopup.addItem(withTitle: Localization.string(.preferencesSearchEngineBing))
        searchEnginePopup.addItem(withTitle: Localization.string(.preferencesSearchEngineYahoo))
        searchEnginePopup.addItem(withTitle: Localization.string(.preferencesSearchEngineStackOverflow))
    }

    private func selectSearchEngine(_ choice: SearchEngineChoice) {
        searchEnginePopup.selectItem(at: searchEngineChoices.firstIndex(of: choice) ?? 0)
    }

    private var selectedSearchEngineChoice: SearchEngineChoice {
        let index = max(0, searchEnginePopup.indexOfSelectedItem)
        return searchEngineChoices[min(index, searchEngineChoices.count - 1)]
    }

    private var selectedLocalizationFileName: String {
        guard let fileName = localizationPopup.selectedItem?.representedObject as? String else {
            return AppPreferences.defaultValue.localizationFileName
        }
        return fileName
    }

    private func updateSearchEngineFieldState() {
        searchEngineCustomURLField.isEnabled = selectedSearchEngineChoice == .custom
    }

    private var searchEngineChoices: [SearchEngineChoice] {
        [.custom, .duckDuckGo, .google, .bing, .yahoo, .stackOverflow]
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: AppPreferences.minimumEditorFontSize)
        formatter.maximum = NSNumber(value: AppPreferences.maximumEditorFontSize)
        return formatter
    }

    private var tabSizeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 8
        return formatter
    }

    private func populateNewDocEncodingPopup(selected: String) {
        newDocEncodingPopup.removeAllItems()
        for option in TextEncodingOption.allCases {
            newDocEncodingPopup.addItem(withTitle: option.displayName)
            newDocEncodingPopup.lastItem?.representedObject = option.rawValue
        }
        selectNewDocEncodingPopup(selected)
    }

    private func selectNewDocEncodingPopup(_ rawValue: String) {
        if let index = newDocEncodingPopup.itemArray.firstIndex(where: {
            $0.representedObject as? String == rawValue
        }) {
            newDocEncodingPopup.selectItem(at: index)
        } else {
            newDocEncodingPopup.selectItem(at: 0)
        }
    }

    private var selectedNewDocEncoding: String {
        newDocEncodingPopup.selectedItem?.representedObject as? String ?? "utf8"
    }

    private func populateNewDocLineEndingPopup(selected: String) {
        newDocLineEndingPopup.removeAllItems()
        for lineEnding in LineEnding.allCases {
            newDocLineEndingPopup.addItem(withTitle: lineEnding.displayName)
            newDocLineEndingPopup.lastItem?.representedObject = lineEnding.rawValue
        }
        selectNewDocLineEndingPopup(selected)
    }

    private func selectNewDocLineEndingPopup(_ rawValue: String) {
        if let index = newDocLineEndingPopup.itemArray.firstIndex(where: {
            $0.representedObject as? String == rawValue
        }) {
            newDocLineEndingPopup.selectItem(at: index)
        } else {
            newDocLineEndingPopup.selectItem(at: 0)
        }
    }

    private func populateDefaultLangPopup(selected: String) {
        defaultLangPopup.removeAllItems()
        defaultLangPopup.addItem(withTitle: Localization.string(.preferencesDefaultLanguageNone, default: "(Normal Text)"))
        defaultLangPopup.lastItem?.representedObject = ""
        for entry in languageEntries {
            defaultLangPopup.addItem(withTitle: entry.displayName)
            defaultLangPopup.lastItem?.representedObject = entry.name
        }
        if let index = defaultLangPopup.itemArray.firstIndex(where: { $0.representedObject as? String == selected }) {
            defaultLangPopup.selectItem(at: index)
        } else {
            defaultLangPopup.selectItem(at: 0)
        }
    }

    private var selectedDefaultLangName: String {
        defaultLangPopup.selectedItem?.representedObject as? String ?? ""
    }

    private var selectedNewDocLineEnding: String {
        newDocLineEndingPopup.selectedItem?.representedObject as? String ?? "lf"
    }

    private func populateBackupOnSavePopup() {
        backupOnSavePopup.removeAllItems()
        for mode in BackupOnSaveMode.allCases {
            backupOnSavePopup.addItem(withTitle: mode.displayName)
            backupOnSavePopup.lastItem?.representedObject = mode.rawValue
        }
    }

    private func selectBackupOnSaveMode(_ mode: BackupOnSaveMode) {
        if let index = backupOnSavePopup.itemArray.firstIndex(where: {
            $0.representedObject as? String == mode.rawValue
        }) {
            backupOnSavePopup.selectItem(at: index)
        } else {
            backupOnSavePopup.selectItem(at: 0)
        }
    }

    private func selectedBackupOnSaveMode() -> BackupOnSaveMode {
        let raw = backupOnSavePopup.selectedItem?.representedObject as? String
        return BackupOnSaveMode(rawValue: raw ?? "") ?? .none
    }

    private func updateCustomBackupDirEnabled() {
        let enabled = useCustomBackupDirButton.state == .on
        customBackupDirField.isEnabled = enabled
        customBackupDirBrowseButton.isEnabled = enabled
    }

    @objc private func browseCustomBackupDirectory(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        customBackupDirField.stringValue = url.path
        savePreferences(sender: sender)
    }

    // MARK: - Custom Matched Pairs

    @objc private func addCustomPair(_ sender: Any?) {
        customPairsData.append(["(", ")"])
        customPairsTableView.reloadData()
        let newRow = customPairsData.count - 1
        customPairsTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        customPairsTableView.editColumn(0, row: newRow, with: nil, select: true)
        savePreferences(sender: sender)
    }

    @objc private func removeCustomPair(_ sender: Any?) {
        let row = customPairsTableView.selectedRow
        guard row >= 0, row < customPairsData.count else { return }
        customPairsData.remove(at: row)
        customPairsTableView.reloadData()
        savePreferences(sender: sender)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        customPairsData.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < customPairsData.count else { return nil }
        let pair = customPairsData[row]
        let identifier = tableColumn?.identifier.rawValue == "Open" ? "Open" : "Close"
        let value = identifier == "Open" ? (pair.first ?? "") : (pair.count > 1 ? pair[1] : "")
        let cellID = NSUserInterfaceItemIdentifier(identifier)
        if let cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = value
            return cell
        }
        let cell = NSTableCellView()
        cell.identifier = cellID
        let field = NSTextField(string: value)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isBordered = false
        field.isEditable = true
        field.drawsBackground = false
        cell.addSubview(field)
        cell.textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        true
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row < customPairsData.count, let value = object as? String else { return }
        var pair = customPairsData[row]
        if tableColumn?.identifier.rawValue == "Open" {
            pair = [value, pair.count > 1 ? pair[1] : ""]
        } else {
            pair = [pair.first ?? "", value]
        }
        customPairsData[row] = pair
        savePreferences(sender: tableView)
    }
}

private extension BackupOnSaveMode {
    var displayName: String {
        switch self {
        case .none: "None"
        case .simple: "Simple (.bak)"
        case .verbose: "Verbose (timestamped .bak)"
        }
    }
}
