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
private func searchControls<T: NSView>(_ type: T.Type, in view: NSView?) -> [T] {
    guard let view else { return [] }
    return (view as? T).map { [$0] } ?? []
        + view.subviews.flatMap { searchControls(type, in: $0) }
}

@MainActor
@Test func findPanelRunsFileSearchAsynchronouslyAndCancelsOnClose() async throws {
    let (panel, editor, _) = makePanel()
    defer { editor.editorSurface.teardown() }
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try "hit".write(to: directory.appending(path: "sample.txt"), atomically: true, encoding: .utf8)
    let root = panel.window?.contentView
    findTabView(in: root)?.selectTabViewItem(at: 2)
    let fields = searchControls(NSComboBox.self, in: root)
    #expect(fields.count == 4)
    guard fields.count == 4 else { return }
    fields[0].stringValue = "hit"
    fields[2].stringValue = directory.path
    fields[3].stringValue = "*.txt"
    let replace = try #require(searchControls(NSButton.self, in: root).first {
        $0.action == NSSelectorFromString("findInFilesReplaceAll:")
    })
    panel.perform(NSSelectorFromString("findInFilesFindAll:"), with: nil)
    #expect(!replace.isEnabled)
    for _ in 0..<200 where !replace.isEnabled { try await Task.sleep(for: .milliseconds(5)) }
    #expect(replace.isEnabled)
    panel.perform(NSSelectorFromString("findInFilesFindAll:"), with: nil)
    #expect(!replace.isEnabled)
    panel.window?.close()
    #expect(replace.isEnabled)
}

@MainActor
@Test func fileSearchPanelPublishesOnlyTheLatestBackgroundSearch() async throws {
    let (_, editor, _) = makePanel()
    defer { editor.editorSurface.teardown() }
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try ("first\n" + String(repeating: "hit\n", count: 1_000))
        .write(to: directory.appending(path: "sample.txt"), atomically: true, encoding: .utf8)
    let store = FindInFilesResultsStore()
    var publications = 0
    let panel = FindInFilesPanelController(editor: editor, resultsStore: store) { publications += 1 }
    let fields = searchControls(NSTextField.self, in: panel.window?.contentView)
    let query = try #require(fields.first {
        $0.placeholderString == Localization.string(.findInFilesFindPlaceholder, default: "Search term")
    })
    let directoryField = try #require(fields.first {
        $0.placeholderString == Localization.string(.findInFilesDirectoryPlaceholder, default: "Directory path")
    })
    directoryField.stringValue = directory.path
    query.stringValue = "hit"
    panel.perform(NSSelectorFromString("performFind:"), with: nil)
    #expect(publications == 0)
    query.stringValue = "first"
    panel.perform(NSSelectorFromString("performFind:"), with: nil)
    for _ in 0..<200 where publications == 0 { try await Task.sleep(for: .milliseconds(5)) }
    #expect(publications == 1)
    #expect(store.matches.count == 1)
    #expect(store.matches.first?.lineText == "first")
    panel.window?.close()
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
