import Testing
@testable import NotepadMac

@Test func clipboardHistoryStoreRecordsNewestEntriesFirst() {
    let store = ClipboardHistoryStore(maximumEntries: 5)

    store.record("alpha")
    store.record("beta")

    #expect(store.entries == ["beta", "alpha"])
}

@Test func clipboardHistoryStoreMovesDuplicateEntryToFrontWithoutDuplicating() {
    let store = ClipboardHistoryStore(maximumEntries: 5)

    store.record("alpha")
    store.record("beta")
    store.record("alpha")

    #expect(store.entries == ["alpha", "beta"])
}

@Test func clipboardHistoryStoreTrimsToMaximumEntries() {
    let store = ClipboardHistoryStore(maximumEntries: 2)

    store.record("alpha")
    store.record("beta")
    store.record("charlie")

    #expect(store.entries == ["charlie", "beta"])
}

@Test func clipboardHistoryStoreIgnoresEmptyEntries() {
    let store = ClipboardHistoryStore(maximumEntries: 5)

    store.record("")
    store.record("   ")
    store.record("alpha")

    #expect(store.entries == ["alpha"])
}
