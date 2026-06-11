import Foundation

/// Semantic-style application version used for update comparison.
/// Accepts forms like "1", "1.2", "1.2.3", optionally prefixed with "v",
/// and ignores a trailing pre-release/build suffix ("1.2.3-beta", "1.2.3+45").
public struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    public let components: [Int]
    public let isPrerelease: Bool

    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("v") {
            text = String(text.dropFirst())
        }
        guard !text.isEmpty else { return nil }
        var numericPart = text
        var prerelease = false
        if let split = text.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            prerelease = text[split] == "-"
            numericPart = String(text[..<split])
        }
        let pieces = numericPart.split(separator: ".", omittingEmptySubsequences: false)
        guard !pieces.isEmpty else { return nil }
        var parsed: [Int] = []
        for piece in pieces {
            guard let value = Int(piece), value >= 0 else { return nil }
            parsed.append(value)
        }
        components = parsed
        isPrerelease = prerelease
    }

    public var description: String {
        components.map(String.init).joined(separator: ".") + (isPrerelease ? "-pre" : "")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        // Same numeric core: a pre-release sorts before the final release.
        if lhs.isPrerelease != rhs.isPrerelease {
            return lhs.isPrerelease
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

/// One release entry decoded from the GitHub Releases API.
public struct UpdateRelease: Equatable {
    public let tagName: String
    public let name: String?
    public let htmlURL: URL?
    public let isDraft: Bool
    public let isPrerelease: Bool
    public let dmgAssetURL: URL?

    public init(
        tagName: String,
        name: String?,
        htmlURL: URL?,
        isDraft: Bool,
        isPrerelease: Bool,
        dmgAssetURL: URL?
    ) {
        self.tagName = tagName
        self.name = name
        self.htmlURL = htmlURL
        self.isDraft = isDraft
        self.isPrerelease = isPrerelease
        self.dmgAssetURL = dmgAssetURL
    }

    public var version: AppVersion? {
        AppVersion(tagName)
    }
}

public enum UpdateCheckOutcome: Equatable {
    /// The feed has a release newer than the running version.
    case updateAvailable(UpdateRelease)
    /// The running version is the newest published release (or newer).
    case upToDate
    /// The repository exists but has no usable (non-draft) releases yet.
    case noPublishedReleases
}

public enum UpdateCheckError: Error, Equatable {
    case invalidFeedData
    case noParsableVersion(tag: String)
}

/// Pure decision logic for the GitHub Releases update channel.
/// Networking stays in the app layer so this is fully unit-testable.
public enum UpdateChecker {
    public static let defaultRepositorySlugInfoKey = "NotepadMacUpdateRepository"
    public static let repositoryOverrideDefaultsKey = "UpdateRepositorySlug"

    /// Builds the GitHub API URL listing releases for `owner/repo`.
    public static func releasesAPIURL(repositorySlug: String) -> URL? {
        let trimmed = repositorySlug.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])/releases?per_page=20")
    }

    /// Decodes the GitHub `/releases` JSON array.
    public static func decodeReleases(from data: Data) throws -> [UpdateRelease] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw UpdateCheckError.invalidFeedData
        }
        return array.compactMap { entry in
            guard let tag = entry["tag_name"] as? String, !tag.isEmpty else { return nil }
            var dmg: URL?
            if let assets = entry["assets"] as? [[String: Any]] {
                for asset in assets {
                    guard let assetName = asset["name"] as? String,
                          assetName.lowercased().hasSuffix(".dmg"),
                          let urlText = asset["browser_download_url"] as? String,
                          let url = URL(string: urlText)
                    else { continue }
                    dmg = url
                    break
                }
            }
            return UpdateRelease(
                tagName: tag,
                name: entry["name"] as? String,
                htmlURL: (entry["html_url"] as? String).flatMap(URL.init(string:)),
                isDraft: entry["draft"] as? Bool ?? false,
                isPrerelease: entry["prerelease"] as? Bool ?? false,
                dmgAssetURL: dmg
            )
        }
    }

    /// Compares the running version against the decoded feed.
    /// Draft releases never count; pre-releases count only when
    /// `includePrereleases` is set.
    public static func evaluate(
        currentVersion: String,
        releases: [UpdateRelease],
        includePrereleases: Bool = false
    ) throws -> UpdateCheckOutcome {
        let usable = releases.filter { !$0.isDraft && (includePrereleases || !$0.isPrerelease) }
        guard !usable.isEmpty else { return .noPublishedReleases }
        guard let current = AppVersion(currentVersion) else {
            throw UpdateCheckError.noParsableVersion(tag: currentVersion)
        }
        var newest: (release: UpdateRelease, version: AppVersion)?
        for release in usable {
            guard let version = release.version else { continue }
            if newest == nil || newest!.version < version {
                newest = (release, version)
            }
        }
        guard let best = newest else {
            throw UpdateCheckError.noParsableVersion(tag: usable[0].tagName)
        }
        return current < best.version ? .updateAvailable(best.release) : .upToDate
    }
}

/// Proxy settings for the updater, mirroring upstream "Set Updater Proxy...".
public struct UpdaterProxySettings: Equatable {
    public var isEnabled: Bool
    public var host: String
    public var port: Int

    public init(isEnabled: Bool = false, host: String = "", port: Int = 8080) {
        self.isEnabled = isEnabled
        self.host = host
        self.port = port
    }

    /// True when the settings describe a proxy that can actually be used.
    public var isUsable: Bool {
        isEnabled && !host.trimmingCharacters(in: .whitespaces).isEmpty && (1...65535).contains(port)
    }

    /// Keys for `URLSessionConfiguration.connectionProxyDictionary`.
    /// String keys avoid importing CFNetwork constants in tests.
    public var connectionProxyDictionary: [String: Any]? {
        guard isUsable else { return nil }
        let cleanHost = host.trimmingCharacters(in: .whitespaces)
        return [
            "HTTPEnable": 1,
            "HTTPProxy": cleanHost,
            "HTTPPort": port,
            "HTTPSEnable": 1,
            "HTTPSProxy": cleanHost,
            "HTTPSPort": port,
        ]
    }
}

/// UserDefaults persistence for the updater proxy.
public struct UpdaterProxyStore {
    public static let enabledKey = "UpdaterProxyEnabled"
    public static let hostKey = "UpdaterProxyHost"
    public static let portKey = "UpdaterProxyPort"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> UpdaterProxySettings {
        let port = defaults.object(forKey: Self.portKey) as? Int ?? 8080
        return UpdaterProxySettings(
            isEnabled: defaults.bool(forKey: Self.enabledKey),
            host: defaults.string(forKey: Self.hostKey) ?? "",
            port: port
        )
    }

    public func save(_ settings: UpdaterProxySettings) {
        defaults.set(settings.isEnabled, forKey: Self.enabledKey)
        defaults.set(settings.host, forKey: Self.hostKey)
        defaults.set(settings.port, forKey: Self.portKey)
    }
}
