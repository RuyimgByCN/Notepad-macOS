import Foundation

/// A remapped key binding for a Scintilla built-in command.
public struct ScintillaKeyRemap: Codable, Equatable, Sendable {
    /// SCI_* command message ID (e.g. 2300 for SCI_LINEDOWN)
    public let commandID: Int32
    /// SCK_* key value (0 = unbound / clear)
    public let key: Int
    /// SCMOD_* modifier flags
    public let modifiers: Int

    public init(commandID: Int32, key: Int, modifiers: Int) {
        self.commandID = commandID
        self.key = key
        self.modifiers = modifiers
    }

    /// Scintilla wParam encoding: key | (mods << 16)
    public var keyDefinition: Int { key | (modifiers << 16) }

    public var displayString: String {
        guard key != 0 else { return "(unbound)" }
        var s = ""
        if modifiers & SCMOD.ctrl  != 0 { s += "⌘" }
        if modifiers & SCMOD.alt   != 0 { s += "⌥" }
        if modifiers & SCMOD.shift != 0 { s += "⇧" }
        s += keyName(for: key)
        return s
    }

    private func keyName(for k: Int) -> String {
        switch k {
        case SCK.down:     return "↓"
        case SCK.up:       return "↑"
        case SCK.left:     return "←"
        case SCK.right:    return "→"
        case SCK.home:     return "Home"
        case SCK.end:      return "End"
        case SCK.prior:    return "PgUp"
        case SCK.next:     return "PgDn"
        case SCK.delete:   return "Del"
        case SCK.insert:   return "Ins"
        case SCK.escape:   return "Esc"
        case SCK.back:     return "⌫"
        case SCK.tab:      return "⇥"
        case SCK.`return`: return "↩"
        case SCK.add:      return "+"
        case SCK.subtract: return "−"
        case SCK.divide:   return "/"
        default:
            if k >= 32 && k < 127, let scalar = Unicode.Scalar(k) {
                return String(scalar).uppercased()
            }
            return "(\(k))"
        }
    }
}

/// Persists custom Scintilla key remaps via UserDefaults.
public final class ScintillaKeyMapStore {
    private enum Key {
        static let remaps = "notepadMac.scintillaKeyRemaps"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [ScintillaKeyRemap] {
        guard let data = defaults.data(forKey: Key.remaps),
              let remaps = try? decoder.decode([ScintillaKeyRemap].self, from: data)
        else { return [] }
        return remaps
    }

    public func save(_ remaps: [ScintillaKeyRemap]) {
        guard let data = try? encoder.encode(remaps) else { return }
        defaults.set(data, forKey: Key.remaps)
        defaults.synchronize()
    }

    public func remap(forCommandID id: Int32) -> ScintillaKeyRemap? {
        load().first { $0.commandID == id }
    }

    public func setRemap(_ remap: ScintillaKeyRemap) {
        var remaps = load().filter { $0.commandID != remap.commandID }
        remaps.append(remap)
        save(remaps)
    }

    public func clearRemap(forCommandID id: Int32) {
        save(load().filter { $0.commandID != id })
    }
}
