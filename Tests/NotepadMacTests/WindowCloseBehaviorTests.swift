import AppKit
import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

/// Tests for the window-close interception that distinguishes "quit the app"
/// (red traffic-light / ⌘W / toolbar close) from "close a single tab"
/// (tab bar X, tab context menu, document list). Classic Notepad++ semantics:
/// the window close button exits the app; only the per-tab X closes a file.
@MainActor
private func makeController() throws -> EditorWindowController {
    EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
}

@MainActor
@Test func windowCloseAllowsTabTargetedCloseWithoutQuitting() throws {
    let controller = try makeController()
    defer { controller.editorSurface.teardown() }

    // Closing via the tab bar X / tab context menu / document list.
    controller.isClosingSingleTab = true

    var quitInvoked = false
    let allowed = controller.shouldAllowWindowClose { quitInvoked = true }

    // A tab-targeted close dismisses the document — it must neither quit the
    // app nor be blocked.
    #expect(allowed == true)
    #expect(quitInvoked == false)
}

@MainActor
@Test func windowCloseRedirectsNonTabCloseToAppQuit() throws {
    let controller = try makeController()
    defer { controller.editorSurface.teardown() }

    // Default state: not a tab close (red X / ⌘W / toolbar close).
    controller.isClosingSingleTab = false

    var quitInvoked = false
    let allowed = controller.shouldAllowWindowClose { quitInvoked = true }

    // The window itself must NOT close; instead the app quit path is triggered.
    #expect(allowed == false)
    #expect(quitInvoked == true)
}

private func upstreamLanguageModelURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/src/langs.model.xml")
}

private func upstreamStyleModelURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/src/stylers.model.xml")
}
