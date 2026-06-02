import Foundation

public struct FileChangeSnapshot: Codable, Equatable, Sendable {
    public let url: URL
    public let modificationDate: Date
    public let byteCount: Int64

    public init(url: URL, modificationDate: Date, byteCount: Int64) {
        self.url = url.standardizedFileURL
        self.modificationDate = modificationDate
        self.byteCount = byteCount
    }

    public static func capture(_ url: URL) throws -> FileChangeSnapshot {
        let standardizedURL = url.standardizedFileURL
        let values = try standardizedURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])

        guard let modificationDate = values.contentModificationDate,
              let fileSize = values.fileSize
        else {
            throw FileChangeSnapshotError.missingMetadata(standardizedURL.path)
        }

        return FileChangeSnapshot(
            url: standardizedURL,
            modificationDate: modificationDate,
            byteCount: Int64(fileSize)
        )
    }

    public static func captureIfPresent(_ url: URL) -> FileChangeSnapshot? {
        try? capture(url)
    }

    public func changeStatus(comparedTo current: FileChangeSnapshot?) -> FileChangeStatus {
        guard let current else { return .deleted }

        if current.url == url,
           current.modificationDate == modificationDate,
           current.byteCount == byteCount {
            return .unchanged
        }

        return .modified(current)
    }
}

public enum FileChangeStatus: Equatable, Sendable {
    case unchanged
    case modified(FileChangeSnapshot)
    case deleted
}

public enum FileChangeSnapshotError: Error, Equatable, Sendable {
    case missingMetadata(String)
}
