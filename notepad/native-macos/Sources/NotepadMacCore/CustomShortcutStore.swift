import Foundation

public struct CustomShortcut: Codable, Equatable, Sendable {
    public let menuItemTitle: String
    public let keyEquivalent: String        // e.g. "s", "z"
    public let modifierFlags: Int           // NSEvent.ModifierFlags.rawValue

    public init(menuItemTitle: String, keyEquivalent: String, modifierFlags: Int) {
        self.menuItemTitle = menuItemTitle
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
    }

    /// Human-readable representation, e.g. "⌘⇧S" (⌃⌥⇧⌘ order, matching macOS convention)
    public var displayString: String {
        var s = ""
        let raw = UInt(bitPattern: modifierFlags)
        if raw & (1 << 18) != 0 { s += "⌃" }  // control  (bit 18 = 0x40000)
        if raw & (1 << 19) != 0 { s += "⌥" }  // option   (bit 19 = 0x80000)
        if raw & (1 << 17) != 0 { s += "⇧" }  // shift    (bit 17 = 0x20000)
        if raw & (1 << 20) != 0 { s += "⌘" }  // command  (bit 20 = 0x100000)
        return s + keyEquivalent.uppercased()
    }
}

public final class CustomShortcutStore {
    private enum Key {
        static let shortcuts = "notepadMac.customShortcuts"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [CustomShortcut] {
        guard let data = defaults.data(forKey: Key.shortcuts),
              let shortcuts = try? decoder.decode([CustomShortcut].self, from: data)
        else { return [] }
        return shortcuts
    }

    public func save(_ shortcuts: [CustomShortcut]) {
        guard let data = try? encoder.encode(shortcuts) else { return }
        defaults.set(data, forKey: Key.shortcuts)
        defaults.synchronize()
    }

    public func setShortcut(_ shortcut: CustomShortcut) {
        var current = load()
        current.removeAll { $0.menuItemTitle == shortcut.menuItemTitle }
        current.append(shortcut)
        save(current)
    }

    public func removeShortcut(forTitle title: String) {
        var current = load()
        current.removeAll { $0.menuItemTitle == title }
        save(current)
    }

    public func shortcut(forTitle title: String) -> CustomShortcut? {
        load().first { $0.menuItemTitle == title }
    }

    /// Find all menu items that use the given key combo (for conflict detection)
    public func conflictingTitle(keyEquivalent: String, modifierFlags: Int, excluding title: String) -> String? {
        load().first { s in
            s.menuItemTitle != title &&
            s.keyEquivalent.lowercased() == keyEquivalent.lowercased() &&
            s.modifierFlags == modifierFlags
        }?.menuItemTitle
    }
}
