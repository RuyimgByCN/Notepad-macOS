import Foundation
import XCTest
@testable import NotepadMacCore

final class RectangularSelectionTests: XCTestCase {
    func testExtractsCharacterOffsetBlockWithoutUTF16ColumnAssumptions() throws {
        let block = try RectangularSelection.extract(
            from: "a👩‍💻bc\nxy\n",
            lineRange: 1...2,
            columnRange: 1..<3
        )

        XCTAssertEqual(block, ["👩‍💻b", "y"])
    }

    func testInsertsRectangularBlockAndPadsShortLines() throws {
        let result = try RectangularSelection.insert(
            ["Z", "Q", "R"],
            into: "ab\nx\ncdef",
            lineRange: 1...3,
            column: 3
        )

        XCTAssertEqual(result, "ab Z\nx  Q\ncdeRf")
    }

    func testReplacesRectangularBlockAndPadsShortLines() throws {
        let result = try RectangularSelection.replace(
            in: "abcde\nx\n12345",
            lineRange: 1...3,
            columnRange: 2..<4,
            with: ["XX", "YY", "Z"]
        )

        XCTAssertEqual(result, "abXXe\nx YY\n12Z5")
    }

    func testPreservesCRLFLineEndingsDuringEdit() throws {
        let result = try RectangularSelection.insert(
            ["|", "|"],
            into: "one\r\ntwo\r\nthree",
            lineRange: 1...2,
            column: 0
        )

        XCTAssertEqual(result, "|one\r\n|two\r\nthree")
    }

    func testDerivesPreviewContextFromCurrentSelection() throws {
        let text = "prefix\npresto\npretty"
        let start = ("pr" as NSString).length
        let end = ("prefix\npres" as NSString).length
        let context = try RectangularSelection.context(
            in: text,
            selectedRange: NSRange(location: start, length: end - start)
        )

        XCTAssertEqual(context.lineRange, 1...2)
        XCTAssertEqual(context.startColumn, 3)
        XCTAssertEqual(context.endColumn, 4)
        XCTAssertEqual(context.selectedBlock, ["ef", "es"])
        XCTAssertEqual(context.blockText, "ef\nes")
    }

    func testSelectionEndingAtLineStartUsesPreviousLineForPreview() throws {
        let text = "alpha\nbravo"
        let context = try RectangularSelection.context(
            in: text,
            selectedRange: NSRange(location: 0, length: ("alpha\n" as NSString).length)
        )

        XCTAssertEqual(context.lineRange, 1...1)
        XCTAssertEqual(context.startColumn, 1)
        XCTAssertEqual(context.endColumn, 5)
        XCTAssertEqual(context.selectedBlock, ["alpha"])
        XCTAssertEqual(context.blockText, "alpha")
    }

    func testDerivesCaretContextWithoutSelection() throws {
        let text = "alpha\nbravo"
        let caret = ("alpha\nbr" as NSString).length
        let context = try RectangularSelection.context(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(context.lineRange, 2...2)
        XCTAssertEqual(context.startColumn, 3)
        XCTAssertEqual(context.endColumn, 3)
        XCTAssertEqual(context.selectedBlock, [])
        XCTAssertEqual(context.blockText, "")
    }

    func testDerivesLiveRectangularContextFromEditorPositions() throws {
        let text = "alpha\nbravo\ncat"
        let anchor = ("al" as NSString).length
        let caret = ("alpha\nbrav" as NSString).length
        let context = try RectangularSelection.context(
            in: text,
            liveSelection: RectangularSelectionLiveMetadata(
                anchorUTF16Location: anchor,
                caretUTF16Location: caret,
                anchorVirtualSpace: 0,
                caretVirtualSpace: 0
            )
        )

        XCTAssertEqual(context.lineRange, 1...2)
        XCTAssertEqual(context.startColumn, 3)
        XCTAssertEqual(context.endColumn, 4)
        XCTAssertEqual(context.selectedBlock, ["ph", "av"])
        XCTAssertEqual(context.blockText, "ph\nav")
    }

    func testLiveRectangularContextIncludesVirtualSpaceColumns() throws {
        let text = "a\nbravo"
        let anchor = ("a" as NSString).length
        let caret = ("a\nbravo" as NSString).length
        let context = try RectangularSelection.context(
            in: text,
            liveSelection: RectangularSelectionLiveMetadata(
                anchorUTF16Location: anchor,
                caretUTF16Location: caret,
                anchorVirtualSpace: 2,
                caretVirtualSpace: 0
            )
        )

        XCTAssertEqual(context.lineRange, 1...2)
        XCTAssertEqual(context.startColumn, 4)
        XCTAssertEqual(context.endColumn, 5)
        XCTAssertEqual(context.selectedBlock, ["", "vo"])
        XCTAssertEqual(context.blockText, "\nvo")
    }

    func testInsertResultReportsEditedRangesAndFinalCaret() throws {
        let result = try RectangularSelection.insertResult(
            ["Z", "YY"],
            into: "abc\nx\nlast",
            lineRange: 1...2,
            column: 2
        )

        XCTAssertEqual(result.text, "abZc\nx YY\nlast")
        XCTAssertEqual(result.editedRanges, [
            NSRange(location: 2, length: 1),
            NSRange(location: 7, length: 2)
        ])
        XCTAssertEqual(result.finalCaretRange, NSRange(location: 9, length: 0))
    }

    func testReplaceResultReportsEditedRangesAndFinalCaret() throws {
        let result = try RectangularSelection.replaceResult(
            in: "abcd\nxy\n",
            lineRange: 1...2,
            columnRange: 1..<3,
            with: ["Q", "RR"]
        )

        XCTAssertEqual(result.text, "aQd\nxRR\n")
        XCTAssertEqual(result.editedRanges, [
            NSRange(location: 1, length: 1),
            NSRange(location: 5, length: 2)
        ])
        XCTAssertEqual(result.finalCaretRange, NSRange(location: 7, length: 0))
    }

    func testEditResultReportsContiguousEditedRangeForSingleSelectionHighlight() throws {
        let result = try RectangularSelection.insertResult(
            ["Z", "YY"],
            into: "abc\nx\nlast",
            lineRange: 1...2,
            column: 2
        )

        XCTAssertEqual(result.contiguousEditedRange, NSRange(location: 2, length: 7))
    }

    func testRejectsInvalidRanges() {
        XCTAssertThrowsError(
            try RectangularSelection.extract(
                from: "one",
                lineRange: 0...1,
                columnRange: 0..<1
            )
        ) { error in
            XCTAssertEqual(error as? RectangularSelectionError, .invalidLineRange)
        }

        XCTAssertThrowsError(
            try RectangularSelection.extract(
                from: "one",
                lineRange: 1...2,
                columnRange: 0..<1
            )
        ) { error in
            XCTAssertEqual(error as? RectangularSelectionError, .lineRangeOutsideDocument)
        }

        XCTAssertThrowsError(
            try RectangularSelection.extract(
                from: "one",
                lineRange: 1...1,
                columnRange: -1..<1
            )
        ) { error in
            XCTAssertEqual(error as? RectangularSelectionError, .invalidColumnRange)
        }

        XCTAssertThrowsError(
            try RectangularSelection.insert(
                ["x"],
                into: "one",
                lineRange: 1...1,
                column: -1
            )
        ) { error in
            XCTAssertEqual(error as? RectangularSelectionError, .invalidColumn)
        }

        XCTAssertThrowsError(
            try RectangularSelection.replace(
                in: "one\ntwo",
                lineRange: 1...2,
                columnRange: 0..<1,
                with: ["x"]
            )
        ) { error in
            XCTAssertEqual(error as? RectangularSelectionError, .blockLineCountMismatch)
        }
    }

    func testConvertsEditorCaretOffsetsToZeroBasedCharacterColumns() throws {
        let text = "a👩‍💻bc\r\nxy"
        let firstLineCaret = ("a👩‍💻" as NSString).length
        let secondLineCaret = ("a👩‍💻bc\r\nx" as NSString).length

        XCTAssertEqual(RectangularSelection.zeroBasedCharacterColumn(in: text, utf16Location: firstLineCaret), 2)
        XCTAssertEqual(RectangularSelection.zeroBasedCharacterColumn(in: text, utf16Location: secondLineCaret), 1)
        XCTAssertEqual(try RectangularSelection.zeroBasedCharacterColumn(fromOneBasedColumn: 1), 0)
        XCTAssertEqual(try RectangularSelection.zeroBasedCharacterColumn(fromOneBasedColumn: 4), 3)
        XCTAssertThrowsError(try RectangularSelection.zeroBasedCharacterColumn(fromOneBasedColumn: 0)) { error in
            XCTAssertEqual(error as? RectangularSelectionError, .invalidColumn)
        }
    }
}
