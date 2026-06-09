import XCTest
import NotepadMacCore

final class PreferencesEnhancementTests: XCTestCase {

    // MARK: - AutoComplete Mode

    func testAutoCompleteModeDefaultIsThree() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.autoCompleteMode, 3, "Default auto-complete mode should be 3 (function + words)")
    }

    func testAutoCompleteModeClampedToZeroToThree() {
        let tooHigh = AppPreferences(autoCompleteMode: 99)
        XCTAssertEqual(tooHigh.autoCompleteMode, 3)
        let negative = AppPreferences(autoCompleteMode: -1)
        XCTAssertEqual(negative.autoCompleteMode, 0)
        let valid = AppPreferences(autoCompleteMode: 1)
        XCTAssertEqual(valid.autoCompleteMode, 1)
    }

    func testAutoCompleteChooseSingleDefault() {
        let prefs = AppPreferences()
        XCTAssertTrue(prefs.autoCompleteChooseSingle)
    }

    func testAutoCompleteTABFillupDefault() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.autoCompleteTABFillup)
    }

    // MARK: - In-Selection Threshold

    func testInSelectionThresholdDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.inSelectionThreshold, 1024)
    }

    func testInSelectionThresholdMinimumIsOne() {
        let prefs = AppPreferences(inSelectionThreshold: 0)
        XCTAssertEqual(prefs.inSelectionThreshold, 1)
        let negative = AppPreferences(inSelectionThreshold: -5)
        XCTAssertEqual(negative.inSelectionThreshold, 1)
    }

    func testInSelectionThresholdCustomValue() {
        let prefs = AppPreferences(inSelectionThreshold: 512)
        XCTAssertEqual(prefs.inSelectionThreshold, 512)
    }

    // MARK: - Keep Find Dialog Open

    func testKeepFindDialogOpenDefault() {
        let prefs = AppPreferences()
        XCTAssertTrue(prefs.keepFindDialogOpen)
    }

    func testKeepFindDialogOpenCanBeDisabled() {
        let prefs = AppPreferences(keepFindDialogOpen: false)
        XCTAssertFalse(prefs.keepFindDialogOpen)
    }

    // MARK: - Tabbar Preferences

    func testTabbarDoubleClickCloseDefault() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.tabbarDoubleClickClose)
    }

    func testTabbarMaxLabelLengthDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.tabbarMaxLabelLength, 0, "Default max label length should be 0 (no limit)")
    }

    func testTabbarMaxLabelLengthClampedToNonNegative() {
        let prefs = AppPreferences(tabbarMaxLabelLength: -5)
        XCTAssertEqual(prefs.tabbarMaxLabelLength, 0)
    }

    func testTabbarMaxLabelLengthCustomValue() {
        let prefs = AppPreferences(tabbarMaxLabelLength: 30)
        XCTAssertEqual(prefs.tabbarMaxLabelLength, 30)
    }

    // MARK: - Persistence Round-trip

    func testNewPreferencesRoundTripViaPreferencesStore() {
        let defaults = UserDefaults(suiteName: "PreferencesEnhancementTests.roundtrip")!
        defer { defaults.removePersistentDomain(forName: "PreferencesEnhancementTests.roundtrip") }

        let store = PreferencesStore(defaults: defaults)
        let written = AppPreferences(
            autoCompleteMode: 1,
            autoCompleteChooseSingle: false,
            autoCompleteTABFillup: true,
            inSelectionThreshold: 256,
            tabbarDoubleClickClose: true,
            tabbarMaxLabelLength: 25,
            keepFindDialogOpen: false
        )
        store.save(written)
        let read = store.load()

        XCTAssertEqual(read.autoCompleteMode, 1)
        XCTAssertFalse(read.autoCompleteChooseSingle)
        XCTAssertTrue(read.autoCompleteTABFillup)
        XCTAssertEqual(read.inSelectionThreshold, 256)
        XCTAssertTrue(read.tabbarDoubleClickClose)
        XCTAssertEqual(read.tabbarMaxLabelLength, 25)
        XCTAssertFalse(read.keepFindDialogOpen)
    }

    // MARK: - Previously broken save/load fields

    func testNewDocumentOnLaunchPersists() {
        let defaults = UserDefaults(suiteName: "PreferencesEnhancementTests.newDocOnLaunch")!
        defer { defaults.removePersistentDomain(forName: "PreferencesEnhancementTests.newDocOnLaunch") }

        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(newDocumentOnLaunch: false))
        let read = store.load()
        XCTAssertFalse(read.newDocumentOnLaunch, "newDocumentOnLaunch should persist via UserDefaults")
    }

    func testPrintLineNumbersPersists() {
        let defaults = UserDefaults(suiteName: "PreferencesEnhancementTests.printLineNumbers")!
        defer { defaults.removePersistentDomain(forName: "PreferencesEnhancementTests.printLineNumbers") }

        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(printLineNumbers: false))
        let read = store.load()
        XCTAssertFalse(read.printLineNumbers, "printLineNumbers should persist via UserDefaults")
    }

    func testPostItAlphaPersists() {
        let defaults = UserDefaults(suiteName: "PreferencesEnhancementTests.postItAlpha")!
        defer { defaults.removePersistentDomain(forName: "PreferencesEnhancementTests.postItAlpha") }

        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(postItAlpha: 0.5))
        let read = store.load()
        XCTAssertEqual(read.postItAlpha, 0.5, accuracy: 0.001, "postItAlpha should persist via UserDefaults")
    }

    // MARK: - Per-Language Tab Overrides

    func testParsedLanguageTabOverridesEmptyString() {
        let prefs = AppPreferences(languageTabOverrides: "")
        XCTAssertTrue(prefs.parsedLanguageTabOverrides().isEmpty)
    }

    func testParsedLanguageTabOverridesSpaces() {
        let prefs = AppPreferences(languageTabOverrides: "python:4s")
        let overrides = prefs.parsedLanguageTabOverrides()
        XCTAssertEqual(overrides["python"]?.tabSize, 4)
        XCTAssertEqual(overrides["python"]?.insertSpaces, true)
    }

    func testParsedLanguageTabOverridesTabs() {
        let prefs = AppPreferences(languageTabOverrides: "c:8t")
        let overrides = prefs.parsedLanguageTabOverrides()
        XCTAssertEqual(overrides["c"]?.tabSize, 8)
        XCTAssertEqual(overrides["c"]?.insertSpaces, false)
    }

    func testParsedLanguageTabOverridesMultiple() {
        let prefs = AppPreferences(languageTabOverrides: "python:4s, html:2s, c:8t")
        let overrides = prefs.parsedLanguageTabOverrides()
        XCTAssertEqual(overrides.count, 3)
        XCTAssertEqual(overrides["html"]?.tabSize, 2)
        XCTAssertEqual(overrides["html"]?.insertSpaces, true)
    }

    func testParsedLanguageTabOverridesIgnoresInvalidEntries() {
        let prefs = AppPreferences(languageTabOverrides: "python:4s, invalid, bad:xs, java:2")
        let overrides = prefs.parsedLanguageTabOverrides()
        XCTAssertEqual(overrides.count, 1)
        XCTAssertNotNil(overrides["python"])
    }

    func testParsedLanguageTabOverridesCaseInsensitive() {
        let prefs = AppPreferences(languageTabOverrides: "PYTHON:4s")
        let overrides = prefs.parsedLanguageTabOverrides()
        XCTAssertNotNil(overrides["python"])
    }

    // MARK: - URL Indicator Style

    func testUrlIndicatorStyleClamped() {
        XCTAssertEqual(AppPreferences(urlIndicatorStyle: -1).urlIndicatorStyle, 0)
        XCTAssertEqual(AppPreferences(urlIndicatorStyle: 3).urlIndicatorStyle, 2)
        XCTAssertEqual(AppPreferences(urlIndicatorStyle: 1).urlIndicatorStyle, 1)
    }

    // MARK: - Appearance Mode

    func testAppearanceModeDefault() {
        XCTAssertEqual(AppPreferences().appearanceMode, 0)
    }

    func testAppearanceModeClamped() {
        XCTAssertEqual(AppPreferences(appearanceMode: -1).appearanceMode, 0)
        XCTAssertEqual(AppPreferences(appearanceMode: 3).appearanceMode, 2)
        XCTAssertEqual(AppPreferences(appearanceMode: 1).appearanceMode, 1)
        XCTAssertEqual(AppPreferences(appearanceMode: 2).appearanceMode, 2)
    }

    func testAppearanceModeRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.appearanceMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(appearanceMode: 2))
        let loaded = store.load()
        XCTAssertEqual(loaded.appearanceMode, 2)
    }

    // MARK: - Mute All Sounds

    func testMuteAllSoundsDefault() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.muteAllSounds)
    }

    func testMuteAllSoundsRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.muteAllSounds.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(muteAllSounds: true))
        let loaded = store.load()
        XCTAssertTrue(loaded.muteAllSounds)
    }

    func testMuteAllSoundsCanBeDisabled() {
        let prefs = AppPreferences(muteAllSounds: false)
        XCTAssertFalse(prefs.muteAllSounds)
    }

    // MARK: - Large File Performance Suppression

    func testLargeFileSuppressAutoCompleteDefault() {
        XCTAssertTrue(AppPreferences().largeFileSuppressAutoComplete)
    }

    func testLargeFileSuppressSmartHighlightDefault() {
        XCTAssertTrue(AppPreferences().largeFileSuppressSmartHighlight)
    }

    func testLargeFileSuppressBraceMatchDefault() {
        XCTAssertTrue(AppPreferences().largeFileSuppressBraceMatch)
    }

    func testLargeFileSuppressAutoCompleteRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.largeFileSuppressAC.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(largeFileSuppressAutoComplete: false))
        XCTAssertFalse(store.load().largeFileSuppressAutoComplete)
    }

    func testLargeFileSuppressSmartHighlightRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.largeFileSuppressSH.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(largeFileSuppressSmartHighlight: false))
        XCTAssertFalse(store.load().largeFileSuppressSmartHighlight)
    }

    func testLargeFileSuppressBraceMatchRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.largeFileSuppressBM.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(largeFileSuppressBraceMatch: false))
        XCTAssertFalse(store.load().largeFileSuppressBraceMatch)
    }

    func testLargeFileSuppressWordWrapDefault() {
        XCTAssertTrue(AppPreferences().largeFileSuppressWordWrap)
    }

    func testLargeFileSuppressWordWrapRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.largeFileSuppressWW.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(largeFileSuppressWordWrap: false))
        XCTAssertFalse(store.load().largeFileSuppressWordWrap)
    }

    func testLargeFileSuppressSyntaxHighlightDefault() {
        XCTAssertTrue(AppPreferences().largeFileSuppressSyntaxHighlight)
    }

    func testLargeFileSuppressSyntaxHighlightRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.largeFileSuppressSH2.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(largeFileSuppressSyntaxHighlight: false))
        XCTAssertFalse(store.load().largeFileSuppressSyntaxHighlight)
    }

    // MARK: - Tab Bar Hide

    func testTabbarHideDefault() {
        XCTAssertFalse(AppPreferences().tabbarHide)
    }

    func testTabbarHideRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.tabbarHide.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(tabbarHide: true))
        XCTAssertTrue(store.load().tabbarHide)
    }

    // MARK: - Reload Scroll To Last Caret

    func testReloadScrollToLastCaretDefault() {
        XCTAssertFalse(AppPreferences().reloadScrollToLastCaret)
    }

    func testReloadScrollToLastCaretRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.reloadScrollToLastCaret.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(reloadScrollToLastCaret: true))
        XCTAssertTrue(store.load().reloadScrollToLastCaret)
    }

    // MARK: - Tab Bar Show Close Button

    func testTabbarShowCloseButtonDefault() {
        XCTAssertTrue(AppPreferences().tabbarShowCloseButton)
    }

    func testTabbarShowCloseButtonRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.tabbarShowCloseButton.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(tabbarShowCloseButton: false))
        XCTAssertFalse(store.load().tabbarShowCloseButton)
    }

    // MARK: - Editor Font Name and Bold

    func testEditorFontNameDefault() {
        XCTAssertEqual(AppPreferences().editorFontName, "")
    }

    func testEditorFontNameRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.editorFontName.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(editorFontName: "Courier New"))
        XCTAssertEqual(store.load().editorFontName, "Courier New")
    }

    func testEditorFontBoldDefault() {
        XCTAssertFalse(AppPreferences().editorFontBold)
    }

    func testEditorFontBoldRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.editorFontBold.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(editorFontBold: true))
        XCTAssertTrue(store.load().editorFontBold)
    }

    // MARK: - Confirm Replace In All Docs

    func testConfirmReplaceInAllDocsDefault() {
        XCTAssertTrue(AppPreferences().confirmReplaceInAllDocs)
    }

    func testConfirmReplaceInAllDocsRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.confirmReplaceInAllDocs.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(confirmReplaceInAllDocs: false))
        XCTAssertFalse(store.load().confirmReplaceInAllDocs)
    }

    // MARK: - Max Find History Count

    func testMaxFindHistoryCountDefault() {
        XCTAssertEqual(AppPreferences().maxFindHistoryCount, 20)
    }

    func testMaxFindHistoryCountClampedAndRoundtrip() {
        XCTAssertEqual(AppPreferences(maxFindHistoryCount: 0).maxFindHistoryCount, 1)
        XCTAssertEqual(AppPreferences(maxFindHistoryCount: 100).maxFindHistoryCount, 50)

        let defaults = UserDefaults(suiteName: "test.maxFindHistoryCount.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(maxFindHistoryCount: 30))
        XCTAssertEqual(store.load().maxFindHistoryCount, 30)
    }

    // MARK: - Caret Blink Rate

    func testCaretBlinkRateDefault() {
        XCTAssertEqual(AppPreferences().caretBlinkRate, 500)
    }

    func testCaretBlinkRateClampedAndRoundtrip() {
        XCTAssertEqual(AppPreferences(caretBlinkRate: 50).caretBlinkRate, 100)
        XCTAssertEqual(AppPreferences(caretBlinkRate: 5000).caretBlinkRate, 2000)

        let defaults = UserDefaults(suiteName: "test.caretBlinkRate.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(caretBlinkRate: 800))
        XCTAssertEqual(store.load().caretBlinkRate, 800)
    }

    // MARK: - Trim Trailing Spaces on Save

    func testTrimTrailingSpacesOnSaveDefault() {
        XCTAssertFalse(AppPreferences().trimTrailingSpacesOnSave)
    }

    func testTrimTrailingSpacesOnSaveRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.trimTrailingSpacesOnSave.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(trimTrailingSpacesOnSave: true))
        XCTAssertTrue(store.load().trimTrailingSpacesOnSave)
    }

    // MARK: - Paste Convert Endings

    func testPasteConvertEndingsDefault() {
        XCTAssertTrue(AppPreferences().pasteConvertEndings)
    }

    func testPasteConvertEndingsRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.pasteConvertEndings.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(pasteConvertEndings: false))
        XCTAssertFalse(store.load().pasteConvertEndings)
    }

    // MARK: - Caret Sticky Mode

    func testCaretStickyModeDefault() {
        XCTAssertEqual(AppPreferences().caretStickyMode, 0)
    }

    func testCaretStickyModeRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.caretStickyMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(caretStickyMode: 2))
        XCTAssertEqual(store.load().caretStickyMode, 2)
    }

    // MARK: - Enable Code Folding

    func testEnableCodeFoldingDefault() {
        XCTAssertTrue(AppPreferences().enableCodeFolding)
    }

    func testEnableCodeFoldingRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.enableCodeFolding.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(enableCodeFolding: false))
        XCTAssertFalse(store.load().enableCodeFolding)
    }

    func testFoldMarginStyleDefaultsToUpstreamBoxTree() {
        XCTAssertEqual(AppPreferences().foldMarginStyle, 4)
    }

    func testFoldMarginStyleMigratesLegacyStoredValuesToUpstreamRawValues() {
        let expectations = [
            0: 4,
            1: 4,
            2: 3
        ]

        for (legacy, upstream) in expectations {
            let defaults = UserDefaults(suiteName: "test.foldMarginStyle.legacy.\(legacy).\(UUID().uuidString)")!
            defaults.set(legacy, forKey: "notepadMac.foldMarginStyle")
            let store = PreferencesStore(defaults: defaults)

            XCTAssertEqual(store.load().foldMarginStyle, upstream)
        }
    }

    func testFoldMarginStyleRoundtripsAllUpstreamOptions() {
        let defaults = UserDefaults(suiteName: "test.foldMarginStyle.upstream.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)

        for style in 1...5 {
            store.save(AppPreferences(foldMarginStyle: style))
            XCTAssertEqual(store.load().foldMarginStyle, style)
        }
    }

    // MARK: - Auto-Complete Ignore Case

    func testAutoCompleteIgnoreCaseDefault() {
        XCTAssertTrue(AppPreferences().autoCompleteIgnoreCase)
    }

    func testAutoCompleteIgnoreCaseRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.autoCompleteIgnoreCase.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(autoCompleteIgnoreCase: false))
        XCTAssertFalse(store.load().autoCompleteIgnoreCase)
    }

    // MARK: - Whitespace Display Mode

    func testWhitespaceDisplayModeDefault() {
        XCTAssertEqual(AppPreferences().whitespaceDisplayMode, 0)
    }

    func testWhitespaceDisplayModeRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.whitespaceDisplayMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(whitespaceDisplayMode: 2))
        XCTAssertEqual(store.load().whitespaceDisplayMode, 2)
    }

    // MARK: - Bidi Mode

    func testBidiModeDefault() {
        XCTAssertEqual(AppPreferences().bidiMode, 0)
    }

    func testBidiModeRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.bidiMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(bidiMode: 2))
        XCTAssertEqual(store.load().bidiMode, 2)
    }

    // MARK: - Smooth Font

    func testSmoothFontDefault() {
        XCTAssertTrue(AppPreferences().smoothFont, "Default smooth font should be true")
    }

    func testSmoothFontRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.smoothFont.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(smoothFont: false))
        XCTAssertFalse(store.load().smoothFont)
    }

    // MARK: - Multi-Edit Enabled

    func testMultiEditEnabledDefault() {
        XCTAssertTrue(AppPreferences().multiEditEnabled, "Default multi-edit should be true")
    }

    func testMultiEditEnabledRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.multiEditEnabled.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(multiEditEnabled: false))
        XCTAssertFalse(store.load().multiEditEnabled)
    }

    // MARK: - Multi-Paste Mode

    func testMultiPasteModeDefault() {
        XCTAssertEqual(AppPreferences().multiPasteMode, 1, "Default multi-paste mode should be 1 (each)")
    }

    func testMultiPasteModeClampedAndRoundtrip() {
        let clamped = AppPreferences(multiPasteMode: 99)
        XCTAssertEqual(clamped.multiPasteMode, 1, "Should clamp to max 1")
        let negative = AppPreferences(multiPasteMode: -1)
        XCTAssertEqual(negative.multiPasteMode, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.multiPasteMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(multiPasteMode: 0))
        XCTAssertEqual(store.load().multiPasteMode, 0)
    }

    // MARK: - Indent Guide Mode

    func testIndentGuideModeDefault() {
        XCTAssertEqual(AppPreferences().indentGuideMode, 2, "Default indent guide mode should be 2 (lookForward)")
    }

    func testIndentGuideModeClampedAndRoundtrip() {
        let clamped = AppPreferences(indentGuideMode: 99)
        XCTAssertEqual(clamped.indentGuideMode, 3, "Should clamp to max 3")
        let negative = AppPreferences(indentGuideMode: -1)
        XCTAssertEqual(negative.indentGuideMode, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.indentGuideMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(indentGuideMode: 3))
        XCTAssertEqual(store.load().indentGuideMode, 3)
    }

    // MARK: - Word Wrap Mode

    func testWordWrapModeDefault() {
        XCTAssertEqual(AppPreferences().wordWrapMode, 1, "Default word wrap mode should be 1 (word)")
    }

    func testWordWrapModeClampedAndRoundtrip() {
        let clamped = AppPreferences(wordWrapMode: 99)
        XCTAssertEqual(clamped.wordWrapMode, 3, "Should clamp to max 3")
        let negative = AppPreferences(wordWrapMode: -1)
        XCTAssertEqual(negative.wordWrapMode, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.wordWrapMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(wordWrapMode: 2))
        XCTAssertEqual(store.load().wordWrapMode, 2)
    }

    // MARK: - Additional Selection Alpha

    func testAdditionalSelAlphaDefault() {
        XCTAssertEqual(AppPreferences().additionalSelAlpha, 256, "Default should be 256 (opaque)")
    }

    func testAdditionalSelAlphaClampedAndRoundtrip() {
        let clamped = AppPreferences(additionalSelAlpha: 999)
        XCTAssertEqual(clamped.additionalSelAlpha, 256, "Should clamp to max 256")
        let negative = AppPreferences(additionalSelAlpha: -5)
        XCTAssertEqual(negative.additionalSelAlpha, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.additionalSelAlpha.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(additionalSelAlpha: 128))
        XCTAssertEqual(store.load().additionalSelAlpha, 128)
    }

    // MARK: - Additional Carets Blink

    func testAdditionalCaretsBlinkDefault() {
        XCTAssertTrue(AppPreferences().additionalCaretsBlink, "Default should be true")
    }

    func testAdditionalCaretsBlinkRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.additionalCaretsBlink.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(additionalCaretsBlink: false))
        XCTAssertFalse(store.load().additionalCaretsBlink)
    }

    // MARK: - Additional Carets Visible

    func testAdditionalCaretsVisibleDefault() {
        XCTAssertTrue(AppPreferences().additionalCaretsVisible, "Default should be true")
    }

    func testAdditionalCaretsVisibleRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.additionalCaretsVisible.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(additionalCaretsVisible: false))
        XCTAssertFalse(store.load().additionalCaretsVisible)
    }

    // MARK: - Caret Line Visible Always

    func testCaretLineVisibleAlwaysDefault() {
        XCTAssertFalse(AppPreferences().caretLineVisibleAlways, "Default should be false")
    }

    func testCaretLineVisibleAlwaysRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.caretLineVisibleAlways.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(caretLineVisibleAlways: true))
        XCTAssertTrue(store.load().caretLineVisibleAlways)
    }

    // MARK: - Whitespace Size

    func testWhitespaceSizeDefault() {
        XCTAssertEqual(AppPreferences().whitespaceSize, 1, "Default should be 1")
    }

    func testWhitespaceSizeClampedAndRoundtrip() {
        let clamped = AppPreferences(whitespaceSize: 99)
        XCTAssertEqual(clamped.whitespaceSize, 5, "Should clamp to max 5")
        let zero = AppPreferences(whitespaceSize: 0)
        XCTAssertEqual(zero.whitespaceSize, 1, "Should clamp to min 1")
        let defaults = UserDefaults(suiteName: "test.whitespaceSize.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(whitespaceSize: 3))
        XCTAssertEqual(store.load().whitespaceSize, 3)
    }

    // MARK: - Selection Alpha

    func testSelectionAlphaDefault() {
        XCTAssertEqual(AppPreferences().selectionAlpha, 256, "Default should be 256 (opaque)")
    }

    func testSelectionAlphaClampedAndRoundtrip() {
        let clamped = AppPreferences(selectionAlpha: 999)
        XCTAssertEqual(clamped.selectionAlpha, 256, "Should clamp to max 256")
        let negative = AppPreferences(selectionAlpha: -5)
        XCTAssertEqual(negative.selectionAlpha, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.selectionAlpha.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(selectionAlpha: 128))
        XCTAssertEqual(store.load().selectionAlpha, 128)
    }

    // MARK: - Control Char Display

    func testControlCharDisplayDefault() {
        XCTAssertEqual(AppPreferences().controlCharDisplay, 0, "Default should be 0 (glyph)")
    }

    func testControlCharDisplayClampedAndRoundtrip() {
        let clamped = AppPreferences(controlCharDisplay: 99)
        XCTAssertEqual(clamped.controlCharDisplay, 6, "Should clamp to max 6")
        let negative = AppPreferences(controlCharDisplay: -1)
        XCTAssertEqual(negative.controlCharDisplay, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.controlCharDisplay.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(controlCharDisplay: 3))
        XCTAssertEqual(store.load().controlCharDisplay, 3)
    }

    // MARK: - Auto-Indent Mode

    func testAutoIndentModeDefault() {
        XCTAssertEqual(AppPreferences().autoIndentMode, 1, "Default should be 1 (basic)")
    }

    func testAutoIndentModeClampedAndRoundtrip() {
        let clamped = AppPreferences(autoIndentMode: 99)
        XCTAssertEqual(clamped.autoIndentMode, 2, "Should clamp to max 2")
        let negative = AppPreferences(autoIndentMode: -1)
        XCTAssertEqual(negative.autoIndentMode, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.autoIndentMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(autoIndentMode: 2))
        XCTAssertEqual(store.load().autoIndentMode, 2)
    }

    // MARK: - File Auto-Detection

    func testFileAutoDetectionDefault() {
        XCTAssertEqual(AppPreferences().fileAutoDetection, 1, "Default should be 1 (on-activate)")
    }

    func testFileAutoDetectionClampedAndRoundtrip() {
        let clamped = AppPreferences(fileAutoDetection: 99)
        XCTAssertEqual(clamped.fileAutoDetection, 2, "Should clamp to max 2")
        let negative = AppPreferences(fileAutoDetection: -1)
        XCTAssertEqual(negative.fileAutoDetection, 0, "Should clamp to min 0")
        let defaults = UserDefaults(suiteName: "test.fileAutoDetection.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(fileAutoDetection: 2))
        XCTAssertEqual(store.load().fileAutoDetection, 2)
    }

    // MARK: - Update Silently

    func testUpdateSilentlyDefault() {
        XCTAssertFalse(AppPreferences().updateSilently, "Default should be false")
    }

    func testUpdateSilentlyRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.updateSilently.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(updateSilently: true))
        XCTAssertTrue(store.load().updateSilently)
    }

    // MARK: - Zoom Sync To All Tabs

    func testZoomSyncToAllTabsDefault() {
        XCTAssertFalse(AppPreferences().zoomSyncToAllTabs, "Default should be false")
    }

    func testZoomSyncToAllTabsRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.zoomSyncToAllTabs.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(zoomSyncToAllTabs: true))
        XCTAssertTrue(store.load().zoomSyncToAllTabs)
    }

    // MARK: - Hide Menu Shortcuts

    func testHideMenuShortcutsDefault() {
        XCTAssertFalse(AppPreferences().hideMenuShortcuts, "Default should be false")
    }

    func testHideMenuShortcutsRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.hideMenuShortcuts.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(hideMenuShortcuts: true))
        XCTAssertTrue(store.load().hideMenuShortcuts)
    }

    // MARK: - Scroll To Last Line On Monitor Reload

    func testScrollToLastLineOnMonitorReloadDefault() {
        XCTAssertFalse(AppPreferences().scrollToLastLineOnMonitorReload, "Default should be false")
    }

    func testScrollToLastLineOnMonitorReloadRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.scrollToLastLineOnMonitorReload.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(scrollToLastLineOnMonitorReload: true))
        XCTAssertTrue(store.load().scrollToLastLineOnMonitorReload)
    }

    // MARK: - Tabbar Compact

    func testTabbarCompactDefaultIsFalse() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.tabbarCompact)
    }

    func testTabbarCompactRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.tabbarCompact.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(tabbarCompact: true))
        XCTAssertTrue(store.load().tabbarCompact)
    }

    // MARK: - Open ANSI as UTF-8

    func testOpenAnsiAsUtf8Default() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.openAnsiAsUtf8, "Default openAnsiAsUtf8 should be false")
    }

    func testOpenAnsiAsUtf8Roundtrip() {
        let defaults = UserDefaults(suiteName: "test.openAnsiAsUtf8.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(openAnsiAsUtf8: true))
        XCTAssertTrue(store.load().openAnsiAsUtf8)
    }

    // MARK: - XML Tag Attribute Highlight

    func testXmlTagAttributeHighlightDefault() {
        let prefs = AppPreferences()
        XCTAssertTrue(prefs.xmlTagAttributeHighlight, "Default xmlTagAttributeHighlight should be true")
    }

    func testXmlTagAttributeHighlightRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.xmlTagAttrHighlight.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(xmlTagAttributeHighlight: false))
        XCTAssertFalse(store.load().xmlTagAttributeHighlight)
    }

    // MARK: - Highlight Non-HTML Zone

    func testHighlightNonHtmlZoneDefault() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.highlightNonHtmlZone, "Default highlightNonHtmlZone should be false")
    }

    func testHighlightNonHtmlZoneRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.highlightNonHtmlZone.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(highlightNonHtmlZone: true))
        XCTAssertTrue(store.load().highlightNonHtmlZone)
    }

    // MARK: - Default Save Directory

    func testDefaultSaveDirectoryDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.defaultSaveDirectory, "", "Default save directory should be empty string")
    }

    func testDefaultSaveDirectoryRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.defaultSaveDir.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(defaultSaveDirectory: "/Users/test/Documents"))
        XCTAssertEqual(store.load().defaultSaveDirectory, "/Users/test/Documents")
    }

    // MARK: - Toolbar Icon Size Style

    func testToolbarIconSizeStyleDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.toolbarIconSizeStyle, 0, "Default toolbar icon size style should be 0 (regular)")
    }

    func testToolbarIconSizeStyleClamped() {
        let tooHigh = AppPreferences(toolbarIconSizeStyle: 5)
        XCTAssertEqual(tooHigh.toolbarIconSizeStyle, 1)
        let negative = AppPreferences(toolbarIconSizeStyle: -1)
        XCTAssertEqual(negative.toolbarIconSizeStyle, 0)
    }

    func testToolbarIconSizeStyleRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.toolbarIconSize.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(toolbarIconSizeStyle: 1))
        XCTAssertEqual(store.load().toolbarIconSizeStyle, 1)
    }

    // MARK: - Scintilla Rendering Technology

    func testScintillaRenderingTechnologyDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.scintillaRenderingTechnology, 0, "Default rendering technology should be 0 (default)")
    }

    func testScintillaRenderingTechnologyClamped() {
        let tooHigh = AppPreferences(scintillaRenderingTechnology: 3)
        XCTAssertEqual(tooHigh.scintillaRenderingTechnology, 1)
        let negative = AppPreferences(scintillaRenderingTechnology: -1)
        XCTAssertEqual(negative.scintillaRenderingTechnology, 0)
    }

    func testScintillaRenderingTechnologyRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.scintillaRendering.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(scintillaRenderingTechnology: 1))
        XCTAssertEqual(store.load().scintillaRenderingTechnology, 1)
    }

    // MARK: - Disable Advanced Scrolling

    func testDisableAdvancedScrollingDefault() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.disableAdvancedScrolling, "Default should be false (advanced scrolling enabled)")
    }

    func testDisableAdvancedScrollingRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.disableAdvScroll.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(disableAdvancedScrolling: true))
        XCTAssertTrue(store.load().disableAdvancedScrolling)
    }

    // MARK: - Right Click Keep Selection

    func testRightClickKeepSelectionDefault() {
        let prefs = AppPreferences()
        XCTAssertTrue(prefs.rightClickKeepSelection, "Default should be true (keep selection on right-click)")
    }

    func testRightClickKeepSelectionRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.rightClickKeepSel.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(rightClickKeepSelection: false))
        XCTAssertFalse(store.load().rightClickKeepSelection)
    }

    // MARK: - Edge Mode

    func testEdgeModeDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.edgeMode, 1, "Default edge mode should be 1 (line)")
    }

    func testEdgeModeClamped() {
        let tooHigh = AppPreferences(edgeMode: 5)
        XCTAssertEqual(tooHigh.edgeMode, 2)
        let negative = AppPreferences(edgeMode: -1)
        XCTAssertEqual(negative.edgeMode, 0)
    }

    func testEdgeModeRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.edgeMode.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(edgeMode: 2))
        XCTAssertEqual(store.load().edgeMode, 2)
    }

    // MARK: - Fold Flags

    func testFoldFlagsDefault() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.foldFlags, 0, "Default fold flags should be 0 (none)")
    }

    func testFoldFlagsClamped() {
        let tooHigh = AppPreferences(foldFlags: 100)
        XCTAssertEqual(tooHigh.foldFlags, 30)
        let negative = AppPreferences(foldFlags: -1)
        XCTAssertEqual(negative.foldFlags, 0)
    }

    func testFoldFlagsRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.foldFlags.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(foldFlags: 10))
        XCTAssertEqual(store.load().foldFlags, 10)
    }

    // MARK: - foldCompact

    func testFoldCompactDefault() {
        XCTAssertFalse(AppPreferences().foldCompact)
    }

    func testFoldCompactRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.foldCompact.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(foldCompact: true))
        XCTAssertTrue(store.load().foldCompact)
    }

    // MARK: - showDocSwitcher

    func testShowDocSwitcherDefault() {
        XCTAssertTrue(AppPreferences().showDocSwitcher)
    }

    func testShowDocSwitcherRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.showDocSwitcher.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(showDocSwitcher: false))
        XCTAssertFalse(store.load().showDocSwitcher)
    }

    // MARK: - perLineResultInFind

    func testPerLineResultInFindDefault() {
        XCTAssertFalse(AppPreferences().perLineResultInFind)
    }

    func testPerLineResultInFindRoundtrip() {
        let defaults = UserDefaults(suiteName: "test.perLineResult.\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(perLineResultInFind: true))
        XCTAssertTrue(store.load().perLineResultInFind)
    }
}
