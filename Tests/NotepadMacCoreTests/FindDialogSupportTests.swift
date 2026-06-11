import Foundation
import Testing
@testable import NotepadMacCore

// MARK: - Replace All "In selection" scope

@Test func replaceAllHonorsSearchRangeScope() throws {
    let text = "aaa bbb aaa bbb aaa"
    // Constrain to the middle "aaa bbb" (UTF-16 offsets 8..<15).
    let options = TextSearch.Options(
        matchCase: true,
        searchMode: .normal,
        searchRange: NSRange(location: 8, length: 7)
    )
    let result = TextSearch.replaceAll("aaa", with: "XXX", in: text, options: options)
    #expect(result.text == "aaa bbb XXX bbb aaa")
    #expect(result.count == 1)
}

@Test func replaceAllWithRegexInsideSearchRange() throws {
    let text = "one1 two2 three3"
    let options = TextSearch.Options(
        matchCase: true,
        searchMode: .regex,
        searchRange: NSRange(location: 5, length: 5)  // "two2 "
    )
    let result = TextSearch.replaceAll("(\\w+?)(\\d)", with: "$2$1", in: text, options: options)
    #expect(result.text == "one1 2two three3")
    #expect(result.count == 1)
}

@Test func replaceAllWithEmptySearchRangeReplacesNothing() throws {
    let options = TextSearch.Options(searchRange: NSRange(location: 3, length: 0))
    let result = TextSearch.replaceAll("a", with: "b", in: "aaaa", options: options)
    #expect(result.text == "aaaa")
    #expect(result.count == 0)
}

// MARK: - DocumentMatchLocator

@Test func documentMatchLocatorReportsLineColumnAndLineText() throws {
    let text = "alpha beta\ngamma alpha\r\nalpha"
    let matches = DocumentMatchLocator.matches(
        query: "alpha",
        in: text,
        filePath: "/tmp/sample.txt",
        options: .init(matchCase: true, searchMode: .normal)
    )
    #expect(matches.count == 3)
    #expect(matches[0].line == 1)
    #expect(matches[0].column == 1)
    #expect(matches[0].lineText == "alpha beta")
    #expect(matches[1].line == 2)
    #expect(matches[1].column == 7)
    #expect(matches[1].lineText == "gamma alpha")
    #expect(matches[2].line == 3)
    #expect(matches[2].column == 1)
    #expect(matches[2].lineText == "alpha")
    #expect(matches.allSatisfy { $0.filePath == "/tmp/sample.txt" })
}

@Test func documentMatchLocatorReturnsEmptyForNoMatches() throws {
    let matches = DocumentMatchLocator.matches(
        query: "zzz", in: "abc\ndef", filePath: "f",
        options: .init(searchMode: .normal))
    #expect(matches.isEmpty)
}

// MARK: - FindDialogState persistence

@Test func findDialogStateRoundTripsThroughPreferencesStore() throws {
    let suite = "FindDialogSupportTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = PreferencesStore(defaults: defaults)

    // Defaults
    let initial = store.loadFindDialogState()
    #expect(initial == FindDialogState())

    let custom = FindDialogState(
        backwardDirection: true,
        transparencyEnabled: false,
        transparencyOnLosingFocusOnly: false,
        transparencyOpacity: 0.5,
        markBookmarkLine: true,
        markPurgeForEachSearch: true,
        collapsed: true
    )
    store.saveFindDialogState(custom)
    #expect(store.loadFindDialogState() == custom)
}

@Test func findDialogStateClampsOpacity() throws {
    #expect(FindDialogState(transparencyOpacity: 0.01).transparencyOpacity == 0.2)
    #expect(FindDialogState(transparencyOpacity: 5).transparencyOpacity == 1.0)
}

// MARK: - Smart highlight persistence

@Test func smartHighlightDefaultsToEnabledAndRoundTrips() throws {
    let suite = "FindDialogSupportTests.smart.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = PreferencesStore(defaults: defaults)

    // Upstream default: smart highlighting is on out of the box.
    #expect(store.loadSmartHighlightEnabled() == true)
    store.saveSmartHighlightEnabled(false)
    #expect(store.loadSmartHighlightEnabled() == false)
    store.saveSmartHighlightEnabled(true)
    #expect(store.loadSmartHighlightEnabled() == true)
}
