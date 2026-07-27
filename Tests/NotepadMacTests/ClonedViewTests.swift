import AppKit
import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func textViewSurfaceReportsNoDocumentSharingSupport() {
    let surface = TextViewEditorSurface()

    #expect(surface.documentPointer == nil)
    #expect(surface.setDocumentPointer(0x1234) == false)
    // Detaching must be a safe no-op on the fallback surface.
    surface.detachFromSharedDocument()
}

@MainActor
@Test func editorWindowControllerExposesDualViewCommands() {
    // The selectors must exist for the View menu items to validate/dispatch.
    #expect(EditorWindowController.instancesRespond(to: #selector(EditorWindowController.toggleCloneToOtherView(_:))))
    #expect(EditorWindowController.instancesRespond(to: #selector(EditorWindowController.focusOtherView(_:))))
}

@MainActor
@Test func scintillaClickPastLineEndClampsToLineEnd() throws {
    guard let surface = ScintillaEditorSurface.load() else { return }
    defer { surface.teardown() }

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = surface.view
    surface.view.frame = window.contentView?.bounds ?? .zero
    surface.text = "abc\nsecond line"
    surface.applyVirtualSpace(true)

    let contentView = try #require(descendants(of: surface.view).first {
        NSStringFromClass(type(of: $0)).contains("SCIContentView")
    })
    let clickPoint = contentView.convert(NSPoint(x: 300, y: 8), to: nil)
    let event = try #require(NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: clickPoint,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    ))

    contentView.mouseDown(with: event)

    #expect(surface.selectedRange == NSRange(location: 3, length: 0))
}

@MainActor
private func descendants(of view: NSView) -> [NSView] {
    view.subviews + view.subviews.flatMap(descendants)
}
