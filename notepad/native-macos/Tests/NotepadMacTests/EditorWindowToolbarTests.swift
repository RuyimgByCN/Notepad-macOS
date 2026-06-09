import AppKit
import Testing
@testable import NotepadMac

@MainActor
@Test func toolbarDefaultOrderMatchesCompleteUpstreamToolBarIcons() {
    #expect(EditorWindowToolbar.upstreamDefaultItemIdentifierRawValues(includesFoldingCommands: false) == upstreamToolbarOrder)
}

@MainActor
@Test func toolbarDefaultOrderDoesNotAppendNativeFoldingCommands() {
    #expect(EditorWindowToolbar.upstreamDefaultItemIdentifierRawValues(includesFoldingCommands: true) == upstreamToolbarOrder)
}

@MainActor
@Test func toolbarButtonsUseUpstreamStandardBitmapResources() {
    #expect(EditorWindowToolbar.upstreamToolbarBitmapResourceNames() == [
        "newFile",
        "openFile",
        "saveFile",
        "saveAll",
        "closeFile",
        "closeAll",
        "print",
        "cut",
        "copy",
        "paste",
        "undo",
        "redo",
        "find",
        "findReplace",
        "zoomIn",
        "zoomOut",
        "syncV",
        "syncH",
        "wrap",
        "allChars",
        "indentGuide",
        "udl",
        "docMap",
        "docList",
        "funcList",
        "fileBrowser",
        "monitoring",
        "startRecord",
        "stopRecord",
        "playRecord",
        "playRecord_m",
        "saveRecord"
    ])
}

private let upstreamToolbarOrder = [
        "org.notepad-plus-plus.macnative.editor.toolbar.new",
        "org.notepad-plus-plus.macnative.editor.toolbar.open",
        "org.notepad-plus-plus.macnative.editor.toolbar.save",
        "org.notepad-plus-plus.macnative.editor.toolbar.save-all",
        "org.notepad-plus-plus.macnative.editor.toolbar.close",
        "org.notepad-plus-plus.macnative.editor.toolbar.close-all",
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
        "org.notepad-plus-plus.macnative.editor.toolbar.zoom-in",
        "org.notepad-plus-plus.macnative.editor.toolbar.zoom-out",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.sync-vertical-scroll",
        "org.notepad-plus-plus.macnative.editor.toolbar.sync-horizontal-scroll",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.wrap.toggle",
        "org.notepad-plus-plus.macnative.editor.toolbar.show-all-characters",
        "org.notepad-plus-plus.macnative.editor.toolbar.indent-guide",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.user-defined-language",
        "org.notepad-plus-plus.macnative.editor.toolbar.document-map",
        "org.notepad-plus-plus.macnative.editor.toolbar.document-list",
        "org.notepad-plus-plus.macnative.editor.toolbar.function-list",
        "org.notepad-plus-plus.macnative.editor.toolbar.file-browser",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.monitoring",
        NSToolbarItem.Identifier.space.rawValue,
        "org.notepad-plus-plus.macnative.editor.toolbar.macro.start-recording",
        "org.notepad-plus-plus.macnative.editor.toolbar.macro.stop-recording",
        "org.notepad-plus-plus.macnative.editor.toolbar.macro.play-recorded",
        "org.notepad-plus-plus.macnative.editor.toolbar.macro.run-multiple",
        "org.notepad-plus-plus.macnative.editor.toolbar.macro.save-current"
]
