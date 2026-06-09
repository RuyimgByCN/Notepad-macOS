import Testing
@testable import NotepadMac

@MainActor
@Test func quitUnsavedChangesPromptFormatsDocumentTitleWithoutRawPlaceholders() {
    let message = AppDelegate.quitUnsavedChangesInformativeText(documentTitle: "notes.txt")

    #expect(message.contains("notes.txt"))
    #expect(!message.contains("%d"))
    #expect(!message.contains("%@"))
    #expect(!message.contains("%1$@"))
}

@MainActor
@Test func closeUnsavedChangesPromptFormatsCountAndActionWithoutRawPlaceholders() {
    let message = AppDelegate.closeUnsavedChangesInformativeText(label: "Close All", count: 3)

    #expect(message.contains("3"))
    #expect(message.contains("Close All"))
    #expect(!message.contains("%d"))
    #expect(!message.contains("%@"))
    #expect(!message.contains("%1$@"))
}
