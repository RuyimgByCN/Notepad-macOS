import AppKit
import Foundation
import NotepadMacCore

@MainActor
protocol CharacterPalettePresenting: AnyObject {
    func orderFrontCharacterPalette(_ sender: Any?)
}

extension NSApplication: CharacterPalettePresenting {}

enum EditMenuDateTimeStyle {
    case short
    case long
    case custom(String)
}

enum EditDocumentClipboardMode {
    case fullPath
    case filename
    case directoryPath
}

enum EditSelectionTarget: Equatable {
    case file(URL)
    case web(URL)
}

enum SearchURLBuilderError: Error, Equatable {
    case missingQuery
}

enum EditMenuSupport {
    @MainActor
    static func presentCharacterPanel(using presenter: CharacterPalettePresenting, sender: Any?) {
        presenter.orderFrontCharacterPalette(sender)
    }

    static func dateTimeString(
        for date: Date,
        style: EditMenuDateTimeStyle,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        reverseOrder: Bool = false
    ) -> String {
        if case let .custom(pattern) = style {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        switch style {
        case .short:
            dateFormatter.dateStyle = .short
        case .long:
            dateFormatter.dateStyle = .long
        case .custom:
            dateFormatter.dateStyle = .none
        }
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let dateText = dateFormatter.string(from: date)
        let timeText = timeFormatter.string(from: date)

        return reverseOrder
            ? "\(dateText) \(timeText)"
            : "\(timeText) \(dateText)"
    }

    static func documentClipboardString(for fileURL: URL, mode: EditDocumentClipboardMode) -> String {
        switch mode {
        case .fullPath:
            return fileURL.path
        case .filename:
            return fileURL.lastPathComponent
        case .directoryPath:
            return fileURL.deletingLastPathComponent().path
        }
    }

    static func selectionTarget(
        in text: String,
        selectedRange: NSRange,
        currentFileURL: URL?
    ) -> EditSelectionTarget? {
        guard let candidate = selectionCandidate(in: text, selectedRange: selectedRange), !candidate.isEmpty else {
            return nil
        }

        if candidate.hasPrefix("http://") || candidate.hasPrefix("https://"),
           let url = URL(string: candidate) {
            return .web(url)
        }

        if candidate.hasPrefix("/") {
            return .file(URL(filePath: candidate))
        }

        guard let currentFileURL else {
            return nil
        }

        return .file(currentFileURL.deletingLastPathComponent().appending(path: candidate).standardizedFileURL)
    }

    static func searchURL(
        in text: String,
        selectedRange: NSRange,
        preferences: AppPreferences
    ) throws -> URL {
        guard let query = searchQuery(in: text, selectedRange: selectedRange), !query.isEmpty else {
            throw SearchURLBuilderError.missingQuery
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let template: String
        switch preferences.searchEngineChoice {
        case .custom:
            let trimmed = preferences.customSearchEngineURL.replacingOccurrences(of: " ", with: "")
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                template = trimmed
            } else {
                template = "https://www.google.com/search?q=$(CURRENT_WORD)"
            }
        case .duckDuckGo, .bing:
            template = "https://duckduckgo.com/?q=$(CURRENT_WORD)"
        case .google:
            template = "https://www.google.com/search?q=$(CURRENT_WORD)"
        case .yahoo:
            template = "https://search.yahoo.com/search?q=$(CURRENT_WORD)"
        case .stackOverflow:
            template = "https://stackoverflow.com/search?q=$(CURRENT_WORD)"
        }

        let urlString = template.replacingOccurrences(of: "$(CURRENT_WORD)", with: encodedQuery)
        return URL(string: urlString) ?? URL(string: "https://www.google.com/search?q=\(encodedQuery)")!
    }

    private static func selectionCandidate(in text: String, selectedRange: NSRange) -> String? {
        let nsText = text as NSString

        if selectedRange.length > 0 {
            return cleanedCandidate(nsText.substring(with: selectedRange))
        }

        let textLength = nsText.length
        guard textLength > 0 else { return nil }
        let location = min(max(0, selectedRange.location), max(0, textLength - 1))

        var start = location
        while start > 0, !isBoundary(nsText.character(at: start - 1)) {
            start -= 1
        }

        var end = location
        while end < textLength, !isBoundary(nsText.character(at: end)) {
            end += 1
        }

        guard end > start else { return nil }
        return cleanedCandidate(nsText.substring(with: NSRange(location: start, length: end - start)))
    }

    private static func searchQuery(in text: String, selectedRange: NSRange) -> String? {
        let nsText = text as NSString
        if selectedRange.length > 0 {
            let query = nsText.substring(with: selectedRange).trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty ? nil : query
        }

        let textLength = nsText.length
        guard textLength > 0 else { return nil }
        let location = min(max(0, selectedRange.location), max(0, textLength - 1))

        var start = location
        while start > 0, !isSearchBoundary(nsText.character(at: start - 1)) {
            start -= 1
        }

        var end = location
        while end < textLength, !isSearchBoundary(nsText.character(at: end)) {
            end += 1
        }

        guard end > start else { return nil }
        let query = nsText.substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }

    private static func cleanedCandidate(_ candidate: String) -> String {
        candidate.trimmingCharacters(in: CharacterSet(charactersIn: "\"'<>[](){} \t\r\n"))
    }

    private static func isBoundary(_ codeUnit: unichar) -> Bool {
        switch codeUnit {
        case 9, 10, 13, 32, 34, 39, 40, 41, 60, 62, 91, 93, 123, 125:
            return true
        default:
            return false
        }
    }

    private static func isSearchBoundary(_ codeUnit: unichar) -> Bool {
        switch codeUnit {
        case 9, 10, 13, 32, 34, 39, 40, 41, 60, 62, 91, 93, 123, 125:
            return true
        default:
            return false
        }
    }
}
