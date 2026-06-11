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
