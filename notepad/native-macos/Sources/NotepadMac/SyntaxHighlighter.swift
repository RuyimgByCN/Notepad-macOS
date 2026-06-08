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

    /// Apply XML/HTML tag-based coloring: tag names in blue, attributes in orange,
    /// attribute values in yellow, XML declarations in purple.
    private func applyXmlTagHighlighting(in storage: NSTextStorage, text: String) {
        // Match XML/HTML tags: <...> including self-closing and declarations
        // Step 1: tag names (e.g. <div, </span, <root, <xsl:template)
        apply(pattern: #"(?<=</?)[A-Za-z_:][\w.\-:]*(?=\s|>|/)"#,
              to: storage, text: text, color: .systemBlue)
        // Step 2: attribute names (e.g. class=, id=, xmlns:xsl=)
        apply(pattern: #"\b[A-Za-z_][\w.\-:]*(?=\s*=)"#,
              to: storage, text: text, color: .systemOrange)
        // Step 3: XML declaration <?xml ...?>
        apply(pattern: #"<\?[^>]*\?>"#,
              to: storage, text: text, color: .systemPurple)
        // Step 4: CDATA sections
        apply(pattern: #"<!\[CDATA\[[\s\S]*?\]\]>"#,
              to: storage, text: text, color: .systemGray)
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
