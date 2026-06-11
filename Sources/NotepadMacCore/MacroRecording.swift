import Foundation

public struct TextEditRange: Codable, Equatable, Hashable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = max(location, 0)
        self.length = max(length, 0)
    }

    var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

public enum MacroCommand: Codable, Equatable, Sendable {
    case replaceText(range: TextEditRange, replacement: String)

    public static func textEdit(from oldText: String, to newText: String) -> MacroCommand? {
        guard oldText != newText else { return nil }

        let old = oldText as NSString
        let new = newText as NSString
        let oldLength = old.length
        let newLength = new.length
        let sharedPrefixLimit = min(oldLength, newLength)

        var prefixLength = 0
        while prefixLength < sharedPrefixLimit,
              old.character(at: prefixLength) == new.character(at: prefixLength) {
            prefixLength += 1
        }

        var oldSuffixStart = oldLength
        var newSuffixStart = newLength
        while oldSuffixStart > prefixLength,
              newSuffixStart > prefixLength,
              old.character(at: oldSuffixStart - 1) == new.character(at: newSuffixStart - 1) {
            oldSuffixStart -= 1
            newSuffixStart -= 1
        }

        let replacementLength = newSuffixStart - prefixLength
        let replacement = replacementLength > 0
            ? new.substring(with: NSRange(location: prefixLength, length: replacementLength))
            : ""
        return .replaceText(
            range: TextEditRange(location: prefixLength, length: oldSuffixStart - prefixLength),
            replacement: replacement
        )
    }

    public func applying(to text: String) -> String? {
        switch self {
        case let .replaceText(range, replacement):
            let nsText = text as NSString
            guard range.location <= nsText.length,
                  range.location + range.length <= nsText.length
            else {
                return nil
            }
            return nsText.replacingCharacters(in: range.nsRange, with: replacement)
        }
    }
}

public struct MacroRecording: Codable, Equatable, Sendable {
    public let name: String
    public let commands: [MacroCommand]

    public init(name: String, commands: [MacroCommand] = []) {
        self.name = name
        self.commands = commands
    }

    public func appending(_ command: MacroCommand) -> MacroRecording {
        MacroRecording(name: name, commands: commands + [command])
    }

    public func recordingTextChange(from oldText: String, to newText: String) -> MacroRecording {
        guard let command = MacroCommand.textEdit(from: oldText, to: newText) else {
            return self
        }
        return appending(command)
    }

    public func replaying(on text: String) -> String? {
        var nextText = text
        for command in commands {
            guard let applied = command.applying(to: nextText) else {
                return nil
            }
            nextText = applied
        }
        return nextText
    }
}

public final class MacroStore {
    private enum Key {
        static let lastRecording = "notepadMac.lastMacroRecording"
        static let namedRecordings = "notepadMac.namedMacroRecordings"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadLastRecording() -> MacroRecording? {
        guard let data = defaults.data(forKey: Key.lastRecording) else { return nil }
        return try? decoder.decode(MacroRecording.self, from: data)
    }

    public func saveLastRecording(_ recording: MacroRecording) {
        guard let data = try? encoder.encode(recording) else { return }
        defaults.set(data, forKey: Key.lastRecording)
        defaults.synchronize()
    }

    public func clearLastRecording() {
        defaults.removeObject(forKey: Key.lastRecording)
        defaults.synchronize()
    }

    public func loadNamedRecordings() -> [MacroRecording] {
        guard let data = defaults.data(forKey: Key.namedRecordings),
              let recordings = try? decoder.decode([MacroRecording].self, from: data)
        else {
            return []
        }

        return recordings.filter { !$0.normalizedName.isEmpty && !$0.commands.isEmpty }
    }

    public func loadNamedRecording(named name: String) -> MacroRecording? {
        let normalizedName = name.normalizedMacroName
        guard !normalizedName.isEmpty else { return nil }

        return loadNamedRecordings().first { $0.normalizedName.caseInsensitiveCompare(normalizedName) == .orderedSame }
    }

    public func saveNamedRecording(_ recording: MacroRecording) {
        let normalizedRecording = recording.withNormalizedName()
        guard !normalizedRecording.name.isEmpty, !normalizedRecording.commands.isEmpty else { return }

        var recordings = loadNamedRecordings()
        if let existingIndex = recordings.firstIndex(where: {
            $0.normalizedName.caseInsensitiveCompare(normalizedRecording.name) == .orderedSame
        }) {
            recordings[existingIndex] = normalizedRecording
        } else {
            recordings.append(normalizedRecording)
        }

        saveNamedRecordings(recordings)
    }

    public func deleteNamedRecording(named name: String) {
        let normalizedName = name.normalizedMacroName
        guard !normalizedName.isEmpty else { return }

        let recordings = loadNamedRecordings().filter {
            $0.normalizedName.caseInsensitiveCompare(normalizedName) != .orderedSame
        }
        saveNamedRecordings(recordings)
    }

    public func clearNamedRecordings() {
        defaults.removeObject(forKey: Key.namedRecordings)
        defaults.synchronize()
    }

    private func saveNamedRecordings(_ recordings: [MacroRecording]) {
        let filteredRecordings = recordings
            .map { $0.withNormalizedName() }
            .filter { !$0.name.isEmpty && !$0.commands.isEmpty }

        guard !filteredRecordings.isEmpty else {
            clearNamedRecordings()
            return
        }

        guard let data = try? encoder.encode(filteredRecordings) else { return }
        defaults.set(data, forKey: Key.namedRecordings)
        defaults.synchronize()
    }
}

private extension MacroRecording {
    var normalizedName: String {
        name.normalizedMacroName
    }

    func withNormalizedName() -> MacroRecording {
        MacroRecording(name: normalizedName, commands: commands)
    }
}

private extension String {
    var normalizedMacroName: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
