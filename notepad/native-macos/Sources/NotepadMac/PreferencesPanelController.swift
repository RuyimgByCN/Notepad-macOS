import AppKit
import NotepadMacCore

@MainActor
final class PreferencesPanelController: NSWindowController {
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
    private let openDirFollowsDocButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let folderDropAsWorkspaceButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
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
    private let wrapsLinesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabSizeLabel = NSTextField(labelWithString: "")
    private let tabSizeField = NSTextField(string: "")
    private let tabSizeStepper = NSStepper()
    private let insertSpacesButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPairButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let xmlTagMatchButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let clickableLinksButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smartHighlightMatchCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let smartHighlightWholeWordButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let caretWidthLabel = NSTextField(labelWithString: "")
    private let caretWidthSegmented = NSSegmentedControl()
    private let caretNoBlinkButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let currentLineFrameLabel = NSTextField(labelWithString: "")
    private let currentLineFrameSegmented = NSSegmentedControl()
    private let lineWrapIndentLabel = NSTextField(labelWithString: "")
    private let lineWrapIndentPopup = NSPopUpButton()
    private let foldMarginStyleLabel = NSTextField(labelWithString: "")
    private let foldMarginStylePopup = NSPopUpButton()
    private let virtualSpaceButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let backspaceUnindentsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoIndentButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let scrollBeyondLastLineButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let selectedTextDragDropButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let lineNumberDynamicWidthButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let columnSelectionToMultiEditingButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteLabel = NSTextField(labelWithString: "")
    private let autoCompleteField = NSTextField(string: "3")
    private let autoCompleteStepper = NSStepper()
    private let autoCompleteModeLabel = NSTextField(labelWithString: "")
    private let autoCompleteModePopup = NSPopUpButton()
    private let autoCompleteChooseSingleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoCompleteTABFillupButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let linePaddingLabel = NSTextField(labelWithString: "")
    private let linePaddingSegmented = NSSegmentedControl()
    private let largeFileSectionLabel = NSTextField(labelWithString: "")
    private let largeFileMBLabel = NSTextField(labelWithString: "")
    private let largeFileMBField = NSTextField(string: "50")
    private let largeFileMBStepper = NSStepper()
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
    // Tabbar section (in Window tab)
    private let tabbarSectionLabel = NSTextField(labelWithString: "")
    private let tabbarDoubleClickCloseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarLockDragDropButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarExitOnLastTabButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let tabbarMaxLabelLengthLabel = NSTextField(labelWithString: "")
    private let tabbarMaxLabelLengthField = NSTextField(string: "0")
    private let tabbarMaxLabelLengthStepper = NSStepper()

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
        xmlTagMatchButton.title = Localization.string(.preferencesXmlTagMatch, default: "Highlight matching XML tags")
        clickableLinksButton.title = Localization.string(.preferencesClickableLinks, default: "Highlight clickable links")
        smartHighlightMatchCaseButton.title = Localization.string(.preferencesSmartHighlightMatchCase, default: "Smart highlight: match case")
        smartHighlightWholeWordButton.title = Localization.string(.preferencesSmartHighlightWholeWord, default: "Smart highlight: whole word only")
        caretWidthLabel.stringValue = Localization.string(.preferencesCaretWidth, default: "Caret width:")
        if caretWidthSegmented.segmentCount == 3 {
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthThin, default: "Thin"), forSegment: 0)
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthMedium, default: "Medium"), forSegment: 1)
            caretWidthSegmented.setLabel(Localization.string(.preferencesCaretWidthThick, default: "Thick"), forSegment: 2)
        }
        caretNoBlinkButton.title = Localization.string(.preferencesCaretNoBlink, default: "Disable caret blinking")
        currentLineFrameLabel.stringValue = Localization.string(.preferencesCurrentLineFrame, default: "Current line highlight:")
        if currentLineFrameSegmented.segmentCount == 4 {
            currentLineFrameSegmented.setLabel(Localization.string(.preferencesCurrentLineFrameFill, default: "Fill"), forSegment: 0)
            currentLineFrameSegmented.setLabel("1px", forSegment: 1)
            currentLineFrameSegmented.setLabel("2px", forSegment: 2)
            currentLineFrameSegmented.setLabel("3px", forSegment: 3)
        }
        lineWrapIndentLabel.stringValue = Localization.string(.preferencesLineWrapIndent, default: "Wrap indent:")
        foldMarginStyleLabel.stringValue = Localization.string(.preferencesFoldMarginStyle, default: "Fold margin style:")
        virtualSpaceButton.title = Localization.string(.preferencesVirtualSpace, default: "Enable virtual space")
        backspaceUnindentsButton.title = Localization.string(.preferencesBackspaceUnindents, default: "Backspace key unindents")
        autoIndentButton.title = Localization.string(.preferencesAutoIndent, default: "Auto-indent new lines")
        scrollBeyondLastLineButton.title = Localization.string(.preferencesScrollBeyondLastLine, default: "Scroll beyond last line")
        selectedTextDragDropButton.title = "Allow dragging selected text within editor"
        lineNumberDynamicWidthButton.title = "Dynamic line number margin width"
        columnSelectionToMultiEditingButton.title = "Column selection converts to multi-cursor editing"
        linePaddingLabel.stringValue = Localization.string(.preferencesLinePadding, default: "Line padding:")
        autoCompleteLabel.stringValue = Localization.string(.preferencesAutoCompleteFrom, default: "Auto-complete from Nth character (0=off):")
        largeFileSectionLabel.stringValue = Localization.string(.preferencesLargeFileSection, default: "Large File")
        largeFileMBLabel.stringValue = Localization.string(.preferencesLargeFileMB, default: "Large file threshold (MB):")
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
        inSelectionSectionLabel.stringValue = "In-Selection Search"
        inSelectionThresholdLabel.stringValue = "Auto-check In Selection threshold (chars):"
        keepFindDialogOpenButton.title = "Keep Find dialog open after Replace All"
        replaceDoesNotMoveButton.title = "After Replace, don't move caret to replaced range"
        findDialogMonospaceButton.title = "Use monospaced font in Find / Replace fields"
        fillFindFromSelectionButton.title = "Fill Find field with selected text when opening Find dialog"
        autoSelectWordUnderCaretButton.title = "Auto-select word under caret when no selection"
        findInFilesIgnoreUnsavedButton.title = "Find in Files: ignore unsaved changes in open documents"
        copyLineWithoutSelectionButton.title = "Copy / Cut whole line when nothing is selected"
        smartHighlightUseFindSettingsButton.title = "Smart highlight uses Find dialog Match Case / Whole Word settings"
        urlIndicatorStyleLabel.stringValue = "URL style:"
        langTabOverridesLabel.stringValue = "Lang tabs:"
        langTabOverridesField.placeholderString = "python:4s, html:2s, c:8t  (langname:sizeS/T)"
        findTransparencyLabel.stringValue = "Find dialog transparency when unfocused:"
        tabbarSectionLabel.stringValue = "Tab Bar"
        tabbarDoubleClickCloseButton.title = "Double-click tab to close"
        tabbarLockDragDropButton.title = "Lock tab bar (disable drag-drop reordering)"
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
        generalSectionLabel.stringValue = "General"
        statusBarVisibleButton.title = "Show status bar"
        shortTitleButton.title = "Short title (filename only in title bar)"
        saveAllConfirmButton.title = "Confirm before Save All"
        autoCompleteIgnoreNumbersButton.title = "Auto-complete: ignore words starting with digits"
        printLineNumbersButton.title = "Print line numbers"
        openDirFollowsDocButton.title = Localization.string(.preferencesOpenDirFollowsDoc, default: "Open dialog starts in the current document's directory")
        folderDropAsWorkspaceButton.title = Localization.string(.preferencesFolderDropAsWorkspace, default: "Open dropped folder as workspace")
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

        [localizationPopup, fontSizeField, fontSizeStepper, wrapsLinesButton, tabSizeField, tabSizeStepper, insertSpacesButton, autoPairButton, xmlTagMatchButton, clickableLinksButton, smartHighlightMatchCaseButton, smartHighlightWholeWordButton, caretWidthSegmented, caretNoBlinkButton, currentLineFrameSegmented, lineWrapIndentPopup, foldMarginStylePopup, virtualSpaceButton, backspaceUnindentsButton, autoIndentButton, scrollBeyondLastLineButton, linePaddingSegmented, autoCompleteField, autoCompleteStepper, autoCompleteModePopup, autoCompleteChooseSingleButton, autoCompleteTABFillupButton, additionalEdgeColumnsField, largeFileMBField, largeFileMBStepper, rememberSessionButton, newDocumentOnLaunchButton, useFirstLineAsTabNameButton, recentFilesMaxField, recentFilesMaxStepper, recentFilesShowFullPathButton, noCheckRecentAtLaunchButton, keepAbsentFilesButton, autoReloadButton, snapshotModeButton, periodicBackupLabel, periodicBackupField, periodicBackupStepper, backupOnSaveLabel, backupOnSavePopup, useCustomBackupDirButton, customBackupDirField, customBackupDirBrowseButton, printLineNumbersButton, openDirFollowsDocButton, folderDropAsWorkspaceButton, defaultLangPopup, newDocEncodingPopup, newDocLineEndingPopup, searchMatchCaseButton, searchWholeWordButton, dateTimeFormatField, searchEnginePopup, searchEngineCustomURLField, extraURLSchemesField, inSelectionThresholdField, inSelectionThresholdStepper, keepFindDialogOpenButton, replaceDoesNotMoveButton, findDialogMonospaceButton, findTransparencySlider, fileChangeDetectionButton, copyLineWithoutSelectionButton, smartHighlightUseFindSettingsButton, urlIndicatorStyleSegmented, langTabOverridesField, tabbarDoubleClickCloseButton, tabbarLockDragDropButton, tabbarMaxLabelLengthField, tabbarMaxLabelLengthStepper, statusBarVisibleButton, shortTitleButton, saveAllConfirmButton, autoCompleteIgnoreNumbersButton, printHeaderLeftField, printHeaderCenterField, printHeaderRightField, printFooterLeftField, printFooterCenterField, printFooterRightField, printColorModePopup, printFontSizeField, printFontSizeStepper, delimiterLeftField, delimiterRightField].forEach {
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
        inSelectionThresholdStepper.minValue = 1
        inSelectionThresholdStepper.maxValue = 10000
        inSelectionThresholdStepper.increment = 64
        inSelectionThresholdField.formatter = integerFormatter
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
        caretWidthSegmented.segmentCount = 3
        caretWidthSegmented.setLabel("Thin", forSegment: 0)
        caretWidthSegmented.setLabel("Medium", forSegment: 1)
        caretWidthSegmented.setLabel("Thick", forSegment: 2)
        caretWidthSegmented.trackingMode = .selectOne

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

        linePaddingSegmented.segmentCount = 6
        for i in 0...5 { linePaddingSegmented.setLabel("\(i)px", forSegment: i) }
        linePaddingSegmented.trackingMode = .selectOne

        urlIndicatorStyleSegmented.segmentCount = 3
        urlIndicatorStyleSegmented.setLabel("Underline", forSegment: 0)
        urlIndicatorStyleSegmented.setLabel("Box", forSegment: 1)
        urlIndicatorStyleSegmented.setLabel("Full Box", forSegment: 2)
        urlIndicatorStyleSegmented.trackingMode = .selectOne

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
         autoPairButton, xmlTagMatchButton, clickableLinksButton,
         smartHighlightMatchCaseButton, smartHighlightWholeWordButton,
         caretWidthLabel, caretWidthSegmented, caretNoBlinkButton,
         currentLineFrameLabel, currentLineFrameSegmented,
         lineWrapIndentLabel, lineWrapIndentPopup,
         foldMarginStyleLabel, foldMarginStylePopup,
         virtualSpaceButton, backspaceUnindentsButton, autoIndentButton, scrollBeyondLastLineButton,
         selectedTextDragDropButton, lineNumberDynamicWidthButton, columnSelectionToMultiEditingButton,
         linePaddingLabel, linePaddingSegmented,
         autoCompleteLabel, autoCompleteField, autoCompleteStepper,
         largeFileSectionLabel, largeFileMBLabel, largeFileMBField, largeFileMBStepper,
         additionalEdgeColumnsLabel, additionalEdgeColumnsField,
         autoCompleteModeLabel, autoCompleteModePopup,
         autoCompleteChooseSingleButton, autoCompleteTABFillupButton,
         copyLineWithoutSelectionButton, smartHighlightUseFindSettingsButton,
         urlIndicatorStyleLabel, urlIndicatorStyleSegmented,
         langTabOverridesLabel, langTabOverridesField
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
         openDirFollowsDocButton, folderDropAsWorkspaceButton,
         defaultLangLabel, defaultLangPopup,
         fileChangeDetectionButton
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
         findTransparencyLabel, findTransparencySlider
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; toolsCV.addSubview($0) }

        // Tab 4 – Window
        [tabbarSectionLabel, tabbarDoubleClickCloseButton, tabbarLockDragDropButton,
         tabbarExitOnLastTabButton,
         tabbarMaxLabelLengthLabel, tabbarMaxLabelLengthField, tabbarMaxLabelLengthStepper,
         delimiterSectionLabel, delimiterLeftLabel, delimiterLeftField,
         delimiterRightLabel, delimiterRightField,
         generalSectionLabel, statusBarVisibleButton, shortTitleButton,
         saveAllConfirmButton, autoCompleteIgnoreNumbersButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; windowCV.addSubview($0) }

        [localizationSectionLabel, editorSectionLabel, editorFeaturesSectionLabel, largeFileSectionLabel, newDocumentSectionLabel, findDefaultsSectionLabel, dateTimeSectionLabel, searchEngineSectionLabel, inSelectionSectionLabel, tabbarSectionLabel, printSectionLabel, delimiterSectionLabel, generalSectionLabel].forEach {
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

            wrapsLinesButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            wrapsLinesButton.topAnchor.constraint(equalTo: fontSizeField.bottomAnchor, constant: 14),

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

            xmlTagMatchButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            xmlTagMatchButton.topAnchor.constraint(equalTo: autoPairButton.bottomAnchor, constant: 10),

            clickableLinksButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            clickableLinksButton.topAnchor.constraint(equalTo: xmlTagMatchButton.bottomAnchor, constant: 10),

            smartHighlightMatchCaseButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            smartHighlightMatchCaseButton.topAnchor.constraint(equalTo: clickableLinksButton.bottomAnchor, constant: 10),

            smartHighlightWholeWordButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            smartHighlightWholeWordButton.topAnchor.constraint(equalTo: smartHighlightMatchCaseButton.bottomAnchor, constant: 10),

            caretWidthLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            caretWidthLabel.topAnchor.constraint(equalTo: smartHighlightWholeWordButton.bottomAnchor, constant: 14),
            caretWidthLabel.widthAnchor.constraint(equalToConstant: 92),

            caretWidthSegmented.leadingAnchor.constraint(equalTo: caretWidthLabel.trailingAnchor, constant: 12),
            caretWidthSegmented.centerYAnchor.constraint(equalTo: caretWidthLabel.centerYAnchor),

            caretNoBlinkButton.leadingAnchor.constraint(equalTo: autoPairButton.leadingAnchor),
            caretNoBlinkButton.topAnchor.constraint(equalTo: caretWidthLabel.bottomAnchor, constant: 10),

            currentLineFrameLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            currentLineFrameLabel.topAnchor.constraint(equalTo: caretNoBlinkButton.bottomAnchor, constant: 10),
            currentLineFrameLabel.widthAnchor.constraint(equalToConstant: 140),

            currentLineFrameSegmented.leadingAnchor.constraint(equalTo: currentLineFrameLabel.trailingAnchor, constant: 8),
            currentLineFrameSegmented.centerYAnchor.constraint(equalTo: currentLineFrameLabel.centerYAnchor),

            lineWrapIndentLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            lineWrapIndentLabel.topAnchor.constraint(equalTo: currentLineFrameLabel.bottomAnchor, constant: 10),
            lineWrapIndentLabel.widthAnchor.constraint(equalToConstant: 140),

            lineWrapIndentPopup.leadingAnchor.constraint(equalTo: lineWrapIndentLabel.trailingAnchor, constant: 8),
            lineWrapIndentPopup.centerYAnchor.constraint(equalTo: lineWrapIndentLabel.centerYAnchor),

            foldMarginStyleLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            foldMarginStyleLabel.topAnchor.constraint(equalTo: lineWrapIndentLabel.bottomAnchor, constant: 10),
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

            linePaddingLabel.leadingAnchor.constraint(equalTo: fontSizeLabel.leadingAnchor),
            linePaddingLabel.topAnchor.constraint(equalTo: columnSelectionToMultiEditingButton.bottomAnchor, constant: 14),

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

            additionalEdgeColumnsLabel.leadingAnchor.constraint(equalTo: editorSectionLabel.leadingAnchor),
            additionalEdgeColumnsLabel.topAnchor.constraint(equalTo: largeFileMBLabel.bottomAnchor, constant: 14),
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

            copyLineWithoutSelectionButton.leadingAnchor.constraint(equalTo: fontSizeField.leadingAnchor),
            copyLineWithoutSelectionButton.topAnchor.constraint(equalTo: autoCompleteTABFillupButton.bottomAnchor, constant: 10),

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

            // Pin Tab1 content bottom
            editCV.bottomAnchor.constraint(equalTo: langTabOverridesLabel.bottomAnchor, constant: 24)
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

            snapshotModeButton.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            snapshotModeButton.topAnchor.constraint(equalTo: fileChangeDetectionButton.bottomAnchor, constant: 10),

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

            defaultLangLabel.leadingAnchor.constraint(equalTo: rememberSessionButton.leadingAnchor),
            defaultLangLabel.topAnchor.constraint(equalTo: folderDropAsWorkspaceButton.bottomAnchor, constant: 14),

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

            sessionCV.bottomAnchor.constraint(equalTo: printFontSizeLabel.bottomAnchor, constant: 24)
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

            findTransparencyLabel.leadingAnchor.constraint(equalTo: findDefaultsSectionLabel.leadingAnchor),
            findTransparencyLabel.topAnchor.constraint(equalTo: findInFilesIgnoreUnsavedButton.bottomAnchor, constant: 14),
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

            tabbarDoubleClickCloseButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarDoubleClickCloseButton.topAnchor.constraint(equalTo: tabbarSectionLabel.bottomAnchor, constant: 14),

            tabbarLockDragDropButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarLockDragDropButton.topAnchor.constraint(equalTo: tabbarDoubleClickCloseButton.bottomAnchor, constant: 10),

            tabbarExitOnLastTabButton.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarExitOnLastTabButton.topAnchor.constraint(equalTo: tabbarLockDragDropButton.bottomAnchor, constant: 10),

            tabbarMaxLabelLengthLabel.leadingAnchor.constraint(equalTo: tabbarSectionLabel.leadingAnchor),
            tabbarMaxLabelLengthLabel.topAnchor.constraint(equalTo: tabbarExitOnLastTabButton.bottomAnchor, constant: 14),
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

            windowCV.bottomAnchor.constraint(equalTo: autoCompleteIgnoreNumbersButton.bottomAnchor, constant: 24)
        ])
    }

    private func loadPreferences() {
        let preferences = preferencesStore.load()
        fontSizeField.doubleValue = preferences.editorFontSize
        fontSizeStepper.doubleValue = preferences.editorFontSize
        wrapsLinesButton.state = preferences.wrapsLines ? .on : .off
        tabSizeField.intValue = Int32(preferences.tabSize)
        tabSizeStepper.intValue = Int32(preferences.tabSize)
        insertSpacesButton.state = preferences.insertSpacesInsteadOfTabs ? .on : .off
        autoPairButton.state = preferences.enableAutoPair ? .on : .off
        xmlTagMatchButton.state = preferences.enableXmlTagMatch ? .on : .off
        clickableLinksButton.state = preferences.enableClickableLinks ? .on : .off
        smartHighlightMatchCaseButton.state = preferences.smartHighlightMatchCase ? .on : .off
        smartHighlightWholeWordButton.state = preferences.smartHighlightWholeWord ? .on : .off
        caretWidthSegmented.selectedSegment = max(0, min(2, preferences.caretWidth - 1))
        caretNoBlinkButton.state = preferences.caretNoBlink ? .on : .off
        currentLineFrameSegmented.selectedSegment = max(0, min(3, preferences.currentLineFrameWidth))
        lineWrapIndentPopup.selectItem(at: max(0, min(3, preferences.lineWrapIndent)))
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
        populateDefaultLangPopup(selected: preferences.defaultNewDocumentLanguageName)
        virtualSpaceButton.state = preferences.enableVirtualSpace ? .on : .off
        backspaceUnindentsButton.state = preferences.backspaceUnindents ? .on : .off
        autoIndentButton.state = preferences.autoIndent ? .on : .off
        scrollBeyondLastLineButton.state = preferences.scrollBeyondLastLine ? .on : .off
        selectedTextDragDropButton.state = preferences.selectedTextDragDrop ? .on : .off
        lineNumberDynamicWidthButton.state = preferences.lineNumberDynamicWidth ? .on : .off
        columnSelectionToMultiEditingButton.state = preferences.columnSelectionToMultiEditing ? .on : .off
        linePaddingSegmented.selectedSegment = max(0, min(5, preferences.linePadding))
        autoCompleteField.intValue = Int32(preferences.autoCompleteFromNthChar)
        autoCompleteStepper.intValue = Int32(preferences.autoCompleteFromNthChar)
        autoCompleteModePopup.selectItem(at: max(0, min(3, preferences.autoCompleteMode)))
        autoCompleteChooseSingleButton.state = preferences.autoCompleteChooseSingle ? .on : .off
        autoCompleteTABFillupButton.state = preferences.autoCompleteTABFillup ? .on : .off
        inSelectionThresholdField.intValue = Int32(preferences.inSelectionThreshold)
        inSelectionThresholdStepper.intValue = Int32(preferences.inSelectionThreshold)
        keepFindDialogOpenButton.state = preferences.keepFindDialogOpen ? .on : .off
        replaceDoesNotMoveButton.state = preferences.replaceDoesNotMove ? .on : .off
        findDialogMonospaceButton.state = preferences.findDialogMonospace ? .on : .off
        fillFindFromSelectionButton.state = preferences.fillFindFromSelection ? .on : .off
        autoSelectWordUnderCaretButton.state = preferences.autoSelectWordUnderCaret ? .on : .off
        findInFilesIgnoreUnsavedButton.state = preferences.findInFilesIgnoreUnsaved ? .on : .off
        copyLineWithoutSelectionButton.state = preferences.copyLineWithoutSelection ? .on : .off
        smartHighlightUseFindSettingsButton.state = preferences.smartHighlightUseFindSettings ? .on : .off
        urlIndicatorStyleSegmented.selectedSegment = max(0, min(2, preferences.urlIndicatorStyle))
        langTabOverridesField.stringValue = preferences.languageTabOverrides
        findTransparencySlider.doubleValue = preferences.findDialogTransparency
        tabbarDoubleClickCloseButton.state = preferences.tabbarDoubleClickClose ? .on : .off
        tabbarLockDragDropButton.state = preferences.tabbarLockDragDrop ? .on : .off
        tabbarExitOnLastTabButton.state = preferences.tabbarExitOnLastTab ? .on : .off
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
        delimiterLeftField.stringValue = preferences.delimiterLeft
        delimiterRightField.stringValue = preferences.delimiterRight
        statusBarVisibleButton.state = preferences.statusBarVisible ? .on : .off
        shortTitleButton.state = preferences.shortTitle ? .on : .off
        saveAllConfirmButton.state = preferences.saveAllConfirm ? .on : .off
        autoCompleteIgnoreNumbersButton.state = preferences.autoCompleteIgnoreNumbers ? .on : .off
        largeFileMBField.intValue = Int32(preferences.largeFileSizeMB)
        largeFileMBStepper.intValue = Int32(preferences.largeFileSizeMB)
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
            showWhitespace: existing.showWhitespace,
            showEOL: existing.showEOL,
            showIndentGuides: existing.showIndentGuides,
            highlightCurrentLine: existing.highlightCurrentLine,
            showWrapSymbol: existing.showWrapSymbol,
            showChangeHistory: existing.showChangeHistory,
            tabSize: Int(tabSizeField.intValue),
            insertSpacesInsteadOfTabs: insertSpacesButton.state == .on,
            showLineNumberMargin: existing.showLineNumberMargin,
            showEdgeLine: existing.showEdgeLine,
            edgeLineColumn: existing.edgeLineColumn,
            enableAutoPair: autoPairButton.state == .on,
            enableXmlTagMatch: xmlTagMatchButton.state == .on,
            enableClickableLinks: clickableLinksButton.state == .on,
            defaultNewDocumentEncoding: selectedNewDocEncoding,
            defaultNewDocumentLineEnding: selectedNewDocLineEnding,
            rememberLastSession: rememberSessionButton.state == .on,
            showNpcCharacters: existing.showNpcCharacters,
            smartHighlightMatchCase: smartHighlightMatchCaseButton.state == .on,
            smartHighlightWholeWord: smartHighlightWholeWordButton.state == .on,
            caretWidth: caretWidthSegmented.selectedSegment + 1,
            enableVirtualSpace: virtualSpaceButton.state == .on,
            backspaceUnindents: backspaceUnindentsButton.state == .on,
            autoIndent: autoIndentButton.state == .on,
            largeFileSizeMB: Int(largeFileMBField.intValue),
            scrollBeyondLastLine: scrollBeyondLastLineButton.state == .on,
            autoCompleteFromNthChar: Int(autoCompleteField.intValue),
            caretNoBlink: caretNoBlinkButton.state == .on,
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
            extraURLSchemes: extraURLSchemesField.stringValue,
            newDocumentOnLaunch: newDocumentOnLaunchButton.state == .on,
            printLineNumbers: printLineNumbersButton.state == .on,
            autoCompleteMode: autoCompleteModePopup.indexOfSelectedItem,
            autoCompleteChooseSingle: autoCompleteChooseSingleButton.state == .on,
            autoCompleteTABFillup: autoCompleteTABFillupButton.state == .on,
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
                marginTop: existing.printSettings.marginTop,
                marginBottom: existing.printSettings.marginBottom,
                marginLeft: existing.printSettings.marginLeft,
                marginRight: existing.printSettings.marginRight
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
            selectedTextDragDrop: selectedTextDragDropButton.state == .on,
            lineNumberDynamicWidth: lineNumberDynamicWidthButton.state == .on,
            columnSelectionToMultiEditing: columnSelectionToMultiEditingButton.state == .on
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
