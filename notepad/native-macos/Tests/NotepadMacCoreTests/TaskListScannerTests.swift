import Foundation
import Testing
@testable import NotepadMacCore

@Test func taskListScannerFindsBasicTags() {
    let text = """
    // TODO: fix this later
    let x = 1
    // FIXME: broken edge case
    var y = 2
    """
    let entries = TaskListScanner.scan(text: text)
    #expect(entries.count == 2)
    #expect(entries[0].tag == "TODO")
    #expect(entries[0].line == 1)
    #expect(entries[0].message == "fix this later")
    #expect(entries[1].tag == "FIXME")
    #expect(entries[1].line == 3)
    #expect(entries[1].message == "broken edge case")
}

@Test func taskListScannerFindsAllDefaultTags() {
    let text = """
    // TODO: a
    // FIXME: b
    // NOTE: c
    // HACK: d
    // BUG: e
    // XXX: f
    """
    let entries = TaskListScanner.scan(text: text)
    let tags = entries.map { $0.tag }
    #expect(Set(tags) == Set(["TODO", "FIXME", "NOTE", "HACK", "BUG", "XXX"]))
}

@Test func taskListScannerIsCaseInsensitive() {
    let text = "// todo: lowercase tag"
    let entries = TaskListScanner.scan(text: text)
    #expect(entries.count == 1)
    #expect(entries[0].tag == "TODO")
}

@Test func taskListScannerEmptyTextReturnsEmpty() {
    #expect(TaskListScanner.scan(text: "").isEmpty)
}

@Test func taskListScannerNoTagsReturnsEmpty() {
    let text = "let x = 1\nvar y = 2\n"
    #expect(TaskListScanner.scan(text: text).isEmpty)
}

@Test func taskListScannerAtMostOneEntryPerLine() {
    // A line with two tags should produce only one entry.
    let text = "// TODO: first FIXME: second"
    let entries = TaskListScanner.scan(text: text)
    #expect(entries.count == 1)
}

@Test func taskListScannerReturnsCorrectLineNumbers() {
    let text = "line1\n// TODO: here\nline3"
    let entries = TaskListScanner.scan(text: text)
    #expect(entries.count == 1)
    #expect(entries[0].line == 2)
}

@Test func taskListScannerCustomTagsOnly() {
    let text = "// TODO: ignored\n// MYMARK: found"
    let entries = TaskListScanner.scan(text: text, tags: ["MYMARK"])
    #expect(entries.count == 1)
    #expect(entries[0].tag == "MYMARK")
}

@Test func taskListScannerHandlesCRLF() {
    let text = "// TODO: first\r\n// FIXME: second\r\n"
    let entries = TaskListScanner.scan(text: text)
    #expect(entries.count == 2)
    #expect(entries[0].tag == "TODO")
    #expect(entries[0].line == 1)
    #expect(entries[1].tag == "FIXME")
    #expect(entries[1].line == 2)
}

@Test func taskListScannerHashCommentPrefix() {
    let text = "# TODO: python style"
    let entries = TaskListScanner.scan(text: text)
    #expect(entries.count == 1)
    #expect(entries[0].message == "python style")
}

@Test func taskListScannerTagsFromPreferenceEmpty() {
    #expect(TaskListScanner.tags(fromPreference: "") == TaskListScanner.defaultTags)
}

@Test func taskListScannerTagsFromPreferenceCustom() {
    let tags = TaskListScanner.tags(fromPreference: "MYMARK, CUSTOM")
    #expect(tags == ["MYMARK", "CUSTOM"])
}

@Test func taskListScannerTagsFromPreferenceUppercased() {
    let tags = TaskListScanner.tags(fromPreference: "todo, fixme")
    #expect(tags == ["TODO", "FIXME"])
}

@Test func taskListScannerTagsFromPreferenceFiltersEmpty() {
    let tags = TaskListScanner.tags(fromPreference: " , , ")
    #expect(tags == TaskListScanner.defaultTags)
}

@Test func taskListScannerCustomTagsScanning() {
    let text = "// MYMARK: custom task"
    let entries = TaskListScanner.scan(text: text, tags: ["MYMARK"])
    #expect(entries.count == 1)
    #expect(entries[0].tag == "MYMARK")
    #expect(entries[0].message == "custom task")
}
