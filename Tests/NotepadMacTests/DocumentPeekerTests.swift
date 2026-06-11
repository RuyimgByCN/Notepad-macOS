import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func documentPeekerExcerptLimitsLinesAndLineLength() {
    let longLine = String(repeating: "x", count: 500)
    let text = (0..<100).map { "line\($0) \(longLine)" }.joined(separator: "\n")
    let excerpt = DocumentPeekerController.previewExcerpt(from: text)

    let lines = excerpt.components(separatedBy: "\n")
    #expect(lines.count == DocumentPeekerController.maxPreviewLines)
    #expect(lines.allSatisfy { $0.count <= DocumentPeekerController.maxPreviewLineLength })
    #expect(lines[0].hasPrefix("line0 "))
}

@MainActor
@Test func documentPeekerExcerptKeepsShortTextsIntact() {
    #expect(DocumentPeekerController.previewExcerpt(from: "hello\nworld") == "hello\nworld")
    #expect(DocumentPeekerController.previewExcerpt(from: "") == "")
}

@MainActor
@Test func documentPeekerShowAndHideDoNotCrashOffscreen() {
    let peeker = DocumentPeekerController()
    peeker.show(
        title: "sample.txt",
        previewText: "alpha\nbravo",
        near: NSRect(x: 100, y: 100, width: 120, height: 24)
    )
    peeker.hide()
}

@MainActor
@Test func tabBarPeekCallbackFiresAfterDwellAndCancelsOnExit() async throws {
    let bar = EditorTabBarView(frame: NSRect(x: 0, y: 0, width: 600, height: 28))
    var events: [Bool] = []
    bar.onTabPeek = { identity, _ in events.append(identity != nil) }

    let identity = EditorTabIdentity.untitled("peek-test")
    let button = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 28))

    // Hover then immediate exit: the dwell timer must be cancelled.
    bar.handleTabPeekHover(button, identity: identity, hovering: true)
    bar.handleTabPeekHover(button, identity: identity, hovering: false)
    try await Task.sleep(nanoseconds: 700_000_000)
    #expect(events == [false])
}
