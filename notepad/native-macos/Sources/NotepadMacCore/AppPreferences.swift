import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let minimumEditorFontSize = 9.0
    public static let maximumEditorFontSize = 32.0
    public static let defaultValue = AppPreferences(
        editorFontSize: 13,
        wrapsLines: false,
        searchMatchCase: false,
        searchWholeWord: false
    )

    public let editorFontSize: Double
    public let wrapsLines: Bool
    public let searchMatchCase: Bool
    public let searchWholeWord: Bool

    public var searchOptions: TextSearch.Options {
        TextSearch.Options(matchCase: searchMatchCase, wholeWord: searchWholeWord)
    }

    public init(
        editorFontSize: Double = 13,
        wrapsLines: Bool = false,
        searchMatchCase: Bool = false,
        searchWholeWord: Bool = false
    ) {
        self.editorFontSize = min(max(editorFontSize, Self.minimumEditorFontSize), Self.maximumEditorFontSize)
        self.wrapsLines = wrapsLines
        self.searchMatchCase = searchMatchCase
        self.searchWholeWord = searchWholeWord
    }

    public func withEditorFontSize(_ editorFontSize: Double) -> AppPreferences {
        AppPreferences(
            editorFontSize: editorFontSize,
            wrapsLines: wrapsLines,
            searchMatchCase: searchMatchCase,
            searchWholeWord: searchWholeWord
        )
    }

    public func withWrapsLines(_ wrapsLines: Bool) -> AppPreferences {
        AppPreferences(
            editorFontSize: editorFontSize,
            wrapsLines: wrapsLines,
            searchMatchCase: searchMatchCase,
            searchWholeWord: searchWholeWord
        )
    }

    public func withSearchOptions(_ options: TextSearch.Options) -> AppPreferences {
        AppPreferences(
            editorFontSize: editorFontSize,
            wrapsLines: wrapsLines,
            searchMatchCase: options.matchCase,
            searchWholeWord: options.wholeWord
        )
    }
}

public final class PreferencesStore {
    private enum Key {
        static let editorFontSize = "notepadMac.editorFontSize"
        static let wrapsLines = "notepadMac.wrapsLines"
        static let searchMatchCase = "notepadMac.searchMatchCase"
        static let searchWholeWord = "notepadMac.searchWholeWord"
        static let disabledNativePluginIdentifiers = "notepadMac.disabledNativePluginIdentifiers"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppPreferences {
        AppPreferences(
            editorFontSize: defaults.object(forKey: Key.editorFontSize) as? Double ?? AppPreferences.defaultValue.editorFontSize,
            wrapsLines: defaults.object(forKey: Key.wrapsLines) as? Bool ?? AppPreferences.defaultValue.wrapsLines,
            searchMatchCase: defaults.object(forKey: Key.searchMatchCase) as? Bool ?? AppPreferences.defaultValue.searchMatchCase,
            searchWholeWord: defaults.object(forKey: Key.searchWholeWord) as? Bool ?? AppPreferences.defaultValue.searchWholeWord
        )
    }

    public func save(_ preferences: AppPreferences) {
        defaults.set(preferences.editorFontSize, forKey: Key.editorFontSize)
        defaults.set(preferences.wrapsLines, forKey: Key.wrapsLines)
        defaults.set(preferences.searchMatchCase, forKey: Key.searchMatchCase)
        defaults.set(preferences.searchWholeWord, forKey: Key.searchWholeWord)
        defaults.synchronize()
    }

    public func loadDisabledNativePluginIdentifiers() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.disabledNativePluginIdentifiers) ?? [])
    }

    public func saveDisabledNativePluginIdentifiers(_ identifiers: Set<String>) {
        if identifiers.isEmpty {
            defaults.removeObject(forKey: Key.disabledNativePluginIdentifiers)
        } else {
            defaults.set(identifiers.sorted(), forKey: Key.disabledNativePluginIdentifiers)
        }
        defaults.synchronize()
    }
}
