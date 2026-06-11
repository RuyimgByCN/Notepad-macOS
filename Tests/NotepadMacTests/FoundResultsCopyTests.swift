import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func foundResultsPanelCopiesAllResultsWithoutSelection() {
    let store = FindInFilesResultsStore()
    store.setResults([
        FindInFilesMatch(filePath: "/tmp/a.txt", line: 3, column: 2, lineText: "alpha line"),
        FindInFilesMatch(filePath: "/tmp/b.txt", line: 7, column: 1, lineText: "beta line"),
    ], purgeFirst: true)

    let panel = FoundResultsPanelController(store: store)
    panel.reload()

    // With a row selected (reload auto-selects the current match),
    // copy takes just that row.
    NSPasteboard.general.clearContents()
    #expect(panel.copySelectedResults() == true)
    #expect(NSPasteboard.general.string(forType: .string) == "/tmp/a.txt:3:2: alpha line")

    // With no selection, copy takes every result.
    panel.deselectAllResultsForTesting()
    NSPasteboard.general.clearContents()
    #expect(panel.copySelectedResults() == true)
    let copied = NSPasteboard.general.string(forType: .string)
    #expect(copied == "/tmp/a.txt:3:2: alpha line\n/tmp/b.txt:7:1: beta line")
}

@MainActor
@Test func foundResultsPanelCopyReportsFalseWhenEmpty() {
    let store = FindInFilesResultsStore()
    let panel = FoundResultsPanelController(store: store)
    panel.reload()
    #expect(panel.copySelectedResults() == false)
}

@MainActor
@Test func foundResultsOutlineViewRespondsToCopyOnlyWhenHooked() {
    let outline = CopyableOutlineView()
    #expect(outline.responds(to: #selector(CopyableOutlineView.copy(_:))) == false)
    outline.onCopy = { true }
    #expect(outline.responds(to: #selector(CopyableOutlineView.copy(_:))) == true)
}
