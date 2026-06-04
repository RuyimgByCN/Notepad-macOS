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
}
