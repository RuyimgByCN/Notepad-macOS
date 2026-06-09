import AppKit
import Testing
@testable import NotepadMac

@MainActor
@Test func topLevelMenuOrderMatchesUpstream() {
    #expect(AppMenu.upstreamTopLevelMenuDefaultTitles == [
        "File",
        "Edit",
        "Search",
        "View",
        "Encoding",
        "Language",
        "Settings",
        "Tools",
        "Macro",
        "Run",
        "Plugins",
        "Window",
        "?"
    ])
}

@MainActor
@Test func topLevelMenuOrderRemovesWorkspaceAndAppliesUpstreamSequence() {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem(title: "App", action: nil, keyEquivalent: "")
    let workspaceMenuItem = NSMenuItem(title: "Workspace", action: nil, keyEquivalent: "")
    let orderedItems = AppMenu.upstreamTopLevelMenuDefaultTitles.map {
        NSMenuItem(title: $0, action: nil, keyEquivalent: "")
    }

    mainMenu.addItem(appMenuItem)
    mainMenu.addItem(orderedItems[0])
    mainMenu.addItem(orderedItems[1])
    mainMenu.addItem(workspaceMenuItem)
    orderedItems.dropFirst(2).forEach { mainMenu.addItem($0) }

    AppMenu.applyUpstreamTopLevelMenuOrder(
        mainMenu: mainMenu,
        appMenuItem: appMenuItem,
        orderedItems: orderedItems
    )

    #expect(mainMenu.items.map(\.title) == ["App"] + AppMenu.upstreamTopLevelMenuDefaultTitles)
    #expect(mainMenu.items.contains(workspaceMenuItem) == false)
}

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
