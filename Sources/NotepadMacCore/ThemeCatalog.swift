import Foundation

public struct ThemeDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let displayName: String
    public let url: URL

    public var id: String { name }

    public init(name: String, displayName: String? = nil, url: URL) {
        self.name = name
        self.displayName = displayName?.nilIfEmpty ?? name
        self.url = url.standardizedFileURL
    }
}

public struct ThemeCatalog: Equatable, Sendable {
    public let themes: [ThemeDescriptor]

    private let byName: [String: ThemeDescriptor]

    public init(themes: [ThemeDescriptor]) {
        self.themes = themes.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        self.byName = Dictionary(uniqueKeysWithValues: self.themes.map { ($0.name, $0) })
    }

    public func theme(named name: String) -> ThemeDescriptor? {
        byName[name]
    }

    public func loadStyleCatalog(for theme: ThemeDescriptor) throws -> StyleCatalog {
        try StyleCatalog.load(from: theme.url)
    }

    public static func scan(directories: [URL] = defaultThemeDirectories()) throws -> ThemeCatalog {
        var themes: [ThemeDescriptor] = []

        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            for url in urls where url.pathExtension.lowercased() == "xml" {
                let name = url.deletingPathExtension().lastPathComponent
                themes.append(ThemeDescriptor(name: name, displayName: displayName(for: name), url: url))
            }
        }

        var deduplicated: [String: ThemeDescriptor] = [:]
        for theme in themes {
            deduplicated[theme.name] = theme
        }

        return ThemeCatalog(themes: Array(deduplicated.values))
    }

    public static func loadDefault() -> ThemeCatalog {
        (try? scan()) ?? ThemeCatalog(themes: [])
    }

    public static var userThemesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(filePath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return appSupport.appending(path: "NotepadMac/themes")
    }

    public static func defaultThemeDirectories() -> [URL] {
        let sourceURL = URL(filePath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        // User themes take highest precedence
        urls.append(userThemesDirectory)
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appending(path: "themes"))
        }
        urls.append(projectRoot.appending(path: "notepad-plus-plus/PowerEditor/installer/themes"))

        let cwd = URL(filePath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appending(path: "notepad-plus-plus/PowerEditor/installer/themes"))
        urls.append(cwd.appending(path: "upstream/notepad-plus-plus/PowerEditor/installer/themes").standardizedFileURL)
        return urls
    }

    private static func displayName(for fileStem: String) -> String {
        switch fileStem {
        case "DarkModeDefault":
            "Dark Mode Default"
        default:
            fileStem
        }
    }
}

public struct ThemePreferences: Codable, Equatable, Sendable {
    public let selectedThemeName: String?
    /// Theme to apply automatically when the system is in dark mode (nil = don't auto-switch)
    public let darkModeThemeName: String?

    public init(selectedThemeName: String? = nil, darkModeThemeName: String? = nil) {
        self.selectedThemeName = selectedThemeName?.nilIfEmpty
        self.darkModeThemeName = darkModeThemeName?.nilIfEmpty
    }

    /// Returns the effective theme name for the given appearance.
    /// In dark mode, prefers darkModeThemeName if set.
    public func effectiveThemeName(isDarkMode: Bool) -> String? {
        if isDarkMode, let dark = darkModeThemeName { return dark }
        return selectedThemeName
    }
}

public final class ThemePreferencesStore {
    private enum Key {
        static let data = "notepadMac.themePreferences"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ThemePreferences {
        guard let data = defaults.data(forKey: Key.data),
              let preferences = try? decoder.decode(ThemePreferences.self, from: data)
        else {
            return ThemePreferences()
        }
        return preferences
    }

    public func save(_ preferences: ThemePreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: Key.data)
        defaults.synchronize()
    }

    public func clear() {
        defaults.removeObject(forKey: Key.data)
        defaults.synchronize()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
