import Testing
@testable import NotepadMac

@Test func macroDisplayNamesHidesPlaceholderRecordingNamesFromEditing() {
    #expect(MacroDisplayNames.editableName(for: MacroDisplayNames.placeholderRecordingName) == "")
    #expect(MacroDisplayNames.editableName(for: "Last Macro") == "")
    #expect(MacroDisplayNames.editableName(for: "  Last Macro  ") == "")
}

@Test func macroDisplayNamesKeepsRealUserNames() {
    #expect(MacroDisplayNames.editableName(for: "Build Release") == "Build Release")
}
