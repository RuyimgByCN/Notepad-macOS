import Foundation
import Testing
@testable import NotepadMacCore

@Test func selectAndFindContextUsesSingleLineSelection() {
    let text = "one selected value two"
    let range = (text as NSString).range(of: "selected value")

    #expect(TextSearch.contextQuery(in: text, at: range) == "selected value")
}

@Test func selectAndFindContextUsesWordAtCaret() {
    let text = "first current_word last"
    let wordRange = (text as NSString).range(of: "current_word")

    #expect(TextSearch.contextQuery(in: text, at: NSRange(location: wordRange.location + 4, length: 0)) == "current_word")
    #expect(TextSearch.contextQuery(in: text, at: NSRange(location: NSMaxRange(wordRange), length: 0)) == "current_word")
}

@Test func selectAndFindContextRejectsNonWordCaret() {
    #expect(TextSearch.contextQuery(in: "one  two", at: NSRange(location: 4, length: 0)) == nil)
}

@Test func selectAndFindContextRejectsMultilineSelection() {
    #expect(TextSearch.contextQuery(in: "one\ntwo", at: NSRange(location: 0, length: 7)) == nil)
    #expect(TextSearch.contextQuery(in: "one\rtwo", at: NSRange(location: 0, length: 7)) == nil)
}

@Test func selectAndFindContextEnforcesUTF8ByteLimit() {
    let accepted = String(repeating: "a", count: 1023)
    let rejected = String(repeating: "é", count: 512)

    #expect(TextSearch.contextQuery(in: accepted, at: NSRange(location: 0, length: accepted.utf16.count)) == accepted)
    #expect(TextSearch.contextQuery(in: rejected, at: NSRange(location: 0, length: rejected.utf16.count)) == nil)
    #expect(TextSearch.contextQuery(in: rejected, at: NSRange(location: 1, length: 0)) == nil)
}
