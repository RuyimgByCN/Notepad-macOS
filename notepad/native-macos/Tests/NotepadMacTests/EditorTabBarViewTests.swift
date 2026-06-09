import AppKit
import Testing
@testable import NotepadMac
@testable import NotepadMacCore

@MainActor
@Test func editorTabButtonShowsDocumentIconBeforeFilename() {
    let item = EditorTabItem(
        identity: .file(URL(fileURLWithPath: "/tmp/project/notes.md")),
        title: "notes.md",
        isDirty: false,
        isPinned: true
    )
    let button = EditorTabButton(
        item: item,
        isActive: true,
        onSelect: {},
        onClose: {},
        onContextAction: { _ in }
    )

    button.frame = CGRect(x: 0, y: 0, width: 140, height: EditorTabBarView.barHeight)
    button.layoutSubtreeIfNeeded()

    let iconViews = button.subviews.compactMap { $0 as? NSImageView }
    let titleFields = button.subviews.compactMap { $0 as? NSTextField }

    #expect(EditorTabButton.minWidth >= 110)
    #expect(iconViews.count == 1)
    #expect(titleFields.count == 1)
    if let iconView = iconViews.first, let titleField = titleFields.first {
        #expect(iconView.frame.minX < titleField.frame.minX)
        #expect(iconView.frame.maxX <= titleField.frame.minX)
    }
}

@MainActor
@Test func editorTabButtonUsesUpstreamStatusIconResourceNames() {
    let clean = EditorTabItem(
        identity: .file(URL(fileURLWithPath: "/tmp/project/clean.txt")),
        title: "clean.txt",
        isDirty: false
    )
    let dirty = EditorTabItem(
        identity: .file(URL(fileURLWithPath: "/tmp/project/dirty.txt")),
        title: "dirty.txt",
        isDirty: true
    )
    let monitoring = EditorTabItem(
        identity: .file(URL(fileURLWithPath: "/tmp/project/log.txt")),
        title: "log.txt",
        isDirty: false,
        isMonitoring: true
    )

    #expect(EditorTabButton.upstreamDocumentIconResourceName(for: clean) == "saved")
    #expect(EditorTabButton.upstreamDocumentIconResourceName(for: dirty) == "unsaved")
    #expect(EditorTabButton.upstreamDocumentIconResourceName(for: monitoring) == "monitoring")
}
