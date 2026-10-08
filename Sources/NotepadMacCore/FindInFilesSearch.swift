import Foundation

public enum FindInFilesSearch {
    public static func searchInDirectory(
        _ directory: URL,
        query: String,
        filters: [String],
        matchCase: Bool,
        wholeWord: Bool,
        searchMode: TextSearch.SearchMode = .normal,
        skipPaths: Set<String> = [],
        perLineResult: Bool = false,
        dotMatchesLineSeparators: Bool = false
    ) -> [FindInFilesMatch] {
        var allResults: [FindInFilesMatch] = []
        let options = TextSearch.Options(
            matchCase: matchCase,
            wholeWord: wholeWord,
            wraps: false,
            direction: .down,
            searchMode: searchMode,
            dotMatchesLineSeparators: dotMatchesLineSeparators
        )
        let findMatches = TextSearch.prepareFindAll(query, options: options)

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else { continue }

            if !skipPaths.isEmpty, skipPaths.contains(fileURL.path) { continue }

            if !filters.isEmpty, !matchesFilter(fileURL.lastPathComponent, filters: filters) {
                continue
            }

            allResults.append(contentsOf: searchFile(at: fileURL, findMatches: findMatches, perLineResult: perLineResult))
        }

        return allResults
    }

    public static func searchInFiles(
        _ fileURLs: [URL],
        query: String,
        matchCase: Bool,
        wholeWord: Bool,
        searchMode: TextSearch.SearchMode = .normal,
        perLineResult: Bool = false
    ) -> [FindInFilesMatch] {
        let options = TextSearch.Options(
            matchCase: matchCase,
            wholeWord: wholeWord,
            wraps: false,
            direction: .down,
            searchMode: searchMode
        )

        var allResults: [FindInFilesMatch] = []
        let findMatches = TextSearch.prepareFindAll(query, options: options)
        for fileURL in fileURLs {
            if Task.isCancelled { break }
            allResults.append(contentsOf: searchFile(at: fileURL, findMatches: findMatches, perLineResult: perLineResult))
        }
        return allResults
    }

    public static func searchFile(
        at fileURL: URL,
        query: String,
        options: TextSearch.Options,
        perLineResult: Bool = false
    ) -> [FindInFilesMatch] {
        searchFile(at: fileURL, findMatches: TextSearch.prepareFindAll(query, options: options), perLineResult: perLineResult)
    }

    private static func searchFile(
        at fileURL: URL,
        findMatches: (String) -> [NSRange],
        perLineResult: Bool
    ) -> [FindInFilesMatch] {
        let content: String
        if let loaded = try? TextFileCodec.read(fileURL) {
            content = loaded.text
        } else if let decoded = try? String(contentsOf: fileURL, encoding: .utf8) {
            content = decoded
        } else {
            return []
        }
        return searchInContent(content, findMatches: findMatches, filePath: fileURL.path, perLineResult: perLineResult)
    }

    public static func searchInContent(
        _ content: String,
        query: String,
        options: TextSearch.Options,
        filePath: String,
        perLineResult: Bool = false
    ) -> [FindInFilesMatch] {
        searchInContent(content, findMatches: TextSearch.prepareFindAll(query, options: options), filePath: filePath, perLineResult: perLineResult)
    }

    private static func searchInContent(
        _ content: String,
        findMatches: (String) -> [NSRange],
        filePath: String,
        perLineResult: Bool
    ) -> [FindInFilesMatch] {
        var results: [FindInFilesMatch] = []
        let nsContent = content as NSString
        var lineNumber = 1
        var lineRange = nsContent.lineRange(for: NSRange(location: 0, length: 0))
        var lastResultLine = 0
        var cachedSnippetRange: NSRange?
        var cachedSnippet = ""

        for range in findMatches(content) {
            if Task.isCancelled { break }
            // Walk forward through logical lines once, including CRLF and an
            // empty final line. Cache the snippet when a line has many hits.
            while range.location >= NSMaxRange(lineRange), lineRange.length > 0 {
                let nextLine = nsContent.lineRange(for: NSRange(location: NSMaxRange(lineRange), length: 0))
                guard nextLine.location > lineRange.location else { break }
                lineRange = nextLine
                lineNumber += 1
            }
            if perLineResult, lastResultLine == lineNumber { continue }
            let snippetRange = NSMaxRange(range) <= NSMaxRange(lineRange)
                ? lineRange : nsContent.lineRange(for: range)
            if cachedSnippetRange != snippetRange {
                cachedSnippet = nsContent.substring(with: snippetRange).trimmingCharacters(in: .newlines)
                cachedSnippetRange = snippetRange
            }
            results.append(FindInFilesMatch(
                filePath: filePath,
                line: lineNumber,
                column: range.location - lineRange.location + 1,
                lineText: cachedSnippet
            ))
            lastResultLine = lineNumber
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
