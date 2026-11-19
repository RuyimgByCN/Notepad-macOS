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
@Test func foundResultsSelectionTracksDuplicateHitsAndCollapsedFiles() throws {
    let duplicate = FindInFilesMatch(filePath: "/tmp/a.txt", line: 2, column: 4, lineText: "same hit")
    let other = FindInFilesMatch(filePath: "/tmp/b.txt", line: 3, column: 1, lineText: "other hit")
    let store = FindInFilesResultsStore()
    store.setResults([duplicate, other, duplicate], purgeFirst: true)
    let panel = FoundResultsPanelController(store: store)
    panel.reload()

    let scroll = try #require(panel.window?.contentView?.subviews.compactMap { $0 as? NSScrollView }.first)
    let outline = try #require(scroll.documentView as? NSOutlineView)
    let firstFile = try #require(outline.item(atRow: 0))
    let secondFile = try #require(outline.item(atRow: 3))
    outline.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
    #expect(store.selectedIndex == 2)

    outline.collapseItem(firstFile)
    outline.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
    #expect(store.selectedIndex == 1)

    outline.collapseItem(secondFile)
    store.select(index: 2)
    panel.revealSelectedMatch()
    #expect(outline.isItemExpanded(firstFile))
    #expect(!outline.isItemExpanded(secondFile))
    #expect(outline.selectedRow == 2)
    #expect(store.selectedIndex == 2)

    panel.perform(NSSelectorFromString("deleteSelected:"), with: nil)
    #expect(store.matches == [duplicate, other])
}

@MainActor
@Test func foundResultsOutlineViewRespondsToCopyOnlyWhenHooked() {
    let outline = CopyableOutlineView()
    #expect(outline.responds(to: #selector(CopyableOutlineView.copy(_:))) == false)
    outline.onCopy = { true }
    #expect(outline.responds(to: #selector(CopyableOutlineView.copy(_:))) == true)
}
