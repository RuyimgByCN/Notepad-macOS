import Foundation
import Testing
@testable import NotepadMacCore

@Test func fileSearchCountsLogicalLinesAndUnicodeColumns() {
    let text = "😀 hit hit\r\nnone\rhit\n末尾 hit"
    let options = TextSearch.Options(matchCase: true, wraps: false)
    let matches = FindInFilesSearch.searchInContent(text, query: "hit", options: options, filePath: "test")
    #expect(matches.map(\.line) == [1, 1, 3, 4])
    #expect(matches.map(\.column) == [4, 8, 1, 4])
    #expect(matches.map(\.lineText) == ["😀 hit hit", "😀 hit hit", "hit", "末尾 hit"])
    let perLine = FindInFilesSearch.searchInContent(text, query: "hit", options: options, filePath: "test", perLineResult: true)
    #expect(perLine.map(\.line) == [1, 3, 4])
}

@Test func fileSearchTerminatesForEmptyRegexMatchesIncludingEOF() {
    let options = TextSearch.Options(wraps: false, searchMode: .regex)
    let lookahead = FindInFilesSearch.searchInContent("😀hit\nhit", query: "(?=hit)", options: options, filePath: "test")
    #expect(lookahead.map(\.line) == [1, 2])
    #expect(lookahead.map(\.column) == [3, 1])
    let allPositions = FindInFilesSearch.searchInContent("😀ab", query: "(?=.)", options: options, filePath: "test")
    #expect(allPositions.map(\.column) == [1, 3, 4])
    for (text, line, column) in [("hit", 1, 4), ("hit\r\n", 2, 1)] {
        let eof = FindInFilesSearch.searchInContent(text, query: "\\z", options: options, filePath: "test")
        #expect(eof.count == 1)
        #expect(eof.first?.line == line)
        #expect(eof.first?.column == column)
    }
}

@Test func fileSearchPreservesMultilineAndWholeWordSemantics() {
    let multiline = FindInFilesSearch.searchInContent(
        "first\nsecond\nthird", query: "first.*second",
        options: TextSearch.Options(searchMode: .regex, dotMatchesLineSeparators: true), filePath: "test"
    )
    #expect(multiline.first?.line == 1)
    #expect(multiline.first?.lineText == "first\nsecond")
    let options = TextSearch.Options(matchCase: false, wholeWord: true, searchMode: .regex)
    let findMatches = TextSearch.prepareFindAll("hit", options: options)
    #expect(findMatches("HIT hitter").map(\.location) == [0])
    #expect(findMatches("other hit").map(\.location) == [6])
    #expect(findMatches("").isEmpty)
    #expect(TextSearch.prepareFindAll("[", options: options)("hit").isEmpty)
}

@Test func fileSearchHandlesDenseResults() {
    let count = 4_000
    let matches = FindInFilesSearch.searchInContent(
        String(repeating: "hit\r\n", count: count), query: "hit",
        options: TextSearch.Options(searchMode: .regex), filePath: "test"
    )
    #expect(matches.count == count)
    #expect(matches.last?.line == count)
    #expect(matches.last?.column == 1)
}

@Test func fileSearchHonorsTaskCancellation() async {
    let task = Task.detached {
        while !Task.isCancelled { await Task.yield() }
        return FindInFilesSearch.searchInContent(
            "hit", query: "hit", options: TextSearch.Options(), filePath: "test"
        )
    }
    task.cancel()
    #expect(await task.value.isEmpty)
}

@Test func fileSearchAllowsConcurrentIndependentRegexBatches() async {
    await withTaskGroup(of: Bool.self) { group in
        for _ in 0..<16 {
            group.addTask {
                for _ in 0..<50 {
                    let matches = FindInFilesSearch.searchInContent(
                        "😀 hit\r\nhit", query: "h(it)",
                        options: TextSearch.Options(searchMode: .regex), filePath: "test"
                    )
                    if matches.map(\.line) != [1, 2] { return false }
                }
                return true
            }
        }
        for await success in group { #expect(success) }
    }
}

@Test func structuredTextUsesItsLexerAndFixedKeywordSlots() throws {
    let modelURL = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "upstream/notepad-plus-plus/PowerEditor/src/langs.model.xml")
    let catalog = try LanguageCatalog.load(from: modelURL)
    let language = try #require(catalog.language(named: "fcST"))
    #expect(language.displayName == "Structured Text")
    #expect(language.lexillaLexerName == "fcST")
    #expect(language.extensions.contains("stx"))
    #expect(language.scintillaKeywordSets.map(\.index) == [0, 1, 2, 3])
    let sparse = LanguageDefinition(name: "fcST", keywordGroups: ["instre1": ["if"], "type4": ["pragma"]])
    #expect(sparse.scintillaKeywordSets.map(\.index) == [0, 5])
}
