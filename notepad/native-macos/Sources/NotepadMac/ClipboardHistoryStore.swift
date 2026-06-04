import Foundation

final class ClipboardHistoryStore {
    private(set) var entries: [String] = []
    private let maximumEntries: Int

    init(maximumEntries: Int = 25) {
        self.maximumEntries = max(1, maximumEntries)
    }

    func record(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return
        }

        entries.removeAll { $0 == text }
        entries.insert(text, at: 0)

        if entries.count > maximumEntries {
            entries.removeLast(entries.count - maximumEntries)
        }
    }
}
