import Foundation
import Testing
@testable import NotepadMac

@Test func editorDisplayStringsUsesLocalizedUntitledNames() {
    let strings = EditorDisplayStrings.localized { key, defaultValue in
        switch key {
        case .editorUntitledDocumentName:
            return "未命名"
        case .editorUntitledFileName:
            return "未命名.txt"
        case .editorWindowTitleFormat:
            return "%@ - 记事本"
        default:
            return defaultValue
        }
    }

    #expect(strings.displayName(fileURL: nil, fallbackDisplayName: nil) == "未命名")
    #expect(strings.saveAsName(fileURL: nil) == "未命名.txt")
    #expect(strings.windowTitle(displayName: "未命名", isDirty: false) == "未命名 - 记事本")
}

@Test func editorDisplayStringsUsesFileNameWhenAvailable() {
    let strings = EditorDisplayStrings(
        untitledDocumentName: "Untitled",
        untitledFileName: "Untitled.txt",
        windowTitleFormat: "%@ - Notepad++ Mac"
    )
    let fileURL = URL(filePath: "/tmp/notes.md")

    #expect(strings.displayName(fileURL: fileURL, fallbackDisplayName: "Ignored") == "notes.md")
    #expect(strings.saveAsName(fileURL: fileURL) == "notes.md")
}

@Test func editorDisplayStringsPrefixesDirtyWindowTitles() {
    let strings = EditorDisplayStrings(
        untitledDocumentName: "Untitled",
        untitledFileName: "Untitled.txt",
        windowTitleFormat: "%@ - Notepad++ Mac"
    )

    #expect(strings.windowTitle(displayName: "notes.md", isDirty: true) == "*notes.md - Notepad++ Mac")
}

@Test func editorDisplayStringsNormalizesLegacyUntitledFallbackNames() {
    let strings = EditorDisplayStrings(
        untitledDocumentName: "未命名",
        untitledFileName: "未命名.txt",
        windowTitleFormat: "%@ - 记事本"
    )

    #expect(strings.displayName(fileURL: nil, fallbackDisplayName: "Untitled") == "未命名")
    #expect(strings.displayName(fileURL: nil, fallbackDisplayName: "  Untitled  ") == "未命名")
}
