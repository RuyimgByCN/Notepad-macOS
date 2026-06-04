import Foundation
import Testing
@testable import NotepadMacCore

@Test func savedRunCommandStoreRoundTrips() {
    let defaults = UserDefaults(suiteName: "test.savedRunCommandStore.\(UUID().uuidString)")!
    let store = SavedRunCommandStore(defaults: defaults)

    let cmd1 = SavedRunCommand(name: "Build", commandLine: "swift build")
    let cmd2 = SavedRunCommand(name: "Test", commandLine: "swift test")
    store.save([cmd1, cmd2])

    let loaded = store.load()
    #expect(loaded.count == 2)
    #expect(loaded[0].name == "Build")
    #expect(loaded[1].commandLine == "swift test")
}

@Test func savedRunCommandStoreAddDeduplicatesByName() {
    let defaults = UserDefaults(suiteName: "test.savedRunCommandStore.\(UUID().uuidString)")!
    let store = SavedRunCommandStore(defaults: defaults)

    store.add(SavedRunCommand(name: "Build", commandLine: "swift build"))
    store.add(SavedRunCommand(name: "Build", commandLine: "swift build --release"))

    let commands = store.load()
    #expect(commands.count == 1)
    #expect(commands[0].commandLine == "swift build --release")
}

@Test func savedRunCommandStoreRemovesById() {
    let defaults = UserDefaults(suiteName: "test.savedRunCommandStore.\(UUID().uuidString)")!
    let store = SavedRunCommandStore(defaults: defaults)

    let cmd = SavedRunCommand(name: "Run", commandLine: "python3 script.py")
    store.add(cmd)
    #expect(store.load().count == 1)

    store.remove(id: cmd.id)
    #expect(store.load().isEmpty)
}

@Test func savedRunCommandStoreUpdatesExisting() {
    let defaults = UserDefaults(suiteName: "test.savedRunCommandStore.\(UUID().uuidString)")!
    let store = SavedRunCommandStore(defaults: defaults)

    var cmd = SavedRunCommand(name: "Deploy", commandLine: "deploy.sh")
    store.add(cmd)

    cmd = SavedRunCommand(id: cmd.id, name: "Deploy", commandLine: "deploy.sh --production")
    store.update(cmd)

    let commands = store.load()
    #expect(commands.count == 1)
    #expect(commands[0].commandLine == "deploy.sh --production")
}

@Test func savedRunCommandStoreReturnsEmptyForNewStore() {
    let defaults = UserDefaults(suiteName: "test.savedRunCommandStore.\(UUID().uuidString)")!
    let store = SavedRunCommandStore(defaults: defaults)
    #expect(store.load().isEmpty)
}
