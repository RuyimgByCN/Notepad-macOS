import Foundation
import NotepadMacCore
import Testing

@Test func pluginCatalogInstallsNativePluginFolderIntoUserPluginDirectory() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makePluginFolder(
        named: "NativeTools",
        manifest: nativeToolsManifest(version: "1.0.0"),
        files: ["native-tools": "#!/bin/sh\nexit 0\n"]
    )

    let result = try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)

    #expect(result.action == .installed)
    #expect(result.plugin.identifier == "org.notepad-plus-plus.macnative.native-tools")
    #expect(result.destinationURL.lastPathComponent == "NativeTools")
    #expect(FileManager.default.fileExists(atPath: result.destinationURL.appending(path: "notepad-mac-plugin.json").path))
    #expect(FileManager.default.fileExists(atPath: result.destinationURL.appending(path: "native-tools").path))

    let installedCatalog = PluginCatalog.scan(directories: [fixture.userPluginDirectory])
    let installedPlugin = try #require(installedCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.native-tools"))
    #expect(installedPlugin.displayName == "Native Tools")
    #expect(installedPlugin.version == "1.0.0")
}

@Test func pluginCatalogUpdatesExistingNativePluginFolder() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makePluginFolder(
        named: "NativeTools",
        manifest: nativeToolsManifest(version: "2.0.0"),
        files: ["native-tools": "#!/bin/sh\nexit 0\n"]
    )
    let destination = fixture.userPluginDirectory.appending(path: "NativeTools")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try "stale".write(to: destination.appending(path: "stale.txt"), atomically: true, encoding: .utf8)
    try nativeToolsManifest(version: "1.0.0")
        .write(to: destination.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)

    let result = try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)

    #expect(result.action == .updated)
    #expect(result.destinationURL == destination.standardizedFileURL)
    #expect(!FileManager.default.fileExists(atPath: destination.appending(path: "stale.txt").path))

    let installedCatalog = PluginCatalog.scan(directories: [fixture.userPluginDirectory])
    let installedPlugin = try #require(installedCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.native-tools"))
    #expect(installedPlugin.version == "2.0.0")
}

@Test func pluginCatalogRejectsUpdateCollisionWithDifferentManifestIdentifier() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makePluginFolder(
        named: "NativeTools",
        manifest: companionToolsManifest(version: "1.0.0"),
        files: ["companion-tools": "#!/bin/sh\nexit 0\n"]
    )
    let destination = fixture.userPluginDirectory.appending(path: "NativeTools")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try "enabled".write(to: destination.appending(path: "native-tools"), atomically: true, encoding: .utf8)
    try nativeToolsManifest(version: "1.0.0")
        .write(to: destination.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)

    #expect(throws: PluginInstallationError.invalidManifest(
        destination.appending(path: "notepad-mac-plugin.json").standardizedFileURL,
        reason: "Installed plugin identifier org.notepad-plus-plus.macnative.native-tools does not match selected plugin identifier org.notepad-plus-plus.macnative.companion-tools. Choose a different plugin folder name or remove the installed plugin first."
    )) {
        try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)
    }

    let installedCatalog = PluginCatalog.scan(directories: [fixture.userPluginDirectory])
    let installedPlugin = try #require(installedCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.native-tools"))
    #expect(installedPlugin.version == "1.0.0")
    #expect(installedCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.companion-tools") == nil)
    #expect(FileManager.default.fileExists(atPath: destination.appending(path: "native-tools").path))
    #expect(!FileManager.default.fileExists(atPath: destination.appending(path: "companion-tools").path))
}

@Test func pluginCatalogRejectsPluginFolderWithoutManifest() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makeFolder(named: "NppExec")
    try Data([0x4D, 0x5A]).write(to: source.appending(path: "NppExec.dll"))

    #expect(throws: PluginInstallationError.missingManifest(source.appending(path: "notepad-mac-plugin.json").standardizedFileURL)) {
        try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)
    }
    #expect(!FileManager.default.fileExists(atPath: fixture.userPluginDirectory.appending(path: "NppExec").path))
}

@Test func pluginCatalogRejectsWindowsDllOnlyManifestFolder() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makePluginFolder(
        named: "NppExec",
        manifest: """
        {
          "identifier": "org.notepad-plus-plus.windows.nppexec",
          "name": "NppExec",
          "version": "1.0.0",
          "entryPoint": "NppExec.dll",
          "commands": [
            { "identifier": "run", "title": "Run" }
          ]
        }
        """,
        files: ["NppExec.dll": "MZ"]
    )

    #expect(throws: PluginInstallationError.windowsDLLOnly(source.standardizedFileURL)) {
        try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)
    }
    #expect(!FileManager.default.fileExists(atPath: fixture.userPluginDirectory.appending(path: "NppExec").path))
}

@Test func pluginCatalogFallsBackToSafeIdentifierForBlankSourceFolderName() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makePluginFolder(
        named: "   ",
        manifest: nativeToolsManifest(version: "1.0.0"),
        files: ["native-tools": "#!/bin/sh\nexit 0\n"]
    )

    let result = try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)

    #expect(result.destinationURL.lastPathComponent == "org.notepad-plus-plus.macnative.native-tools")
    #expect(FileManager.default.fileExists(atPath: result.destinationURL.appending(path: "notepad-mac-plugin.json").path))
}

@Test func pluginCatalogRemovesInstalledNativeManifestPluginFolder() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let source = try fixture.makePluginFolder(
        named: "NativeTools",
        manifest: nativeToolsManifest(version: "1.0.0"),
        files: ["native-tools": "#!/bin/sh\nexit 0\n"]
    )
    let installResult = try PluginCatalog.installNativePlugin(from: source, into: fixture.userPluginDirectory)

    let removalResult = try PluginCatalog.removeNativePlugin(installResult.plugin, from: fixture.userPluginDirectory)

    #expect(removalResult.plugin.identifier == "org.notepad-plus-plus.macnative.native-tools")
    #expect(removalResult.removedURL == installResult.destinationURL)
    #expect(!FileManager.default.fileExists(atPath: installResult.destinationURL.path))
    #expect(PluginCatalog.scan(directories: [fixture.userPluginDirectory]).plugins.isEmpty)
}

@Test func pluginCatalogRejectsRemovingWindowsOnlyPlugin() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let plugin = PluginDescriptor(
        identifier: "windows-dll:NppExec.dll",
        displayName: "NppExec",
        kind: .windowsDLL,
        compatibility: .windowsOnly(reason: PluginCompatibility.windowsDLLReason),
        directoryURL: fixture.userPluginDirectory,
        entryURL: fixture.userPluginDirectory.appending(path: "NppExec.dll")
    )

    #expect(throws: PluginRemovalError.windowsOnlyPlugin(plugin.entryURL!)) {
        try PluginCatalog.removeNativePlugin(plugin, from: fixture.userPluginDirectory)
    }
}

@Test func pluginCatalogRejectsRemovingNativePluginOutsideUserPluginDirectory() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let outsidePluginDirectory = fixture.rootURL
        .appending(path: "Outside")
        .appending(path: "NativeTools")
    try FileManager.default.createDirectory(at: outsidePluginDirectory, withIntermediateDirectories: true)
    try nativeToolsManifest(version: "1.0.0")
        .write(to: outsidePluginDirectory.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)
    let traversalURL = URL(fileURLWithPath: "\(fixture.userPluginDirectory.path)/../../../Outside/NativeTools")

    let plugin = PluginDescriptor(
        identifier: "org.notepad-plus-plus.macnative.native-tools",
        displayName: "Native Tools",
        version: "1.0.0",
        kind: .nativeManifest,
        compatibility: .nativeCompatible,
        directoryURL: traversalURL
    )

    #expect(throws: PluginRemovalError.nonUserPluginLocation(
        pluginDirectoryURL: outsidePluginDirectory.standardizedFileURL,
        userPluginDirectoryURL: fixture.userPluginDirectory.standardizedFileURL
    )) {
        try PluginCatalog.removeNativePlugin(plugin, from: fixture.userPluginDirectory)
    }
    #expect(FileManager.default.fileExists(atPath: outsidePluginDirectory.path))
}

@Test func pluginCatalogReportsMissingNativePluginFolderDuringRemoval() throws {
    let fixture = try PluginCatalogInstallationFixture()
    defer { fixture.cleanup() }

    let missingDirectory = fixture.userPluginDirectory.appending(path: "NativeTools")
    let plugin = PluginDescriptor(
        identifier: "org.notepad-plus-plus.macnative.native-tools",
        displayName: "Native Tools",
        version: "1.0.0",
        kind: .nativeManifest,
        compatibility: .nativeCompatible,
        directoryURL: missingDirectory
    )

    #expect(throws: PluginRemovalError.missingPluginDirectory(missingDirectory.standardizedFileURL)) {
        try PluginCatalog.removeNativePlugin(plugin, from: fixture.userPluginDirectory)
    }
}

private struct PluginCatalogInstallationFixture {
    let rootURL: URL
    let sourceRootURL: URL
    let userPluginDirectory: URL

    init() throws {
        rootURL = URL(filePath: NSTemporaryDirectory())
            .appending(path: "NotepadMacPluginInstallTests-\(UUID().uuidString)")
        sourceRootURL = rootURL.appending(path: "Source")
        userPluginDirectory = rootURL.appending(path: "Application Support/Notepad++ Mac/Plugins")
        try FileManager.default.createDirectory(at: sourceRootURL, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func makeFolder(named name: String) throws -> URL {
        let folder = sourceRootURL.appending(path: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func makePluginFolder(named name: String, manifest: String, files: [String: String]) throws -> URL {
        let folder = try makeFolder(named: name)
        try manifest.write(to: folder.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)
        for (relativePath, contents) in files {
            let fileURL = folder.appending(path: relativePath)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return folder
    }
}

private func nativeToolsManifest(version: String) -> String {
    """
    {
      "identifier": "org.notepad-plus-plus.macnative.native-tools",
      "name": "Native Tools",
      "version": "\(version)",
      "entryPoint": "native-tools",
      "commands": [
        { "identifier": "uppercase", "title": "Uppercase Document" }
      ]
    }
    """
}

private func companionToolsManifest(version: String) -> String {
    """
    {
      "identifier": "org.notepad-plus-plus.macnative.companion-tools",
      "name": "Companion Tools",
      "version": "\(version)",
      "entryPoint": "companion-tools",
      "commands": [
        { "identifier": "inspect", "title": "Inspect Document" }
      ]
    }
    """
}
