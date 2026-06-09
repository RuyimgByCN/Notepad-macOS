import AppKit
import NotepadMacCore
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

@MainActor
@Test func toolbarButtonsLoadPackagedUpstreamBitmapImages() {
    let controller = EditorWindowController()
    defer { controller.editorSurface.teardown() }
    let toolbarDelegate = EditorWindowToolbar(controller: controller)
    let toolbar = toolbarDelegate.makeToolbar()

    for rawIdentifier in upstreamToolbarOrder where rawIdentifier != NSToolbarItem.Identifier.space.rawValue {
        let identifier = NSToolbarItem.Identifier(rawIdentifier)
        let item = toolbarDelegate.toolbar(
            toolbar,
            itemForItemIdentifier: identifier,
            willBeInsertedIntoToolbar: true
        )

        #expect(item?.image?.isTemplate == false, "Toolbar item should use upstream bitmap image for \(rawIdentifier)")
    }
}

@MainActor
@Test func toolbarButtonsMaskPackagedBitmapBackgrounds() throws {
    let controller = EditorWindowController()
    defer { controller.editorSurface.teardown() }
    let toolbarDelegate = EditorWindowToolbar(controller: controller)
    let toolbar = toolbarDelegate.makeToolbar()

    for rawIdentifier in upstreamToolbarOrder where rawIdentifier != NSToolbarItem.Identifier.space.rawValue {
        let identifier = NSToolbarItem.Identifier(rawIdentifier)
        let item = toolbarDelegate.toolbar(
            toolbar,
            itemForItemIdentifier: identifier,
            willBeInsertedIntoToolbar: true
        )
        let image = try #require(item?.image)
        let transparentEdgePixelCount = try countTransparentEdgePixels(in: image)

        #expect(
            transparentEdgePixelCount > 0,
            "Toolbar bitmap background should be transparent for \(rawIdentifier)"
        )
    }
}

@MainActor
@Test func upstreamToolbarButtonsExposeConcreteActions() {
    let controller = EditorWindowController()
    defer { controller.editorSurface.teardown() }
    let toolbarDelegate = EditorWindowToolbar(controller: controller)
    let toolbar = toolbarDelegate.makeToolbar()

    for rawIdentifier in upstreamToolbarOrder where rawIdentifier != NSToolbarItem.Identifier.space.rawValue {
        let identifier = NSToolbarItem.Identifier(rawIdentifier)
        let item = toolbarDelegate.toolbar(
            toolbar,
            itemForItemIdentifier: identifier,
            willBeInsertedIntoToolbar: true
        )

        #expect(item?.action != nil, "Missing toolbar action for \(rawIdentifier)")
        #expect(item?.isEnabled == true, "Toolbar item should be enabled for \(rawIdentifier)")
    }
}

@MainActor
@Test func findReplacePanelIsResizable() {
    let defaults = UserDefaults(suiteName: "test.findPanel.resizable.\(UUID().uuidString)")!
    let controller = EditorWindowController(preferencesStore: PreferencesStore(defaults: defaults))
    defer { controller.editorSurface.teardown() }
    let panel = FindPanelController(editor: controller, preferencesStore: PreferencesStore(defaults: defaults))

    #expect(panel.window?.styleMask.contains(NSWindow.StyleMask.resizable) == true)
    #expect((panel.window?.minSize.width ?? 0) >= 460)
    #expect((panel.window?.minSize.height ?? 0) >= 295)
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

private func countTransparentEdgePixels(in image: NSImage) throws -> Int {
    let representation = try bitmapRepresentation(for: image)
    let width = representation.pixelsWide
    let height = representation.pixelsHigh
    var count = 0

    for x in 0..<width {
        if (representation.colorAt(x: x, y: 0)?.alphaComponent ?? 1) < 0.01 {
            count += 1
        }
        if (representation.colorAt(x: x, y: height - 1)?.alphaComponent ?? 1) < 0.01 {
            count += 1
        }
    }

    guard height > 2 else { return count }
    for y in 1..<(height - 1) {
        if (representation.colorAt(x: 0, y: y)?.alphaComponent ?? 1) < 0.01 {
            count += 1
        }
        if (representation.colorAt(x: width - 1, y: y)?.alphaComponent ?? 1) < 0.01 {
            count += 1
        }
    }

    return count
}

private func bitmapRepresentation(for image: NSImage) throws -> NSBitmapImageRep {
    let imageSize = NSSize(width: 16, height: 16)
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(imageSize.width),
        pixelsHigh: Int(imageSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
    let bitmap = try #require(representation)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(
        in: NSRect(origin: .zero, size: imageSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.none]
    )
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
