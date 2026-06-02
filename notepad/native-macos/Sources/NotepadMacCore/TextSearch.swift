import Foundation

public enum TextSearch {
    public enum Direction: Equatable, Sendable {
        case down
        case up
    }

    public struct Options: Equatable, Sendable {
        public var matchCase: Bool
        public var wholeWord: Bool
        public var wraps: Bool
        public var direction: Direction

        public init(matchCase: Bool = false, wholeWord: Bool = false, wraps: Bool = true, direction: Direction = .down) {
            self.matchCase = matchCase
            self.wholeWord = wholeWord
            self.wraps = wraps
            self.direction = direction
        }
    }

    public struct Replacement: Equatable, Sendable {
        public let text: String
        public let replacedRange: NSRange
    }

    public struct ReplaceAllResult: Equatable, Sendable {
        public let text: String
        public let count: Int
    }

    public static func findNext(
        _ query: String,
        in text: String,
        from selection: NSRange,
        options: Options = Options()
    ) -> NSRange? {
        guard !query.isEmpty, !text.isEmpty else { return nil }

        let nsText = text as NSString
        switch options.direction {
        case .down:
            let searchStart = clamped(selection.location + selection.length, to: nsText.length)
            if let range = find(query, in: nsText, searchRange: NSRange(location: searchStart, length: nsText.length - searchStart), options: options, direction: .down) {
                return range
            }

            guard options.wraps, searchStart > 0 else { return nil }
            return find(query, in: nsText, searchRange: NSRange(location: 0, length: searchStart), options: options, direction: .down)
        case .up:
            let searchEnd = clamped(selection.location, to: nsText.length)
            if let range = find(query, in: nsText, searchRange: NSRange(location: 0, length: searchEnd), options: options, direction: .up) {
                return range
            }

            guard options.wraps, searchEnd < nsText.length else { return nil }
            return find(query, in: nsText, searchRange: NSRange(location: searchEnd, length: nsText.length - searchEnd), options: options, direction: .up)
        }
    }

    public static func replaceNext(
        _ query: String,
        with replacement: String,
        in text: String,
        from selection: NSRange,
        options: Options = Options()
    ) -> Replacement? {
        guard let range = findNext(query, in: text, from: selection, options: options) else { return nil }
        let replacedText = (text as NSString).replacingCharacters(in: range, with: replacement)
        return Replacement(text: replacedText, replacedRange: NSRange(location: range.location, length: replacement.utf16.count))
    }

    public static func replaceAll(
        _ query: String,
        with replacement: String,
        in text: String,
        options: Options = Options()
    ) -> ReplaceAllResult {
        guard !query.isEmpty, !text.isEmpty else {
            return ReplaceAllResult(text: text, count: 0)
        }

        var currentText = text
        var count = 0
        var searchLocation = 0

        while searchLocation <= (currentText as NSString).length {
            let nsText = currentText as NSString
            let searchRange = NSRange(location: searchLocation, length: nsText.length - searchLocation)
            guard let match = find(query, in: nsText, searchRange: searchRange, options: options, direction: .down) else {
                break
            }

            currentText = nsText.replacingCharacters(in: match, with: replacement)
            count += 1
            searchLocation = match.location + replacement.utf16.count
        }

        return ReplaceAllResult(text: currentText, count: count)
    }

    public static func findAll(
        _ query: String,
        in text: String,
        options: Options = Options()
    ) -> [NSRange] {
        guard !query.isEmpty, !text.isEmpty else { return [] }

        let nsText = text as NSString
        var matches: [NSRange] = []
        var searchLocation = 0

        while searchLocation <= nsText.length {
            let remainingLength = nsText.length - searchLocation
            guard remainingLength >= query.utf16.count else { break }

            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            guard let match = findForward(query, in: nsText, searchRange: searchRange, options: options) else {
                break
            }

            matches.append(match)
            searchLocation = match.location + max(match.length, 1)
        }

        return matches
    }

    private static func find(_ query: String, in text: NSString, searchRange: NSRange, options: Options, direction: Direction) -> NSRange? {
        switch direction {
        case .down:
            findForward(query, in: text, searchRange: searchRange, options: options)
        case .up:
            findBackward(query, in: text, searchRange: searchRange, options: options)
        }
    }

    private static func findForward(_ query: String, in text: NSString, searchRange: NSRange, options: Options) -> NSRange? {
        var currentRange = searchRange
        let compareOptions = compareOptions(for: options)

        while currentRange.length >= query.utf16.count {
            let candidate = text.range(of: query, options: compareOptions, range: currentRange)
            guard candidate.location != NSNotFound else { return nil }

            if !options.wholeWord || isWholeWord(candidate, in: text) {
                return candidate
            }

            let nextLocation = candidate.location + max(candidate.length, 1)
            let searchEnd = searchRange.location + searchRange.length
            currentRange = NSRange(location: nextLocation, length: max(searchEnd - nextLocation, 0))
        }

        return nil
    }

    private static func findBackward(_ query: String, in text: NSString, searchRange: NSRange, options: Options) -> NSRange? {
        var currentRange = searchRange
        let compareOptions = compareOptions(for: options).union(.backwards)

        while currentRange.length >= query.utf16.count {
            let candidate = text.range(of: query, options: compareOptions, range: currentRange)
            guard candidate.location != NSNotFound else { return nil }

            if !options.wholeWord || isWholeWord(candidate, in: text) {
                return candidate
            }

            currentRange = NSRange(location: currentRange.location, length: max(candidate.location - currentRange.location, 0))
        }

        return nil
    }

    private static func compareOptions(for options: Options) -> NSString.CompareOptions {
        options.matchCase ? [] : [.caseInsensitive]
    }

    private static func clamped(_ location: Int, to upperBound: Int) -> Int {
        min(max(location, 0), upperBound)
    }

    private static func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        !isWordCharacter(before: range.location, in: text) &&
            !isWordCharacter(at: range.location + range.length, in: text)
    }

    private static func isWordCharacter(before location: Int, in text: NSString) -> Bool {
        guard location > 0 else { return false }
        return isWordCharacter(at: location - 1, in: text)
    }

    private static func isWordCharacter(at location: Int, in text: NSString) -> Bool {
        guard location >= 0, location < text.length else { return false }
        guard let scalar = UnicodeScalar(text.character(at: location)) else { return false }
        return scalar == "_" || CharacterSet.alphanumerics.contains(scalar)
    }
}
