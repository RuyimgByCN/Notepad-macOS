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
}
