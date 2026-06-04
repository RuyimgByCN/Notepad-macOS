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
    private var newDocumentCounter = 0
    private var windowSortMode = AppMenu.WindowSortMode.none
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
    private var currentWorkspaceURL: URL?
    private lazy var localizationOptions = AppLocalizationCatalog.loadBundledOptions()
    private var snapshotSaveTimer: Timer?
    private var recentlyClosedDocuments: [URL] = []
    private var closeCompletions: [ObjectIdentifier: [() -> Void]] = [:]
    private var didCompleteLaunch = false
    private lazy var preferencesPanel = PreferencesPanelController(
        preferencesStore: preferencesStore,
        localizationOptions: localizationOptions,
        languageEntries: languageCatalog.languages
            .map { (name: $0.name, displayName: $0.displayName) }
            .sorted { $0.displayName < $1.displayName }
    ) { [weak self] preferences in
        self?.applyAppPreferences(preferences)
    }
    private lazy var styleConfiguratorPanel = StyleConfiguratorPanelController(
        styleCatalog: styleCatalog,
        preferencesStore: stylePreferencesStore
    ) { [weak self] preferences in
        self?.windows.forEach { $0.applyStylePreferences(preferences) }
    }
    private lazy var hashTextPanel = HashTextPanelController()
    private let savedRunCommandStore = SavedRunCommandStore()
    private lazy var runCommandPanel: RunCommandPanelController = {
        let panel = RunCommandPanelController()
        panel.onSaveCommand = { [weak self] command in
            self?.savedRunCommandStore.add(command)
            self?.refreshRunMenu()
        }
        return panel
    }()
    private lazy var workspacePanel = WorkspacePanelController { [weak self] url in
        self?.openFile(url)
    }
    private lazy var fileBrowserPanel = WorkspacePanelController { [weak self] url in
        self?.openFile(url)
    }
    private lazy var documentListPanel = DocumentListPanelController()
    private lazy var windowsDialog = WindowsDialogController()
    private lazy var tabSwitcher = TabSwitcherController()
    private var mruList: [EditorWindowController] = []
    private var ctrlTabMonitor: Any?
    private lazy var pluginsPanel = PluginsPanelController(
        documentURLProvider: { [weak self] in
            self?.activeEditorController()?.sessionFileURL
        },
        selectionProvider: { [weak self] in
            self?.activeEditorController()?.pluginSelectionContext
        }
    )
    private let customShortcutStore = CustomShortcutStore()
    private(set) var findInFilesResultsStore = FindInFilesResultsStore()
    private lazy var foundResultsPanel: FoundResultsPanelController = {
        let panel = FoundResultsPanelController(store: findInFilesResultsStore)
        panel.onNavigateToMatch = { [weak self] match in
            self?.openFileAtLine(fileURL: URL(fileURLWithPath: match.filePath), line: match.line)
            self?.foundResultsPanel.reload()
        }
        panel.onFindInSearchResults = { [weak self] in
            self?.showFindInFinderPanel(nil)
        }
        return panel
    }()
    private lazy var shortcutMapperPanel: ShortcutMapperPanelController = {
        let panel = ShortcutMapperPanelController(shortcutStore: customShortcutStore)
        panel.onShortcutsChanged = { [weak self] in
            // Nothing extra to do — shortcuts are already applied to menu items directly
        }
        return panel
    }()
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

        // Pre-warm ObjC/UIFoundation class hierarchy before any Scintilla views render.
        // On macOS 26+ (ARM64), UIFoundation class metadata resides in __AUTH_CONST which is
        // hardware write-protected. The ObjC runtime's lazy class realization (realizeClassWithoutSwift)
        // fails with KERN_PROTECTION_FAILURE if triggered for the first time inside drawRect.
        // Accessing these constants here forces safe realization outside the paint cycle.
        _ = NSText.didChangeNotification
        _ = NSTextView.didChangeSelectionNotification

        let preferences = preferencesStore.load()
        Localization.apply(localizationFileName: preferences.localizationFileName, postNotification: false)
        reloadLanguageCatalog()
        AppMenu.install(
            delegate: self,
            catalog: languageCatalog,
            themeCatalog: themeCatalog,
            selectedThemeName: nil
        )
        installTerminationHandlers()
        installCtrlTabMonitor()
        installWorkspaceFindInFiles()
        refreshRunMenu()
        // Apply custom shortcuts after main menu is built
        DispatchQueue.main.async { [weak self] in
            self?.shortcutMapperPanel.applyStoredShortcuts()
        }

        let args = CommandLine.arguments.dropFirst()
        let parsedArgs = CommandLineArgs.parse(args)

        if parsedArgs.noSession {
            newDocument(nil)
        } else if parsedArgs.fileURLs.isEmpty && parsedArgs.newFileURLs.isEmpty {
            restoreSessionOrNewDocument()
        } else {
            parsedArgs.fileURLs.forEach { openFile($0) }
            promptToCreateNewFiles(parsedArgs.newFileURLs)
        }
        restoreWorkspace()

        // Apply command-line view options (deferred to let windows settle)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let active = self.activeEditorController()
            if parsedArgs.alwaysOnTop {
                active?.setAlwaysOnTop(true)
            }
            if parsedArgs.readOnly {
                active?.editorSurface.isReadOnly = true
            }
            if parsedArgs.monitoring {
                active?.enableMonitoringMode()
            }
            if let langName = parsedArgs.languageName {
                active?.setLanguage(named: langName)
            }
            if let pos = parsedArgs.gotoPosition {
                active?.goToScintillaPosition(pos)
            } else if let line = parsedArgs.gotoLine {
                active?.goToLine(line, column: parsedArgs.gotoColumn)
            }
            // Apply -x/-y window position
            if let x = parsedArgs.windowX, let window = active?.window {
                let y = parsedArgs.windowY.map { CGFloat($0) } ?? window.frame.origin.y
                window.setFrameOrigin(NSPoint(x: CGFloat(x), y: y))
            }
        }
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

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(closeAllDocuments(_:)):
            return windows.count > 0
        case #selector(closeOtherDocuments(_:)):
            return windows.count > 1
        case #selector(closeUnchangedDocuments(_:)):
            return windows.contains { !$0.hasUnsavedChanges }
        case #selector(saveAllDocuments(_:)):
            return !windows.isEmpty
        case #selector(restoreLastClosedDocument(_:)):
            return !recentlyClosedDocuments.isEmpty
        case #selector(copyAllDocumentNames(_:)):
            return !windows.isEmpty
        case #selector(copyAllDocumentPaths(_:)):
            return windows.contains(where: { $0.sessionFileURL != nil })
        case #selector(toggleWindowTabPin(_:)):
            return activeEditorController() != nil
        case #selector(setWindowSort(_:)):
            return !windows.isEmpty
        case #selector(setWindowTabColor(_:)):
            return activeEditorController() != nil
        case #selector(showFileBrowser(_:)):
            return activeEditorController()?.sessionFileURL != nil
        case #selector(showDocumentList(_:)):
            return !windows.isEmpty
        default:
            return true
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openFile(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        filenames.forEach { openFile(URL(fileURLWithPath: $0)) }
        sender.reply(toOpenOrPrint: .success)
    }

    @objc private func handleQuitAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        terminateFromExternalRequest()
    }

    @objc func newDocument(_ sender: Any?) {
        let prefix = Localization.string(.editorNewDocumentPrefix, default: "新文件")
        // Find lowest unused numbered name across all open untitled tabs.
        let usedNumbers = Set(windows.compactMap { w -> Int? in
            let title = w.tabItem.title
            guard title.hasPrefix(prefix), let n = Int(title.dropFirst(prefix.count)) else { return nil }
            return n
        })
        let n = (1...).first { !usedNumbers.contains($0) } ?? (newDocumentCounter + 1)
        newDocumentCounter = max(newDocumentCounter, n)
        let controller = EditorWindowController(
            untitledDisplayName: "\(prefix)\(n)",
            languageCatalog: languageCatalog,
            styleCatalog: styleCatalog,
            preferencesStore: preferencesStore,
            stylePreferencesStore: stylePreferencesStore
        )
        let prefs = preferencesStore.load()
        if !prefs.defaultNewDocumentLanguageName.isEmpty {
            controller.setLanguage(named: prefs.defaultNewDocumentLanguageName)
        }
        show(controller)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if preferencesStore.load().openDirectoryFollowsDocument {
            panel.directoryURL = activeEditorController()?.sessionFileURL?.deletingLastPathComponent()
        }
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            panel.urls.forEach { self?.openFile($0) }
        }
    }

    @objc func saveAllDocuments(_ sender: Any?) {
        windows.forEach { $0.saveDocument(sender) }
    }

    @objc func closeAllDocuments(_ sender: Any?) {
        closeDocumentControllers(windows)
    }

    @objc func closeOtherDocuments(_ sender: Any?) {
        guard let activeController = activeEditorController() else { return }
        closeDocumentControllers(windows.filter { $0 !== activeController })
    }

    @objc func closeDocumentsToRight(_ sender: Any?) {
        guard let activeController = activeEditorController() else { return }
        let ordered = orderedWindows()
        guard let activeIndex = ordered.firstIndex(where: { $0 === activeController }) else { return }
        let toClose = Array(ordered[activeIndex...].dropFirst())
        closeDocumentControllers(toClose)
    }

    @objc func closeDocumentsToLeft(_ sender: Any?) {
        guard let activeController = activeEditorController() else { return }
        let ordered = orderedWindows()
        guard let activeIndex = ordered.firstIndex(where: { $0 === activeController }) else { return }
        let toClose = Array(ordered[..<activeIndex])
        closeDocumentControllers(toClose)
    }

    @objc func closeAllButPinnedDocuments(_ sender: Any?) {
        let toClose = windows.filter { !$0.isPinnedToTab }
        closeDocumentControllers(toClose)
    }

    @objc func closeUnchangedDocuments(_ sender: Any?) {
        closeDocumentControllers(windows.filter { !$0.hasUnsavedChanges }, label: Localization.string(.fileCloseUnchanged, default: "Close Unchanged"))
    }

    @objc func restoreLastClosedDocument(_ sender: Any?) {
        while let closedURL = recentlyClosedDocuments.popLast() {
            if FileManager.default.fileExists(atPath: closedURL.path) {
                openFile(closedURL)
                return
            }
        }
    }

    @objc func openRecentFile(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let path = item.representedObject as? String
        else {
            return
        }

        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            openFile(url)
        }
    }

    func openFileAtLine(fileURL: URL, line: Int) {
        openFile(fileURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let controller = self?.activeEditorController() else { return }
            controller.goToLine(line)
        }
    }

    func showFoundResultsPanel() {
        foundResultsPanel.show()
    }

    @objc func showFoundResultsPanel(_ sender: Any?) {
        showFoundResultsPanel()
    }

    @objc func showFindInProjectsPanel(_ sender: Any?) {
        guard let workspace = workspaceStore.load() else {
            presentSimpleAlert(
                title: Localization.string(.findInProjectsNoWorkspaceTitle, default: "No Workspace"),
                message: Localization.string(.findInProjectsNoWorkspaceMessage, default: "Open a workspace before searching in projects.")
            )
            return
        }
        let fileURLs = workspace.allFileURLs()
        guard !fileURLs.isEmpty else {
            presentSimpleAlert(
                title: Localization.string(.findInProjectsNoFilesTitle, default: "No Project Files"),
                message: Localization.string(.findInProjectsNoFilesMessage, default: "The current workspace does not contain any files.")
            )
            return
        }
        presentFindInFileList(
            fileURLs: fileURLs,
            title: Localization.string(.findInProjectsPanelTitle, default: "Find in Projects")
        )
    }

    @objc func showFindInFinderPanel(_ sender: Any?) {
        let paths = findInFilesResultsStore.uniqueFilePaths()
        guard !paths.isEmpty else {
            presentSimpleAlert(
                title: Localization.string(.findInFinderNoResultsTitle, default: "No Search Results"),
                message: Localization.string(.findInFinderNoResultsMessage, default: "Run Find in Files first, or open Found Results with matching files.")
            )
            return
        }
        let fileURLs = paths.map { URL(fileURLWithPath: $0) }
        presentFindInFileList(
            fileURLs: fileURLs,
            title: Localization.string(.findInFinderPanelTitle, default: "Find in Search Results")
        )
    }

    private func presentFindInFileList(fileURLs: [URL], title: String) {
        if let controller = activeEditorController() ?? windows.first {
            controller.showFindInFilesPanel(fileURLs: fileURLs, title: title)
            return
        }
        newDocument(nil)
        windows.last?.showFindInFilesPanel(fileURLs: fileURLs, title: title)
    }

    private func presentSimpleAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    @discardableResult
    func navigateFoundResult(forward: Bool) -> Bool {
        guard findInFilesResultsStore.hasResults else { return false }
        let match = forward
            ? findInFilesResultsStore.selectNext()
            : findInFilesResultsStore.selectPrevious()
        guard let match else { return false }
        openFileAtLine(fileURL: URL(fileURLWithPath: match.filePath), line: match.line)
        foundResultsPanel.reload()
        return true
    }

    @objc func clearRecentFiles(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
        refreshRecentFilesMenu()
    }

    @objc func saveSessionToFile(_ sender: Any?) {
        let session = buildSessionState().session

        guard let data = try? JSONEncoder().encode(session) else {
            NSApp.presentError(NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(EINVAL),
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode session."]
            ))
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "session.json"
        panel.allowedContentTypes = [.json]
        let anchorWindow = activeEditorWindow() ?? NSApp.keyWindow ?? NSApp.mainWindow

        if let anchorWindow {
            panel.beginSheetModal(for: anchorWindow) { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url)
                } catch {
                    NSApp.presentError(error)
                }
            }
        } else {
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                NSApp.presentError(error)
            }
        }
    }

    @objc func loadSession(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        let anchorWindow = activeEditorWindow() ?? NSApp.keyWindow ?? NSApp.mainWindow

        if let anchorWindow {
            panel.beginSheetModal(for: anchorWindow) { [weak self] response in
                guard let self, response == .OK, let url = panel.url else { return }
                self.loadSessionFile(url)
            }
        } else {
            guard panel.runModal() == .OK, let url = panel.url else { return }
            loadSessionFile(url)
        }
    }

    private func loadSessionFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let session = try JSONDecoder().decode(AppSession.self, from: data)

            closeDocumentControllers(windows, label: Localization.string(.fileLoadSession, default: "Load Session")) {
                self.restoreSession(session)
            }
        } catch {
            NSApp.presentError(error)
        }
    }

    private func openFile(_ url: URL) {
        _ = openFile(url, persistSession: true)
    }

    func openFile(at url: URL) {
        openFile(url)
    }

    @discardableResult
    private func openFile(_ url: URL, persistSession: Bool) -> EditorWindowController? {
        // Resolve symlinks and aliases to their real path
        let url = url.resolvingSymlinksInPath()

        // Handle directory URLs
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            if preferencesStore.load().folderDropOpensAsWorkspace {
                loadWorkspaceFolder(url)
            }
            // Don't open directories as text files regardless
            return nil
        }

        if let existingController = existingController(for: url) {
            activate(existingController)
            if persistSession {
                saveSession()
                registerRecentDocument(url)
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
            if persistSession {
                registerRecentDocument(url)
            }
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

    private func registerRecentDocument(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        NSDocumentController.shared.noteNewRecentDocumentURL(standardizedURL)
        refreshRecentFilesMenu()
    }

    private func rememberClosedDocument(_ controller: EditorWindowController) {
        guard let fileURL = controller.sessionFileURL else { return }
        let standardizedURL = fileURL.standardizedFileURL
        recentlyClosedDocuments.removeAll { $0 == standardizedURL }
        recentlyClosedDocuments.append(standardizedURL)

        if recentlyClosedDocuments.count > 20 {
            recentlyClosedDocuments.removeFirst(recentlyClosedDocuments.count - 20)
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

    @objc func showDocumentList(_ sender: Any?) {
        documentListPanel.show(
            items: currentDocumentListItems(),
            onSelect: { [weak self] item in
                guard let controller = item.representedObject as? EditorWindowController else { return }
                self?.activate(controller)
            },
            onAction: { [weak self] item, action in
                self?.handleDocumentListAction(item: item, action: action)
            }
        )
    }

    @objc func showWindowsDialog(_ sender: Any?) {
        windowsDialog.show(
            items: currentWindowsDialogItems(),
            onAction: { [weak self] action, items in
                self?.handleWindowsDialogAction(action, items: items)
            }
        )
    }

    private func currentWindowsDialogItems() -> [WindowsDialogItem] {
        let activeIdentity = activeEditorController()?.tabIdentity.normalized
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return orderedWindows().map { controller in
            let sizeStr = WindowsDialogItem.fileSizeString(controller.windowListSortContentLength)
            let dateStr: String
            let sortDate = controller.windowListSortDate
            dateStr = sortDate == .distantPast ? "" : dateFormatter.string(from: sortDate)
            return WindowsDialogItem(
                title: controller.windowListSortName,
                path: controller.sessionFileURL?.path ?? "",
                fileType: controller.windowListSortType,
                fileSize: sizeStr,
                modifiedDate: dateStr,
                isDirty: controller.hasUnsavedChanges,
                isActive: controller.tabIdentity.normalized == activeIdentity,
                representedObject: controller
            )
        }
    }

    private func handleWindowsDialogAction(_ action: WindowsDialogAction, items: [WindowsDialogItem]) {
        let controllers = items.compactMap { $0.representedObject as? EditorWindowController }
        switch action {
        case .activate:
            if let first = controllers.first { activate(first) }
        case .save:
            controllers.forEach { $0.saveDocument(nil) }
        case .close:
            controllers.forEach { $0.window?.performClose(nil) }
        case .copyFilename:
            let names = controllers.map(\.windowListSortName).joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(names, forType: .string)
        case .copyPath:
            let paths = controllers.compactMap { $0.sessionFileURL?.path }.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths, forType: .string)
        }
    }

    @objc func showFileBrowser(_ sender: Any?) {
        guard let fileURL = activeEditorController()?.sessionFileURL else { return }
        let folderURL = fileURL.deletingLastPathComponent()
        do {
            let workspace = try WorkspaceDocument.folderWorkspace(from: folderURL)
            fileBrowserPanel.show(workspace: workspace)
            fileBrowserPanel.startWatching(url: folderURL) { [weak self] in
                guard let self else { return }
                if let updated = try? WorkspaceDocument.folderWorkspace(from: folderURL) {
                    self.fileBrowserPanel.show(workspace: updated)
                }
            }
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc func syncZoomToAll(_ sender: Any?) {
        guard let sourceController = activeEditorController() else { return }
        let targetFontSize = sourceController.currentFontSize
        windows.filter { $0 !== sourceController }.forEach { $0.applyFontSize(targetFontSize) }
    }

    @objc func setReadOnlyForAll(_ sender: Any?) {
        allEditorControllers().forEach { $0.editorSurface.isReadOnly = true }
    }

    @objc func clearReadOnlyForAll(_ sender: Any?) {
        allEditorControllers().forEach { $0.editorSurface.isReadOnly = false }
    }

    @objc func copyAllFilenames(_ sender: Any?) {
        let names = allEditorControllers().compactMap { $0.sessionFileURL?.lastPathComponent }
        guard !names.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(names.joined(separator: "\n"), forType: .string)
    }

    @objc func copyAllFilePaths(_ sender: Any?) {
        let paths = allEditorControllers().compactMap { $0.sessionFileURL?.path }
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    @objc func locateCurrentFile(_ sender: Any?) {
        guard let fileURL = activeEditorController()?.sessionFileURL else { return }
        if fileBrowserPanel.window?.isVisible != true {
            do {
                fileBrowserPanel.show(workspace: try WorkspaceDocument.folderWorkspace(from: fileURL.deletingLastPathComponent()))
            } catch {
                NSApp.presentError(error)
                return
            }
        }
        fileBrowserPanel.locateFile(fileURL)
    }

    @objc func saveWorkspace(_ sender: Any?) {
        guard let workspace = workspaceStore.load() else { return }
        if let url = currentWorkspaceURL {
            try? workspace.write(to: url)
        } else {
            saveWorkspaceAs(sender)
        }
    }

    @objc func saveWorkspaceAs(_ sender: Any?) {
        guard let workspace = workspaceStore.load() else { return }
        let panel = NSSavePanel()
        panel.title = Localization.string(.workspaceSaveAs, default: "Save Workspace As...")
        panel.allowedContentTypes = [.init(filenameExtension: "nppworkspace") ?? .data]
        panel.nameFieldStringValue = "workspace.nppworkspace"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try workspace.write(to: url)
            currentWorkspaceURL = url
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc func closeWorkspace(_ sender: Any?) {
        workspaceStore.clear()
        workspacePanel.clear()
        currentWorkspaceURL = nil
    }

    @objc func showPluginAdmin(_ sender: Any?) {
        pluginsPanel.show()
    }

    @objc func showShortcutMapper(_ sender: Any?) {
        shortcutMapperPanel.show()
    }

    func replaceInAllOpenDocuments(query: String, replacement: String, options: TextSearch.Options) -> Int {
        var totalCount = 0
        for window in NSApp.windows {
            guard let controller = window.windowController as? EditorWindowController else { continue }
            totalCount += controller.performReplaceAll(query: query, replacement: replacement, options: options)
        }
        return totalCount
    }

    @objc func openPluginsFolder(_ sender: Any?) {
        guard let dir = PluginCatalog.userPluginDirectory() else { return }
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc func importPlugin(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = Localization.string(.pluginsImportTitle, default: "Select Plugin Directory")
        panel.prompt = Localization.string(.pluginsImportButton, default: "Import")
        panel.message = Localization.string(.pluginsImportMessage, default: "Select a folder containing notepad-mac-plugin.json")
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.pluginsPanel.importPlugin(from: url)
        }
    }

    @objc func showUserDefinedLanguages(_ sender: Any?) {
        userDefinedLanguagePanel.show()
    }

    @objc func showMD5Generator(_ sender: Any?) {
        showHashGenerator(.md5)
    }

    @objc func showSHA1Generator(_ sender: Any?) {
        showHashGenerator(.sha1)
    }

    @objc func showSHA256Generator(_ sender: Any?) {
        showHashGenerator(.sha256)
    }

    @objc func showSHA512Generator(_ sender: Any?) {
        showHashGenerator(.sha512)
    }

    @objc func generateMD5FromFiles(_ sender: Any?) {
        generateHashFromFiles(.md5)
    }

    @objc func generateSHA1FromFiles(_ sender: Any?) {
        generateHashFromFiles(.sha1)
    }

    @objc func generateSHA256FromFiles(_ sender: Any?) {
        generateHashFromFiles(.sha256)
    }

    @objc func generateSHA512FromFiles(_ sender: Any?) {
        generateHashFromFiles(.sha512)
    }

    @objc func showRunCommandPanel(_ sender: Any?) {
        let controller = activeEditorController()
        runCommandPanel.show(
            documentURL: controller?.sessionFileURL,
            variableContext: controller?.runCommandVariableContext
        )
    }

    @objc func executeSavedRunCommand(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let command = item.representedObject as? SavedRunCommand else { return }
        let editorController = activeEditorController()
        let ctx = editorController?.runCommandVariableContext
        let docURL = editorController?.sessionFileURL
        let environment = buildRunEnvironment(for: docURL)
        Task { @MainActor in
            let expandedLine = ctx.map {
                RunCommandSupport.expandVariables(in: command.commandLine, context: $0)
            } ?? command.commandLine
            do {
                let plan = try RunCommandSupport.plan(
                    commandLine: expandedLine,
                    documentURL: docURL,
                    environment: environment
                )
                _ = try await RunCommandSupport.execute(plan, environment: environment)
            } catch {
                NSApp.presentError(error)
            }
        }
    }

    private func buildRunEnvironment(for documentURL: URL?) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let url = documentURL, url.isFileURL {
            env["NOTEPAD_MAC_DOCUMENT_PATH"] = url.path
            env["NOTEPAD_MAC_DOCUMENT_DIRECTORY"] = url.deletingLastPathComponent().path
            env["NOTEPAD_MAC_DOCUMENT_NAME"] = url.lastPathComponent
        }
        return env
    }

    private func refreshRunMenu() {
        AppMenu.refreshRunMenu(
            delegate: self,
            savedCommands: savedRunCommandStore.load()
        )
    }

    @objc func showCommandLineArguments(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = Localization.string(.helpCommandLinePanelTitle, default: "Command Line Arguments")
        alert.informativeText = HelpSupport.commandLineArgumentsText(appName: "NotepadMac")
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.runModal()
    }

    @objc func openHomePage(_ sender: Any?) {
        NSWorkspace.shared.open(HelpSupport.url(for: .home))
    }

    @objc func openProjectPage(_ sender: Any?) {
        NSWorkspace.shared.open(HelpSupport.url(for: .projectPage))
    }

    @objc func openOnlineUserManual(_ sender: Any?) {
        NSWorkspace.shared.open(HelpSupport.url(for: .userManual))
    }

    @objc func openForum(_ sender: Any?) {
        NSWorkspace.shared.open(HelpSupport.url(for: .forum))
    }

    @objc func openDownloadsPage(_ sender: Any?) {
        NSWorkspace.shared.open(HelpSupport.url(for: .downloads))
    }

    @objc func showDebugInfo(_ sender: Any?) {
        let active = activeEditorController()
        let debugText = HelpSupport.debugInfoText(
            documentName: active?.windowListSortName ?? Localization.string(.editorUntitledDocumentName, default: "Untitled"),
            documentPath: active?.sessionFileURL?.path,
            editorBackend: active?.editorBackendDisplayName ?? "Unknown",
            supportsFolding: active?.supportsToolbarFoldingCommands ?? false,
            documentEncoding: active?.encodingDisplayName,
            documentLineEnding: active?.lineEndingDisplayName,
            documentLanguage: active?.languageDisplayName,
            activePluginCount: 0,
            savedCommandCount: savedRunCommandStore.load().count
        )
        let alert = NSAlert()
        alert.messageText = Localization.string(.helpDebugInfoPanelTitle, default: "Debug Info")
        alert.informativeText = debugText
        alert.addButton(withTitle: Localization.string(.helpDebugInfoCopy, default: "Copy to Clipboard"))
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(debugText, forType: .string)
        }
    }

    @objc func showAbout(_ sender: Any?) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let alert = NSAlert()
        alert.messageText = Localization.string(.helpAbout, default: "About Notepad++ Mac")
        alert.informativeText = HelpSupport.aboutText(
            appName: "Notepad++ Mac",
            version: version,
            subtitle: Localization.string(.helpAboutSubtitle, default: "Native macOS prototype")
        )
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.runModal()
    }

    @objc func copyAllDocumentNames(_ sender: Any?) {
        let names = orderedWindows().map { $0.windowListSortName }
        guard !names.isEmpty else {
            return
        }
        copyToPasteboard(names.joined(separator: "\n"))
    }

    @objc func copyAllDocumentPaths(_ sender: Any?) {
        let paths = orderedWindows().compactMap { $0.sessionFileURL?.path }
        guard !paths.isEmpty else {
            return
        }
        copyToPasteboard(paths.joined(separator: "\n"))
    }

    @objc func activateWindowFromList(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let controller = item.representedObject as? EditorWindowController
        else {
            return
        }
        activate(controller)
    }

    // MARK: - Tab Navigation

    @objc func activateNextTab(_ sender: Any?) {
        let ordered = orderedWindows()
        guard ordered.count > 1, let active = activeEditorController() else { return }
        guard let index = ordered.firstIndex(where: { $0 === active }) else { return }
        let nextIndex = (index + 1) % ordered.count
        activate(ordered[nextIndex])
    }

    @objc func activatePreviousTab(_ sender: Any?) {
        let ordered = orderedWindows()
        guard ordered.count > 1, let active = activeEditorController() else { return }
        guard let index = ordered.firstIndex(where: { $0 === active }) else { return }
        let prevIndex = (index - 1 + ordered.count) % ordered.count
        activate(ordered[prevIndex])
    }

    @objc func activateTabByIndex(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let index = item.representedObject as? Int
        else { return }
        let ordered = orderedWindows()
        guard index < ordered.count else { return }
        activate(ordered[index])
    }

    @objc func activateFirstTab(_ sender: Any?) {
        let ordered = orderedWindows()
        guard !ordered.isEmpty else { return }
        activate(ordered[0])
    }

    @objc func activateLastTab(_ sender: Any?) {
        let ordered = orderedWindows()
        guard !ordered.isEmpty else { return }
        activate(ordered[ordered.count - 1])
    }

    // MARK: - Tab Reorder

    @objc func moveTabForward(_ sender: Any?) {
        moveTab(by: 1)
    }

    @objc func moveTabBackward(_ sender: Any?) {
        moveTab(by: -1)
    }

    @objc func moveTabToStart(_ sender: Any?) {
        moveTab(to: 0)
    }

    @objc func moveTabToEnd(_ sender: Any?) {
        let ordered = orderedWindows()
        moveTab(to: ordered.count - 1)
    }

    private func moveTab(by offset: Int) {
        let ordered = orderedWindows()
        guard ordered.count > 1, let active = activeEditorController() else { return }
        guard let index = ordered.firstIndex(where: { $0 === active }) else { return }
        let newIndex = max(0, min(ordered.count - 1, index + offset))
        guard newIndex != index else { return }
        reorderWindow(active, to: newIndex)
    }

    private func moveTab(to targetIndex: Int) {
        let ordered = orderedWindows()
        guard ordered.count > 1, let active = activeEditorController() else { return }
        guard let index = ordered.firstIndex(where: { $0 === active }) else { return }
        let clamped = max(0, min(ordered.count - 1, targetIndex))
        guard clamped != index else { return }
        reorderWindow(active, to: clamped)
    }

    private func reorderWindow(_ controller: EditorWindowController, to newIndex: Int) {
        guard let windowIndex = windows.firstIndex(where: { $0 === controller }) else { return }
        windows.remove(at: windowIndex)
        let insertAt = min(newIndex, windows.count)
        windows.insert(controller, at: insertAt)
        rebuildTabState(activeIdentity: controller.tabIdentity)
    }

    // MARK: - Print Now

    @objc func printNow(_ sender: Any?) {
        guard let activeController = activeEditorController() else { return }
        activeController.printNow()
    }

    @objc func toggleWindowTabPin(_ sender: Any?) {
        guard let activeController = activeEditorController() else {
            return
        }

        activeController.isPinnedToTab = !activeController.isPinnedToTab
        rebuildTabState(activeIdentity: activeController.tabIdentity)
    }

    @objc func setWindowSort(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let mode = AppMenu.WindowSortMode(rawValue: item.tag)
        else {
            return
        }

        windowSortMode = mode
        rebuildTabState(activeIdentity: activeEditorController()?.tabIdentity)
    }

    @objc func setWindowTabColor(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let activeController = activeEditorController()
        else {
            return
        }

        activeController.tabColorIndex = item.tag == 0 ? nil : item.tag
        rebuildTabState(activeIdentity: activeController.tabIdentity)
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
        controller.onClose = { [weak self, weak controller] in
            guard let self, let controller else { return }
            let wasVisible = controller.window?.isVisible == true
            self.windows.removeAll { $0 === controller }
            self.removeMRU(controller)
            self.rebuildTabState()
            self.saveSession()
            self.rememberClosedDocument(controller)
            self.consumeCloseCompletions(for: controller)
            // If this tab's window was the visible one, show the next tab or open a new document.
            if wasVisible {
                let activeId = self.tabState.activeIdentity
                let next = self.windows.first { $0.tabIdentity == activeId } ?? self.windows.first
                if let next {
                    self.activate(next)
                } else {
                    // Last tab closed — open a new empty file instead of leaving the app windowless.
                    self.newDocument(nil)
                }
            }
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
        controller.onTabSelect = { [weak self] identity in
            self?.activateTab(identity: identity)
        }
        controller.onTabClose = { [weak self] identity in
            self?.closeTab(identity: identity)
        }
        controller.onTabContextAction = { [weak self] identity, action in
            self?.handleTabContextAction(identity: identity, action: action)
        }
        controller.onNewDocument = { [weak self] in
            DispatchQueue.main.async { self?.newDocument(nil) }
        }
        controller.onReorderTab = { [weak self] identity, targetIndex in
            guard let self else { return }
            let ordered = self.orderedWindows()
            guard let target = ordered.first(where: { $0.tabIdentity == identity }) else { return }
            self.reorderWindow(target, to: targetIndex)
        }

        // Align new window to the current visible editor window
        if let currentFrame = activeEditorWindow()?.frame,
           let newWindow = controller.window {
            newWindow.setFrame(currentFrame, display: false)
        }

        windows.append(controller)
        rebuildTabState(activeIdentity: controller.tabIdentity)
        // Switch to the new tab; activate() handles showing/hiding windows atomically.
        activate(controller)

        if persistSession {
            saveSession()
        }
    }

    private func existingController(for url: URL) -> EditorWindowController? {
        let standardizedURL = url.standardizedFileURL
        return windows.first { $0.sessionFileURL == standardizedURL }
    }

    private func activate(_ controller: EditorWindowController) {
        guard let newWindow = controller.window else { return }
        let alreadyVisible = newWindow === NSApp.keyWindow
        guard !alreadyVisible else { return }

        // Align to the currently visible editor window's frame.
        let sourceFrame = windows.first(where: { $0.window?.isVisible == true })?.window?.frame
            ?? NSApp.keyWindow?.frame
        if let sourceFrame { newWindow.setFrame(sourceFrame, display: false) }

        trackMRU(controller)
        rebuildTabState(activeIdentity: controller.tabIdentity)

        // Show new window and hide all others atomically to avoid any flash.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0
            newWindow.makeKeyAndOrderFront(nil)
            windows.forEach { if $0 !== controller { $0.window?.orderOut(nil) } }
        }
    }

    private func activateTab(identity: EditorTabIdentity) {
        guard let controller = windows.first(where: { $0.tabIdentity == identity }) else { return }
        activate(controller)
    }

    private func closeTab(identity: EditorTabIdentity) {
        guard let controller = windows.first(where: { $0.tabIdentity == identity }) else { return }
        controller.window?.performClose(nil)
    }

    private func handleTabContextAction(identity: EditorTabIdentity, action: TabContextAction) {
        let ordered = orderedWindows()
        guard let targetController = ordered.first(where: { $0.tabIdentity == identity }) else { return }
        let targetIndex = ordered.firstIndex(where: { $0 === targetController }) ?? 0

        switch action {
        case .closeOthers:
            closeDocumentControllers(ordered.filter { $0 !== targetController })
        case .closeToLeft:
            closeDocumentControllers(Array(ordered[..<targetIndex]))
        case .closeToRight:
            closeDocumentControllers(Array(ordered[ordered.index(after: targetIndex)...]))
        case .copyFilename:
            if case .file(let url) = identity {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
            }
        case .copyFullPath:
            if case .file(let url) = identity {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
        case .openContainingFolder:
            if case .file(let url) = identity {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        case .togglePin:
            targetController.isPinnedToTab.toggle()
            rebuildTabState()
        case .setColor(let colorIndex):
            targetController.tabColorIndex = colorIndex
            rebuildTabState()
        case .moveToStart:
            if let idx = windows.firstIndex(where: { $0 === targetController }), idx > 0 {
                windows.remove(at: idx)
                windows.insert(targetController, at: 0)
                rebuildTabState()
            }
        case .moveToEnd:
            if let idx = windows.firstIndex(where: { $0 === targetController }), idx < windows.count - 1 {
                windows.remove(at: idx)
                windows.append(targetController)
                rebuildTabState()
            }
        case .moveForward:
            if let idx = windows.firstIndex(where: { $0 === targetController }), idx < windows.count - 1 {
                windows.swapAt(idx, idx + 1)
                rebuildTabState()
            }
        case .moveBackward:
            if let idx = windows.firstIndex(where: { $0 === targetController }), idx > 0 {
                windows.swapAt(idx, idx - 1)
                rebuildTabState()
            }
        case .copyDirectoryPath:
            if case .file(let url) = identity {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.deletingLastPathComponent().path, forType: .string)
            }
        case .openContainingFolderInTerminal:
            if case .file(let url) = identity {
                let dir = url.deletingLastPathComponent()
                let script = "tell application \"Terminal\" to do script \"cd \\\"\(dir.path)\\\"\" activate"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        case .save:
            activate(targetController)
            targetController.saveDocument(nil)
        case .saveAs:
            activate(targetController)
            targetController.saveDocumentAs(nil)
        case .rename:
            activate(targetController)
            targetController.renameDocument(nil)
        case .moveToTrash:
            activate(targetController)
            targetController.moveToTrash(nil)
        case .reload:
            activate(targetController)
            targetController.reloadFromDisk(nil)
        case .print:
            activate(targetController)
            targetController.printDocument(nil)
        case .toggleReadOnly:
            activate(targetController)
            targetController.toggleReadOnly(nil)
        }
    }

    private func rebuildTabState(activeIdentity: EditorTabIdentity? = nil) {
        let orderedWindows = orderedWindows()
        let resolvedActive = activeIdentity ?? activeEditorController()?.tabIdentity
        tabState = EditorTabState(
            items: orderedWindows.map(\.tabItem),
            activeIdentity: resolvedActive
        )

        // Push updated tab state to all window tab bars
        for controller in windows {
            controller.updateTabBar(tabState)
        }

        refreshDocumentListPanel()
        refreshWindowsDialog()

        AppMenu.refreshWindowMenu(
            windows: orderedWindows,
            activeIdentity: resolvedActive,
            sortMode: windowSortMode
        )
    }

    private func orderedWindows() -> [EditorWindowController] {
        switch windowSortMode {
        case .none:
            return windows
        case .nameAsc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortName)
        case .nameDesc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortName, ascending: false)
        case .pathAsc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortPath)
        case .pathDesc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortPath, ascending: false)
        case .typeAsc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortType)
        case .typeDesc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortType, ascending: false)
        case .sizeAsc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortSize)
        case .sizeDesc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortSize, ascending: false)
        case .dateAsc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortDate)
        case .dateDesc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortDate, ascending: false)
        case .contentLengthAsc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortContentLength)
        case .contentLengthDesc:
            return orderedWindows(pinned: windows.filter(\.isPinnedToTab), unpinned: windows.filter { !$0.isPinnedToTab }, sortKey: \.windowListSortContentLength, ascending: false)
        }
    }

    private func orderedWindows<T: Comparable>(
        pinned: [EditorWindowController],
        unpinned: [EditorWindowController],
        sortKey: KeyPath<EditorWindowController, T>,
        ascending: Bool = true
    ) -> [EditorWindowController] {
        func sortedWindows(_ list: [EditorWindowController]) -> [EditorWindowController] {
            list.enumerated().sorted { lhs, rhs in
                let lhsValue = lhs.element[keyPath: sortKey]
                let rhsValue = rhs.element[keyPath: sortKey]
                if lhsValue != rhsValue {
                    return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }

        return sortedWindows(pinned) + sortedWindows(unpinned)
    }

    // String-based sort using localized comparison
    private func orderedWindows(
        pinned: [EditorWindowController],
        unpinned: [EditorWindowController],
        sortKey: KeyPath<EditorWindowController, String>,
        ascending: Bool = true
    ) -> [EditorWindowController] {
        func sortedWindows(_ list: [EditorWindowController]) -> [EditorWindowController] {
            list.enumerated().sorted { lhs, rhs in
                let lhsValue = lhs.element[keyPath: sortKey]
                let rhsValue = rhs.element[keyPath: sortKey]
                let order = lhsValue.localizedCaseInsensitiveCompare(rhsValue)
                if order != .orderedSame {
                    return ascending ? order == .orderedAscending : order == .orderedDescending
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }

        return sortedWindows(pinned) + sortedWindows(unpinned)
    }

    private func currentDocumentListItems() -> [DocumentListItem] {
        let activeIdentity = activeEditorController()?.tabIdentity.normalized
        let unsavedFallback = Localization.string(.documentListUnsaved, default: "Unsaved document")

        return orderedWindows().map { controller in
            DocumentListItem(
                title: controller.windowListTitle,
                detail: DocumentListItem.detailText(
                    forPath: controller.sessionFileURL?.path,
                    unsavedFallback: unsavedFallback
                ),
                isActive: controller.tabIdentity.normalized == activeIdentity,
                isDirty: controller.hasUnsavedChanges,
                isPinned: controller.isPinnedToTab,
                representedObject: controller
            )
        }
    }

    private func refreshWindowsDialog() {
        guard windowsDialog.window?.isVisible == true else { return }
        windowsDialog.update(items: currentWindowsDialogItems())
    }

    private func refreshDocumentListPanel() {
        guard documentListPanel.window?.isVisible == true else { return }
        documentListPanel.show(
            items: currentDocumentListItems(),
            onSelect: { [weak self] item in
                guard let controller = item.representedObject as? EditorWindowController else { return }
                self?.activate(controller)
            },
            onAction: { [weak self] item, action in
                self?.handleDocumentListAction(item: item, action: action)
            }
        )
    }

    private func handleDocumentListAction(item: DocumentListItem, action: DocumentListAction) {
        guard let controller = item.representedObject as? EditorWindowController else { return }
        switch action {
        case .activate:
            activate(controller)
        case .close:
            controller.window?.performClose(nil)
        case .closeOthers:
            closeDocumentControllers(windows.filter { $0 !== controller })
        case .copyFilename:
            if let url = controller.sessionFileURL {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
            }
        case .copyPath:
            if let url = controller.sessionFileURL {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
        case .togglePin:
            controller.isPinnedToTab.toggle()
            rebuildTabState()
        }
    }

    private func applyAppPreferences(_ preferences: AppPreferences) {
        let currentLocalizationFileName = Localization.currentLocalizationFileName

        if currentLocalizationFileName != preferences.localizationFileName {
            Localization.apply(localizationFileName: preferences.localizationFileName)
            AppMenu.install(
                delegate: self,
                catalog: languageCatalog,
                themeCatalog: themeCatalog,
                selectedThemeName: themePreferencesStore.load().selectedThemeName
            )
            windows.forEach { $0.refreshLocalization() }
        }

        windows.forEach { $0.applyPreferences(preferences) }
        refreshRecentFilesMenu()
    }

    private func refreshRecentFilesMenu() {
        let prefs = preferencesStore.load()
        AppMenu.refreshRecentFiles(
            maxCount: prefs.recentFilesMaxCount,
            showFullPath: prefs.recentFilesShowFullPath
        )
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showHashGenerator(_ algorithm: HashAlgorithm) {
        hashTextPanel.show(algorithm: algorithm)
    }

    private func generateHashFromFiles(_ algorithm: HashAlgorithm) {
        let panel = NSOpenPanel()
        panel.title = String(
            format: Localization.string(.toolsHashGenerateFromFilesTitleFormat, default: "Generate %@ digest from files"),
            locale: Locale.current,
            algorithm.displayName
        )
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        do {
            let report = try HashToolSupport.fileDigestReport(for: panel.urls, using: algorithm)
            showHashFileReport(report, algorithm: algorithm)
        } catch {
            NSApp.presentError(error)
        }
    }

    private func showHashFileReport(_ report: String, algorithm: HashAlgorithm) {
        let alert = NSAlert()
        alert.messageText = String(
            format: Localization.string(.toolsHashGenerateFromFilesTitleFormat, default: "Generate %@ digest from files"),
            locale: Locale.current,
            algorithm.displayName
        )
        alert.addButton(withTitle: Localization.string(.toolsHashCopyToClipboard, default: "Copy to Clipboard"))
        alert.addButton(withTitle: Localization.string(.toolsHashClose, default: "Close"))

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = report
        textView.setAccessibilityLabel(
            Localization.string(.toolsHashResultAccessibilityLabel, default: "Hash digest result")
        )
        scrollView.documentView = textView
        alert.accessoryView = scrollView

        if alert.runModal() == .alertFirstButtonReturn {
            copyToPasteboard(report)
        }
    }

    func allEditorControllers() -> [EditorWindowController] {
        windows.filter { $0.window?.isVisible == true }
    }

    func activeEditorController() -> EditorWindowController? {
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

    @discardableResult
    private func closeDocumentControllers(
        _ controllers: [EditorWindowController],
        label: String? = nil,
        completion: @escaping () -> Void = {}
    ) -> Bool {
        let existingControllers = controllers.filter { controller in
            windows.contains(where: { $0 === controller })
        }
        guard !existingControllers.isEmpty else {
            completion()
            return false
        }

        let unsaved = existingControllers.filter(\.hasUnsavedChanges)
        let labelText = label ?? Localization.string(.fileClose, default: "Close")

        if !unsaved.isEmpty {
            confirmCloseUnsavedChanges(label: labelText, count: unsaved.count) {
                self.closeDocumentControllersForcibly(existingControllers, completion: completion)
            }
            return true
        }

        closeDocumentControllersForcibly(existingControllers, completion: completion)
        return true
    }

    private func closeDocumentControllersForcibly(
        _ controllers: [EditorWindowController],
        completion: @escaping () -> Void
    ) {
        guard !controllers.isEmpty else {
            completion()
            return
        }

        var remaining = controllers.count
        for controller in controllers {
            addCloseCompletion(for: controller) {
                remaining -= 1
                if remaining == 0 {
                    completion()
                }
            }
            controller.close()
        }
    }

    private func addCloseCompletion(for controller: EditorWindowController, _ completion: @escaping () -> Void) {
        let id = ObjectIdentifier(controller)
        closeCompletions[id, default: []].append(completion)
    }

    private func consumeCloseCompletions(for controller: EditorWindowController) {
        let id = ObjectIdentifier(controller)
        let completions = closeCompletions.removeValue(forKey: id) ?? []
        completions.forEach { $0() }
    }

    private func confirmCloseUnsavedChanges(label: String, count: Int, confirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = Localization.string(.fileCloseUnsavedChangesTitle, default: "Unsaved Changes")
        alert.informativeText = String(
            format: Localization.string(.fileCloseUnsavedChangesMessage, default: "There are %d unsaved document(s) in the selected group. Do you want to %1$@ without saving?"),
            locale: Locale.current,
            count,
            label
        )
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        guard let anchorWindow = NSApp.mainWindow ?? NSApp.keyWindow ?? windows.last?.window else {
            confirm()
            return
        }
        alert.beginSheetModal(for: anchorWindow) { response in
            if response == .alertFirstButtonReturn {
                confirm()
            }
        }
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

    @objc func importStyleTheme(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.xml]
        panel.message = Localization.string(.settingsImportThemeMessage, default: "Choose a Notepad++ XML theme file to import.")
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.importThemeFile(url)
        }
    }

    private func importThemeFile(_ url: URL) {
        let destDir = ThemeCatalog.userThemesDirectory
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let destURL = destDir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
        } catch {
            NSApp.presentError(error)
            return
        }
        // Reload theme catalog and apply new theme
        Task { @MainActor [weak self] in
            let themeName = url.deletingPathExtension().lastPathComponent
            let result = await Task.detached(priority: .userInitiated) {
                Self.loadThemeResources(selectedThemeName: themeName)
            }.value
            self?.applyLoadedThemeResources(result)
        }
    }

    private func reloadLanguageCatalog() {
        languageCatalog = LanguageCatalog.loadDefault()
            .appendingUserDefinedLanguages(userDefinedLanguageStore.load())
    }

    // MARK: - Workspace Find in Files

    private func installWorkspaceFindInFiles() {
        let handler: (URL) -> Void = { [weak self] url in
            self?.showFindInFilesPanel(searchRoot: url)
        }
        workspacePanel.onFindInFiles = handler
        fileBrowserPanel.onFindInFiles = handler
    }

    private func showFindInFilesPanel(searchRoot: URL) {
        if let controller = activeEditorController() {
            controller.showFindInFilesPanel(searchRoot: searchRoot)
        } else if let controller = windows.first {
            controller.showFindInFilesPanel(searchRoot: searchRoot)
        }
    }

    // MARK: - MRU and Ctrl+Tab

    private func trackMRU(_ controller: EditorWindowController) {
        mruList.removeAll { $0 === controller }
        mruList.insert(controller, at: 0)
    }

    private func removeMRU(_ controller: EditorWindowController) {
        mruList.removeAll { $0 === controller }
    }

    private func mruOrderedWindows() -> [EditorWindowController] {
        let windowSet = Set(windows.map { ObjectIdentifier($0) })
        let mruSet = Set(mruList.map { ObjectIdentifier($0) })
        let rest = windows.filter { !mruSet.contains(ObjectIdentifier($0)) }
        let valid = mruList.filter { windowSet.contains(ObjectIdentifier($0)) }
        return valid + rest
    }

    private func installCtrlTabMonitor() {
        tabSwitcher.onConfirm = { [weak self] item in
            guard let controller = item.representedObject as? EditorWindowController else { return }
            self?.activate(controller)
        }

        ctrlTabMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handleCtrlTabEvent(event)
        }
    }

    private func handleCtrlTabEvent(_ event: NSEvent) -> NSEvent? {
        // Tab key = keyCode 48
        let isTab = event.type == .keyDown && event.keyCode == 48
        let isCtrl = event.modifierFlags.contains(.control)
        let isShift = event.modifierFlags.contains(.shift)

        if event.type == .flagsChanged {
            // Ctrl released while switcher is visible → confirm
            if tabSwitcher.isVisible && !event.modifierFlags.contains(.control) {
                tabSwitcher.confirmAndHide()
                return nil
            }
            return event
        }

        guard isTab && isCtrl else { return event }

        // Build MRU item list (exclude current active if only 1 doc)
        let allControllers = windows
        guard allControllers.count > 1 else { return event }

        // Build MRU-ordered list
        let mruIds = mruList.map { ObjectIdentifier($0) }
        let sorted = allControllers.sorted { a, b in
            let ai = mruIds.firstIndex(of: ObjectIdentifier(a)) ?? Int.max
            let bi = mruIds.firstIndex(of: ObjectIdentifier(b)) ?? Int.max
            return ai < bi
        }

        let items = sorted.map { ctrl in
            TabSwitcherController.Item(
                title: ctrl.windowListSortName,
                isDirty: ctrl.hasUnsavedChanges,
                representedObject: ctrl
            )
        }

        if tabSwitcher.isVisible {
            // Already showing: advance selection
            if isShift { tabSwitcher.selectPrevious() } else { tabSwitcher.selectNext() }
        } else {
            // Show with index 1 (skip current), or 0 if only 2 docs
            let startIndex = min(isShift ? items.count - 1 : 1, items.count - 1)
            tabSwitcher.show(items: items, selectedIndex: startIndex)
        }
        return nil
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

    private func promptToCreateNewFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            let alert = NSAlert()
            alert.messageText = url.lastPathComponent
            alert.informativeText = String(
                format: Localization.string(
                    .fileCreateNewPromptMessage,
                    default: "\"%@\" does not exist. Create a new file at this path?"
                ),
                url.path
            )
            alert.addButton(withTitle: Localization.string(.fileCreateNewPromptCreate, default: "Create"))
            alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { continue }
            // Create an empty file at the path
            FileManager.default.createFile(atPath: url.path, contents: nil)
            openFile(url)
        }
    }

    private func restoreSessionOrNewDocument() {
        let prefs = preferencesStore.load()
        if prefs.rememberLastSession {
            restoreSession(sessionStore.load())
        } else if prefs.newDocumentOnLaunch {
            newDocument(nil)
        }
        // else: start with empty state (no windows)
    }

    private func restoreSession(_ session: AppSession) {
        let prefs = preferencesStore.load()
        let skipFileCheck = prefs.noCheckRecentAtLaunch || prefs.keepAbsentFilesInSession
        let existingFiles = skipFileCheck
            ? session.openFiles
            : session.openFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
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
            applyTabState(session.tabState(for: .file(fileURL)), to: controller)
            if let caret = session.caretLocation(for: .file(fileURL)) {
                controller.restoreCaretPosition(caret)
            }
            return controller
        }
        let restoredSnapshotControllers = existingSnapshots.compactMap { snapshot -> EditorWindowController? in
            guard let controller = openSnapshot(snapshot, persistSession: false) else { return nil }
            controller.restoreBookmarks(session.bookmarkSet(for: .snapshot(snapshot.id)))
            controller.restoreFolds(session.foldState(for: .snapshot(snapshot.id)))
            applyTabState(session.tabState(for: .snapshot(snapshot.id)), to: controller)
            if let caret = session.caretLocation(for: .snapshot(snapshot.id)) {
                controller.restoreCaretPosition(caret)
            }
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
            currentWorkspaceURL = url
            showWorkspace(try WorkspaceDocument.load(from: url))
        } catch {
            NSApp.presentError(error)
        }
    }

    func openFolderURLAsWorkspace(_ url: URL) {
        loadWorkspaceFolder(url)
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
        let prefs = preferencesStore.load()
        guard prefs.rememberLastSession, prefs.snapshotModeEnabled else { return }

        snapshotSaveTimer?.invalidate()
        let interval = TimeInterval(prefs.periodicBackupIntervalSeconds)
        snapshotSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveSession()
            }
        }
    }

    private func saveSession() {
        snapshotSaveTimer?.invalidate()
        snapshotSaveTimer = nil

        let state = buildSessionState()

        do {
            try snapshotStore.prune(keeping: state.snapshots)
        } catch {
            NSLog("Failed to prune document snapshots: \(String(describing: error))")
        }

        if state.session.openFiles.isEmpty && state.session.snapshots.isEmpty {
            sessionStore.clear()
        } else {
            sessionStore.save(state.session)
        }
    }

    private func buildSessionState() -> (session: AppSession, snapshots: [DocumentSnapshot]) {
        var openFiles: [URL] = []
        var snapshots: [DocumentSnapshot] = []
        var bookmarkRecords: [SessionBookmarkRecord] = []
        var foldRecords: [SessionFoldRecord] = []
        var tabStateRecords: [SessionTabStateRecord] = []
        var caretRecords: [SessionCaretRecord] = []

        for controller in windows {
            if let draft = controller.makeSnapshotDraft() {
                do {
                    let snapshot = try snapshotStore.save(draft)
                    controller.markSnapshotSaved(snapshot)
                    snapshots.append(snapshot)
                    appendBookmarkRecord(from: controller, to: &bookmarkRecords)
                    appendFoldRecord(from: controller, to: &foldRecords)
                    appendTabStateRecord(from: controller, snapshotID: snapshot.id, to: &tabStateRecords)
                    appendCaretRecord(from: controller, snapshotID: snapshot.id, to: &caretRecords)
                } catch {
                    NSLog("Failed to save document snapshot: \(String(describing: error))")
                    if let fileURL = controller.sessionFileURL {
                        openFiles.append(fileURL)
                        appendBookmarkRecord(from: controller, to: &bookmarkRecords)
                        appendFoldRecord(from: controller, to: &foldRecords)
                        appendTabStateRecord(from: controller, fileURL: fileURL, to: &tabStateRecords)
                        appendCaretRecord(from: controller, fileURL: fileURL, to: &caretRecords)
                    }
                }
            } else if let fileURL = controller.sessionFileURL {
                openFiles.append(fileURL)
                appendBookmarkRecord(from: controller, to: &bookmarkRecords)
                appendFoldRecord(from: controller, to: &foldRecords)
                appendTabStateRecord(from: controller, fileURL: fileURL, to: &tabStateRecords)
                appendCaretRecord(from: controller, fileURL: fileURL, to: &caretRecords)
            }
        }

        let activeSnapshotID = activeSessionSnapshotID()
        let session = AppSession(
            openFiles: openFiles,
            activeFile: activeSnapshotID == nil ? activeSessionFileURL() : nil,
            snapshots: snapshots,
            activeSnapshotID: activeSnapshotID,
            bookmarks: bookmarkRecords,
            folds: foldRecords,
            tabStates: tabStateRecords,
            caretPositions: caretRecords
        )

        return (session, snapshots)
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

    private func appendCaretRecord(
        from controller: EditorWindowController,
        snapshotID: String? = nil,
        fileURL: URL? = nil,
        to records: inout [SessionCaretRecord]
    ) {
        let caretLoc = controller.editorSurface.selectedRange.location
        guard caretLoc > 0 else { return }
        let identity: EditorTabIdentity
        if let id = snapshotID {
            identity = .snapshot(id)
        } else if let url = fileURL {
            identity = .file(url)
        } else {
            return
        }
        records.append(SessionCaretRecord(identity: identity, caretLocation: caretLoc))
    }

    private func applyTabState(_ state: SessionTabStateRecord?, to controller: EditorWindowController) {
        guard let state else { return }
        controller.isTabPinned = state.isPinned
        controller.tabColorIndex = state.tabColorIndex
    }

    private func appendTabStateRecord(
        from controller: EditorWindowController,
        snapshotID: String? = nil,
        fileURL: URL? = nil,
        to records: inout [SessionTabStateRecord]
    ) {
        guard controller.isTabPinned || controller.tabColorIndex != nil else { return }
        let identity: EditorTabIdentity
        if let id = snapshotID {
            identity = .snapshot(id)
        } else if let url = fileURL {
            identity = .file(url)
        } else {
            return
        }
        records.append(SessionTabStateRecord(
            identity: identity,
            isPinned: controller.isTabPinned,
            tabColorIndex: controller.tabColorIndex
        ))
    }

    private func activeSessionFileURL() -> URL? {
        if let keyWindow = NSApp.keyWindow,
           let controller = windows.first(where: { $0.window === keyWindow }),
           let fileURL = controller.sessionFileURL {
            return fileURL
        }

        return windows.compactMap { $0.sessionFileURL }.last
    }
}
