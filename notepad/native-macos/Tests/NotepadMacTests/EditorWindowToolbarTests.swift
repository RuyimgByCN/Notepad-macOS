import AppKit
import Testing
@testable import NotepadMac

@MainActor
@Test func toolbarDefaultOrderStartsWithUpstreamCommands() {
    #expect(EditorWindowToolbar.upstreamDefaultItemIdentifierRawValues(includesFoldingCommands: false) == [
        "org.notepad-plus-plus.macnative.editor.toolbar.new",
        "org.notepad-plus-plus.macnative.editor.toolbar.open",
        "org.notepad-plus-plus.macnative.editor.toolbar.save",
        "org.notepad-plus-plus.macnative.editor.toolbar.save-all",
        "org.notepad-plus-plus.macnative.editor.toolbar.close",
        "org.notepad-plus-plus.macnative.editor.toolbar.close-all",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.print",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.cut",
        "org.notepad-plus-plus.macnative.editor.toolbar.copy",
        "org.notepad-plus-plus.macnative.editor.toolbar.paste",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.undo",
        "org.notepad-plus-plus.macnative.editor.toolbar.redo",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.find",
        "org.notepad-plus-plus.macnative.editor.toolbar.replace",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.bookmark.toggle",
        "org.notepad-plus-plus.macnative.editor.toolbar.bookmark.previous",
        "org.notepad-plus-plus.macnative.editor.toolbar.bookmark.next",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.wrap.toggle",
        "org.notepad-plus-plus.macnative.editor.toolbar.function-list"
    ])
}

@MainActor
@Test func toolbarDefaultOrderIncludesFoldingCommandsWhenAvailable() {
    #expect(Array(EditorWindowToolbar.upstreamDefaultItemIdentifierRawValues(includesFoldingCommands: true).suffix(4)) == [
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.fold.toggle",
        "org.notepad-plus-plus.macnative.editor.toolbar.fold.all",
        "org.notepad-plus-plus.macnative.editor.toolbar.fold.unfold-all"
    ])
}
