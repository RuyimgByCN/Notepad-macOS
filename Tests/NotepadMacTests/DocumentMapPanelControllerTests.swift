import Testing
@testable import NotepadMac

@Test func documentMapEntryBuildsLinePreviewsAndLocations() {
    let entries = DocumentMapEntry.entries(in: "alpha\nbravo\ncharlie")

    #expect(entries == [
        DocumentMapEntry(line: 1, utf16Location: 0, preview: "alpha"),
        DocumentMapEntry(line: 2, utf16Location: 6, preview: "bravo"),
        DocumentMapEntry(line: 3, utf16Location: 12, preview: "charlie")
    ])
}

@Test func documentMapEntryPreservesEmptyTrailingLineAfterFinalNewline() {
    let entries = DocumentMapEntry.entries(in: "alpha\r\nbravo\r\n")

    #expect(entries == [
        DocumentMapEntry(line: 1, utf16Location: 0, preview: "alpha"),
        DocumentMapEntry(line: 2, utf16Location: 7, preview: "bravo"),
        DocumentMapEntry(line: 3, utf16Location: 14, preview: "")
    ])
}
