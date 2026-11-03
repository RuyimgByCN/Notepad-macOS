import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func tabsReuseOneNativeWindowAndKeepIndependentEditingState() throws {
    let presenter = EditorWindowPresenter()
    let first = EditorWindowController(untitledDisplayName: "First", usesSharedWindow: true)
    let second = EditorWindowController(untitledDisplayName: "Second", usesSharedWindow: true)
    let firstSurface = first.editorSurface
    firstSurface.text = "first document\nsecond line"
    firstSurface.setSelectedRange(NSRange(location: 6, length: 8))
    second.editorSurface.text = "other document"
    #expect(first.window == nil)
    #expect(second.window == nil)
    presenter.present(first)
    let window = try #require(first.window)
    defer {
        presenter.remove(first)
        presenter.remove(second)
        window.close()
    }

    presenter.present(first)
    let firstContent = try #require(window.contentView)
    for _ in 0..<20 {
        presenter.present(second)
        #expect(first.window == nil)
        #expect(firstSurface.view.window == nil)
        #expect(second.window === window)
        #expect(window.windowController === second)
        #expect(window.delegate === second)
        #expect(window.title.contains("Second"))
        presenter.present(first)
    }

    #expect(second.window == nil)
    #expect(window.contentView === firstContent)
    #expect(first.editorSurface === firstSurface)
    #expect(firstSurface.text == "first document\nsecond line")
    #expect(firstSurface.selectedRange == NSRange(location: 6, length: 8))
    #expect(second.editorSurface.text == "other document")
    #expect(window.title.contains("First"))
}

@MainActor
@Test func closingBackgroundTabDoesNotCloseSharedWindow() throws {
    let presenter = EditorWindowPresenter()
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    presenter.present(first)
    presenter.present(second)
    let window = try #require(second.window)
    defer { presenter.remove(second); window.close() }
    var closeCount = 0
    first.onClose = { closeCount += 1; presenter.remove(first) }

    first.close()
    first.close()

    #expect(closeCount == 1)
    #expect(presenter.activeController === second)
    #expect(second.window === window)
    #expect(window.contentView != nil)
}

@MainActor
@Test func closingActiveTabTransfersWindowToNextDocument() throws {
    let presenter = EditorWindowPresenter()
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    presenter.present(first)
    let window = try #require(first.window)
    defer { presenter.remove(second); window.close() }
    first.onClose = {
        presenter.present(second)
        presenter.remove(first)
    }

    first.closeDocumentTab()

    #expect(first.window == nil)
    #expect(second.window === window)
    #expect(presenter.activeController === second)
    #expect(window.isVisible)
}

@MainActor
@Test func clonedPaneSurvivesWindowReuse() throws {
    let presenter = EditorWindowPresenter()
    let first = EditorWindowController(usesSharedWindow: true)
    guard first.editorSurface.documentPointer != nil else { return }
    let second = EditorWindowController(usesSharedWindow: true)
    presenter.present(first)
    let window = try #require(first.window)
    defer { first.closeDocumentTab(); presenter.remove(first); presenter.remove(second); window.close() }
    first.editorSurface.text = "shared buffer"
    first.toggleCloneToOtherView(nil)
    let clone = try #require(first.clonedSurface)
    window.makeFirstResponder(clone.firstResponder)

    presenter.present(second)
    #expect(clone.view.window == nil)
    presenter.present(first)

    #expect(first.clonedSurface === clone)
    #expect(clone.documentPointer == first.editorSurface.documentPointer)
    #expect(clone.view.window === window)
    #expect(clone.text == "shared buffer")
    #expect(window.firstResponder === clone.firstResponder)
}

@MainActor
@Test func undoHistoryAndScrollPositionSurviveTabSwitches() throws {
    let presenter = EditorWindowPresenter()
    let first = EditorWindowController(usesSharedWindow: true)
    guard first.editorSurface.documentPointer != nil else { return }
    let second = EditorWindowController(usesSharedWindow: true)
    presenter.present(first)
    let window = try #require(first.window)
    defer { presenter.remove(first); presenter.remove(second); window.close() }
    let original = (0..<200).map { "line \($0)" }.joined(separator: "\n")
    first.editorSurface.text = original
    first.editorSurface.setSelectedRange(NSRange(location: 4, length: 1))
    first.delete(nil)
    let edited = first.editorSurface.text
    #expect(edited != original)
    first.editorSurface.restoreViewPosition(EditorViewPosition(
        selectedRange: first.editorSurface.selectedRange, firstVisibleLine: 50
    ))
    let position = first.editorSurface.captureViewPosition()

    presenter.present(second)
    second.editorSurface.text = "another buffer"
    presenter.present(first)

    #expect(first.editorSurface.text == edited)
    #expect(first.editorSurface.captureViewPosition().firstVisibleLine == position.firstVisibleLine)
    #expect(first.editorSurface.selectedRange == position.selectedRange)
    let contentView = try #require(allSubviews(first.editorSurface.view).first {
        NSStringFromClass(type(of: $0)).contains("SCIContentView")
    })
    #expect(contentView.tryToPerform(Selector(("undo:")), with: nil))
    #expect(first.editorSurface.text == original)
    #expect(second.editorSurface.text == "another buffer")
}

@MainActor
@Test func movedDocumentCanBeClosedWhileItsOwnWindowIsDetached() throws {
    let presenter = EditorWindowPresenter()
    let host = EditorWindowController(usesSharedWindow: true)
    let other = EditorWindowController(usesSharedWindow: true)
    guard host.editorSurface.documentPointer != nil else { return }
    presenter.present(other)
    let window = try #require(other.window)
    defer { presenter.remove(host); window.close() }
    other.editorSurface.text = "second pane"
    #expect(host.hostDocumentInOtherView(from: other))
    presenter.present(host)
    host.focusHostedPane()

    #expect(other.window == nil)
    #expect(host.hostedSurface?.text == "second pane")
    other.closeDocumentTab()

    #expect(host.hostedSurface == nil)
    #expect(host.hostedController == nil)
    #expect(other.hostingController == nil)
    #expect(host.window === window)
    #expect(window.firstResponder === host.editorSurface.firstResponder)
}

@MainActor
private func allSubviews(_ view: NSView) -> [NSView] {
    view.subviews + view.subviews.flatMap(allSubviews)
}

@MainActor
@Test func detachedDocumentCanSaveBeforeTermination() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("document.txt")
    try "original".write(to: url, atomically: true, encoding: .utf8)
    let document = try EditorWindowController(
        fileURL: url, languageCatalog: .fallback, styleCatalog: .empty, usesSharedWindow: true
    )
    defer { document.closeDocumentTab() }
    document.editorSurface.text = "saved from detached document"

    #expect(document.window == nil)
    #expect(document.saveDocumentForTermination())
    #expect(try String(contentsOf: url, encoding: .utf8) == "saved from detached document")
    #expect(document.window == nil)
}

@MainActor
@Test func tabSwitchWaitsUntilAttachedSheetFinishes() throws {
    let presenter = EditorWindowPresenter()
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    presenter.present(first)
    let window = try #require(first.window)
    let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                        styleMask: [.titled], backing: .buffered, defer: false)
    sheet.isReleasedWhenClosed = false
    defer { presenter.remove(first); presenter.remove(second); sheet.close(); window.close() }
    window.beginSheet(sheet)

    presenter.present(second)
    #expect(presenter.activeController === first)
    #expect(first.window === window)
    #expect(second.window == nil)

    window.endSheet(sheet)
    presenter.present(second)
    #expect(presenter.activeController === second)
    #expect(second.window === window)
}
