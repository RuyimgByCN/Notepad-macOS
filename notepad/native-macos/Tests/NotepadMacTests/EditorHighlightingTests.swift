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
        .deletingLastPathComponent()
        .appending(path: "notepad-plus-plus/PowerEditor/src/langs.model.xml")
}

private func upstreamStyleModelURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "notepad-plus-plus/PowerEditor/src/stylers.model.xml")
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
