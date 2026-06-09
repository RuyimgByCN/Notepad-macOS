import AppKit
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

@MainActor
@Test func documentListTitleCellsReserveSpaceForDocumentIcon() {
    let cleanItem = DocumentListItem(
        title: "notes.md",
        detail: "/tmp/project/notes.md",
        isActive: true
    )
    let dirtyItem = DocumentListItem(
        title: "notes.md",
        detail: "/tmp/project/notes.md",
        isActive: true,
        isDirty: true
    )

    #expect(DocumentListPanelController.titleColumnInitialWidth == 200)
    #expect(DocumentListPanelController.titleText(for: cleanItem) == "notes.md")
    #expect(DocumentListPanelController.titleText(for: dirtyItem) == "● notes.md")
    #expect(DocumentListPanelController.documentIconSymbolName(for: cleanItem) == "doc.text")
    #expect(DocumentListPanelController.documentIconSymbolName(for: dirtyItem) == "doc.badge.ellipsis")
}
