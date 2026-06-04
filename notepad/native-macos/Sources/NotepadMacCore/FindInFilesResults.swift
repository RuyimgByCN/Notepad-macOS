import Foundation

public struct FindInFilesMatch: Equatable, Sendable, Codable {
    public let filePath: String
    public let line: Int
    public let column: Int
    public let lineText: String

    public init(filePath: String, line: Int, column: Int, lineText: String) {
        self.filePath = filePath
        self.line = line
        self.column = column
        self.lineText = lineText
    }
}

@MainActor
public final class FindInFilesResultsStore {
    public private(set) var matches: [FindInFilesMatch] = []
    public private(set) var selectedIndex: Int = -1

    public init() {}

    public var hasResults: Bool {
        !matches.isEmpty
    }

    public var selectedMatch: FindInFilesMatch? {
        guard matches.indices.contains(selectedIndex) else { return nil }
        return matches[selectedIndex]
    }

    public func setResults(_ newMatches: [FindInFilesMatch], purgeFirst: Bool) {
        if purgeFirst {
            matches = newMatches
        } else {
            matches.append(contentsOf: newMatches)
        }
        selectedIndex = matches.isEmpty ? -1 : 0
    }

    public func clear() {
        matches = []
        selectedIndex = -1
    }

    public func select(index: Int) {
        guard matches.indices.contains(index) else { return }
        selectedIndex = index
    }

    @discardableResult
    public func selectNext() -> FindInFilesMatch? {
        guard !matches.isEmpty else { return nil }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else if selectedIndex < matches.count - 1 {
            selectedIndex += 1
        } else {
            selectedIndex = 0
        }
        return matches[selectedIndex]
    }

    @discardableResult
    public func selectPrevious() -> FindInFilesMatch? {
        guard !matches.isEmpty else { return nil }
        if selectedIndex < 0 {
            selectedIndex = matches.count - 1
        } else if selectedIndex > 0 {
            selectedIndex -= 1
        } else {
            selectedIndex = matches.count - 1
        }
        return matches[selectedIndex]
    }

    public func remove(at index: Int) {
        guard matches.indices.contains(index) else { return }
        matches.remove(at: index)
        if matches.isEmpty {
            selectedIndex = -1
        } else if selectedIndex >= matches.count {
            selectedIndex = matches.count - 1
        } else if index < selectedIndex {
            selectedIndex -= 1
        }
    }

    public func removeFile(_ filePath: String) {
        let removedBeforeSelection = matches[..<max(0, selectedIndex)].filter { $0.filePath == filePath }.count
        let removedCount = matches.filter { $0.filePath == filePath }.count
        guard removedCount > 0 else { return }
        matches.removeAll { $0.filePath == filePath }
        if matches.isEmpty {
            selectedIndex = -1
        } else {
            selectedIndex = max(0, min(selectedIndex - removedBeforeSelection, matches.count - 1))
        }
    }

    public struct FileGroup: Equatable, Sendable {
        public let filePath: String
        public let matches: [FindInFilesMatch]
    }

    public func groupedByFile() -> [FileGroup] {
        var order: [String] = []
        var map: [String: [FindInFilesMatch]] = [:]
        for match in matches {
            if map[match.filePath] == nil {
                order.append(match.filePath)
                map[match.filePath] = []
            }
            map[match.filePath, default: []].append(match)
        }
        return order.map { FileGroup(filePath: $0, matches: map[$0] ?? []) }
    }

    public func flatIndex(of match: FindInFilesMatch) -> Int? {
        matches.firstIndex(of: match)
    }

    public func uniqueFilePaths() -> [String] {
        var order: [String] = []
        var seen: Set<String> = []
        for match in matches {
            if seen.insert(match.filePath).inserted {
                order.append(match.filePath)
            }
        }
        return order
    }
}
