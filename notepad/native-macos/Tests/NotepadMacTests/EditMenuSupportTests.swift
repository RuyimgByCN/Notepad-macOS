import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
private final class CharacterPalettePresenterSpy: CharacterPalettePresenting {
    var invocationCount = 0

    func orderFrontCharacterPalette(_ sender: Any?) {
        invocationCount += 1
    }
}

@Test func editMenuSupportFormatsShortDateTimeUsingTimeThenDateByDefault() throws {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = 6
    components.day = 2
    components.hour = 13
    components.minute = 8
    components.second = 30
    let date = try #require(components.date)

    let value = EditMenuSupport.dateTimeString(
        for: date,
        style: .short,
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        reverseOrder: false
    )

    #expect(value == "1:08 PM 6/2/26")
}

@Test func editMenuSupportFormatsLongDateTimeUsingReversedOrderWhenRequested() throws {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = 6
    components.day = 2
    components.hour = 13
    components.minute = 8
    components.second = 30
    let date = try #require(components.date)

    let value = EditMenuSupport.dateTimeString(
        for: date,
        style: .long,
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        reverseOrder: true
    )

    #expect(value == "June 2, 2026 1:08 PM")
}

@Test func editMenuSupportFormatsCustomizedDateTimeUsingProvidedPattern() throws {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = 6
    components.day = 2
    components.hour = 13
    components.minute = 8
    components.second = 30
    let date = try #require(components.date)

    let value = EditMenuSupport.dateTimeString(
        for: date,
        style: .custom("yyyy-MM-dd HH:mm"),
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: TimeZone(secondsFromGMT: 0)!,
        reverseOrder: false
    )

    #expect(value == "2026-06-02 13:08")
}

@Test func editMenuSupportBuildsClipboardStringsForCurrentDocumentPaths() {
    let fileURL = URL(filePath: "/tmp/project/notes.md")

    #expect(EditMenuSupport.documentClipboardString(for: fileURL, mode: .fullPath) == "/tmp/project/notes.md")
    #expect(EditMenuSupport.documentClipboardString(for: fileURL, mode: .filename) == "notes.md")
    #expect(EditMenuSupport.documentClipboardString(for: fileURL, mode: .directoryPath) == "/tmp/project")
}

@Test func editMenuSupportResolvesSelectedRelativeFilePathAgainstCurrentDocument() {
    let text = "include docs/readme.md here"
    let selection = (text as NSString).range(of: "docs/readme.md")
    let currentFileURL = URL(filePath: "/tmp/project/current.txt")

    let target = EditMenuSupport.selectionTarget(
        in: text,
        selectedRange: selection,
        currentFileURL: currentFileURL
    )

    #expect(target == .file(URL(filePath: "/tmp/project/docs/readme.md")))
}

@Test func editMenuSupportExtractsUrlAtCaretWithoutSelection() {
    let text = "Visit https://example.com/docs?q=1 now"
    let caret = (text as NSString).range(of: "example").location

    let target = EditMenuSupport.selectionTarget(
        in: text,
        selectedRange: NSRange(location: caret, length: 0),
        currentFileURL: nil
    )

    #expect(target == .web(URL(string: "https://example.com/docs?q=1")!))
}

@Test func editMenuSupportExtractsQuotedAbsolutePathAtCaret() {
    let text = "Open '/tmp/project/notes.md' next"
    let caret = (text as NSString).range(of: "project").location

    let target = EditMenuSupport.selectionTarget(
        in: text,
        selectedRange: NSRange(location: caret, length: 0),
        currentFileURL: nil
    )

    #expect(target == .file(URL(filePath: "/tmp/project/notes.md")))
}

@Test func editMenuSupportBuildsGoogleSearchUrlFromSelectedText() throws {
    let preferences = AppPreferences(searchEngineChoice: .google, customSearchEngineURL: "")
    let text = "search hello world"
    let selection = (text as NSString).range(of: "hello world")

    let url = try EditMenuSupport.searchURL(in: text, selectedRange: selection, preferences: preferences)

    #expect(url.absoluteString == "https://www.google.com/search?q=hello%20world")
}

@Test func editMenuSupportBuildsCustomSearchUrlFromCaretWord() throws {
    let preferences = AppPreferences(
        searchEngineChoice: .custom,
        customSearchEngineURL: "https://example.com/find?term=$(CURRENT_WORD)"
    )
    let text = "look up rustlang now"
    let caret = (text as NSString).range(of: "rustlang").location + 2

    let url = try EditMenuSupport.searchURL(
        in: text,
        selectedRange: NSRange(location: caret, length: 0),
        preferences: preferences
    )

    #expect(url.absoluteString == "https://example.com/find?term=rustlang")
}

@MainActor
@Test func editMenuSupportPresentsNativeCharacterPalette() {
    let presenter = CharacterPalettePresenterSpy()

    EditMenuSupport.presentCharacterPanel(using: presenter, sender: nil)

    #expect(presenter.invocationCount == 1)
}
