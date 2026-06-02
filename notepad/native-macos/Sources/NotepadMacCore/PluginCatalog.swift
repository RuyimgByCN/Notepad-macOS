import Foundation

public struct PluginCommandDescriptor: Codable, Equatable, Hashable, Sendable {
    public let identifier: String
    public let title: String

    public init(identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }
}

public struct PluginManifest: Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String?
    public let entryPoint: String?
    public let commands: [PluginCommandDescriptor]

    public init(
        identifier: String,
        name: String,
        version: String? = nil,
        entryPoint: String? = nil,
        commands: [PluginCommandDescriptor] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version?.nilIfEmpty
        self.entryPoint = entryPoint?.nilIfEmpty
        self.commands = commands
    }
}

public struct PluginDescriptor: Equatable, Identifiable, Sendable {
    public let identifier: String
    public let displayName: String
    public let version: String?
    public let kind: PluginKind
    public let compatibility: PluginCompatibility
    public let directoryURL: URL
    public let entryURL: URL?
    public let commands: [PluginCommandDescriptor]

    public var id: String { identifier }

    public init(
        identifier: String,
        displayName: String,
        version: String? = nil,
        kind: PluginKind,
        compatibility: PluginCompatibility,
        directoryURL: URL,
        entryURL: URL? = nil,
        commands: [PluginCommandDescriptor] = []
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.kind = kind
        self.compatibility = compatibility
        self.directoryURL = directoryURL.standardizedFileURL
        self.entryURL = entryURL?.standardizedFileURL
        self.commands = commands
    }
}

public enum PluginInstallationAction: Codable, Equatable, Sendable {
    case installed
    case updated
    case unchanged
}

public struct PluginInstallationResult: Equatable, Sendable {
    public let plugin: PluginDescriptor
    public let destinationURL: URL
    public let action: PluginInstallationAction

    public init(plugin: PluginDescriptor, destinationURL: URL, action: PluginInstallationAction) {
        self.plugin = plugin
        self.destinationURL = destinationURL.standardizedFileURL
        self.action = action
    }
}

public struct PluginRemovalResult: Equatable, Sendable {
    public let plugin: PluginDescriptor
    public let removedURL: URL

    public init(plugin: PluginDescriptor, removedURL: URL) {
        self.plugin = plugin
        self.removedURL = removedURL.standardizedFileURL
    }
}

public enum PluginInstallationError: Error, Equatable, Sendable {
    case userPluginDirectoryUnavailable
    case sourceNotDirectory(URL)
    case missingManifest(URL)
    case invalidManifest(URL, reason: String)
    case windowsDLLOnly(URL)
    case invalidDestinationName(sourceFolderName: String, pluginIdentifier: String)
}

public enum PluginRemovalError: Error, Equatable, Sendable {
    case userPluginDirectoryUnavailable
    case windowsOnlyPlugin(URL)
    case nonNativeManifestPlugin(identifier: String, kind: PluginKind)
    case nonUserPluginLocation(pluginDirectoryURL: URL, userPluginDirectoryURL: URL)
    case unsafePluginDirectoryName(String)
    case missingPluginDirectory(URL)
}

public enum PluginKind: Codable, Equatable, Sendable {
    case nativeManifest
    case windowsDLL
    case macOSBundle
    case unsupported
}

public enum PluginCompatibility: Codable, Equatable, Sendable {
    public static let disabledPluginReason = "Plugin is disabled by Plugin Admin."
    public static let windowsDLLReason = "Notepad++ plugins are Win32 DLLs and cannot be loaded by the native macOS host without Wine."

    case nativeCompatible
    case windowsOnly(reason: String)
    case unsupported(reason: String)
    case invalidManifest(reason: String)
}

public struct PluginCatalog: Equatable, Sendable {
    public let plugins: [PluginDescriptor]

    public init(plugins: [PluginDescriptor]) {
        self.plugins = plugins.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    public func plugin(identifier: String) -> PluginDescriptor? {
        plugins.first { $0.identifier == identifier }
    }

    public func withDisabledPlugins<S: Sequence>(_ disabledPluginIdentifiers: S) -> PluginCatalog where S.Element == String {
        let disabledPluginIdentifiers = Set(disabledPluginIdentifiers)
        guard !disabledPluginIdentifiers.isEmpty else {
            return self
        }

        return PluginCatalog(plugins: plugins.map { plugin in
            guard disabledPluginIdentifiers.contains(plugin.identifier), plugin.kind == .nativeManifest else {
                return plugin
            }

            return PluginDescriptor(
                identifier: plugin.identifier,
                displayName: plugin.displayName,
                version: plugin.version,
                kind: plugin.kind,
                compatibility: .unsupported(reason: PluginCompatibility.disabledPluginReason),
                directoryURL: plugin.directoryURL,
                entryURL: plugin.entryURL,
                commands: plugin.commands
            )
        })
    }

    public static func scan(directories: [URL]) -> PluginCatalog {
        var selectedPlugins: [PluginDescriptor] = []
        var seenIdentifiers: Set<String> = []

        for directory in directories {
            for plugin in scanDirectory(directory) where !seenIdentifiers.contains(plugin.identifier) {
                selectedPlugins.append(plugin)
                seenIdentifiers.insert(plugin.identifier)
            }
        }

        return PluginCatalog(plugins: selectedPlugins)
    }

    public static func defaultPluginDirectories() -> [URL] {
        var directories: [URL] = []
        if let userPluginDirectory = userPluginDirectory() {
            directories.append(userPluginDirectory)
        }
        if let resourceURL = Bundle.main.resourceURL {
            directories.append(resourceURL.appending(path: "Plugins"))
        }
        return directories
    }

    public static func userPluginDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appending(path: "Notepad++ Mac/Plugins")
            .standardizedFileURL
    }

    public static func installNativePlugin(
        from sourceDirectoryURL: URL,
        into userPluginDirectoryURL: URL? = PluginCatalog.userPluginDirectory(),
        fileManager: FileManager = .default
    ) throws -> PluginInstallationResult {
        guard let userPluginDirectoryURL else {
            throw PluginInstallationError.userPluginDirectoryUnavailable
        }

        let sourceDirectoryURL = sourceDirectoryURL.standardizedFileURL
        let destinationRootURL = userPluginDirectoryURL.standardizedFileURL
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: sourceDirectoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PluginInstallationError.sourceNotDirectory(sourceDirectoryURL)
        }

        let manifestURL = sourceDirectoryURL.appending(path: "notepad-mac-plugin.json").standardizedFileURL
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PluginInstallationError.missingManifest(manifestURL)
        }

        let manifest: PluginManifest
        do {
            manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: manifestURL))
        } catch {
            throw PluginInstallationError.invalidManifest(manifestURL, reason: error.localizedDescription)
        }

        try rejectWindowsDLLOnlyPlugin(sourceDirectoryURL, manifest: manifest, fileManager: fileManager)

        let destinationName = try destinationDirectoryName(sourceDirectoryURL: sourceDirectoryURL, manifest: manifest)
        let destinationURL = destinationRootURL.appending(path: destinationName).standardizedFileURL
        let destinationManifestURL = destinationURL.appending(path: "notepad-mac-plugin.json").standardizedFileURL

        if sourceDirectoryURL.resolvingSymlinksInPath() == destinationURL.resolvingSymlinksInPath() {
            return PluginInstallationResult(
                plugin: nativeManifestDescriptor(directoryURL: destinationURL, manifestURL: destinationManifestURL),
                destinationURL: destinationURL,
                action: .unchanged
            )
        }

        try rejectIdentifierCollision(
            destinationManifestURL: destinationManifestURL,
            incomingManifest: manifest,
            fileManager: fileManager
        )

        try fileManager.createDirectory(at: destinationRootURL, withIntermediateDirectories: true)

        let action: PluginInstallationAction = fileManager.fileExists(atPath: destinationURL.path)
            ? .updated
            : .installed
        let temporaryURL = destinationRootURL
            .appending(path: ".notepad-mac-plugin-install-\(UUID().uuidString)")
            .standardizedFileURL

        do {
            try fileManager.copyItem(at: sourceDirectoryURL, to: temporaryURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        return PluginInstallationResult(
            plugin: nativeManifestDescriptor(directoryURL: destinationURL, manifestURL: destinationManifestURL),
            destinationURL: destinationURL,
            action: action
        )
    }

    public static func removeNativePlugin(
        _ plugin: PluginDescriptor,
        from userPluginDirectoryURL: URL? = PluginCatalog.userPluginDirectory(),
        fileManager: FileManager = .default
    ) throws -> PluginRemovalResult {
        guard let resolvedUserPluginDirectoryURL = userPluginDirectoryURL else {
            throw PluginRemovalError.userPluginDirectoryUnavailable
        }

        let pluginDirectoryURL = plugin.directoryURL.standardizedFileURL
        let userPluginDirectoryURL = resolvedUserPluginDirectoryURL.standardizedFileURL

        if plugin.kind == .windowsDLL {
            throw PluginRemovalError.windowsOnlyPlugin((plugin.entryURL ?? plugin.directoryURL).standardizedFileURL)
        }
        guard plugin.kind == .nativeManifest else {
            throw PluginRemovalError.nonNativeManifestPlugin(identifier: plugin.identifier, kind: plugin.kind)
        }
        if case .windowsOnly = plugin.compatibility {
            throw PluginRemovalError.windowsOnlyPlugin((plugin.entryURL ?? plugin.directoryURL).standardizedFileURL)
        }

        try validateUserPluginRemovalTarget(
            pluginDirectoryURL: pluginDirectoryURL,
            userPluginDirectoryURL: userPluginDirectoryURL
        )

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: pluginDirectoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PluginRemovalError.missingPluginDirectory(pluginDirectoryURL)
        }

        try fileManager.removeItem(at: pluginDirectoryURL)
        return PluginRemovalResult(plugin: plugin, removedURL: pluginDirectoryURL)
    }

    private static func scanDirectory(_ directory: URL) -> [PluginDescriptor] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap(descriptor(for:))
    }

    private static func descriptor(for url: URL) -> PluginDescriptor? {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = resourceValues?.isDirectory == true

        if isDirectory {
            let manifestURL = url.appending(path: "notepad-mac-plugin.json")
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                return nativeManifestDescriptor(directoryURL: url, manifestURL: manifestURL)
            }

            if url.pathExtension.lowercased() == "bundle" {
                return PluginDescriptor(
                    identifier: "bundle:\(url.lastPathComponent)",
                    displayName: url.deletingPathExtension().lastPathComponent,
                    kind: .macOSBundle,
                    compatibility: .unsupported(reason: "macOS plugin bundles need a notepad-mac-plugin.json manifest before they can be exposed in the native host."),
                    directoryURL: url,
                    entryURL: url
                )
            }
        }

        if url.pathExtension.lowercased() == "dll" {
            return PluginDescriptor(
                identifier: "windows-dll:\(url.lastPathComponent)",
                displayName: url.deletingPathExtension().lastPathComponent,
                kind: .windowsDLL,
                compatibility: .windowsOnly(reason: PluginCompatibility.windowsDLLReason),
                directoryURL: url.deletingLastPathComponent(),
                entryURL: url
            )
        }

        return nil
    }

    private static func rejectIdentifierCollision(
        destinationManifestURL: URL,
        incomingManifest: PluginManifest,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: destinationManifestURL.path) else {
            return
        }

        let installedManifest: PluginManifest
        do {
            installedManifest = try JSONDecoder().decode(
                PluginManifest.self,
                from: Data(contentsOf: destinationManifestURL)
            )
        } catch {
            return
        }

        guard installedManifest.identifier != incomingManifest.identifier else {
            return
        }

        throw PluginInstallationError.invalidManifest(
            destinationManifestURL,
            reason: "Installed plugin identifier \(installedManifest.identifier) does not match selected plugin identifier \(incomingManifest.identifier). Choose a different plugin folder name or remove the installed plugin first."
        )
    }

    private static func rejectWindowsDLLOnlyPlugin(
        _ sourceDirectoryURL: URL,
        manifest: PluginManifest,
        fileManager: FileManager
    ) throws {
        if manifest.entryPoint?.lowercased().hasSuffix(".dll") == true {
            throw PluginInstallationError.windowsDLLOnly(sourceDirectoryURL)
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: sourceDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let payload = contents.filter { $0.lastPathComponent != "notepad-mac-plugin.json" }
        guard !payload.isEmpty else {
            return
        }

        let nonMetadataPayload = payload.filter { url in
            !["json", "md", "txt"].contains(url.pathExtension.lowercased())
        }
        if !nonMetadataPayload.isEmpty,
           nonMetadataPayload.allSatisfy({ $0.pathExtension.lowercased() == "dll" }) {
            throw PluginInstallationError.windowsDLLOnly(sourceDirectoryURL)
        }
    }

    private static func destinationDirectoryName(sourceDirectoryURL: URL, manifest: PluginManifest) throws -> String {
        if let sourceName = sourceDirectoryURL.lastPathComponent.safePluginDirectoryName {
            return sourceName
        }
        if let identifierName = manifest.identifier.safePluginDirectoryName {
            return identifierName
        }
        throw PluginInstallationError.invalidDestinationName(
            sourceFolderName: sourceDirectoryURL.lastPathComponent,
            pluginIdentifier: manifest.identifier
        )
    }

    private static func validateUserPluginRemovalTarget(
        pluginDirectoryURL: URL,
        userPluginDirectoryURL: URL
    ) throws {
        let pluginDirectoryURL = pluginDirectoryURL.standardizedFileURL
        let userPluginDirectoryURL = userPluginDirectoryURL.standardizedFileURL
        guard pluginDirectoryURL.deletingLastPathComponent().path == userPluginDirectoryURL.path else {
            throw PluginRemovalError.nonUserPluginLocation(
                pluginDirectoryURL: pluginDirectoryURL,
                userPluginDirectoryURL: userPluginDirectoryURL
            )
        }

        let directoryName = pluginDirectoryURL.lastPathComponent
        guard directoryName.safePluginDirectoryName == directoryName else {
            throw PluginRemovalError.unsafePluginDirectoryName(directoryName)
        }
    }

    private static func nativeManifestDescriptor(directoryURL: URL, manifestURL: URL) -> PluginDescriptor {
        do {
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: manifestURL))
            let entryURL = manifest.entryPoint.map { directoryURL.appending(path: $0).standardizedFileURL }
            return PluginDescriptor(
                identifier: manifest.identifier,
                displayName: manifest.name,
                version: manifest.version,
                kind: .nativeManifest,
                compatibility: .nativeCompatible,
                directoryURL: directoryURL,
                entryURL: entryURL,
                commands: manifest.commands
            )
        } catch {
            return PluginDescriptor(
                identifier: "invalid:\(directoryURL.lastPathComponent)",
                displayName: directoryURL.lastPathComponent,
                kind: .nativeManifest,
                compatibility: .invalidManifest(reason: error.localizedDescription),
                directoryURL: directoryURL,
                entryURL: manifestURL
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var safePluginDirectoryName: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let allowedScalars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        var sanitized = ""
        var insertedReplacement = false
        for scalar in trimmed.unicodeScalars {
            if allowedScalars.contains(scalar) {
                sanitized.unicodeScalars.append(scalar)
                insertedReplacement = false
            } else if !insertedReplacement {
                sanitized.append("-")
                insertedReplacement = true
            }
        }

        let safeName = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: " .-_"))
        guard !safeName.isEmpty, safeName != ".", safeName != ".." else {
            return nil
        }
        return safeName
    }
}
