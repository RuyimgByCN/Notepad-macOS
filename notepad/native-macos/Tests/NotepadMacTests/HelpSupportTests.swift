import Testing
import Foundation
@testable import NotepadMac

@Suite("Help Support Tests")
struct HelpSupportTests {

    @Test func helpSupportBuildsAboutText() {
        let text = HelpSupport.aboutText(appName: "NotepadMac", version: "1.0", subtitle: "Test")
        #expect(text.contains("NotepadMac"))
        #expect(text.contains("1.0"))
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

    @Test func debugInfoIncludesExtendedFields() {
        let text = HelpSupport.debugInfoText(
            documentName: "test.txt",
            documentPath: "/home/test.txt",
            editorBackend: "Scintilla",
            supportsFolding: false,
            currentTheme: "Dark Mode",
            scintillaVersion: "Cocoa (bundled)",
            lexillaVersion: "Cocoa (bundled)",
            preferencesPath: "/tmp/prefs.json"
        )

        #expect(text.contains("Theme: Dark Mode"))
        #expect(text.contains("Scintilla: Cocoa (bundled)"))
        #expect(text.contains("Lexilla: Cocoa (bundled)"))
        #expect(text.contains("Preferences: /tmp/prefs.json"))
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
}
