import Foundation

public struct DocumentSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let originalFile: URL?
    public let backupFile: URL
    public let encodingRawValue: UInt
    public let lineEnding: LineEnding
    public let preservesByteOrderMark: Bool
    public let languageName: String?

    public var encoding: String.Encoding {
        String.Encoding(rawValue: encodingRawValue)
    }

    public init(
        id: String,
        displayName: String,
        originalFile: URL?,
        backupFile: URL,
        encoding: String.Encoding,
        lineEnding: LineEnding,
        preservesByteOrderMark: Bool = false,
        languageName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName.isEmpty ? "Untitled" : displayName
        self.originalFile = originalFile?.standardizedFileURL
        self.backupFile = backupFile.standardizedFileURL
        self.encodingRawValue = encoding.rawValue
        self.lineEnding = lineEnding
        self.preservesByteOrderMark = preservesByteOrderMark
        self.languageName = languageName
    }
}

extension DocumentSnapshot {
    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case originalFile
        case backupFile
        case encodingRawValue
        case lineEnding
        case preservesByteOrderMark
        case languageName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            displayName: try container.decode(String.self, forKey: .displayName),
            originalFile: try container.decodeIfPresent(URL.self, forKey: .originalFile),
            backupFile: try container.decode(URL.self, forKey: .backupFile),
            encoding: String.Encoding(rawValue: try container.decode(UInt.self, forKey: .encodingRawValue)),
            lineEnding: try container.decode(LineEnding.self, forKey: .lineEnding),
            preservesByteOrderMark: try container.decodeIfPresent(Bool.self, forKey: .preservesByteOrderMark) ?? false,
            languageName: try container.decodeIfPresent(String.self, forKey: .languageName)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(originalFile, forKey: .originalFile)
        try container.encode(backupFile, forKey: .backupFile)
        try container.encode(encodingRawValue, forKey: .encodingRawValue)
        try container.encode(lineEnding, forKey: .lineEnding)
        try container.encode(preservesByteOrderMark, forKey: .preservesByteOrderMark)
        try container.encodeIfPresent(languageName, forKey: .languageName)
    }
}

public struct DocumentSnapshotDraft {
    public let id: String?
    public let displayName: String
    public let originalFile: URL?
    public let text: String
    public let encoding: String.Encoding
    public let lineEnding: LineEnding
    public let preservesByteOrderMark: Bool
    public let languageName: String?

    public init(
        id: String?,
        displayName: String,
        originalFile: URL?,
        text: String,
        encoding: String.Encoding,
        lineEnding: LineEnding,
        preservesByteOrderMark: Bool = false,
        languageName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName.isEmpty ? "Untitled" : displayName
        self.originalFile = originalFile?.standardizedFileURL
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.preservesByteOrderMark = preservesByteOrderMark
        self.languageName = languageName
    }
}

public final class SnapshotStore {
    private let directory: URL
    private let now: () -> Date
    private let idGenerator: () -> String

    public init(
        directory: URL = SnapshotStore.defaultDirectory(),
        now: @escaping () -> Date = Date.init,
        idGenerator: @escaping () -> String = { UUID().uuidString }
    ) {
        self.directory = directory.standardizedFileURL
        self.now = now
        self.idGenerator = idGenerator
    }

    public func save(_ draft: DocumentSnapshotDraft) throws -> DocumentSnapshot {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let id = draft.id ?? idGenerator()
        let backupFile = directory.appending(path: backupFileName(displayName: draft.displayName, id: id))
        guard let data = draft.text.data(using: .utf8) else {
            throw SnapshotStoreError.invalidUTF8
        }

        try data.write(to: backupFile, options: .atomic)

        return DocumentSnapshot(
            id: id,
            displayName: draft.displayName,
            originalFile: draft.originalFile,
            backupFile: backupFile,
            encoding: draft.encoding,
            lineEnding: draft.lineEnding,
            preservesByteOrderMark: draft.preservesByteOrderMark,
            languageName: draft.languageName
        )
    }

    public func loadText(for snapshot: DocumentSnapshot) throws -> String {
        let data = try Data(contentsOf: snapshot.backupFile)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SnapshotStoreError.invalidUTF8
        }
        return text
    }

    public func delete(_ snapshot: DocumentSnapshot) throws {
        guard FileManager.default.fileExists(atPath: snapshot.backupFile.path) else { return }
        try FileManager.default.removeItem(at: snapshot.backupFile)
    }

    public func prune(keeping snapshots: [DocumentSnapshot]) throws {
        try prune(keepingBackupFiles: snapshots.map(\.backupFile))
    }

    private func prune(keepingBackupFiles backupFiles: [URL]) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }

        let keptPaths = Set(backupFiles.map { $0.standardizedFileURL.path })
        let existingFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        for file in existingFiles where file.pathExtension == "bak" && !keptPaths.contains(file.standardizedFileURL.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    private func backupFileName(displayName: String, id: String) -> String {
        "\(sanitized(displayName))@\(timestamp())-\(sanitized(id)).bak"
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: now())
    }

    private func sanitized(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\")
            .union(.newlines)
            .union(.controlCharacters)
        let parts = name.components(separatedBy: invalidCharacters)
        let result = parts.joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Untitled" : result
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return base.appending(path: "Notepad++ Mac/backup")
    }
}

public enum SnapshotStoreError: Error, Equatable, Sendable {
    case invalidUTF8
}
