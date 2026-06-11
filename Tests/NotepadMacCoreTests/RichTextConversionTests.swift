import Testing
import Foundation
@testable import NotepadMacCore

@Suite("RichTextConversion Tests")
struct RichTextConversionTests {

    // MARK: - Colour conversion

    @Test("bgrToRGB converts Scintilla BGR to RGB")
    func bgrToRGB() {
        // Scintilla: 0x00BBGGRR → 0x00RRGGBB
        // Red only (Scintilla 0x000000FF)
        #expect(RichTextConversion.bgrToRGB(0x000000FF) == 0x00FF0000)
        // Green only (Scintilla 0x0000FF00)
        #expect(RichTextConversion.bgrToRGB(0x0000FF00) == 0x0000FF00)
        // Blue only (Scintilla 0x00FF0000)
        #expect(RichTextConversion.bgrToRGB(0x00FF0000) == 0x000000FF)
        // White (0x00FFFFFF in both)
        #expect(RichTextConversion.bgrToRGB(0x00FFFFFF) == 0x00FFFFFF)
        // Black
        #expect(RichTextConversion.bgrToRGB(0) == 0)
    }

    @Test("hexColor formats 0xRRGGBB as 6-digit hex")
    func hexColor() {
        #expect(RichTextConversion.hexColor(0xFF0000) == "FF0000")
        #expect(RichTextConversion.hexColor(0x00FF00) == "00FF00")
        #expect(RichTextConversion.hexColor(0x0000FF) == "0000FF")
        #expect(RichTextConversion.hexColor(0) == "000000")
        #expect(RichTextConversion.hexColor(0xABCDEF) == "ABCDEF")
    }

    // MARK: - HTML escape

    @Test("htmlEscape escapes special HTML characters")
    func htmlEscape() {
        #expect(RichTextConversion.htmlEscape("a & b") == "a &amp; b")
        #expect(RichTextConversion.htmlEscape("<tag>") == "&lt;tag&gt;")
        #expect(RichTextConversion.htmlEscape("x = \"1\"") == "x = &quot;1&quot;")
        #expect(RichTextConversion.htmlEscape("no special") == "no special")
        #expect(RichTextConversion.htmlEscape("&<>\"") == "&amp;&lt;&gt;&quot;")
    }

    // MARK: - RTF escape

    @Test("rtfEscape escapes RTF special characters")
    func rtfEscape() {
        #expect(RichTextConversion.rtfEscape("a\\b") == "a\\\\b")
        #expect(RichTextConversion.rtfEscape("{x}") == "\\{x\\}")
        #expect(RichTextConversion.rtfEscape("line1\nline2") == "line1\\line line2")
        #expect(RichTextConversion.rtfEscape("no special") == "no special")
    }

    @Test("rtfEscape encodes non-ASCII as Unicode escapes")
    func rtfEscapeUnicode() {
        // é (U+00E9) → \u233?
        #expect(RichTextConversion.rtfEscape("café") == "caf\\u233?")
        // 中 (U+4E2D) →  3?
        #expect(RichTextConversion.rtfEscape("中") == "\\u20013?")
    }

    @Test("rtfEscape ignores CR in CRLF")
    func rtfEscapeCRLF() {
        #expect(RichTextConversion.rtfEscape("a\r\nb") == "a\\line b")
    }

    // MARK: - HTML generation

    @Test("htmlFromSegments generates correct HTML")
    func htmlFromSegments() {
        let segments = [
            StyledSegment(text: "hello", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
            StyledSegment(text: "world", foreColor: 0x0000FF, backColor: 0xFFFFFF, bold: true, italic: false),
        ]
        let html = RichTextConversion.htmlFromSegments(segments)
        #expect(html.contains("<pre"))
        #expect(html.contains("color:#000000"))
        #expect(html.contains("color:#0000FF"))
        #expect(html.contains("font-weight:bold"))
        #expect(html.contains("hello"))
        #expect(html.contains("world"))
    }

    @Test("htmlFromSegments escapes text content")
    func htmlFromSegmentsEscapes() {
        let segments = [
            StyledSegment(text: "a & b", foreColor: 0, backColor: 0xFFFFFF, bold: false, italic: false),
        ]
        let html = RichTextConversion.htmlFromSegments(segments)
        #expect(html.contains("a &amp; b"))
        #expect(!html.contains("a & b</span>"))
    }

    // MARK: - RTF generation

    @Test("rtfFromSegments generates valid RTF structure")
    func rtfFromSegments() {
        let segments = [
            StyledSegment(text: "plain", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
            StyledSegment(text: "bold", foreColor: 0xFF0000, backColor: 0xFFFFFF, bold: true, italic: false),
        ]
        let rtf = RichTextConversion.rtfFromSegments(segments)
        #expect(rtf.hasPrefix("{\\rtf1"))
        #expect(rtf.contains("\\colortbl;"))
        #expect(rtf.contains("\\b "))
        #expect(rtf.contains("\\b0 "))
        #expect(rtf.contains("plain"))
        #expect(rtf.contains("bold"))
    }

    @Test("rtfFromSegments builds shared colour table")
    func rtfFromSegmentsSharedColours() {
        let segments = [
            StyledSegment(text: "a", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
            StyledSegment(text: "b", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
        ]
        let rtf = RichTextConversion.rtfFromSegments(segments)
        // Both segments share the same fore + back, so colour table has only 2 entries.
        // Count \red occurrences to verify.
        let redCount = rtf.components(separatedBy: "\\red").count - 1
        #expect(redCount == 2)
    }
}
