import Foundation

/// A single TODO/FIXME/NOTE/HACK/BUG/XXX entry found in a document.
public struct TaskListEntry: Sendable, Equatable {
    public let line: Int
    public let utf16Location: Int
    public let tag: String          // e.g. "TODO", "FIXME"
    public let message: String      // text after the tag (trimmed)
    public let preview: String      // full line text (trimmed)

    public init(line: Int, utf16Location: Int, tag: String, message: String, preview: String) {
        self.line = line
        self.utf16Location = utf16Location
        self.tag = tag
        self.message = message
        self.preview = preview
    }
}

/// Scans document text for task markers and returns matching entries.
public enum TaskListScanner {
    /// Default tags to search for (case-insensitive).
    public static let defaultTags: [String] = ["TODO", "FIXME", "NOTE", "HACK", "BUG", "XXX"]

    /// Scan `text` for any of `tags` and return one entry per match.
    /// Tag matching is case-insensitive. A tag must be followed by `:`, space, or end-of-word.
    public static func scan(text: String, tags: [String] = defaultTags) -> [TaskListEntry] {
        guard !text.isEmpty, !tags.isEmpty else { return [] }

        let nsText = text as NSString
        let length = nsText.length

        // Build a regex that matches any of the tags at a word boundary.
        let tagPattern = tags
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        // Match optional comment prefixes (// # /* * -- ; !) then the tag
        let pattern = "(?i)(?://|#|/\\*|\\*|--|;|!)?\\s*(" + tagPattern + ")(?::|\\s|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var entries: [TaskListEntry] = []
        var lineNumber = 1
        var lineStart = 0

        var i = 0
        while i <= length {
            let atEnd = (i == length)
            let isNewline: Bool
            if atEnd {
                isNewline = true
            } else {
                let ch = nsText.character(at: i)
                isNewline = ch == 10 || ch == 13
                if isNewline && ch == 13 && i + 1 < length && nsText.character(at: i + 1) == 10 {
                    i += 1 // skip LF of CRLF
                }
            }

            if isNewline || atEnd {
                let lineRange = NSRange(location: lineStart, length: i - lineStart)
                let lineText = nsText.substring(with: lineRange)

                let nsLineText = lineText as NSString
                let hits = regex.matches(in: lineText, range: NSRange(location: 0, length: nsLineText.length))
                for hit in hits {
                    guard hit.numberOfRanges > 1 else { continue }
                    let tagRange = hit.range(at: 1)
                    guard tagRange.location != NSNotFound else { continue }
                    let tag = nsLineText.substring(with: tagRange).uppercased()
                    // Extract message: everything after the tag match
                    let afterTag = NSMaxRange(tagRange)
                    var msgStart = afterTag
                    // Skip optional colon and whitespace
                    while msgStart < nsLineText.length {
                        let c = nsLineText.character(at: msgStart)
                        if c == 58 /* ':' */ || c == 32 /* ' ' */ || c == 9 /* '\t' */ {
                            msgStart += 1
                        } else { break }
                    }
                    let message = msgStart < nsLineText.length
                        ? nsLineText.substring(from: msgStart).trimmingCharacters(in: .whitespaces)
                        : ""

                    entries.append(TaskListEntry(
                        line: lineNumber,
                        utf16Location: lineStart,
                        tag: tag,
                        message: message,
                        preview: lineText.trimmingCharacters(in: .whitespaces)
                    ))
                    break // at most one task entry per line
                }

                lineNumber += 1
                lineStart = i + 1
            }
            i += 1
        }

        return entries
    }
}
