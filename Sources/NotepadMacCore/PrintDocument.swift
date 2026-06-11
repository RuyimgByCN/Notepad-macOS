import Foundation

public struct PrintDocument: Codable, Equatable, Sendable {
    public let title: String
    public let text: String
    public let languageDisplayName: String
    public let encodingDisplayName: String

    public init(
        title: String,
        text: String,
        languageDisplayName: String,
        encodingDisplayName: String
    ) {
        self.title = title
        self.text = text
        self.languageDisplayName = languageDisplayName
        self.encodingDisplayName = encodingDisplayName
    }

    public var normalizedLines: [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")

        if lines.last == "" {
            lines.removeLast()
        }

        return lines.isEmpty ? [""] : lines
    }

    public func pages(linesPerPage: Int) -> [PrintPage] {
        let lines = normalizedLines
        guard linesPerPage > 0 else {
            return [PrintPage(number: 1, totalPages: 1, lines: lines)]
        }

        let chunks = stride(from: 0, to: lines.count, by: linesPerPage).map { startIndex in
            Array(lines[startIndex..<min(startIndex + linesPerPage, lines.count)])
        }
        let total = chunks.count
        return chunks.enumerated().map { index, lines in
            PrintPage(number: index + 1, totalPages: total, lines: lines)
        }
    }

    public func renderedPlainText(includeLineNumbers: Bool = true) -> String {
        let header = [title, languageDisplayName, encodingDisplayName]
            .filter { !$0.isEmpty }
            .joined(separator: "    ")
        let lines = normalizedLines
        let lineNumberWidth = max(String(lines.count).count, 4)
        let body = lines.enumerated().map { index, line in
            if includeLineNumbers {
                return "\(String(index + 1).leftPadded(to: lineNumberWidth))  \(line)"
            }
            return line
        }
        return ([header, String(repeating: "=", count: max(header.count, 1))] + body).joined(separator: "\n")
    }
}

public struct PrintPage: Codable, Equatable, Sendable {
    public let number: Int
    public let totalPages: Int
    public let lines: [String]

    public init(number: Int, totalPages: Int, lines: [String]) {
        self.number = number
        self.totalPages = totalPages
        self.lines = lines
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        guard count < width else { return self }
        return String(repeating: " ", count: width - count) + self
    }
}
