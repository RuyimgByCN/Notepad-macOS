import Foundation

/// Keyboard shortcut assigned to a plugin command.
public struct PluginCommandShortcut: Codable, Equatable, Sendable {
    /// Plugin identifier, e.g. "com.example.MyPlugin"
    public let pluginIdentifier: String
    /// Command identifier within the plugin, e.g. "formatCode"
    public let commandIdentifier: String
    /// Single character key equivalent, e.g. "p"
    public let keyEquivalent: String
    /// NSEvent.ModifierFlags.rawValue
    public let modifierFlags: Int

    public init(
        pluginIdentifier: String,
        commandIdentifier: String,
        keyEquivalent: String,
        modifierFlags: Int
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.commandIdentifier = commandIdentifier
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
    }

    public var displayString: String {
        guard !keyEquivalent.isEmpty else { return "" }
        var s = ""
        let raw = UInt(bitPattern: modifierFlags)
        if raw & (1 << 18) != 0 { s += "⌃" }
        if raw & (1 << 19) != 0 { s += "⌥" }
        if raw & (1 << 17) != 0 { s += "⇧" }
        if raw & (1 << 20) != 0 { s += "⌘" }
        return s + keyEquivalent.uppercased()
    }

    public var compositeKey: String { "\(pluginIdentifier):\(commandIdentifier)" }
}

/// Persists keyboard shortcuts for plugin commands.
public final class PluginCommandShortcutStore {
    private enum Key {
        static let shortcuts = "notepadMac.pluginCommandShortcuts"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [PluginCommandShortcut] {
        guard let data = defaults.data(forKey: Key.shortcuts),
              let shortcuts = try? decoder.decode([PluginCommandShortcut].self, from: data)
        else { return [] }
        return shortcuts
    }

    public func save(_ shortcuts: [PluginCommandShortcut]) {
        guard let data = try? encoder.encode(shortcuts) else { return }
        defaults.set(data, forKey: Key.shortcuts)
        defaults.synchronize()
    }

    public func shortcut(forPlugin pluginId: String, command commandId: String) -> PluginCommandShortcut? {
        let key = "\(pluginId):\(commandId)"
        return load().first { $0.compositeKey == key }
    }

    public func setShortcut(_ shortcut: PluginCommandShortcut) {
        var shortcuts = load().filter { $0.compositeKey != shortcut.compositeKey }
        shortcuts.append(shortcut)
        save(shortcuts)
    }

    public func clearShortcut(forPlugin pluginId: String, command commandId: String) {
        let key = "\(pluginId):\(commandId)"
        let shortcuts = load().filter { $0.compositeKey != key }
        save(shortcuts)
    }
}
