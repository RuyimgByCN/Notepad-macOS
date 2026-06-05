import Foundation

/// A text segment with style information for rich copy operations (HTML/RTF).
public struct StyledSegment: Equatable, Sendable {
    public let text: String
    /// Foreground colour in 0xRRGGBB format.
    public let foreColor: Int
    /// Background colour in 0xRRGGBB format.
    public let backColor: Int
    public let bold: Bool
    public let italic: Bool

    public init(text: String, foreColor: Int, backColor: Int, bold: Bool, italic: Bool) {
        self.text = text
        self.foreColor = foreColor
        self.backColor = backColor
        self.bold = bold
        self.italic = italic
    }
}

/// Colour and text-formatting helpers for Copy as HTML / Copy as RTF.
public enum RichTextConversion {

    /// Convert Scintilla 0x00BBGGRR colour value to 0x00RRGGBB.
    public static func bgrToRGB(_ bgr: Int) -> Int {
        let r = bgr & 0xFF
        let g = (bgr >> 8) & 0xFF
        let b = (bgr >> 16) & 0xFF
        return (r << 16) | (g << 8) | b
    }

    /// Return a 6-digit hex string like `"FF00CC"` from an 0xRRGGBB colour.
    public static func hexColor(_ rgb: Int) -> String {
        String(format: "%02X%02X%02X", (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
    }

    /// Escape text for safe inclusion inside an HTML element body.
    public static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Escape text for safe inclusion inside an RTF document body.
    public static func rtfEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf16.count)
        for c in s.unicodeScalars {
            switch c {
            case "\\": out += "\\\\"
            case "{":  out += "\\{"
            case "}":  out += "\\}"
            case "\n": out += "\\line "
            case "\r": break // CR handled via LF
            default:
                if c.value < 128 {
                    out.append(Character(c))
                } else {
                    out += "\\u\(c.value)?"
                }
            }
        }
        return out
    }

    /// Build a complete HTML fragment from styled segments.
    public static func htmlFromSegments(_ segments: [StyledSegment]) -> String {
        var html = "<pre style=\"font-family:monospace\">"
        for seg in segments {
            var css = "color:#\(hexColor(seg.foreColor));background-color:#\(hexColor(seg.backColor));"
            if seg.bold { css += "font-weight:bold;" }
            if seg.italic { css += "font-style:italic;" }
            html += "<span style=\"\(css)\">\(htmlEscape(seg.text))</span>"
        }
        html += "</pre>"
        return html
    }

    /// Build a complete RTF document from styled segments.
    public static func rtfFromSegments(_ segments: [StyledSegment]) -> String {
        // Build colour table (RTF 1-based; \redN\greenN\blueN per entry).
        var colourList: [(r: Int, g: Int, b: Int)] = []
        var colourIndex: [Int: Int] = [:] // 0xRRGGBB → 0-based index
        for seg in segments {
            for c in [seg.foreColor, seg.backColor] {
                if colourIndex[c] == nil {
                    colourIndex[c] = colourList.count
                    colourList.append((r: (c >> 16) & 0xFF, g: (c >> 8) & 0xFF, b: c & 0xFF))
                }
            }
        }

        var rtf = "{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Courier New;}}"
        rtf += "{\\colortbl;"
        for c in colourList {
            rtf += "\\red\(c.r)\\green\(c.g)\\blue\(c.b);"
        }
        rtf += "}\\f0\\fs20 "

        for seg in segments {
            let fi = colourIndex[seg.foreColor, default: 0] + 1
            let bi = colourIndex[seg.backColor, default: 0] + 1
            rtf += "\\cf\(fi)\\highlight\(bi)"
            if seg.bold { rtf += "\\b" }
            if seg.italic { rtf += "\\i" }
            rtf += " \(rtfEscape(seg.text))"
            if seg.bold { rtf += "\\b0 " }
            if seg.italic { rtf += "\\i0 " }
        }
        rtf += "}"
        return rtf
    }
}
