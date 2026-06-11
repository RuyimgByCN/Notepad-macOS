import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
private func makePanel() -> (FindPanelController, EditorWindowController, UserDefaults) {
    let defaults = UserDefaults(suiteName: "test.findPanel.upstream.\(UUID().uuidString)")!
    let store = PreferencesStore(defaults: defaults)
    let controller = EditorWindowController(preferencesStore: store)
    let panel = FindPanelController(editor: controller, preferencesStore: store)
    return (panel, controller, defaults)
}

@MainActor
@Test func findPanelHasUpstreamTabOrder() {
    let (panel, controller, _) = makePanel()
    defer { controller.editorSurface.teardown() }

    let tabView = findTabView(in: panel.window?.contentView)
    #expect(tabView != nil)
    let identifiers = tabView?.tabViewItems.compactMap { $0.identifier as? Int }
    #expect(identifiers == [0, 1, 2, 3, 4])  // Find, Replace, Find in Files, Find in Projects, Mark
}

@MainActor
@Test func findPanelShowsPerTabButtonsLikeUpstream() {
    let (panel, controller, _) = makePanel()
    defer { controller.editorSurface.teardown() }
    guard let contentView = panel.window?.contentView,
          let tabView = findTabView(in: contentView) else {
        Issue.record("tab view missing")
        return
    }

    func visibleButtonTitles() -> Set<String> {
        var titles: Set<String> = []
        func walk(_ view: NSView) {
            if let button = view as? NSButton, !button.isHidden, !button.title.isEmpty,
               button.window != nil {
                titles.insert(button.title)
            }
            view.subviews.forEach(walk)
        }
        walk(contentView)
        return titles
    }

    // Find tab
    tabView.selectTabViewItem(at: 0)
    var titles = visibleButtonTitles()
    #expect(titles.contains("Find Next"))
    #expect(titles.contains("Count"))
    #expect(titles.contains("Find All in Current Document"))
    #expect(titles.contains("Find All in All Opened Documents"))
    #expect(titles.contains("Close"))
    #expect(!titles.contains("Replace All"))
    #expect(!titles.contains("Mark All"))
    #expect(titles.contains("Backward direction"))
    #expect(titles.contains("Wrap around"))

    // Replace tab
    tabView.selectTabViewItem(at: 1)
    titles = visibleButtonTitles()
    #expect(titles.contains("Replace"))
    #expect(titles.contains("Replace All"))
    #expect(titles.contains("Replace All in All Opened Documents"))
    #expect(!titles.contains("Count"))

    // Mark tab
    tabView.selectTabViewItem(at: 4)
    titles = visibleButtonTitles()
    #expect(titles.contains("Mark All"))
    #expect(titles.contains("Clear all marks"))
    #expect(titles.contains("Copy Marked Text"))
    #expect(titles.contains("Bookmark line"))
    #expect(titles.contains("Purge for each search"))
    #expect(!titles.contains("Find Next"))
}

@MainActor
@Test func findPanelBackwardDirectionPersistsThroughDialogState() {
    let (panel, controller, defaults) = makePanel()
    defer { controller.editorSurface.teardown() }
    _ = panel  // panel loads state on init

    let store = PreferencesStore(defaults: defaults)
    var state = store.loadFindDialogState()
    #expect(state.backwardDirection == false)
    state.backwardDirection = true
    store.saveFindDialogState(state)
    #expect(store.loadFindDialogState().backwardDirection == true)
}

@MainActor
private func findTabView(in view: NSView?) -> NSTabView? {
    guard let view else { return nil }
    if let tabView = view as? NSTabView { return tabView }
    for subview in view.subviews {
        if let found = findTabView(in: subview) { return found }
    }
    return nil
}

@MainActor
@Test func findComboBoxFillsAvailableWidthOnFirstOpen() {
    let (panel, controller, _) = makePanel()
    defer { controller.editorSurface.teardown() }
    guard let contentView = panel.window?.contentView else {
        Issue.record("content view missing")
        return
    }
    panel.window?.layoutIfNeeded()
    contentView.layoutSubtreeIfNeeded()

    func firstComboBox(_ view: NSView) -> NSComboBox? {
        if let box = view as? NSComboBox { return box }
        for subview in view.subviews {
            if let found = firstComboBox(subview) { return found }
        }
        return nil
    }

    let combo = firstComboBox(contentView)
    #expect(combo != nil)
    // On a 660pt-wide dialog the find field must occupy a substantial
    // width, not collapse to its intrinsic minimum.
    #expect((combo?.frame.width ?? 0) > 200)
}
