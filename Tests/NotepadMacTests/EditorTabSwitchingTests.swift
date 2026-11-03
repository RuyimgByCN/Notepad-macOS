import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test(arguments: [false, true])
func pooledScrolledCaretSurvivesPaintAndShortDocumentSwitch(wrapsLines: Bool) async throws {
    let suite = "EditorTabSwitchingTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = PreferencesStore(defaults: defaults)
    preferences.save(AppPreferences().withWrapsLines(wrapsLines))
    let first = EditorWindowController(preferencesStore: preferences, usesSharedWindow: true)
    let second = EditorWindowController(preferencesStore: preferences, usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    let line = String(repeating: "中文 🚀 example ", count: 12) + "\n"
    first.editorSurface.text = String(repeating: line, count: 500)
    second.editorSurface.text = "short document"
    presenter.present(first)
    let surface = try #require(first.editorSurface as? ScintillaEditorSurface)
    let backend = try #require(surface.presentationBackend)
    let scroll = try #require(backend.view.subviews.compactMap { $0 as? NSScrollView }.first)
    first.editorSurface.setSelectedRange(NSRange(location: line.utf16.count * 200 + 5, length: 0))
    first.editorSurface.restoreViewPosition(EditorViewPosition(
        selectedRange: first.editorSurface.selectedRange, firstVisibleLine: 190
    ))
    try await Task.sleep(for: .milliseconds(30))
    if wrapsLines {
        backend.bridge.setGeneralProperty(ScintillaMessage.scrollVertical, parameter: 100, value: 1)
        try await Task.sleep(for: .milliseconds(30))
        backend.bridge.setGeneralProperty(ScintillaMessage.scrollVertical, parameter: 100, value: 1)
        try await Task.sleep(for: .milliseconds(30))
    }
    let expected = first.editorSurface.captureViewPosition()
    let expectedDocumentLine = backend.bridge.getGeneralProperty(ScintillaMessage.docLineFromVisible, parameter: expected.firstVisibleLine)
    func visibleDocumentLine() -> Int? {
        let current = ScintillaDynamicBridge(target: surface.scintillaView)
        let visible = current.getGeneralProperty(ScintillaMessage.getFirstVisibleLine, parameter: 0) ?? 0
        return current.getGeneralProperty(ScintillaMessage.docLineFromVisible, parameter: visible)
    }
    let expectedOrigin = scroll.contentView.bounds.origin
    let expectedSubLine = expected.firstVisibleLine - (backend.bridge.getGeneralProperty(ScintillaMessage.visibleFromDocLine, parameter: expectedDocumentLine ?? 0) ?? 0)
    if wrapsLines { #expect(expectedSubLine == 1) }
    #expect(expectedOrigin.y > 0)
    if !wrapsLines { #expect(expected.firstVisibleLine == 190) }
    // SCI_GETSELECTIONHIDDEN: restoring the viewport must leave the caret visible.
    #expect(backend.bridge.getGeneralProperty(2088, parameter: 0) == 0)

    for _ in 0..<3 {
        presenter.present(second)
        try await Task.sleep(for: .milliseconds(30))
        #expect(surface.parkedViewState.firstVisibleDocumentLine == expectedDocumentLine)
        _ = first.editorSurface.selectedRange
        #expect(visibleDocumentLine() == expectedDocumentLine)
        _ = second.editorSurface.selectedRange
        presenter.present(first)
        #expect(surface.parkedViewState.firstVisibleDocumentLine == expectedDocumentLine)
        try await Task.sleep(for: .milliseconds(30))
        #expect(first.editorSurface.selectedRange == expected.selectedRange)
        #expect(visibleDocumentLine() == expectedDocumentLine)
        let currentVisible = backend.bridge.getGeneralProperty(ScintillaMessage.getFirstVisibleLine, parameter: 0) ?? 0
        let currentBase = backend.bridge.getGeneralProperty(ScintillaMessage.visibleFromDocLine, parameter: expectedDocumentLine ?? 0) ?? 0
        #expect(currentVisible - currentBase == expectedSubLine)
        if !wrapsLines {
            #expect(first.editorSurface.captureViewPosition().firstVisibleLine == expected.firstVisibleLine)
            #expect(scroll.contentView.bounds.origin == expectedOrigin)
        }
        #expect(backend.bridge.getGeneralProperty(2088, parameter: 0) == 0)
    }
}

@MainActor
@Test func pooledCaretRestoredBeforePresentationScrollsIntoView() async throws {
    let first = EditorWindowController(usesSharedWindow: true)
    let second = EditorWindowController(usesSharedWindow: true)
    let presenter = EditorWindowPresenter()
    defer {
        presenter.remove(first); presenter.remove(second)
        first.closeDocumentTab(); second.closeDocumentTab(); presenter.window?.close()
    }
    let line = "restore caret 中文 🚀\n"
    first.editorSurface.text = String(repeating: line, count: 500)
    let caret = line.utf16.count * 200 + 5
    first.restoreCaretPosition(caret)
    _ = second.editorSurface.selectedRange
    presenter.present(first)
    try await Task.sleep(for: .milliseconds(30))
    let surface = try #require(first.editorSurface as? ScintillaEditorSurface)
    let backend = try #require(surface.presentationBackend)
    #expect(first.editorSurface.selectedRange == NSRange(location: caret, length: 0))
    let top = backend.bridge.getGeneralProperty(ScintillaMessage.getFirstVisibleLine, parameter: 0) ?? 0
    let lines = backend.bridge.getGeneralProperty(ScintillaMessage.linesOnScreen, parameter: 0) ?? 0
    #expect(top > 0)
    #expect(top <= 200 && top + lines > 200)
    #expect(backend.bridge.getGeneralProperty(2088, parameter: 0) == 0)
}
