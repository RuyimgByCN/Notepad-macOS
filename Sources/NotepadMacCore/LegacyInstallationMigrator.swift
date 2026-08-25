import Foundation

public struct LegacyInstallationMigrator {
    public static let currentDomainName = "org.notepad.macnative"
    public static let legacyDomainName = "org.notepad-plus-plus.macnative"

    private let currentDefaults: UserDefaults
    private let legacyDefaults: UserDefaults?
    private let currentDomainName: String
    private let legacyDomainName: String
    private let legacySupportDirectory: URL
    private let currentSupportDirectory: URL
    private let fileManager: FileManager

    public init(
        currentDefaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = nil,
        currentDomainName: String = Self.currentDomainName,
        legacyDomainName: String = Self.legacyDomainName,
        legacySupportDirectory: URL? = nil,
        currentSupportDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        self.currentDefaults = currentDefaults
        self.legacyDefaults = legacyDefaults ?? UserDefaults(suiteName: legacyDomainName)
        self.currentDomainName = currentDomainName
        self.legacyDomainName = legacyDomainName
        self.legacySupportDirectory = (legacySupportDirectory
            ?? applicationSupport.appending(path: "Notepad++ Mac")).standardizedFileURL
        self.currentSupportDirectory = (currentSupportDirectory
            ?? applicationSupport.appending(path: "Notepad Mac")).standardizedFileURL
        self.fileManager = fileManager
    }

    public func migrate() throws {
        guard let legacyDefaults else { return }
        let legacyDomain = legacyDefaults.persistentDomain(forName: legacyDomainName)
        let hasLegacySupport = fileManager.fileExists(atPath: legacySupportDirectory.path)
        guard legacyDomain != nil || hasLegacySupport else { return }

        let relocatedFiles = try copyLegacySupportContents()
        copyMissingPreferences(from: legacyDomain ?? [:])

        let sessionStore = SessionStore(defaults: currentDefaults, legacyDefaults: legacyDefaults)
        let session = sessionStore.load()
        let relocatedSession = AppSession(
            openFiles: session.openFiles,
            activeFile: session.activeFile,
            snapshots: session.snapshots.map { snapshot in
                guard let backupFile = relocatedFiles[snapshot.backupFile.standardizedFileURL.path] else {
                    return snapshot
                }
                return DocumentSnapshot(
                    id: snapshot.id,
                    displayName: snapshot.displayName,
                    originalFile: snapshot.originalFile,
                    backupFile: backupFile,
                    encoding: snapshot.encoding,
                    lineEnding: snapshot.lineEnding,
                    preservesByteOrderMark: snapshot.preservesByteOrderMark,
                    languageName: snapshot.languageName
                )
            },
            activeSnapshotID: session.activeSnapshotID,
            bookmarks: session.bookmarks,
            folds: session.folds,
            tabStates: session.tabStates,
            caretPositions: session.caretPositions
        )
        sessionStore.save(relocatedSession)

        if hasLegacySupport {
            try fileManager.removeItem(at: legacySupportDirectory)
        }
        legacyDefaults.removePersistentDomain(forName: legacyDomainName)
        legacyDefaults.synchronize()
    }

    private func copyMissingPreferences(from legacyDomain: [String: Any]) {
        let currentDomain = currentDefaults.persistentDomain(forName: currentDomainName) ?? [:]
        for (key, value) in legacyDomain where currentDomain[key] == nil {
            currentDefaults.set(value, forKey: key)
        }
        currentDefaults.synchronize()
    }

    private func copyLegacySupportContents() throws -> [String: URL] {
        guard fileManager.fileExists(atPath: legacySupportDirectory.path) else { return [:] }
        try fileManager.createDirectory(at: currentSupportDirectory, withIntermediateDirectories: true)

        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: legacySupportDirectory,
            includingPropertiesForKeys: Array(keys)
        ) else { return [:] }

        var relocatedFiles: [String: URL] = [:]
        for case let source as URL in enumerator {
            let relativePath = String(source.path.dropFirst(legacySupportDirectory.path.count + 1))
            let destination = currentSupportDirectory.appending(path: relativePath)
            if try source.resourceValues(forKeys: keys).isDirectory == true {
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                continue
            }

            let finalDestination: URL
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: source, to: destination)
                finalDestination = destination
            } else if fileManager.contentsEqual(atPath: source.path, andPath: destination.path) {
                finalDestination = destination
            } else {
                finalDestination = uniqueLegacyDestination(for: destination)
                try fileManager.copyItem(at: source, to: finalDestination)
            }
            relocatedFiles[source.standardizedFileURL.path] = finalDestination.standardizedFileURL
        }
        return relocatedFiles
    }

    private func uniqueLegacyDestination(for destination: URL) -> URL {
        let directory = destination.deletingLastPathComponent()
        let fileExtension = destination.pathExtension
        let baseName = destination.deletingPathExtension().lastPathComponent
        var suffix = 1
        while true {
            let label = suffix == 1 ? "\(baseName)-legacy" : "\(baseName)-legacy-\(suffix)"
            let candidate = directory.appending(path: label)
                .appendingPathExtension(fileExtension)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }
}
