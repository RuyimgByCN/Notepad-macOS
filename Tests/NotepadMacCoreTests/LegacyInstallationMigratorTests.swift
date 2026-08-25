import Foundation
import Testing
@testable import NotepadMacCore

@Suite struct LegacyInstallationMigratorTests {
    @Test func migratesLegacyPreferencesSessionAndSupportDirectory() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let openFile = fixture.root.appending(path: "open.txt")
        let backupFile = fixture.legacySupport.appending(path: "backup/Untitled-old.bak")
        try FileManager.default.createDirectory(
            at: backupFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "unsaved".write(to: backupFile, atomically: true, encoding: .utf8)
        try "open".write(to: openFile, atomically: true, encoding: .utf8)

        fixture.currentDefaults.set(["/current/recent.txt"], forKey: "notepadMac.recentFiles.urls")
        fixture.legacyDefaults.set(["/legacy/recent.txt"], forKey: "notepadMac.recentFiles.urls")
        fixture.legacyDefaults.set(37, forKey: "notepadMac.recentFilesMaxCount")
        SessionStore(defaults: fixture.legacyDefaults).save(AppSession(
            openFiles: [openFile],
            activeFile: openFile,
            snapshots: [DocumentSnapshot(
                id: "legacy-snapshot",
                displayName: "Untitled",
                originalFile: nil,
                backupFile: backupFile,
                encoding: .utf8,
                lineEnding: .lf
            )]
        ))

        try fixture.migrator.migrate()

        let session = SessionStore(defaults: fixture.currentDefaults).load()
        let migratedBackup = try #require(session.snapshots.first?.backupFile)
        #expect(session.openFiles == [openFile.standardizedFileURL])
        #expect(migratedBackup.path.hasPrefix(fixture.currentSupport.path + "/"))
        #expect(try String(contentsOf: migratedBackup, encoding: .utf8) == "unsaved")
        #expect(fixture.currentDefaults.stringArray(forKey: "notepadMac.recentFiles.urls") == ["/current/recent.txt"])
        #expect(fixture.currentDefaults.integer(forKey: "notepadMac.recentFilesMaxCount") == 37)
        #expect(!FileManager.default.fileExists(atPath: fixture.legacySupport.path))
        #expect(fixture.currentDefaults.persistentDomain(forName: fixture.legacyDomain) == nil)
    }

    @Test func preservesBothFilesWhenLegacyAndCurrentContentsConflict() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }

        let relativePath = "backup/Untitled-conflict.bak"
        let legacyFile = fixture.legacySupport.appending(path: relativePath)
        let currentFile = fixture.currentSupport.appending(path: relativePath)
        try FileManager.default.createDirectory(at: legacyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: currentFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "legacy".write(to: legacyFile, atomically: true, encoding: .utf8)
        try "current".write(to: currentFile, atomically: true, encoding: .utf8)
        SessionStore(defaults: fixture.legacyDefaults).save(AppSession(
            openFiles: [],
            activeFile: nil,
            snapshots: [DocumentSnapshot(
                id: "conflict",
                displayName: "Untitled",
                originalFile: nil,
                backupFile: legacyFile,
                encoding: .utf8,
                lineEnding: .lf
            )]
        ))

        try fixture.migrator.migrate()

        let snapshot = try #require(SessionStore(defaults: fixture.currentDefaults).load().snapshots.first)
        #expect(try String(contentsOf: currentFile, encoding: .utf8) == "current")
        #expect(snapshot.backupFile != currentFile.standardizedFileURL)
        #expect(try String(contentsOf: snapshot.backupFile, encoding: .utf8) == "legacy")
    }

    private final class Fixture {
        let root: URL
        let currentSupport: URL
        let legacySupport: URL
        let currentDomain = "test.notepad.current.\(UUID().uuidString)"
        let legacyDomain = "test.notepad.legacy.\(UUID().uuidString)"
        let currentDefaults: UserDefaults
        let legacyDefaults: UserDefaults
        let migrator: LegacyInstallationMigrator

        init() throws {
            root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            currentSupport = root.appending(path: "Notepad Mac")
            legacySupport = root.appending(path: "Notepad++ Mac")
            currentDefaults = try #require(UserDefaults(suiteName: currentDomain))
            legacyDefaults = try #require(UserDefaults(suiteName: legacyDomain))
            migrator = LegacyInstallationMigrator(
                currentDefaults: currentDefaults,
                legacyDefaults: legacyDefaults,
                currentDomainName: currentDomain,
                legacyDomainName: legacyDomain,
                legacySupportDirectory: legacySupport,
                currentSupportDirectory: currentSupport
            )
        }

        func cleanUp() {
            currentDefaults.removePersistentDomain(forName: currentDomain)
            legacyDefaults.removePersistentDomain(forName: legacyDomain)
            try? FileManager.default.removeItem(at: root)
        }
    }
}
