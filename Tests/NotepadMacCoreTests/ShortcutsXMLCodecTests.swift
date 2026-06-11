import Foundation
import Testing
@testable import NotepadMacCore

// NSEvent.ModifierFlags raw values used in tests:
//   command = 1<<20 = 0x100000
//   option  = 1<<19 = 0x080000
//   shift   = 1<<17 = 0x020000

@Test func shortcutsXMLCodecRoundTrips() throws {
    let input = [
        CustomShortcut(menuItemTitle: "Save", keyEquivalent: "s", modifierFlags: 0x100000),
        CustomShortcut(menuItemTitle: "Find...", keyEquivalent: "f", modifierFlags: 0x100000),
        CustomShortcut(menuItemTitle: "Find Next", keyEquivalent: "f", modifierFlags: 0x120000),
    ]
    let data = try #require(ShortcutsXMLCodec.encode(input))
    let decoded = try #require(ShortcutsXMLCodec.decode(data))

    #expect(decoded.count == 3)
    #expect(decoded[0].menuItemTitle == "Save")
    #expect(decoded[0].keyEquivalent == "s")
    #expect(decoded[0].modifierFlags == 0x100000)

    #expect(decoded[1].menuItemTitle == "Find...")
    #expect(decoded[1].keyEquivalent == "f")

    #expect(decoded[2].menuItemTitle == "Find Next")
    #expect(decoded[2].modifierFlags & 0x020000 != 0) // shift bit set
}

@Test func shortcutsXMLCodecEncodesXMLSpecialCharsInTitle() throws {
    let input = [CustomShortcut(menuItemTitle: "Open & Save <All>", keyEquivalent: "a", modifierFlags: 0x100000)]
    let data = try #require(ShortcutsXMLCodec.encode(input))
    let xml = try #require(String(data: data, encoding: .utf8))
    #expect(xml.contains("Open &amp; Save &lt;All&gt;"))
    let decoded = try #require(ShortcutsXMLCodec.decode(data))
    #expect(decoded[0].menuItemTitle == "Open & Save <All>")
}

@Test func shortcutsXMLCodecHandlesSpecialKeys() throws {
    // Arrow keys use Unicode private-use area
    let input = [
        CustomShortcut(menuItemTitle: "Test", keyEquivalent: "\u{F700}", modifierFlags: 0x100000),
    ]
    let data = try #require(ShortcutsXMLCodec.encode(input))
    let decoded = try #require(ShortcutsXMLCodec.decode(data))
    #expect(decoded[0].keyEquivalent == "\u{F700}")
}

@Test func shortcutsXMLCodecEmptyInput() throws {
    let data = try #require(ShortcutsXMLCodec.encode([]))
    let decoded = try #require(ShortcutsXMLCodec.decode(data))
    #expect(decoded.isEmpty)
}

@Test func shortcutsXMLCodecRejectsBadXML() {
    let bad = "not xml at all 🔥".data(using: .utf8)!
    let result = ShortcutsXMLCodec.decode(bad)
    #expect(result == nil)
}

@Test func shortcutsXMLCodecSkipsItemsWithoutTitle() throws {
    // Items from a pure Notepad++ file have no menuItemTitle — they should be skipped.
    let xmlStr = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <NotepadPlus>
        <InternalCommands>
            <Shortcut id="41001" Ctrl="yes" Alt="no" Shift="no" Key="83" />
        </InternalCommands>
    </NotepadPlus>
    """
    let data = xmlStr.data(using: .utf8)!
    let decoded = try #require(ShortcutsXMLCodec.decode(data))
    #expect(decoded.isEmpty)
}

@Test func shortcutsXMLValidatorPassesWellFormedFile() {
    let xmlStr = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <NotepadPlus>
        <InternalCommands>
            <Shortcut id="0" menuItemTitle="Save" Ctrl="yes" Alt="no" Shift="no" Key="83" />
            <Shortcut id="0" menuItemTitle="Open" Ctrl="yes" Alt="no" Shift="no" Key="79" />
        </InternalCommands>
    </NotepadPlus>
    """
    let report = ShortcutsXMLCodec.validate(xmlStr.data(using: .utf8)!)
    #expect(report.isValid)
    #expect(report.shortcutCount == 2)
}

@Test func shortcutsXMLValidatorReportsMalformedXML() {
    let report = ShortcutsXMLCodec.validate("<NotepadPlus><Internal".data(using: .utf8)!)
    #expect(!report.isValid)
}

@Test func shortcutsXMLValidatorReportsMissingInternalCommands() {
    let xmlStr = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <NotepadPlus></NotepadPlus>
    """
    let report = ShortcutsXMLCodec.validate(xmlStr.data(using: .utf8)!)
    #expect(!report.isValid)
    #expect(report.issues.contains { $0.message.contains("InternalCommands") })
}

@Test func shortcutsXMLValidatorReportsInvalidModifierAndKey() {
    let xmlStr = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <NotepadPlus>
        <InternalCommands>
            <Shortcut id="0" menuItemTitle="Bad" Ctrl="maybe" Alt="no" Shift="no" Key="abc" />
        </InternalCommands>
    </NotepadPlus>
    """
    let report = ShortcutsXMLCodec.validate(xmlStr.data(using: .utf8)!)
    #expect(report.issues.count == 2)
    #expect(report.issues.contains { $0.message.contains("Ctrl=\"maybe\"") })
    #expect(report.issues.contains { $0.message.contains("Key=\"abc\"") })
}

@Test func shortcutsXMLValidatorReportsDuplicateCombination() {
    let xmlStr = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <NotepadPlus>
        <InternalCommands>
            <Shortcut id="0" menuItemTitle="Save" Ctrl="yes" Alt="no" Shift="no" Key="83" />
            <Shortcut id="0" menuItemTitle="Stop" Ctrl="yes" Alt="no" Shift="no" Key="83" />
        </InternalCommands>
    </NotepadPlus>
    """
    let report = ShortcutsXMLCodec.validate(xmlStr.data(using: .utf8)!)
    #expect(report.issues.count == 1)
    #expect(report.issues.first?.message.contains("conflicts") == true)
}
