import AppKit
import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func plainTextHighlightUsesUpstreamDefaultStyleColors() throws {
    let languageCatalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let styleCatalog = try StyleCatalog.load(from: upstreamStyleModelURL())
    let language = try #require(languageCatalog.language(named: "normal"))
    let controller = EditorWindowController(
        languageCatalog: languageCatalog,
        styleCatalog: styleCatalog
    )
    defer { controller.editorSurface.teardown() }

    controller.editorSurface.text = "Plain text"
    controller.editorSurface.applyHighlight(
        language: language,
        styleCatalog: styleCatalog,
        stylePreferences: .empty,
        highlighter: SyntaxHighlighter()
    )

    let segments = controller.editorSurface.styledSegments(ofSelection: NSRange(location: 0, length: 5))
    let segment = try #require(segments.first)

    #expect(segment.foreColor == 0x000000)
    #expect(segment.backColor == 0xFFFFFF)
}

@MainActor
@Test func scintillaTextSetterReplacesTextThroughBytePath() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }

    controller.editorSurface.text = "before\0中间\nafter"

    #expect(controller.editorSurface.text == "before\0中间\nafter")
    #expect(controller.editorSurface.documentByteCount == "before\0中间\nafter".utf8.count)

    controller.editorSurface.text = ""

    #expect(controller.editorSurface.text == "")
    #expect(controller.editorSurface.documentByteCount == 0)
}

@MainActor
@Test func scintillaDirectUTF8DataLoadPreservesBytesAndSkipsBOM() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }

    let text = "before\0中间\nafter"
    let data = Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    controller.editorSurface.replaceText(withUTF8Data: data, contentOffset: 3)

    #expect(controller.editorSurface.text == text)
    #expect(controller.editorSurface.documentByteCount == text.utf8.count)
}

@MainActor
@Test func editorWindowOpensLargeUTF8FileThroughDirectDataPath() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let defaultsName = "test.largeUTF8Open.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: defaultsName))
    defer { defaults.removePersistentDomain(forName: defaultsName) }
    let preferencesStore = PreferencesStore(defaults: defaults)
    preferencesStore.save(AppPreferences(largeFileSizeMB: 1))

    let line = "直接打开 UTF-8 large file\r\n"
    let text = String(repeating: line, count: 50_000)
    let fileURL = directory.appending(path: "large.log")
    try (Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)).write(to: fileURL)

    let controller = try EditorWindowController(
        fileURL: fileURL,
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL()),
        preferencesStore: preferencesStore
    )
    defer { controller.editorSurface.teardown() }

    #expect(controller.editorSurface.documentByteCount == text.utf8.count)
    #expect(controller.documentEncoding == .utf8)
    #expect(controller.lineEndingDisplayName == "CRLF")
}

@MainActor
@Test func scintillaNativeFindSelectsLargeDocumentMatchesWithWrapAndUnicode() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }
    guard controller.editorSurface is ScintillaEditorSurface else { return }

    let prefix = String(repeating: "普通日志行\n", count: 100_000)
    let target = "目标🚀value"
    controller.editorSurface.text = prefix + target + "\n尾部"
    controller.editorSurface.setSelectedRange(NSRange(location: 0, length: 0))

    #expect(controller.performFind(
        query: target,
        options: TextSearch.Options(matchCase: true, wraps: false, direction: .down)
    ))
    #expect(controller.editorSurface.selectedRange == NSRange(
        location: prefix.utf16.count,
        length: target.utf16.count
    ))
    #expect(controller.editorSurface.selectedLineCount == 1)

    #expect(controller.performFind(
        query: target,
        options: TextSearch.Options(matchCase: true, wraps: true, direction: .down)
    ))
    #expect(controller.editorSurface.selectedRange.location == prefix.utf16.count)

    let words = "Cat scatter\ncat CAT"
    controller.editorSurface.text = words
    controller.editorSurface.setSelectedRange(NSRange(location: words.utf16.count, length: 0))
    #expect(controller.performFind(
        query: "cat",
        options: TextSearch.Options(
            matchCase: false,
            wholeWord: true,
            wraps: false,
            direction: .up
        )
    ))
    #expect(controller.editorSurface.selectedRange == (words as NSString).range(of: "CAT"))

    let scopedMatch = (words as NSString).range(of: "cat", options: [], range: NSRange(location: 4, length: 11))
    controller.editorSurface.setSelectedRange(NSRange(location: 0, length: 0))
    #expect(controller.performFind(
        query: "cat",
        options: TextSearch.Options(
            matchCase: true,
            wraps: false,
            direction: .down,
            searchRange: NSRange(location: 4, length: 11)
        )
    ))
    #expect(controller.editorSurface.selectedRange == scopedMatch)

    controller.editorSurface.setSelectedRange(NSRange(location: 0, length: words.utf16.count))
    #expect(controller.editorSurface.selectedLineCount == 2)
}

@MainActor
@Test func scintillaJavascriptLanguageSwitchAfterEditingReturns() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }

    controller.editorSurface.text = "const answer = 42\nfunction show() { return answer }\n"
    controller.setLanguage(named: "javascript")

    #expect(controller.languageDisplayName.lowercased() == "javascript")
    #expect(controller.editorSurface.text.contains("function show"))
}

@MainActor
@Test func scintillaRawNativeTextChangeNotificationIsIgnored() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }

    NotificationCenter.default.post(
        name: NSText.didChangeNotification,
        object: controller.editorSurface.notificationObject
    )

    #expect(!controller.hasUnsavedChanges)

    NotificationCenter.default.post(
        name: NSText.didChangeNotification,
        object: controller.editorSurface.notificationObject,
        userInfo: [EditorSurfaceNotificationKey.programmaticTextChange: false]
    )

    #expect(controller.hasUnsavedChanges)
}

@MainActor
@Test func scintillaXmlFoldStaysCollapsedAfterEditingAndAutoCloseInsertion() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }

    controller.editorSurface.text = "<root>\n  <child>value</child>\n</root>\n"
    controller.setLanguage(named: "xml")
    #expect(controller.editorSurface.toggleFold(atLine: 1))
    #expect(controller.editorSurface.foldState.isCollapsed(line: 1))

    NotificationCenter.default.post(
        name: NSText.didChangeNotification,
        object: controller.editorSurface.notificationObject,
        userInfo: [EditorSurfaceNotificationKey.programmaticTextChange: false]
    )

    #expect(controller.editorSurface.foldState.isCollapsed(line: 1))

    controller.editorSurface.setSelectedRange(NSRange(location: controller.editorSurface.text.utf16.count, length: 0))
    controller.editorSurface.insertAutoPairClose("</tail>")

    #expect(controller.editorSurface.foldState.isCollapsed(line: 1))
}

@MainActor
@Test func fallbackXmlHighlightUsesUpstreamStringColor() throws {
    let languageCatalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let language = try #require(languageCatalog.language(named: "xml"))
    let textView = NSTextView()
    textView.string = #"<root attr="value">text</root>"#

    SyntaxHighlighter().apply(language: language, to: textView)

    let storage = try #require(textView.textStorage)
    let valueRange = (textView.string as NSString).range(of: #""value""#)
    let color = try #require(storage.attribute(.foregroundColor, at: valueRange.location, effectiveRange: nil) as? NSColor)

    #expect(rgbValue(of: color) == 0x8000FF)
}

@Test func foldMarginBoxTreeShowsNestedXmlHeaderMarkers() {
    let symbols = foldMarginSymbols(for: FoldMarginStyle.box.rawValue)

    #expect(symbols[25] == 13)
    #expect(symbols[26] == 15)
    #expect(symbols[27] == 11)
}

@Test func foldMarginArrowStyleKeepsUpstreamEmptyNestedMarkers() {
    let symbols = foldMarginSymbols(for: FoldMarginStyle.arrow.rawValue)

    #expect(symbols[25] == 5)
    #expect(symbols[26] == 5)
    #expect(symbols[27] == 5)
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

private func rgbValue(of color: NSColor) -> Int? {
    guard let converted = color.usingColorSpace(.sRGB) else {
        return nil
    }
    let red = Int(round(converted.redComponent * 255))
    let green = Int(round(converted.greenComponent * 255))
    let blue = Int(round(converted.blueComponent * 255))
    return (red << 16) | (green << 8) | blue
}

private func foldMarginSymbols(for style: Int) -> [Int: Int] {
    Dictionary(
        uniqueKeysWithValues: ScintillaFoldMarginMarkerStyle
            .symbols(forRawValue: style)
            .map { (Int($0.markerNumber), Int($0.symbol)) }
    )
}

// MARK: - Smart highlight trigger conditions

/// Drives the controller's private selection-changed path by posting the same
/// SCIUpdateUI notification Scintilla emits on selection change.
@MainActor
private func postSCIUpdateUI(on controller: EditorWindowController) {
    NotificationCenter.default.post(
        name: Notification.Name("SCIUpdateUI"),
        object: controller.editorSurface.notificationObject
    )
}

@MainActor
@Test func smartHighlightOnlyAppliesWhenSelectionExists() throws {
    let controller = EditorWindowController(
        languageCatalog: try LanguageCatalog.load(from: upstreamLanguageModelURL()),
        styleCatalog: try StyleCatalog.load(from: upstreamStyleModelURL())
    )
    defer { controller.editorSurface.teardown() }

    // Document with the token "foo" appearing twice.
    controller.editorSurface.text = "foo bar foo"

    // 1) Bare caret move (no selection) must NOT highlight the word under the
    //    caret — mirrors upstream SmartHighlighter::highlightView, which clears
    //    and returns when SCI_GETSELECTIONEMPTY.
    controller.editorSurface.setSelectedRange(NSRange(location: 0, length: 0))
    postSCIUpdateUI(on: controller)
    #expect(controller.editorSurface.hasSmartHighlightApplied == false)

    // 2) Double-click-style selection of the first "foo" highlights occurrences.
    controller.editorSurface.setSelectedRange(NSRange(location: 0, length: 3))
    postSCIUpdateUI(on: controller)
    #expect(controller.editorSurface.hasSmartHighlightApplied == true)

    // 3) Collapsing the selection back to a caret clears the highlight again.
    controller.editorSurface.setSelectedRange(NSRange(location: 0, length: 0))
    postSCIUpdateUI(on: controller)
    #expect(controller.editorSurface.hasSmartHighlightApplied == false)
}
