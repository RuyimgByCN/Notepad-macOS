import Foundation

public struct BookmarkSet: Codable, Equatable, Sendable {
    private let lines: Set<Int>

    public var sortedLines: [Int] {
        lines.sorted()
    }

    public var count: Int {
        lines.count
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }

    public init(lines: some Sequence<Int> = []) {
        self.lines = Set(lines.filter { $0 > 0 })
    }

    public func contains(line: Int) -> Bool {
        lines.contains(line)
    }

    public func toggling(line: Int) -> BookmarkSet {
        guard line > 0 else { return self }

        var next = lines
        if next.contains(line) {
            next.remove(line)
        } else {
            next.insert(line)
        }
        return BookmarkSet(lines: next)
    }

    public func adding(lines newLines: some Sequence<Int>) -> BookmarkSet {
        var next = lines
        next.formUnion(newLines.filter { $0 > 0 })
        return BookmarkSet(lines: next)
    }

    public func addingSearchMatches(_ matches: some Sequence<NSRange>, in text: String) -> BookmarkSet {
        adding(lines: Self.linesContainingSearchMatches(matches, in: text))
    }

    public func clearing() -> BookmarkSet {
        BookmarkSet()
    }

    public func clamped(toLineCount lineCount: Int) -> BookmarkSet {
        guard lineCount > 0 else { return BookmarkSet() }
        return BookmarkSet(lines: lines.filter { $0 <= lineCount })
    }

    public func next(after line: Int) -> Int? {
        guard !lines.isEmpty else { return nil }

        if let next = sortedLines.first(where: { $0 > line }) {
            return next
        }
        return sortedLines.first
    }

    public func previous(before line: Int) -> Int? {
        guard !lines.isEmpty else { return nil }

        if let previous = sortedLines.last(where: { $0 < line }) {
            return previous
        }
        return sortedLines.last
    }

    public var zeroBasedLines: [Int] {
        sortedLines.map { $0 - 1 }
    }

    public static func linesContainingSearchMatches(_ matches: some Sequence<NSRange>, in text: String) -> [Int] {
        let lines = matches.reduce(into: Set<Int>()) { result, match in
            guard match.location != NSNotFound else { return }
            result.insert(TextPosition.lineAndColumn(in: text, utf16Location: match.location).line)
        }
        return lines.sorted()
    }
}
