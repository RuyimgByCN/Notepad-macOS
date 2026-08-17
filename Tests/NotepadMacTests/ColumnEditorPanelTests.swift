import Testing
@testable import NotepadMac

@MainActor
@Test func columnEditorLineRangeClampsAndAcceptsReverseInput() {
    #expect(ColumnEditorPanelController.normalizedLineRange(start: 1, end: 8, lineCount: 8) == 1...8)
    #expect(ColumnEditorPanelController.normalizedLineRange(start: 6, end: 2, lineCount: 5) == 2...5)
    #expect(ColumnEditorPanelController.normalizedLineRange(start: 0, end: 99, lineCount: 0) == 1...1)
}
