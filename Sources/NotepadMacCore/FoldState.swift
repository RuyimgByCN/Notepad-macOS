import Foundation

public struct FoldState: Codable, Equatable, Sendable {
    public let collapsedLines: [Int]

    public var count: Int {
        collapsedLines.count
    }

    public var isEmpty: Bool {
        collapsedLines.isEmpty
    }

    public init(collapsedLines: some Sequence<Int> = []) {
        self.collapsedLines = Set(collapsedLines.filter { $0 > 0 }).sorted()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let collapsedLines = try container.decodeIfPresent([Int].self, forKey: .collapsedLines) ?? []
        self.init(collapsedLines: collapsedLines)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(collapsedLines, forKey: .collapsedLines)
    }

    public func isCollapsed(line: Int) -> Bool {
        collapsedLines.contains(line)
    }

    public func clamped(toLineCount lineCount: Int) -> FoldState {
        guard lineCount > 0 else { return FoldState() }
        return FoldState(collapsedLines: collapsedLines.filter { $0 <= lineCount })
    }

    private enum CodingKeys: String, CodingKey {
        case collapsedLines
    }
}

public struct SessionFoldRecord: Codable, Equatable, Sendable {
    public let identity: EditorTabIdentity
    public let folds: FoldState

    public init(identity: EditorTabIdentity, folds: FoldState) {
        self.identity = identity.normalized
        self.folds = folds
    }
}
