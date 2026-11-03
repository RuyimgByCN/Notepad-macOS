import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func pooledTabsReuseOneDrawingViewDuringBackgroundAccess() throws {
    let documents = (0..<14).map { _ in EditorWindowController(usesSharedWindow: true) }
    let presenter = EditorWindowPresenter()
    defer {
        documents.forEach { presenter.remove($0); $0.closeDocumentTab() }
        presenter.window?.close()
    }
    for (index, document) in documents.enumerated() { document.editorSurface.text = "document \(index)" }
    presenter.present(documents[0])
    let first = try #require(documents[0].editorSurface as? ScintillaEditorSurface)
    let drawingView = try #require(first.presentationBackend?.view)

    for _ in 0..<3 {
        for (index, document) in documents.enumerated() {
            presenter.present(document)
            let active = try #require(document.editorSurface as? ScintillaEditorSurface)
            #expect(active.presentationBackend?.view === drawingView)
            #expect(documents.filter { ($0.editorSurface as? ScintillaEditorSurface)?.presentationBackend != nil }.count == 1)
            #expect(active.text == "document \(index)")
            for (otherIndex, background) in documents.enumerated() where background !== document {
                #expect(background.editorSurface.text == "document \(otherIndex)")
                _ = background.editorSurface.selectedRange
            }
            #expect(active.presentationBackend?.view === drawingView)
            #expect(active.text == "document \(index)")
        }
    }
}

@MainActor
@Test func pooledViewOptionsAndMultipleSelectionsBelongToEachDocument() throws {
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    first.editorSurface.text = "one two three"
    first.editorSurface.applyCaretWidth(3)
    first.editorSurface.applyShowWhitespace(mode: 2)
    first.editorSurface.applyUrlHighlights(ranges: [NSRange(location: 0, length: 3)], style: 2)
    #expect(first.editorSurface.applyDiscontiguousSelections([
        NSRange(location: 0, length: 3), NSRange(location: 8, length: 5)
    ], mainSelectionIndex: 1))
    second.editorSurface.text = "unrelated"
    second.editorSurface.applyCaretWidth(1)
    second.editorSurface.applyShowWhitespace(mode: 0)
    let surface = try #require(first.editorSurface as? ScintillaEditorSurface)

    for _ in 0..<3 {
        presenter.present(second)
        #expect(second.editorSurface.selectionCount == 1)
        presenter.present(first)
        let backend = try #require(surface.presentationBackend)
        #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getCaretWidth, parameter: 0) == 3)
        #expect(backend.bridge.getGeneralProperty(2020, parameter: 0) == 2)
        #expect(first.editorSurface.selectionCount == 2)
        #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getMainSelection, parameter: 0) == 1)
        #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getSelectionNCaret, parameter: 1) == 13)
        #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getSelectionNAnchor, parameter: 1) == 8)
        #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getMultipleSelection, parameter: 0) == 1)
        #expect(backend.bridge.getGeneralProperty(2081, parameter: 12) == 16)
    }
}

@MainActor
@Test func pooledFoldsAndManuallyHiddenLinesSurviveViewReuse() throws {
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    first.editorSurface.text = (0..<10).map { "line \($0)" }.joined(separator: "\n")
    second.editorSurface.text = first.editorSurface.text
    presenter.present(first)
    let surface = try #require(first.editorSurface as? ScintillaEditorSurface)
    let backend = try #require(surface.presentationBackend)
    backend.bridge.setGeneralProperty(2222, parameter: 0, value: 0x2400)
    backend.bridge.setGeneralProperty(2222, parameter: 1, value: 0x401)
    backend.bridge.setGeneralProperty(2222, parameter: 2, value: 0x400)
    #expect(first.editorSurface.toggleFold(atLine: 1))
    first.editorSurface.hideLines(6...7)
    #expect(first.editorSurface.isLineHidden(2))

    presenter.present(second)
    #expect(!second.editorSurface.isLineHidden(2))
    #expect(!second.editorSurface.isLineHidden(6))
    presenter.present(first)

    #expect(first.editorSurface.foldState.collapsedLines.contains(1))
    #expect(first.editorSurface.isLineHidden(2))
    #expect(first.editorSurface.isLineHidden(6))
    #expect(first.editorSurface.isLineHidden(7))
}

@MainActor
@Test func pooledCloneEditsInvalidateParkedDocumentCopies() throws {
    let source = try #require(ScintillaEditorSurface.load(pooled: true))
    let clone = try #require(ScintillaEditorSurface.load(pooled: true))
    defer { source.teardown(); clone.teardown() }
    source.text = "abc"
    #expect(clone.setDocumentPointer(try #require(source.documentPointer)))
    #expect(source.text == "abc")
    clone.setSelectedRange(NSRange(location: 1, length: 1))
    clone.deleteSelection()
    #expect(source.text == "ac")

    source.teardown()
    #expect(clone.text == "ac")
    clone.setSelectedRange(NSRange(location: 0, length: 1))
    clone.deleteSelection()
    #expect(clone.text == "c")
}

@MainActor
@Test func retiredSurfaceCallbacksCannotEditReassignedDrawingView() throws {
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    first.editorSurface.text = "closed document"
    presenter.present(first)
    first.closeDocumentTab()
    second.editorSurface.text = "keep this text"
    presenter.present(second)

    first.editorSurface.deleteSelection()
    first.editorSurface.applyUrlHighlights(ranges: [], style: 0)
    first.editorSurface.text = "late callback"

    #expect(first.editorSurface.documentPointer == nil)
    #expect(second.editorSurface.text == "keep this text")
    #expect(second.window === presenter.window)
}

@MainActor
@Test func pooledRectangleSelectionRetainsVirtualSpaceAndOrientation() throws {
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    first.editorSurface.text = "ab\nc\ndef"
    let selection = RectangularSelectionLiveMetadata(
        anchorUTF16Location: 2, caretUTF16Location: 4,
        anchorVirtualSpace: 3, caretVirtualSpace: 2
    )
    #expect(first.editorSurface.applyRectangularSelection(selection))
    let expected = first.editorSurface.liveRectangularSelection
    #expect(expected != nil)

    presenter.present(first)
    presenter.present(second)
    presenter.present(first)

    #expect(first.editorSurface.liveRectangularSelection == expected)
}

@MainActor
@Test func fallbackDocumentsKeepIndependentUndoManagersWhenSharingWindow() {
    let first = TextViewEditorSurface()
    let second = TextViewEditorSurface()
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
                          styleMask: [.borderless], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    defer { window.contentView = nil; window.close() }
    window.contentView = first.view
    first.textView.insertText("first", replacementRange: NSRange(location: 0, length: 0))
    window.contentView = second.view
    second.textView.insertText("second", replacementRange: NSRange(location: 0, length: 0))

    #expect(first.textView.undoManager !== second.textView.undoManager)
    first.textView.undoManager?.undo()

    #expect(first.text == "")
    #expect(second.text == "second")
}

@MainActor
@Test func pooledHorizontalScrollAndNativeZoomDoNotLeakBetweenDocuments() throws {
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    first.editorSurface.text = String(repeating: "long line ", count: 200)
    second.editorSurface.text = "short"
    presenter.present(first)
    let surface = try #require(first.editorSurface as? ScintillaEditorSurface)
    let backend = try #require(surface.presentationBackend)
    backend.bridge.setGeneralProperty(ScintillaMessage.setZoom, parameter: 3, value: 0)
    backend.bridge.setGeneralProperty(ScintillaMessage.setScrollWidth, parameter: 20000, value: 0)
    backend.bridge.setGeneralProperty(ScintillaMessage.setXOffset, parameter: 300, value: 0)
    let offset = backend.bridge.getGeneralProperty(ScintillaMessage.getXOffset, parameter: 0)
    #expect(offset == 300)

    presenter.present(second)
    let other = try #require((second.editorSurface as? ScintillaEditorSurface)?.presentationBackend)
    #expect(other.bridge.getGeneralProperty(ScintillaMessage.getZoom, parameter: 0) == 0)
    #expect(other.bridge.getGeneralProperty(ScintillaMessage.getXOffset, parameter: 0) == 0)
    presenter.present(first)

    #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getZoom, parameter: 0) == 3)
    #expect(backend.bridge.getGeneralProperty(ScintillaMessage.getXOffset, parameter: 0) == offset)
}
