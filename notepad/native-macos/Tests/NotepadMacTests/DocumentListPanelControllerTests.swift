import Testing
@testable import NotepadMac

@Test func documentListItemUsesFilePathWhenAvailable() {
    let item = DocumentListItem(
        title: "notes.md",
        detail: DocumentListItem.detailText(forPath: "/tmp/project/notes.md", unsavedFallback: "Unsaved document"),
        isActive: false
    )

    #expect(item.detail == "/tmp/project/notes.md")
}

@Test func documentListItemUsesUnsavedFallbackWhenPathMissing() {
    let item = DocumentListItem(
        title: "Untitled",
        detail: DocumentListItem.detailText(forPath: nil, unsavedFallback: "Unsaved document"),
        isActive: true
    )

    #expect(item.detail == "Unsaved document")
    #expect(item.isActive == true)
}
