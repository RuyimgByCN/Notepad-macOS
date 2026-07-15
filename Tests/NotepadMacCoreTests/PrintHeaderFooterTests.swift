import XCTest
import NotepadMacCore

final class PrintHeaderFooterTests: XCTestCase {

    private let knownDate: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 4
        comps.hour = 14; comps.minute = 30; comps.second = 5
        return Calendar.current.date(from: comps)!
    }()

    // MARK: - Variable expansion

    func testFileNameExpansion() {
        let result = PrintBand.expandVariables("$(FILE_NAME)", page: 1, totalPages: 5,
                                               filePath: "/tmp/hello.swift", date: knownDate)
        XCTAssertEqual(result, "hello.swift")
    }

    func testFileNameWithoutExtExpansion() {
        let result = PrintBand.expandVariables("$(FILE_NAME_WITHOUT_EXT)", page: 1, totalPages: 5,
                                               filePath: "/tmp/hello.swift", date: knownDate)
        XCTAssertEqual(result, "hello")
    }

    func testFullPathExpansion() {
        let result = PrintBand.expandVariables("$(FULL_CURRENT_PATH)", page: 1, totalPages: 5,
                                               filePath: "/tmp/hello.swift", date: knownDate)
        XCTAssertEqual(result, "/tmp/hello.swift")
    }

    func testPageAndPagesExpansion() {
        let result = PrintBand.expandVariables("$(PAGE)/$(PAGES)", page: 3, totalPages: 10,
                                               filePath: nil, date: knownDate)
        XCTAssertEqual(result, "3/10")
    }

    func testDateComponentExpansion() {
        let year = PrintBand.expandVariables("$(YEAR)", page: 1, totalPages: 1, filePath: nil, date: knownDate)
        XCTAssertEqual(year, "2026")
        let month = PrintBand.expandVariables("$(MONTH)", page: 1, totalPages: 1, filePath: nil, date: knownDate)
        XCTAssertEqual(month, "06")
        let day = PrintBand.expandVariables("$(DAY)", page: 1, totalPages: 1, filePath: nil, date: knownDate)
        XCTAssertEqual(day, "04")
    }

    func testUntitledFileExpansion() {
        let result = PrintBand.expandVariables("$(FULL_CURRENT_PATH)", page: 1, totalPages: 1,
                                               filePath: nil, date: knownDate)
        XCTAssertEqual(result, "(untitled)")
        let name = PrintBand.expandVariables("$(FILE_NAME)", page: 1, totalPages: 1,
                                             filePath: nil, date: knownDate)
        XCTAssertEqual(name, "")
    }

    func testEmptyTemplateReturnsEmpty() {
        let result = PrintBand.expandVariables("", page: 1, totalPages: 5, filePath: "/tmp/a.txt", date: knownDate)
        XCTAssertEqual(result, "")
    }

    func testLiteralTextPassesThrough() {
        let result = PrintBand.expandVariables("Confidential", page: 1, totalPages: 5, filePath: nil, date: knownDate)
        XCTAssertEqual(result, "Confidential")
    }

    func testCombinedTemplate() {
        let tmpl = "$(FILE_NAME) — Page $(PAGE) of $(PAGES)"
        let result = PrintBand.expandVariables(tmpl, page: 2, totalPages: 7,
                                               filePath: "/docs/report.md", date: knownDate)
        XCTAssertEqual(result, "report.md — Page 2 of 7")
    }

    // MARK: - PrintBand.expand triple output

    func testExpandProducesAllThreeCells() {
        let band = PrintBand(left: "$(FILE_NAME)", center: "Page $(PAGE)", right: "$(YEAR)")
        let (left, center, right) = band.expand(page: 4, totalPages: 8,
                                                filePath: "/tmp/test.txt", date: knownDate)
        XCTAssertEqual(left, "test.txt")
        XCTAssertEqual(center, "Page 4")
        XCTAssertEqual(right, "2026")
    }

    func testEmptyBandIsEmpty() {
        let band = PrintBand()
        XCTAssertTrue(band.isEmpty)
    }

    func testNonEmptyBandIsNotEmpty() {
        let band = PrintBand(center: "hello")
        XCTAssertFalse(band.isEmpty)
    }

    // MARK: - PrintSettings defaults

    func testDefaultPrintSettingsHaveHeaderAndFooter() {
        let ps = PrintSettings.defaultValue
        XCTAssertEqual(ps.header.center, "$(FILE_NAME)")
        XCTAssertEqual(ps.footer.right, "$(PAGE) / $(PAGES)")
        XCTAssertEqual(ps.colorMode, 0)
        XCTAssertEqual(ps.fontSize, 0)
        XCTAssertEqual(ps.marginTop, 36)
        XCTAssertFalse(ps.printFormFeedPageBreak)
    }

    func testPrintSettingsColorModeClamp() {
        XCTAssertEqual(PrintSettings(colorMode: -1).colorMode, 0)
        XCTAssertEqual(PrintSettings(colorMode: 5).colorMode, 1)
        XCTAssertEqual(PrintSettings(colorMode: 1).colorMode, 1)
    }

    func testPrintSettingsMarginClamp() {
        let ps = PrintSettings(marginTop: -10, marginLeft: -5)
        XCTAssertEqual(ps.marginTop, 0)
        XCTAssertEqual(ps.marginLeft, 0)
    }

    // MARK: - AppPreferences print round-trip

    func testPrintSettingsPersistViaPreferencesStore() {
        let defaults = UserDefaults(suiteName: "PrintHeaderFooterTests.roundtrip")!
        defer { defaults.removePersistentDomain(forName: "PrintHeaderFooterTests.roundtrip") }

        let store = PreferencesStore(defaults: defaults)
        let written = AppPreferences(
            printSettings: PrintSettings(
                header: PrintBand(left: "L", center: "C", right: "R"),
                footer: PrintBand(left: "", center: "footer", right: ""),
                colorMode: 1,
                fontSize: 11,
                printFormFeedPageBreak: true
            )
        )
        store.save(written)
        let read = store.load()

        XCTAssertEqual(read.printSettings.header.left, "L")
        XCTAssertEqual(read.printSettings.header.center, "C")
        XCTAssertEqual(read.printSettings.header.right, "R")
        XCTAssertEqual(read.printSettings.footer.center, "footer")
        XCTAssertEqual(read.printSettings.colorMode, 1)
        XCTAssertEqual(read.printSettings.fontSize, 11)
        XCTAssertTrue(read.printSettings.printFormFeedPageBreak)
    }

    func testPrintFormFeedPageBreakDefaultsFalseWhenMissingFromJSON() throws {
        // Older preferences JSON without the new key must decode as false.
        let legacy = """
        {"header":{"left":"","center":"$(FILE_NAME)","right":""},\
        "footer":{"left":"","center":"","right":"$(PAGE) / $(PAGES)"},\
        "colorMode":0,"fontSize":0,\
        "marginTop":36,"marginBottom":36,"marginLeft":36,"marginRight":36}
        """
        let data = Data(legacy.utf8)
        let ps = try JSONDecoder().decode(PrintSettings.self, from: data)
        XCTAssertFalse(ps.printFormFeedPageBreak)
    }

    func testDelimiterPreferencesPersist() {
        let defaults = UserDefaults(suiteName: "PrintHeaderFooterTests.delimiter")!
        defer { defaults.removePersistentDomain(forName: "PrintHeaderFooterTests.delimiter") }

        let store = PreferencesStore(defaults: defaults)
        store.save(AppPreferences(delimiterLeft: "(", delimiterRight: ")"))
        let read = store.load()
        XCTAssertEqual(read.delimiterLeft, "(")
        XCTAssertEqual(read.delimiterRight, ")")
    }
}
