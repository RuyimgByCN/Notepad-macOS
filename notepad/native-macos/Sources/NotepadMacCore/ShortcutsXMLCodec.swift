import Foundation

/// Encodes and decodes custom keyboard shortcuts in a Notepad++-compatible
/// shortcuts.xml subset. Only the InternalCommands section is round-tripped
/// because macOS shortcuts are identified by menu item title rather than
/// numeric command IDs.
///
/// Format produced:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8" ?>
/// <NotepadPlus>
///     <InternalCommands>
///         <!-- menuItemTitle is a macOS extension; id is always 0 -->
///         <Shortcut id="0" menuItemTitle="Save" Ctrl="no" Alt="no" Shift="no" Key="83" />
///     </InternalCommands>
/// </NotepadPlus>
/// ```
public enum ShortcutsXMLCodec {

    // MARK: - Encode

    /// Serialise custom shortcuts to Notepad++-style shortcuts.xml.
    public static func encode(_ shortcuts: [CustomShortcut]) -> Data? {
        var lines: [String] = []
        lines.append(#"<?xml version="1.0" encoding="UTF-8" ?>"#)
        lines.append("<NotepadPlus>")
        lines.append("    <InternalCommands>")
        for sc in shortcuts {
            let modifiers = nsMod(sc.modifierFlags)
            let keyCode = nsKeyToVK(sc.keyEquivalent)
            let title = escapeXML(sc.menuItemTitle)
            lines.append(
                "        <Shortcut id=\"0\" menuItemTitle=\"\(title)\"" +
                " Ctrl=\"\(modifiers.ctrl)\"" +
                " Alt=\"\(modifiers.alt)\"" +
                " Shift=\"\(modifiers.shift)\"" +
                " Key=\"\(keyCode)\" />"
            )
        }
        lines.append("    </InternalCommands>")
        lines.append("</NotepadPlus>")
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    // MARK: - Decode

    /// Parse a shortcuts.xml file and return the `InternalCommands` shortcuts.
    /// Returns nil if the XML cannot be parsed at all.
    public static func decode(_ data: Data) -> [CustomShortcut]? {
        let parser = ShortcutsXMLParser(data: data)
        return parser.parse()
    }

    // MARK: - Helpers

    private struct ModBits {
        let ctrl: String; let alt: String; let shift: String
    }

    private static func nsMod(_ rawValue: Int) -> ModBits {
        let raw = UInt(bitPattern: rawValue)
        // NSEvent.ModifierFlags bit layout:
        // control = 1<<18 (0x40000), option = 1<<19 (0x80000)
        // shift   = 1<<17 (0x20000), command = 1<<20 (0x100000)
        let ctrl  = raw & (1 << 20) != 0 // ⌘ mapped to Ctrl (Notepad++ convention)
        let alt   = raw & (1 << 19) != 0
        let shift = raw & (1 << 17) != 0
        return ModBits(
            ctrl:  ctrl  ? "yes" : "no",
            alt:   alt   ? "yes" : "no",
            shift: shift ? "yes" : "no"
        )
    }

    /// Convert NSEvent keyEquivalent character to a virtual key code integer.
    /// Uses macOS key codes for special keys; ASCII value for printable characters.
    private static func nsKeyToVK(_ key: String) -> Int {
        guard let ch = key.unicodeScalars.first else { return 0 }
        // macOS Unicode private-use area for special keys
        switch ch.value {
        case 0xF700: return 126  // up arrow
        case 0xF701: return 125  // down arrow
        case 0xF702: return 123  // left arrow
        case 0xF703: return 124  // right arrow
        case 0xF704: return 122  // F1
        case 0xF705: return 120  // F2
        case 0xF706: return 99   // F3
        case 0xF707: return 118  // F4
        case 0xF708: return 96   // F5
        case 0xF709: return 97   // F6
        case 0xF70A: return 98   // F7
        case 0xF70B: return 100  // F8
        case 0xF70C: return 101  // F9
        case 0xF70D: return 109  // F10
        case 0xF70E: return 103  // F11
        case 0xF70F: return 111  // F12
        case 0xF729: return 115  // home
        case 0xF72B: return 119  // end
        case 0xF72C: return 116  // page up
        case 0xF72D: return 121  // page down
        case 0xF728: return 117  // forward delete
        case 0x001B: return 53   // escape
        case 0x0008: return 51   // backspace/delete
        case 0x0009: return 48   // tab
        case 0x000D: return 36   // return
        default:
            // Printable ASCII — use the uppercase code point
            let upper = key.uppercased()
            if let ascii = upper.unicodeScalars.first?.value, ascii < 128 { return Int(ascii) }
            return Int(ch.value)
        }
    }

    /// Inverse of nsKeyToVK: VK integer → NSEvent keyEquivalent string.
    static func vkToNSKey(_ vk: Int) -> String? {
        switch vk {
        case 126: return "\u{F700}"
        case 125: return "\u{F701}"
        case 123: return "\u{F702}"
        case 124: return "\u{F703}"
        case 122: return "\u{F704}"
        case 120: return "\u{F705}"
        case 99:  return "\u{F706}"
        case 118: return "\u{F707}"
        case 96:  return "\u{F708}"
        case 97:  return "\u{F709}"
        case 98:  return "\u{F70A}"
        case 100: return "\u{F70B}"
        case 101: return "\u{F70C}"
        case 109: return "\u{F70D}"
        case 103: return "\u{F70E}"
        case 111: return "\u{F70F}"
        case 115: return "\u{F729}"
        case 119: return "\u{F72B}"
        case 116: return "\u{F72C}"
        case 121: return "\u{F72D}"
        case 117: return "\u{F728}"
        case 53:  return "\u{001B}"
        case 51:  return "\u{0008}"
        case 48:  return "\t"
        case 36:  return "\r"
        case 0:   return nil
        default:
            // Printable ASCII
            if vk >= 32 && vk < 127 {
                return String(UnicodeScalar(vk)!).lowercased()
            }
            return nil
        }
    }

    private static func escapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - XML Parser

private final class ShortcutsXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var shortcuts: [CustomShortcut] = []
    private var insideInternal = false

    init(data: Data) { self.data = data }

    func parse() -> [CustomShortcut]? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return shortcuts
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attrs: [String: String] = [:]) {
        if elementName == "InternalCommands" { insideInternal = true; return }
        guard insideInternal, elementName == "Shortcut" else { return }

        // We require the macOS-extension menuItemTitle attribute for round-trip.
        // If it's absent (pure Notepad++ file), skip.
        guard let title = attrs["menuItemTitle"], !title.isEmpty else { return }

        let ctrl  = attrs["Ctrl"]  == "yes"
        let alt   = attrs["Alt"]   == "yes"
        let shift = attrs["Shift"] == "yes"
        let vk = Int(attrs["Key"] ?? "0") ?? 0

        guard let keyEquivalent = ShortcutsXMLCodec.vkToNSKey(vk) else { return }

        // Rebuild NSEvent.ModifierFlags raw value:
        // command = 1<<20, option = 1<<19, shift = 1<<17
        var raw: UInt = 0
        if ctrl  { raw |= (1 << 20) } // ⌘ ↔ Ctrl (Notepad++ convention)
        if alt   { raw |= (1 << 19) }
        if shift { raw |= (1 << 17) }

        shortcuts.append(CustomShortcut(
            menuItemTitle: title,
            keyEquivalent: keyEquivalent,
            modifierFlags: Int(bitPattern: raw)
        ))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "InternalCommands" { insideInternal = false }
    }
}
