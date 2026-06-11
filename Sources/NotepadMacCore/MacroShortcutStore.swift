import Foundation

/// Keyboard shortcut assigned to a named macro.
public struct MacroShortcut: Codable, Equatable, Sendable {
    public let macroName: String
    public let keyEquivalent: String   // single character, e.g. "m"
    public let modifierFlags: Int      // NSEvent.ModifierFlags.rawValue

    public init(macroName: String, keyEquivalent: String, modifierFlags: Int) {
        self.macroName = macroName
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
    }

    public var displayString: String {
        guard !keyEquivalent.isEmpty else { return "" }
        var s = ""
        let raw = UInt(bitPattern: modifierFlags)
        if raw & (1 << 18) != 0 { s += "⌃" }  // control
        if raw & (1 << 19) != 0 { s += "⌥" }  // option
        if raw & (1 << 17) != 0 { s += "⇧" }  // shift
        if raw & (1 << 20) != 0 { s += "⌘" }  // command
        return s + keyEquivalent.uppercased()
    }
}

/// Persists keyboard shortcuts for named macros.
public final class MacroShortcutStore {
    private enum Key {
        static let shortcuts = "notepadMac.macroShortcuts"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [MacroShortcut] {
        guard let data = defaults.data(forKey: Key.shortcuts),
              let shortcuts = try? decoder.decode([MacroShortcut].self, from: data)
        else { return [] }
        return shortcuts
    }

    public func save(_ shortcuts: [MacroShortcut]) {
        guard let data = try? encoder.encode(shortcuts) else { return }
        defaults.set(data, forKey: Key.shortcuts)
        defaults.synchronize()
    }

    public func shortcut(for macroName: String) -> MacroShortcut? {
        load().first { $0.macroName.caseInsensitiveCompare(macroName) == .orderedSame }
    }

    public func setShortcut(_ shortcut: MacroShortcut) {
        var shortcuts = load().filter {
            $0.macroName.caseInsensitiveCompare(shortcut.macroName) != .orderedSame
        }
        if !shortcut.keyEquivalent.isEmpty {
            shortcuts.append(shortcut)
        }
        save(shortcuts)
    }

    public func removeShortcut(for macroName: String) {
        let shortcuts = load().filter {
            $0.macroName.caseInsensitiveCompare(macroName) != .orderedSame
        }
        save(shortcuts)
    }
}
