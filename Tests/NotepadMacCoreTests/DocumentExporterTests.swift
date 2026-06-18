import XCTest
import NotepadMacCore

final class DocumentExporterTests: XCTestCase {

    // MARK: - Helper

    private func makeSegments() -> [StyledSegment] {
        [
            StyledSegment(text: "int ", foreColor: 0x0000FF, backColor: 0xFFFFFF, bold: true, italic: false),
            StyledSegment(text: "main", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
            StyledSegment(text: "() ", foreColor: 0x008000, backColor: 0xFFFFFF, bold: false, italic: false),
            StyledSegment(text: "{\n", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
            StyledSegment(text: "return", foreColor: 0x800080, backColor: 0xFFFFFF, bold: true, italic: false),
            StyledSegment(text: " 0;\n}", foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false),
        ]
    }

    // MARK: - HTML Export

    func testHTMLExportContainsStyledContent() throws {
        let segments = makeSegments()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExporterTest_HTML.html")
        try DocumentExporter.writeExport(
            segments: segments,
            format: .html,
            title: "test.cpp",
            to: url
        )
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(content.contains("<!DOCTYPE html>"))
        XCTAssertTrue(content.contains("<title>test.cpp</title>"))
        XCTAssertTrue(content.contains("<pre"))
        XCTAssertTrue(content.contains("color:#0000FF"))
        XCTAssertTrue(content.contains("font-weight:bold"))
        XCTAssertTrue(content.contains("int "))
        XCTAssertTrue(content.contains("</html>"))

        try? FileManager.default.removeItem(at: url)
    }

    func testHTMLExportEscapesSpecialCharacters() throws {
        let segments = [
            StyledSegment(text: "a < b && c > d", foreColor: 0, backColor: 0xFFFFFF, bold: false, italic: false),
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExporterTest_Escape.html")
        try DocumentExporter.writeExport(
            segments: segments,
            format: .html,
            title: "escape",
            to: url
        )
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(content.contains("&lt;"))
        XCTAssertTrue(content.contains("&amp;"))
        XCTAssertTrue(content.contains("&gt;"))
        XCTAssertFalse(content.contains("a < b && c > d")) // raw should be escaped

        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - RTF Export

    func testRTFExportContainsStyledContent() throws {
        let segments = makeSegments()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExporterTest_RTF.rtf")
        try DocumentExporter.writeExport(
            segments: segments,
            format: .rtf,
            title: "test.cpp",
            to: url
        )
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(content.hasPrefix("{\\rtf1"))
        XCTAssertTrue(content.contains("{\\fonttbl"))
        XCTAssertTrue(content.contains("{\\colortbl"))
        XCTAssertTrue(content.contains("\\b"))    // bold
        XCTAssertTrue(content.contains("int"))
        XCTAssertTrue(content.hasSuffix("}"))

        try? FileManager.default.removeItem(at: url)
    }

    func testRTFExportEscapesSpecialCharacters() throws {
        let segments = [
            StyledSegment(text: "path\\{file\\}", foreColor: 0, backColor: 0xFFFFFF, bold: false, italic: false),
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExporterTest_RTFEscape.rtf")
        try DocumentExporter.writeExport(
            segments: segments,
            format: .rtf,
            title: "rtf_escape",
            to: url
        )
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(content.contains("\\\\"))
        XCTAssertTrue(content.contains("\\{"))
        XCTAssertTrue(content.contains("\\}"))

        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Style Collection

    func testCollectStylesQueriesCorrectProperties() {
        // Mock query function: return plausible values for style 0 (default) and style 5.
        let query: (Int32, CLong) -> CLong? = { msg, param in
            if param == 0 {
                // STYLE_DEFAULT: black fore, white back, not bold, not italic
                switch msg {
                case 2481: return 0          // fore = 0x00BBGGRR(0) → bgrToRGB → 0
                case 2482: return 0xFFFFFF   // back = white (BGR=0xFFFFFF, RGB also 0xFFFFFF)
                case 2483: return 0          // not bold
                case 2484: return 0          // not italic
                default: return nil
                }
            }
            if param == 5 {
                // Style 5: red fore (BGR=0x0000FF → RGB=0xFF0000), bold
                switch msg {
                case 2481: return 0x0000FF   // BGR red → RGB will be 0xFF0000
                case 2482: return 0xFFFFFF
                case 2483: return 1          // bold
                case 2484: return 0
                default: return nil
                }
            }
            return nil
        }

        let styles = DocumentExporter.collectStyles(usedIndices: [0, 5], query: query)

        XCTAssertEqual(styles.count, 2)
        // Style 0: bgrToRGB(0) = 0 → foreColor=0
        XCTAssertEqual(styles[0]?.foreColor, 0)
        XCTAssertEqual(styles[0]?.backColor, 0xFFFFFF)
        XCTAssertEqual(styles[0]?.bold, false)

        // Style 5: bgrToRGB(0x0000FF) = 0xFF0000 → foreColor=0xFF0000
        XCTAssertEqual(styles[5]?.foreColor, 0xFF0000)
        XCTAssertEqual(styles[5]?.bold, true)
    }

    // MARK: - Styled Segment Building

    func testBuildSegmentsFromStyledBuffer() {
        // Simulate Scintilla styled buffer: 'H' style=0, 'i' style=0, '!' style=5
        // Each character + style byte = 2 bytes per char
        let buffer: [UInt8] = [
            72, 0,   // 'H' style 0
            105, 0,  // 'i' style 0
            33, 5,   // '!' style 5
            0, 0,    // NUL terminator
        ]
        let styleInfo: [Int: DocumentExporter.ScintillaStyleInfo] = [
            0: .init(foreColor: 0, backColor: 0xFFFFFF, bold: false, italic: false),
            5: .init(foreColor: 0xFF0000, backColor: 0xFFFFFF, bold: true, italic: false),
        ]

        let segments = DocumentExporter.buildSegments(styledBuffer: buffer, styleInfo: styleInfo)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "Hi")
        XCTAssertEqual(segments[0].foreColor, 0)
        XCTAssertEqual(segments[1].text, "!")
        XCTAssertEqual(segments[1].foreColor, 0xFF0000)
        XCTAssertEqual(segments[1].bold, true)
    }

    func testBuildSegmentsEmptyBufferReturnsEmpty() {
        let segments = DocumentExporter.buildSegments(styledBuffer: [], styleInfo: [:])
        XCTAssertEqual(segments.count, 0)
    }

    // MARK: - Format enum

    func testFormatAllCases() {
        XCTAssertEqual(DocumentExporter.Format.allCases.count, 2)
        XCTAssertEqual(DocumentExporter.Format.html.rawValue, "html")
        XCTAssertEqual(DocumentExporter.Format.rtf.rawValue, "rtf")
    }
}
