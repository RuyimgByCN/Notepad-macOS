import Foundation

/// Finds matching XML/HTML tag pairs given a text and cursor position.
public struct XmlTagMatcher {
    public struct TagMatch {
        public let openTagRange: NSRange
        public let closeTagRange: NSRange
    }

    private struct TagInfo {
        let name: String
        let isClose: Bool
        let isSelfClose: Bool
        let range: NSRange
    }

    public static func findMatch(in text: String, cursorPosition: Int) -> TagMatch? {
        let nsText = text as NSString
        let len = nsText.length
        guard cursorPosition >= 0, cursorPosition <= len else { return nil }

        guard let tagInfo = findTagAtCursor(nsText, cursorPosition: cursorPosition),
              !tagInfo.isSelfClose
        else { return nil }

        if tagInfo.isClose {
            if let openRange = findMatchingOpenTag(nsText, tagName: tagInfo.name, before: tagInfo.range.location) {
                return TagMatch(openTagRange: openRange, closeTagRange: tagInfo.range)
            }
        } else {
            let searchFrom = NSMaxRange(tagInfo.range)
            if let closeRange = findMatchingCloseTag(nsText, tagName: tagInfo.name, from: searchFrom) {
                return TagMatch(openTagRange: tagInfo.range, closeTagRange: closeRange)
            }
        }
        return nil
    }

    // MARK: - Cursor tag detection

    private static func findTagAtCursor(_ text: NSString, cursorPosition: Int) -> TagInfo? {
        let len = text.length
        guard len > 0 else { return nil }

        // Scan backward from cursor to find < without crossing >
        // cursorPosition may equal len (insertion point at end), so clamp before use
        var pos = min(cursorPosition, len - 1)
        while pos > 0 {
            let ch = text.character(at: pos)
            if ch == ascii("<") { break }
            if ch == ascii(">") { return nil }
            pos -= 1
        }
        guard pos >= 0, pos < len, text.character(at: pos) == ascii("<") else { return nil }

        return parseTag(text, at: pos, bound: len)
    }

    // MARK: - Forward search

    private static func findMatchingCloseTag(_ text: NSString, tagName: String, from start: Int) -> NSRange? {
        let len = text.length
        var pos = start
        var depth = 0

        while pos < len {
            guard let tag = findNextTag(text, from: pos, bound: len) else { break }
            let lower = tag.name.lowercased()
            if lower == tagName.lowercased() {
                if tag.isClose {
                    if depth == 0 { return tag.range }
                    depth -= 1
                } else if !tag.isSelfClose {
                    depth += 1
                }
            }
            pos = NSMaxRange(tag.range)
        }
        return nil
    }

    private static func findNextTag(_ text: NSString, from pos: Int, bound: Int) -> TagInfo? {
        var i = pos
        while i < bound {
            if text.character(at: i) == ascii("<") {
                if let tag = parseTag(text, at: i, bound: bound) { return tag }
            }
            i += 1
        }
        return nil
    }

    // MARK: - Backward search

    private static func findMatchingOpenTag(_ text: NSString, tagName: String, before pos: Int) -> NSRange? {
        var i = pos
        var depth = 0

        while i > 0 {
            guard let tag = findPreviousTag(text, before: i) else { break }
            let lower = tag.name.lowercased()
            if lower == tagName.lowercased() {
                if !tag.isClose && !tag.isSelfClose {
                    if depth == 0 { return tag.range }
                    depth -= 1
                } else if tag.isClose {
                    depth += 1
                }
            }
            i = tag.range.location
        }
        return nil
    }

    private static func findPreviousTag(_ text: NSString, before pos: Int) -> TagInfo? {
        var i = pos - 1
        // Scan backward for >
        while i >= 0 {
            if text.character(at: i) == ascii(">") {
                // Found end of a tag; now find its <
                var j = i - 1
                while j >= 0 {
                    let ch = text.character(at: j)
                    if ch == ascii("<") {
                        if let tag = parseTag(text, at: j, bound: i + 1),
                           NSMaxRange(tag.range) == i + 1 {
                            return tag
                        }
                        break
                    }
                    if ch == ascii(">") { break }
                    j -= 1
                }
                i = j - 1
            } else {
                i -= 1
            }
        }
        return nil
    }

    // MARK: - Tag parser

    private static func parseTag(_ text: NSString, at start: Int, bound: Int) -> TagInfo? {
        guard start < bound, text.character(at: start) == ascii("<") else { return nil }

        var end = start + 1
        var inString = false
        var stringChar: UInt16 = 0

        while end < bound {
            let ch = text.character(at: end)
            if inString {
                if ch == stringChar { inString = false }
            } else if ch == ascii("\"") || ch == ascii("'") {
                inString = true
                stringChar = ch
            } else if ch == ascii(">") {
                break
            } else if ch == ascii("<") {
                return nil
            }
            end += 1
        }
        guard end < bound else { return nil }

        let tagRange = NSRange(location: start, length: end - start + 1)
        var nameStart = start + 1
        var isClose = false

        if nameStart < end, text.character(at: nameStart) == ascii("/") {
            isClose = true
            nameStart += 1
        }

        // Skip comments <!-- and processing instructions <?
        if nameStart < end {
            let ch = text.character(at: nameStart)
            if ch == ascii("!") || ch == ascii("?") { return nil }
        }

        // Extract tag name
        var nameEnd = nameStart
        while nameEnd < end {
            let ch = text.character(at: nameEnd)
            if ch == ascii(" ") || ch == ascii("\t") || ch == ascii("\n") ||
               ch == ascii("\r") || ch == ascii("/") || ch == ascii(">") { break }
            nameEnd += 1
        }
        guard nameEnd > nameStart else { return nil }

        let name = text.substring(with: NSRange(location: nameStart, length: nameEnd - nameStart))
        // Tag name must start with letter or underscore
        guard let first = name.unicodeScalars.first,
              CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first)
        else { return nil }

        // Self-closing: ends with />
        let isSelfClose = end > start + 1 && text.character(at: end - 1) == ascii("/")

        return TagInfo(name: name, isClose: isClose, isSelfClose: isSelfClose, range: tagRange)
    }

    // MARK: - Helpers

    private static func ascii(_ char: Character) -> UInt16 {
        UInt16(char.asciiValue!)
    }
}
