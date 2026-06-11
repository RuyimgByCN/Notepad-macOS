import Foundation
import Testing
@testable import NotepadMacCore

private func script(_ json: String) throws -> PluginEditScript {
    try PluginEditScript.decode(json.data(using: .utf8)!)
}

@Test func pluginEditScriptDecodesAllActions() throws {
    let decoded = try script("""
    {"version": 1, "edits": [
        {"action": "replaceSelection", "text": "a"},
        {"action": "insertAtCaret", "text": "b"},
        {"action": "replaceRange", "location": 1, "length": 2, "text": "c"},
        {"action": "setText", "text": "d"}
    ]}
    """)

    #expect(decoded.edits == [
        .replaceSelection(text: "a"),
        .insertAtCaret(text: "b"),
        .replaceRange(utf16Location: 1, utf16Length: 2, text: "c"),
        .setText(text: "d")
    ])
}

@Test func pluginEditScriptRejectsMalformedPayloads() {
    #expect(throws: PluginEditScript.DecodeError.self) { try script("not json") }
    #expect(throws: PluginEditScript.DecodeError.unsupportedVersion(2)) {
        try script(#"{"version": 2, "edits": [{"action": "setText", "text": "x"}]}"#)
    }
    #expect(throws: PluginEditScript.DecodeError.missingEdits) {
        try script(#"{"version": 1, "edits": []}"#)
    }
    #expect(throws: PluginEditScript.DecodeError.unknownAction("deleteEverything")) {
        try script(#"{"edits": [{"action": "deleteEverything"}]}"#)
    }
    #expect(throws: PluginEditScript.DecodeError.missingField(action: "replaceSelection", field: "text")) {
        try script(#"{"edits": [{"action": "replaceSelection"}]}"#)
    }
    #expect(throws: PluginEditScript.DecodeError.negativeRangeField(action: "replaceRange", field: "location")) {
        try script(#"{"edits": [{"action": "replaceRange", "location": -1, "length": 0, "text": "x"}]}"#)
    }
}

@Test func pluginEditScriptAppliesSequentialEdits() throws {
    let editScript = PluginEditScript(edits: [
        .replaceSelection(text: "WORLD"),
        .insertAtCaret(text: "!")
    ])

    let text = "hello world"
    let selection = (text as NSString).range(of: "world")
    let result = try editScript.apply(to: text, selection: selection)

    #expect(result.text == "hello WORLD!")
    #expect(result.selectedRange == NSRange(location: "hello WORLD!".utf16.count, length: 0))
    #expect(result.appliedEditCount == 2)
}

@Test func pluginEditScriptReplaceRangeUsesAbsoluteOffsetsAndValidatesBounds() throws {
    let editScript = PluginEditScript(edits: [
        .replaceRange(utf16Location: 0, utf16Length: 5, text: "howdy")
    ])
    let result = try editScript.apply(to: "hello world", selection: NSRange(location: 0, length: 0))
    #expect(result.text == "howdy world")

    let outOfBounds = PluginEditScript(edits: [
        .replaceRange(utf16Location: 8, utf16Length: 10, text: "x")
    ])
    #expect(throws: PluginEditScript.ApplyError.rangeOutOfBounds(utf16Location: 8, utf16Length: 10, bufferLength: 11)) {
        try outOfBounds.apply(to: "hello world", selection: NSRange(location: 0, length: 0))
    }
}

@Test func pluginEditScriptSetTextResetsSelection() throws {
    let editScript = PluginEditScript(edits: [.setText(text: "fresh")])
    let result = try editScript.apply(to: "old content", selection: NSRange(location: 4, length: 3))
    #expect(result.text == "fresh")
    #expect(result.selectedRange == NSRange(location: 0, length: 0))
}

@Test func pluginRuntimeExposesHostOwnedEditScriptEnvironmentKey() throws {
    #expect(PluginCommandRuntime.editScriptFileEnvironmentKey == "NOTEPAD_MAC_EDIT_SCRIPT_FILE")

    let invocationWithFile = PluginCommandInvocation(
        pluginIdentifier: "p",
        commandIdentifier: "c",
        editScriptFileURL: URL(fileURLWithPath: "/tmp/edit.json")
    )
    #expect(invocationWithFile.editScriptFileURL?.path == "/tmp/edit.json")
}
