import Foundation
import Testing
@testable import NotepadMac

@Test func helpSupportBuildsAboutText() {
    let text = HelpSupport.aboutText(
        appName: "Notepad++ Mac",
        version: "0.1.0",
        subtitle: "Native macOS prototype"
    )

    #expect(text.contains("Notepad++ Mac"))
    #expect(text.contains("0.1.0"))
    #expect(text.contains("Native macOS prototype"))
}

@Test func helpSupportBuildsDebugInfoText() {
    let text = HelpSupport.debugInfoText(
        documentName: "notes.md",
        documentPath: "/tmp/notes.md",
        editorBackend: "Scintilla",
        supportsFolding: true
    )

    #expect(text.contains("notes.md"))
    #expect(text.contains("/tmp/notes.md"))
    #expect(text.contains("Scintilla"))
    #expect(text.contains("yes"))
}

@Test func helpSupportBuildsCommandLineArgumentsText() {
    let text = HelpSupport.commandLineArgumentsText(appName: "NotepadMac")

    #expect(text.contains("NotepadMac"))
    #expect(text.contains("file paths"))
    #expect(text.contains("-nosession"))
    #expect(text.contains("-n <line>"))
}

@Test func helpSupportExposesOnlineHelpLinks() {
    #expect(HelpSupport.url(for: .home).absoluteString == "https://notepad-plus-plus.org/")
    #expect(HelpSupport.url(for: .projectPage).absoluteString == "https://github.com/notepad-plus-plus/notepad-plus-plus")
    #expect(HelpSupport.url(for: .userManual).absoluteString == "https://npp-user-manual.org/")
    #expect(HelpSupport.url(for: .forum).absoluteString == "https://community.notepad-plus-plus.org/")
    #expect(HelpSupport.url(for: .downloads).absoluteString == "https://notepad-plus-plus.org/downloads/")
}
