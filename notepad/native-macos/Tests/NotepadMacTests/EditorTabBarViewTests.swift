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
        #expect(iconView.alphaValue == 1.0)
        #expect(iconView.image?.isTemplate == false)
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

@MainActor
@Test func editorTabButtonPackagesUpstreamTabActionIcons() {
    let resourceNames = [
        "closeTabButton",
        "closeTabButton_hoverIn",
        "closeTabButton_hoverOnTab",
        "closeTabButton_push",
        "empty",
        "pinTabButton",
        "pinTabButton_pinned"
    ]

    for resourceName in resourceNames {
        #expect(
            EditorTabButton.hasUpstreamTabBarIconResource(named: resourceName),
            "Missing upstream tab action icon \(resourceName).ico"
        )
    }
}

@MainActor
@Test func editorTabButtonUsesUpstreamTabActionIconResourceNames() {
    #expect(EditorTabButton.upstreamCloseButtonResourceName(isActive: true, isTabHovered: false, isButtonHovered: false, isPressed: false) == "closeTabButton")
    #expect(EditorTabButton.upstreamCloseButtonResourceName(isActive: false, isTabHovered: false, isButtonHovered: false, isPressed: false) == "empty")
    #expect(EditorTabButton.upstreamCloseButtonResourceName(isActive: false, isTabHovered: true, isButtonHovered: false, isPressed: false) == "closeTabButton_hoverOnTab")
    #expect(EditorTabButton.upstreamCloseButtonResourceName(isActive: true, isTabHovered: true, isButtonHovered: true, isPressed: false) == "closeTabButton_hoverIn")
    #expect(EditorTabButton.upstreamCloseButtonResourceName(isActive: true, isTabHovered: true, isButtonHovered: true, isPressed: true) == "closeTabButton_push")

    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: false, isActive: true, isTabHovered: false, isButtonHovered: false, isPressed: false) == "pinTabButton")
    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: false, isActive: false, isTabHovered: false, isButtonHovered: false, isPressed: false) == "empty")
    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: false, isActive: false, isTabHovered: true, isButtonHovered: false, isPressed: false) == "pinTabButton")
    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: false, isActive: true, isTabHovered: true, isButtonHovered: true, isPressed: false) == "pinTabButton_pinned")
    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: false, isActive: true, isTabHovered: true, isButtonHovered: true, isPressed: true) == "pinTabButton_pinned")
    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: true, isActive: true, isTabHovered: false, isButtonHovered: false, isPressed: false) == "pinTabButton_pinned")
    #expect(EditorTabButton.upstreamPinButtonResourceName(isPinned: true, isActive: true, isTabHovered: true, isButtonHovered: true, isPressed: false) == "pinTabButton")
}

@MainActor
@Test func activeUnpinnedEditorTabShowsPinAndCloseButtons() {
    let item = EditorTabItem(
        identity: .file(URL(fileURLWithPath: "/tmp/project/current.txt")),
        title: "current.txt",
        isDirty: false,
        isPinned: false
    )
    let button = EditorTabButton(
        item: item,
        isActive: true,
        onSelect: {},
        onClose: {},
        onContextAction: { _ in }
    )

    button.frame = CGRect(x: 0, y: 0, width: 150, height: EditorTabBarView.barHeight)
    button.layoutSubtreeIfNeeded()

    let actionButtons = button.subviews.compactMap { $0 as? NSButton }
    let buttonTemplateStates = actionButtons.map { $0.image?.isTemplate }

    #expect(actionButtons.count == 2)
    #expect(actionButtons.allSatisfy { !$0.isHidden })
    #expect(buttonTemplateStates == [false, false])
}

@MainActor
@Test func clickingVisiblePinAreaTogglesPinInsteadOfSelectingTab() throws {
    let item = EditorTabItem(
        identity: .file(URL(fileURLWithPath: "/tmp/project/current.txt")),
        title: "current.txt",
        isDirty: false,
        isPinned: false
    )
    var selected = false
    var toggledPin = false
    let button = EditorTabButton(
        item: item,
        isActive: true,
        onSelect: { selected = true },
        onClose: {},
        onContextAction: { action in
            if case .togglePin = action {
                toggledPin = true
            }
        }
    )

    button.frame = CGRect(x: 0, y: 0, width: 150, height: EditorTabBarView.barHeight)
    button.layoutSubtreeIfNeeded()

    let actionButtons = button.subviews.compactMap { $0 as? NSButton }
    let pinButton = try #require(actionButtons.sorted { $0.frame.minX < $1.frame.minX }.first)
    let event = try #require(NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: NSPoint(x: pinButton.frame.midX, y: pinButton.frame.midY),
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    ))

    button.mouseDown(with: event)

    #expect(toggledPin)
    #expect(!selected)
}
