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

    /// ASCII form feed (page break) character.
    public static let formFeed = "\u{000C}"

    public var normalizedLines: [String] {
        Self.lines(from: text, stripFormFeed: true)
    }

    /// Line sequences for each form-feed section (form feeds themselves are not lines).
    public var formFeedSections: [[String]] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let sections = normalized.components(separatedBy: Self.formFeed)
        return sections.map { Self.lines(from: $0, stripFormFeed: true) }
    }

    public func pages(linesPerPage: Int, formFeedPageBreak: Bool = false) -> [PrintPage] {
        if formFeedPageBreak {
            return pagesHonoringFormFeed(linesPerPage: linesPerPage)
        }
        return pagesFromLines(normalizedLines, linesPerPage: linesPerPage)
    }

    public func renderedPlainText(
        includeLineNumbers: Bool = true,
        formFeedPageBreak: Bool = false
    ) -> String {
        let header = [title, languageDisplayName, encodingDisplayName]
            .filter { !$0.isEmpty }
            .joined(separator: "    ")
        let headerBlock = [header, String(repeating: "=", count: max(header.count, 1))]

        if formFeedPageBreak {
            // Keep form feeds so the print view can force page breaks between sections.
            var globalLine = 0
            var bodyLines: [String] = []
            let allLineCount = formFeedSections.reduce(0) { $0 + $1.count }
            let lineNumberWidth = max(String(max(allLineCount, 1)).count, 4)
            for (sectionIndex, section) in formFeedSections.enumerated() {
                if sectionIndex > 0 {
                    bodyLines.append(Self.formFeed)
                }
                for line in section {
                    globalLine += 1
                    if includeLineNumbers {
                        bodyLines.append("\(String(globalLine).leftPadded(to: lineNumberWidth))  \(line)")
                    } else {
                        bodyLines.append(line)
                    }
                }
            }
            if bodyLines.isEmpty {
                bodyLines = [includeLineNumbers ? "\(String(1).leftPadded(to: 4))  " : ""]
            }
            return (headerBlock + bodyLines).joined(separator: "\n")
        }

        let lines = normalizedLines
        let lineNumberWidth = max(String(lines.count).count, 4)
        let body = lines.enumerated().map { index, line in
            if includeLineNumbers {
                return "\(String(index + 1).leftPadded(to: lineNumberWidth))  \(line)"
            }
            return line
        }
        return (headerBlock + body).joined(separator: "\n")
    }

    private func pagesHonoringFormFeed(linesPerPage: Int) -> [PrintPage] {
        var collected: [[String]] = []
        for section in formFeedSections {
            if linesPerPage > 0 {
                let chunks = stride(from: 0, to: max(section.count, 1), by: linesPerPage).map { start in
                    if section.isEmpty { return [""] as [String] }
                    return Array(section[start..<min(start + linesPerPage, section.count)])
                }
                // Empty section still produces a blank page so consecutive form feeds work.
                if section.isEmpty {
                    collected.append([""])
                } else {
                    collected.append(contentsOf: chunks)
                }
            } else {
                collected.append(section.isEmpty ? [""] : section)
            }
        }
        if collected.isEmpty {
            collected = [[""]]
        }
        let total = collected.count
        return collected.enumerated().map { index, lines in
            PrintPage(number: index + 1, totalPages: total, lines: lines)
        }
    }

    private func pagesFromLines(_ lines: [String], linesPerPage: Int) -> [PrintPage] {
        guard linesPerPage > 0 else {
            return [PrintPage(number: 1, totalPages: 1, lines: lines)]
        }

        let chunks = stride(from: 0, to: lines.count, by: linesPerPage).map { startIndex in
            Array(lines[startIndex..<min(startIndex + linesPerPage, lines.count)])
        }
        let total = max(chunks.count, 1)
        if chunks.isEmpty {
            return [PrintPage(number: 1, totalPages: 1, lines: [""])]
        }
        return chunks.enumerated().map { index, lines in
            PrintPage(number: index + 1, totalPages: total, lines: lines)
        }
    }

    private static func lines(from text: String, stripFormFeed: Bool) -> [String] {
        var normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if stripFormFeed {
            normalized = normalized.replacingOccurrences(of: formFeed, with: "")
        }
        var lines = normalized.components(separatedBy: "\n")

        if lines.last == "" {
            lines.removeLast()
        }

        return lines.isEmpty ? [""] : lines
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
