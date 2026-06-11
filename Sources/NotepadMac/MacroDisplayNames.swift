import Foundation

enum MacroDisplayNames {
    static let placeholderRecordingName = "__notepad_last_macro__"

    private static let legacyPlaceholderRecordingNames = ["Last Macro"]

    static func editableName(for recordingName: String) -> String {
        isPlaceholderRecordingName(recordingName) ? "" : recordingName
    }

    static func isPlaceholderRecordingName(_ recordingName: String) -> Bool {
        let trimmedRecordingName = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecordingName.isEmpty else {
            return false
        }

        if trimmedRecordingName == placeholderRecordingName {
            return true
        }

        return legacyPlaceholderRecordingNames.contains {
            $0.caseInsensitiveCompare(trimmedRecordingName) == .orderedSame
        }
    }
}
