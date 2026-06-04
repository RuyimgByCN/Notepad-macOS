import Foundation

public enum TextSearch {
    public enum Direction: Equatable, Sendable {
        case down
        case up
    }

    public enum SearchMode: String, Equatable, Sendable, CaseIterable {
        case normal
        case extended  // \n, \t, \r, \\, \0 escape sequences
        case regex     // NSRegularExpression
    }

    public struct Options: Equatable, Sendable {
        public var matchCase: Bool
        public var wholeWord: Bool
        public var wraps: Bool
        public var direction: Direction
        public var searchMode: SearchMode
        public var dotMatchesLineSeparators: Bool
        /// When non-nil, restricts search to this character range within the text.
        public var searchRange: NSRange?

        public init(matchCase: Bool = false, wholeWord: Bool = false, wraps: Bool = true, direction: Direction = .down, searchMode: SearchMode = .normal, dotMatchesLineSeparators: Bool = false, searchRange: NSRange? = nil) {
            self.matchCase = matchCase
            self.wholeWord = wholeWord
            self.wraps = wraps
            self.direction = direction
            self.searchMode = searchMode
            self.dotMatchesLineSeparators = dotMatchesLineSeparators
            self.searchRange = searchRange
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

        // If a search range constraint is set, search only within it
        if let constraint = options.searchRange {
            let lo = clamped(constraint.location, to: nsText.length)
            let hi = clamped(NSMaxRange(constraint), to: nsText.length)
            guard lo < hi else { return nil }

            switch options.direction {
            case .down:
                let searchStart = max(lo, clamped(selection.location + selection.length, to: hi))
                let firstRange = NSRange(location: searchStart, length: hi - searchStart)
                if let range = find(query, in: nsText, searchRange: firstRange, options: options, direction: .down) {
                    return range
                }
                guard options.wraps, searchStart > lo else { return nil }
                return find(query, in: nsText, searchRange: NSRange(location: lo, length: searchStart - lo), options: options, direction: .down)
            case .up:
                let searchEnd = min(hi, clamped(selection.location, to: nsText.length))
                let firstRange = NSRange(location: lo, length: searchEnd - lo)
                if let range = find(query, in: nsText, searchRange: firstRange, options: options, direction: .up) {
                    return range
                }
                guard options.wraps, searchEnd < hi else { return nil }
                return find(query, in: nsText, searchRange: NSRange(location: searchEnd, length: hi - searchEnd), options: options, direction: .up)
            }
        }

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

        // Fast path: regex replace with capture group support
        if options.searchMode == .regex {
            var regexOptions: NSRegularExpression.Options = []
            if !options.matchCase { regexOptions.insert(.caseInsensitive) }
            if options.dotMatchesLineSeparators { regexOptions.insert(.dotMatchesLineSeparators) }
            guard let regex = try? NSRegularExpression(pattern: query, options: regexOptions) else {
                return ReplaceAllResult(text: text, count: 0)
            }
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let count = regex.numberOfMatches(in: text, options: [], range: fullRange)
            let replaced = regex.stringByReplacingMatches(in: text, options: [], range: fullRange, withTemplate: replacement)
            return ReplaceAllResult(text: replaced, count: count)
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

        if options.searchMode == .regex {
            var regexOptions: NSRegularExpression.Options = []
            if !options.matchCase { regexOptions.insert(.caseInsensitive) }
            if options.dotMatchesLineSeparators { regexOptions.insert(.dotMatchesLineSeparators) }
            guard let regex = try? NSRegularExpression(pattern: query, options: regexOptions) else { return [] }
            let fullRange = NSRange(location: 0, length: nsText.length)
            let candidates = regex.matches(in: text, options: [], range: fullRange).map(\.range)
            if options.wholeWord {
                return candidates.filter { isWholeWord($0, in: nsText) }
            }
            return candidates
        }

        let effectiveQuery = options.searchMode == .extended ? expandExtendedEscapes(query) : query
        var matches: [NSRange] = []
        var searchLocation = 0

        while searchLocation <= nsText.length {
            let remainingLength = nsText.length - searchLocation
            guard remainingLength >= effectiveQuery.utf16.count else { break }

            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            guard let match = findForward(effectiveQuery, in: nsText, searchRange: searchRange, options: options) else {
                break
            }

            matches.append(match)
            searchLocation = match.location + max(match.length, 1)
        }

        return matches
    }

    private static func find(_ query: String, in text: NSString, searchRange: NSRange, options: Options, direction: Direction) -> NSRange? {
        let effectiveQuery: String
        switch options.searchMode {
        case .normal:
            effectiveQuery = query
        case .extended:
            effectiveQuery = expandExtendedEscapes(query)
        case .regex:
            return findRegex(query, in: text, searchRange: searchRange, options: options, direction: direction)
        }

        switch direction {
        case .down:
            return findForward(effectiveQuery, in: text, searchRange: searchRange, options: options)
        case .up:
            return findBackward(effectiveQuery, in: text, searchRange: searchRange, options: options)
        }
    }

    private static func findForward(_ query: String, in text: NSString, searchRange: NSRange, options: Options) -> NSRange? {
        var currentRange = searchRange
        let cmpOptions = compareOptions(for: options)

        while currentRange.length >= query.utf16.count {
            let candidate = text.range(of: query, options: cmpOptions, range: currentRange)
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
        let cmpOptions = compareOptions(for: options).union(.backwards)

        while currentRange.length >= query.utf16.count {
            let candidate = text.range(of: query, options: cmpOptions, range: currentRange)
            guard candidate.location != NSNotFound else { return nil }

            if !options.wholeWord || isWholeWord(candidate, in: text) {
                return candidate
            }

            currentRange = NSRange(location: currentRange.location, length: max(candidate.location - currentRange.location, 0))
        }

        return nil
    }

    private static func findRegex(_ pattern: String, in text: NSString, searchRange: NSRange, options: Options, direction: Direction) -> NSRange? {
        var regexOptions: NSRegularExpression.Options = []
        if !options.matchCase { regexOptions.insert(.caseInsensitive) }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else { return nil }

        let fullText = text as String
        let utf16View = fullText.utf16

        // Convert NSRange (UTF-16 based) to Swift Range for regex
        guard let swiftStart = fullText.index(fullText.startIndex, offsetBy: searchRange.location, limitedBy: fullText.endIndex),
              let swiftEnd = fullText.index(swiftStart, offsetBy: searchRange.length, limitedBy: fullText.endIndex)
        else { return nil }
        let swiftRange = swiftStart..<swiftEnd

        let matches = regex.matches(in: fullText, options: [], range: NSRange(swiftRange, in: fullText))

        let candidates: [NSRange]
        if direction == .up {
            candidates = matches.map(\.range).reversed()
        } else {
            candidates = matches.map(\.range)
        }

        for candidate in candidates {
            if options.wholeWord && !isWholeWord(candidate, in: text) { continue }
            return candidate
        }
        return nil
    }

    // Translate Notepad++ extended escape sequences
    private static func expandExtendedEscapes(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            let c = input[i]
            if c == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    switch input[next] {
                    case "n": result.append("\n"); i = input.index(after: next)
                    case "t": result.append("\t"); i = input.index(after: next)
                    case "r": result.append("\r"); i = input.index(after: next)
                    case "0": result.append("\0"); i = input.index(after: next)
                    case "\\": result.append("\\"); i = input.index(after: next)
                    default: result.append(c); i = next
                    }
                    continue
                }
            }
            result.append(c)
            i = input.index(after: i)
        }
        return result
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
