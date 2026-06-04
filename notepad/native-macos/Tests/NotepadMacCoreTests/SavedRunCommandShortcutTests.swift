import XCTest
import NotepadMacCore

final class SavedRunCommandShortcutTests: XCTestCase {

    func testSavedRunCommandDefaultsToNoShortcut() {
        let cmd = SavedRunCommand(name: "Build", commandLine: "make build")
        XCTAssertEqual(cmd.keyEquivalent, "")
        XCTAssertEqual(cmd.modifierFlags, 0)
    }

    func testSavedRunCommandStoresShortcut() {
        let cmd = SavedRunCommand(name: "Run", commandLine: "python main.py",
                                  keyEquivalent: "r", modifierFlags: Int(bitPattern: UInt(1 << 20)))
        XCTAssertEqual(cmd.keyEquivalent, "r")
        XCTAssertNotEqual(cmd.modifierFlags, 0)
    }

    func testSavedRunCommandShortcutRoundTrip() {
        let defaults = UserDefaults(suiteName: "SavedRunCommandShortcutTests.roundtrip")!
        defer { defaults.removePersistentDomain(forName: "SavedRunCommandShortcutTests.roundtrip") }

        let store = SavedRunCommandStore(defaults: defaults)
        let cmd = SavedRunCommand(name: "MyCmd", commandLine: "echo hello",
                                   keyEquivalent: "e", modifierFlags: 0)
        store.add(cmd)
        let loaded = store.load().first
        XCTAssertEqual(loaded?.keyEquivalent, "e")
        XCTAssertEqual(loaded?.modifierFlags, 0)
    }

    func testSavedRunCommandUpdatePreservesShortcut() {
        let defaults = UserDefaults(suiteName: "SavedRunCommandShortcutTests.update")!
        defer { defaults.removePersistentDomain(forName: "SavedRunCommandShortcutTests.update") }

        let store = SavedRunCommandStore(defaults: defaults)
        var cmd = SavedRunCommand(name: "Test", commandLine: "test.sh", keyEquivalent: "t", modifierFlags: 0)
        store.add(cmd)

        // Update shortcut
        cmd.keyEquivalent = "u"
        store.update(cmd)

        let updated = store.load().first
        XCTAssertEqual(updated?.keyEquivalent, "u")
    }
}
