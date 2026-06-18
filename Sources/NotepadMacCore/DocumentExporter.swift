import Foundation

/// Exports the current document (or selection) to HTML or RTF files,
/// preserving syntax-highlighting colours from Scintilla.
public enum DocumentExporter {

    public enum Format: String, CaseIterable {
        case html
        case rtf
    }

    /// Style information for one Scintilla style index.
    public struct ScintillaStyleInfo: Equatable {
        public let foreColor: Int   // 0xRRGGBB
        public let backColor: Int   // 0xRRGGBB
        public let bold: Bool
        public let italic: Bool

        public init(foreColor: Int, backColor: Int, bold: Bool, italic: Bool) {
            self.foreColor = foreColor
            self.backColor = backColor
            self.italic = italic
            self.bold = bold
        }
    }

    /// Fetch style information for all used style indices via a
    /// Scintilla-style property-query closure.
    ///
    /// The closure receives (messageID: Int32, styleIndex: CLong) and
    /// returns the Scintilla result as CLong, mirroring
    /// `ScintillaDynamicBridge.getGeneralProperty`.
    public static func collectStyles(
        usedIndices: Set<Int>,
        query: (_ message: Int32, _ parameter: CLong) -> CLong?
    ) -> [Int: ScintillaStyleInfo] {
        var result: [Int: ScintillaStyleInfo] = [:]
        for idx in usedIndices {
            let rawFore = Int(query(2481, CLong(idx)) ?? 0)  // SCI_STYLEGETFORE
            let rawBack = Int(query(2482, CLong(idx)) ?? 0)  // SCI_STYLEGETBACK
            let bold    = (query(2483, CLong(idx)) ?? 0) != 0 // SCI_STYLEGETBOLD
            let italic  = (query(2484, CLong(idx)) ?? 0) != 0 // SCI_STYLEGETITALIC

            result[idx] = ScintillaStyleInfo(
                foreColor: RichTextConversion.bgrToRGB(rawFore),
                backColor: RichTextConversion.bgrToRGB(rawBack),
                bold: bold,
                italic: italic
            )
        }
        return result
    }

    /// Build styled segments from a styled-text buffer (alternating
    /// character / style-byte pairs from Scintilla's SCI_GETSTYLEDTEXT).
    ///
    /// - Parameters:
    ///   - styledBuffer: A buffer where every even byte is a character
    ///     and every odd byte is its style index.
    ///   - styleInfo: Pre-collected style metadata keyed by style index.
    /// - Returns: An array of `StyledSegment` ready for HTML/RTF conversion.
    public static func buildSegments(
        styledBuffer: [UInt8],
        styleInfo: [Int: ScintillaStyleInfo]
    ) -> [StyledSegment] {
        guard styledBuffer.count >= 2 else { return [] }

        var segments: [StyledSegment] = []
        var currentText = ""
        var currentStyle = Int(styledBuffer[1])
        var currentFore = 0
        var currentBack = 0xFFFFFF
        var currentBold = false
        var currentItalic = false

        if let info = styleInfo[currentStyle] {
            currentFore = info.foreColor
            currentBack = info.backColor
            currentBold = info.bold
            currentItalic = info.italic
        }

        var i = 0
        while i < styledBuffer.count - 1 {
            let char = styledBuffer[i]
            let style = Int(styledBuffer[i + 1])
            i += 2

            if style != currentStyle {
                if !currentText.isEmpty {
                    segments.append(StyledSegment(
                        text: currentText,
                        foreColor: currentFore,
                        backColor: currentBack,
                        bold: currentBold,
                        italic: currentItalic
                    ))
                }
                currentText = ""
                currentStyle = style
                if let info = styleInfo[style] {
                    currentFore = info.foreColor
                    currentBack = info.backColor
                    currentBold = info.bold
                    currentItalic = info.italic
                } else {
                    // Fallback: inherit from STYLE_DEFAULT (32) or plain
                    currentFore = 0
                    currentBack = 0xFFFFFF
                    currentBold = false
                    currentItalic = false
                }
            }

            if char == 0 { break } // NUL terminator
            currentText.append(Character(UnicodeScalar(char)))
        }

        if !currentText.isEmpty {
            segments.append(StyledSegment(
                text: currentText,
                foreColor: currentFore,
                backColor: currentBack,
                bold: currentBold,
                italic: currentItalic
            ))
        }

        return segments
    }

    /// Export styled segments to the requested format and write the result
    /// to `destinationURL`.
    ///
    /// - Parameters:
    ///   - segments: Pre-built styled segments.
    ///   - format: `.html` or `.rtf`.
    ///   - title: Document title used in the HTML `<title>` tag or RTF header.
    ///   - destinationURL: File URL to write the output to.
    public static func writeExport(
        segments: [StyledSegment],
        format: Format,
        title: String,
        to destinationURL: URL
    ) throws {
        let content: String
        switch format {
        case .html:
            let bodyHTML = RichTextConversion.htmlFromSegments(segments)
            content = """
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>\(RichTextConversion.htmlEscape(title))</title>
            <style>body{margin:0;padding:8px;background:#FFFFFF}</style></head>
            <body>\(bodyHTML)</body>
            </html>
            """
        case .rtf:
            content = RichTextConversion.rtfFromSegments(segments)
        }
        try content.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
}
