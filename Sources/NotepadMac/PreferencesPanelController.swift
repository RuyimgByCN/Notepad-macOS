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
    private let showControlCharactersAndUnicodeEOLButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
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
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 760, height: 500)

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
        editorFontNameLabel.stringValue = Localization.string("pref.fontName", default: "Font name:")
        editorFontBoldButton.title = Localization.string("pref.fontBold", default: "Bold")
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
        autoPairParenthesesButton.title = Localization.string("pref.autoPair.parentheses", default: "  ( ) Parentheses")
        autoPairBracketsButton.title = Localization.string("pref.autoPair.brackets", default: "  [ ] Brackets")
        autoPairCurlyBracketsButton.title = Localization.string("pref.autoPair.curly", default: "  { } Curly brackets")
        autoPairSingleQuotesButton.title = Localization.string("pref.autoPair.singleQuotes", default: "  ' ' Single quotes")
        autoPairDoubleQuotesButton.title = Localization.string("pref.autoPair.doubleQuotes", default: "  \" \" Double quotes")
        customPairsAddButton.bezelStyle = .smallSquare
        customPairsAddButton.target = self
        customPairsAddButton.action = #selector(addCustomPair(_:))
        customPairsRemoveButton.bezelStyle = .smallSquare
        customPairsRemoveButton.target = self
        customPairsRemoveButton.action = #selector(removeCustomPair(_:))
        if customPairsTableView.tableColumns.isEmpty {
            let openCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Open"))
            openCol.width = 50
            openCol.isEditable = true
            let closeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Close"))
            closeCol.width = 50
            closeCol.isEditable = true
            customPairsTableView.addTableColumn(openCol)
            customPairsTableView.addTableColumn(closeCol)
        }
        for column in customPairsTableView.tableColumns {
            column.title = column.identifier.rawValue == "Open"
                ? Localization.string("pref.pairColumn.open", default: "Open")
                : Localization.string("pref.pairColumn.close", default: "Close")
        }
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
        markAllMatchCaseButton.title = Localization.string("pref.markAll.matchCase", default: "Mark All: match case")
        markAllWholeWordButton.title = Localization.string("pref.markAll.wholeWord", default: "Mark All: whole word only")
        langMenuCompactButton.title = Localization.string("pref.langMenuCompact", default: "Compact Language menu (hide rarely-used entries)")
        caretWidthLabel.stringValue = Localization.string(.preferencesCaretWidth, default: "Caret width:")
        if caretWidthSegmented.segmentCount == 3 {
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthThin, default: "Thin"), forSegment: 0)
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthMedium, default: "Medium"), forSegment: 1)
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthThick, default: "Thick"), forSegment: 2)
        }
        caretNoBlinkButton.title = Localization.string(.preferencesCaretNoBlink, default: "Disable caret blinking")
        caretBlinkRateLabel.stringValue = Localization.string("pref.caretBlinkRate", default: "Blink rate (ms):")
        caretBlinkRateField.placeholderString = "100-2000"
        caretBlinkRateStepper.minValue = 100
        caretBlinkRateStepper.maxValue = 2000
        caretBlinkRateStepper.increment = 50
        caretStickyModeLabel.stringValue = Localization.string("pref.caretStickyMode", default: "Caret sticky mode:")
        currentLineFrameLabel.stringValue = Localization.string(.preferencesCurrentLineFrame, default: "Current line highlight:")
        if currentLineFrameSegmented.segmentCount == 4 {
            currentLineFrameSegmented.setLabel(Localization.string(.preferencesCurrentLineFrameFill, default: "Fill"), forSegment: 0)
            currentLineFrameSegmented.setLabel("1px", forSegment: 1)
            currentLineFrameSegmented.setLabel("2px", forSegment: 2)
            currentLineFrameSegmented.setLabel("3px", forSegment: 3)
        }
        lineWrapIndentLabel.stringValue = Localization.string(.preferencesLineWrapIndent, default: "Wrap indent:")
        enableCodeFoldingButton.title = Localization.string("pref.enableCodeFolding", default: "Enable code folding")
        foldMarginStyleLabel.stringValue = Localization.string(.preferencesFoldMarginStyle, default: "Fold margin style:")
        virtualSpaceButton.title = Localization.string(.preferencesVirtualSpace, default: "Enable virtual space")
        backspaceUnindentsButton.title = Localization.string(.preferencesBackspaceUnindents, default: "Backspace key unindents")
        autoIndentButton.title = Localization.string(.preferencesAutoIndent, default: "Auto-indent new lines")
        autoIndentModeLabel.stringValue = Localization.string("pref.autoIndentMode", default: "Auto-indent mode:")
        autoIndentModePopup.removeAllItems()
        autoIndentModePopup.addItems(withTitles: [Localization.string("pref.item.none", default: "None"), Localization.string("pref.item.basic", default: "Basic"), Localization.string("pref.item.advancedBracketAware", default: "Advanced (bracket-aware)")])
        fileAutoDetectionLabel.stringValue = Localization.string("pref.fileAutoDetection", default: "File change detection:")
        fileAutoDetectionPopup.removeAllItems()
        fileAutoDetectionPopup.addItems(withTitles: [Localization.string("pref.item.disabled", default: "Disabled"), Localization.string("pref.item.onTabActivate", default: "On tab activate"), Localization.string("pref.item.realtimeMonitoring", default: "Real-time monitoring")])
        updateSilentlyButton.title = Localization.string("pref.updateSilently", default: "Auto-reload changed files without confirmation")
        zoomSyncToAllTabsButton.title = Localization.string("pref.zoomSyncToAllTabs", default: "Sync zoom level to all tabs when zooming")
        hideMenuShortcutsButton.title = Localization.string("pref.hideMenuShortcuts", default: "Hide keyboard shortcuts in menu items")
        scrollToLastLineOnMonitorReloadButton.title = Localization.string("pref.scrollToLastLineOnMonitorReload", default: "Scroll to last line after monitoring reload")
        scrollBeyondLastLineButton.title = Localization.string(.preferencesScrollBeyondLastLine, default: "Scroll beyond last line")
        selectedTextDragDropButton.title = Localization.string("pref.selectedTextDragDrop", default: "Allow dragging selected text within editor")
        lineNumberDynamicWidthButton.title = Localization.string("pref.lineNumberDynamicWidth", default: "Dynamic line number margin width")
        columnSelectionToMultiEditingButton.title = Localization.string("pref.columnSelectionToMultiEditing", default: "Column selection converts to multi-cursor editing")
        showBookmarkMarginButton.title = Localization.string("pref.showBookmarkMargin", default: "Show bookmark margin")
        showEdgeLineButton.title = Localization.string("pref.showEdgeLine", default: "Show edge line")
        displayDefaultsSectionLabel.stringValue = Localization.string("pref.displayDefaultsSection", default: "Display Defaults")
        showLineNumberMarginButton.title = Localization.string("pref.showLineNumberMargin", default: "Show line number margin")
        showWhitespaceButton.title = Localization.string("pref.showWhitespace", default: "Show whitespace")
        whitespaceDisplayModeLabel.stringValue = Localization.string("pref.whitespaceDisplayMode", default: "Whitespace mode:")
        whitespaceDisplayModePopup.removeAllItems()
        whitespaceDisplayModePopup.addItems(withTitles: [Localization.string("pref.item.dontShow", default: "Don't show"), Localization.string("pref.item.always", default: "Always"), Localization.string("pref.item.afterIndent", default: "After indent"), Localization.string("pref.item.onlyInIndent", default: "Only in indent")])
        bidiModeLabel.stringValue = Localization.string("pref.bidiMode", default: "Text direction:")
        bidiModePopup.removeAllItems()
        bidiModePopup.addItems(withTitles: [Localization.string("pref.item.default", default: "Default"), Localization.string("pref.item.leftToRight", default: "Left to right"), Localization.string("pref.item.rightToLeft", default: "Right to left")])
        showEOLButton.title = Localization.string("pref.showEOL", default: "Show EOL characters")
        showIndentGuidesButton.title = Localization.string("pref.showIndentGuides", default: "Show indent guides")
        highlightCurrentLineButton.title = Localization.string("pref.highlightCurrentLine", default: "Highlight current line")
        showNpcCharactersButton.title = Localization.string("pref.showNpcCharacters", default: "Show non-printable characters")
        showControlCharactersAndUnicodeEOLButton.title = Localization.string("pref.showControlChars", default: "Show control characters && Unicode EOL")
        showWrapSymbolButton.title = Localization.string("pref.showWrapSymbol", default: "Show wrap symbol")
        showChangeHistoryButton.title = Localization.string("pref.showChangeHistory", default: "Show change history margin")
        edgeLineColumnLabel.stringValue = Localization.string("pref.edgeColumn", default: "Edge column:")
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
        newDocumentOnLaunchButton.title = Localization.string("pref.newDocumentOnLaunch", default: "Create a new document on launch when session is empty")
        useFirstLineAsTabNameButton.title = Localization.string("pref.useFirstLineAsTabName", default: "Use first line as tab name for untitled files")
        recentFilesMaxLabel.stringValue = Localization.string("pref.recentFilesMax", default: "Max recent files:")
        noCheckRecentAtLaunchButton.title = Localization.string("pref.noCheckRecentAtLaunch", default: "Don't check recent files at launch")
        keepAbsentFilesButton.title = Localization.string("pref.keepAbsentFiles", default: "Keep absent files in session")
        autoReloadButton.title = Localization.string("pref.autoReload", default: "Auto-reload file when changed externally")
        fileChangeDetectionButton.title = Localization.string("pref.fileChangeDetection", default: "Enable file change detection (monitor for external changes)")
        snapshotModeButton.title = Localization.string("pref.snapshotMode", default: "Enable session snapshot and periodic backup")
        periodicBackupLabel.stringValue = Localization.string("pref.periodicBackup", default: "Periodic backup interval (seconds):")
        backupOnSaveLabel.stringValue = Localization.string("pref.backupOnSave", default: "Backup on save:")
        useCustomBackupDirButton.title = Localization.string("pref.useCustomBackupDir", default: "Use custom backup directory")
        customBackupDirBrowseButton.title = Localization.string(.findInFilesBrowse, default: "Browse...")
        populateBackupOnSavePopup()
        autoCompleteModeLabel.stringValue = Localization.string("pref.autoCompleteMode", default: "Auto-complete source:")
        autoCompleteChooseSingleButton.title = Localization.string("pref.autoCompleteChooseSingle", default: "Auto-accept when only one match")
        autoCompleteTABFillupButton.title = Localization.string("pref.autoCompleteTABFillup", default: "Tab key commits auto-complete selection")
        autoCompleteEnterCommitButton.title = Localization.string("pref.autoCompleteEnterCommit", default: "Enter key also commits auto-complete selection")
        autoCompleteBriefButton.title = Localization.string("pref.autoCompleteBrief", default: "Brief mode (hide function prototypes in list)")
        autoCompleteIgnoreCaseButton.title = Localization.string("pref.autoCompleteIgnoreCase", default: "Ignore case when matching completions")
        htmlXmlCloseTagButton.title = Localization.string("pref.htmlXmlCloseTag", default: "Auto-close HTML/XML tags when typing '>'")
        muteAllSoundsButton.title = Localization.string("pref.muteAllSounds", default: "Mute all sounds")
        trimTrailingSpacesOnSaveButton.title = Localization.string("pref.trimTrailingSpacesOnSave", default: "Trim trailing whitespace on save")
        pasteConvertEndingsButton.title = Localization.string("pref.pasteConvertEndings", default: "Convert line endings when pasting")
        smoothFontButton.title = Localization.string("pref.smoothFont", default: "Smooth font rendering (antialiased)")
        multiEditEnabledButton.title = Localization.string("pref.multiEditEnabled", default: "Enable multiple selections")
        multiPasteModeLabel.stringValue = Localization.string("pref.multiPasteMode", default: "Multi-paste mode:")
        multiPasteModePopup.removeAllItems()
        multiPasteModePopup.addItems(withTitles: [Localization.string("pref.item.pasteOnce", default: "Paste once (main selection)"), Localization.string("pref.item.pasteEach", default: "Paste into each selection")])
        indentGuideModeLabel.stringValue = Localization.string("pref.indentGuideMode", default: "Indent guide mode:")
        indentGuideModePopup.removeAllItems()
        indentGuideModePopup.addItems(withTitles: [Localization.string("pref.item.none", default: "None"), Localization.string("pref.item.real", default: "Real"), Localization.string("pref.item.lookForward", default: "Look forward"), Localization.string("pref.item.lookBoth", default: "Look both")])
        wordWrapModeLabel.stringValue = Localization.string("pref.wordWrapMode", default: "Word wrap mode:")
        wordWrapModePopup.removeAllItems()
        wordWrapModePopup.addItems(withTitles: [Localization.string("pref.item.none", default: "None"), Localization.string("pref.item.word", default: "Word"), Localization.string("pref.item.whitespace", default: "Whitespace"), Localization.string("pref.item.character", default: "Character")])
        additionalSelAlphaLabel.stringValue = Localization.string("pref.additionalSelAlpha", default: "Additional selection alpha:")
        additionalSelAlphaField.formatter = integerFormatter
        whitespaceSizeField.formatter = integerFormatter
        selectionAlphaField.formatter = integerFormatter
        additionalSelAlphaStepper.minValue = 0
        additionalSelAlphaStepper.maxValue = 256
        additionalSelAlphaStepper.increment = 16
        additionalSelAlphaStepper.valueWraps = false
        additionalCaretsBlinkButton.title = Localization.string("pref.additionalCaretsBlink", default: "Additional carets blink")
        additionalCaretsVisibleButton.title = Localization.string("pref.additionalCaretsVisible", default: "Show additional carets")
        caretLineVisibleAlwaysButton.title = Localization.string("pref.caretLineVisibleAlways", default: "Highlight current line when unfocused")
        whitespaceSizeLabel.stringValue = Localization.string("pref.whitespaceSize", default: "Whitespace dot size (px):")
        whitespaceSizeStepper.minValue = 1
        whitespaceSizeStepper.maxValue = 5
        whitespaceSizeStepper.increment = 1
        whitespaceSizeStepper.valueWraps = false
        selectionAlphaLabel.stringValue = Localization.string("pref.selectionAlpha", default: "Selection alpha:")
        selectionAlphaStepper.minValue = 0
        selectionAlphaStepper.maxValue = 256
        selectionAlphaStepper.increment = 16
        selectionAlphaStepper.valueWraps = false
        controlCharDisplayLabel.stringValue = Localization.string("pref.controlCharDisplay", default: "Control char display:")
        controlCharDisplayPopup.removeAllItems()
        controlCharDisplayPopup.addItems(withTitles: [Localization.string("pref.item.showAsGlyph", default: "Show as glyph"), Localization.string("pref.item.arrow", default: "Arrow"), Localization.string("pref.item.dot", default: "Dot"), Localization.string("pref.item.smallCircle", default: "Small circle"), Localization.string("pref.item.largeCircle", default: "Large circle"), Localization.string("pref.item.space", default: "Space"), Localization.string("pref.item.nbsp", default: "Nbsp")])
        inSelectionSectionLabel.stringValue = Localization.string("pref.inSelectionSection", default: "In-Selection Search")
        inSelectionThresholdLabel.stringValue = Localization.string("pref.inSelectionThreshold", default: "Auto-check In Selection threshold (chars):")
        keepFindDialogOpenButton.title = Localization.string("pref.keepFindDialogOpen", default: "Keep Find dialog open after Replace All")
        replaceDoesNotMoveButton.title = Localization.string("pref.replaceDoesNotMove", default: "After Replace, don't move caret to replaced range")
        findDialogMonospaceButton.title = Localization.string("pref.findDialogMonospace", default: "Use monospaced font in Find / Replace fields")
        fillFindFromSelectionButton.title = Localization.string("pref.fillFindFromSelection", default: "Fill Find field with selected text when opening Find dialog")
        autoSelectWordUnderCaretButton.title = Localization.string("pref.autoSelectWordUnderCaret", default: "Auto-select word under caret when no selection")
        findInFilesIgnoreUnsavedButton.title = Localization.string("pref.findInFilesIgnoreUnsaved", default: "Find in Files: ignore unsaved changes in open documents")
        confirmReplaceInAllDocsButton.title = Localization.string("pref.confirmReplaceInAllDocs", default: "Confirm before Replace All in Open Documents")
        maxFindHistoryLabel.stringValue = Localization.string("pref.maxFindHistory", default: "Max find/replace history:")
        copyLineWithoutSelectionButton.title = Localization.string("pref.copyLineWithoutSelection", default: "Copy / Cut whole line when nothing is selected")
        smartHighlightUseFindSettingsButton.title = Localization.string("pref.smartHighlightUseFindSettings", default: "Smart highlight uses Find dialog Match Case / Whole Word settings")
        urlIndicatorStyleLabel.stringValue = Localization.string("pref.urlIndicatorStyle", default: "URL style:")
        langTabOverridesLabel.stringValue = Localization.string("pref.langTabOverrides", default: "Lang tabs:")
        langTabOverridesField.placeholderString = "python:4s, html:2s, c:8t  (langname:sizeS/T)"
        taskListTagsLabel.stringValue = Localization.string("pref.taskListTags", default: "Task List tags:")
        taskListTagsField.placeholderString = "TODO, FIXME, NOTE, HACK, BUG, XXX"
        findTransparencyLabel.stringValue = Localization.string("pref.findTransparency", default: "Find dialog transparency when unfocused:")
        tabbarSectionLabel.stringValue = Localization.string("pref.section.tabBar", default: "Tab Bar")
        tabbarHideButton.title = Localization.string("pref.tabbarHide", default: "Hide tab bar")
        tabbarDoubleClickCloseButton.title = Localization.string("pref.tabbarDoubleClickClose", default: "Double-click tab to close")
        tabbarLockDragDropButton.title = Localization.string("pref.tabbarLockDragDrop", default: "Lock tab bar (disable drag-drop reordering)")
        tabbarShowCloseButtonButton.title = Localization.string("pref.tabbarShowCloseButton", default: "Show close button on tabs")
        tabbarCompactButton.title = Localization.string("pref.tabbarCompact", default: "Compact (reduced) tab bar")
        tabbarShowIndexNumbersButton.title = Localization.string("pref.tabbarShowIndexNumbers", default: "Show tab index numbers (1-9)")
        toolbarIconSizeLabel.stringValue = Localization.string("pref.toolbarIconSize", default: "Toolbar icon size:")
        scintillaRenderingLabel.stringValue = Localization.string("pref.scintillaRendering", default: "Scintilla rendering:")
        disableAdvancedScrollingButton.title = Localization.string("pref.disableAdvancedScrolling", default: "Disable advanced scrolling")
        rightClickKeepSelectionButton.title = Localization.string("pref.rightClickKeepSelection", default: "Keep selection on right-click")
        edgeModeLabel.stringValue = Localization.string("pref.edgeMode", default: "Edge line style:")
        foldFlagsLabel.stringValue = Localization.string("pref.foldFlags", default: "Fold indicators:")
        foldCompactButton.title = Localization.string("pref.foldCompact", default: "Compact fold (no extra lines around folded regions)")
        showDocSwitcherButton.title = Localization.string("pref.showDocSwitcher", default: "Show document switcher on Ctrl+Tab")
        perLineResultButton.title = Localization.string("pref.perLineResult", default: "Show only one result per line in Find in Files")
        tabbarExitOnLastTabButton.title = Localization.string("pref.tabbarExitOnLastTab", default: "Exit app when last tab is closed")
        tabbarMaxLabelLengthLabel.stringValue = Localization.string("pref.tabbarMaxLabelLength", default: "Max tab label length (0 = unlimited):")
        printSectionLabel.stringValue = Localization.string("pref.section.print", default: "Print")
        printHeaderSectionLabel.stringValue = Localization.string("pref.printHeader", default: "Header (Left / Center / Right):")
        printFooterSectionLabel.stringValue = Localization.string("pref.printFooter", default: "Footer (Left / Center / Right):")
        printColorModeLabel.stringValue = Localization.string("pref.printColor", default: "Color:")
        printFontSizeLabel.stringValue = Localization.string("pref.printFontSize", default: "Font size (0=auto):")
        delimiterSectionLabel.stringValue = Localization.string("pref.section.delimiter", default: "Delimiter")
        delimiterLeftLabel.stringValue = Localization.string("pref.delimiterLeft", default: "Left char (empty=whitespace):")
        delimiterRightLabel.stringValue = Localization.string("pref.delimiterRight", default: "Right char:")
        appearanceSectionLabel.stringValue = Localization.string("pref.appearanceSection", default: "Appearance")
        appearanceModeLabel.stringValue = Localization.string("pref.colorMode", default: "Color mode:")
        appearanceModeSegmented.setLabel(Localization.string("pref.item.system", default: "System"), forSegment: 0)
        appearanceModeSegmented.setLabel(Localization.string("pref.item.light", default: "Light"), forSegment: 1)
        appearanceModeSegmented.setLabel(Localization.string("pref.item.dark", default: "Dark"), forSegment: 2)
        postItSectionLabel.stringValue = Localization.string("pref.postItSection", default: "Post-It Mode")
        postItAlphaLabel.stringValue = Localization.string("pref.windowOpacity", default: "Window opacity:")
        postItAlphaSlider.minValue = 0.2
        postItAlphaSlider.maxValue = 1.0
        postItAlphaSlider.isContinuous = true
        postItAlphaSlider.target = self
        postItAlphaSlider.action = #selector(controlChanged(_:))
        generalSectionLabel.stringValue = Localization.string("pref.section.general", default: "General")
        statusBarVisibleButton.title = Localization.string("pref.statusBarVisible", default: "Show status bar")
        shortTitleButton.title = Localization.string("pref.shortTitle", default: "Short title (filename only in title bar)")
        saveAllConfirmButton.title = Localization.string("pref.saveAllConfirm", default: "Confirm before Save All")
        autoCompleteIgnoreNumbersButton.title = Localization.string("pref.autoCompleteIgnoreNumbers", default: "Auto-complete: ignore words starting with digits")
        reloadScrollToLastCaretButton.title = Localization.string("pref.reloadScrollToLastCaret", default: "Scroll to last caret position after external file reload")
        openAnsiAsUtf8Button.title = Localization.string("pref.openAnsiAsUtf8", default: "Open ANSI files as UTF-8 (auto-reinterpret ANSI/Windows encodings as UTF-8)")
        xmlTagAttributeHighlightButton.title = Localization.string("pref.xmlTagAttributeHighlight", default: "Highlight tag attributes in XML/HTML matching")
        highlightNonHtmlZoneButton.title = Localization.string("pref.highlightNonHtmlZone", default: "Apply XML tag matching in non-HTML/PHP/ASP zones")
        defaultSaveDirLabel.stringValue = Localization.string("pref.defaultSaveDir", default: "Default save directory (empty = system default):")
        printLineNumbersButton.title = Localization.string("pref.printLineNumbers", default: "Print line numbers")
        openDirFollowsDocButton.title = Localization.string(.preferencesOpenDirFollowsDoc, default: "Open dialog starts in the current document's directory")
        folderDropAsWorkspaceButton.title = Localization.string(.preferencesFolderDropAsWorkspace, default: "Open dropped folder as workspace")
        folderDropRecursiveOpenButton.title = Localization.string("pref.folderDropRecursiveOpen", default: "Recursively open all files when dropping a folder")
        defaultLangLabel.stringValue = Localization.string(.preferencesDefaultLanguage, default: "Default language for new documents:")
        additionalEdgeColumnsLabel.stringValue = Localization.string("pref.additionalEdgeColumns", default: "Extra vertical edges (columns):")
        recentFilesShowFullPathButton.title = Localization.string("pref.recentFilesShowFullPath", default: "Show full path in recent files menu")
        recentFilesInSubmenuButton.title = Localization.string("pref.recentFilesInSubmenu", default: "Show recent files in a submenu")
        recentFilesCustomLengthLabel.stringValue = Localization.string("pref.recentFilesCustomLength", default: "Path display length (0=full):")
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
        // Upstream re-translates the whole Preferences dialog in place on
        // language change; repopulate option lists before loadPreferences
        // restores their selections.
        refreshLocalizedStrings()
        populateLocalizedControlItems()
        loadPreferences()
        closeButton.title = Localization.string("pref.close", default: "Close")
        let selectedRow = sectionListTableView.selectedRow
        sectionListTableView.reloadData()
        if selectedRow >= 0 {
            sectionListTableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        }
    }

    /// (Re)fills popup items and segmented-control labels with localized
    /// titles. Called at construction and again on every language change;
    /// selections are restored afterwards by loadPreferences().
    private func populateLocalizedControlItems() {
        autoCompleteModePopup.removeAllItems()
        autoCompleteModePopup.addItems(withTitles: [
            Localization.string("pref.item.disabled", default: "Disabled"),
            Localization.string("pref.item.functionApiOnly", default: "Function API only"),
            Localization.string("pref.item.documentWordsOnly", default: "Document words only"),
            Localization.string("pref.item.functionPlusWords", default: "Function + words (default)")
        ])

        printColorModePopup.removeAllItems()
        printColorModePopup.addItems(withTitles: [
            Localization.string("pref.item.colorAsDisplayed", default: "Color (as displayed)"),
            Localization.string("pref.item.forceBlackText", default: "Force black text")
        ])

        caretWidthSegmented.setLabel(Localization.string("pref.item.thin", default: "Thin"), forSegment: 0)
        caretWidthSegmented.setLabel(Localization.string("pref.item.medium", default: "Medium"), forSegment: 1)
        caretWidthSegmented.setLabel(Localization.string("pref.item.thick", default: "Thick"), forSegment: 2)

        caretStickyModePopup.removeAllItems()
        caretStickyModePopup.addItems(withTitles: [
            Localization.string("pref.item.disabled", default: "Disabled"),
            Localization.string("pref.item.enabled", default: "Enabled"),
            Localization.string("pref.item.enabledForWhitespace", default: "Enabled for whitespace")
        ])

        currentLineFrameSegmented.setLabel(Localization.string("pref.item.fill", default: "Fill"), forSegment: 0)
        currentLineFrameSegmented.setLabel("1px", forSegment: 1)
        currentLineFrameSegmented.setLabel("2px", forSegment: 2)
        currentLineFrameSegmented.setLabel("3px", forSegment: 3)

        lineWrapIndentPopup.removeAllItems()
        lineWrapIndentPopup.addItems(withTitles: [
            Localization.string("pref.item.fixed", default: "Fixed"),
            Localization.string("pref.item.sameIndent", default: "Same indent"),
            Localization.string("pref.item.indent", default: "Indent"),
            Localization.string("pref.item.deepIndent", default: "Deep indent")
        ])

        foldMarginStylePopup.removeAllItems()
        let foldMarginStyleItems: [(title: String, style: FoldMarginStyle)] = [
            (Localization.string("pref.item.simple", default: "Simple"), .simple),
            (Localization.string("pref.item.arrow", default: "Arrow"), .arrow),
            (Localization.string("pref.item.circleTree", default: "Circle tree"), .circle),
            (Localization.string("pref.item.boxTree", default: "Box tree"), .box),
            (Localization.string("pref.item.none", default: "None"), .none)
        ]
        for (title, style) in foldMarginStyleItems {
            foldMarginStylePopup.addItem(withTitle: title)
            foldMarginStylePopup.lastItem?.tag = style.rawValue
        }

        urlIndicatorStyleSegmented.setLabel(Localization.string("pref.item.underline", default: "Underline"), forSegment: 0)
        urlIndicatorStyleSegmented.setLabel(Localization.string("pref.item.box", default: "Box"), forSegment: 1)
        urlIndicatorStyleSegmented.setLabel(Localization.string("pref.item.fullBox", default: "Full Box"), forSegment: 2)

        toolbarIconSizeSegmented.setLabel(Localization.string("pref.item.regular", default: "Regular"), forSegment: 0)
        toolbarIconSizeSegmented.setLabel(Localization.string("pref.item.small", default: "Small"), forSegment: 1)

        scintillaRenderingPopup.removeAllItems()
        scintillaRenderingPopup.addItems(withTitles: [
            Localization.string("pref.item.default", default: "Default"),
            Localization.string("pref.item.directRendering", default: "Direct (better quality)")
        ])

        edgeModePopup.removeAllItems()
        edgeModePopup.addItems(withTitles: [
            Localization.string("pref.item.none", default: "None"),
            Localization.string("pref.item.line", default: "Line"),
            Localization.string("pref.item.backgroundHighlight", default: "Background highlight")
        ])

        foldFlagsPopup.removeAllItems()
        foldFlagsPopup.addItems(withTitles: [
            Localization.string("pref.item.none", default: "None"),
            Localization.string("pref.item.lineBeforeExpanded", default: "Line before expanded"),
            Localization.string("pref.item.lineBeforeContracted", default: "Line before contracted"),
            Localization.string("pref.item.lineAfterExpanded", default: "Line after expanded"),
            Localization.string("pref.item.lineAfterContracted", default: "Line after contracted")
        ])
    }

    @objc private func controlChanged(_ sender: Any?) {
        savePreferences(sender: sender)
    }

    private func configureContent() {
        guard let outerView = window?.contentView else { return }

        // Upstream preferences layout: category list on the left, the
        // selected category's panel on the right, Close button at the bottom.
        let sectionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Section"))
        sectionListTableView.addTableColumn(sectionColumn)
        sectionListTableView.headerView = nil
        sectionListTableView.rowHeight = 22
        sectionListTableView.allowsEmptySelection = false
        sectionListTableView.delegate = self
        sectionListTableView.dataSource = self

        let listScroll = NSScrollView()
        listScroll.translatesAutoresizingMaskIntoConstraints = false
        listScroll.hasVerticalScroller = true
        listScroll.borderType = .bezelBorder
        listScroll.documentView = sectionListTableView

        sectionDetailScrollView.translatesAutoresizingMaskIntoConstraints = false
        sectionDetailScrollView.hasVerticalScroller = true
        sectionDetailScrollView.borderType = .noBorder
        sectionDetailScrollView.drawsBackground = false

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.target = self
        closeButton.action = #selector(closePreferences(_:))

        outerView.addSubview(listScroll)
        outerView.addSubview(sectionDetailScrollView)
        outerView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            listScroll.leadingAnchor.constraint(equalTo: outerView.leadingAnchor, constant: 16),
            listScroll.topAnchor.constraint(equalTo: outerView.topAnchor, constant: 16),
            listScroll.widthAnchor.constraint(equalToConstant: 180),
            listScroll.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -12),

            sectionDetailScrollView.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor, constant: 12),
            sectionDetailScrollView.trailingAnchor.constraint(equalTo: outerView.trailingAnchor, constant: -16),
            sectionDetailScrollView.topAnchor.constraint(equalTo: outerView.topAnchor, constant: 16),
            sectionDetailScrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -12),

            closeButton.centerXAnchor.constraint(equalTo: outerView.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: outerView.bottomAnchor, constant: -14),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])

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
        printFontSizeStepper.minValue = 0
        printFontSizeStepper.maxValue = 32
        printFontSizeStepper.increment = 1
        printFontSizeField.formatter = integerFormatter
        printMarginsLabel.stringValue = Localization.string("pref.printMargins", default: "Margins (pt):")
        printMarginTopLabel.stringValue = Localization.string("pref.marginTop", default: "Top:")
        printMarginBottomLabel.stringValue = Localization.string("pref.marginBottom", default: "Bottom:")
        printMarginLeftLabel.stringValue = Localization.string("pref.marginLeft", default: "Left:")
        printMarginRightLabel.stringValue = Localization.string("pref.marginRight", default: "Right:")
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
        caretWidthSegmented.trackingMode = .selectOne

        currentLineFrameSegmented.segmentCount = 4
        currentLineFrameSegmented.trackingMode = .selectOne

        edgeLineColumnField.formatter = integerFormatter
        edgeLineColumnStepper.target = self
        edgeLineColumnStepper.action = #selector(controlChanged(_:))

        linePaddingSegmented.segmentCount = 6
        for i in 0...5 { linePaddingSegmented.setLabel("\(i)px", forSegment: i) }
        linePaddingSegmented.trackingMode = .selectOne

        urlIndicatorStyleSegmented.segmentCount = 3
        urlIndicatorStyleSegmented.trackingMode = .selectOne

        appearanceModeSegmented.segmentCount = 3
        appearanceModeSegmented.trackingMode = .selectOne

        toolbarIconSizeSegmented.segmentCount = 2
        toolbarIconSizeSegmented.trackingMode = .selectOne

        populateLocalizedControlItems()

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

        // ── Upstream-style category sections ─────────────────────────
        customPairsScrollView.translatesAutoresizingMaskIntoConstraints = false
        customPairsScrollView.heightAnchor.constraint(equalToConstant: 110).isActive = true
        customPairsScrollView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        buildSectionViews()
        closeButton.title = Localization.string("pref.close", default: "Close")
        sectionListTableView.reloadData()
        sectionListTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        showSection(.general)
    }

    // MARK: - Upstream-style section navigation

    private let sectionListTableView = NSTableView()
    private let sectionDetailScrollView = NSScrollView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private var sectionViews: [PreferenceSection: NSView] = [:]
    private var currentSection: PreferenceSection?

    // Upstream preferences categories, in upstream order.
    enum PreferenceSection: Int, CaseIterable {
        case general, toolbar, tabBar, editing1, editing2, darkMode, marginsBorderEdge,
             newDocument, defaultDirectory, recentFiles, fileAssociation, language,
             indentation, highlighting, print, searching, backup, autoCompletion,
             multiInstanceDate, delimiter, performance, cloudLink, searchEngine, misc

        var title: String {
            switch self {
            case .general: Localization.string("pref.section.general", default: "General")
            case .toolbar: Localization.string("pref.section.toolbar", default: "Toolbar")
            case .tabBar: Localization.string("pref.section.tabBar", default: "Tab Bar")
            case .editing1: Localization.string("pref.section.editing1", default: "Editing 1")
            case .editing2: Localization.string("pref.section.editing2", default: "Editing 2")
            case .darkMode: Localization.string("pref.section.darkMode", default: "Dark Mode")
            case .marginsBorderEdge: Localization.string("pref.section.margins", default: "Margins/Border/Edge")
            case .newDocument: Localization.string("pref.section.newDocument", default: "New Document")
            case .defaultDirectory: Localization.string("pref.section.defaultDirectory", default: "Default Directory")
            case .recentFiles: Localization.string("pref.section.recentFiles", default: "Recent Files History")
            case .fileAssociation: Localization.string("pref.section.fileAssociation", default: "File Association")
            case .language: Localization.string("pref.section.language", default: "Language")
            case .indentation: Localization.string("pref.section.indentation", default: "Indentation")
            case .highlighting: Localization.string("pref.section.highlighting", default: "Highlighting")
            case .print: Localization.string("pref.section.print", default: "Print")
            case .searching: Localization.string("pref.section.searching", default: "Searching")
            case .backup: Localization.string("pref.section.backup", default: "Backup")
            case .autoCompletion: Localization.string("pref.section.autoCompletion", default: "Auto-Completion")
            case .multiInstanceDate: Localization.string("pref.section.multiInstance", default: "Multi-Instance & Date")
            case .delimiter: Localization.string("pref.section.delimiter", default: "Delimiter")
            case .performance: Localization.string("pref.section.performance", default: "Performance")
            case .cloudLink: Localization.string("pref.section.cloudLink", default: "Cloud & Link")
            case .searchEngine: Localization.string("pref.section.searchEngine", default: "Search Engine")
            case .misc: Localization.string("pref.section.misc", default: "MISC.")
            }
        }
    }

    @objc private func closePreferences(_ sender: Any?) {
        window?.close()
    }

    private func showSection(_ section: PreferenceSection) {
        guard currentSection != section, let view = sectionViews[section] else { return }
        currentSection = section
        sectionDetailScrollView.documentView = view
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: sectionDetailScrollView.contentView.leadingAnchor),
            view.topAnchor.constraint(equalTo: sectionDetailScrollView.contentView.topAnchor),
            view.widthAnchor.constraint(equalTo: sectionDetailScrollView.contentView.widthAnchor)
        ])
    }

    private func buildSectionViews() {
        func sized(_ view: NSView, _ width: CGFloat) -> NSView {
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
            return view
        }
        func row(_ views: [NSView]) -> NSStackView {
            let stack = NSStackView(views: views)
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 8
            return stack
        }
        func column(_ rows: [NSView]) -> NSView {
            let stack = NSStackView(views: rows)
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 10
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }

        sectionViews[.general] = column([
            row([localizationChoiceLabel, sized(localizationPopup, 220)]),
            statusBarVisibleButton,
            shortTitleButton,
            showDocSwitcherButton,
            hideMenuShortcutsButton,
            saveAllConfirmButton,
            muteAllSoundsButton
        ])

        sectionViews[.toolbar] = column([
            row([toolbarIconSizeLabel, toolbarIconSizeSegmented])
        ])

        sectionViews[.tabBar] = column([
            tabbarHideButton,
            tabbarShowCloseButtonButton,
            tabbarCompactButton,
            tabbarDoubleClickCloseButton,
            tabbarLockDragDropButton,
            tabbarExitOnLastTabButton,
            tabbarShowIndexNumbersButton,
            useFirstLineAsTabNameButton,
            row([tabbarMaxLabelLengthLabel, sized(tabbarMaxLabelLengthField, 58), tabbarMaxLabelLengthStepper])
        ])

        sectionViews[.editing1] = column([
            row([fontSizeLabel, sized(fontSizeField, 58), fontSizeStepper]),
            row([editorFontNameLabel, sized(editorFontNameField, 180), editorFontBoldButton]),
            row([caretWidthLabel, caretWidthSegmented]),
            caretNoBlinkButton,
            row([caretBlinkRateLabel, sized(caretBlinkRateField, 70), caretBlinkRateStepper]),
            row([caretStickyModeLabel, caretStickyModePopup]),
            highlightCurrentLineButton,
            row([currentLineFrameLabel, currentLineFrameSegmented]),
            caretLineVisibleAlwaysButton,
            wrapsLinesButton,
            row([wordWrapModeLabel, wordWrapModePopup]),
            row([lineWrapIndentLabel, lineWrapIndentPopup]),
            multiEditEnabledButton,
            row([multiPasteModeLabel, multiPasteModePopup]),
            columnSelectionToMultiEditingButton,
            additionalCaretsBlinkButton,
            additionalCaretsVisibleButton,
            row([additionalSelAlphaLabel, sized(additionalSelAlphaField, 58), additionalSelAlphaStepper]),
            row([selectionAlphaLabel, sized(selectionAlphaField, 58), selectionAlphaStepper]),
            selectedTextDragDropButton,
            virtualSpaceButton,
            scrollBeyondLastLineButton,
            smoothFontButton,
            row([linePaddingLabel, linePaddingSegmented]),
            zoomSyncToAllTabsButton,
            copyLineWithoutSelectionButton,
            rightClickKeepSelectionButton,
            disableAdvancedScrollingButton,
            row([scintillaRenderingLabel, scintillaRenderingPopup])
        ])

        sectionViews[.editing2] = column([
            showWhitespaceButton,
            row([whitespaceDisplayModeLabel, whitespaceDisplayModePopup]),
            row([whitespaceSizeLabel, sized(whitespaceSizeField, 58), whitespaceSizeStepper]),
            showEOLButton,
            showNpcCharactersButton,
            showControlCharactersAndUnicodeEOLButton,
            row([controlCharDisplayLabel, controlCharDisplayPopup]),
            showWrapSymbolButton,
            showIndentGuidesButton,
            row([indentGuideModeLabel, indentGuideModePopup]),
            showChangeHistoryButton,
            row([bidiModeLabel, bidiModePopup])
        ])

        sectionViews[.darkMode] = column([
            row([appearanceModeLabel, appearanceModeSegmented])
        ])

        sectionViews[.marginsBorderEdge] = column([
            showLineNumberMarginButton,
            lineNumberDynamicWidthButton,
            showBookmarkMarginButton,
            enableCodeFoldingButton,
            row([foldMarginStyleLabel, foldMarginStylePopup]),
            row([foldFlagsLabel, foldFlagsPopup]),
            foldCompactButton,
            showEdgeLineButton,
            row([edgeLineColumnLabel, sized(edgeLineColumnField, 70), edgeLineColumnStepper]),
            row([edgeModeLabel, edgeModePopup]),
            row([additionalEdgeColumnsLabel, sized(additionalEdgeColumnsField, 160)])
        ])

        sectionViews[.newDocument] = column([
            row([newDocEncodingLabel, newDocEncodingPopup]),
            openAnsiAsUtf8Button,
            row([newDocLineEndingLabel, newDocLineEndingPopup]),
            row([defaultLangLabel, defaultLangPopup]),
            newDocumentOnLaunchButton
        ])

        sectionViews[.defaultDirectory] = column([
            row([defaultSaveDirLabel]),
            sized(defaultSaveDirField, 320),
            openDirFollowsDocButton,
            folderDropAsWorkspaceButton,
            folderDropRecursiveOpenButton
        ])

        sectionViews[.recentFiles] = column([
            row([recentFilesMaxLabel, sized(recentFilesMaxField, 58), recentFilesMaxStepper]),
            noCheckRecentAtLaunchButton,
            keepAbsentFilesButton,
            recentFilesShowFullPathButton,
            recentFilesInSubmenuButton,
            row([recentFilesCustomLengthLabel, sized(recentFilesCustomLengthField, 58), recentFilesCustomLengthStepper])
        ])

        let fileAssociationInfo = NSTextField(wrappingLabelWithString: Localization.string(
            "pref.fileAssociation.macosHint",
            default: "On macOS, file associations are managed by Finder: select a file, choose File > Get Info, set \"Open with\" and click \"Change All...\"."
        ))
        fileAssociationInfo.preferredMaxLayoutWidth = 460
        sectionViews[.fileAssociation] = column([fileAssociationInfo])

        sectionViews[.language] = column([
            langMenuCompactButton,
            row([langTabOverridesLabel, sized(langTabOverridesField, 280)])
        ])

        sectionViews[.indentation] = column([
            row([tabSizeLabel, sized(tabSizeField, 58), tabSizeStepper]),
            insertSpacesButton,
            backspaceUnindentsButton,
            autoIndentButton,
            row([autoIndentModeLabel, autoIndentModePopup])
        ])

        sectionViews[.highlighting] = column([
            smartHighlightMatchCaseButton,
            smartHighlightWholeWordButton,
            smartHighlightUseFindSettingsButton,
            markAllMatchCaseButton,
            markAllWholeWordButton,
            xmlTagMatchButton,
            xmlTagAttributeHighlightButton,
            highlightNonHtmlZoneButton
        ])

        sectionViews[.print] = column([
            printLineNumbersButton,
            row([printColorModeLabel, printColorModePopup]),
            row([printFontSizeLabel, sized(printFontSizeField, 58), printFontSizeStepper]),
            printHeaderSectionLabel,
            row([sized(printHeaderLeftField, 120), sized(printHeaderCenterField, 120), sized(printHeaderRightField, 120)]),
            printFooterSectionLabel,
            row([sized(printFooterLeftField, 120), sized(printFooterCenterField, 120), sized(printFooterRightField, 120)]),
            row([printMarginsLabel,
                 printMarginTopLabel, sized(printMarginTopField, 50),
                 printMarginBottomLabel, sized(printMarginBottomField, 50),
                 printMarginLeftLabel, sized(printMarginLeftField, 50),
                 printMarginRightLabel, sized(printMarginRightField, 50)])
        ])

        sectionViews[.searching] = column([
            searchMatchCaseButton,
            searchWholeWordButton,
            keepFindDialogOpenButton,
            replaceDoesNotMoveButton,
            findDialogMonospaceButton,
            fillFindFromSelectionButton,
            autoSelectWordUnderCaretButton,
            findInFilesIgnoreUnsavedButton,
            confirmReplaceInAllDocsButton,
            perLineResultButton,
            row([inSelectionThresholdLabel, sized(inSelectionThresholdField, 70), inSelectionThresholdStepper]),
            row([maxFindHistoryLabel, sized(maxFindHistoryField, 58), maxFindHistoryStepper]),
            row([findTransparencyLabel, sized(findTransparencySlider, 180)])
        ])

        sectionViews[.backup] = column([
            rememberSessionButton,
            snapshotModeButton,
            row([periodicBackupLabel, sized(periodicBackupField, 70), periodicBackupStepper]),
            row([backupOnSaveLabel, backupOnSavePopup]),
            useCustomBackupDirButton,
            row([sized(customBackupDirField, 280), customBackupDirBrowseButton])
        ])

        sectionViews[.autoCompletion] = column([
            row([autoCompleteLabel, sized(autoCompleteField, 58), autoCompleteStepper]),
            row([autoCompleteModeLabel, autoCompleteModePopup]),
            autoCompleteIgnoreNumbersButton,
            autoCompleteIgnoreCaseButton,
            autoCompleteChooseSingleButton,
            autoCompleteTABFillupButton,
            autoCompleteEnterCommitButton,
            autoCompleteBriefButton,
            htmlXmlCloseTagButton,
            autoPairButton,
            autoPairParenthesesButton,
            autoPairBracketsButton,
            autoPairCurlyBracketsButton,
            autoPairSingleQuotesButton,
            autoPairDoubleQuotesButton,
            customPairsScrollView,
            row([customPairsAddButton, customPairsRemoveButton])
        ])

        sectionViews[.multiInstanceDate] = column([
            row([dateTimeFormatLabel, sized(dateTimeFormatField, 220)])
        ])

        sectionViews[.delimiter] = column([
            row([delimiterLeftLabel, sized(delimiterLeftField, 50)]),
            row([delimiterRightLabel, sized(delimiterRightField, 50)])
        ])

        sectionViews[.performance] = column([
            row([largeFileMBLabel, sized(largeFileMBField, 70), largeFileMBStepper]),
            largeFileSuppressSyntaxHighlightButton,
            largeFileSuppressWordWrapButton,
            largeFileSuppressAutoCompleteButton,
            largeFileSuppressSmartHighlightButton,
            largeFileSuppressBraceMatchButton
        ])

        sectionViews[.cloudLink] = column([
            clickableLinksButton,
            row([urlIndicatorStyleLabel, urlIndicatorStyleSegmented]),
            row([extraURLSchemesLabel, sized(extraURLSchemesField, 240)])
        ])

        sectionViews[.searchEngine] = column([
            row([searchEngineChoiceLabel, searchEnginePopup]),
            row([searchEngineCustomURLLabel, sized(searchEngineCustomURLField, 300)])
        ])

        sectionViews[.misc] = column([
            row([fileAutoDetectionLabel, fileAutoDetectionPopup]),
            fileChangeDetectionButton,
            autoReloadButton,
            scrollToLastLineOnMonitorReloadButton,
            reloadScrollToLastCaretButton,
            updateSilentlyButton,
            trimTrailingSpacesOnSaveButton,
            pasteConvertEndingsButton,
            row([taskListTagsLabel, sized(taskListTagsField, 280)]),
            postItAlphaLabel,
            sized(postItAlphaSlider, 180)
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
        foldMarginStylePopup.selectItem(withTag: preferences.foldMarginStyle)
        if foldMarginStylePopup.selectedItem == nil {
            foldMarginStylePopup.selectItem(withTag: FoldMarginStyle.defaultRawValue)
        }
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
        showControlCharactersAndUnicodeEOLButton.state = preferences.showControlCharactersAndUnicodeEOL ? .on : .off
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
            showControlCharactersAndUnicodeEOL: showControlCharactersAndUnicodeEOLButton.state == .on,
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
            foldMarginStyle: foldMarginStylePopup.selectedItem?.tag ?? FoldMarginStyle.defaultRawValue,
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
        if tableView === sectionListTableView {
            return PreferenceSection.allCases.count
        }
        return customPairsData.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              tableView === sectionListTableView,
              let section = PreferenceSection(rawValue: tableView.selectedRow)
        else { return }
        showSection(section)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === sectionListTableView {
            guard let section = PreferenceSection(rawValue: row) else { return nil }
            let cellID = NSUserInterfaceItemIdentifier("SectionCell")
            if let cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = section.title
                return cell
            }
            let cell = NSTableCellView()
            cell.identifier = cellID
            let label = NSTextField(labelWithString: section.title)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }
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
        tableView === customPairsTableView
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard tableView === customPairsTableView,
              row < customPairsData.count, let value = object as? String else { return }
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
        case .none: Localization.string("pref.item.none", default: "None")
        case .simple: Localization.string("pref.backup.simple", default: "Simple (.bak)")
        case .verbose: Localization.string("pref.backup.verbose", default: "Verbose (timestamped .bak)")
        }
    }
}
