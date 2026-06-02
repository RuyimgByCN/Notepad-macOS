import XCTest
@testable import NotepadMacCore

final class TextStatisticsTests: XCTestCase {
    func testTextStatisticsCountsEmptyDocument() {
        let summary = TextStatistics.summary(for: "")

        XCTAssertEqual(summary.utf16CharacterCount, 0)
        XCTAssertEqual(summary.unicodeScalarCount, 0)
        XCTAssertEqual(summary.lineCount, 0)
        XCTAssertEqual(summary.wordCount, 0)
    }

    func testTextStatisticsCountsSingleLineDocument() {
        let summary = TextStatistics.summary(for: "Hello world 123")

        XCTAssertEqual(summary.utf16CharacterCount, 15)
        XCTAssertEqual(summary.unicodeScalarCount, 15)
        XCTAssertEqual(summary.lineCount, 1)
        XCTAssertEqual(summary.wordCount, 3)
    }

    func testTextStatisticsCountsMixedLineEndingsAndTrailingNewline() {
        let summary = TextStatistics.summary(for: "one\r\ntwo\nthree\rfour\n")

        XCTAssertEqual(summary.lineCount, 5)
        XCTAssertEqual(summary.wordCount, 4)
    }

    func testTextStatisticsCountsUnicodeScalarsAndUTF16Separately() {
        let text = "café 🚀 family👨‍👩‍👧‍👦"
        let summary = TextStatistics.summary(for: text)

        XCTAssertEqual(summary.utf16CharacterCount, text.utf16.count)
        XCTAssertEqual(summary.unicodeScalarCount, text.unicodeScalars.count)
        XCTAssertEqual(summary.lineCount, 1)
        XCTAssertEqual(summary.wordCount, 2)
    }

    func testTextStatisticsCountsAsciiAndUnicodeAlphanumericWords() {
        let summary = TextStatistics.summary(for: "alpha_beta 中文42 café42 123 -- русский")

        XCTAssertEqual(summary.wordCount, 6)
    }
}
