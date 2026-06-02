import Foundation
import XCTest
@testable import NotepadMacCore

final class LineCommentEditTests: XCTestCase {
    func testCommentsSelectedLineWithLFAndPreservesIndentation() {
        let result = LineCommentEdit.toggle(
            in: "let a = 1\n    let b = 2\n",
            selection: NSRange(location: 15, length: 0),
            marker: "//"
        )

        XCTAssertEqual(result.text, "let a = 1\n    //let b = 2\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 17, length: 0))
    }

    func testUncommentsAllSelectedCRLFLinesWhenEachLineHasMarkerAfterIndentation() {
        let text = "  //one\r\n\t//two\r\nthree"
        let result = LineCommentEdit.toggle(
            in: text,
            selection: NSRange(location: 0, length: ("  //one\r\n\t//two" as NSString).length),
            marker: "//"
        )

        XCTAssertEqual(result.text, "  one\r\n\ttwo\r\nthree")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("  one\r\n\ttwo" as NSString).length))
    }

    func testCommentsAllTouchedLinesWhenSelectionSpansLines() {
        let text = "alpha\nbeta\ngamma"
        let result = LineCommentEdit.toggle(
            in: text,
            selection: NSRange(location: 2, length: 7),
            marker: "#"
        )

        XCTAssertEqual(result.text, "#alpha\n#beta\ngamma")
        XCTAssertEqual(result.selectedRange, NSRange(location: 3, length: 8))
    }

    func testMixedCommentedAndUncommentedSelectionAddsMarkersToEveryTouchedLine() {
        let text = "//ready\nplain\n  //done"
        let result = LineCommentEdit.toggle(
            in: text,
            selection: NSRange(location: 0, length: (text as NSString).length),
            marker: "//"
        )

        XCTAssertEqual(result.text, "////ready\n//plain\n  ////done")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("////ready\n//plain\n  ////done" as NSString).length))
    }

    func testPreservesCREndingsAndNoOpsForEmptyMarker() {
        let text = "one\rtwo\rthree"
        let result = LineCommentEdit.toggle(
            in: text,
            selection: NSRange(location: 4, length: 3),
            marker: ""
        )

        XCTAssertEqual(result.text, text)
        XCTAssertEqual(result.selectedRange, NSRange(location: 4, length: 3))
    }
}
