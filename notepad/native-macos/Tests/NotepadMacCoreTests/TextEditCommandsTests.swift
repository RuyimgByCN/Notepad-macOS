import Foundation
import XCTest
@testable import NotepadMacCore

final class TextEditCommandsTests: XCTestCase {
    func testTextEditCommandsDuplicatesCurrentLFLineAndMovesCaretToDuplicate() {
        let text = "alpha\nbravo\ncharlie"
        let caret = (text as NSString).range(of: "av").location

        let result = TextEditCommands.duplicate(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\nbravo\nbravo\ncharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: caret + "bravo\n".utf16.count, length: 0))
    }

    func testTextEditCommandsDuplicatesLastLineWithoutFinalNewlineUsingDetectedEnding() {
        let text = "alpha\r\nbravo"
        let caret = (text as NSString).length

        let result = TextEditCommands.duplicate(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\nbravo\r\nbravo")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha\r\nbravo\r\nbravo".utf16.count, length: 0))
    }

    func testTextEditCommandsDuplicatesSelectedTextRange() {
        let text = "alpha\nbravo\ncharlie"
        let selection = (text as NSString).range(of: "bravo")

        let result = TextEditCommands.duplicate(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "alpha\nbravobravo\ncharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location + selection.length, length: selection.length))
    }

    func testTextEditCommandsDuplicatesSelectionAcrossLines() {
        let text = "one\ntwo\nthree"
        let selection = (text as NSString).range(of: "e\ntw")

        let result = TextEditCommands.duplicate(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one\ntwe\ntwo\nthree")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location + selection.length, length: selection.length))
    }

    func testTextEditCommandsTrimsTrailingSpacesAndTabsPreservingLFAndFinalNewline() {
        let text = "one  \ntwo\t \n"
        let selection = NSRange(location: (text as NSString).range(of: "two").location + 3, length: 0)

        let result = TextEditCommands.trimTrailingWhitespace(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one\ntwo\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: "one\ntwo".utf16.count, length: 0))
    }

    func testTextEditCommandsTrimsTrailingWhitespacePreservingCRLFAndSelection() {
        let text = "one \r\ntwo\t\r\nthree"
        let selection = NSRange(location: (text as NSString).range(of: "two").location, length: "two\t\r\nth".utf16.count)

        let result = TextEditCommands.trimTrailingWhitespace(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one\r\ntwo\r\nthree")
        XCTAssertEqual(result.selectedRange, NSRange(location: "one\r\n".utf16.count, length: "two\r\nth".utf16.count))
    }

    func testTextEditCommandsTrimsTrailingWhitespacePreservingCROnLastLineWithoutNewline() {
        let text = "one\t\rtwo  "
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.trimTrailingWhitespace(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one\rtwo")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: "one\rtwo".utf16.count))
    }

    func testTextEditCommandsTrimsTrailingWhitespacePreservingCRLFAndCRFinalNewlines() {
        let crlf = TextEditCommands.trimTrailingWhitespace(
            in: "one \r\ntwo\t\r\n",
            selectedRange: NSRange(location: 0, length: 0)
        )
        let cr = TextEditCommands.trimTrailingWhitespace(
            in: "one \rtwo\t\r",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(crlf.text, "one\r\ntwo\r\n")
        XCTAssertEqual(cr.text, "one\rtwo\r")
    }

    func testTextEditCommandsTrimsSelectionCollapsedInsideRemovedWhitespace() {
        let text = "one   \ntwo"
        let caret = "one  ".utf16.count

        let result = TextEditCommands.trimTrailingWhitespace(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "one\ntwo")
        XCTAssertEqual(result.selectedRange, NSRange(location: "one".utf16.count, length: 0))
    }

    func testTextEditCommandsJoinsSelectedLinesWithoutAddingSpaces() {
        let text = "alpha\nbravo\r\ncharlie\rdelta"
        let selection = NSRange(
            location: "alpha\nbr".utf16.count,
            length: "avo\r\nchar".utf16.count
        )

        let result = TextEditCommands.joinSelectedLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "alpha\nbravocharlie\rdelta")
        XCTAssertEqual(
            result.selectedRange,
            NSRange(location: "alpha\nbr".utf16.count, length: "avochar".utf16.count)
        )
    }

    func testTextEditCommandsJoinSelectedLinesDoesNotIncludeLineAtSelectionEnd() {
        let text = "alpha\nbravo\ncharlie"
        let selection = NSRange(
            location: "alpha\n".utf16.count,
            length: "bravo\n".utf16.count
        )

        let result = TextEditCommands.joinSelectedLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, text)
        XCTAssertEqual(result.selectedRange, selection)
    }

    func testTextEditCommandsJoinSelectedLinesNoOpsOnCurrentLineAndEmptyDocument() {
        let currentLine = TextEditCommands.joinSelectedLines(
            in: "alpha\nbravo",
            selectedRange: NSRange(location: "alpha\nbr".utf16.count, length: 0)
        )
        let empty = TextEditCommands.joinSelectedLines(
            in: "",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(currentLine.text, "alpha\nbravo")
        XCTAssertEqual(currentLine.selectedRange, NSRange(location: "alpha\nbr".utf16.count, length: 0))
        XCTAssertEqual(empty.text, "")
        XCTAssertEqual(empty.selectedRange, NSRange(location: 0, length: 0))
    }

    func testTextEditCommandsRemovesEmptyLinesGloballyPreservingNonEmptyLineEndings() {
        let text = "one\n\n two\r\n\r\nthree\r\rfour"
        let selection = NSRange(location: "one\n\n t".utf16.count, length: "\r\n\r\nthr".utf16.count)

        let result = TextEditCommands.removeEmptyLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one\n two\r\nthree\rfour")
        XCTAssertEqual(
            result.selectedRange,
            NSRange(location: "one\n t".utf16.count, length: "\r\nthr".utf16.count)
        )
    }

    func testTextEditCommandsRemoveEmptyLinesPreservesSpaceAndTabOnlyLines() {
        let text = "one\n \n\t\rthree"

        let result = TextEditCommands.removeEmptyLines(
            in: text,
            selectedRange: NSRange(location: (text as NSString).length, length: 0)
        )

        XCTAssertEqual(result.text, text)
        XCTAssertEqual(result.selectedRange, NSRange(location: (text as NSString).length, length: 0))
    }

    func testTextEditCommandsRemovesBlankLinesGloballyPreservingNonBlankLineEndings() {
        let text = "one\n \r\ntwo\r\t\rfour"
        let selection = NSRange(location: "one\n ".utf16.count, length: "\r\ntwo\r\t".utf16.count)

        let result = TextEditCommands.removeBlankLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one\ntwo\rfour")
        XCTAssertEqual(
            result.selectedRange,
            NSRange(location: "one\n".utf16.count, length: "two\r".utf16.count)
        )
    }

    func testTextEditCommandsRemoveBlankLinesHandlesEmptyDocument() {
        let result = TextEditCommands.removeBlankLines(
            in: "",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 0))
    }

    func testTextEditCommandsSortsSelectedLinesAscendingAndKeepsFinalLineWithoutEndingLast() {
        let text = "delta\r\nalpha\ncharlie\rbravo"
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesAscending(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "alpha\nbravo\rcharlie\r\ndelta")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: (result.text as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesDescendingWithoutIncludingLineAtSelectionEnd() {
        let text = "head\nb\na\nb\ntail"
        let selection = NSRange(
            location: "head\n".utf16.count,
            length: "b\na\nb\n".utf16.count
        )

        let result = TextEditCommands.sortSelectedLinesDescending(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "head\nb\nb\na\ntail")
        XCTAssertEqual(
            result.selectedRange,
            NSRange(location: "head\n".utf16.count, length: "b\nb\na\n".utf16.count)
        )
    }

    func testTextEditCommandsSortSelectedLinesNoOpsOnCurrentLineAndEmptyDocument() {
        let currentLine = TextEditCommands.sortSelectedLinesAscending(
            in: "alpha\nbravo",
            selectedRange: NSRange(location: "alpha\nbr".utf16.count, length: 0)
        )
        let empty = TextEditCommands.sortSelectedLinesDescending(
            in: "",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(currentLine.text, "alpha\nbravo")
        XCTAssertEqual(currentLine.selectedRange, NSRange(location: "alpha\nbr".utf16.count, length: 0))
        XCTAssertEqual(empty.text, "")
        XCTAssertEqual(empty.selectedRange, NSRange(location: 0, length: 0))
    }

    func testTextEditCommandsRemovesDuplicateLinesPreservingFirstOccurrenceAndLineEndings() {
        let text = "alpha\nbravo\r\nalpha\ncharlie\rbravo\nzulu"
        let selection = NSRange(location: "alpha\nbravo\r\nalpha".utf16.count, length: "\ncharlie".utf16.count)

        let result = TextEditCommands.removeDuplicateLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "alpha\nbravo\r\ncharlie\rzulu")
        XCTAssertEqual(
            result.selectedRange,
            NSRange(location: "alpha\nbravo\r\n".utf16.count, length: "charlie".utf16.count)
        )
    }

    func testTextEditCommandsRemovesOnlyConsecutiveDuplicateLines() {
        let text = "alpha\nalpha\r\nbravo\nalpha\nbravo\rbravo\n"
        let selection = NSRange(location: (text as NSString).length, length: 0)

        let result = TextEditCommands.removeConsecutiveDuplicateLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "alpha\nbravo\nalpha\nbravo\r")
        XCTAssertEqual(result.selectedRange, NSRange(location: (result.text as NSString).length, length: 0))
    }

    func testTextEditCommandsUppercasesSelectionAndExpandsSelectionForUnicodeMapping() {
        let text = "one straße café two"
        let selection = (text as NSString).range(of: "straße café")

        let result = TextEditCommands.uppercaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one STRASSE CAFÉ two")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: "STRASSE CAFÉ".utf16.count))
    }

    func testTextEditCommandsLowercasesSelectionAndPreservesSurroundingText() {
        let text = "Alpha BRAVO ΔELTA"
        let selection = (text as NSString).range(of: "BRAVO ΔELTA")

        let result = TextEditCommands.lowercaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "Alpha bravo δelta")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: "bravo δelta".utf16.count))
    }

    func testTextEditCommandsInvertsSelectionCaseAndPreservesSurroundingText() {
        let text = "one Alpha BRAVO Δelta two"
        let selection = (text as NSString).range(of: "Alpha BRAVO Δelta")

        let result = TextEditCommands.invertSelectionCase(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "one aLPHA bravo δELTA two")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: "aLPHA bravo δELTA".utf16.count))
    }

    func testTextEditCommandsInvertSelectionCaseExpandsUnicodeMapping() {
        let text = "straße CAFÉ"
        let selection = (text as NSString).range(of: "straße CAFÉ")

        let result = TextEditCommands.invertSelectionCase(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "STRASSE café")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: "STRASSE café".utf16.count))
    }

    func testTextEditCommandsSentenceCasesSelectionAfterSentenceBoundaries() {
        let text = "prefix hELLO WORLD. aNOTHER? YES! tail"
        let selection = (text as NSString).range(of: "hELLO WORLD. aNOTHER? YES!")

        let result = TextEditCommands.sentenceCaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "prefix Hello world. Another? Yes! tail")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: "Hello world. Another? Yes!".utf16.count))
    }

    func testTextEditCommandsSentenceCaseUsesUnicodeCaseMapping() {
        let text = "straße CAFÉ. δELTA"
        let selection = (text as NSString).range(of: "straße CAFÉ. δELTA")

        let result = TextEditCommands.sentenceCaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "Strasse café. Δelta")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: "Strasse café. Δelta".utf16.count))
    }

    func testTextEditCommandsCaseConversionNoOpsOnCollapsedSelection() {
        let text = "Alpha"
        let selection = NSRange(location: 2, length: 0)

        let result = TextEditCommands.uppercaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, text)
        XCTAssertEqual(result.selectedRange, selection)
    }

    func testTextEditCommandsDeletesSelectedRangeWithoutExpandingToLines() {
        let text = "alpha\nbravo\ncharlie"
        let selection = (text as NSString).range(of: "ha\nbr")

        let result = TextEditCommands.deleteCurrentLineOrSelection(
            in: text,
            selectedRange: selection
        )

        XCTAssertEqual(result.text, "alpavo\ncharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: selection.location, length: 0))
    }

    func testTextEditCommandsDeletesCurrentLineIncludingMixedLineEnding() {
        let text = "alpha\r\nbravo\rcharlie"
        let caret = (text as NSString).range(of: "av").location

        let result = TextEditCommands.deleteCurrentLineOrSelection(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\ncharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha\r\n".utf16.count, length: 0))
    }

    func testTextEditCommandsDeletesLastLineWithoutEndingByRemovingPreviousEnding() {
        let text = "alpha\r\nbravo"
        let caret = (text as NSString).length

        let result = TextEditCommands.deleteCurrentLineOrSelection(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha".utf16.count, length: 0))
    }

    func testTextEditCommandsDeleteCurrentLineNoOpsOnEmptyDocument() {
        let result = TextEditCommands.deleteCurrentLineOrSelection(
            in: "",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 0))
    }

    func testTextEditCommandsMoveCurrentLineUpPreservesMixedLineEndings() {
        let text = "alpha\r\nbravo\ncharlie\rdelta"
        let caret = (text as NSString).range(of: "ar").location

        let result = TextEditCommands.moveCurrentLineOrSelectionUp(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\ncharlie\rbravo\ndelta")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha\r\nch".utf16.count, length: 0))
    }

    func testTextEditCommandsMoveCurrentLineUpMovesLastLineWithoutFinalEndingNaturally() {
        let text = "alpha\r\nbravo\rcharlie"
        let caret = (text as NSString).range(of: "li").location

        let result = TextEditCommands.moveCurrentLineOrSelectionUp(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\ncharlie\rbravo")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha\r\nchar".utf16.count, length: 0))
    }

    func testTextEditCommandsMoveSelectionUpDoesNotIncludeLineStartingAtSelectionEnd() {
        let text = "alpha\nbravo\ncharlie\ndelta"
        let selection = NSRange(
            location: "alpha\n".utf16.count,
            length: "bravo\n".utf16.count
        )

        let result = TextEditCommands.moveCurrentLineOrSelectionUp(
            in: text,
            selectedRange: selection
        )

        XCTAssertEqual(result.text, "bravo\nalpha\ncharlie\ndelta")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: "bravo\n".utf16.count))
    }

    func testTextEditCommandsMoveCurrentLineUpNoOpsAtDocumentStartAndSingleLine() {
        let firstLine = TextEditCommands.moveCurrentLineOrSelectionUp(
            in: "alpha\nbravo",
            selectedRange: NSRange(location: 1, length: 0)
        )
        let singleLine = TextEditCommands.moveCurrentLineOrSelectionUp(
            in: "alpha",
            selectedRange: NSRange(location: 3, length: 0)
        )

        XCTAssertEqual(firstLine.text, "alpha\nbravo")
        XCTAssertEqual(firstLine.selectedRange, NSRange(location: 1, length: 0))
        XCTAssertEqual(singleLine.text, "alpha")
        XCTAssertEqual(singleLine.selectedRange, NSRange(location: 3, length: 0))
    }

    func testTextEditCommandsMoveCurrentLineDownPreservesMixedLineEndings() {
        let text = "alpha\r\nbravo\ncharlie"
        let caret = (text as NSString).range(of: "av").location

        let result = TextEditCommands.moveCurrentLineOrSelectionDown(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\ncharlie\nbravo")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha\r\ncharlie\nbr".utf16.count, length: 0))
    }

    func testTextEditCommandsMoveSelectionDownDoesNotIncludeLineStartingAtSelectionEnd() {
        let text = "alpha\nbravo\ncharlie\ndelta"
        let selection = NSRange(
            location: "alpha\n".utf16.count,
            length: "bravo\n".utf16.count
        )

        let result = TextEditCommands.moveCurrentLineOrSelectionDown(
            in: text,
            selectedRange: selection
        )

        XCTAssertEqual(result.text, "alpha\ncharlie\nbravo\ndelta")
        XCTAssertEqual(result.selectedRange, NSRange(location: "alpha\ncharlie\n".utf16.count, length: "bravo\n".utf16.count))
    }

    func testTextEditCommandsMoveCurrentLineDownNoOpsAtDocumentEndAndEmptyDocument() {
        let lastLine = TextEditCommands.moveCurrentLineOrSelectionDown(
            in: "alpha\nbravo",
            selectedRange: NSRange(location: "alpha\nbr".utf16.count, length: 0)
        )
        let empty = TextEditCommands.moveCurrentLineOrSelectionDown(
            in: "",
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(lastLine.text, "alpha\nbravo")
        XCTAssertEqual(lastLine.selectedRange, NSRange(location: "alpha\nbr".utf16.count, length: 0))
        XCTAssertEqual(empty.text, "")
        XCTAssertEqual(empty.selectedRange, NSRange(location: 0, length: 0))
    }
}
