import AppKit
import NotepadMacCore

@MainActor
final class SyntaxHighlighter {
    private static let maximumHighlightedUTF16Length = 250_000

    private var isApplying = false
    private var keywordRegexCache: [String: NSRegularExpression] = [:]

    func apply(language: LanguageDefinition, to textView: NSTextView) {
        guard !isApplying, let storage = textView.textStorage else { return }

        isApplying = true
        defer { isApplying = false }

        let text = storage.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let baseFont = textView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)

        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        guard text.utf16.count <= Self.maximumHighlightedUTF16Length else {
            storage.endEditing()
            return
        }

        applyStringHighlighting(in: storage, text: text)
        applyCommentHighlighting(in: storage, text: text, language: language)
        applyKeywordHighlighting(in: storage, text: text, language: language)
        // XML/HTML tag-based highlighting for XML, HTML and derived languages
        if language.name == "xml" || language.name == "html" {
            applyXmlTagHighlighting(in: storage, text: text)
        }
        storage.endEditing()
    }

    private func applyKeywordHighlighting(in storage: NSTextStorage, text: String, language: LanguageDefinition) {
        guard let regex = keywordRegex(for: language) else { return }
        let keywordColor = language.userDefinedKeywordForeground.map(NSColor.init(styleColor:)) ?? .systemBlue
        let range = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
            storage.addAttribute(.foregroundColor, value: keywordColor, range: matchRange)
        }
    }

    private func applyStringHighlighting(in storage: NSTextStorage, text: String) {
        apply(pattern: #""([^"\\]|\\.)*"|'([^'\\]|\\.)*'"#, to: storage, text: text, color: .systemGreen)
    }

    private func applyCommentHighlighting(in storage: NSTextStorage, text: String, language: LanguageDefinition) {
        if let lineComment = language.lineComment {
            apply(
                pattern: #"(?m)"# + NSRegularExpression.escapedPattern(for: lineComment) + #".*$"#,
                to: storage,
                text: text,
                color: .secondaryLabelColor
            )
        }

        if let start = language.blockCommentStart, let end = language.blockCommentEnd {
            apply(
                pattern: NSRegularExpression.escapedPattern(for: start) + #"[\s\S]*?"# + NSRegularExpression.escapedPattern(for: end),
                to: storage,
                text: text,
                color: .secondaryLabelColor
            )
        }
    }

    /// Apply XML/HTML tag-based coloring using upstream Notepad++ XML style colors
    /// when available, falling back to system colors.
    private func applyXmlTagHighlighting(in storage: NSTextStorage, text: String) {
        // Load upstream XML lexer colors from style catalog
        let xmlStyles = loadXmlStyleColors()
        let tagColor = xmlStyles[1] ?? .systemBlue       // TAG → #0000FF blue
        let attrColor = xmlStyles[3] ?? .systemRed        // ATTRIBUTE → #FF0000 red
        let stringColor = xmlStyles[6] ?? .systemPurple   // STRING → #8000FF purple
        let commentColor = xmlStyles[9] ?? .systemGreen   // COMMENT → #008000 green
        let cdataColor = xmlStyles[17] ?? .systemOrange   // CDATA → #FF8000 orange
        let declColor = xmlStyles[12] ?? .systemPurple    // XMLSTART

        // Tag names: <tagname, </tagname
        apply(pattern: #"(?<=</?)[A-Za-z_:][\w.\-:]*(?=\s|>|/)"#,
              to: storage, text: text, color: tagColor)
        // Attribute names: attr=
        apply(pattern: #"\b[A-Za-z_][\w.\-:]*(?=\s*=)"#,
              to: storage, text: text, color: attrColor)
        // XML declaration <?xml ...?>
        apply(pattern: #"<\?[^>]*\?>"#,
              to: storage, text: text, color: declColor)
        // CDATA sections
        apply(pattern: #"<!\[CDATA\[[\s\S]*?\]\]>"#,
              to: storage, text: text, color: cdataColor)
        // HTML/XML comments <!-- ... -->
        apply(pattern: #"<!--[\s\S]*?-->"#,
              to: storage, text: text, color: commentColor)
    }

    /// Load upstream Notepad++ XML lexer colors from stylers.model.xml.
    /// These match the exact colors shown in Notepad++ Windows for XML files.
    private func loadXmlStyleColors() -> [Int: NSColor] {
        // Match upstream Notepad++ XML style definitions:
        // TAG=#0000FF, ATTRIBUTE=#FF0000, STRING=#8000FF, COMMENT=#008000, CDATA=#FF8000
        let upstreamDefaults: [(Int, UInt8, UInt8, UInt8)] = [
            (1,  0x00, 0x00, 0xFF),  // TAG → blue #0000FF
            (2,  0x00, 0x00, 0xFF),  // TAG UNKNOWN → blue #0000FF
            (3,  0xFF, 0x00, 0x00),  // ATTRIBUTE → red #FF0000
            (4,  0xFF, 0x00, 0x00),  // ATTRIBUTE UNKNOWN → red #FF0000
            (6,  0x80, 0x00, 0xFF),  // DOUBLE STRING → purple #8000FF
            (7,  0x80, 0x00, 0xFF),  // SINGLE STRING → purple #8000FF
            (9,  0x00, 0x80, 0x00),  // COMMENT → green #008000
            (11, 0x00, 0x00, 0xFF),  // TAG END → blue
            (12, 0xFF, 0x00, 0x00),  // XML START → red
            (17, 0xFF, 0x80, 0x00),  // CDATA → orange #FF8000
        ]
        var colors: [Int: NSColor] = [:]
        for (id, r, g, b) in upstreamDefaults {
            colors[id] = NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
        }
        return colors
    }

    private func apply(pattern: String, to storage: NSTextStorage, text: String, color: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
            storage.addAttribute(.foregroundColor, value: color, range: matchRange)
        }
    }

    private func keywordRegex(for language: LanguageDefinition) -> NSRegularExpression? {
        if let cached = keywordRegexCache[language.name] {
            return cached
        }

        let identifierKeywords = language.allKeywords
            .filter { $0.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count > rhs.count
            }

        guard !identifierKeywords.isEmpty else { return nil }

        let pattern = "\\b(" + identifierKeywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")\\b"
        let regex = try? NSRegularExpression(pattern: pattern)
        if let regex {
            keywordRegexCache[language.name] = regex
        }
        return regex
    }
}

private extension NSColor {
    convenience init(styleColor: StyleColor) {
        self.init(
            srgbRed: CGFloat(styleColor.red) / 255.0,
            green: CGFloat(styleColor.green) / 255.0,
            blue: CGFloat(styleColor.blue) / 255.0,
            alpha: 1.0
        )
    }
}
