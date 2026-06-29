import Foundation
import Testing
@testable import NotepadMacCore

@Test func splitLinesDropsTrailingEmptyLine() {
    #expect(FileDiff.splitLines("") == [])
    #expect(FileDiff.splitLines("a") == ["a"])
    #expect(FileDiff.splitLines("a\n") == ["a"])
    #expect(FileDiff.splitLines("a\nb\n") == ["a", "b"])
    #expect(FileDiff.splitLines("a\nb") == ["a", "b"])
}

@Test func splitLinesStripsTrailingCR() {
    // CRLF and lone CR both normalize so "a\r\nb" compares line-by-line.
    #expect(FileDiff.splitLines("a\r\nb") == ["a", "b"])
    #expect(FileDiff.splitLines("a\rb") == ["a", "b"])
}

@Test func computeIgnoresLeadingWhitespaceWhenOptionEnabled() {
    let result = FileDiff.compute(
        left: "  hello",
        right: "hello",
        leftTitle: "L",
        rightTitle: "R",
        options: FileDiff.CompareOptions(ignoreLeadingWhitespace: true)
    )
    #expect(result.isIdentical)
}

@Test func computeRespectsLeadingWhitespaceWhenOptionDisabled() {
    let result = FileDiff.compute(
        left: "  hello",
        right: "hello",
        leftTitle: "L",
        rightTitle: "R",
        options: FileDiff.CompareOptions(ignoreLeadingWhitespace: false)
    )
    #expect(!result.isIdentical)
    #expect(result.hunks.count == 1)
}

@Test func computeIdenticalTextHasNoHunks() {
    let result = FileDiff.compute(left: "a\nb\nc", right: "a\nb\nc",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks == [])
    #expect(result.isIdentical)
    #expect(result.leftLines.count == result.rightLines.count)
    #expect(result.leftLines.allSatisfy { $0.kind == .common })
}

@Test func computeIdenticalWithTrailingNewline() {
    // "a\nb" and "a\nb\n" must compare equal (trailing newline is insignificant).
    let result = FileDiff.compute(left: "a\nb", right: "a\nb\n",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks == [])
    #expect(result.isIdentical)
}

@Test func computePureInsert() {
    let result = FileDiff.compute(left: "a\nc", right: "a\nb\nc",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks.count == 1)
    // Right gained one line; left must have a pad opposite the inserted line.
    #expect(result.leftLines.count == result.rightLines.count)
    let leftPads = result.leftLines.filter { $0.kind == .pad }
    let rightAdded = result.rightLines.filter { $0.kind == .added }
    #expect(leftPads.count == 1)
    #expect(rightAdded.count == 1)
    #expect(rightAdded.first?.text == "b")
}

@Test func computePureDelete() {
    let result = FileDiff.compute(left: "a\nb\nc", right: "a\nc",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks.count == 1)
    let rightPads = result.rightLines.filter { $0.kind == .pad }
    let leftRemoved = result.leftLines.filter { $0.kind == .removed }
    #expect(rightPads.count == 1)
    #expect(leftRemoved.count == 1)
    #expect(leftRemoved.first?.text == "b")
}

@Test func computeReplacedLine() {
    let result = FileDiff.compute(left: "hello world", right: "hello there",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks.count == 1)
    let leftChanged = result.leftLines.filter { $0.kind == .changed }
    let rightChanged = result.rightLines.filter { $0.kind == .changed }
    #expect(leftChanged.count == 1)
    #expect(rightChanged.count == 1)
    #expect(leftChanged.first?.text == "hello world")
    #expect(rightChanged.first?.text == "hello there")
}

@Test func computeAlignmentKeepsSidesEqualLength() {
    // Multiple interleaved edits — both aligned arrays must stay equal length.
    let result = FileDiff.compute(
        left: "keep1\nremove\nkeep2\nchange_me\nkeep3",
        right: "keep1\nkeep2\nchanged\nkeep3\nadded",
        leftTitle: "L", rightTitle: "R")
    #expect(result.leftLines.count == result.rightLines.count)
    // At least two distinct hunks: the removal and the replace+insert region.
    #expect(result.hunks.count >= 2)
}

@Test func computeGroupsContiguousEditsIntoOneHunk() {
    // Two adjacent deletions should be a single hunk, not two.
    let result = FileDiff.compute(left: "x\na\nb\ny", right: "x\ny",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks.count == 1)
    let removed = result.leftLines.filter { $0.kind == .removed }
    #expect(removed.count == 2)
}

@Test func inlineSegmentsMarkChangedCharacters() throws {
    let result = FileDiff.compute(left: "hello world", right: "hello there",
                                  leftTitle: "L", rightTitle: "R")
    let hunk = try #require(result.hunks.first)
    // "hello " is the common prefix.
    let leftSegs = hunk.leftSegments.first ?? []
    let rightSegs = hunk.rightSegments.first ?? []
    #expect(leftSegs.contains { $0.edit == .equal && $0.text == "hello " })
    #expect(rightSegs.contains { $0.edit == .equal && $0.text == "hello " })
    // The differing tail is a delete on the left ("world") and insert on the right ("there").
    #expect(leftSegs.contains { $0.edit == .delete })
    #expect(rightSegs.contains { $0.edit == .insert })
}

@Test func inlineSegmentsHandleUnicode() throws {
    let result = FileDiff.compute(left: "价格一百", right: "价格两百",
                                  leftTitle: "L", rightTitle: "R")
    let hunk = try #require(result.hunks.first)
    let leftSegs = hunk.leftSegments.first ?? []
    let rightSegs = hunk.rightSegments.first ?? []
    // "价格" common prefix, "一"/"两" differ, "百" common suffix.
    #expect(leftSegs.contains { $0.edit == .equal && $0.text == "价格" })
    #expect(rightSegs.contains { $0.edit == .equal && $0.text == "价格" })
    #expect(leftSegs.contains { $0.edit == .delete && $0.text == "一" })
    #expect(rightSegs.contains { $0.edit == .insert && $0.text == "两" })
}

@Test func reconstructTextRoundTrips() {
    let original = "a\nb\nc"
    let result = FileDiff.compute(left: original, right: "x\nb\nc",
                                  leftTitle: "L", rightTitle: "R")
    // Left side reconstructs to the original input (minus trailing newline).
    #expect(FileDiff.reconstructText(result.leftLines) == original)
    // Right side reconstructs to its input.
    #expect(FileDiff.reconstructText(result.rightLines) == "x\nb\nc")
}

@Test func reconstructTextIgnoresPads() {
    let result = FileDiff.compute(left: "a\nc", right: "a\nb\nc",
                                  leftTitle: "L", rightTitle: "R")
    // Left had a pad inserted opposite "b"; reconstruction must drop it.
    #expect(FileDiff.reconstructText(result.leftLines) == "a\nc")
    #expect(FileDiff.reconstructText(result.rightLines) == "a\nb\nc")
}

@Test func applyLeftToRightMakesSidesAgree() {
    let result = FileDiff.compute(left: "a\nb\nc", right: "a\nX\nc",
                                  leftTitle: "L", rightTitle: "R")
    let newRight = FileDiff.applyLeftToRight(result, hunkIndex: 0)
    #expect(newRight == "a\nb\nc")
    // After applying, recomputing the diff must show no hunks.
    let rechecked = FileDiff.compute(left: "a\nb\nc", right: newRight ?? "",
                                     leftTitle: "L", rightTitle: "R")
    #expect(rechecked.hunks == [])
}

@Test func applyRightToLeftMakesSidesAgree() {
    let result = FileDiff.compute(left: "a\nb\nc", right: "a\nX\nc",
                                  leftTitle: "L", rightTitle: "R")
    let newLeft = FileDiff.applyRightToLeft(result, hunkIndex: 0)
    #expect(newLeft == "a\nX\nc")
}

@Test func applyOutOfRangeHunkReturnsNil() {
    let result = FileDiff.compute(left: "a", right: "b",
                                  leftTitle: "L", rightTitle: "R")
    #expect(FileDiff.applyLeftToRight(result, hunkIndex: 5) == nil)
    #expect(FileDiff.applyRightToLeft(result, hunkIndex: -1) == nil)
}

@Test func computeEmptyLeftToNonEmptyRight() {
    let result = FileDiff.compute(left: "", right: "a\nb",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks.count == 1)
    let added = result.rightLines.filter { $0.kind == .added }
    let pads = result.leftLines.filter { $0.kind == .pad }
    #expect(added.count == 2)
    #expect(pads.count == 2)
    #expect(result.leftLines.count == result.rightLines.count)
}

@Test func computeBothEmpty() {
    let result = FileDiff.compute(left: "", right: "",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks == [])
    #expect(result.leftLines == [])
    #expect(result.rightLines == [])
}

@Test func computeBlankLinesPreserved() {
    let result = FileDiff.compute(left: "a\n\nb", right: "a\n\nb",
                                  leftTitle: "L", rightTitle: "R")
    #expect(result.hunks == [])
    #expect(result.leftLines.count == 3)
}

@Test func sourceLineNumbersTrackOriginal() {
    let result = FileDiff.compute(left: "a\nb\nc", right: "a\nb\nc",
                                  leftTitle: "L", rightTitle: "R")
    // 1-based source line numbers.
    #expect(result.leftLines.map(\.sourceLine) == [1, 2, 3])
}
