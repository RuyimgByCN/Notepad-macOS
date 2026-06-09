import AppKit
import Testing
@testable import NotepadMac

@MainActor
@Test func showSymbolMenuMatchesUpstreamDefaultOptions() {
    let specs = AppMenu.showSymbolMenuItemSpecs

    #expect(specs.map(\.defaultTitle) == [
        "Show Space and Tab",
        "Show End of Line",
        "Show Non-Printing Characters",
        "Show Control Characters && Unicode EOL",
        "Show All Characters",
        "",
        "Show Indent Guide",
        "Show Wrap Symbol"
    ])
    #expect(specs.map(\.isSeparator) == [false, false, false, false, false, true, false, false])
    #expect(specs.compactMap(\.action).map(NSStringFromSelector) == [
        "toggleShowWhitespace:",
        "toggleShowEOL:",
        "toggleNpcDisplay:",
        "toggleControlCharactersAndUnicodeEOL:",
        "toggleShowAllCharacters:",
        "toggleIndentGuides:",
        "toggleWrapSymbol:"
    ])
    #expect(Localization.string(.viewShowWhitespace, default: "") == "Show Space and Tab")
    #expect(Localization.string(.viewShowNpcCharacters, default: "") == "Show Non-Printing Characters")
    #expect(Localization.string(.viewShowControlCharactersAndUnicodeEOL, default: "") == "Show Control Characters && Unicode EOL")
}
