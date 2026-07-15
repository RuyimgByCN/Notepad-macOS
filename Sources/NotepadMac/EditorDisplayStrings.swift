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

    /// Default name shown in Save / Save As / Save a Copy As.
    /// - Parameter untitledBaseName: Numbered untitled tab name when the buffer
    ///   has no path yet (e.g. `"新文件1"`, `"Untitled2"`). Used as the base of
    ///   the suggested filename so Save As matches the tab.
    /// - Parameter preferredExtension: Primary extension of the current syntax
    ///   language (e.g. `"swift"`, `"py"`). When `nil` or empty, uses `"txt"`.
    ///   Existing files always keep their on-disk name.
    func saveAsName(
        fileURL: URL?,
        untitledBaseName: String? = nil,
        preferredExtension: String? = nil
    ) -> String {
        if let fileURL {
            return fileURL.lastPathComponent
        }

        let fallbackBase = (untitledFileName as NSString).deletingPathExtension
        let trimmedBase = untitledBaseName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName: String
        if let trimmedBase, !trimmedBase.isEmpty {
            // Keep names like "新文件1" / "Untitled2" intact; only strip a real
            // extension if first-line-as-tab-name already included one.
            let withoutExtension = (trimmedBase as NSString).deletingPathExtension
            baseName = withoutExtension.isEmpty
                ? (fallbackBase.isEmpty ? "Untitled" : fallbackBase)
                : withoutExtension
        } else {
            baseName = fallbackBase.isEmpty ? "Untitled" : fallbackBase
        }

        let normalizedExtension: String
        if let preferredExtension {
            let cleaned = preferredExtension
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            normalizedExtension = cleaned.isEmpty ? "txt" : cleaned
        } else {
            let fromUntitled = (untitledFileName as NSString).pathExtension
            normalizedExtension = fromUntitled.isEmpty ? "txt" : fromUntitled.lowercased()
        }

        return "\(baseName).\(normalizedExtension)"
    }

    func windowTitle(displayName: String, isDirty: Bool) -> String {
        let title = String(format: windowTitleFormat, locale: Locale.current, displayName)
        return isDirty ? "*\(title)" : title
    }
}
