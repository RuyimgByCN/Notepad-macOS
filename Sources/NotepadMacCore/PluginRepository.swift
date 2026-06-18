import Foundation

/// One entry in the remote plugin catalog JSON.
public struct PluginRepositoryEntry: Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String?
    public let description: String?
    public let author: String?
    public let homepage: String?
    public let repository: String?
    /// Notepad-mac version compatibility range, e.g. "[8.9.6,]"
    public let nppMacCompatibleVersions: String?

    public init(
        identifier: String,
        name: String,
        version: String? = nil,
        description: String? = nil,
        author: String? = nil,
        homepage: String? = nil,
        repository: String? = nil,
        nppMacCompatibleVersions: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.homepage = homepage
        self.repository = repository
        self.nppMacCompatibleVersions = nppMacCompatibleVersions
    }
}

/// The top-level structure of the remote plugin catalog.
public struct PluginRepositoryCatalog: Codable, Equatable, Sendable {
    public let version: Int
    public let plugins: [PluginRepositoryEntry]

    public init(version: Int = 1, plugins: [PluginRepositoryEntry] = []) {
        self.version = version
        self.plugins = plugins
    }
}

/// Fetches and caches the remote plugin catalog, compares with
/// locally installed plugins, and produces available/update lists.
public enum PluginRepository {

    /// Default URL for the official Notepad-mac plugin catalog.
    public static var defaultCatalogURL: URL {
        URL(string: "https://raw.githubusercontent.com/RuyimgByCN/Notepad-macOS/main/plugin-catalog.json")!
    }

    /// Cache file location.
    public static func cacheURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appending(path: "Notepad++ Mac/plugin-catalog-cache.json")
            .standardizedFileURL
    }

    /// Fetch the remote catalog (with local cache fallback).
    /// Returns the decoded catalog, or nil on failure.
    @MainActor
    public static func fetchCatalog(
        from remoteURL: URL = defaultCatalogURL,
        session: URLSession = .shared
    ) async -> PluginRepositoryCatalog? {
        // Try remote first
        if let remoteCatalog = await fetchRemote(url: remoteURL, session: session) {
            // Cache the result
            try? JSONEncoder().encode(remoteCatalog).write(to: cacheURL(), options: .atomic)
            return remoteCatalog
        }

        // Fallback to cached version
        return loadCached()
    }

    /// Load catalog from cache file.
    public static func loadCached() -> PluginRepositoryCatalog? {
        guard let data = try? Data(contentsOf: cacheURL()) else { return nil }
        return try? JSONDecoder().decode(PluginRepositoryCatalog.self, from: data)
    }

    /// Compare remote entries against installed plugins and return:
    /// - `available`: entries not installed locally
    /// - `updates`: entries where remote version > installed version
    public static func compare(
        remote: PluginRepositoryCatalog,
        installed: PluginCatalog
    ) -> (available: [PluginRepositoryEntry], updates: [(remote: PluginRepositoryEntry, installed: PluginDescriptor)]) {
        var available: [PluginRepositoryEntry] = []
        var updates: [(remote: PluginRepositoryEntry, installed: PluginDescriptor)] = []

        let installedByIdentifier: [String: PluginDescriptor] = Dictionary(
            installed.plugins.map { ($0.identifier, $0) },
            uniquingKeysWith: { _, later in later }
        )

        for entry in remote.plugins {
            if let installedPlugin = installedByIdentifier[entry.identifier] {
                // Check for update
                if let remoteVersion = entry.version,
                   let installedVersion = installedPlugin.version,
                   let rv = AppVersion(remoteVersion),
                   let iv = AppVersion(installedVersion),
                   rv > iv {
                    updates.append((remote: entry, installed: installedPlugin))
                }
                // Same or older version — skip
            } else {
                available.append(entry)
            }
        }

        return (available, updates)
    }

    /// Download a plugin zip from its repository URL and install it.
    @MainActor
    public static func installFromRepository(
        entry: PluginRepositoryEntry,
        into userPluginDirectory: URL? = PluginCatalog.userPluginDirectory(),
        session: URLSession = .shared
    ) async throws -> PluginInstallationResult {
        guard let repositoryURLString = entry.repository,
              let downloadURL = URL(string: repositoryURLString)
        else {
            throw PluginRepositoryError.missingRepositoryURL(identifier: entry.identifier)
        }

        guard let userPluginDirectory else {
            throw PluginRepositoryError.userPluginDirectoryUnavailable
        }

        // Download the archive
        let (location, response) = try await session.download(from: downloadURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PluginRepositoryError.downloadFailed(
                identifier: entry.identifier,
                reason: "HTTP \(statusCode)"
            )
        }

        // Stage the download as a .zip
        let stagedURL = FileManager.default.temporaryDirectory
            .appending(path: "notepad-mac-repo-download-\(UUID().uuidString).zip")
        try FileManager.default.moveItem(at: location, to: stagedURL)
        defer { try? FileManager.default.removeItem(at: stagedURL) }

        // Install via existing archive path
        return try PluginCatalog.installNativePlugin(
            fromArchive: stagedURL,
            into: userPluginDirectory
        )
    }

    // MARK: - Private

    @MainActor
    private static func fetchRemote(
        url: URL,
        session: URLSession
    ) async -> PluginRepositoryCatalog? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode)
            else { return nil }
            return try JSONDecoder().decode(PluginRepositoryCatalog.self, from: data)
        } catch {
            return nil
        }
    }
}

public enum PluginRepositoryError: Error, Equatable, Sendable {
    case missingRepositoryURL(identifier: String)
    case userPluginDirectoryUnavailable
    case downloadFailed(identifier: String, reason: String)
}
