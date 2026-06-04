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

    func testTextEditCommandsSortsSelectedLinesAsIntegersAscendingAndMovesBlankLinesFirst() {
        let text = "10\n\n-2\n3\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesAsIntegersAscending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "\n-2\n3\n10\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("\n-2\n3\n10\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesAsIntegersDescendingAndMovesBlankLinesLast() {
        let text = "10\n\n-2\n3\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesAsIntegersDescending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "10\n3\n-2\n\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("10\n3\n-2\n\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesAsDecimalDotAscending() {
        let text = "3.5\n-2.25\n10.0\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesAsDecimalDotAscending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "-2.25\n3.5\n10.0\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("-2.25\n3.5\n10.0\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesAsDecimalCommaDescending() {
        let text = "3,5\n-2,25\n10,0\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesAsDecimalCommaDescending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "10,0\n3,5\n-2,25\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("10,0\n3,5\n-2,25\n" as NSString).length))
    }

    func testTextEditCommandsReversesSelectedLineOrder() {
        let text = "head\na\nbb\nccc\ntail"
        let selection = NSRange(
            location: "head\n".utf16.count,
            length: "a\nbb\nccc\n".utf16.count
        )

        let result = TextEditCommands.reverseSelectedLines(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "head\nccc\nbb\na\ntail")
        XCTAssertEqual(result.selectedRange, NSRange(location: "head\n".utf16.count, length: "ccc\nbb\na\n".utf16.count))
    }

    func testTextEditCommandsSortsSelectedLinesByLengthAscending() {
        let text = "long\nx\nmid\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesByLengthAscending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "x\nmid\nlong\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("x\nmid\nlong\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesByLengthDescending() {
        let text = "long\nx\nmid\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesByLengthDescending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "long\nmid\nx\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("long\nmid\nx\n" as NSString).length))
    }

    func testTextEditCommandsRandomizesSelectedLineOrderUsingInjectedKeys() {
        let text = "head\na\nbb\nccc\ntail"
        let selection = NSRange(
            location: "head\n".utf16.count,
            length: "a\nbb\nccc\n".utf16.count
        )
        var keys = [2, 0, 1]

        let result = TextEditCommands.randomizeSelectedLines(
            in: text,
            selectedRange: selection
        ) {
            keys.removeFirst()
        }

        XCTAssertEqual(result.text, "head\nbb\nccc\na\ntail")
        XCTAssertEqual(result.selectedRange, NSRange(location: "head\n".utf16.count, length: "bb\nccc\na\n".utf16.count))
    }

    func testTextEditCommandsSortsSelectedLinesCaseInsensitiveAscending() {
        let text = "Zulu\nalpha\nBravo\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesCaseInsensitiveAscending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "alpha\nBravo\nZulu\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("alpha\nBravo\nZulu\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesCaseInsensitiveDescending() {
        let text = "Zulu\nalpha\nBravo\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesCaseInsensitiveDescending(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "Zulu\nBravo\nalpha\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("Zulu\nBravo\nalpha\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesInLocaleAscending() {
        let text = "file10\nFile2\nfile1\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesInLocaleAscending(
            in: text,
            selectedRange: full,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(result.text, "file1\nFile2\nfile10\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("file1\nFile2\nfile10\n" as NSString).length))
    }

    func testTextEditCommandsSortsSelectedLinesInLocaleDescending() {
        let text = "file10\nFile2\nfile1\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.sortSelectedLinesInLocaleDescending(
            in: text,
            selectedRange: full,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(result.text, "file10\nFile2\nfile1\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("file10\nFile2\nfile1\n" as NSString).length))
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

    func testTextEditCommandsProperCaseCapitalizesWordStartsAndLowercasesInteriorLetters() {
        let text = "heLLo woRLD from NOTEPAD"
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.properCaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "Hello World From Notepad")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("Hello World From Notepad" as NSString).length))
    }

    func testTextEditCommandsProperCaseKeepsApostropheSuffixLowercased() {
        let text = "JOHN'S ROCK'N'ROLL"
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.properCaseSelection(in: text, selectedRange: selection)

        XCTAssertEqual(result.text, "John's Rock'n'roll")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: ("John's Rock'n'roll" as NSString).length))
    }

    func testTextEditCommandsRandomCaseUsesInjectedPatternAndPreservesNonLetters() {
        let text = "Abc 123 XyZ!"
        let selection = NSRange(location: 0, length: (text as NSString).length)
        var pattern = [true, false, true, false, true, false]

        let result = TextEditCommands.randomCaseSelection(
            in: text,
            selectedRange: selection
        ) {
            pattern.removeFirst()
        }

        XCTAssertEqual(result.text, "AbC 123 xYz!")
        XCTAssertEqual(result.selectedRange, selection)
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

    func testTextEditCommandsSplitsCurrentLineToConfiguredWidthAndMapsSelection() {
        let text = "abcdefghi"
        let caret = 5

        let result = TextEditCommands.splitLines(
            in: text,
            selectedRange: NSRange(location: caret, length: 0),
            lineWidth: 3
        )

        XCTAssertEqual(result.text, "abc\ndef\nghi")
        XCTAssertEqual(result.selectedRange, NSRange(location: 6, length: 0))
    }

    func testTextEditCommandsTransposesCurrentLineAndMapsSelectionToPreviousLine() {
        let text = "alpha\nbravo\ncharlie"
        let caret = (text as NSString).range(of: "bravo").location

        let result = TextEditCommands.transposeLine(in: text, selectedRange: NSRange(location: caret, length: 0))

        XCTAssertEqual(result.text, "bravo\nalpha\ncharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 0))
    }

    func testTextEditCommandsTransposeLineNoOpsOnSingleLineDocument() {
        let result = TextEditCommands.transposeLine(
            in: "alpha\n",
            selectedRange: NSRange(location: 2, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 2, length: 0))
    }

    func testTextEditCommandsInsertBlankLineAboveCurrentLinePreservesLineEndingAndMapsSelection() {
        let text = "alpha\r\nbravo"
        let caret = (text as NSString).range(of: "bravo").location

        let result = TextEditCommands.insertBlankLineAboveCurrentLine(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\n\r\nbravo")
        XCTAssertEqual(result.selectedRange, NSRange(location: 9, length: 0))
    }

    func testTextEditCommandsInsertBlankLineBelowCurrentLinePreservesLineEndingAndKeepsSelection() {
        let text = "alpha\r\nbravo"
        let caret = (text as NSString).range(of: "bravo").location

        let result = TextEditCommands.insertBlankLineBelowCurrentLine(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "alpha\r\nbravo\r\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 7, length: 0))
    }

    func testTextEditCommandsTrimLeadingWhitespaceOnlyTouchesSelectedLineBlock() {
        let text = "  alpha\r\n \t bravo\r\n\tcharlie"
        let caret = (text as NSString).range(of: " bravo").location + 1

        let result = TextEditCommands.trimLeadingWhitespace(
            in: text,
            selectedRange: NSRange(location: caret, length: 0)
        )

        XCTAssertEqual(result.text, "  alpha\r\nbravo\r\n\tcharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: 9, length: 0))
    }

    func testTextEditCommandsTrimLeadingAndTrailingWhitespaceAffectsSelectionRange() {
        let text = "  a  \r\n \t \r\n \tb\t\r\n"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.trimLeadingAndTrailingWhitespace(
            in: text,
            selectedRange: full
        )

        XCTAssertEqual(result.text, "a\r\n\r\nb\r\n")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 8))
    }

    func testTextEditCommandsEolToWhitespaceReplacesLineEndingsInSelection() {
        let text = "a\r\nb\nc"

        let result = TextEditCommands.eolToWhitespace(
            in: text,
            selectedRange: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(result.text, "a b c")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 5))
    }

    func testTextEditCommandsTrimAllTrimsAndConvertsEndingsForFullSelection() {
        let text = "  a  \n  b  \n c  "
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.trimAll(in: text, selectedRange: full)

        XCTAssertEqual(result.text, "a b c")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 5))
    }

    func testTextEditCommandsTabToSpacesExpandsTabsAcrossEntireDocumentAndMapsCaret() {
        let text = "\talpha\nbe\t"

        let result = TextEditCommands.tabToSpaces(
            in: text,
            selectedRange: NSRange(location: 1, length: 0)
        )

        XCTAssertEqual(result.text, "    alpha\nbe  ")
        XCTAssertEqual(result.selectedRange, NSRange(location: 4, length: 0))
    }

    func testTextEditCommandsSpaceToTabsLeadingOnlyConvertsIndentation() {
        let text = "    alpha\nalpha    beta\n    gamma"
        let full = NSRange(location: 0, length: (text as NSString).length)
        let expected = "\talpha\nalpha    beta\n\tgamma"

        let result = TextEditCommands.spaceToTabsLeading(
            in: text,
            selectedRange: full
        )

        XCTAssertEqual(result.text, expected)
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: (expected as NSString).length))
    }

    func testTextEditCommandsSpaceToTabsAllConvertsAlignedInteriorRuns() {
        let text = "alpha   beta\n1234    5678\n    lead"
        let full = NSRange(location: 0, length: (text as NSString).length)
        let expected = "alpha\tbeta\n1234\t5678\n\tlead"

        let result = TextEditCommands.spaceToTabsAll(
            in: text,
            selectedRange: full
        )

        XCTAssertEqual(result.text, expected)
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: (expected as NSString).length))
    }

    func testTextEditCommandsSetBlockCommentsWrapsTouchedLinesAfterIndentation() {
        let text = "  alpha\n\tbeta\n\ncharlie"
        let selection = NSRange(location: 1, length: (" alpha\n\tbeta\n\nch" as NSString).length)

        let result = TextEditCommands.setBlockComments(
            in: text,
            selectedRange: selection,
            commentStart: "/*",
            commentEnd: "*/"
        )

        XCTAssertEqual(result.text, "  /* alpha */\n\t/* beta */\n\n/* charlie */")
        XCTAssertEqual(result.selectedRange, NSRange(location: 1, length: 31))
    }

    func testTextEditCommandsRemoveBlockCommentsUnwrapsTouchedLinesAndRestoresSelection() {
        let text = "  /* alpha */\n\t/* beta */\n\n/* charlie */"
        let full = NSRange(location: 0, length: (text as NSString).length)

        let result = TextEditCommands.removeBlockComments(
            in: text,
            selectedRange: full,
            commentStart: "/*",
            commentEnd: "*/"
        )

        XCTAssertEqual(result.text, "  alpha\n\tbeta\n\ncharlie")
        XCTAssertEqual(result.selectedRange, NSRange(location: 0, length: 22))
    }

    func testTextEditCommandsStreamCommentWrapsCurrentLineBodyWhenSelectionIsCollapsed() {
        let text = "  alpha\nbeta"
        let caret = (text as NSString).range(of: "ph").location

        let result = TextEditCommands.streamComment(
            in: text,
            selectedRange: NSRange(location: caret, length: 0),
            commentStart: "/*",
            commentEnd: "*/"
        )

        XCTAssertEqual(result.text, "  /* alpha */\nbeta")
        XCTAssertEqual(result.selectedRange, NSRange(location: 5, length: 5))
    }

    func testTextEditCommandsStreamUncommentRemovesMarkersAroundSelection() {
        let text = "before /* target */ after"
        let selection = (text as NSString).range(of: "target")

        let result = TextEditCommands.streamUncomment(
            in: text,
            selectedRange: selection,
            commentStart: "/*",
            commentEnd: "*/"
        )

        XCTAssertEqual(result.text, "before target after")
        XCTAssertEqual(result.selectedRange, NSRange(location: 7, length: 6))
    }
}
