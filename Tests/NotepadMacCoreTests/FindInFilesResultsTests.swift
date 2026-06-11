import Foundation
import Testing
@testable import NotepadMacCore

@Test @MainActor
func findInFilesResultsStorePurgesAndNavigates() {
    let store = FindInFilesResultsStore()
    let first = FindInFilesMatch(filePath: "/tmp/a.txt", line: 1, column: 1, lineText: "hello")
    let second = FindInFilesMatch(filePath: "/tmp/b.txt", line: 2, column: 3, lineText: "world")

    store.setResults([first, second], purgeFirst: true)
    #expect(store.matches.count == 2)
    #expect(store.selectedMatch == first)

    #expect(store.selectNext() == second)
    #expect(store.selectNext() == first)

    #expect(store.selectPrevious() == second)

    store.setResults([FindInFilesMatch(filePath: "/tmp/c.txt", line: 5, column: 1, lineText: "new")], purgeFirst: false)
    #expect(store.matches.count == 3)
    #expect(store.selectedIndex == 0)
}

@Test @MainActor
func findInFilesResultsStoreGroupsByFile() {
    let store = FindInFilesResultsStore()
    store.setResults([
        FindInFilesMatch(filePath: "/tmp/a.txt", line: 1, column: 1, lineText: "one"),
        FindInFilesMatch(filePath: "/tmp/b.txt", line: 2, column: 1, lineText: "two"),
        FindInFilesMatch(filePath: "/tmp/a.txt", line: 3, column: 1, lineText: "three"),
    ], purgeFirst: true)

    let groups = store.groupedByFile()
    #expect(groups.count == 2)
    #expect(groups[0].filePath == "/tmp/a.txt")
    #expect(groups[0].matches.count == 2)
    #expect(groups[1].filePath == "/tmp/b.txt")
}

@Test @MainActor
func findInFilesResultsStoreRemovesFileGroup() {
    let store = FindInFilesResultsStore()
    store.setResults([
        FindInFilesMatch(filePath: "/tmp/a.txt", line: 1, column: 1, lineText: "one"),
        FindInFilesMatch(filePath: "/tmp/b.txt", line: 2, column: 1, lineText: "two"),
    ], purgeFirst: true)
    store.select(index: 1)

    store.removeFile("/tmp/a.txt")
    #expect(store.matches.count == 1)
    #expect(store.selectedMatch?.filePath == "/tmp/b.txt")
}
