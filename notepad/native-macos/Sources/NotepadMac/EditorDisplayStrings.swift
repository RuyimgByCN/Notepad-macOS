import Foundation

struct EditorDisplayStrings {
    private static let legacyUntitledDocumentNames = ["Untitled"]

    let untitledDocumentName: String
    let untitledFileName: String
    let windowTitleFormat: String

    static func localized(
        localize: (Localization.Key, String) -> String = { key, defaultValue in
            Localization.string(key, default: defaultValue)
        }
    ) -> EditorDisplayStrings {
        EditorDisplayStrings(
            untitledDocumentName: localize(.editorUntitledDocumentName, "Untitled"),
            untitledFileName: localize(.editorUntitledFileName, "Untitled.txt"),
            windowTitleFormat: localize(.editorWindowTitleFormat, "%@ - Notepad++ Mac")
        )
    }

    func displayName(fileURL: URL?, fallbackDisplayName: String?) -> String {
        if let fileURL {
            return fileURL.lastPathComponent
        }

        guard let fallbackDisplayName else {
            return untitledDocumentName
        }

        let trimmedFallbackDisplayName = fallbackDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFallbackDisplayName.isEmpty {
            return untitledDocumentName
        }

        if Self.legacyUntitledDocumentNames.contains(where: {
            $0.caseInsensitiveCompare(trimmedFallbackDisplayName) == .orderedSame
        }) {
            return untitledDocumentName
        }

        return fallbackDisplayName
    }

    func saveAsName(fileURL: URL?) -> String {
        fileURL?.lastPathComponent ?? untitledFileName
    }

    func windowTitle(displayName: String, isDirty: Bool) -> String {
        let title = String(format: windowTitleFormat, locale: Locale.current, displayName)
        return isDirty ? "*\(title)" : title
    }
}
