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
    // Existing files keep their on-disk name even when a language extension is provided.
    #expect(
        strings.saveAsName(
            fileURL: fileURL,
            untitledBaseName: "Untitled1",
            preferredExtension: "swift"
        ) == "notes.md"
    )
}

@Test func editorDisplayStringsSaveAsNameUsesNumberedUntitledBaseAndLanguageExtension() {
    let english = EditorDisplayStrings(
        untitledDocumentName: "Untitled",
        untitledFileName: "Untitled.txt",
        windowTitleFormat: "%@ - Notepad++ Mac"
    )

    #expect(
        english.saveAsName(
            fileURL: nil,
            untitledBaseName: "Untitled1",
            preferredExtension: "txt"
        ) == "Untitled1.txt"
    )
    #expect(
        english.saveAsName(
            fileURL: nil,
            untitledBaseName: "Untitled2",
            preferredExtension: "swift"
        ) == "Untitled2.swift"
    )
    #expect(
        english.saveAsName(
            fileURL: nil,
            untitledBaseName: "Untitled3",
            preferredExtension: ".py"
        ) == "Untitled3.py"
    )
    #expect(
        english.saveAsName(
            fileURL: nil,
            untitledBaseName: "Untitled1",
            preferredExtension: nil
        ) == "Untitled1.txt"
    )
    #expect(
        english.saveAsName(fileURL: nil, preferredExtension: "rs") == "Untitled.rs"
    )
}

@Test func editorDisplayStringsSaveAsNameUsesChineseNumberedBase() {
    let chinese = EditorDisplayStrings(
        untitledDocumentName: "未命名",
        untitledFileName: "未命名.txt",
        windowTitleFormat: "%@ - 记事本"
    )

    #expect(
        chinese.saveAsName(
            fileURL: nil,
            untitledBaseName: "新文件1",
            preferredExtension: "txt"
        ) == "新文件1.txt"
    )
    #expect(
        chinese.saveAsName(
            fileURL: nil,
            untitledBaseName: "新文件2",
            preferredExtension: "swift"
        ) == "新文件2.swift"
    )
    #expect(
        chinese.saveAsName(
            fileURL: nil,
            untitledBaseName: "新文件3",
            preferredExtension: "json"
        ) == "新文件3.json"
    )
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
