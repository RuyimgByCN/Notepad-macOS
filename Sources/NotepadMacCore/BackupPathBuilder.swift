import Foundation

public enum BackupOnSaveMode: String, Codable, Equatable, Sendable, CaseIterable {
    case none
    case simple
    case verbose
}

public enum BackupPathBuilder {
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    public static func backupURL(
        for originalFile: URL,
        mode: BackupOnSaveMode,
        useCustomDirectory: Bool,
        customDirectory: String
    ) -> URL? {
        guard mode != .none else { return nil }

        let fileName = originalFile.lastPathComponent
        let baseDirectory: URL
        if useCustomDirectory, !customDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseDirectory = URL(fileURLWithPath: customDirectory, isDirectory: true)
        } else {
            baseDirectory = originalFile.deletingLastPathComponent()
        }

        switch mode {
        case .none:
            return nil
        case .simple:
            let ext = originalFile.pathExtension
            if ext.isEmpty {
                return baseDirectory.appendingPathComponent("\(fileName).bak")
            }
            let stem = originalFile.deletingPathExtension().lastPathComponent
            return baseDirectory.appendingPathComponent("\(stem).\(ext).bak")
        case .verbose:
            let verboseDirectory = baseDirectory.appendingPathComponent("nppBackup", isDirectory: true)
            let timestamp = timestampFormatter.string(from: Date())
            let ext = originalFile.pathExtension
            if ext.isEmpty {
                return verboseDirectory.appendingPathComponent("\(fileName).\(timestamp).bak")
            }
            let stem = originalFile.deletingPathExtension().lastPathComponent
            return verboseDirectory.appendingPathComponent("\(stem).\(ext).\(timestamp).bak")
        }
    }

    public static func ensureParentDirectoryExists(for url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
