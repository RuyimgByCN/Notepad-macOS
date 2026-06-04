import XCTest
import NotepadMacCore

final class MacroShortcutStoreTests: XCTestCase {

    private func makeStore() -> MacroShortcutStore {
        let defaults = UserDefaults(suiteName: "MacroShortcutStoreTests.\(UUID().uuidString)")!
        return MacroShortcutStore(defaults: defaults)
    }

    func testEmptyStoreReturnsNoShortcuts() {
        let store = makeStore()
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertNil(store.shortcut(for: "MyMacro"))
    }

    func testSetAndRetrieveShortcut() {
        let store = makeStore()
        let sc = MacroShortcut(macroName: "FormatCode", keyEquivalent: "f", modifierFlags: 0)
        store.setShortcut(sc)
        let loaded = store.shortcut(for: "FormatCode")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.keyEquivalent, "f")
        XCTAssertEqual(loaded?.modifierFlags, 0)
    }

    func testShortcutLookupIsCaseInsensitive() {
        let store = makeStore()
        store.setShortcut(MacroShortcut(macroName: "MyMacro", keyEquivalent: "m", modifierFlags: 0))
        XCTAssertNotNil(store.shortcut(for: "mymacro"))
        XCTAssertNotNil(store.shortcut(for: "MYMACRO"))
    }

    func testRemoveShortcut() {
        let store = makeStore()
        store.setShortcut(MacroShortcut(macroName: "DoSomething", keyEquivalent: "d", modifierFlags: 0))
        store.removeShortcut(for: "DoSomething")
        XCTAssertNil(store.shortcut(for: "DoSomething"))
    }

    func testUpdateExistingShortcut() {
        let store = makeStore()
        store.setShortcut(MacroShortcut(macroName: "Macro1", keyEquivalent: "a", modifierFlags: 0))
        store.setShortcut(MacroShortcut(macroName: "Macro1", keyEquivalent: "b", modifierFlags: 0x100000))
        let all = store.load()
        XCTAssertEqual(all.count, 1, "Should replace existing entry")
        XCTAssertEqual(all.first?.keyEquivalent, "b")
    }

    func testMultipleShortcuts() {
        let store = makeStore()
        store.setShortcut(MacroShortcut(macroName: "A", keyEquivalent: "a", modifierFlags: 0))
        store.setShortcut(MacroShortcut(macroName: "B", keyEquivalent: "b", modifierFlags: 0))
        store.setShortcut(MacroShortcut(macroName: "C", keyEquivalent: "c", modifierFlags: 0))
        XCTAssertEqual(store.load().count, 3)
    }

    func testDisplayString() {
        // command = bit 20 = 0x100000
        let commandMods = Int(bitPattern: UInt(1 << 20))
        let sc = MacroShortcut(macroName: "test", keyEquivalent: "m", modifierFlags: commandMods)
        XCTAssertTrue(sc.displayString.contains("⌘"), "Command modifier should show ⌘; got: \(sc.displayString)")
        XCTAssertTrue(sc.displayString.contains("M"), "Key should be uppercased; got: \(sc.displayString)")

        // control = bit 18 = 0x40000
        let controlMods = Int(bitPattern: UInt(1 << 18))
        let sc2 = MacroShortcut(macroName: "test2", keyEquivalent: "t", modifierFlags: controlMods)
        XCTAssertTrue(sc2.displayString.contains("⌃"), "Control modifier should show ⌃; got: \(sc2.displayString)")
    }

    func testEmptyKeyEquivalentGivesEmptyDisplayString() {
        let sc = MacroShortcut(macroName: "test", keyEquivalent: "", modifierFlags: 0)
        XCTAssertEqual(sc.displayString, "")
    }
}
