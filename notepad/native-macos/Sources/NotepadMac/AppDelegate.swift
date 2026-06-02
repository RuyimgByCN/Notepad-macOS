import AppKit
import Carbon
import NotepadMacCore
import UniformTypeIdentifiers

private struct ThemeResourceLoadResult: Sendable {
    let themeCatalog: ThemeCatalog
    let styleCatalog: StyleCatalog
    let selectedThemeName: String?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [EditorWindowController] = []
    private var tabState = EditorTabState()
    private var languageCatalog = LanguageCatalog.loadDefault()
    private var themeCatalog = ThemeCatalog(themes: [])
    private let userDefinedLanguageStore = UserDefinedLanguageStore()
    private let themePreferencesStore = ThemePreferencesStore()
    private var styleCatalog = StyleCatalog.empty
    private let preferencesStore = PreferencesStore()
    private let stylePreferencesStore = StylePreferencesStore()
    private let sessionStore = SessionStore()
    private let snapshotStore = SnapshotStore()
    private let workspaceStore = WorkspaceStore()
    private var snapshotSaveTimer: Timer?
    private var didCompleteLaunch = false
    private lazy var preferencesPanel = PreferencesPanelController(preferencesStore: preferencesStore) { [weak self] preferences in
        self?.windows.forEach { $0.applyPreferences(preferences) }
    }
    private lazy var styleConfiguratorPanel = StyleConfiguratorPanelController(
        styleCatalog: styleCatalog,
        preferencesStore: stylePreferencesStore
    ) { [weak self] preferences in
        self?.windows.forEach { $0.applyStylePreferences(preferences) }
    }
    private lazy var workspacePanel = WorkspacePanelController { [weak self] url in
        self?.openFile(url)
    }
    private lazy var pluginsPanel = PluginsPanelController(
        documentURLProvider: { [weak self] in
            self?.activeEditorController()?.sessionFileURL
        },
        selectionProvider: { [weak self] in
            self?.activeEditorController()?.pluginSelectionContext
        }
    )
    private lazy var userDefinedLanguagePanel = UserDefinedLanguagePanelController(
        store: userDefinedLanguageStore
    ) { [weak self] in
        guard let self else { return }
        self.reloadLanguageCatalog()
        AppMenu.refreshLanguages(catalog: self.languageCatalog)
        self.windows.forEach { $0.applyLanguageCatalog(self.languageCatalog) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        finishLaunchingIfNeeded()
    }

    func finishLaunchingIfNeeded() {
        guard !didCompleteLaunch else { return }
        didCompleteLaunch = true

        NSWindow.allowsAutomaticWindowTabbing = true
        reloadLanguageCatalog()
        AppMenu.install(
            delegate: self,
            catalog: languageCatalog,
            themeCatalog: themeCatalog,
            selectedThemeName: nil
        )
        installTerminationHandlers()

        let fileArguments = CommandLine.arguments
            .dropFirst()
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        if fileArguments.isEmpty {
            restoreSessionOrNewDocument()
        } else {
            fileArguments.forEach(openFile)
        }
        restoreWorkspace()
        DispatchQueue.main.async { [weak self] in
            self?.loadThemeResources()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        snapshotSaveTimer?.invalidate()
        saveSession()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openFile(URL(fileURLWithPath: filename))
        return true
    }

    @objc private func handleQuitAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        terminateFromExternalRequest()
    }

    @objc func newDocument(_ sender: Any?) {
        show(
            EditorWindowController(
                languageCatalog: languageCatalog,
                styleCatalog: styleCatalog,
                preferencesStore: preferencesStore,
                stylePreferencesStore: stylePreferencesStore
            )
        )
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            panel.urls.forEach { self?.openFile($0) }
        }
    }

    private func openFile(_ url: URL) {
        _ = openFile(url, persistSession: true)
    }

    @discardableResult
    private func openFile(_ url: URL, persistSession: Bool) -> EditorWindowController? {
        if let existingController = existingController(for: url) {
            activate(existingController)
            if persistSession {
                saveSession()
            }
            return existingController
        }

        do {
            let controller = try EditorWindowController(
                fileURL: url,
                languageCatalog: languageCatalog,
                styleCatalog: styleCatalog,
                preferencesStore: preferencesStore,
                stylePreferencesStore: stylePreferencesStore
            )
            show(controller, persistSession: persistSession)
            return controller
        } catch {
            NSApp.presentError(error)
            return nil
        }
    }

    @discardableResult
    private func openSnapshot(_ snapshot: DocumentSnapshot, persistSession: Bool) -> EditorWindowController? {
        do {
            let controller = try EditorWindowController(
                snapshot: snapshot,
                snapshotStore: snapshotStore,
                languageCatalog: languageCatalog,
                styleCatalog: styleCatalog,
                preferencesStore: preferencesStore,
                stylePreferencesStore: stylePreferencesStore
            )
            show(controller, persistSession: persistSession)
            return controller
        } catch {
            NSApp.presentError(error)
            return nil
        }
    }

    @objc func showPreferences(_ sender: Any?) {
        preferencesPanel.show()
    }

    @objc func showStyleConfigurator(_ sender: Any?) {
        styleConfiguratorPanel.show()
    }

    @objc func openWorkspaceFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "npproj") ?? .data, .xml]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadWorkspaceFile(url)
        }
    }

    @objc func openFolderAsWorkspace(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadWorkspaceFolder(url)
        }
    }

    @objc func closeWorkspace(_ sender: Any?) {
        workspaceStore.clear()
        workspacePanel.clear()
    }

    @objc func showPluginAdmin(_ sender: Any?) {
        pluginsPanel.show()
    }

    @objc func showUserDefinedLanguages(_ sender: Any?) {
        userDefinedLanguagePanel.show()
    }

    @objc func selectTheme(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else { return }

        if let themeName = item.representedObject as? String,
           let theme = themeCatalog.theme(named: themeName),
           let catalog = try? themeCatalog.loadStyleCatalog(for: theme) {
            themePreferencesStore.save(ThemePreferences(selectedThemeName: theme.name))
            applyStyleCatalog(catalog)
        } else {
            themePreferencesStore.clear()
            applyStyleCatalog(.loadDefault())
        }

        AppMenu.refreshThemes(themeCatalog: themeCatalog, selectedThemeName: selectedThemeName)
    }

    private func show(_ controller: EditorWindowController) {
        show(controller, persistSession: true)
    }

    private func show(_ controller: EditorWindowController, persistSession: Bool) {
        let tabHostWindow = activeEditorWindow()
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windows.removeAll { $0 === controller }
            self?.rebuildTabState()
            self?.saveSession()
        }
        controller.onContentChange = { [weak self] in
            self?.scheduleSnapshotSave()
        }
        controller.onSessionStateChange = { [weak self] in
            self?.saveSession()
        }
        controller.onActivate = { [weak self, weak controller] in
            guard let controller else { return }
            self?.rebuildTabState(activeIdentity: controller.tabIdentity)
        }
        windows.append(controller)
        rebuildTabState(activeIdentity: controller.tabIdentity)
        controller.showWindow(nil)

        if let tabHostWindow,
           let newWindow = controller.window,
           tabHostWindow !== newWindow {
            tabHostWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        }

        if persistSession {
            saveSession()
        }
    }

    private func existingController(for url: URL) -> EditorWindowController? {
        let standardizedURL = url.standardizedFileURL
        return windows.first { $0.sessionFileURL == standardizedURL }
    }

    private func activate(_ controller: EditorWindowController) {
        rebuildTabState(activeIdentity: controller.tabIdentity)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func rebuildTabState(activeIdentity: EditorTabIdentity? = nil) {
        tabState = EditorTabState(
            items: windows.map(\.tabItem),
            activeIdentity: activeIdentity ?? activeEditorController()?.tabIdentity
        )
    }

    private func activeEditorController() -> EditorWindowController? {
        if let keyWindow = NSApp.keyWindow,
           let controller = windows.first(where: { $0.window === keyWindow }) {
            return controller
        }

        if let mainWindow = NSApp.mainWindow,
           let controller = windows.first(where: { $0.window === mainWindow }) {
            return controller
        }

        return windows.last(where: { $0.window?.isVisible == true })
    }

    private func applyStyleCatalog(_ catalog: StyleCatalog) {
        styleCatalog = catalog
        styleConfiguratorPanel.updateStyleCatalog(catalog)
        windows.forEach { $0.applyStyleCatalog(catalog) }
    }

    private func loadThemeResources() {
        let selectedThemeName = selectedThemeName
        Task { [weak self, selectedThemeName] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.loadThemeResources(selectedThemeName: selectedThemeName)
            }.value
            self?.applyLoadedThemeResources(result)
        }
    }

    private func reloadLanguageCatalog() {
        languageCatalog = LanguageCatalog.loadDefault()
            .appendingUserDefinedLanguages(userDefinedLanguageStore.load())
    }

    private func installTerminationHandlers() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleQuitAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEQuitApplication)
        )
    }

    private func terminateFromExternalRequest() {
        snapshotSaveTimer?.invalidate()
        saveSession()
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if NSApp.isRunning {
                NSApp.stop(nil)
            }
        }
    }

    private var selectedThemeName: String? {
        themePreferencesStore.load().selectedThemeName
    }

    private func applyLoadedThemeResources(_ result: ThemeResourceLoadResult) {
        themeCatalog = result.themeCatalog
        applyStyleCatalog(result.styleCatalog)
        AppMenu.refreshThemes(themeCatalog: result.themeCatalog, selectedThemeName: result.selectedThemeName)
    }

    nonisolated private static func loadThemeResources(selectedThemeName: String?) -> ThemeResourceLoadResult {
        let themeCatalog = ThemeCatalog.loadDefault()
        let styleCatalog = loadInitialStyleCatalog(themeCatalog: themeCatalog, selectedThemeName: selectedThemeName)
        return ThemeResourceLoadResult(
            themeCatalog: themeCatalog,
            styleCatalog: styleCatalog,
            selectedThemeName: selectedThemeName
        )
    }

    nonisolated private static func loadInitialStyleCatalog(
        themeCatalog: ThemeCatalog,
        selectedThemeName: String?
    ) -> StyleCatalog {
        guard let themeName = selectedThemeName,
              let theme = themeCatalog.theme(named: themeName),
              let catalog = try? themeCatalog.loadStyleCatalog(for: theme)
        else {
            return .loadDefault()
        }

        return catalog
    }

    private func activeEditorWindow() -> NSWindow? {
        activeEditorController()?.window
    }

    private func restoreSessionOrNewDocument() {
        let session = sessionStore.load()
        let existingFiles = session.openFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
        let existingSnapshots = session.snapshots.filter { FileManager.default.fileExists(atPath: $0.backupFile.path) }
        let existingSnapshotIDs = Set(existingSnapshots.map(\.id))
        let missingSnapshotIDs = Set(session.snapshots.map(\.id)).subtracting(existingSnapshotIDs)
        let existingFileSet = Set(existingFiles.map(\.standardizedFileURL))
        let snapshotFileFallbacks = session.snapshotFileFallbacks(missingSnapshotIDs: missingSnapshotIDs)
            .filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
            .filter { !existingFileSet.contains($0.fileURL.standardizedFileURL) }

        guard !existingFiles.isEmpty || !existingSnapshots.isEmpty || !snapshotFileFallbacks.isEmpty else {
            newDocument(nil)
            return
        }

        let restoredControllers = existingFiles.compactMap { fileURL -> EditorWindowController? in
            guard let controller = openFile(fileURL, persistSession: false) else { return nil }
            controller.restoreBookmarks(session.bookmarkSet(for: .file(fileURL)))
            controller.restoreFolds(session.foldState(for: .file(fileURL)))
            return controller
        }
        let restoredSnapshotControllers = existingSnapshots.compactMap { snapshot -> EditorWindowController? in
            guard let controller = openSnapshot(snapshot, persistSession: false) else { return nil }
            controller.restoreBookmarks(session.bookmarkSet(for: .snapshot(snapshot.id)))
            controller.restoreFolds(session.foldState(for: .snapshot(snapshot.id)))
            return controller
        }
        let fallbackSnapshotControllers = snapshotFileFallbacks.compactMap { fallback -> (snapshotID: String, controller: EditorWindowController)? in
            guard let controller = openFile(fallback.fileURL, persistSession: false) else { return nil }
            controller.restoreBookmarks(fallback.bookmarks)
            controller.restoreFolds(fallback.folds)
            return (fallback.snapshotID, controller)
        }
        let allRestoredControllers = restoredControllers
            + restoredSnapshotControllers
            + fallbackSnapshotControllers.map(\.controller)

        guard !allRestoredControllers.isEmpty else {
            newDocument(nil)
            return
        }

        if let activeSnapshotID = session.activeSnapshotID,
           let activeController = restoredSnapshotControllers.first(where: { $0.sessionSnapshotID == activeSnapshotID }) {
            activeController.showWindow(nil)
            activeController.window?.makeKeyAndOrderFront(nil)
        } else if let activeSnapshotID = session.activeSnapshotID,
                  let activeController = fallbackSnapshotControllers.first(where: { $0.snapshotID == activeSnapshotID })?.controller {
            activeController.showWindow(nil)
            activeController.window?.makeKeyAndOrderFront(nil)
        } else if let activeFile = session.activeFile,
           let activeController = restoredControllers.first(where: { $0.sessionFileURL == activeFile }) {
            activeController.showWindow(nil)
            activeController.window?.makeKeyAndOrderFront(nil)
        }

        saveSession()
    }

    private func restoreWorkspace() {
        guard let workspace = workspaceStore.load() else { return }
        workspacePanel.show(workspace: workspace)
    }

    private func loadWorkspaceFile(_ url: URL) {
        do {
            showWorkspace(try WorkspaceDocument.load(from: url))
        } catch {
            NSApp.presentError(error)
        }
    }

    private func loadWorkspaceFolder(_ url: URL) {
        do {
            showWorkspace(try WorkspaceDocument.folderWorkspace(from: url))
        } catch {
            NSApp.presentError(error)
        }
    }

    private func showWorkspace(_ workspace: WorkspaceDocument) {
        workspaceStore.save(workspace)
        workspacePanel.show(workspace: workspace)
    }

    private func scheduleSnapshotSave() {
        snapshotSaveTimer?.invalidate()
        snapshotSaveTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveSession()
            }
        }
    }

    private func saveSession() {
        snapshotSaveTimer?.invalidate()
        snapshotSaveTimer = nil

        var openFiles: [URL] = []
        var snapshots: [DocumentSnapshot] = []
        var bookmarkRecords: [SessionBookmarkRecord] = []
        var foldRecords: [SessionFoldRecord] = []

        for controller in windows {
            if let draft = controller.makeSnapshotDraft() {
                do {
                    let snapshot = try snapshotStore.save(draft)
                    controller.markSnapshotSaved(snapshot)
                    snapshots.append(snapshot)
                    appendBookmarkRecord(from: controller, to: &bookmarkRecords)
                    appendFoldRecord(from: controller, to: &foldRecords)
                } catch {
                    NSLog("Failed to save document snapshot: \(String(describing: error))")
                    if let fileURL = controller.sessionFileURL {
                        openFiles.append(fileURL)
                        appendBookmarkRecord(from: controller, to: &bookmarkRecords)
                        appendFoldRecord(from: controller, to: &foldRecords)
                    }
                }
            } else if let fileURL = controller.sessionFileURL {
                openFiles.append(fileURL)
                appendBookmarkRecord(from: controller, to: &bookmarkRecords)
                appendFoldRecord(from: controller, to: &foldRecords)
            }
        }

        do {
            try snapshotStore.prune(keeping: snapshots)
        } catch {
            NSLog("Failed to prune document snapshots: \(String(describing: error))")
        }

        let activeSnapshotID = activeSessionSnapshotID()
        let session = AppSession(
            openFiles: openFiles,
            activeFile: activeSnapshotID == nil ? activeSessionFileURL() : nil,
            snapshots: snapshots,
            activeSnapshotID: activeSnapshotID,
            bookmarks: bookmarkRecords,
            folds: foldRecords
        )

        if session.openFiles.isEmpty && session.snapshots.isEmpty {
            sessionStore.clear()
        } else {
            sessionStore.save(session)
        }
    }

    private func activeSessionSnapshotID() -> String? {
        if let keyWindow = NSApp.keyWindow,
           let controller = windows.first(where: { $0.window === keyWindow }) {
            return controller.sessionSnapshotID
        }

        return nil
    }

    private func appendBookmarkRecord(
        from controller: EditorWindowController,
        to bookmarkRecords: inout [SessionBookmarkRecord]
    ) {
        let bookmarks = controller.sessionBookmarks
        guard !bookmarks.isEmpty else { return }
        bookmarkRecords.append(SessionBookmarkRecord(identity: controller.tabIdentity, bookmarks: bookmarks))
    }

    private func appendFoldRecord(
        from controller: EditorWindowController,
        to foldRecords: inout [SessionFoldRecord]
    ) {
        let folds = controller.sessionFolds
        guard !folds.isEmpty else { return }
        foldRecords.append(SessionFoldRecord(identity: controller.tabIdentity, folds: folds))
    }

    private func activeSessionFileURL() -> URL? {
        if let keyWindow = NSApp.keyWindow,
           let controller = windows.first(where: { $0.window === keyWindow }),
           let fileURL = controller.sessionFileURL {
            return fileURL
        }

        return windows.compactMap(\.sessionFileURL).last
    }
}
