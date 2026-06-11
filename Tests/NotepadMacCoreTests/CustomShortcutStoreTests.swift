import Foundation
import Testing
@testable import NotepadMacCore

@Test func customShortcutStoreRoundTrips() {
    let defaults = UserDefaults(suiteName: "test.customShortcutStore.\(UUID().uuidString)")!
    let store = CustomShortcutStore(defaults: defaults)

    let cmd_s = CustomShortcut(menuItemTitle: "Save", keyEquivalent: "s", modifierFlags: 0x00100000)
    store.setShortcut(cmd_s)

    let loaded = store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].menuItemTitle == "Save")
    #expect(loaded[0].keyEquivalent == "s")
}

@Test func customShortcutStoreDeduplicatesByTitle() {
    let defaults = UserDefaults(suiteName: "test.customShortcutStore.\(UUID().uuidString)")!
    let store = CustomShortcutStore(defaults: defaults)

    store.setShortcut(CustomShortcut(menuItemTitle: "Open", keyEquivalent: "o", modifierFlags: 0x00100000))
    store.setShortcut(CustomShortcut(menuItemTitle: "Open", keyEquivalent: "p", modifierFlags: 0x00100000))

    let loaded = store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].keyEquivalent == "p")
}

@Test func customShortcutStoreRemovesShortcut() {
    let defaults = UserDefaults(suiteName: "test.customShortcutStore.\(UUID().uuidString)")!
    let store = CustomShortcutStore(defaults: defaults)

    store.setShortcut(CustomShortcut(menuItemTitle: "Close", keyEquivalent: "w", modifierFlags: 0x00100000))
    #expect(store.load().count == 1)

    store.removeShortcut(forTitle: "Close")
    #expect(store.load().isEmpty)
}

@Test func customShortcutStoreFindsConflict() {
    let defaults = UserDefaults(suiteName: "test.customShortcutStore.\(UUID().uuidString)")!
    let store = CustomShortcutStore(defaults: defaults)

    store.setShortcut(CustomShortcut(menuItemTitle: "Save All", keyEquivalent: "s", modifierFlags: 0x00100000 | 0x00020000))
    store.setShortcut(CustomShortcut(menuItemTitle: "Close All", keyEquivalent: "w", modifierFlags: 0x00100000))

    // Conflict: another item uses s+shift+cmd
    let conflict = store.conflictingTitle(keyEquivalent: "s", modifierFlags: 0x00100000 | 0x00020000, excluding: "Other")
    #expect(conflict == "Save All")

    // No conflict for a unique combo
    let noConflict = store.conflictingTitle(keyEquivalent: "x", modifierFlags: 0x00100000, excluding: "Other")
    #expect(noConflict == nil)
}

@Test func customShortcutDisplayStringFormatsCorrectly() {
    // command = bit 20 = 0x100000 → ⌘
    let cmdS = CustomShortcut(menuItemTitle: "Save", keyEquivalent: "s", modifierFlags: Int(bitPattern: UInt(1 << 20)))
    #expect(cmdS.displayString == "⌘S")
    // control = bit 18 = 0x40000 → ⌃
    let ctrlT = CustomShortcut(menuItemTitle: "Test", keyEquivalent: "t", modifierFlags: Int(bitPattern: UInt(1 << 18)))
    #expect(ctrlT.displayString == "⌃T")
}

@Test func customShortcutStoreReturnsEmptyWhenNew() {
    let defaults = UserDefaults(suiteName: "test.customShortcutStore.\(UUID().uuidString)")!
    let store = CustomShortcutStore(defaults: defaults)
    #expect(store.load().isEmpty)
    #expect(store.shortcut(forTitle: "Save") == nil)
}
