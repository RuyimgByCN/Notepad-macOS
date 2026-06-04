import Foundation
import Testing
@testable import NotepadMacCore

@Test func charRangeFinderFindsNonASCIIByte() {
    let text = "Hello \u{00E9} World" // é is UTF-8 0xC3 0xA9
    let options = CharRangeSearchOptions(preset: .nonASCII, direction: .down, wraps: false)
    let match = CharRangeFinder.findNext(in: text, from: NSRange(location: 0, length: 0), options: options)
    #expect(match != nil)
}

@Test func charRangeFinderFindsASCIIByte() {
    let text = "Hello World"
    let options = CharRangeSearchOptions(preset: .ascii, direction: .down, wraps: false)
    let match = CharRangeFinder.findNext(in: text, from: NSRange(location: 0, length: 0), options: options)
    #expect(match?.location == 0)
}

@Test func charRangeFinderWrapsWhenEnabled() {
    let text = "Z"
    let options = CharRangeSearchOptions(preset: .custom(90, 90), direction: .down, wraps: true)
    let first = CharRangeFinder.findNext(in: text, from: NSRange(location: 0, length: 1), options: options)
    #expect(first?.location == 0)
}

@Test func workspaceDocumentCollectsAllFileURLs() {
    let workspace = WorkspaceDocument(
        name: "Demo",
        projects: [
            WorkspaceNode(
                name: "Root",
                kind: .project,
                children: [
                    .file(url: URL(fileURLWithPath: "/tmp/a.txt")),
                    WorkspaceNode(
                        name: "Nested",
                        kind: .folder,
                        children: [.file(url: URL(fileURLWithPath: "/tmp/b.txt"))]
                    )
                ]
            )
        ]
    )
    let urls = workspace.allFileURLs().map(\.path)
    #expect(urls == ["/tmp/a.txt", "/tmp/b.txt"])
}

@Test func findInFilesSearchFindsMatchesInProvidedFiles() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("sample.txt")
    try "alpha beta alpha".write(to: fileURL, atomically: true, encoding: .utf8)

    let results = FindInFilesSearch.searchInFiles(
        [fileURL],
        query: "alpha",
        matchCase: false,
        wholeWord: false
    )
    #expect(results.count == 2)
    #expect(results.allSatisfy { $0.filePath == fileURL.path })
}

@Test func backupPathBuilderCreatesSimpleAndVerbosePaths() {
    let file = URL(fileURLWithPath: "/tmp/project/readme.txt")
    let simple = BackupPathBuilder.backupURL(
        for: file,
        mode: .simple,
        useCustomDirectory: false,
        customDirectory: ""
    )
    #expect(simple?.lastPathComponent == "readme.txt.bak")

    let verbose = BackupPathBuilder.backupURL(
        for: file,
        mode: .verbose,
        useCustomDirectory: false,
        customDirectory: ""
    )
    #expect(verbose?.path.contains("nppBackup") == true)
    #expect(verbose?.lastPathComponent.hasSuffix(".bak") == true)
}

@MainActor
@Test func findInFilesResultsStoreUniqueFilePathsPreserveOrder() {
    let store = FindInFilesResultsStore()
    store.setResults([
        FindInFilesMatch(filePath: "/a.txt", line: 1, column: 1, lineText: "one"),
        FindInFilesMatch(filePath: "/b.txt", line: 2, column: 1, lineText: "two"),
        FindInFilesMatch(filePath: "/a.txt", line: 3, column: 1, lineText: "three"),
    ], purgeFirst: true)
    #expect(store.uniqueFilePaths() == ["/a.txt", "/b.txt"])
}
