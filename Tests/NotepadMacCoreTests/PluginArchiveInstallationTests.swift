import Foundation
import NotepadMacCore
import Testing

private struct PluginArchiveFixture {
    let rootURL: URL
    let userPluginDirectory: URL

    init() throws {
        rootURL = URL(filePath: NSTemporaryDirectory())
            .appending(path: "NotepadMacPluginArchiveTests-\(UUID().uuidString)")
        userPluginDirectory = rootURL.appending(path: "Plugins")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func makePluginFolder(named name: String, version: String) throws -> URL {
        let folder = rootURL.appending(path: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest = """
        {
          "identifier": "org.notepad-plus-plus.macnative.archive-tools",
          "name": "Archive Tools",
          "version": "\(version)",
          "entryPoint": "archive-tools",
          "commands": [
            { "identifier": "noop", "title": "No-op" }
          ]
        }
        """
        try manifest.write(
            to: folder.appending(path: "notepad-mac-plugin.json"),
            atomically: true, encoding: .utf8)
        try "#!/bin/sh\nexit 0\n".write(
            to: folder.appending(path: "archive-tools"),
            atomically: true, encoding: .utf8)
        return folder
    }

    /// Zips `folder` with ditto. `wrapped: true` zips the folder itself
    /// (archive root contains one wrapping directory); `false` zips the
    /// folder's contents at the archive root.
    func zip(_ folder: URL, named archiveName: String, wrapped: Bool) throws -> URL {
        let archiveURL = rootURL.appending(path: archiveName)
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        if wrapped {
            process.arguments = ["-c", "-k", "--keepParent", folder.path, archiveURL.path]
        } else {
            process.arguments = ["-c", "-k", folder.path, archiveURL.path]
        }
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "ditto failed to create test archive")
        return archiveURL
    }
}

@Test func pluginCatalogInstallsPluginFromZipWithWrappingFolder() throws {
    let fixture = try PluginArchiveFixture()
    defer { fixture.cleanup() }

    let folder = try fixture.makePluginFolder(named: "ArchiveTools", version: "1.0.0")
    let archive = try fixture.zip(folder, named: "ArchiveTools.zip", wrapped: true)

    let result = try PluginCatalog.installNativePlugin(
        fromArchive: archive, into: fixture.userPluginDirectory)

    #expect(result.action == .installed)
    #expect(result.plugin.identifier == "org.notepad-plus-plus.macnative.archive-tools")
    #expect(FileManager.default.fileExists(
        atPath: result.destinationURL.appending(path: "notepad-mac-plugin.json").path))
}

@Test func pluginCatalogInstallsPluginFromZipWithManifestAtArchiveRoot() throws {
    let fixture = try PluginArchiveFixture()
    defer { fixture.cleanup() }

    let folder = try fixture.makePluginFolder(named: "ArchiveTools", version: "1.0.0")
    let archive = try fixture.zip(folder, named: "flat.zip", wrapped: false)

    let result = try PluginCatalog.installNativePlugin(
        fromArchive: archive, into: fixture.userPluginDirectory)
    #expect(result.action == .installed)
}

@Test func pluginCatalogReportsVersionTransitionWhenUpdatingFromArchive() throws {
    let fixture = try PluginArchiveFixture()
    defer { fixture.cleanup() }

    let v1 = try fixture.makePluginFolder(named: "ArchiveToolsV1", version: "1.0.0")
    _ = try PluginCatalog.installNativePlugin(from: v1, into: fixture.userPluginDirectory)

    let v2 = try fixture.makePluginFolder(named: "ArchiveToolsV2", version: "2.0.0")
    let archive = try fixture.zip(v2, named: "v2.zip", wrapped: true)
    let result = try PluginCatalog.installNativePlugin(
        fromArchive: archive, into: fixture.userPluginDirectory)

    #expect(result.action == .updated)
    #expect(result.previousVersion == "1.0.0")
    #expect(result.plugin.version == "2.0.0")
}

@Test func pluginCatalogRejectsArchiveWithoutManifest() throws {
    let fixture = try PluginArchiveFixture()
    defer { fixture.cleanup() }

    let folder = fixture.rootURL.appending(path: "NoManifest")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try "data".write(to: folder.appending(path: "readme.txt"), atomically: true, encoding: .utf8)
    let archive = try fixture.zip(folder, named: "nomanifest.zip", wrapped: true)

    #expect(throws: PluginInstallationError.archiveMissingManifest(archive)) {
        _ = try PluginCatalog.installNativePlugin(
            fromArchive: archive, into: fixture.userPluginDirectory)
    }
}

@Test func pluginCatalogRejectsCorruptArchive() throws {
    let fixture = try PluginArchiveFixture()
    defer { fixture.cleanup() }

    let archive = fixture.rootURL.appending(path: "corrupt.zip")
    try Data([0x00, 0x01, 0x02, 0x03]).write(to: archive)

    #expect(throws: PluginInstallationError.self) {
        _ = try PluginCatalog.installNativePlugin(
            fromArchive: archive, into: fixture.userPluginDirectory)
    }
}

@Test func pluginCatalogDirectoryInstallReportsPreviousVersion() throws {
    let fixture = try PluginArchiveFixture()
    defer { fixture.cleanup() }

    let v1 = try fixture.makePluginFolder(named: "DirToolsV1", version: "1.2.0")
    _ = try PluginCatalog.installNativePlugin(from: v1, into: fixture.userPluginDirectory)

    let v2 = try fixture.makePluginFolder(named: "DirToolsV2", version: "1.3.0")
    let result = try PluginCatalog.installNativePlugin(from: v2, into: fixture.userPluginDirectory)
    #expect(result.action == .updated)
    #expect(result.previousVersion == "1.2.0")
}
