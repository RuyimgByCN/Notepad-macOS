import Foundation

public enum FindInFilesSearch {
    public static func searchInDirectory(
        _ directory: URL,
        query: String,
        filters: [String],
        matchCase: Bool,
        wholeWord: Bool,
        searchMode: TextSearch.SearchMode = .normal,
        skipPaths: Set<String> = []
    ) -> [FindInFilesMatch] {
        var allResults: [FindInFilesMatch] = []
        let options = TextSearch.Options(
            matchCase: matchCase,
            wholeWord: wholeWord,
            wraps: false,
            direction: .down,
            searchMode: searchMode
        )

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else { continue }

            if !skipPaths.isEmpty, skipPaths.contains(fileURL.path) { continue }

            if !filters.isEmpty, !matchesFilter(fileURL.lastPathComponent, filters: filters) {
                continue
            }

            allResults.append(contentsOf: searchFile(at: fileURL, query: query, options: options))
        }

        return allResults
    }

    public static func searchInFiles(
        _ fileURLs: [URL],
        query: String,
        matchCase: Bool,
        wholeWord: Bool,
        searchMode: TextSearch.SearchMode = .normal
    ) -> [FindInFilesMatch] {
        let options = TextSearch.Options(
            matchCase: matchCase,
            wholeWord: wholeWord,
            wraps: false,
            direction: .down,
            searchMode: searchMode
        )

        var allResults: [FindInFilesMatch] = []
        for fileURL in fileURLs {
            allResults.append(contentsOf: searchFile(at: fileURL, query: query, options: options))
        }
        return allResults
    }

    public static func searchFile(
        at fileURL: URL,
        query: String,
        options: TextSearch.Options
    ) -> [FindInFilesMatch] {
        let content: String
        if let loaded = try? TextFileCodec.read(fileURL) {
            content = loaded.text
        } else if let decoded = try? String(contentsOf: fileURL, encoding: .utf8) {
            content = decoded
        } else {
            return []
        }
        return searchInContent(content, query: query, options: options, filePath: fileURL.path)
    }

    public static func searchInContent(
        _ content: String,
        query: String,
        options: TextSearch.Options,
        filePath: String
    ) -> [FindInFilesMatch] {
        var results: [FindInFilesMatch] = []
        let nsContent = content as NSString
        var searchFrom = NSRange(location: 0, length: 0)

        while let range = TextSearch.findNext(query, in: content, from: searchFrom, options: options) {
            let lineRange = nsContent.lineRange(for: range)
            let lineNumber = nsContent.substring(with: NSRange(location: 0, length: lineRange.location))
                .components(separatedBy: .newlines).count
            let lineText = nsContent.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let column = range.location - lineRange.location + 1

            results.append(FindInFilesMatch(
                filePath: filePath,
                line: lineNumber,
                column: column,
                lineText: lineText
            ))

            searchFrom = NSRange(location: range.location + range.length, length: 0)
        }

        return results
    }

    public static func matchesFilter(_ filename: String, filters: [String]) -> Bool {
        for filter in filters {
            let pattern = filter
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: "?", with: ".")
            if filename.range(of: "^\(pattern)$", options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    public static func parseFilters(_ filter: String) -> [String] {
        filter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
