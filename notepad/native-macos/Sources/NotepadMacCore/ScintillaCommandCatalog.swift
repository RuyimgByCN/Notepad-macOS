import Foundation

/// A built-in Scintilla editing command that can be key-remapped.
public struct ScintillaCommandDefinition: Sendable {
    public let name: String
    public let commandID: Int32

    /// SCMOD_CTRL=2 | SCMOD_ALT=4 | SCMOD_SHIFT=1  (default modifiers)
    public let defaultModifiers: Int
    /// SCK_* value (0 = unbound)
    public let defaultKey: Int

    public init(name: String, commandID: Int32, defaultModifiers: Int, defaultKey: Int) {
        self.name = name
        self.commandID = commandID
        self.defaultModifiers = defaultModifiers
        self.defaultKey = defaultKey
    }
}

// Scintilla SCK_ key constants
public enum SCK {
    public static let down: Int     = 300
    public static let up: Int       = 301
    public static let left: Int     = 302
    public static let right: Int    = 303
    public static let home: Int     = 304
    public static let end: Int      = 305
    public static let prior: Int    = 306  // Page Up
    public static let next: Int     = 307  // Page Down
    public static let delete: Int   = 308
    public static let insert: Int   = 309
    public static let escape: Int   = 7
    public static let back: Int     = 8
    public static let tab: Int      = 9
    public static let `return`: Int = 13
    public static let add: Int      = 310  // +
    public static let subtract: Int = 311  // -
    public static let divide: Int   = 312  // /
    public static let win: Int      = 313
    public static let rwin: Int     = 314
    public static let menu: Int     = 315
}

// SCMOD_ modifier bit flags
public enum SCMOD {
    public static let shift: Int = 1
    public static let ctrl: Int  = 2   // Command on macOS
    public static let alt: Int   = 4   // Option on macOS
}

/// Built-in Scintilla commands. Ported from Notepad++ Parameters.cpp `winKeyDefs[]`.
public enum ScintillaCommandCatalog {
    public static let commands: [ScintillaCommandDefinition] = [
        .init(name: "SCI_BACKTAB",                 commandID: 2328, defaultModifiers: SCMOD.shift,               defaultKey: SCK.tab),
        .init(name: "SCI_FORMFEED",                commandID: 2330, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_ZOOMIN",                  commandID: 2333, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.add),
        .init(name: "SCI_ZOOMOUT",                 commandID: 2334, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.subtract),
        .init(name: "SCI_SETZOOM",                 commandID: 2373, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.divide),
        .init(name: "SCI_SELECTIONDUPLICATE",      commandID: 2469, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("D".unicodeScalars.first!.value)),
        .init(name: "SCI_LINESJOIN",               commandID: 2288, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_SCROLLCARET",             commandID: 2169, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_EDITTOGGLEOVERTYPE",      commandID: 2324, defaultModifiers: 0,                         defaultKey: SCK.insert),
        .init(name: "SCI_MOVECARETINSIDEVIEW",     commandID: 2401, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_LINEDOWN",                commandID: 2300, defaultModifiers: 0,                         defaultKey: SCK.down),
        .init(name: "SCI_LINEDOWNEXTEND",          commandID: 2301, defaultModifiers: SCMOD.shift,               defaultKey: SCK.down),
        .init(name: "SCI_LINEDOWNRECTEXTEND",      commandID: 2426, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.down),
        .init(name: "SCI_LINESCROLLDOWN",          commandID: 2342, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.down),
        .init(name: "SCI_LINEUP",                  commandID: 2302, defaultModifiers: 0,                         defaultKey: SCK.up),
        .init(name: "SCI_LINEUPEXTEND",            commandID: 2303, defaultModifiers: SCMOD.shift,               defaultKey: SCK.up),
        .init(name: "SCI_LINEUPRECTEXTEND",        commandID: 2427, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.up),
        .init(name: "SCI_LINESCROLLUP",            commandID: 2343, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.up),
        .init(name: "SCI_PARADOWN",                commandID: 2413, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("]".unicodeScalars.first!.value)),
        .init(name: "SCI_PARADOWNEXTEND",          commandID: 2414, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: Int("]".unicodeScalars.first!.value)),
        .init(name: "SCI_PARAUP",                  commandID: 2415, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("[".unicodeScalars.first!.value)),
        .init(name: "SCI_PARAUPEXTEND",            commandID: 2416, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: Int("[".unicodeScalars.first!.value)),
        .init(name: "SCI_CHARLEFT",                commandID: 2304, defaultModifiers: 0,                         defaultKey: SCK.left),
        .init(name: "SCI_CHARLEFTEXTEND",          commandID: 2305, defaultModifiers: SCMOD.shift,               defaultKey: SCK.left),
        .init(name: "SCI_CHARLEFTRECTEXTEND",      commandID: 2428, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.left),
        .init(name: "SCI_CHARRIGHT",               commandID: 2306, defaultModifiers: 0,                         defaultKey: SCK.right),
        .init(name: "SCI_CHARRIGHTEXTEND",         commandID: 2307, defaultModifiers: SCMOD.shift,               defaultKey: SCK.right),
        .init(name: "SCI_CHARRIGHTRECTEXTEND",     commandID: 2429, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.right),
        .init(name: "SCI_WORDLEFT",                commandID: 2308, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.left),
        .init(name: "SCI_WORDLEFTEXTEND",          commandID: 2309, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: SCK.left),
        .init(name: "SCI_WORDRIGHT",               commandID: 2310, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.right),
        .init(name: "SCI_WORDRIGHTEXTEND",         commandID: 2311, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_WORDLEFTEND",             commandID: 2439, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_WORDLEFTENDEXTEND",       commandID: 2440, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_WORDRIGHTEND",            commandID: 2441, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_WORDRIGHTENDEXTEND",      commandID: 2442, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: SCK.right),
        .init(name: "SCI_WORDPARTLEFT",            commandID: 2390, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("/".unicodeScalars.first!.value)),
        .init(name: "SCI_WORDPARTLEFTEXTEND",      commandID: 2391, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: Int("/".unicodeScalars.first!.value)),
        .init(name: "SCI_WORDPARTRIGHT",           commandID: 2392, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("\\".unicodeScalars.first!.value)),
        .init(name: "SCI_WORDPARTRIGHTEXTEND",     commandID: 2393, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: Int("\\".unicodeScalars.first!.value)),
        .init(name: "SCI_HOME",                    commandID: 2312, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_HOMEEXTEND",              commandID: 2313, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_HOMERECTEXTEND",          commandID: 2430, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_HOMEDISPLAY",             commandID: 2345, defaultModifiers: SCMOD.alt,                 defaultKey: SCK.home),
        .init(name: "SCI_HOMEDISPLAYEXTEND",       commandID: 2346, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_HOMEWRAP",                commandID: 2349, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_HOMEWRAPEXTEND",          commandID: 2450, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_VCHOME",                  commandID: 2331, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_VCHOMEEXTEND",            commandID: 2332, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_VCHOMERECTEXTEND",        commandID: 2431, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.home),
        .init(name: "SCI_VCHOMEDISPLAY",           commandID: 2333, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_VCHOMEDISPLAYEXTEND",     commandID: 2334, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_VCHOMEWRAP",              commandID: 2453, defaultModifiers: 0,                         defaultKey: SCK.home),
        .init(name: "SCI_VCHOMEWRAPEXTEND",        commandID: 2454, defaultModifiers: SCMOD.shift,               defaultKey: SCK.home),
        .init(name: "SCI_LINEEND",                 commandID: 2314, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_LINEENDWRAPEXTEND",       commandID: 2452, defaultModifiers: SCMOD.shift,               defaultKey: SCK.end),
        .init(name: "SCI_LINEENDRECTEXTEND",       commandID: 2432, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.end),
        .init(name: "SCI_LINEENDDISPLAY",          commandID: 2347, defaultModifiers: SCMOD.alt,                 defaultKey: SCK.end),
        .init(name: "SCI_LINEENDDISPLAYEXTEND",    commandID: 2348, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_LINEENDWRAP",             commandID: 2451, defaultModifiers: 0,                         defaultKey: SCK.end),
        .init(name: "SCI_LINEENDEXTEND",           commandID: 2315, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_DOCUMENTSTART",           commandID: 2316, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.home),
        .init(name: "SCI_DOCUMENTSTARTEXTEND",     commandID: 2317, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: SCK.home),
        .init(name: "SCI_DOCUMENTEND",             commandID: 2318, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.end),
        .init(name: "SCI_DOCUMENTENDEXTEND",       commandID: 2319, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: SCK.end),
        .init(name: "SCI_PAGEUP",                  commandID: 2320, defaultModifiers: 0,                         defaultKey: SCK.prior),
        .init(name: "SCI_PAGEUPEXTEND",            commandID: 2321, defaultModifiers: SCMOD.shift,               defaultKey: SCK.prior),
        .init(name: "SCI_PAGEUPRECTEXTEND",        commandID: 2433, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.prior),
        .init(name: "SCI_PAGEDOWN",                commandID: 2322, defaultModifiers: 0,                         defaultKey: SCK.next),
        .init(name: "SCI_PAGEDOWNEXTEND",          commandID: 2323, defaultModifiers: SCMOD.shift,               defaultKey: SCK.next),
        .init(name: "SCI_PAGEDOWNRECTEXTEND",      commandID: 2434, defaultModifiers: SCMOD.alt|SCMOD.shift,     defaultKey: SCK.next),
        .init(name: "SCI_STUTTEREDPAGEUP",         commandID: 2435, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_STUTTEREDPAGEUPEXTEND",   commandID: 2436, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_STUTTEREDPAGEDOWN",       commandID: 2437, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_STUTTEREDPAGEDOWNEXTEND", commandID: 2438, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_DELETEBACK",              commandID: 2326, defaultModifiers: 0,                         defaultKey: SCK.back),
        .init(name: "SCI_DELETEBACKNOTLINE",       commandID: 2344, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_DELWORDLEFT",             commandID: 2335, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.back),
        .init(name: "SCI_DELWORDRIGHT",            commandID: 2336, defaultModifiers: SCMOD.ctrl,                defaultKey: SCK.delete),
        .init(name: "SCI_DELLINELEFT",             commandID: 2395, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: SCK.back),
        .init(name: "SCI_DELLINERIGHT",            commandID: 2396, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: SCK.delete),
        .init(name: "SCI_LINEDELETE",              commandID: 2338, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: Int("L".unicodeScalars.first!.value)),
        .init(name: "SCI_LINECUT",                 commandID: 2337, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("L".unicodeScalars.first!.value)),
        .init(name: "SCI_LINECOPY",                commandID: 2455, defaultModifiers: SCMOD.ctrl|SCMOD.shift,    defaultKey: Int("X".unicodeScalars.first!.value)),
        .init(name: "SCI_LINETRANSPOSE",           commandID: 2339, defaultModifiers: SCMOD.ctrl,                defaultKey: Int("T".unicodeScalars.first!.value)),
        .init(name: "SCI_LINEDUPLICATE",           commandID: 2404, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_CANCEL",                  commandID: 2325, defaultModifiers: 0,                         defaultKey: SCK.escape),
        .init(name: "SCI_SWAPMAINANCHORCARET",     commandID: 2607, defaultModifiers: 0,                         defaultKey: 0),
        .init(name: "SCI_ROTATESELECTION",         commandID: 2606, defaultModifiers: 0,                         defaultKey: 0),
    ]
}
