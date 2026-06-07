import AppKit
import NotepadMacCore

enum WhitespaceDisplayMode: Int, CaseIterable {
    case invisible = 0
    case visibleAlways = 1
    case visibleAfterIndent = 2
    case visibleOnlyInIndent = 3
}

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation, NSToolbarItemValidation, NSDraggingDestination {
    var onClose: (() -> Void)?
    var onContentChange: (() -> Void)?
    var onSessionStateChange: (() -> Void)?
    var onActivate: (() -> Void)?
    var onTabSelect: ((EditorTabIdentity) -> Void)?
    var onTabClose: ((EditorTabIdentity) -> Void)?
    var onTabContextAction: ((EditorTabIdentity, TabContextAction) -> Void)?
    var onNewDocument: (() -> Void)?
    var onReorderTab: ((EditorTabIdentity, Int) -> Void)?

    let editorSurface: EditorSurface
    private let tabBarView = EditorTabBarView()
    private let statusField = NSTextField(labelWithString: "")
    private let highlighter = SyntaxHighlighter()
    private var languageCatalog: LanguageCatalog
    private var styleCatalog: StyleCatalog
    private let displayStrings: EditorDisplayStrings
    private let stylePreferencesStore: StylePreferencesStore
    private let preferencesStore: PreferencesStore
    private let scintillaKeyMapStore = ScintillaKeyMapStore()
    private var editorContextMenuSpec: EditorContextMenuSpec?
    private let macroStore = MacroStore()
    private lazy var findPanel = FindPanelController(editor: self, preferencesStore: preferencesStore)
    private lazy var autoCompletionPanel = AutoCompletionPanelController()
    private lazy var callTipPanel = CallTipPanelController()
    private lazy var functionListPanel = FunctionListPanelController()
    private lazy var documentMapPanel = DocumentMapPanelController()
    private lazy var taskListPanel = TaskListPanelController()
    private lazy var columnEditorPanel = ColumnEditorPanelController()
    private lazy var rectangularSelectionPanel = RectangularSelectionPanelController()
    private lazy var clipboardHistoryPanel = ClipboardHistoryPanelController()
    private lazy var findInFilesPanel: FindInFilesPanelController = {
        let delegate = NSApp.delegate as! AppDelegate
        let panel = FindInFilesPanelController(
            editor: self,
            resultsStore: delegate.findInFilesResultsStore,
            onResultsUpdated: { delegate.showFoundResultsPanel() }
        )
        panel.getDirtyFilePaths = { delegate.collectDirtyFilePaths() }
        return panel
    }()
    private lazy var incrementalSearchPanel = IncrementalSearchPanelController(editor: self)
    private lazy var findCharRangePanel = FindCharRangePanelController(editor: self)
    private lazy var editorToolbar = EditorWindowToolbar(controller: self)

    private var fileURL: URL?
    private var encoding: String.Encoding = .utf8
    private var savePolicy = TextFileSavePolicy.newFile
    private var lineEnding: LineEnding = .lf
    private var language: LanguageDefinition
    private var fontSize: CGFloat = 13
    /// User-applied zoom offset (points) relative to the preference base font size.
    /// Preserved across applyPreferences() calls so per-tab zoom survives pref changes.
    private var fontSizeZoomDelta: CGFloat = 0
    private var isDirty = false
    private var wrapsLines = false
    private var whitespaceMode: WhitespaceDisplayMode = .invisible
    private var showsEOL = false
    private var showsIndentGuides = false
    private var highlightsCurrentLine = false
    private var showsWrapSymbol = false
    private var showsChangeHistory = false
    private var showsNpcCharacters = false
    private var caretWidth = 1
    private var caretNoBlink = false
    private var caretBlinkRate = 500
    private var currentLineFrameWidth = 0
    private var lineWrapIndent = 0
    private var foldMarginStyle = 0
    private var useFirstLineAsTabName = false
    private var autoReloadOnExternalChange = false
    private var fileChangeDetectionEnabled = true
    private var reloadScrollToLastCaret = false
    private var editorFontName = ""
    private var editorFontBold = false
    private var backupOnSaveMode: BackupOnSaveMode = .none
    private var useCustomBackupDirectory = false
    private var customBackupDirectory = ""
    private var additionalEdgeColumns: [Int] = []
    private var linePadding = 0
    /// 0=default, 1=LTR, 2=RTL — mirrors SCI_SETBIDIRECTIONAL values
    private var currentBidiMode = 0
    private var enableVirtualSpace = false
    private var backspaceUnindents = true
    private var autoIndent = true
    private var autoIndentMode = 1
    private var fileAutoDetection = 1
    private var updateSilently = false
    private var scrollBeyondLastLine = false
    private var selectedTextDragDrop = true
    private var lineNumberDynamicWidth = false
    private var columnSelectionToMultiEditing = false
    private var muteAllSounds = false
    private var zoomSyncToAllTabs = false
    private var hideMenuShortcuts = false
    private var scrollToLastLineOnMonitorReload = false
    private var trimTrailingSpacesOnSave = false
    private var pasteConvertEndings = true
    private var caretStickyMode = 0
    private var enableCodeFolding = true
    private var autoCompleteIgnoreCase = true
    private var smoothFont = true
    private var multiEditEnabled = true
    private var multiPasteMode = 1
    private var indentGuideMode = 2
    private var wordWrapMode = 1
    private var additionalSelAlpha = 256
    private var additionalCaretsBlink = true
    private var additionalCaretsVisible = true
    private var caretLineVisibleAlways = false
    private var whitespaceSize = 1
    private var selectionAlpha = 256
    private var controlCharDisplay = 0
    private var autoCompleteFromNthChar = 3
    private var autoCompleteMode = 3
    private var autoCompleteChooseSingle = true
    private var autoCompleteTABFillup = false
    private var autoCompleteEnterCommit = true
    private var autoCompleteBrief = false
    private var customMatchedPairs: [[String]] = []
    private var cachedAutoCompletionCatalog: AutoCompletionCatalog?
    private var cachedAutoCompletionCatalogLanguage: String?
    private var enablesSmartHighlight = false
    private var smartHighlightMatchCase = false
    private var smartHighlightWholeWord = true
    private var enablesXmlTagMatch = true
    private var xmlTagAttributeHighlight = true
    private var highlightNonHtmlZone = false
    private var htmlXmlCloseTagEnabled = true
    private var enablesAutoPair = true
    private var autoPairParentheses = true
    private var autoPairBrackets = true
    private var autoPairCurlyBrackets = true
    private var autoPairSingleQuotes = false
    private var autoPairDoubleQuotes = false
    private var enablesClickableLinks = true
    private var showsLineNumberMargin = true
    private var showsBookmarkMargin = true
    private var showsEdgeLine = false
    private var edgeLineColumn = 80
    private var showsStatusBar = true
    private var beginSelectPosition: Int?
    private var lastFindQuery: String?
    private var presentationState = WindowPresentationState()
    private var stylePreferences: StylePreferences
    private var fileChangeSnapshot: FileChangeSnapshot?
    private var fileMonitor: FileMonitor?
    private var isPresentingFileChangeAlert = false
    private var isMonitoringMode = false
    private var documentMapUpdateTimer: Timer?
    private var activeMacroRecording: MacroRecording?
    private var macroBaselineText: String?
    private var isReplayingMacro = false
    private var snapshotID: String?
    private var bookmarks = BookmarkSet()
    private let untitledID = UUID().uuidString
    private var untitledDisplayName: String
    private var pinnedToTab = false
    private var windowTabColorIndex: Int? = nil
    private var statusFieldHeightConstraint: NSLayoutConstraint?
    private var tabBarHeightConstraint: NSLayoutConstraint?

    var sessionFileURL: URL? {
        fileURL?.standardizedFileURL
    }

    var hasUnsavedChanges: Bool {
        isDirty
    }

    var isFileBacked: Bool {
        fileURL != nil
    }

    var sessionSnapshotID: String? {
        snapshotID
    }

    var tabIdentity: EditorTabIdentity {
        if let snapshotID {
            return .snapshot(snapshotID)
        }

        if let fileURL {
            return .file(fileURL)
        }

        return .untitled(untitledID)
    }

    var tabItem: EditorTabItem {
        EditorTabItem(
            identity: tabIdentity,
            title: displayName,
            isDirty: isDirty,
            isPinned: pinnedToTab,
            tabColorIndex: windowTabColorIndex,
            isMonitoring: isMonitoringMode
        )
    }

    var isPinnedToTab: Bool {
        get { pinnedToTab }
        set { pinnedToTab = newValue }
    }

    var windowListTitle: String {
        var title = pinnedToTab ? "📌 \(displayName)" : displayName

        if let tabColorIndex {
            title += " (Color \(tabColorIndex))"
        }

        return title
    }

    var windowListSortName: String {
        displayName
    }

    var encodingDisplayName: String {
        TextEncodingOption(encoding: encoding)?.displayName ?? encoding.description
    }

    var lineEndingDisplayName: String {
        lineEnding.displayName
    }

    var languageDisplayName: String {
        language.displayName
    }

    var currentThemeName: String? {
        // Theme name is managed by AppDelegate; not stored in AppPreferences
        nil
    }

    var scintillaVersion: String? {
        editorSurface is ScintillaEditorSurface ? "Cocoa (bundled)" : nil
    }

    var lexillaVersion: String? {
        editorSurface is ScintillaEditorSurface ? "Cocoa (bundled)" : nil
    }

    var windowListSortPath: String {
        sessionFileURL?.path ?? displayName
    }

    var windowListSortType: String {
        fileURL?.pathExtension.uppercased() ?? ""
    }

    var windowListSortSize: Int {
        guard let url = fileURL else { return 0 }
        return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    var windowListSortDate: Date {
        guard let url = fileURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date
        else { return .distantPast }
        return date
    }

    var windowListSortContentLength: Int {
        editorSurface.text.utf16.count
    }

    var tabColorIndex: Int? {
        get { windowTabColorIndex }
        set { windowTabColorIndex = newValue }
    }

    var isTabPinned: Bool {
        get { pinnedToTab }
        set { pinnedToTab = newValue }
    }

    var sessionBookmarks: BookmarkSet {
        bookmarks.clamped(toLineCount: documentLineCount())
    }

    var sessionFolds: FoldState {
        editorSurface.foldState.clamped(toLineCount: documentLineCount())
    }

    var pluginSelectionContext: PluginCommandSelectionContext {
        let range = editorSurface.selectedRange
        let selectedText = (editorSurface.text as NSString).substring(with: range)
        return PluginCommandSelectionContext(utf16Range: range, text: selectedText)
    }

    var runCommandVariableContext: RunCommandVariableContext {
        let pos = caretLocation()
        let range = editorSurface.selectedRange
        let nsText = editorSurface.text as NSString
        let selectedText = range.length > 0 ? nsText.substring(with: range) : ""
        return RunCommandVariableContext(
            fileURL: sessionFileURL,
            currentLine: pos.line,
            currentColumn: pos.column,
            currentWord: selectedText,
            appBundleURL: Bundle.main.bundleURL
        )
    }

    var supportsToolbarFoldingCommands: Bool {
        editorSurface.supportsFolding
    }

    var editorBackendDisplayName: String {
        editorSurface.displayName
    }

    convenience init(
        fileURL: URL,
        languageCatalog: LanguageCatalog,
        styleCatalog: StyleCatalog,
        preferencesStore: PreferencesStore = PreferencesStore(),
        stylePreferencesStore: StylePreferencesStore = StylePreferencesStore()
    ) throws {
        self.init(
            languageCatalog: languageCatalog,
            styleCatalog: styleCatalog,
            preferencesStore: preferencesStore,
            stylePreferencesStore: stylePreferencesStore
        )
        try load(fileURL)
    }

    convenience init(
        snapshot: DocumentSnapshot,
        snapshotStore: SnapshotStore,
        languageCatalog: LanguageCatalog,
        styleCatalog: StyleCatalog,
        preferencesStore: PreferencesStore = PreferencesStore(),
        stylePreferencesStore: StylePreferencesStore = StylePreferencesStore()
    ) throws {
        self.init(
            languageCatalog: languageCatalog,
            styleCatalog: styleCatalog,
            preferencesStore: preferencesStore,
            stylePreferencesStore: stylePreferencesStore
        )
        try load(snapshot, snapshotStore: snapshotStore)
    }

    init(
        untitledDisplayName: String? = nil,
        languageCatalog: LanguageCatalog = .fallback,
        styleCatalog: StyleCatalog = .empty,
        preferencesStore: PreferencesStore = PreferencesStore(),
        stylePreferencesStore: StylePreferencesStore = StylePreferencesStore()
    ) {
        self.languageCatalog = languageCatalog
        self.styleCatalog = styleCatalog
        let displayStrings = EditorDisplayStrings.localized()
        self.displayStrings = displayStrings
        self.untitledDisplayName = untitledDisplayName ?? displayStrings.untitledDocumentName
        self.preferencesStore = preferencesStore
        self.stylePreferencesStore = stylePreferencesStore
        self.language = languageCatalog.defaultLanguage
        self.editorSurface = EditorSurfaceFactory.make()
        let preferences = preferencesStore.load()
        let stylePreferences = stylePreferencesStore.load()
        self.fontSize = CGFloat(preferences.editorFontSize)
        self.wrapsLines = preferences.wrapsLines
        self.whitespaceMode = preferences.showWhitespace ? .visibleAlways : .invisible
        self.showsEOL = preferences.showEOL
        self.showsIndentGuides = preferences.showIndentGuides
        self.highlightsCurrentLine = preferences.highlightCurrentLine
        self.showsWrapSymbol = preferences.showWrapSymbol
        self.showsChangeHistory = preferences.showChangeHistory
        self.showsNpcCharacters = preferences.showNpcCharacters
        self.caretWidth = preferences.caretWidth
        self.enableVirtualSpace = preferences.enableVirtualSpace
        self.backspaceUnindents = preferences.backspaceUnindents
        self.autoIndent = preferences.autoIndent
        self.autoIndentMode = preferences.autoIndentMode
        self.fileAutoDetection = preferences.fileAutoDetection
        self.updateSilently = preferences.updateSilently
        self.scrollBeyondLastLine = preferences.scrollBeyondLastLine
        self.selectedTextDragDrop = preferences.selectedTextDragDrop
        self.lineNumberDynamicWidth = preferences.lineNumberDynamicWidth
        self.columnSelectionToMultiEditing = preferences.columnSelectionToMultiEditing
        self.linePadding = preferences.linePadding
        self.muteAllSounds = preferences.muteAllSounds
        self.zoomSyncToAllTabs = preferences.zoomSyncToAllTabs
        self.hideMenuShortcuts = preferences.hideMenuShortcuts
        self.scrollToLastLineOnMonitorReload = preferences.scrollToLastLineOnMonitorReload
        self.autoCompleteFromNthChar = preferences.autoCompleteFromNthChar
        self.autoCompleteMode = preferences.autoCompleteMode
        self.autoCompleteChooseSingle = preferences.autoCompleteChooseSingle
        self.autoCompleteTABFillup = preferences.autoCompleteTABFillup
        self.autoCompleteEnterCommit = preferences.autoCompleteEnterCommit
        self.autoCompleteBrief = preferences.autoCompleteBrief
        self.customMatchedPairs = preferences.customMatchedPairs
        tabBarView.doubleClickClosesTab = preferences.tabbarDoubleClickClose
        tabBarView.tabMaxLabelLength = preferences.tabbarMaxLabelLength
        tabBarView.showCloseButton = preferences.tabbarShowCloseButton
        tabBarView.compactMode = preferences.tabbarCompact
        tabBarView.showIndexNumbers = preferences.tabbarShowIndexNumbers
        self.enablesAutoPair = preferences.enableAutoPair
        self.autoPairParentheses = preferences.autoPairParentheses
        self.autoPairBrackets = preferences.autoPairBrackets
        self.autoPairCurlyBrackets = preferences.autoPairCurlyBrackets
        self.autoPairSingleQuotes = preferences.autoPairSingleQuotes
        self.autoPairDoubleQuotes = preferences.autoPairDoubleQuotes
        self.enablesXmlTagMatch = preferences.enableXmlTagMatch
        self.xmlTagAttributeHighlight = preferences.xmlTagAttributeHighlight
        self.highlightNonHtmlZone = preferences.highlightNonHtmlZone
        self.htmlXmlCloseTagEnabled = preferences.htmlXmlCloseTagEnabled
        self.enablesClickableLinks = preferences.enableClickableLinks
        self.showsLineNumberMargin = preferences.showLineNumberMargin
        self.showsBookmarkMargin = preferences.showBookmarkMargin
        self.showsEdgeLine = preferences.showEdgeLine
        self.edgeLineColumn = preferences.edgeLineColumn
        self.smartHighlightMatchCase = preferences.smartHighlightUseFindSettings
            ? preferences.searchMatchCase : preferences.smartHighlightMatchCase
        self.smartHighlightWholeWord = preferences.smartHighlightUseFindSettings
            ? preferences.searchWholeWord : preferences.smartHighlightWholeWord
        self.stylePreferences = stylePreferences
        // Apply default new-document encoding and line ending from preferences
        if let encodingOpt = TextEncodingOption(rawValue: preferences.defaultNewDocumentEncoding) {
            self.encoding = encodingOpt.encoding
        }
        if let lineEndingDefault = LineEnding(rawValue: preferences.defaultNewDocumentLineEnding) {
            self.lineEnding = lineEndingDefault
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = displayStrings.windowTitle(displayName: self.untitledDisplayName, isDirty: false)
        window.animationBehavior = .none
        window.delegate = self
        window.nextResponder = self
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("NotepadMacEditorWindow")
        if window.frame == NSRect(x: 0, y: 0, width: 980, height: 680) {
            window.center()
        }
        configureContent()
        configureToolbar()
        observeEditorNotifications()
        observeEditorSurfaceInteractions()
        configureAutoPair()
        configureUrlHighlight()
        configureDragAndDrop()
        updateTitle()
        updateStatus()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillClose(_ notification: Notification) {
        editorSurface.teardown()
        stopFileMonitoring()
        onClose?()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onActivate?()
    }

    @objc private func editorTextDidChange(_ notification: Notification) {
        recordMacroTextChangeIfNeeded(to: editorSurface.text)
        bookmarks = bookmarks.clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        isDirty = true
        if showsLineNumberMargin { editorSurface.applyLineNumberMargin(true) }
        editorSurface.applyBookmarkMarginVisible(showsBookmarkMargin)
        updateFirstLineTabName()
        updateTitle()
        highlight()
        updateStatus()
        updateXmlTagHighlight()
        updateSmartHighlight()
        scheduleUrlHighlightUpdate()
        scheduleDocumentMapUpdate()
        onContentChange?()
    }

    private func scheduleDocumentMapUpdate() {
        guard documentMapPanel.isVisible else { return }
        documentMapUpdateTimer?.invalidate()
        documentMapUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.documentMapPanel.update(
                    documentName: self.displayName,
                    text: self.editorSurface.text,
                    currentLine: self.caretLocation().line
                )
                if self.taskListPanel.isVisible {
                    self.taskListPanel.update(
                        documentName: self.displayName,
                        text: self.editorSurface.text,
                        customTagsPreference: self.preferencesStore.load().taskListCustomTags
                    )
                }
            }
        }
    }

    @objc private func editorSelectionDidChange(_ notification: Notification) {
        updateStatus()
        updateXmlTagHighlight()
        updateSmartHighlight()
        updateBraceHighlight()
        if documentMapPanel.isVisible {
            let line = caretLocation().line
            documentMapPanel.update(documentName: displayName, text: editorSurface.text, currentLine: line)
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        guard let fileURL else {
            saveDocumentAs(sender)
            return
        }
        save(to: fileURL)
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = displayStrings.saveAsName(fileURL: fileURL)
        let prefs = preferencesStore.load()
        if !prefs.defaultSaveDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: prefs.defaultSaveDirectory)
        }
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.save(to: url)
        }
    }

    @objc func saveCopyAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = displayStrings.saveAsName(fileURL: fileURL)
        let prefs = preferencesStore.load()
        if !prefs.defaultSaveDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: prefs.defaultSaveDirectory)
        }
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            self.saveCopy(at: url)
        }
    }

    @objc func insertFile(_ sender: Any?) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let loaded = try TextFileCodec.read(url, openAnsiAsUtf8: preferencesStore.load().openAnsiAsUtf8)
                self.insertText(loaded.text)
            } catch {
                self.presentError(error)
            }
        }
    }

    @objc func reloadFromDisk(_ sender: Any?) {
        guard fileURL != nil else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }

        guard isDirty else {
            reloadMonitoredFileFromDisk()
            return
        }

        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = Localization.string(.fileReloadFromDisk, default: "Reload from Disk")
        alert.informativeText = String(
            format: Localization.string(.fileReloadWithUnsavedChangesWarning),
            locale: Locale.current,
            displayName
        )
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.reloadMonitoredFileFromDisk()
            }
        }
    }

    @objc func openContainingFolder(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }

        let workspace = NSWorkspace.shared
        workspace.activateFileViewerSelecting([fileURL])
        if !workspace.open(fileURL.deletingLastPathComponent()) {
            presentMissingFeatureResource(Localization.string(.fileOpenContainingFolderFailed, default: "Failed to open containing folder."))
        }
    }

    @objc func openContainingFolderAsWorkspace(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        let folderURL = fileURL.deletingLastPathComponent()
        (NSApp.delegate as? AppDelegate)?.openFolderURLAsWorkspace(folderURL)
    }

    @objc func openContainingFolderInTerminal(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        let folder = fileURL.deletingLastPathComponent().path
        openTerminal(at: folder)
    }

    private func openTerminal(at path: String) {
        let escaped = path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            if (count of windows) = 0 then
                do script "cd '\(escaped)'"
            else
                do script "cd '\(escaped)'" in front window
            end if
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        if let error {
            presentMissingFeatureResource("Failed to open Terminal: \(error)")
        }
    }

    @objc func openInDefaultViewer(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        if !NSWorkspace.shared.open(fileURL) {
            presentMissingFeatureResource(String(
                format: Localization.string(.fileOpenInDefaultViewerFailed),
                locale: Locale.current,
                fileURL.lastPathComponent
            ))
        }
    }

    @objc func renameDocument(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }

        let alert = NSAlert()
        alert.messageText = Localization.string(.fileRename, default: "Rename")
        alert.informativeText = Localization.string(.fileRenamePrompt, default: "Enter a new name for this file.")
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        nameField.stringValue = fileURL.lastPathComponent
        alert.accessoryView = nameField
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))

        guard let window else { return }

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.applyRename(to: nameField.stringValue)
        }
    }

    @objc func moveToTrash(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = Localization.string(.fileMoveToTrash, default: "Move to Trash")
        alert.informativeText = String(
            format: Localization.string(.fileMoveToTrashConfirm),
            locale: Locale.current,
            fileURL.lastPathComponent
        )
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.deleteCurrentFileToTrash()
        }
    }

    @objc func printDocument(_ sender: Any?) {
        let prefs = preferencesStore.load()
        runPrintOperation(text: editorSurface.text, title: displayName, showPanel: true, prefs: prefs)
    }

    @objc func printSelection(_ sender: Any?) {
        let sel = editorSurface.selectedRange
        guard sel.length > 0 else { printDocument(sender); return }
        let prefs = preferencesStore.load()
        let selText = (editorSurface.text as NSString).substring(with: sel)
        runPrintOperation(text: selText, title: "\(displayName) [Selection]", showPanel: true, prefs: prefs)
    }

    /// Print immediately without showing the print dialog.
    func printNow() {
        let prefs = preferencesStore.load()
        runPrintOperation(text: editorSurface.text, title: displayName, showPanel: false, prefs: prefs)
    }

    private func runPrintOperation(text: String, title: String, showPanel: Bool, prefs: AppPreferences) {
        let document = PrintDocument(
            title: title,
            text: text,
            languageDisplayName: language.displayName,
            encodingDisplayName: encoding.displayName
        )
        let ps = prefs.printSettings
        let printView = PrintTextView(
            document: document,
            fontSize: fontSize,
            includeLineNumbers: prefs.printLineNumbers,
            printSettings: ps,
            filePath: fileURL?.path
        )
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.topMargin = CGFloat(ps.marginTop)
        printInfo.bottomMargin = CGFloat(ps.marginBottom)
        printInfo.leftMargin = CGFloat(ps.marginLeft)
        printInfo.rightMargin = CGFloat(ps.marginRight)

        let operation = NSPrintOperation(view: printView, printInfo: printInfo)
        operation.jobTitle = title
        operation.showsPrintPanel = showPanel
        operation.showsProgressPanel = true

        if showPanel, let window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    @objc func convertEncoding(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let rawValue = item.representedObject as? String,
              let option = TextEncodingOption(rawValue: rawValue)
        else {
            return
        }

        encoding = option.encoding
        savePolicy = savePolicy.converted(to: option.encoding)
        isDirty = true
        updateTitle()
        updateStatus()
        onContentChange?()
    }

    @objc func encodeInEncoding(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let rawValue = item.representedObject as? String,
              let option = TextEncodingOption(rawValue: rawValue),
              let url = fileURL
        else { return }

        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: option.encoding) else {
                let alert = NSAlert()
                alert.messageText = Localization.string(.encodingReinterpretFailed, default: "Cannot Reinterpret")
                alert.informativeText = String(format: Localization.string(.encodingReinterpretFailedInfo, default: "The file cannot be reinterpreted as %@."), option.displayName)
                alert.runModal()
                return
            }
            editorSurface.text = text
            encoding = option.encoding
            savePolicy = TextFileSavePolicy(preservesByteOrderMark: false)
            isDirty = false
            updateTitle()
            updateStatus()
            highlight()
        } catch {
            // Failed to read file
        }
    }

    @objc func autoDetectEncoding(_ sender: Any?) {
        guard let url = fileURL else { return }
        do {
            let loaded = try TextFileCodec.read(url, openAnsiAsUtf8: preferencesStore.load().openAnsiAsUtf8)
            let detectedEncoding = loaded.encoding
            guard detectedEncoding != encoding else { return }
            encoding = detectedEncoding
            savePolicy = TextFileSavePolicy.loaded(loaded)
            updateStatus()
        } catch {
            // File unreadable; no change
        }
    }

    /// Encoding > Reload as Encoding — reload current file interpreting it as a specific encoding.
    @objc func reloadAsEncoding(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let rawValue = menuItem.representedObject as? String,
              let option = TextEncodingOption(rawValue: rawValue),
              let url = fileURL
        else { return }
        do {
            let loaded = try TextFileCodec.read(url, forcingEncoding: option)
            encoding = loaded.encoding
            savePolicy = TextFileSavePolicy.loaded(loaded)
            editorSurface.text = loaded.text
            isDirty = false
            updateTitle()
            updateStatus()
        } catch {
            presentMissingFeatureResource(
                String(format: "Failed to reload file as %@: %@",
                       option.displayName, error.localizedDescription)
            )
        }
    }

    @objc func toggleByteOrderMark(_ sender: Any?) {
        savePolicy = savePolicy.withByteOrderMark(!savePolicy.preservesByteOrderMark)
        isDirty = true
        updateTitle()
        updateStatus()
        onContentChange?()
    }

    @objc func convertLineEnding(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let rawValue = item.representedObject as? String,
              let nextLineEnding = LineEnding(rawValue: rawValue)
        else {
            return
        }

        let selectedRange = editorSurface.selectedRange
        let normalizedText = nextLineEnding.normalize(editorSurface.text)
        lineEnding = nextLineEnding
        applyEditedText(
            normalizedText,
            selectedRange: NSRange(
                location: min(selectedRange.location, (normalizedText as NSString).length),
                length: 0
            )
        )
    }

    @objc func toggleLineWrap(_ sender: Any?) {
        wrapsLines.toggle()
        saveCurrentEditorPreferences()
        applyLineWrapping()
    }

    @objc func toggleShowWhitespace(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        // Toggle between invisible and visible always
        whitespaceMode = whitespaceMode == .invisible ? .visibleAlways : .invisible
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func setWhitespaceMode(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let mode = menuItem.representedObject as? WhitespaceDisplayMode
        else { return }
        whitespaceMode = mode
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func toggleShowEOL(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        showsEOL.toggle()
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func toggleIndentGuides(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        showsIndentGuides.toggle()
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func toggleCurrentLineHighlight(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        highlightsCurrentLine.toggle()
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func toggleWrapSymbol(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        showsWrapSymbol.toggle()
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func toggleChangeHistory(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        showsChangeHistory.toggle()
        saveCurrentEditorPreferences()
        applyAdvancedViewOptions()
    }

    @objc func toggleSmartHighlight(_ sender: Any?) {
        enablesSmartHighlight.toggle()
        if !enablesSmartHighlight {
            editorSurface.clearSmartHighlight()
        }
        updateSmartHighlight()
        updateStatus()
    }

    @objc func toggleXmlTagMatch(_ sender: Any?) {
        enablesXmlTagMatch.toggle()
        if !enablesXmlTagMatch {
            editorSurface.clearXmlTagHighlight()
        } else {
            updateXmlTagHighlight()
        }
        saveCurrentEditorPreferences()
    }

    private func updateBraceHighlight() {
        if isLargeFile && preferencesStore.load().largeFileSuppressBraceMatch { return }
        editorSurface.updateBraceHighlightAtUtf16Location(editorSurface.selectedRange.location)
    }

    private func updateXmlTagHighlight() {
        guard enablesXmlTagMatch, editorSurface.supportsXmlTagMatch else { return }
        let text = editorSurface.text
        let nsLen = (text as NSString).length
        let cursorPos = min(editorSurface.selectedRange.location, nsLen)
        if let match = XmlTagMatcher.findMatch(in: text, cursorPosition: cursorPos) {
            editorSurface.applyXmlTagHighlight(openRange: match.openTagRange, closeRange: match.closeTagRange)
            if xmlTagAttributeHighlight, let attrRange = match.attributeRange {
                editorSurface.applyXmlAttributeHighlight(range: attrRange)
            } else {
                editorSurface.clearXmlAttributeHighlight()
            }
        } else {
            editorSurface.clearXmlTagHighlight()
            editorSurface.clearXmlAttributeHighlight()
        }
    }

    @objc func toggleAutoPair(_ sender: Any?) {
        enablesAutoPair.toggle()
        configureAutoPair()
        saveCurrentEditorPreferences()
    }

    @objc func toggleClickableLinks(_ sender: Any?) {
        enablesClickableLinks.toggle()
        if enablesClickableLinks {
            scheduleUrlHighlightUpdate()
        } else {
            editorSurface.clearUrlHighlights()
        }
        saveCurrentEditorPreferences()
    }

    @objc func toggleNpcDisplay(_ sender: Any?) {
        guard editorSurface.supportsNpcDisplay else { return }
        showsNpcCharacters.toggle()
        editorSurface.applyNpcDisplay(showsNpcCharacters)
        saveCurrentEditorPreferences()
    }

    private func configureUrlHighlight() {
        guard editorSurface.supportsUrlHighlight else { return }
        editorSurface.setUrlClickHandler { [weak self] range in
            self?.openUrlInRange(range)
        }
        scheduleUrlHighlightUpdate()
    }

    private var urlHighlightTimer: DispatchWorkItem?

    private func scheduleUrlHighlightUpdate() {
        urlHighlightTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.applyUrlHighlights()
        }
        urlHighlightTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func applyUrlHighlights() {
        guard enablesClickableLinks, editorSurface.supportsUrlHighlight else { return }
        let prefs = preferencesStore.load()
        let text = editorSurface.text
        let ranges = URLScanner.findURLRanges(in: text, schemes: prefs.effectiveURLSchemes)
        editorSurface.applyUrlHighlights(ranges: ranges, style: prefs.urlIndicatorStyle)
    }

    private func openUrlInRange(_ range: NSRange) {
        let text = editorSurface.text as NSString
        guard range.location + range.length <= text.length else { return }
        let urlString = text.substring(with: range)
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func configureAutoPair() {
        guard editorSurface.supportsAutoPair else { return }
        if enablesAutoPair {
            editorSurface.setAutoPairHandler { [weak self] char in
                self?.handleAutoPairChar(char)
            }
        } else {
            editorSurface.setAutoPairHandler(nil)
        }
    }

    private func handleAutoPairChar(_ ch: Character) {
        let text = editorSurface.text as NSString
        let caretPos = editorSurface.selectedRange.location
        let docLen = text.length

        // charPrev: character before the just-typed char (at caretPos - 2 in NSString terms)
        func charAt(_ pos: Int) -> Character? {
            guard pos >= 0, pos < docLen else { return nil }
            let s = text.substring(with: NSRange(location: pos, length: 1))
            return s.first
        }

        // caretPos is already after the typed char
        let charNext = charAt(caretPos)      // char after cursor
        let charPrev = charAt(caretPos - 2)  // char before what was typed

        let isNextBlank = charNext == nil || charNext == " " || charNext == "\t" || charNext == "\n" || charNext == "\r"
        let isNextCloseSymbol = charNext == ")" || charNext == "]" || charNext == "}"

        switch ch {
        case "(":
            if autoPairParentheses && (isNextBlank || isNextCloseSymbol) {
                editorSurface.insertAutoPairClose(")")
            }
        case "[":
            if autoPairBrackets && (isNextBlank || isNextCloseSymbol) {
                editorSurface.insertAutoPairClose("]")
            }
        case "{":
            if autoPairCurlyBrackets && (isNextBlank || isNextCloseSymbol) {
                editorSurface.insertAutoPairClose("}")
            }
        case "\"":
            let isPrevBlank = charPrev == nil || charPrev == " " || charPrev == "\t" || charPrev == "\n" || charPrev == "\r"
            if autoPairDoubleQuotes && isPrevBlank && isNextBlank {
                editorSurface.insertAutoPairClose("\"")
            }
        case "'":
            let isPrevBlank = charPrev == nil || charPrev == " " || charPrev == "\t" || charPrev == "\n" || charPrev == "\r"
            if autoPairSingleQuotes && isPrevBlank && isNextBlank {
                editorSurface.insertAutoPairClose("'")
            }
        case ">":
            if htmlXmlCloseTagEnabled, let closeTag = xmlCloseTagToInsert(text: text, caretPos: caretPos) {
                // Insert the close tag string char by char via the surface
                let nsText = editorSurface.text as NSString
                let curPos = editorSurface.selectedRange.location
                let newText = (nsText.substring(to: curPos) + closeTag + nsText.substring(from: curPos)) as NSString
                editorSurface.text = newText as String
                editorSurface.setSelectedRange(NSRange(location: curPos + closeTag.utf16.count, length: 0))
            }
        default:
            // Custom user-defined matched pairs
            let typed = String(ch)
            for pair in customMatchedPairs {
                guard pair.count == 2,
                      pair[0] == typed,
                      !pair[1].isEmpty,
                      pair[0] != pair[1] else { continue }
                if isNextBlank || isNextCloseSymbol,
                   let closeChar = pair[1].first {
                    editorSurface.insertAutoPairClose(closeChar)
                }
                break
            }
        }
    }

    private func xmlCloseTagToInsert(text: NSString, caretPos: Int) -> String? {
        let isHtmlOrXml: Bool
        let langName = language.name.lowercased()
        if langName.hasPrefix("html") || langName == "php" || langName == "asp" {
            isHtmlOrXml = true
        } else if langName == "xml" || langName.hasSuffix("xml") {
            isHtmlOrXml = false  // isHTML = false for pure XML
        } else {
            return nil
        }

        // caretPos is after the typed `>`, so text[caretPos-2] and text[caretPos-3]
        guard caretPos >= 2 else { return nil }
        let prev = charAt(text, caretPos - 2)
        let prevprev = caretPos >= 3 ? charAt(text, caretPos - 3) : nil

        // Ignore `-->` and `/>`
        if prevprev == "-" && prev == "-" { return nil }
        if prev == "/" { return nil }

        // Scan backward from caretPos-2 (before `>`) to find `<`
        var pos = caretPos - 2
        while pos > 0 {
            let c = charAt(text, pos)
            if c == "<" { break }
            if c == ">" { return nil }  // encountered another > before finding <
            pos -= 1
        }
        guard charAt(text, pos) == "<" else { return nil }

        // Extract from < to caretPos-1 (just before the >)
        let tagRange = NSRange(location: pos, length: caretPos - 1 - pos)
        guard tagRange.length > 0 else { return nil }
        let tagContent = text.substring(with: tagRange)  // e.g. "<div class='x'"

        // tagContent[1] must not be '/' or '?' or '!'
        let stripped = tagContent.dropFirst()  // drop '<'
        guard let firstChar = stripped.first else { return nil }
        if firstChar == "/" || firstChar == "?" || firstChar == "!" { return nil }

        // Extract tag name: first word after '<'
        let tagName = stripped.prefix(while: { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == ":" })
        guard !tagName.isEmpty else { return nil }

        // For HTML, skip void elements
        if isHtmlOrXml {
            let voidTags: Set<String> = ["area","base","br","col","embed","hr","img","input","keygen","link","meta","param","source","track","wbr","!doctype"]
            if voidTags.contains(tagName.lowercased()) { return nil }
        }

        return "</\(tagName)>"
    }

    private func charAt(_ text: NSString, _ pos: Int) -> Character? {
        guard pos >= 0, pos < text.length else { return nil }
        let s = text.substring(with: NSRange(location: pos, length: 1))
        return s.first
    }

    private func updateSmartHighlight() {
        guard enablesSmartHighlight else { return }
        if isLargeFile && preferencesStore.load().largeFileSuppressSmartHighlight { return }
        let text = editorSurface.text
        let selection = editorSurface.selectedRange
        if selection.length > 0 {
            let word = (text as NSString).substring(with: selection)
            editorSurface.applySmartHighlight(word, matchCase: smartHighlightMatchCase, wholeWord: smartHighlightWholeWord)
        } else {
            // Get word under caret
            let nsText = text as NSString
            let location = min(selection.location, nsText.length)
            var start = location
            var end = location
            while start > 0 {
                let ch = nsText.substring(with: NSRange(location: start - 1, length: 1))
                guard ch.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" }) else { break }
                start -= 1
            }
            while end < nsText.length {
                let ch = nsText.substring(with: NSRange(location: end, length: 1))
                guard ch.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" }) else { break }
                end += 1
            }
            if end > start {
                let word = nsText.substring(with: NSRange(location: start, length: end - start))
                editorSurface.applySmartHighlight(word, matchCase: smartHighlightMatchCase, wholeWord: smartHighlightWholeWord)
            } else {
                editorSurface.clearSmartHighlight()
            }
        }
    }

    @objc func toggleLineNumberMargin(_ sender: Any?) {
        showsLineNumberMargin.toggle()
        saveCurrentEditorPreferences()
        editorSurface.applyLineNumberMargin(showsLineNumberMargin)
    }

    @objc func toggleBookmarkMargin(_ sender: Any?) {
        showsBookmarkMargin.toggle()
        saveCurrentEditorPreferences()
        editorSurface.applyBookmarkMarginVisible(showsBookmarkMargin)
    }

    @objc func toggleEdgeLine(_ sender: Any?) {
        guard editorSurface.supportsAdvancedViewOptions else { return }
        showsEdgeLine.toggle()
        saveCurrentEditorPreferences()
        editorSurface.applyEdgeLine(showsEdgeLine, column: edgeLineColumn)
    }

    @objc func zoomRestore(_ sender: Any?) {
        fontSizeZoomDelta = 0
        fontSize = CGFloat(preferencesStore.load().editorFontSize)
        applyFont()
    }

    private func beepIfEnabled() {
        guard !muteAllSounds else { return }
        NSSound.beep()
    }

    func applyFontSize(_ size: CGFloat) {
        fontSize = min(max(size, CGFloat(AppPreferences.minimumEditorFontSize)), CGFloat(AppPreferences.maximumEditorFontSize))
        fontSizeZoomDelta = fontSize - CGFloat(preferencesStore.load().editorFontSize)
        applyFont()
    }

    var currentFontSize: CGFloat { fontSize }

    @objc func selectBetweenDelimiters(_ sender: Any?) {
        let prefs = preferencesStore.load()
        let left = prefs.delimiterLeft
        let right = prefs.delimiterRight
        let text = editorSurface.text
        let selection = editorSurface.selectedRange
        guard let newRange = TextEditCommands.selectBetweenDelimiters(
            in: text,
            from: selection,
            left: left,
            right: right
        ) else { return }
        editorSurface.setSelectedRange(newRange)
        updateStatus()
    }

    @objc func beginOrEndSelect(_ sender: Any?) {
        if let beginPos = beginSelectPosition {
            let endPos = editorSurface.selectedRange.location
            let start = min(beginPos, endPos)
            let end = max(beginPos, endPos)
            editorSurface.setSelectedRange(NSRange(location: start, length: end - start))
            beginSelectPosition = nil
        } else {
            beginSelectPosition = editorSurface.selectedRange.location
        }
        updateStatus()
    }

    @objc func selectCurrentLine(_ sender: Any?) {
        let lineRange = selectedLineRange()
        let nsText = editorSurface.text as NSString
        let startRange = selectionRange(forLine: lineRange.lowerBound)
        let endRange = lineRange.upperBound <= documentLineCount()
            ? selectionRange(forLine: lineRange.upperBound + 1)
            : NSRange(location: nsText.length, length: 0)
        let lineLength = endRange.location - startRange.location
        editorSurface.setSelectedRange(NSRange(location: startRange.location, length: lineLength))
        updateStatus()
    }

    @objc func toggleStatusBar(_ sender: Any?) {
        showsStatusBar.toggle()
        saveCurrentEditorPreferences()
        applyStatusBarVisibility()
    }

    @objc func toggleToolbarVisibility(_ sender: Any?) {
        guard let window = window else { return }
        window.toolbar?.isVisible.toggle()
        UserDefaults.standard.set(window.toolbar?.isVisible ?? true, forKey: "notepadMac.toolbarVisible")
    }

    @objc private func statusBarDoubleClicked(_ sender: Any?) {
        showGoToLinePanel(sender)
    }

    @objc func toggleReadOnly(_ sender: Any?) {
        editorSurface.isReadOnly.toggle()
        updateStatus()
    }

    @objc func setTextDirectionRTL(_ sender: Any?) {
        currentBidiMode = 2
        editorSurface.applyBidirectional(2)
        saveCurrentEditorPreferences()
    }

    @objc func setTextDirectionLTR(_ sender: Any?) {
        currentBidiMode = 1
        editorSurface.applyBidirectional(1)
        saveCurrentEditorPreferences()
    }

    @objc func increaseNumberAtCaret(_ sender: Any?) {
        modifyNumberAtCaret(delta: 1)
    }

    @objc func decreaseNumberAtCaret(_ sender: Any?) {
        modifyNumberAtCaret(delta: -1)
    }

    private func modifyNumberAtCaret(delta: Int) {
        let nsText = editorSurface.text as NSString
        let caretPos = editorSurface.selectedRange.location
        guard caretPos < nsText.length else { return }

        // Find the number token containing or adjacent to the caret
        let searchRange = NSRange(location: max(0, caretPos - 1), length: min(2, nsText.length - max(0, caretPos - 1)))
        let searchStr = nsText.substring(with: searchRange)

        // Find a digit in the search range to locate the number
        guard let digitOffset = searchStr.firstIndex(where: { $0.isNumber }) else {
            beepIfEnabled()
            return
        }
        let numberStart = searchRange.location + searchStr.distance(from: searchStr.startIndex, to: digitOffset)

        // Expand to find full number boundaries
        var numStart = numberStart
        while numStart > 0, nsText.substring(with: NSRange(location: numStart - 1, length: 1)).first?.isNumber == true {
            numStart -= 1
        }
        var numEnd = numberStart + 1
        while numEnd < nsText.length, nsText.substring(with: NSRange(location: numEnd, length: 1)).first?.isNumber == true {
            numEnd += 1
        }

        let numRange = NSRange(location: numStart, length: numEnd - numStart)
        let numStr = nsText.substring(with: numRange)
        guard let num = Int(numStr) else {
            beepIfEnabled()
            return
        }

        let newNum = num + delta
        let newStr = String(newNum)
        let nextText = nsText.replacingCharacters(in: numRange, with: newStr)
        let nextCaret = NSRange(location: numStart + (newStr as NSString).length, length: 0)
        applyEditedText(nextText, selectedRange: nextCaret)
    }

    @objc func redactSelection(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        guard selection.length > 0 else { return }
        let redacted = String(repeating: "X", count: selection.length)
        insertText(redacted)
        // Clear clipboard to avoid leaking the original content
        NSPasteboard.general.clearContents()
    }

    @objc func pasteHtmlContent(_ sender: Any?) {
        let pb = NSPasteboard.general
        guard let html = pb.string(forType: .html) else {
            beepIfEnabled()
            return
        }
        // Convert HTML to plain text
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
        else {
            beepIfEnabled()
            return
        }
        insertText(attributed.string)
    }

    /// Paste as Plain Text — strips all formatting, inserts only the plain text string.
    @objc func pasteAsPlainText(_ sender: Any?) {
        let pb = NSPasteboard.general
        guard let plain = pb.string(forType: .string) else {
            beepIfEnabled()
            return
        }
        insertText(plain)
    }

    @objc func pasteRtfContent(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let rtfData = pb.data(forType: .rtf) ?? pb.data(forType: .rtfd),
           let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            insertText(attributed.string)
        } else {
            beepIfEnabled()
        }
    }

    private func insertText(_ text: String) {
        let nsText = editorSurface.text as NSString
        let selection = editorSurface.selectedRange
        let safeLoc = min(selection.location, nsText.length)
        let safeLen = min(selection.length, nsText.length - safeLoc)
        let safeRange = NSRange(location: safeLoc, length: safeLen)
        let nextText = nsText.replacingCharacters(in: safeRange, with: text)
        let nextCaret = NSRange(location: safeLoc + (text as NSString).length, length: 0)
        applyEditedText(nextText, selectedRange: nextCaret)
    }

    @objc func copyLink(_ sender: Any?) {
        let selectedRange = editorSurface.selectedRange
        let nsText = editorSurface.text as NSString
        let text: String
        if selectedRange.length > 0 {
            text = nsText.substring(with: selectedRange)
        } else if let urlRange = editorSurface.urlIndicatorRange(at: selectedRange.location),
                  urlRange.length > 0, NSMaxRange(urlRange) <= nsText.length {
            // Cursor is on a detected URL indicator
            text = nsText.substring(with: urlRange)
        } else {
            // Extract the word/token at caret
            let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineText = nsText.substring(with: lineRange)
            let lineOffset = selectedRange.location - lineRange.location
            let chars = Array(lineText)
            guard lineOffset < chars.count else { return }
            var start = lineOffset
            while start > 0, !CharacterSet.whitespacesAndNewlines.contains(chars[start - 1].unicodeScalars.first!) {
                start -= 1
            }
            var end = lineOffset
            while end < chars.count, !CharacterSet.whitespacesAndNewlines.contains(chars[end].unicodeScalars.first!) {
                end += 1
            }
            text = String(chars[start..<end])
        }
        guard !text.isEmpty,
              text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("ftp://") || text.contains("@")
        else {
            beepIfEnabled()
            return
        }
        copyToPasteboard(text)
    }

    @objc func selectAllBetweenMatchingBraces(_ sender: Any?) {
        let currentLocation = editorSurface.selectedRange.location
        let nsText = editorSurface.text as NSString

        // Try to find brace at caret position and one before
        var braceA: Int?
        var braceB: Int?

        if let match = editorSurface.braceMatchPosition(from: currentLocation) {
            braceA = currentLocation
            braceB = match
        } else if currentLocation > 0,
                  let match = editorSurface.braceMatchPosition(from: currentLocation - 1) {
            braceA = currentLocation - 1
            braceB = match
        }

        guard let a = braceA, let b = braceB, a != b else {
            beepIfEnabled()
            return
        }

        // Determine opening and closing brace positions
        let charAtA = a < nsText.length ? nsText.substring(with: NSRange(location: a, length: 1)) : ""
        let openPos: Int
        let closePos: Int
        if "({[".contains(charAtA) {
            openPos = a
            closePos = b
        } else {
            openPos = b
            closePos = a
        }

        // Select content between the braces (excluding the braces themselves)
        let selectStart = openPos + 1
        let selectEnd = closePos
        guard selectStart <= selectEnd, selectEnd <= nsText.length else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(NSRange(location: selectStart, length: selectEnd - selectStart))
        updateStatus()
    }

    @objc func increaseLineIndent(_ sender: Any?) {
        let tabSize = preferencesStore.load().tabSize
        let nsText = editorSurface.text as NSString
        let lineRange = selectedLineRange()
        let indent = String(repeating: " ", count: tabSize)
        var result = nsText as String
        var offset = 0
        for line in lineRange {
            let lineStart = selectionRange(forLine: line).location
            let insertAt = lineStart + offset
            guard insertAt <= (result as NSString).length else { continue }
            let nsResult = result as NSString
            result = nsResult.replacingCharacters(
                in: NSRange(location: insertAt, length: 0),
                with: indent
            )
            offset += tabSize
        }
        let caretOffset = editorSurface.selectedRange.location + tabSize
        applyEditedText(result, selectedRange: NSRange(location: caretOffset, length: 0))
    }

    @objc func decreaseLineIndent(_ sender: Any?) {
        let tabSize = preferencesStore.load().tabSize
        let nsText = editorSurface.text as NSString
        let lineRange = selectedLineRange()
        var result = nsText as String
        var offset = 0
        for line in lineRange {
            let lineStart = selectionRange(forLine: line).location
            let adjustedStart = lineStart - offset
            guard adjustedStart >= 0, adjustedStart <= (result as NSString).length else { continue }
            let nsResult = result as NSString
            let lineEndRange = nsResult.lineRange(for: NSRange(location: adjustedStart, length: 0))
            let lineText = nsResult.substring(with: lineEndRange)
            let leadingSpaces = lineText.prefix(while: { $0 == " " }).count
            let removeCount = min(leadingSpaces, tabSize)
            guard removeCount > 0 else { continue }
            result = nsResult.replacingCharacters(
                in: NSRange(location: adjustedStart, length: removeCount),
                with: ""
            )
            offset += removeCount
        }
        let caretOffset = max(0, editorSurface.selectedRange.location - min(tabSize, offset))
        applyEditedText(result, selectedRange: NSRange(location: caretOffset, length: 0))
    }

    @objc func setAndFindNext(_ sender: Any?) {
        let selectedRange = editorSurface.selectedRange
        guard selectedRange.length > 0 else { return }
        let nsText = editorSurface.text as NSString
        let query = nsText.substring(with: selectedRange)
        let options = preferencesStore.load().searchOptions
        guard let nextRange = TextSearch.findNext(
            query,
            in: editorSurface.text,
            from: NSRange(location: selectedRange.location + selectedRange.length, length: 0),
            options: options
        ) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(nextRange)
        updateStatus()
    }

    @objc func setAndFindPrevious(_ sender: Any?) {
        let selectedRange = editorSurface.selectedRange
        guard selectedRange.length > 0 else { return }
        let nsText = editorSurface.text as NSString
        let query = nsText.substring(with: selectedRange)
        var options = preferencesStore.load().searchOptions
        options.direction = .up
        guard let prevRange = TextSearch.findNext(
            query,
            in: editorSurface.text,
            from: NSRange(location: selectedRange.location, length: 0),
            options: options
        ) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(prevRange)
        updateStatus()
    }

    @objc func volatileFindNext(_ sender: Any?) {
        guard let query = lastFindQuery, !query.isEmpty else {
            beepIfEnabled()
            return
        }
        let options = preferencesStore.load().searchOptions
        guard let range = TextSearch.findNext(
            query,
            in: editorSurface.text,
            from: NSRange(location: editorSurface.selectedRange.location + editorSurface.selectedRange.length, length: 0),
            options: options
        ) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
    }

    @objc func volatileFindPrevious(_ sender: Any?) {
        guard let query = lastFindQuery, !query.isEmpty else {
            beepIfEnabled()
            return
        }
        var options = preferencesStore.load().searchOptions
        options.direction = .up
        guard let range = TextSearch.findNext(
            query,
            in: editorSurface.text,
            from: NSRange(location: editorSurface.selectedRange.location, length: 0),
            options: options
        ) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
    }

    @objc func toggleFoldAtCurrentLine(_ sender: Any?) {
        editorSurface.toggleFoldAtCurrentLine()
        updateStatus()
        onSessionStateChange?()
    }

    @objc func foldAll(_ sender: Any?) {
        editorSurface.foldAll()
        updateStatus()
        onSessionStateChange?()
    }

    @objc func unfoldAll(_ sender: Any?) {
        editorSurface.unfoldAll()
        updateStatus()
        onSessionStateChange?()
    }

    @objc func foldAtLevel(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let level = menuItem.representedObject as? Int
        else { return }
        editorSurface.foldAtLevel(level)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func unfoldAtLevel(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let level = menuItem.representedObject as? Int
        else { return }
        editorSurface.unfoldAtLevel(level)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func foldCurrentLevel(_ sender: Any?) {
        guard editorSurface.supportsFolding else { return }
        let currentLevel = editorSurface.foldLevelAtCaret()
        guard currentLevel > 0 else { return }
        editorSurface.foldAtLevel(currentLevel)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func unfoldCurrentLevel(_ sender: Any?) {
        guard editorSurface.supportsFolding else { return }
        let currentLevel = editorSurface.foldLevelAtCaret()
        guard currentLevel > 0 else { return }
        editorSurface.unfoldAtLevel(currentLevel)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func hideSelectedLines(_ sender: Any?) {
        let lineRange = selectedLineRange()
        editorSurface.hideLines(lineRange)
        updateStatus()
    }

    @objc func showAllHiddenLines(_ sender: Any?) {
        editorSurface.showAllHiddenLines()
        updateStatus()
    }

    @objc func cutMarkedLines(_ sender: Any?) {
        guard !bookmarks.isEmpty else { return }
        let nsText = editorSurface.text as NSString
        let lines = markedLineTexts(in: nsText, bookmarks: bookmarks)
        let lineRanges = markedLineRanges(in: nsText, bookmarks: bookmarks)
        copyToPasteboard(lines.joined(separator: "\n"))
        removeLines(at: lineRanges, in: nsText)
    }

    @objc func copyMarkedLines(_ sender: Any?) {
        guard !bookmarks.isEmpty else { return }
        let nsText = editorSurface.text as NSString
        let lines = markedLineTexts(in: nsText, bookmarks: bookmarks)
        copyToPasteboard(lines.joined(separator: "\n"))
    }

    @objc func pasteMarkedLines(_ sender: Any?) {
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              !clipboardText.isEmpty
        else { return }
        let nsText = editorSurface.text as NSString
        let lines = clipboardText.components(separatedBy: "\n")
        guard !lines.isEmpty else { return }

        // Paste after the last marked line, or at the current position if no marks
        let targetLine: Int
        if let lastMarkedLine = bookmarks.sortedLines.last {
            targetLine = lastMarkedLine
        } else {
            targetLine = caretLocation().line
        }

        let insertLocation = endOfLine(targetLine, in: nsText)
        let insertion = "\n" + clipboardText
        let newRange = NSRange(location: insertLocation, length: 0)
        let nextText = nsText.replacingCharacters(in: newRange, with: insertion)
        let nextCaret = NSRange(location: insertLocation + (insertion as NSString).length, length: 0)
        applyEditedText(nextText, selectedRange: nextCaret)
    }

    @objc func deleteMarkedLines(_ sender: Any?) {
        guard !bookmarks.isEmpty else { return }
        let nsText = editorSurface.text as NSString
        let lineRanges = markedLineRanges(in: nsText, bookmarks: bookmarks)
        removeLines(at: lineRanges, in: nsText)
    }

    @objc func deleteUnmarkedLines(_ sender: Any?) {
        guard !bookmarks.isEmpty else { return }
        let lineCount = documentLineCount()
        var unmarkedLines: [Int] = []
        for line in 1...lineCount {
            if !bookmarks.contains(line: line) {
                unmarkedLines.append(line)
            }
        }
        guard !unmarkedLines.isEmpty else { return }
        let nsText = editorSurface.text as NSString
        let unmarkedBookmarks = BookmarkSet(lines: unmarkedLines)
        let lineRanges = markedLineRanges(in: nsText, bookmarks: unmarkedBookmarks)
        removeLines(at: lineRanges, in: nsText)
    }

    @objc func inverseBookmarkMarks(_ sender: Any?) {
        let lineCount = documentLineCount()
        var newLines: [Int] = []
        for line in 1...lineCount {
            if !bookmarks.contains(line: line) {
                newLines.append(line)
            }
        }
        bookmarks = BookmarkSet(lines: newLines)
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
        onSessionStateChange?()
    }

    // MARK: - Incremental Search

    @objc func showIncrementalSearch(_ sender: Any?) {
        incrementalSearchPanel.show()
    }

    // MARK: - Find Characters in Range

    @objc func showFindCharRangePanel(_ sender: Any?) {
        findCharRangePanel.show()
    }

    func findCharactersInRange(options: CharRangeSearchOptions) {
        let text = editorSurface.text
        let selection = editorSurface.selectedRange
        guard let matchRange = CharRangeFinder.findNext(in: text, from: selection, options: options) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(matchRange)
        updateStatus()
    }

    func performFindCharRange(options: CharRangeSearchOptions) -> Bool {
        findCharactersInRange(options: options)
        let selection = editorSurface.selectedRange
        return selection.length > 0 || options.direction == .up
    }

    func performFindCharRange(start: UInt32, end: UInt32) -> Bool {
        performFindCharRange(options: CharRangeSearchOptions(
            preset: .custom(UInt8(min(max(Int(start), 0), 255)), UInt8(min(max(Int(end), 0), 255)))
        ))
    }

    // MARK: - Select and Find

    @objc func selectAndFindNext(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        guard selection.length > 0 else {
            beepIfEnabled()
            return
        }
        let text = editorSurface.text
        let query = (text as NSString).substring(with: selection)
        lastFindQuery = query
        let options = TextSearch.Options(matchCase: true, wholeWord: false, wraps: true, direction: .down)
        let fromRange = NSRange(location: NSMaxRange(selection), length: 0)
        guard let range = TextSearch.findNext(query, in: text, from: fromRange, options: options) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
    }

    @objc func selectAndFindPrevious(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        guard selection.length > 0 else {
            beepIfEnabled()
            return
        }
        let text = editorSurface.text
        let query = (text as NSString).substring(with: selection)
        lastFindQuery = query
        let options = TextSearch.Options(matchCase: true, wholeWord: false, wraps: true, direction: .up)
        let fromRange = NSRange(location: selection.location, length: 0)
        guard let range = TextSearch.findNext(query, in: text, from: fromRange, options: options) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
    }

    // MARK: - Mark Style Operations

    @objc func markAllUsingStyle(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let style = menuItem.representedObject as? SearchMarkStyle
        else { return }
        let query = resolveFindQuery()
        guard !query.isEmpty else {
            beepIfEnabled()
            return
        }
        let options = TextSearch.Options(matchCase: false, wholeWord: false, wraps: false, direction: .down)
        let text = editorSurface.text
        let matches = TextSearch.findAll(query, in: text, options: options)
        guard !matches.isEmpty else {
            beepIfEnabled()
            return
        }
        editorSurface.markAllWithIndicator(style, ranges: matches)
        updateStatus()
    }

    @objc func markOneUsingStyle(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let style = menuItem.representedObject as? SearchMarkStyle
        else { return }
        let selection = editorSurface.selectedRange
        guard selection.length > 0 else {
            beepIfEnabled()
            return
        }
        editorSurface.markAllWithIndicator(style, ranges: [selection])
        updateStatus()
    }

    @objc func unmarkAllUsingStyle(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let style = menuItem.representedObject as? SearchMarkStyle
        else { return }
        editorSurface.clearSearchIndicator(style)
        updateStatus()
    }

    @objc func clearAllStyles(_ sender: Any?) {
        editorSurface.clearAllSearchIndicators()
        updateStatus()
    }

    /// Context-menu "Find All" — highlights every occurrence of the query.
    @objc func findAllInDocument(_ sender: Any?) {
        let query = resolveFindQuery()
        guard !query.isEmpty else {
            beepIfEnabled()
            return
        }
        let options = TextSearch.Options(matchCase: false, wholeWord: false, wraps: false, direction: .down)
        let text = editorSurface.text
        let matches = TextSearch.findAll(query, in: text, options: options)
        guard !matches.isEmpty else {
            beepIfEnabled()
            return
        }
        // Highlight all matches using style-1 mark indicator.
        editorSurface.markAllWithIndicator(.style1, ranges: matches)
        // Move caret to first match.
        editorSurface.setSelectedRange(matches[0])
        updateStatus()
    }

    /// Context-menu "Mark All" — marks every occurrence with style 1 indicator.
    @objc func markAllFromContextMenu(_ sender: Any?) {
        let query = resolveFindQuery()
        guard !query.isEmpty else {
            beepIfEnabled()
            return
        }
        let prefs = preferencesStore.load()
        let options = TextSearch.Options(matchCase: prefs.markAllMatchCase, wholeWord: prefs.markAllWholeWord, wraps: false, direction: .down)
        let text = editorSurface.text
        let matches = TextSearch.findAll(query, in: text, options: options)
        guard !matches.isEmpty else {
            beepIfEnabled()
            return
        }
        editorSurface.markAllWithIndicator(.style1, ranges: matches)
        updateStatus()
    }

    @objc func goToNextStyle(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let style = menuItem.representedObject as? SearchMarkStyle
        else { return }
        let position = NSMaxRange(editorSurface.selectedRange)
        guard let target = editorSurface.goToNextIndicator(style, fromPosition: position) else {
            beepIfEnabled()
            return
        }
        // Find the end of the indicator at the target position
        let ranges = editorSurface.indicatorRanges(style)
        if let matchRange = ranges.first(where: { $0.location == target }) {
            editorSurface.setSelectedRange(matchRange)
        } else {
            editorSurface.setSelectedRange(NSRange(location: target, length: 0))
        }
        updateStatus()
    }

    @objc func goToPreviousStyle(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let style = menuItem.representedObject as? SearchMarkStyle
        else { return }
        let position = editorSurface.selectedRange.location
        guard let target = editorSurface.goToPreviousIndicator(style, fromPosition: position) else {
            beepIfEnabled()
            return
        }
        let ranges = editorSurface.indicatorRanges(style)
        if let matchRange = ranges.first(where: { $0.location == target }) {
            editorSurface.setSelectedRange(matchRange)
        } else {
            editorSurface.setSelectedRange(NSRange(location: target, length: 0))
        }
        updateStatus()
    }

    @objc func copyStyledText(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let style = menuItem.representedObject as? SearchMarkStyle
        else { return }
        let ranges = editorSurface.indicatorRanges(style)
        guard !ranges.isEmpty else {
            beepIfEnabled()
            return
        }
        let text = editorSurface.text as NSString
        let styledText = ranges.map { text.substring(with: $0) }.joined(separator: "\n")
        copyToPasteboard(styledText)
    }

    @objc func copyAllStyledText(_ sender: Any?) {
        var allText: [String] = []
        let text = editorSurface.text as NSString
        for style in SearchMarkStyle.allCases {
            let ranges = editorSurface.indicatorRanges(style)
            for range in ranges {
                allText.append(text.substring(with: range))
            }
        }
        guard !allText.isEmpty else {
            beepIfEnabled()
            return
        }
        copyToPasteboard(allText.joined(separator: "\n"))
    }

    @objc func copyMarkedText(_ sender: Any?) {
        guard !bookmarks.isEmpty else {
            beepIfEnabled()
            return
        }
        let nsText = editorSurface.text as NSString
        let lines = markedLineTexts(in: nsText, bookmarks: bookmarks)
        copyToPasteboard(lines.joined(separator: "\n"))
    }

    @objc func deleteLinesNotContainingStyle(_ sender: Any?) {
        let nsText = editorSurface.text as NSString
        let lineCount = documentLineCount()
        guard lineCount > 0 else { return }

        // Collect line ranges for lines that have at least one indicator from any style
        var markedLines = Set<Int>()
        for style in SearchMarkStyle.allCases {
            for range in editorSurface.indicatorRanges(style) {
                // Map NSRange to line numbers
                let start = range.location
                let end = NSMaxRange(range)
                var pos = start
                while pos <= end {
                    let (line, _) = lineAndColumn(at: pos)
                    markedLines.insert(line)
                    if pos == end { break }
                    // Advance to next line
                    guard let lineRange = lineRange(line: line, in: nsText) else { break }
                    pos = NSMaxRange(lineRange)
                }
            }
        }
        guard !markedLines.isEmpty else {
            beepIfEnabled()
            return
        }

        // Delete lines NOT in markedLines (from bottom to top)
        var linesToDelete: [Int] = []
        for line in 1...lineCount {
            if !markedLines.contains(line) {
                linesToDelete.append(line)
            }
        }
        guard !linesToDelete.isEmpty else { return }
        let lineRangesForDeletion = markedLineRanges(in: nsText, bookmarks: BookmarkSet(lines: linesToDelete))
        removeLines(at: lineRangesForDeletion, in: nsText)
    }

    private func lineRange(line: Int, in text: NSString) -> NSRange? {
        guard line >= 1 else { return nil }
        let lines = text.components(separatedBy: "\n")
        guard line <= lines.count else { return nil }
        var offset = 0
        for i in 0..<(line - 1) {
            offset += (lines[i] as NSString).length + 1
        }
        let lineLen = (lines[line - 1] as NSString).length
        return NSRange(location: offset, length: lineLen)
    }

    // MARK: - Found Results Navigation

    @objc func goToNextFound(_ sender: Any?) {
        if let appDelegate = NSApp.delegate as? AppDelegate, appDelegate.navigateFoundResult(forward: true) {
            return
        }
        findPanel.findNextFromMenu()
    }

    @objc func goToPreviousFound(_ sender: Any?) {
        if let appDelegate = NSApp.delegate as? AppDelegate, appDelegate.navigateFoundResult(forward: false) {
            return
        }
        findPanel.findPreviousFromMenu()
    }

    @objc func focusFoundResults(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.showFoundResultsPanel()
    }

    // MARK: - Change History Navigation

    @objc func goToNextChangedLine(_ sender: Any?) {
        guard let line = editorSurface.nextChangedLine(from: editorSurface.currentLineNumber) else {
            beepIfEnabled()
            return
        }
        editorSurface.goToLine(line)
        updateStatus()
    }

    @objc func goToPreviousChangedLine(_ sender: Any?) {
        guard let line = editorSurface.previousChangedLine(from: editorSurface.currentLineNumber) else {
            beepIfEnabled()
            return
        }
        editorSurface.goToLine(line)
        updateStatus()
    }

    @objc func clearChangeHistory(_ sender: Any?) {
        editorSurface.clearChangeHistory()
        updateStatus()
    }

    // MARK: - Helper

    private func resolveFindQuery() -> String {
        let selection = editorSurface.selectedRange
        if selection.length > 0 {
            let text = editorSurface.text as NSString
            return text.substring(with: selection)
        }
        return lastFindQuery ?? ""
    }

    // MARK: - Multi-select Operations

    @objc func multiSelectAll(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        if selection.length == 0 {
            editorSurface.expandWordSelection()
        }
        editorSurface.multiSelectAddEach(matchCase: false, wholeWord: false)
        updateStatus()
    }

    @objc func multiSelectAllMatchCase(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        if selection.length == 0 {
            editorSurface.expandWordSelection()
        }
        editorSurface.multiSelectAddEach(matchCase: true, wholeWord: false)
        updateStatus()
    }

    @objc func multiSelectAllWholeWord(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        if selection.length == 0 {
            editorSurface.expandWordSelection()
        }
        editorSurface.multiSelectAddEach(matchCase: false, wholeWord: true)
        updateStatus()
    }

    @objc func multiSelectAllMatchCaseWholeWord(_ sender: Any?) {
        let selection = editorSurface.selectedRange
        if selection.length == 0 {
            editorSurface.expandWordSelection()
        }
        editorSurface.multiSelectAddEach(matchCase: true, wholeWord: true)
        updateStatus()
    }

    @objc func multiSelectNext(_ sender: Any?) {
        editorSurface.multiSelectAddNext(matchCase: false, wholeWord: false)
        updateStatus()
    }

    @objc func multiSelectNextMatchCase(_ sender: Any?) {
        editorSurface.multiSelectAddNext(matchCase: true, wholeWord: false)
        updateStatus()
    }

    @objc func multiSelectNextWholeWord(_ sender: Any?) {
        editorSurface.multiSelectAddNext(matchCase: false, wholeWord: true)
        updateStatus()
    }

    @objc func multiSelectNextMatchCaseWholeWord(_ sender: Any?) {
        editorSurface.multiSelectAddNext(matchCase: true, wholeWord: true)
        updateStatus()
    }

    @objc func multiSelectUndo(_ sender: Any?) {
        editorSurface.dropLastSelection()
        updateStatus()
    }

    @objc func multiSelectSkip(_ sender: Any?) {
        editorSurface.multiSelectSkip()
        updateStatus()
    }

    @objc func columnSelectionToMultiCursor(_ sender: Any?) {
        guard let rectSel = editorSurface.liveRectangularSelection else {
            beepIfEnabled()
            return
        }

        let text = editorSurface.text as NSString
        let len = text.length

        // Build per-line cursor positions from the rectangular selection
        let anchor = min(rectSel.anchorUTF16Location, rectSel.caretUTF16Location)
        let caret = max(rectSel.anchorUTF16Location, rectSel.caretUTF16Location)
        guard anchor <= len, caret <= len else { return }

        // Find lines between anchor and caret
        let topLine = lineAndColumn(at: anchor).line
        let bottomLine = lineAndColumn(at: caret).line
        let leftCol = min(
            lineAndColumn(at: anchor).column,
            lineAndColumn(at: caret).column
        )

        var cursorRanges: [NSRange] = []
        for line in topLine...bottomLine {
            let lineStart = lineStartLocation(line: line, in: text)
            let lineText = text.substring(with: text.lineRange(for: NSRange(location: lineStart, length: 0)))
            let col = min(leftCol - 1, (lineText as NSString).length)
            let cursorLoc = lineStart + col
            cursorRanges.append(NSRange(location: cursorLoc, length: 0))
        }

        guard !cursorRanges.isEmpty,
              editorSurface.applyDiscontiguousSelections(cursorRanges, mainSelectionIndex: 0)
        else {
            beepIfEnabled()
            return
        }
        updateStatus()
    }

    private func lineStartLocation(line: Int, in text: NSString) -> Int {
        guard line >= 1 else { return 0 }
        var loc = 0
        var currentLine = 1
        while currentLine < line, loc < text.length {
            let ch = text.character(at: loc)
            loc += 1
            if ch == 10 { // LF
                currentLine += 1
            } else if ch == 13 { // CR
                currentLine += 1
                if loc < text.length, text.character(at: loc) == 10 { loc += 1 } // CRLF
            }
        }
        return loc
    }

    @objc func increaseFontSize(_ sender: Any?) {
        let newSize = min(fontSize + 1, 32)
        fontSizeZoomDelta += newSize - fontSize
        fontSize = newSize
        applyFont()
        if zoomSyncToAllTabs { syncZoomToAllWindows() }
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        let newSize = max(fontSize - 1, 9)
        fontSizeZoomDelta += newSize - fontSize
        fontSize = newSize
        applyFont()
        if zoomSyncToAllTabs { syncZoomToAllWindows() }
    }

    private func syncZoomToAllWindows() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.syncZoomToAll(nil)
    }

    @objc func toggleAlwaysOnTop(_ sender: Any?) {
        presentationState = presentationState.toggledAlwaysOnTop()
        applyWindowPresentationState()
    }

    func setAlwaysOnTop(_ value: Bool) {
        if presentationState.isAlwaysOnTop != value {
            presentationState = presentationState.toggledAlwaysOnTop()
            applyWindowPresentationState()
        }
    }

    @objc func toggleFullScreenMode(_ sender: Any?) {
        guard let window else { return }
        WindowPresentationSupport.toggleFullScreen(using: window, sender: sender)
    }

    @objc func toggleDistractionFreeMode(_ sender: Any?) {
        presentationState = presentationState.toggledDistractionFree()
        applyWindowPresentationState()
    }

    @objc func togglePostItMode(_ sender: Any?) {
        presentationState = presentationState.toggledPostIt()
        applyWindowPresentationState()
    }

    @objc func launchInBrowser(_ sender: Any?) {
        if let url = fileURL {
            NSWorkspace.shared.open(url)
        } else {
            // Unsaved file: write to a temp file and open
            let tmpDir = FileManager.default.temporaryDirectory
            let tmpURL = tmpDir.appendingPathComponent("NotepadPreview.html")
            let content = editorSurface.text
            try? content.write(to: tmpURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tmpURL)
        }
    }

    @objc func setSyntaxLanguage(_ sender: Any?) {
        guard
            let item = sender as? NSMenuItem,
            let rawValue = item.representedObject as? String,
            let nextLanguage = languageCatalog.language(named: rawValue)
        else {
            return
        }
        language = nextLanguage
        cachedAutoCompletionCatalog = nil
        cachedAutoCompletionCatalogLanguage = nil
        applyTabSettingsForCurrentLanguage()
        highlight()
        updateStatus()
    }

    @objc func showGoToLinePanel(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = Localization.string(.searchGoToLine, default: "Go To Line...")
        let caret = caretLocation()
        alert.informativeText = String(
            format: Localization.string(.editorStatusPosition, default: "Ln %d, Col %d"),
            locale: Locale.current,
            caret.line,
            caret.column
        ) + Localization.string(.searchGoToLineHint, default: " (format: line or line:column)")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.placeholderString = "1 - \(documentLineCount())"
        inputField.stringValue = "\(caret.line)"
        inputField.selectText(nil)
        alert.accessoryView = inputField
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let input = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        let parts = input.split(separator: ":", maxSplits: 1)
        guard let line = Int(parts[0]), line >= 1, line <= documentLineCount() else { return }

        goToLine(line)

        // Move to specific column if provided
        if parts.count == 2, let col = Int(parts[1]), col > 1 {
            let currentSel = editorSurface.selectedRange
            let nsText = editorSurface.text as NSString
            let newLoc = min(currentSel.location + col - 1, nsText.length)
            editorSurface.setSelectedRange(NSRange(location: newLoc, length: 0))
            updateStatus()
        }
    }

    @objc func goToMatchingBrace(_ sender: Any?) {
        let currentLocation = editorSurface.selectedRange.location
        guard let matchLocation = editorSurface.braceMatchPosition(from: currentLocation) else {
            beepIfEnabled()
            return
        }
        editorSurface.setSelectedRange(NSRange(location: matchLocation + 1, length: 0))
        updateStatus()
    }

    @objc func selectToMatchingBrace(_ sender: Any?) {
        let currentLocation = editorSurface.selectedRange.location
        let nsText = editorSurface.text as NSString

        // Determine the brace position (current or one before)
        var braceLocation = currentLocation
        if braceLocation > 0 {
            let charBefore = nsText.substring(with: NSRange(location: braceLocation - 1, length: 1))
            if "([{)}]".contains(charBefore) {
                braceLocation = braceLocation - 1
            }
        }

        guard let matchLocation = editorSurface.braceMatchPosition(from: braceLocation) else {
            beepIfEnabled()
            return
        }

        let selectionStart = min(braceLocation, matchLocation)
        let selectionEnd = max(braceLocation, matchLocation) + 1
        editorSurface.setSelectedRange(NSRange(location: selectionStart, length: selectionEnd - selectionStart))
        updateStatus()
    }

    @objc func showFindInFilesPanel(_ sender: Any?) {
        findInFilesPanel.show()
    }

    func showFindInFilesPanel(searchRoot: URL) {
        findInFilesPanel.show(searchRoot: searchRoot)
    }

    func showFindInFilesPanel(fileURLs: [URL], title: String) {
        findInFilesPanel.show(fileURLs: fileURLs, title: title)
    }

    @objc func showFindPanel(_ sender: Any?) {
        findPanel.show()
    }

    @objc func findNext(_ sender: Any?) {
        findPanel.findNextFromMenu()
    }

    @objc func findPrevious(_ sender: Any?) {
        findPanel.findPreviousFromMenu()
    }

    @objc func showReplacePanel(_ sender: Any?) {
        findPanel.show(focusedOnReplace: true)
    }

    @objc func duplicateLineOrSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.duplicate(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func deleteLineOrSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.deleteCurrentLineOrSelection(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func moveLineUp(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.moveCurrentLineOrSelectionUp(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func moveLineDown(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.moveCurrentLineOrSelectionDown(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func joinSelectedLines(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.joinSelectedLines(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func removeEmptyLines(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.removeEmptyLines(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func removeBlankLines(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.removeBlankLines(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func removeDuplicateLines(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.removeDuplicateLines(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func removeConsecutiveDuplicateLines(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.removeConsecutiveDuplicateLines(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func sortLinesAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAscending(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func sortLinesDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesDescending(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func sortLinesCaseInsensitiveAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesCaseInsensitiveAscending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesCaseInsensitiveDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesCaseInsensitiveDescending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesLocaleAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesInLocaleAscending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesLocaleDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesInLocaleDescending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesIntegerAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAsIntegersAscending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesIntegerDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAsIntegersDescending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesDecimalCommaAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAsDecimalCommaAscending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesDecimalCommaDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAsDecimalCommaDescending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesDecimalDotAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAsDecimalDotAscending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesDecimalDotDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesAsDecimalDotDescending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func reverseLineOrder(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.reverseSelectedLines(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func randomizeLineOrder(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.randomizeSelectedLines(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesLengthAscending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesByLengthAscending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func sortLinesLengthDescending(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sortSelectedLinesByLengthDescending(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func uppercaseSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.uppercaseSelection(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func lowercaseSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.lowercaseSelection(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func invertSelectionCase(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.invertSelectionCase(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func properCaseSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.properCaseSelection(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func sentenceCaseSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.sentenceCaseSelection(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func randomCaseSelection(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.randomCaseSelection(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func insertDateTimeShort(_ sender: Any?) {
        replaceSelection(with: EditMenuSupport.dateTimeString(for: Date(), style: .short))
    }

    @objc func insertDateTimeLong(_ sender: Any?) {
        replaceSelection(with: EditMenuSupport.dateTimeString(for: Date(), style: .long))
    }

    @objc func insertDateTimeCustomized(_ sender: Any?) {
        let preferences = preferencesStore.load()
        replaceSelection(
            with: EditMenuSupport.dateTimeString(
                for: Date(),
                style: .custom(preferences.customDateTimeFormat)
            )
        )
    }

    @objc func copyCurrentFullPath(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        copyToPasteboard(EditMenuSupport.documentClipboardString(for: fileURL, mode: .fullPath))
    }

    @objc func copyCurrentFilename(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        copyToPasteboard(EditMenuSupport.documentClipboardString(for: fileURL, mode: .filename))
    }

    @objc func copyCurrentDirectoryPath(_ sender: Any?) {
        guard let fileURL else {
            presentMissingFeatureResource(Localization.string(.fileRequiresSavedDocument, default: "This command requires an already saved document."))
            return
        }
        copyToPasteboard(EditMenuSupport.documentClipboardString(for: fileURL, mode: .directoryPath))
    }

    // MARK: - Copy as HTML / RTF

    @objc func copySelectionAsHTML(_ sender: Any?) {
        let range = editorSurface.selectedRange
        guard range.length > 0 else { return }
        let segments = editorSurface.styledSegments(ofSelection: range)
        guard !segments.isEmpty else { return }

        let html = RichTextConversion.htmlFromSegments(segments)
        let plainText = segments.map(\.text).joined()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(html, forType: .html)
        pasteboard.setString(plainText, forType: .string)
    }

    @objc func copySelectionAsRTF(_ sender: Any?) {
        let range = editorSurface.selectedRange
        guard range.length > 0 else { return }
        let segments = editorSurface.styledSegments(ofSelection: range)
        guard !segments.isEmpty else { return }

        let rtf = RichTextConversion.rtfFromSegments(segments)
        let plainText = segments.map(\.text).joined()
        guard let rtfData = rtf.data(using: .ascii) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(rtfData, forType: .rtf)
        pasteboard.setString(plainText, forType: .string)
    }

    @objc func generateMD5SelectionIntoClipboard(_ sender: Any?) {
        copySelectionDigestToPasteboard(using: .md5)
    }

    @objc func generateSHA1SelectionIntoClipboard(_ sender: Any?) {
        copySelectionDigestToPasteboard(using: .sha1)
    }

    @objc func generateSHA256SelectionIntoClipboard(_ sender: Any?) {
        copySelectionDigestToPasteboard(using: .sha256)
    }

    @objc func generateSHA512SelectionIntoClipboard(_ sender: Any?) {
        copySelectionDigestToPasteboard(using: .sha512)
    }

    @objc func openSelectedFile(_ sender: Any?) {
        guard let target = currentSelectionTarget() else {
            presentMissingFeatureResource(
                Localization.string(
                    .editorMissingSelectionTarget,
                    default: "No file path or URL was found at the current selection."
                )
            )
            return
        }

        switch target {
        case let .web(url):
            if !NSWorkspace.shared.open(url) {
                presentMissingFeatureResource(url.absoluteString)
            }
        case let .file(url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                presentMissingFeatureResource(
                    Localization.string(
                        .editorMissingSelectionTarget,
                        default: "No file path or URL was found at the current selection."
                    )
                )
                return
            }
            if !NSWorkspace.shared.open(url) {
                presentMissingFeatureResource(url.path)
            }
        }
    }

    @objc func openSelectedContainingFolder(_ sender: Any?) {
        guard let target = currentSelectionTarget() else {
            presentMissingFeatureResource(
                Localization.string(
                    .editorMissingSelectionTarget,
                    default: "No file path or URL was found at the current selection."
                )
            )
            return
        }

        guard case let .file(url) = target else {
            presentMissingFeatureResource(
                Localization.string(
                    .editorSelectionTargetNotFile,
                    default: "The current selection does not resolve to a file path."
                )
            )
            return
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                if !NSWorkspace.shared.open(url) {
                    presentMissingFeatureResource(url.path)
                }
                return
            }

            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        let parent = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            if !NSWorkspace.shared.open(parent) {
                presentMissingFeatureResource(parent.path)
            }
            return
        }

        presentMissingFeatureResource(
            Localization.string(
                .editorMissingSelectionFolder,
                default: "No containing folder could be resolved for the current selection."
            )
        )
    }

    @objc func searchOnInternet(_ sender: Any?) {
        do {
            let url = try EditMenuSupport.searchURL(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange,
                preferences: preferencesStore.load()
            )
            if !NSWorkspace.shared.open(url) {
                presentMissingFeatureResource(url.absoluteString)
            }
        } catch SearchURLBuilderError.missingQuery {
            presentMissingFeatureResource(
                Localization.string(
                    .editorMissingSearchQuery,
                    default: "No text was found to search for on the Internet."
                )
            )
        } catch {
            presentError(error)
        }
    }

    @objc func changeSearchEngine(_ sender: Any?) {
        NSApp.sendAction(#selector(AppDelegate.showPreferences(_:)), to: nil, from: self)
    }

    @objc func showCharacterPanel(_ sender: Any?) {
        EditMenuSupport.presentCharacterPanel(using: NSApp, sender: sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showClipboardHistoryPanel(_ sender: Any?) {
        clipboardHistoryPanel.show { [weak self] text in
            self?.replaceSelection(with: text)
        }
    }

    @objc func splitLines(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.splitLines(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func transposeLine(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.transposeLine(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func insertBlankLineAboveCurrentLine(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.insertBlankLineAboveCurrentLine(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func insertBlankLineBelowCurrentLine(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.insertBlankLineBelowCurrentLine(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func trimLeadingWhitespace(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.trimLeadingWhitespace(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func trimLeadingAndTrailingWhitespace(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.trimLeadingAndTrailingWhitespace(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func trimAll(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.trimAll(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func tabToSpaces(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.tabToSpaces(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func spaceToTabsLeading(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.spaceToTabsLeading(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func spaceToTabsAll(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.spaceToTabsAll(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange
            )
        )
    }

    @objc func eolToWhitespace(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.eolToWhitespace(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func trimTrailingWhitespace(_ sender: Any?) {
        applyEditCommandResult(
            TextEditCommands.trimTrailingWhitespace(in: editorSurface.text, selectedRange: editorSurface.selectedRange)
        )
    }

    @objc func toggleLineComment(_ sender: Any?) {
        guard let marker = language.lineComment, !marker.isEmpty else {
            presentMissingFeatureResource(
                String(
                    format: Localization.string(
                        .editorMissingLineComment,
                        default: "No line-comment marker is configured for %@."
                    ),
                    locale: Locale.current,
                    language.displayName
                )
            )
            return
        }

        let result = LineCommentEdit.toggle(
            in: editorSurface.text,
            selection: editorSurface.selectedRange,
            marker: marker
        )
        applyEditCommandResult(TextEditCommandResult(text: result.text, selectedRange: result.selectedRange))
    }

    @objc func setBlockComments(_ sender: Any?) {
        guard let markers = blockCommentMarkers() else { return }
        applyEditCommandResult(
            TextEditCommands.setBlockComments(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange,
                commentStart: markers.start,
                commentEnd: markers.end
            )
        )
    }

    @objc func removeBlockComments(_ sender: Any?) {
        guard let markers = blockCommentMarkers() else { return }
        applyEditCommandResult(
            TextEditCommands.removeBlockComments(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange,
                commentStart: markers.start,
                commentEnd: markers.end
            )
        )
    }

    @objc func streamComment(_ sender: Any?) {
        guard let markers = blockCommentMarkers() else { return }
        applyEditCommandResult(
            TextEditCommands.streamComment(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange,
                commentStart: markers.start,
                commentEnd: markers.end
            )
        )
    }

    @objc func streamUncomment(_ sender: Any?) {
        guard let markers = blockCommentMarkers() else { return }
        applyEditCommandResult(
            TextEditCommands.streamUncomment(
                in: editorSurface.text,
                selectedRange: editorSurface.selectedRange,
                commentStart: markers.start,
                commentEnd: markers.end
            )
        )
    }

    @objc func showAutoCompletion(_ sender: Any?) {
        guard let catalog = AutoCompletionCatalog.loadDefault(languageName: language.name) else {
            presentMissingFeatureResource(
                String(
                    format: Localization.string(
                        .editorMissingAutoCompletionAPI,
                        default: "No auto-completion API file is available for %@."
                    ),
                    locale: Locale.current,
                    language.displayName
                )
            )
            return
        }

        let prefix = currentCompletionPrefix(environment: catalog.environment)
        autoCompletionPanel.show(catalog: catalog, prefix: prefix, documentName: displayName) { [weak self] keyword in
            self?.insertCompletion(keyword.name, replacingPrefix: prefix)
        }
    }

    @objc func showCallTip(_ sender: Any?) {
        guard let catalog = AutoCompletionCatalog.loadDefault(languageName: language.name) else {
            presentMissingFeatureResource(
                String(
                    format: Localization.string(
                        .editorMissingAutoCompletionAPI,
                        default: "No auto-completion API file is available for %@."
                    ),
                    locale: Locale.current,
                    language.displayName
                )
            )
            return
        }

        guard let callTip = catalog.callTip(in: editorSurface.text, caretLocation: editorSurface.selectedRange.location) else {
            presentMissingFeatureResource(
                Localization.string(
                    .editorMissingActiveCall,
                    default: "No function call with API metadata is active at the insertion point."
                )
            )
            return
        }

        callTipPanel.show(
            callTip: callTip,
            languageDisplayName: catalog.languageDisplayName,
            documentName: displayName
        )
    }

    @objc func showFunctionList(_ sender: Any?) {
        guard let definition = FunctionListDefinition.loadDefault(languageName: language.name) else {
            presentMissingFeatureResource(
                String(
                    format: Localization.string(
                        .editorMissingFunctionList,
                        default: "No function-list definition is available for %@."
                    ),
                    locale: Locale.current,
                    language.displayName
                )
            )
            return
        }

        let symbols = FunctionListExtractor.extract(
            from: editorSurface.text,
            languageName: language.name,
            definition: definition
        )
        functionListPanel.show(
            symbols: symbols,
            languageDisplayName: definition.displayName,
            documentName: displayName
        ) { [weak self] symbol in
            self?.editorSurface.setSelectedRange(symbol.range)
            self?.updateStatus()
        }
    }

    /// View > Export Function List... — extract symbols and save to a text file.
    @objc func exportFunctionList(_ sender: Any?) {
        guard let definition = FunctionListDefinition.loadDefault(languageName: language.name) else {
            presentMissingFeatureResource(
                String(
                    format: Localization.string(
                        .editorMissingFunctionList,
                        default: "No function-list definition is available for %@."
                    ),
                    locale: Locale.current,
                    language.displayName
                )
            )
            return
        }

        let symbols = FunctionListExtractor.extract(
            from: editorSurface.text,
            languageName: language.name,
            definition: definition
        )

        guard !symbols.isEmpty else {
            presentMissingFeatureResource(
                "No functions found in this document."
            )
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = (displayName as NSString).deletingPathExtension + "_functions.txt"
        panel.beginSheetModal(for: window!) { response in
            guard response == .OK, let url = panel.url else { return }
            let lines = symbols.map { symbol in
                "\(symbol.line)\t\(symbol.kind.rawValue)\t\(symbol.name)"
            }
            let content = lines.joined(separator: "\n")
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.presentMissingFeatureResource(
                    String(format: "Failed to export function list: %@", error.localizedDescription)
                )
            }
        }
    }

    @objc func showTaskList(_ sender: Any?) {
        taskListPanel.show(
            documentName: displayName,
            text: editorSurface.text,
            customTagsPreference: preferencesStore.load().taskListCustomTags
        ) { [weak self] entry in
            self?.editorSurface.setSelectedRange(NSRange(location: entry.utf16Location, length: 0))
            self?.updateStatus()
        }
    }

    @objc func showDocumentMap(_ sender: Any?) {
        documentMapPanel.show(
            documentName: displayName,
            text: editorSurface.text,
            currentLine: caretLocation().line
        ) { [weak self] entry in
            self?.editorSurface.setSelectedRange(NSRange(location: entry.utf16Location, length: 0))
            self?.updateStatus()
        }
    }

    @objc func showDocumentStatistics(_ sender: Any?) {
        let text = editorSurface.text
        let summary = TextStatistics.summary(for: text)
        let selection = editorSurface.selectedRange
        let selSummary = selection.length > 0 ? TextStatistics.summary(for: (text as NSString).substring(with: selection)) : nil
        let byteCount = text.data(using: encoding)?.count ?? text.utf8.count
        let fileSizeStr: String
        if let url = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            fileSizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } else {
            fileSizeStr = "-"
        }

        var info = String(
            format: Localization.string(
                .statisticsSummary,
                default: "Document: %@\nLines: %d\nWords: %d\nUTF-16 characters: %d\nUnicode scalars: %d"
            ),
            locale: Locale.current,
            displayName,
            summary.lineCount,
            summary.wordCount,
            summary.utf16CharacterCount,
            summary.unicodeScalarCount
        )
        info += String(format: "\n%@ bytes (UTF-8)", byteCount)
        info += String(format: "\nFile size: %@", fileSizeStr)
        if let sel = selSummary {
            info += String(format: "\n\nSelection: %d chars, %d words, %d lines", sel.utf16CharacterCount, sel.wordCount, sel.lineCount)
        }

        let alert = NSAlert()
        alert.messageText = Localization.string(.statisticsPanelTitle, default: "Document Statistics")
        alert.informativeText = info
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    @objc func showCurrentFileAutoCompletion(_ sender: Any?) {
        // Extract words from current file and show as completion list
        let text = editorSurface.text
        let selection = editorSurface.selectedRange
        let nsText = text as NSString

        // Get current word prefix
        var prefixStart = min(selection.location, nsText.length)
        while prefixStart > 0 {
            let charRange = nsText.rangeOfComposedCharacterSequence(at: prefixStart - 1)
            let ch = nsText.substring(with: charRange)
            guard ch.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" }) else { break }
            prefixStart = charRange.location
        }
        let prefix = nsText.substring(with: NSRange(location: prefixStart, length: min(selection.location, nsText.length) - prefixStart))
        guard !prefix.isEmpty else { return }

        // Extract unique words from the document that start with the prefix
        let words = extractWords(from: text, matchingPrefix: prefix)
        guard !words.isEmpty else { return }

        // Insert first match via completion panel or inline
        autoCompletionPanel.showCurrentFileCompletions(
            words: words,
            prefix: prefix,
            documentName: displayName
        ) { [weak self] word in
            self?.insertCompletion(word, replacingPrefix: prefix)
        }
    }

    @objc func showPathAutoCompletion(_ sender: Any?) {
        // Extract file path under cursor and suggest completions
        let text = editorSurface.text
        let nsText = text as NSString
        let location = min(editorSurface.selectedRange.location, nsText.length)

        // Find path-like text around cursor (quoted strings or path-like sequences)
        var pathStart = location
        var pathEnd = location
        while pathStart > 0 {
            let charRange = nsText.rangeOfComposedCharacterSequence(at: pathStart - 1)
            let ch = nsText.substring(with: charRange)
            guard ch.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || "/._-~:".unicodeScalars.contains($0) }) else { break }
            pathStart = charRange.location
        }
        while pathEnd < nsText.length {
            let charRange = nsText.rangeOfComposedCharacterSequence(at: pathEnd)
            let ch = nsText.substring(with: charRange)
            guard ch.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || "/._-~:".unicodeScalars.contains($0) }) else { break }
            pathEnd = NSMaxRange(charRange)
        }

        guard pathEnd > pathStart else { return }
        let partialPath = nsText.substring(with: NSRange(location: pathStart, length: pathEnd - pathStart))

        // Expand tilde and suggest completions
        let expandedPath = NSString(string: partialPath).expandingTildeInPath
        let suggestions = pathCompletions(for: expandedPath)
        guard !suggestions.isEmpty else { return }

        autoCompletionPanel.showCurrentFileCompletions(
            words: suggestions,
            prefix: partialPath,
            documentName: displayName
        ) { [weak self] completion in
            guard let self else { return }
            let nsCurrent = self.editorSurface.text as NSString
            let currentLocation = min(self.editorSurface.selectedRange.location, nsCurrent.length)
            var start = currentLocation
            while start > 0 {
                let charRange = nsCurrent.rangeOfComposedCharacterSequence(at: start - 1)
                let ch = nsCurrent.substring(with: charRange)
                guard ch.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || "/._-~:".unicodeScalars.contains($0) }) else { break }
                start = charRange.location
            }
            let nextText = nsCurrent.replacingCharacters(
                in: NSRange(location: start, length: currentLocation - start),
                with: completion
            )
            self.applyEditedText(nextText, selectedRange: NSRange(location: start + (completion as NSString).length, length: 0))
        }
    }

    private func extractWords(from text: String, matchingPrefix prefix: String) -> [String] {
        let lowerPrefix = prefix.lowercased()
        let words = text
            .split { !$0.isLetter && $0 != "_" }
            .map(String.init)
            .filter { $0.count > prefix.count && $0.lowercased().hasPrefix(lowerPrefix) }
        // Return unique words, sorted by frequency
        var frequency: [String: Int] = [:]
        for word in words {
            frequency[word, default: 0] += 1
        }
        return frequency.keys.sorted { frequency[$0]! > frequency[$1]! }
    }

    private func pathCompletions(for partialPath: String) -> [String] {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        let directory: String
        let prefix: String

        if fileManager.fileExists(atPath: partialPath, isDirectory: &isDir) && isDir.boolValue {
            directory = partialPath
            prefix = ""
        } else {
            let lastSlash = partialPath.lastIndex(of: "/") ?? partialPath.startIndex
            directory = String(partialPath[...lastSlash])
            prefix = String(partialPath[partialPath.index(after: lastSlash)...])
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return [] }
        let filtered = prefix.isEmpty ? contents : contents.filter { $0.hasPrefix(prefix) }
        return filtered.map { directory + $0 }.sorted()
    }

    @objc func showColumnEditor(_ sender: Any?) {
        let lineRange = selectedLineRange()
        let column = lineAndColumn(at: editorSurface.selectedRange.location).column
        columnEditorPanel.show(lineRange: lineRange, column: column) { [weak self] operation, column in
            self?.performColumnEdit(operation, lineRange: lineRange, column: column)
        }
    }

    @objc func showRectangularSelectionPanel(_ sender: Any?) {
        do {
            let text = editorSurface.text
            let context: RectangularSelectionContext
            if let liveRectangularSelection = editorSurface.liveRectangularSelection {
                context = try RectangularSelection.context(
                    in: text,
                    liveSelection: liveRectangularSelection
                )
            } else {
                context = try RectangularSelection.context(
                    in: text,
                    selectedRange: editorSurface.selectedRange
                )
            }
            rectangularSelectionPanel.show(
                lineRange: context.lineRange,
                column: context.startColumn,
                endColumn: context.endColumn,
                blockText: context.blockText,
                prefersReplaceMode: !context.selectedBlock.isEmpty
            ) { [weak self] operation in
                self?.performRectangularSelectionEdit(
                    operation,
                    lineRange: context.lineRange,
                    column: context.startColumn
                )
            }
        } catch {
            presentError(error)
        }
    }

    @objc func toggleBookmark(_ sender: Any?) {
        toggleBookmark(line: caretLocation().line)
    }

    private func toggleBookmark(line: Int) {
        bookmarks = bookmarks.toggling(line: line).clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func nextBookmark(_ sender: Any?) {
        guard let line = bookmarks.next(after: caretLocation().line) else { return }
        goToLine(line)
    }

    @objc func previousBookmark(_ sender: Any?) {
        guard let line = bookmarks.previous(before: caretLocation().line) else { return }
        goToLine(line)
    }

    @objc func clearBookmarks(_ sender: Any?) {
        bookmarks = bookmarks.clearing()
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func inverseBookmarks(_ sender: Any?) {
        let total = documentLineCount()
        var newSet = BookmarkSet()
        for line in 1...max(1, total) where !bookmarks.contains(line: line) {
            newSet = newSet.toggling(line: line)
        }
        bookmarks = newSet.clamped(toLineCount: total)
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
        onSessionStateChange?()
    }

    @objc func startMacroRecording(_ sender: Any?) {
        activeMacroRecording = MacroRecording(name: MacroDisplayNames.placeholderRecordingName)
        macroBaselineText = editorSurface.text
        updateStatus()
    }

    @objc func stopMacroRecording(_ sender: Any?) {
        guard let recording = activeMacroRecording else { return }

        macroStore.saveLastRecording(recording)
        activeMacroRecording = nil
        macroBaselineText = nil
        updateStatus()
    }

    @objc func playLastMacro(_ sender: Any?) {
        guard let recording = macroStore.loadLastRecording(),
              !recording.commands.isEmpty
        else {
            return
        }

        replayMacro(recording)
    }

    @objc func saveLastMacroAsNamedMacro(_ sender: Any?) {
        guard let recording = macroStore.loadLastRecording(),
              !recording.commands.isEmpty
        else {
            return
        }

        let alert = NSAlert()
        alert.messageText = Localization.string(.macroSavePanelTitle, default: "Save Last Macro")
        alert.informativeText = Localization.string(
            .macroSavePanelMessage,
            default: "Name this recorded macro so it can be replayed later."
        )
        alert.addButton(withTitle: Localization.string(.macroSavePanelSave, default: "Save"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        nameField.placeholderString = Localization.string(.macroSavePanelPlaceholder, default: "Macro name")
        nameField.stringValue = MacroDisplayNames.editableName(for: recording.name)
        alert.accessoryView = nameField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        macroStore.saveNamedRecording(MacroRecording(name: name, commands: recording.commands))
        updateStatus()
        (NSApp.delegate as? AppDelegate)?.refreshMacroMenu()
    }

    @objc func playNamedMacro(_ sender: Any?) {
        guard let recording = chooseNamedMacro(
            title: Localization.string(.macroPlayPanelTitle, default: "Play Saved Macro"),
            message: Localization.string(
                .macroPlayPanelMessage,
                default: "Choose a saved macro to replay in the current document."
            ),
            actionTitle: Localization.string(.macroPlayPanelPlay, default: "Play")
        ) else {
            return
        }

        replayMacro(recording)
    }

    /// Returns all named macros from this editor's macro store (for menu/shortcut display).
    func namedMacros() -> [MacroRecording] {
        macroStore.loadNamedRecordings()
    }

    /// Plays a named macro by name; used by the dynamic macro menu.
    func playNamedMacroByName(_ name: String) {
        guard let recording = macroStore.loadNamedRecording(named: name) else { return }
        replayMacro(recording)
    }

    @objc func deleteNamedMacro(_ sender: Any?) {
        guard let recording = chooseNamedMacro(
            title: Localization.string(.macroDeletePanelTitle, default: "Delete Saved Macro"),
            message: Localization.string(.macroDeletePanelMessage, default: "Choose a saved macro to remove."),
            actionTitle: Localization.string(.macroDeletePanelDelete, default: "Delete")
        ) else {
            return
        }

        macroStore.deleteNamedRecording(named: recording.name)
        updateStatus()
        (NSApp.delegate as? AppDelegate)?.refreshMacroMenu()
    }

    @objc func clearLastMacro(_ sender: Any?) {
        macroStore.clearLastRecording()
        activeMacroRecording = nil
        macroBaselineText = nil
        updateStatus()
    }

    @objc func runMacroMultipleTimes(_ sender: Any?) {
        guard let recording = macroStore.loadLastRecording() else {
            beepIfEnabled()
            return
        }

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        textField.stringValue = "1"
        textField.formatter = {
            let f = NumberFormatter()
            f.minimum = 1
            f.maximum = 100000
            f.allowsFloats = false
            return f
        }()

        let alert = NSAlert()
        alert.messageText = Localization.string(.macroRunTimesTitle, default: "Run Macro")
        alert.informativeText = Localization.string(.macroRunTimesMessage, default: "Number of times to run the macro:")
        alert.accessoryView = textField
        alert.addButton(withTitle: Localization.string(.macroRunTimesRun, default: "Run"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let count = max(1, min(100000, Int(textField.intValue)))

        for _ in 0..<count {
            replayMacro(recording)
        }
    }

    private func replayMacro(_ recording: MacroRecording) {
        guard let replayedText = recording.replaying(on: editorSurface.text) else {
            presentMacroReplayError()
            return
        }

        isReplayingMacro = true
        defer { isReplayingMacro = false }
        let selectedRange = NSRange(location: (replayedText as NSString).length, length: 0)
        applyEditedText(replayedText, selectedRange: selectedRange)
    }

    private func chooseNamedMacro(title: String, message: String, actionTitle: String) -> MacroRecording? {
        let recordings = macroStore.loadNamedRecordings()
        guard !recordings.isEmpty else { return nil }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
        popup.addItems(withTitles: recordings.map(\.name))

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = popup
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let selectedIndex = popup.indexOfSelectedItem
        guard recordings.indices.contains(selectedIndex) else { return nil }
        return recordings[selectedIndex]
    }

    func performFind(query: String, options: TextSearch.Options) -> Bool {
        lastFindQuery = query.isEmpty ? nil : query
        guard let range = TextSearch.findNext(query, in: editorSurface.text, from: editorSurface.selectedRange, options: options) else {
            return false
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
        return true
    }

    func performReplace(query: String, replacement: String, options: TextSearch.Options) -> Bool {
        let currentSelection = editorSurface.selectedRange
        guard let result = TextSearch.replaceNext(query, with: replacement, in: editorSurface.text, from: currentSelection, options: options) else {
            return false
        }
        let postSelection: NSRange
        if preferencesStore.load().replaceDoesNotMove {
            // Keep caret at the original position (not the replaced range)
            let adjustedLoc = min(currentSelection.location, (result.text as NSString).length)
            postSelection = NSRange(location: adjustedLoc, length: 0)
        } else {
            postSelection = result.replacedRange
        }
        applyEditedText(result.text, selectedRange: postSelection)
        return true
    }

    func performReplaceAll(query: String, replacement: String, options: TextSearch.Options) -> Int {
        let result = TextSearch.replaceAll(query, with: replacement, in: editorSurface.text, options: options)
        guard result.count > 0 else { return 0 }
        applyEditedText(result.text, selectedRange: NSRange(location: 0, length: 0))
        return result.count
    }

    func performBookmarkAllMatches(query: String, options: TextSearch.Options) -> (matchCount: Int, lineCount: Int) {
        let text = editorSurface.text
        let matches = TextSearch.findAll(query, in: text, options: options)
        guard !matches.isEmpty else { return (0, 0) }

        let matchingLines = BookmarkSet.linesContainingSearchMatches(matches, in: text)
        bookmarks = bookmarks.adding(lines: matchingLines).clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
        onSessionStateChange?()
        return (matches.count, matchingLines.count)
    }

    /// Search > Bookmark > Bookmark All Matches — bookmarks every line containing a match.
    @objc func bookmarkAllMatchesFromMenu(_ sender: Any?) {
        let query = resolveFindQuery()
        guard !query.isEmpty else {
            beepIfEnabled()
            return
        }
        let options = TextSearch.Options(matchCase: false, wholeWord: false, wraps: false, direction: .down)
        let result = performBookmarkAllMatches(query: query, options: options)
        guard result.matchCount > 0 else {
            beepIfEnabled()
            return
        }
    }

    func performIncrementalFind(query: String) -> Bool {
        editorSurface.hideIncrementalHighlight()
        guard !query.isEmpty else { return false }
        let text = editorSurface.text
        let fromRange = NSRange(location: editorSurface.selectedRange.location, length: 0)
        let options = TextSearch.Options(matchCase: false, wholeWord: false, wraps: true, direction: .down)
        guard let range = TextSearch.findNext(query, in: text, from: fromRange, options: options) else {
            return false
        }
        editorSurface.setSelectedRange(range)
        editorSurface.showIncrementalHighlight(range: range)
        updateStatus()
        return true
    }

    func clearIncrementalHighlight() {
        editorSurface.hideIncrementalHighlight()
    }

    func applyPreferences(_ preferences: AppPreferences) {
        fontSize = CGFloat(preferences.editorFontSize) + fontSizeZoomDelta
        wrapsLines = preferences.wrapsLines
        whitespaceMode = WhitespaceDisplayMode(rawValue: preferences.whitespaceDisplayMode) ?? .invisible
        showsEOL = preferences.showEOL
        showsIndentGuides = preferences.showIndentGuides
        highlightsCurrentLine = preferences.highlightCurrentLine
        showsWrapSymbol = preferences.showWrapSymbol
        showsChangeHistory = preferences.showChangeHistory
        showsLineNumberMargin = preferences.showLineNumberMargin
        showsBookmarkMargin = preferences.showBookmarkMargin
        showsEdgeLine = preferences.showEdgeLine
        edgeLineColumn = preferences.edgeLineColumn
        enablesAutoPair = preferences.enableAutoPair
        autoPairParentheses = preferences.autoPairParentheses
        autoPairBrackets = preferences.autoPairBrackets
        autoPairCurlyBrackets = preferences.autoPairCurlyBrackets
        autoPairSingleQuotes = preferences.autoPairSingleQuotes
        autoPairDoubleQuotes = preferences.autoPairDoubleQuotes
        enablesXmlTagMatch = preferences.enableXmlTagMatch
        htmlXmlCloseTagEnabled = preferences.htmlXmlCloseTagEnabled
        enablesClickableLinks = preferences.enableClickableLinks
        showsNpcCharacters = preferences.showNpcCharacters
        caretWidth = preferences.caretWidth
        caretNoBlink = preferences.caretNoBlink
        caretBlinkRate = preferences.caretBlinkRate
        currentLineFrameWidth = preferences.currentLineFrameWidth
        lineWrapIndent = preferences.lineWrapIndent
        foldMarginStyle = preferences.foldMarginStyle
        useFirstLineAsTabName = preferences.useFirstLineAsTabName
        autoReloadOnExternalChange = preferences.autoReloadOnExternalChange
        fileChangeDetectionEnabled = preferences.fileChangeDetectionEnabled
        reloadScrollToLastCaret = preferences.reloadScrollToLastCaret
        editorFontName = preferences.editorFontName
        editorFontBold = preferences.editorFontBold
        backupOnSaveMode = preferences.backupOnSaveMode
        useCustomBackupDirectory = preferences.useCustomBackupDirectory
        customBackupDirectory = preferences.customBackupDirectory
        additionalEdgeColumns = preferences.additionalEdgeColumns
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        linePadding = preferences.linePadding
        enableVirtualSpace = preferences.enableVirtualSpace
        backspaceUnindents = preferences.backspaceUnindents
        autoIndent = preferences.autoIndent
        autoIndentMode = preferences.autoIndentMode
        fileAutoDetection = preferences.fileAutoDetection
        updateSilently = preferences.updateSilently
        scrollBeyondLastLine = preferences.scrollBeyondLastLine
        selectedTextDragDrop = preferences.selectedTextDragDrop
        lineNumberDynamicWidth = preferences.lineNumberDynamicWidth
        columnSelectionToMultiEditing = preferences.columnSelectionToMultiEditing
        muteAllSounds = preferences.muteAllSounds
        zoomSyncToAllTabs = preferences.zoomSyncToAllTabs
        hideMenuShortcuts = preferences.hideMenuShortcuts
        scrollToLastLineOnMonitorReload = preferences.scrollToLastLineOnMonitorReload
        trimTrailingSpacesOnSave = preferences.trimTrailingSpacesOnSave
        pasteConvertEndings = preferences.pasteConvertEndings
        caretStickyMode = preferences.caretStickyMode
        enableCodeFolding = preferences.enableCodeFolding
        autoCompleteIgnoreCase = preferences.autoCompleteIgnoreCase
        smoothFont = preferences.smoothFont
        multiEditEnabled = preferences.multiEditEnabled
        multiPasteMode = preferences.multiPasteMode
        indentGuideMode = preferences.indentGuideMode
        wordWrapMode = preferences.wordWrapMode
        additionalSelAlpha = preferences.additionalSelAlpha
        additionalCaretsBlink = preferences.additionalCaretsBlink
        additionalCaretsVisible = preferences.additionalCaretsVisible
        caretLineVisibleAlways = preferences.caretLineVisibleAlways
        whitespaceSize = preferences.whitespaceSize
        selectionAlpha = preferences.selectionAlpha
        controlCharDisplay = preferences.controlCharDisplay
        currentBidiMode = preferences.bidiMode
        autoCompleteFromNthChar = preferences.autoCompleteFromNthChar
        autoCompleteMode = preferences.autoCompleteMode
        autoCompleteChooseSingle = preferences.autoCompleteChooseSingle
        autoCompleteTABFillup = preferences.autoCompleteTABFillup
        autoCompleteEnterCommit = preferences.autoCompleteEnterCommit
        autoCompleteBrief = preferences.autoCompleteBrief
        customMatchedPairs = preferences.customMatchedPairs
        if cachedAutoCompletionCatalogLanguage != language.name {
            cachedAutoCompletionCatalog = nil
            cachedAutoCompletionCatalogLanguage = nil
        }
        smartHighlightMatchCase = preferences.smartHighlightUseFindSettings
            ? preferences.searchMatchCase
            : preferences.smartHighlightMatchCase
        smartHighlightWholeWord = preferences.smartHighlightUseFindSettings
            ? preferences.searchWholeWord
            : preferences.smartHighlightWholeWord
        presentationState.postItAlpha = CGFloat(preferences.postItAlpha)
        showsStatusBar = preferences.statusBarVisible
        applyFont()
        applyLineWrapping()
        applyTabSettings(preferences.tabSize, insertSpaces: preferences.insertSpacesInsteadOfTabs)
        applyAdvancedViewOptions()
        editorSurface.applyLineNumberMargin(showsLineNumberMargin)
        editorSurface.applyBookmarkMarginVisible(showsBookmarkMargin)
        editorSurface.applyEdgeLine(showsEdgeLine, column: edgeLineColumn)
        editorSurface.applyAutoCompleteChooseSingle(autoCompleteChooseSingle)
        editorSurface.applyAutoCompleteTABFillup(autoCompleteTABFillup)
        editorSurface.applyAutoCompleteEnterCommit(autoCompleteEnterCommit)
        editorSurface.applyAutoCompleteBrief(autoCompleteBrief)
        editorSurface.applyAutoCompleteIgnoreCase(autoCompleteIgnoreCase)
        editorSurface.applySmoothFont(smoothFont)
        editorSurface.applyMultiEditEnabled(multiEditEnabled)
        editorSurface.applyMultiPasteMode(multiPasteMode)
        editorSurface.applyAdditionalSelAlpha(additionalSelAlpha)
        editorSurface.applyAdditionalCaretsBlink(additionalCaretsBlink)
        editorSurface.applyAdditionalCaretsVisible(additionalCaretsVisible)
        editorSurface.applyCaretLineVisibleAlways(caretLineVisibleAlways)
        editorSurface.applyWhitespaceSize(whitespaceSize)
        editorSurface.applySelectionAlpha(selectionAlpha)
        editorSurface.applyControlCharDisplay(controlCharDisplay)
        editorSurface.applyBidirectional(currentBidiMode)
        editorSurface.applyCopyLineWithoutSelection(preferences.copyLineWithoutSelection)
        editorSurface.applyScintillaKeyRemaps(scintillaKeyMapStore.load())
        tabBarView.doubleClickClosesTab = preferences.tabbarDoubleClickClose
        tabBarView.lockDragDrop = preferences.tabbarLockDragDrop
        tabBarView.tabMaxLabelLength = preferences.tabbarMaxLabelLength
        tabBarView.showCloseButton = preferences.tabbarShowCloseButton
        tabBarView.compactMode = preferences.tabbarCompact
        tabBarView.showIndexNumbers = preferences.tabbarShowIndexNumbers
        applyTabBarVisibility(!preferences.tabbarHide)
        configureAutoPair()
        configureUrlHighlight()
    }

    func applyTabBarVisibility(_ visible: Bool) {
        tabBarHeightConstraint?.constant = visible ? tabBarView.currentBarHeight : 0
        tabBarView.isHidden = !visible
    }

    @objc func toggleTabBarVisibility(_ sender: Any?) {
        var prefs = preferencesStore.load()
        prefs = prefs.withTabbarHide(!prefs.tabbarHide)
        preferencesStore.save(prefs)
        applyTabBarVisibility(!prefs.tabbarHide)
    }

    func reapplyScintillaKeyRemaps() {
        editorSurface.applyScintillaKeyRemaps(scintillaKeyMapStore.load())
    }

    func applyTabContextMenuSpec(_ spec: TabContextMenuSpec?) {
        tabBarView.tabContextMenuSpec = spec
    }

    func applyStylePreferences(_ preferences: StylePreferences) {
        stylePreferences = preferences
        highlight()
    }

    func applyStyleCatalog(_ catalog: StyleCatalog) {
        styleCatalog = catalog
        highlight()
    }

    func applyLanguageCatalog(_ catalog: LanguageCatalog) {
        languageCatalog = catalog
        language = catalog.language(named: language.name)
            ?? LanguageDetector.detect(url: fileURL, in: catalog)
        highlight()
        updateStatus()
    }

    func setLanguage(named name: String) {
        guard !name.isEmpty,
              let lang = languageCatalog.language(named: name)
        else { return }
        language = lang
        applyTabSettingsForCurrentLanguage()
        highlight()
        updateStatus()
    }

    func makeSnapshotDraft() -> DocumentSnapshotDraft? {
        guard isDirty else { return nil }
        return DocumentSnapshotDraft(
            id: snapshotID,
            displayName: displayName,
            originalFile: fileURL,
            text: editorSurface.text,
            encoding: encoding,
            lineEnding: lineEnding,
            preservesByteOrderMark: savePolicy.includeByteOrderMark(for: encoding)
        )
    }

    func markSnapshotSaved(_ snapshot: DocumentSnapshot) {
        snapshotID = snapshot.id
    }

    func restoreBookmarks(_ restoredBookmarks: BookmarkSet) {
        bookmarks = restoredBookmarks.clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
    }

    func restoreFolds(_ restoredFolds: FoldState) {
        editorSurface.applyFoldState(restoredFolds.clamped(toLineCount: documentLineCount()))
        updateStatus()
    }

    func restoreCaretPosition(_ utf16Location: Int) {
        let text = editorSurface.text as NSString
        let clamped = min(utf16Location, text.length)
        let range = NSRange(location: clamped, length: 0)
        editorSurface.setSelectedRange(range)
        editorSurface.scrollToSelection()
        updateStatus()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(setSyntaxLanguage(_:)),
           let rawValue = menuItem.representedObject as? String {
            menuItem.state = rawValue == language.name ? .on : .off
        }
        if menuItem.action == #selector(convertEncoding(_:)),
           let rawValue = menuItem.representedObject as? String,
           let option = TextEncodingOption(rawValue: rawValue) {
            menuItem.state = option.encoding == encoding ? .on : .off
        }
        if menuItem.action == #selector(encodeInEncoding(_:)),
           let rawValue = menuItem.representedObject as? String,
           let option = TextEncodingOption(rawValue: rawValue) {
            menuItem.state = option.encoding == encoding ? .on : .off
        }
        if menuItem.action == #selector(convertLineEnding(_:)),
           let rawValue = menuItem.representedObject as? String,
           let itemLineEnding = LineEnding(rawValue: rawValue) {
            menuItem.state = itemLineEnding == lineEnding ? .on : .off
        }

        switch menuItem.action {
        case #selector(toggleBookmark(_:)):
            menuItem.state = bookmarks.contains(line: caretLocation().line) ? .on : .off
            return true
        case #selector(saveCopyAs(_:)),
            #selector(reloadFromDisk(_:)),
            #selector(openContainingFolder(_:)),
            #selector(openInDefaultViewer(_:)),
            #selector(renameDocument(_:)),
            #selector(moveToTrash(_:)),
            #selector(copyCurrentFullPath(_:)),
            #selector(copyCurrentFilename(_:)),
            #selector(copyCurrentDirectoryPath(_:)):
            return isFileBacked
        case #selector(nextBookmark(_:)), #selector(previousBookmark(_:)), #selector(clearBookmarks(_:)):
            return !bookmarks.isEmpty
        case #selector(encodeInEncoding(_:)):
            return isFileBacked
        case #selector(toggleMonitoringMode(_:)):
            menuItem.state = isMonitoringMode ? .on : .off
            return isFileBacked
        case #selector(toggleByteOrderMark(_:)):
            menuItem.state = savePolicy.preservesByteOrderMark ? .on : .off
            return encoding.supportsByteOrderMarkIntent
        case #selector(toggleLineWrap(_:)):
            menuItem.state = wrapsLines ? .on : .off
            return true
        case #selector(toggleShowWhitespace(_:)):
            menuItem.state = whitespaceMode != .invisible ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(setWhitespaceMode(_:)):
            guard let mode = menuItem.representedObject as? WhitespaceDisplayMode else { return false }
            menuItem.state = whitespaceMode == mode ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleShowEOL(_:)):
            menuItem.state = showsEOL ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleIndentGuides(_:)):
            menuItem.state = showsIndentGuides ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleCurrentLineHighlight(_:)):
            menuItem.state = highlightsCurrentLine ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleWrapSymbol(_:)):
            menuItem.state = showsWrapSymbol ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleChangeHistory(_:)):
            menuItem.state = showsChangeHistory ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleSmartHighlight(_:)):
            menuItem.state = enablesSmartHighlight ? .on : .off
            return true
        case #selector(toggleXmlTagMatch(_:)):
            menuItem.state = enablesXmlTagMatch ? .on : .off
            return editorSurface.supportsXmlTagMatch
        case #selector(toggleAutoPair(_:)):
            menuItem.state = enablesAutoPair ? .on : .off
            return editorSurface.supportsAutoPair
        case #selector(toggleClickableLinks(_:)):
            menuItem.state = enablesClickableLinks ? .on : .off
            return editorSurface.supportsUrlHighlight
        case #selector(toggleNpcDisplay(_:)):
            menuItem.state = showsNpcCharacters ? .on : .off
            return editorSurface.supportsNpcDisplay
        case #selector(toggleLineNumberMargin(_:)):
            menuItem.state = showsLineNumberMargin ? .on : .off
            return true
        case #selector(toggleBookmarkMargin(_:)):
            menuItem.state = showsBookmarkMargin ? .on : .off
            return true
        case #selector(toggleEdgeLine(_:)):
            menuItem.state = showsEdgeLine ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(zoomRestore(_:)):
            return fontSizeZoomDelta != 0
        case #selector(beginOrEndSelect(_:)):
            menuItem.title = beginSelectPosition == nil
                ? Localization.string(.editBeginSelect, default: "Begin Select")
                : Localization.string(.editEndSelect, default: "End Select")
            return true
        case #selector(toggleAlwaysOnTop(_:)):
            menuItem.state = presentationState.isAlwaysOnTop ? .on : .off
            return true
        case #selector(toggleFullScreenMode(_:)):
            menuItem.state = window?.styleMask.contains(.fullScreen) == true ? .on : .off
            return window != nil
        case #selector(toggleDistractionFreeMode(_:)):
            menuItem.state = presentationState.isDistractionFree ? .on : .off
            return true
        case #selector(togglePostItMode(_:)):
            menuItem.state = presentationState.isPostIt ? .on : .off
            return true
        case #selector(toggleFoldAtCurrentLine(_:)), #selector(foldAll(_:)), #selector(unfoldAll(_:)):
            return editorSurface.supportsFolding
        case #selector(foldAtLevel(_:)), #selector(unfoldAtLevel(_:)):
            return editorSurface.supportsFolding
        case #selector(foldCurrentLevel(_:)), #selector(unfoldCurrentLevel(_:)):
            return editorSurface.supportsFolding
        case #selector(columnSelectionToMultiCursor(_:)):
            return editorSurface.liveRectangularSelection != nil
        case #selector(redactSelection(_:)):
            return editorSurface.selectedRange.length > 0 && !editorSurface.isReadOnly
        case #selector(copyLink(_:)):
            // Enable when selection has content, OR cursor is over a URL indicator
            let sel = editorSurface.selectedRange
            if sel.length > 0 { return true }
            return editorSurface.urlIndicatorRange(at: sel.location) != nil
        case #selector(pasteHtmlContent(_:)):
            return NSPasteboard.general.types?.contains(.html) == true && !editorSurface.isReadOnly
        case #selector(pasteRtfContent(_:)):
            let pb = NSPasteboard.general
            return (pb.types?.contains(.rtf) == true || pb.types?.contains(.rtfd) == true) && !editorSurface.isReadOnly
        case #selector(toggleReadOnly(_:)):
            menuItem.state = editorSurface.isReadOnly ? .on : .off
            return true
        case #selector(toggleTabBarVisibility(_:)):
            menuItem.state = !preferencesStore.load().tabbarHide ? .on : .off
            return true
        case #selector(toggleStatusBar(_:)):
            menuItem.state = showsStatusBar ? .on : .off
            return true
        case #selector(hideSelectedLines(_:)):
            return editorSurface.supportsAdvancedViewOptions
        case #selector(showAllHiddenLines(_:)):
            return editorSurface.supportsAdvancedViewOptions
        case #selector(goToMatchingBrace(_:)), #selector(selectToMatchingBrace(_:)):
            return true
        case #selector(cutMarkedLines(_:)), #selector(copyMarkedLines(_:)), #selector(deleteMarkedLines(_:)), #selector(deleteUnmarkedLines(_:)):
            return !bookmarks.isEmpty
        case #selector(pasteMarkedLines(_:)):
            return NSPasteboard.general.string(forType: .string) != nil
        case #selector(inverseBookmarkMarks(_:)):
            return documentLineCount() > 0
        case #selector(setBlockComments(_:)),
            #selector(removeBlockComments(_:)),
            #selector(streamComment(_:)),
            #selector(streamUncomment(_:)):
            return language.blockCommentStart?.isEmpty == false && language.blockCommentEnd?.isEmpty == false
        case #selector(generateMD5SelectionIntoClipboard(_:)),
            #selector(generateSHA1SelectionIntoClipboard(_:)),
            #selector(generateSHA256SelectionIntoClipboard(_:)),
            #selector(generateSHA512SelectionIntoClipboard(_:)):
            return editorSurface.selectedRange.length > 0
        case #selector(uppercaseSelection(_:)),
            #selector(lowercaseSelection(_:)),
            #selector(invertSelectionCase(_:)),
            #selector(properCaseSelection(_:)),
            #selector(sentenceCaseSelection(_:)),
            #selector(randomCaseSelection(_:)):
            return editorSurface.selectedRange.length > 0 && !editorSurface.isReadOnly
        case #selector(sortLinesAscending(_:)),
            #selector(sortLinesDescending(_:)),
            #selector(sortLinesCaseInsensitiveAscending(_:)),
            #selector(sortLinesCaseInsensitiveDescending(_:)),
            #selector(sortLinesLocaleAscending(_:)),
            #selector(sortLinesLocaleDescending(_:)),
            #selector(sortLinesLengthAscending(_:)),
            #selector(sortLinesLengthDescending(_:)),
            #selector(sortLinesIntegerAscending(_:)),
            #selector(sortLinesIntegerDescending(_:)),
            #selector(sortLinesDecimalCommaAscending(_:)),
            #selector(sortLinesDecimalCommaDescending(_:)),
            #selector(sortLinesDecimalDotAscending(_:)),
            #selector(sortLinesDecimalDotDescending(_:)),
            #selector(randomizeLineOrder(_:)),
            #selector(reverseLineOrder(_:)):
            return documentLineCount() > 1 && !editorSurface.isReadOnly
        case #selector(removeBlankLines(_:)),
            #selector(removeEmptyLines(_:)),
            #selector(removeDuplicateLines(_:)),
            #selector(removeConsecutiveDuplicateLines(_:)):
            return documentLineCount() > 1 && !editorSurface.isReadOnly
        case #selector(startMacroRecording(_:)):
            menuItem.state = activeMacroRecording == nil ? .off : .on
            return activeMacroRecording == nil
        case #selector(stopMacroRecording(_:)):
            return activeMacroRecording != nil
        case #selector(playLastMacro(_:)):
            return activeMacroRecording == nil && !(macroStore.loadLastRecording()?.commands.isEmpty ?? true)
        case #selector(saveLastMacroAsNamedMacro(_:)):
            return activeMacroRecording == nil && !(macroStore.loadLastRecording()?.commands.isEmpty ?? true)
        case #selector(playNamedMacro(_:)), #selector(deleteNamedMacro(_:)):
            return activeMacroRecording == nil && !macroStore.loadNamedRecordings().isEmpty
        case #selector(clearLastMacro(_:)):
            return activeMacroRecording == nil && macroStore.loadLastRecording() != nil
        case #selector(runMacroMultipleTimes(_:)):
            return activeMacroRecording == nil && !(macroStore.loadLastRecording()?.commands.isEmpty ?? true)
        case #selector(setTextDirectionRTL(_:)):
            menuItem.state = currentBidiMode == 2 ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(setTextDirectionLTR(_:)):
            menuItem.state = currentBidiMode == 1 ? .on : .off
            return editorSurface.supportsAdvancedViewOptions
        case #selector(toggleLineComment(_:)):
            return language.lineComment?.isEmpty == false
        case #selector(openContainingFolder(_:)),
             #selector(openContainingFolderInTerminal(_:)),
             #selector(openContainingFolderAsWorkspace(_:)),
             #selector(openInDefaultViewer(_:)),
             #selector(openContainingFolder(_:)):
            return isFileBacked
        case #selector(toggleToolbarVisibility(_:)):
            menuItem.state = (window?.toolbar?.isVisible ?? true) ? .on : .off
            return true
        case #selector(copySelectionAsHTML(_:)), #selector(copySelectionAsRTF(_:)):
            return editorSurface.selectedRange.length > 0
        case #selector(exportFunctionList(_:)):
            return FunctionListDefinition.loadDefault(languageName: language.name) != nil
        default:
            break
        }

        return true
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        EditorWindowToolbar.validate(toolbarItem: item, using: self)
    }

    func refreshLocalization() {
        updateTitle()
        updateStatus()
    }

    private func configureToolbar() {
        window?.toolbar = editorToolbar.makeToolbar()
        window?.toolbarStyle = .unifiedCompact
        // Restore saved toolbar visibility preference
        let saved = UserDefaults.standard.object(forKey: "notepadMac.toolbarVisible") as? Bool ?? true
        window?.toolbar?.isVisible = saved
    }

    private func configureContent() {
        guard let window else { return }

        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootView

        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.onSelectTab = { [weak self] identity in self?.onTabSelect?(identity) }
        tabBarView.onCloseTab = { [weak self] identity in self?.onTabClose?(identity) }
        tabBarView.onTabContextAction = { [weak self] identity, action in self?.onTabContextAction?(identity, action) }
        tabBarView.onRenameTab = { [weak self] _ in self?.renameDocument(nil) }
        tabBarView.onNewTab = { [weak self] in self?.onNewDocument?() }
        tabBarView.onReorderTab = { [weak self] identity, index in self?.onReorderTab?(identity, index) }

        statusField.translatesAutoresizingMaskIntoConstraints = false
        statusField.lineBreakMode = .byTruncatingTail
        statusField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusField.textColor = .secondaryLabelColor
        statusField.setAccessibilityLabel(
            Localization.string(.editorStatusBarAccessibilityLabel, default: "Editor status bar")
        )
        // Double-click status bar → Go To Line panel
        let statusClick = NSClickGestureRecognizer(target: self, action: #selector(statusBarDoubleClicked(_:)))
        statusClick.numberOfClicksRequired = 2
        statusField.addGestureRecognizer(statusClick)

        rootView.addSubview(tabBarView)
        rootView.addSubview(editorSurface.view)
        rootView.addSubview(statusField)

        NSLayoutConstraint.activate([
            tabBarView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tabBarView.topAnchor.constraint(equalTo: rootView.topAnchor),
            { tabBarHeightConstraint = tabBarView.heightAnchor.constraint(equalToConstant: EditorTabBarView.barHeight); return tabBarHeightConstraint! }(),

            editorSurface.view.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            editorSurface.view.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            editorSurface.view.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            editorSurface.view.bottomAnchor.constraint(equalTo: statusField.topAnchor),

            statusField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            statusField.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -5)
        ])
        statusFieldHeightConstraint = statusField.heightAnchor.constraint(equalToConstant: 18)
        statusFieldHeightConstraint?.isActive = true

        applyFont()
        applyLineWrapping()
        applyAdvancedViewOptions()
        applyWindowPresentationState()
        window.makeFirstResponder(editorSurface.firstResponder)
        editorSurface.setContextMenu(makeEditorContextMenu())
    }

    func applyEditorContextMenuSpec(_ spec: EditorContextMenuSpec?) {
        editorContextMenuSpec = spec
        editorSurface.setContextMenu(makeEditorContextMenu())
    }

    // MARK: - Editor right-click context menu

    private func makeEditorContextMenu() -> NSMenu {
        if let spec = editorContextMenuSpec {
            return buildEditorContextMenuFromSpec(spec)
        }
        return buildEditorContextMenu()
    }

    private func buildEditorContextMenuFromSpec(_ spec: EditorContextMenuSpec) -> NSMenu {
        let menu = NSMenu(title: "")
        var submenus: [String: NSMenu] = [:]

        func targetMenu(folderName: String?) -> NSMenu {
            guard let folder = folderName else { return menu }
            if let existing = submenus[folder] { return existing }
            let sub = NSMenu(title: folder)
            let parent = NSMenuItem(title: folder, action: nil, keyEquivalent: "")
            parent.submenu = sub
            menu.addItem(parent)
            submenus[folder] = sub
            return sub
        }

        func addItem(_ item: NSMenuItem, folderName: String?) {
            targetMenu(folderName: folderName).addItem(item)
        }

        for specItem in spec.items {
            switch specItem {
            case .separator:
                menu.addItem(.separator())

            case let .action(action, displayName, folderName):
                let title = displayName ?? localizedLabel(for: action)
                if let mi = menuItem(for: action, title: title) {
                    addItem(mi, folderName: folderName)
                }

            case let .pluginCommand(_, commandName, displayName, folderName):
                let title = displayName ?? commandName
                let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                addItem(mi, folderName: folderName)
            }
        }
        return menu
    }

    private func localizedLabel(for action: EditorContextMenuAction) -> String {
        switch action {
        case .undo:               return Localization.string(.editUndo,      default: "Undo")
        case .redo:               return Localization.string(.editRedo,      default: "Redo")
        case .cut:                return Localization.string(.editCut,       default: "Cut")
        case .copy:               return Localization.string(.editCopy,      default: "Copy")
        case .paste:              return Localization.string(.editPaste,     default: "Paste")
        case .delete:             return "Delete"
        case .selectAll:          return Localization.string(.editSelectAll, default: "Select All")
        case .copyAsHTML:         return "Copy as HTML (HEX)"
        case .copyAsRTF:          return "Copy as RTF"
        case .duplicateLine:      return Localization.string(.editDuplicateLineOrSelection, default: "Duplicate Current Line")
        case .deleteLine:         return "Delete Current Line"
        case .joinLines:          return "Join Lines"
        case .upperCase:          return Localization.string(.editUppercase, default: "UPPERCASE")
        case .lowerCase:          return Localization.string(.editLowercase, default: "lowercase")
        case .properCase:         return "Proper Case"
        case .toggleCase:         return "Toggle Case"
        case .find:               return Localization.string(.searchFind,      default: "Find...")
        case .findNext:           return Localization.string(.searchFindNext,   default: "Find Next")
        case .findPrevious:       return Localization.string(.searchFindPrevious, default: "Find Previous")
        case .findAll:            return "Find All"
        case .replace:            return Localization.string(.findReplaceLabel, default: "Replace...")
        case .findInFiles:        return Localization.string(.searchFindInFiles, default: "Find in Files...")
        case .goToLine:           return Localization.string(.searchGoToLine,  default: "Go to...")
        case .markAllFind:        return "Mark All"
        case .searchOnInternet:   return Localization.string(.editSearchOnInternet, default: "Search on Internet")
        case .toggleFold:         return Localization.string(.foldingToggle, default: "Toggle Fold")
        case .foldAll:            return Localization.string(.foldingFoldAll, default: "Fold All")
        case .unfoldAll:          return Localization.string(.foldingUnfoldAll, default: "Unfold All")
        case .collapseCurrentLevel:   return Localization.string(.foldingFoldCurrentLevel, default: "Collapse Current Level")
        case .uncollapseCurrentLevel: return Localization.string(.foldingUnfoldCurrentLevel, default: "Uncollapse Current Level")
        case .collapseAllLevels:      return "Collapse All"
        case .uncollapseAllLevels:    return "Uncollapse All"
        case .openSelectedFile:   return Localization.string(.editOpenSelectedFile, default: "Open File")
        case .toggleReadOnly:     return Localization.string(.editToggleReadOnly, default: "Read-Only on Current Document")
        case .clearReadOnly:      return "Clear Read-Only Flag"
        case .copyFullPath:       return Localization.string(.editCopyCurrentFullPath, default: "Full File Path to Clipboard")
        case .copyFilename:       return Localization.string(.editCopyCurrentFilename, default: "Filename to Clipboard")
        case .copyDirPath:        return Localization.string(.editCopyCurrentDirectoryPath, default: "Current Dir. Path to Clipboard")
        }
    }

    private func menuItem(for action: EditorContextMenuAction, title: String) -> NSMenuItem? {
        func std(_ sel: Selector) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            mi.target = nil
            return mi
        }
        func selfItem(_ sel: Selector) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            mi.target = self
            return mi
        }
        switch action {
        case .undo:               return std(Selector(("undo:")))
        case .redo:               return std(Selector(("redo:")))
        case .cut:                return std(#selector(NSText.cut(_:)))
        case .copy:               return std(#selector(NSText.copy(_:)))
        case .paste:              return std(#selector(NSText.paste(_:)))
        case .delete:             return std(#selector(NSText.delete(_:)))
        case .selectAll:          return std(#selector(NSText.selectAll(_:)))
        case .copyAsHTML:         return selfItem(#selector(copySelectionAsHTML(_:)))
        case .copyAsRTF:          return selfItem(#selector(copySelectionAsRTF(_:)))
        case .duplicateLine:      return selfItem(#selector(duplicateLineOrSelection(_:)))
        case .deleteLine:         return selfItem(#selector(deleteLineOrSelection(_:)))
        case .joinLines:          return selfItem(#selector(joinSelectedLines(_:)))
        case .upperCase:          return selfItem(#selector(uppercaseSelection(_:)))
        case .lowerCase:          return selfItem(#selector(lowercaseSelection(_:)))
        case .properCase:         return selfItem(#selector(properCaseSelection(_:)))
        case .toggleCase:         return selfItem(#selector(invertSelectionCase(_:)))
        case .find:               return selfItem(#selector(showFindPanel(_:)))
        case .findNext:           return selfItem(#selector(findNext(_:)))
        case .findPrevious:       return selfItem(#selector(findPrevious(_:)))
        case .findAll:            return selfItem(#selector(findAllInDocument(_:)))
        case .replace:            return selfItem(#selector(showReplacePanel(_:)))
        case .findInFiles:        return selfItem(#selector(showFindInFilesPanel(_:)))
        case .goToLine:           return selfItem(#selector(showGoToLinePanel(_:)))
        case .markAllFind:        return selfItem(#selector(markAllFromContextMenu(_:)))
        case .searchOnInternet:   return selfItem(#selector(searchOnInternet(_:)))
        case .toggleFold:         return selfItem(#selector(toggleFoldAtCurrentLine(_:)))
        case .foldAll:            return selfItem(#selector(foldAll(_:)))
        case .unfoldAll:          return selfItem(#selector(unfoldAll(_:)))
        case .collapseCurrentLevel:   return selfItem(#selector(foldCurrentLevel(_:)))
        case .uncollapseCurrentLevel: return selfItem(#selector(unfoldCurrentLevel(_:)))
        case .collapseAllLevels:      return selfItem(#selector(foldAll(_:)))
        case .uncollapseAllLevels:    return selfItem(#selector(unfoldAll(_:)))
        case .openSelectedFile:   return selfItem(#selector(openSelectedFile(_:)))
        case .toggleReadOnly:     return selfItem(#selector(toggleReadOnly(_:)))
        case .clearReadOnly:      return selfItem(#selector(toggleReadOnly(_:)))
        case .copyFullPath:       return selfItem(#selector(copyCurrentFullPath(_:)))
        case .copyFilename:       return selfItem(#selector(copyCurrentFilename(_:)))
        case .copyDirPath:        return selfItem(#selector(copyCurrentDirectoryPath(_:)))
        }
    }

    private func buildEditorContextMenu() -> NSMenu {
        let menu = NSMenu(title: "")

        // Standard edit actions — target=nil flows up the responder chain
        func stdItem(_ title: String, action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = nil
            menu.addItem(item)
        }
        func selfItem(_ title: String, action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        stdItem(Localization.string(.editUndo,      default: "Undo"),       action: Selector(("undo:")))
        stdItem(Localization.string(.editRedo,      default: "Redo"),       action: Selector(("redo:")))
        menu.addItem(.separator())

        stdItem(Localization.string(.editCut,       default: "Cut"),        action: #selector(NSText.cut(_:)))
        stdItem(Localization.string(.editCopy,      default: "Copy"),       action: #selector(NSText.copy(_:)))
        stdItem(Localization.string(.editPaste,     default: "Paste"),      action: #selector(NSText.paste(_:)))
        menu.addItem(.separator())

        stdItem(Localization.string(.editSelectAll, default: "Select All"), action: #selector(NSText.selectAll(_:)))
        menu.addItem(.separator())

        selfItem(Localization.string(.editToggleReadOnly, default: "Read-Only on Current Document"),
                 action: #selector(toggleReadOnly(_:)))
        selfItem(Localization.string(.foldingToggle, default: "Toggle Fold"),
                 action: #selector(toggleFoldAtCurrentLine(_:)))
        menu.addItem(.separator())

        selfItem(Localization.string(.editSearchOnInternet, default: "Search on Internet"),
                 action: #selector(searchOnInternet(_:)))
        menu.addItem(.separator())

        // Quick edit actions
        selfItem(Localization.string(.editDuplicateLineOrSelection, default: "Duplicate Current Line"),
                 action: #selector(duplicateLineOrSelection(_:)))
        selfItem(Localization.string(.editLineComment, default: "Toggle Line Comment"),
                 action: #selector(toggleLineComment(_:)))
        selfItem(Localization.string(.editBlockComment, default: "Block Comment"),
                 action: #selector(streamComment(_:)))
        selfItem(Localization.string(.editBlockUncomment, default: "Block Uncomment"),
                 action: #selector(streamUncomment(_:)))
        menu.addItem(.separator())

        // Quick find
        selfItem(Localization.string(.editFindAll, default: "Find All in Current Document"),
                 action: #selector(findAllInDocument(_:)))
        selfItem(Localization.string(.searchFindInFiles, default: "Find in Files..."),
                 action: #selector(showFindInFilesPanel(_:)))
        selfItem(Localization.string(.editOpenSelectedFile, default: "Open File"),
                 action: #selector(openSelectedFile(_:)))
        selfItem(Localization.string(.fileOpenContainingFolder, default: "Open Containing Folder"),
                 action: #selector(openContainingFolder(_:)))
        menu.addItem(.separator())

        // Clipboard shortcuts for current file
        selfItem(Localization.string(.editCopyCurrentFullPath, default: "Copy Full Path"),
                 action: #selector(copyCurrentFullPath(_:)))
        selfItem(Localization.string(.editCopyCurrentFilename, default: "Copy Filename"),
                 action: #selector(copyCurrentFilename(_:)))
        selfItem(Localization.string(.editCopyLink, default: "Copy Link"),
                 action: #selector(copyLink(_:)))

        return menu
    }

    private func observeEditorNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorTextDidChange(_:)),
            name: NSText.didChangeNotification,
            object: editorSurface.notificationObject
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorSelectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: editorSurface.notificationObject
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorSelectionDidChange(_:)),
            name: Notification.Name("SCIUpdateUI"),
            object: editorSurface.notificationObject
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(findInFilesOpenFile(_:)),
            name: .findInFilesOpenFile,
            object: nil
        )
    }

    @objc private func findInFilesOpenFile(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let filePath = userInfo["filePath"] as? String,
              let line = userInfo["line"] as? Int
        else { return }

        let fileURL = URL(fileURLWithPath: filePath)
        let appDelegate = NSApp.delegate as? AppDelegate
        appDelegate?.openFileAtLine(fileURL: fileURL, line: line)
    }

    private func observeEditorSurfaceInteractions() {
        editorSurface.setMarginClickHandler { [weak self] click in
            self?.handleEditorMarginClick(click)
        }
        editorSurface.setCharAddedHandler { [weak self] char in
            self?.handleCharAddedForAutoComplete(char)
        }
    }

    private func handleCharAddedForAutoComplete(_ char: Character) {
        if isLargeFile && preferencesStore.load().largeFileSuppressAutoComplete { return }
        let threshold = autoCompleteFromNthChar
        guard threshold > 0, autoCompleteMode > 0, char.isLetter || char == "_" || char.isNumber else { return }
        // If ignoring numbers-only char additions when autoCompleteIgnoreNumbers is on
        let ignoreNumbers = preferencesStore.load().autoCompleteIgnoreNumbers
        if ignoreNumbers && char.isNumber { return }
        // Get word prefix under caret
        let text = editorSurface.text as NSString
        let caretPos = editorSurface.selectedRange.location
        guard caretPos > 0 else { return }
        var start = caretPos
        while start > 0 {
            let ch = text.character(at: start - 1)
            guard let scalar = Unicode.Scalar(ch), (CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains(scalar)) else { break }
            start -= 1
        }
        let prefixLen = caretPos - start
        guard prefixLen >= threshold else { return }
        let prefix = text.substring(with: NSRange(location: start, length: prefixLen))

        var words = Set<String>()

        // Mode 1 or 3: include API catalog function/keyword names
        if autoCompleteMode == 1 || autoCompleteMode == 3 {
            let catalog = resolveAutoCompletionCatalog()
            if let catalog {
                let lc = prefix.lowercased()
                for kw in catalog.keywords where kw.name.lowercased().hasPrefix(lc) && kw.name != prefix {
                    words.insert(kw.name)
                }
            }
        }

        // Mode 2 or 3: include document words
        if autoCompleteMode == 2 || autoCompleteMode == 3 {
            let allText = editorSurface.text
            let pattern = try? NSRegularExpression(pattern: "\\b[A-Za-z_][A-Za-z0-9_]{" + String(threshold - 1) + ",}\\b")
            pattern?.enumerateMatches(in: allText, range: NSRange(allText.startIndex..., in: allText)) { match, _, _ in
                guard let range = match?.range, let swRange = Range(range, in: allText) else { return }
                let word = String(allText[swRange])
                if word != prefix { words.insert(word) }
            }
            words = Set(words.filter { $0.lowercased().hasPrefix(prefix.lowercased()) })
        }

        if words.isEmpty { return }
        var finalWords = Array(words)
        if ignoreNumbers {
            finalWords = finalWords.filter { !($0.first?.isNumber == true) }
        }
        if finalWords.isEmpty { return }
        editorSurface.showInlineAutoComplete(prefix: prefix, words: finalWords)
    }

    private func resolveAutoCompletionCatalog() -> AutoCompletionCatalog? {
        if cachedAutoCompletionCatalogLanguage == language.name, let cached = cachedAutoCompletionCatalog {
            return cached
        }
        let catalog = AutoCompletionCatalog.loadDefault(languageName: language.name)
        cachedAutoCompletionCatalog = catalog
        cachedAutoCompletionCatalogLanguage = language.name
        return catalog
    }

    private func configureDragAndDrop() {
        window?.contentView?.registerForDraggedTypes([.fileURL])
        window?.contentView?.wantsLayer = true
    }

    // MARK: - NSDraggingDestination

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        guard pb.types?.contains(.fileURL) == true else { return [] }
        return .copy
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return draggingEntered(sender)
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let items = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !items.isEmpty
        else { return false }

        let appDelegate = NSApp.delegate as? AppDelegate
        if items.count == 1 && fileURL == nil && !isDirty {
            // Single drop on empty untitled window: load directly
            do {
                try load(items[0])
            } catch {
                appDelegate?.openFile(at: items[0])
            }
        } else {
            // Multiple files: use batch-confirmation path
            appDelegate?.openURLs(items)
        }
        return true
    }

    private func handleEditorMarginClick(_ click: EditorMarginClick) {
        switch click.margin {
        case .bookmark:
            toggleBookmark(line: click.line)
        case .fold:
            guard editorSurface.toggleFold(atLine: click.line) else { return }
            updateStatus()
            onSessionStateChange?()
        }
    }

    // Files larger than this are treated as "large files" with reduced features
    private var largeFileSizeThreshold: Int { preferencesStore.load().largeFileSizeMB * 1024 * 1024 }
    private var isLargeFile = false

    private func load(_ url: URL) throws {
        let loaded = try TextFileCodec.read(url, openAnsiAsUtf8: preferencesStore.load().openAnsiAsUtf8)
        fileURL = url
        snapshotID = nil
        encoding = loaded.encoding
        savePolicy = TextFileSavePolicy.loaded(loaded)
        lineEnding = loaded.lineEnding
        language = LanguageDetector.detect(url: url, in: languageCatalog)
        isLargeFile = loaded.text.utf8.count > largeFileSizeThreshold
        if isLargeFile && preferencesStore.load().largeFileSuppressWordWrap {
            editorSurface.applyLineWrapping(false, width: window?.contentView?.bounds.width ?? 0)
        }
        editorSurface.text = loaded.text
        bookmarks = bookmarks.clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        isDirty = false
        updateTitle()
        if !isLargeFile {
            highlight()
        }
        updateStatus()
        if !isLargeFile {
            scheduleUrlHighlightUpdate()
        }
        startFileMonitoring(for: url)
    }

    private func load(_ snapshot: DocumentSnapshot, snapshotStore: SnapshotStore) throws {
        fileURL = snapshot.originalFile
        snapshotID = snapshot.id
        untitledDisplayName = snapshot.displayName
        encoding = snapshot.encoding
        savePolicy = TextFileSavePolicy(preservesByteOrderMark: snapshot.preservesByteOrderMark)
            .converted(to: snapshot.encoding)
        let text = try snapshotStore.loadText(for: snapshot)
        lineEnding = snapshot.lineEnding
        language = LanguageDetector.detect(url: snapshot.originalFile, in: languageCatalog)
        editorSurface.text = text
        bookmarks = bookmarks.clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        isDirty = true
        updateTitle()
        highlight()
        updateStatus()
        startFileMonitoring(for: snapshot.originalFile)
    }

    private func save(to url: URL) {
        if trimTrailingSpacesOnSave {
            let current = editorSurface.text
            let result = TextEditCommands.trimTrailingWhitespace(
                in: current,
                selectedRange: editorSurface.selectedRange
            )
            if result.text != current {
                editorSurface.text = result.text
                editorSurface.setSelectedRange(result.selectedRange)
            }
        }
        do {
            if backupOnSaveMode != .none, FileManager.default.fileExists(atPath: url.path),
               let backupURL = BackupPathBuilder.backupURL(
                   for: url,
                   mode: backupOnSaveMode,
                   useCustomDirectory: useCustomBackupDirectory,
                   customDirectory: customBackupDirectory
               ) {
                try? BackupPathBuilder.ensureParentDirectoryExists(for: backupURL)
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try? FileManager.default.removeItem(at: backupURL)
                }
                try? FileManager.default.copyItem(at: url, to: backupURL)
            }
            let nextSavePolicy = savePolicy.converted(to: encoding)
            try TextFileCodec.write(
                editorSurface.text,
                to: url,
                encoding: encoding,
                lineEnding: lineEnding,
                includeByteOrderMark: nextSavePolicy.includeByteOrderMark(for: encoding)
            )
            savePolicy = nextSavePolicy
            fileURL = url
            snapshotID = nil
            language = LanguageDetector.detect(url: url, in: languageCatalog)
            isDirty = false
            updateTitle()
            highlight()
            updateStatus()
            startFileMonitoring(for: url)
        } catch {
            presentError(error)
        }
    }

    private func saveCopy(at url: URL) {
        do {
            let nextSavePolicy = savePolicy.converted(to: encoding)
            try TextFileCodec.write(
                editorSurface.text,
                to: url,
                encoding: encoding,
                lineEnding: lineEnding,
                includeByteOrderMark: nextSavePolicy.includeByteOrderMark(for: encoding)
            )
        } catch {
            presentError(error)
        }
    }

    private func applyRename(to nextFileName: String) {
        let sanitized = nextFileName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !sanitized.isEmpty else {
            return
        }
        guard let currentFileURL = fileURL else { return }
        let targetURL = currentFileURL.deletingLastPathComponent().appendingPathComponent(sanitized)
        guard targetURL != currentFileURL else { return }

        do {
            try FileManager.default.moveItem(at: currentFileURL, to: targetURL)
            fileURL = targetURL
            language = LanguageDetector.detect(url: targetURL, in: languageCatalog)
            snapshotID = nil
            startFileMonitoring(for: targetURL)
            updateTitle()
            highlight()
            updateStatus()
        } catch {
            presentError(error)
        }
    }

    private func deleteCurrentFileToTrash() {
        guard let fileURL else { return }
        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            close()
        } catch {
            presentError(error)
        }
    }

    private func applyEditedText(_ text: String, selectedRange: NSRange) {
        let previousText = editorSurface.text
        editorSurface.text = text
        editorSurface.setSelectedRange(selectedRange)
        recordMacroTextChangeIfNeeded(from: previousText, to: text)
        bookmarks = bookmarks.clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        isDirty = true
        updateTitle()
        highlight()
        updateStatus()
    }

    private func applyEditCommandResult(_ result: TextEditCommandResult) {
        guard result.text != editorSurface.text || result.selectedRange != editorSurface.selectedRange else {
            return
        }
        applyEditedText(result.text, selectedRange: result.selectedRange)
    }

    private func replaceSelection(with insertedText: String) {
        let selectedRange = editorSurface.selectedRange
        let nextText = NSMutableString(string: editorSurface.text)
        nextText.replaceCharacters(in: selectedRange, with: insertedText)
        let nextSelection = NSRange(location: selectedRange.location + insertedText.utf16.count, length: 0)
        applyEditedText(String(nextText), selectedRange: nextSelection)
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func copySelectionDigestToPasteboard(using algorithm: HashAlgorithm) {
        let selectedRange = editorSurface.selectedRange
        guard selectedRange.length > 0 else { return }
        let selectedText = (editorSurface.text as NSString).substring(with: selectedRange)
        copyToPasteboard(HashToolSupport.digest(of: selectedText, using: algorithm))
    }

    private func currentSelectionTarget() -> EditSelectionTarget? {
        EditMenuSupport.selectionTarget(
            in: editorSurface.text,
            selectedRange: editorSurface.selectedRange,
            currentFileURL: fileURL
        )
    }

    private func performColumnEdit(_ operation: ColumnEditorOperation, lineRange: ClosedRange<Int>, column: Int) {
        do {
            let result: ColumnEditResult
            switch operation {
            case let .text(insertion):
                result = try ColumnEdit.insertText(
                    insertion,
                    into: editorSurface.text,
                    lineRange: lineRange,
                    column: column
                )
            case let .number(options):
                result = try ColumnEdit.insertNumberSequence(
                    into: editorSurface.text,
                    lineRange: lineRange,
                    column: column,
                    options: options
                )
            }
            let selectedRange: NSRange
            if let lastRange = result.insertedRanges.last {
                selectedRange = NSRange(location: lastRange.location + lastRange.length, length: 0)
            } else {
                selectedRange = editorSurface.selectedRange
            }
            applyEditedText(result.text, selectedRange: selectedRange)
        } catch {
            presentError(error)
        }
    }

    private func performRectangularSelectionEdit(
        _ operation: RectangularSelectionPanelOperation,
        lineRange: ClosedRange<Int>,
        column: Int
    ) {
        do {
            let result: RectangularSelectionEditResult
            let zeroBasedColumn = try RectangularSelection.zeroBasedCharacterColumn(fromOneBasedColumn: column)

            switch operation {
            case let .insert(blockText):
                result = try RectangularSelection.insertResult(
                    rectangularBlockLines(from: blockText),
                    into: editorSurface.text,
                    lineRange: lineRange,
                    column: zeroBasedColumn
                )
            case let .replace(blockText, endColumn):
                let endExclusiveColumn = try RectangularSelection
                    .zeroBasedCharacterColumn(fromOneBasedColumn: endColumn) + 1
                result = try RectangularSelection.replaceResult(
                    in: editorSurface.text,
                    lineRange: lineRange,
                    columnRange: zeroBasedColumn..<endExclusiveColumn,
                    with: rectangularBlockLines(from: blockText)
                )
            }

            let selectedRange = rectangularSelectionHighlightRange(for: result)
            applyEditedText(result.text, selectedRange: selectedRange)
            if result.editedRanges.count > 1 {
                _ = editorSurface.applyDiscontiguousSelections(
                    result.editedRanges,
                    mainSelectionIndex: result.editedRanges.count - 1
                )
            }
        } catch {
            presentError(error)
        }
    }

    private func rectangularSelectionHighlightRange(for result: RectangularSelectionEditResult) -> NSRange {
        let textLength = (result.text as NSString).length
        let range = result.contiguousEditedRange ?? result.finalCaretRange
        let location = min(max(0, range.location), textLength)
        let requestedLength = max(0, range.length)
        let requestedEnd = range.location > Int.max - requestedLength
            ? Int.max
            : range.location + requestedLength
        let end = min(max(location, requestedEnd), textLength)
        return NSRange(location: location, length: end - location)
    }

    private func insertCompletion(_ completion: String, replacingPrefix prefix: String) {
        let nsText = editorSurface.text as NSString
        let selectedRange = editorSurface.selectedRange
        let prefixLength = (prefix as NSString).length
        let start = max(0, selectedRange.location - prefixLength)
        let replacementRange = NSRange(location: start, length: prefixLength + selectedRange.length)
        let nextText = nsText.replacingCharacters(in: replacementRange, with: completion)
        let nextCaret = NSRange(location: start + (completion as NSString).length, length: 0)
        applyEditedText(nextText, selectedRange: nextCaret)
    }

    private func currentCompletionPrefix(environment: AutoCompletionEnvironment) -> String {
        let nsText = editorSurface.text as NSString
        let selectedLocation = min(editorSurface.selectedRange.location, nsText.length)
        guard selectedLocation > 0 else { return "" }

        let allowedScalars = Set((environment.additionalWordCharacters ?? "").unicodeScalars)
        var location = selectedLocation
        while location > 0 {
            let range = nsText.rangeOfComposedCharacterSequence(at: location - 1)
            let fragment = nsText.substring(with: range)
            guard fragment.unicodeScalars.allSatisfy({ scalar in
                CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || allowedScalars.contains(scalar)
            }) else {
                break
            }
            location = range.location
        }

        return nsText.substring(with: NSRange(location: location, length: selectedLocation - location))
    }

    private func saveCurrentEditorPreferences() {
        let preferences = preferencesStore.load()
            .withWrapsLines(wrapsLines)
            .withViewToggles(
                showWhitespace: whitespaceMode != .invisible,
                showEOL: showsEOL,
                showIndentGuides: showsIndentGuides,
                highlightCurrentLine: highlightsCurrentLine,
                showWrapSymbol: showsWrapSymbol,
                showChangeHistory: showsChangeHistory,
                showLineNumberMargin: showsLineNumberMargin,
                showEdgeLine: showsEdgeLine,
                edgeLineColumn: edgeLineColumn,
                enableAutoPair: enablesAutoPair,
                enableXmlTagMatch: enablesXmlTagMatch,
                enableClickableLinks: enablesClickableLinks,
                showNpcCharacters: showsNpcCharacters,
                showBookmarkMargin: showsBookmarkMargin
            )
            .withWhitespaceDisplayMode(whitespaceMode.rawValue)
            .withBidiMode(currentBidiMode)
            .withSmoothFont(smoothFont)
            .withMultiEditEnabled(multiEditEnabled)
            .withMultiPasteMode(multiPasteMode)
            .withIndentGuideMode(indentGuideMode)
            .withWordWrapMode(wordWrapMode)
            .withAdditionalSelAlpha(additionalSelAlpha)
            .withAdditionalCaretsBlink(additionalCaretsBlink)
            .withAdditionalCaretsVisible(additionalCaretsVisible)
            .withCaretLineVisibleAlways(caretLineVisibleAlways)
            .withWhitespaceSize(whitespaceSize)
            .withSelectionAlpha(selectionAlpha)
            .withControlCharDisplay(controlCharDisplay)
            .withAutoIndentMode(autoIndentMode)
            .withFileAutoDetection(fileAutoDetection)
            .withUpdateSilently(updateSilently)
            .withZoomSyncToAllTabs(zoomSyncToAllTabs)
            .withHideMenuShortcuts(hideMenuShortcuts)
            .withScrollToLastLineOnMonitorReload(scrollToLastLineOnMonitorReload)
            .withXmlTagAttributeHighlight(xmlTagAttributeHighlight)
            .withHighlightNonHtmlZone(highlightNonHtmlZone)
        preferencesStore.save(preferences)
    }

    func updateTabBar(_ state: EditorTabState) {
        tabBarView.update(state: state)
    }

    private func updateFirstLineTabName() {
        guard useFirstLineAsTabName, fileURL == nil else { return }
        let firstLine = editorSurface.text
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        let trimmed = String(firstLine.trimmingCharacters(in: .whitespaces).prefix(60))
        untitledDisplayName = trimmed.isEmpty
            ? displayStrings.untitledDocumentName
            : trimmed
    }

    private func updateTitle() {
        window?.title = displayStrings.windowTitle(displayName: titleBarDisplayName, isDirty: isDirty)
        window?.representedURL = fileURL
    }

    private func updateStatus() {
        let location = caretLocation()
        var parts = [
            String(
                format: Localization.string(.editorStatusPosition, default: "Ln %d, Col %d"),
                locale: Locale.current,
                location.line,
                location.column
            ),
            String(
                format: Localization.string(.editorStatusCharacterCount, default: "%d chars"),
                locale: Locale.current,
                editorSurface.text.count
            ),
        ]
        let selLen = editorSurface.selectedRange.length
        if selLen > 0 {
            let selText = (editorSurface.text as NSString).substring(with: editorSurface.selectedRange)
            let selLines = selText.components(separatedBy: "\n").count
            if selLines > 1 {
                parts.append(String(
                    format: Localization.string(.editorStatusSelectionMultiLine, default: "Sel: %d | %d lines"),
                    locale: Locale.current,
                    selLen,
                    selLines
                ))
            } else {
                parts.append(String(
                    format: Localization.string(.editorStatusSelection, default: "Sel: %d"),
                    locale: Locale.current,
                    selLen
                ))
            }
        }
        parts += [
            language.displayName,
            lineEnding.displayName,
            encoding.displayName + (savePolicy.preservesByteOrderMark ? " BOM" : ""),
            editorSurface.displayName
        ]
        if editorSurface.isReadOnly {
            parts.append(Localization.string(.editorStatusReadOnly, default: "READ ONLY"))
        }
        if let activeMacroRecording {
            parts.append(String(
                format: Localization.string(.editorStatusRecording, default: "REC %d"),
                locale: Locale.current,
                activeMacroRecording.commands.count
            ))
        }
        if isLargeFile {
            parts.append(Localization.string(.editorStatusLargeFile, default: "Large File"))
        }
        if isMonitoringMode {
            parts.append(Localization.string(.editorStatusMonitoring, default: "Monitoring"))
        }
        if editorSurface.isOvertype {
            parts.append("OVR")
        }
        let defaultFontSize = preferencesStore.load().editorFontSize
        let zoomPct = Int((fontSize / defaultFontSize * 100).rounded())
        if zoomPct != 100 {
            parts.append("Zoom: \(zoomPct)%")
        }
        if !bookmarks.isEmpty {
            parts.append(String(
                format: Localization.string(.editorStatusBookmarks, default: "Bookmarks %d"),
                locale: Locale.current,
                bookmarks.count
            ))
        }
        statusField.stringValue = parts.joined(separator: "    ")
    }

    private func caretLocation() -> (line: Int, column: Int) {
        lineAndColumn(at: editorSurface.selectedRange.location)
    }

    private func lineAndColumn(at utf16Location: Int) -> (line: Int, column: Int) {
        let position = TextPosition.lineAndColumn(in: editorSurface.text, utf16Location: utf16Location)
        return (position.line, position.column)
    }

    private func rectangularBlockLines(from text: String) -> [String] {
        guard !text.isEmpty else {
            return [""]
        }

        var lines: [String] = []
        var lineStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "\n" || character == "\r" {
                lines.append(String(text[lineStart..<index]))
                let next = text.index(after: index)
                if character == "\r", next < text.endIndex, text[next] == "\n" {
                    index = text.index(after: next)
                } else {
                    index = next
                }
                lineStart = index
            } else {
                index = text.index(after: index)
            }
        }

        lines.append(String(text[lineStart..<text.endIndex]))
        return lines
    }

    private func selectedLineRange() -> ClosedRange<Int> {
        let selection = editorSurface.selectedRange
        let startLine = lineAndColumn(at: selection.location).line
        let endLocation = max(selection.location, selection.location + selection.length)
        let endLine = lineAndColumn(at: endLocation).line
        return min(startLine, endLine)...max(startLine, endLine)
    }

    private func documentLineCount() -> Int {
        let text = editorSurface.text
        guard !text.isEmpty else { return 1 }

        var count = 1
        var previousWasCarriageReturn = false
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\n":
                if !previousWasCarriageReturn {
                    count += 1
                }
                previousWasCarriageReturn = false
            case "\r":
                count += 1
                previousWasCarriageReturn = true
            default:
                previousWasCarriageReturn = false
            }
        }
        return count
    }

    func goToLine(_ line: Int) {
        editorSurface.setSelectedRange(selectionRange(forLine: line))
        updateStatus()
    }

    func goToLine(_ line: Int, column: Int?) {
        var range = selectionRange(forLine: line)
        if let col = column, col > 1 {
            let offset = min(col - 1, (editorSurface.text as NSString).length - range.location)
            range = NSRange(location: range.location + max(0, offset), length: 0)
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
    }

    func goToScintillaPosition(_ position: Int) {
        let nsText = editorSurface.text as NSString
        let clamped = max(0, min(position, nsText.length))
        editorSurface.setSelectedRange(NSRange(location: clamped, length: 0))
        updateStatus()
    }

    func enableMonitoringMode() {
        guard !isMonitoringMode else { return }
        isMonitoringMode = true
        startFileMonitoring(for: fileURL)
        updateStatus()
    }

    private func markedLineTexts(in nsText: NSString, bookmarks: BookmarkSet) -> [String] {
        let sortedLines = bookmarks.sortedLines
        return sortedLines.compactMap { line in
            let startRange = selectionRange(forLine: line)
            let endRange = selectionRange(forLine: line + 1)
            let lineEnd: Int
            if line < documentLineCount() {
                lineEnd = endRange.location
            } else {
                lineEnd = nsText.length
            }
            let range = NSRange(location: startRange.location, length: lineEnd - startRange.location)
            guard range.location >= 0, range.length >= 0,
                  range.location + range.length <= nsText.length
            else { return nil }
            return nsText.substring(with: range).trimmingCharacters(in: .newlines)
        }
    }

    private func markedLineRanges(in nsText: NSString, bookmarks: BookmarkSet) -> [NSRange] {
        let sortedLines = bookmarks.sortedLines.sorted().reversed()
        return sortedLines.compactMap { line in
            let startRange = selectionRange(forLine: line)
            let endRange = selectionRange(forLine: line + 1)
            let lineEnd: Int
            if line < documentLineCount() {
                lineEnd = endRange.location
            } else {
                lineEnd = nsText.length
            }
            let range = NSRange(location: startRange.location, length: lineEnd - startRange.location)
            guard range.location >= 0, range.length >= 0,
                  range.location + range.length <= nsText.length
            else { return nil }
            return range
        }
    }

    private func removeLines(at lineRanges: [NSRange], in nsText: NSString) {
        guard !lineRanges.isEmpty else { return }
        let nextText = NSMutableString(string: nsText)
        // Ranges are already in reverse order from markedLineRanges
        for range in lineRanges {
            guard range.location + range.length <= nextText.length else { continue }
            nextText.deleteCharacters(in: range)
        }
        let cursorLocation = min(lineRanges.last?.location ?? 0, nextText.length)
        applyEditedText(nextText as String, selectedRange: NSRange(location: cursorLocation, length: 0))
        bookmarks = BookmarkSet()
        editorSurface.syncBookmarkMarkers(bookmarks)
        updateStatus()
        onSessionStateChange?()
    }

    private func endOfLine(_ line: Int, in nsText: NSString) -> Int {
        if line >= documentLineCount() {
            return nsText.length
        }
        let nextLineStart = selectionRange(forLine: line + 1)
        return max(0, nextLineStart.location - 1)
    }

    private func selectionRange(forLine requestedLine: Int) -> NSRange {
        let nsText = editorSurface.text as NSString
        let targetLine = max(1, requestedLine)
        guard targetLine > 1 else {
            return NSRange(location: 0, length: 0)
        }

        var line = 1
        var location = 0
        var previousWasCarriageReturn = false
        while location < nsText.length {
            let range = nsText.rangeOfComposedCharacterSequence(at: location)
            let fragment = nsText.substring(with: range)
            defer { location = range.upperBound }

            guard fragment.unicodeScalars.contains(where: { $0 == "\n" || $0 == "\r" }) else {
                previousWasCarriageReturn = false
                continue
            }

            if fragment == "\n", previousWasCarriageReturn {
                previousWasCarriageReturn = false
                continue
            }

            line += 1
            previousWasCarriageReturn = fragment == "\r"
            if line == targetLine {
                return NSRange(location: range.upperBound, length: 0)
            }
        }

        return NSRange(location: nsText.length, length: 0)
    }

    private func applyFont() {
        editorSurface.applyFont(name: editorFontName, size: fontSize, bold: editorFontBold)
        highlight()
    }

    private func applyLineWrapping() {
        let width = window?.contentView?.bounds.width ?? 0
        if wrapsLines {
            // Use the configured word wrap mode (1=word, 2=whitespace, 3=character)
            editorSurface.applyLineWrapping(true, width: width)
            // Also send the exact mode via the mode-aware method
            if editorSurface.supportsAdvancedViewOptions {
                editorSurface.applyWordWrapMode(wordWrapMode)
            }
        } else {
            editorSurface.applyLineWrapping(false, width: width)
        }
        editorSurface.applyLineWrapIndent(lineWrapIndent)
    }

    private func applyAdvancedViewOptions() {
        editorSurface.applyShowWhitespace(whitespaceMode != .invisible)
        if editorSurface.supportsAdvancedViewOptions {
            editorSurface.applyShowWhitespace(mode: whitespaceMode.rawValue)
        }
        editorSurface.applyShowEOL(showsEOL)
        if showsIndentGuides {
            editorSurface.applyIndentGuides(mode: indentGuideMode)
        } else {
            editorSurface.applyIndentGuides(false)
        }
        editorSurface.applyCurrentLineHighlight(highlightsCurrentLine)
        editorSurface.applyWrapSymbol(showsWrapSymbol)
        editorSurface.applyChangeHistory(showsChangeHistory)
        if editorSurface.supportsNpcDisplay {
            editorSurface.applyNpcDisplay(showsNpcCharacters)
        }
        editorSurface.applyCaretWidth(caretWidth)
        editorSurface.applyCaretPeriod(caretNoBlink ? 0 : caretBlinkRate)
        editorSurface.applyAdditionalEdgeColumns(additionalEdgeColumns)
        editorSurface.applyCurrentLineFrameWidth(currentLineFrameWidth)
        editorSurface.applyFoldMarginStyle(foldMarginStyle)
        editorSurface.applyCodeFolding(enableCodeFolding)
        editorSurface.applyVirtualSpace(enableVirtualSpace)
        editorSurface.applyBackspaceUnindents(backspaceUnindents)
        editorSurface.applyAutoIndent(autoIndent)
        editorSurface.applyAutoIndentMode(autoIndentMode)
        editorSurface.applyScrollBeyondLastLine(scrollBeyondLastLine)
        editorSurface.applySelectedTextDragDrop(selectedTextDragDrop)
        editorSurface.applyPasteConvertEndings(pasteConvertEndings)
        editorSurface.applyCaretStickyMode(caretStickyMode)
        editorSurface.applyLineNumberDynamicWidth(lineNumberDynamicWidth)
        editorSurface.applyColumnSelectionToMultiEditing(columnSelectionToMultiEditing)
        editorSurface.applyLinePadding(linePadding)
    }

    private func applyTabSettings(_ tabSize: Int, insertSpaces: Bool) {
        editorSurface.applyTabSize(tabSize, insertSpaces: insertSpaces)
    }

    /// Re-apply tab settings considering per-language overrides.
    func applyTabSettingsForCurrentLanguage() {
        let prefs = preferencesStore.load()
        let overrides = prefs.parsedLanguageTabOverrides()
        let langKey = language.name.lowercased()
        if let override = overrides[langKey] {
            applyTabSettings(override.tabSize, insertSpaces: override.insertSpaces)
        } else {
            applyTabSettings(prefs.tabSize, insertSpaces: prefs.insertSpacesInsteadOfTabs)
        }
    }

    private func applyStatusBarVisibility() {
        statusField.isHidden = !showsStatusBar
        statusFieldHeightConstraint?.constant = showsStatusBar ? 18 : 0
    }

    private func applyWindowPresentationState() {
        statusField.isHidden = presentationState.shouldHideChrome
        statusFieldHeightConstraint?.constant = presentationState.shouldHideChrome ? 0 : 18
        window?.titleVisibility = presentationState.shouldHideChrome ? .hidden : .visible
        window?.titlebarAppearsTransparent = presentationState.shouldHideChrome
        window?.toolbar?.isVisible = !presentationState.shouldHideChrome
        window?.level = presentationState.windowLevel
        window?.alphaValue = presentationState.windowAlpha
        window?.isOpaque = !presentationState.isPostIt
    }

    private func highlight() {
        guard !isLargeFile || !preferencesStore.load().largeFileSuppressSyntaxHighlight else { return }
        editorSurface.applyHighlight(
            language: language,
            styleCatalog: styleCatalog,
            stylePreferences: stylePreferences,
            highlighter: highlighter
        )
    }

    private func startFileMonitoring(for url: URL?) {
        stopFileMonitoring()
        guard let url else {
            fileChangeSnapshot = nil
            return
        }

        fileChangeSnapshot = FileChangeSnapshot.captureIfPresent(url)
        // Skip FSEvents watcher when user has disabled file change detection globally.
        guard fileChangeDetectionEnabled || isMonitoringMode else { return }
        fileMonitor = FileMonitor(url: url) { [weak self] in
            self?.handleFileSystemChange()
        }
        fileMonitor?.start()
    }

    private func stopFileMonitoring() {
        fileMonitor?.stop()
        fileMonitor = nil
    }

    private func handleFileSystemChange() {
        guard let fileURL,
              let baseline = fileChangeSnapshot
        else { return }

        let current = FileChangeSnapshot.captureIfPresent(fileURL)
        let status = baseline.changeStatus(comparedTo: current)

        switch status {
        case .unchanged:
            return
        case .deleted:
            if !isMonitoringMode {
                guard !isPresentingFileChangeAlert else { return }
                presentFileChangeAlert(status)
            }
        case .modified:
            if isMonitoringMode || autoReloadOnExternalChange {
                reloadForMonitoring()
            } else {
                guard !isPresentingFileChangeAlert else { return }
                presentFileChangeAlert(status)
            }
        }
    }

    private func reloadForMonitoring() {
        guard let url = fileURL else { return }
        do {
            let previousRange = reloadScrollToLastCaret ? editorSurface.selectedRange : nil
            let loaded = try TextFileCodec.read(url, openAnsiAsUtf8: preferencesStore.load().openAnsiAsUtf8)
            fileChangeSnapshot = FileChangeSnapshot.captureIfPresent(url)
            editorSurface.text = loaded.text
            if let saved = previousRange {
                let clamped = NSRange(location: min(saved.location, (loaded.text as NSString).length), length: 0)
                editorSurface.setSelectedRange(clamped)
            } else {
                let endRange = NSRange(location: (loaded.text as NSString).length, length: 0)
                editorSurface.setSelectedRange(endRange)
            }
            updateStatus()
            highlight()
        } catch {
            // Failed to reload – stay in monitoring mode, try again on next change
        }
    }

    @objc func toggleMonitoringMode(_ sender: Any?) {
        isMonitoringMode.toggle()
        if isMonitoringMode {
            // Force a snapshot refresh
            if let url = fileURL {
                fileChangeSnapshot = FileChangeSnapshot.captureIfPresent(url)
            }
        }
        onSessionStateChange?()   // triggers tab state rebuild to show/hide ⟳
    }

    private func presentFileChangeAlert(_ status: FileChangeStatus) {
        guard let window else { return }

        isPresentingFileChangeAlert = true
        let alert = NSAlert()

        switch status {
        case .unchanged:
            isPresentingFileChangeAlert = false
            return
        case .modified:
            alert.messageText = Localization.string(.fileChangeModifiedTitle)
            let messageKey: Localization.Key = isDirty
                ? .fileChangeModifiedDirtyMessage
                : .fileChangeModifiedCleanMessage
            alert.informativeText = String(
                format: Localization.string(messageKey),
                displayName
            )
            alert.addButton(withTitle: Localization.string(.fileChangeReload))
            alert.addButton(withTitle: Localization.string(.fileChangeKeepCurrent))
        case .deleted:
            alert.messageText = Localization.string(.fileChangeDeletedTitle)
            alert.informativeText = String(
                format: Localization.string(.fileChangeDeletedMessage),
                displayName
            )
            alert.addButton(withTitle: Localization.string(.fileChangeKeepCurrent))
        }

        alert.beginSheetModal(for: window) { [weak self] response in
            Task { @MainActor [weak self] in
                self?.completeFileChangeAlert(status: status, response: response)
            }
        }
    }

    private func completeFileChangeAlert(status: FileChangeStatus, response: NSApplication.ModalResponse) {
        defer { isPresentingFileChangeAlert = false }

        switch status {
        case .unchanged:
            return
        case let .modified(current):
            if response == .alertFirstButtonReturn {
                reloadMonitoredFileFromDisk()
            } else {
                fileChangeSnapshot = current
                startFileMonitoring(for: fileURL)
            }
        case .deleted:
            stopFileMonitoring()
            fileChangeSnapshot = nil
            isDirty = true
            updateTitle()
            onContentChange?()
        }
    }

    private func reloadMonitoredFileFromDisk() {
        guard let fileURL else { return }

        let previousRange = reloadScrollToLastCaret ? editorSurface.selectedRange : nil
        do {
            try load(fileURL)
            if scrollToLastLineOnMonitorReload {
                // Scroll to last line of file
                let textLen = (editorSurface.text as NSString).length
                editorSurface.setSelectedRange(NSRange(location: textLen, length: 0))
            } else if let saved = previousRange {
                let textLen = (editorSurface.text as NSString).length
                let clamped = NSRange(location: min(saved.location, textLen), length: 0)
                editorSurface.setSelectedRange(clamped)
            }
        } catch {
            presentError(error)
        }
    }

    private func recordMacroTextChangeIfNeeded(to currentText: String) {
        guard let macroBaselineText else { return }
        recordMacroTextChangeIfNeeded(from: macroBaselineText, to: currentText)
    }

    private func recordMacroTextChangeIfNeeded(from previousText: String, to currentText: String) {
        guard !isReplayingMacro,
              let recording = activeMacroRecording
        else {
            return
        }

        let nextRecording = recording.recordingTextChange(from: previousText, to: currentText)
        activeMacroRecording = nextRecording
        macroBaselineText = currentText
    }

    private func presentMacroReplayError() {
        let alert = NSAlert()
        alert.messageText = Localization.string(.editorMacroReplayFailed, default: "Macro replay failed")
        alert.informativeText = Localization.string(
            .editorMacroReplayMismatch,
            default: "The recorded text edits do not fit the current document."
        )
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func presentMissingFeatureResource(_ message: String) {
        let alert = NSAlert()
        alert.messageText = Localization.string(.editorResourceNotAvailable, default: "Resource not available")
        alert.informativeText = message
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func blockCommentMarkers() -> (start: String, end: String)? {
        guard let start = language.blockCommentStart,
              let end = language.blockCommentEnd,
              !start.isEmpty,
              !end.isEmpty
        else {
            presentMissingFeatureResource(
                String(
                    format: Localization.string(
                        .editorMissingBlockComment,
                        default: "No block-comment markers are configured for %@."
                    ),
                    locale: Locale.current,
                    language.displayName
                )
            )
            return nil
        }

        return (start, end)
    }

    private var displayName: String {
        displayStrings.displayName(fileURL: fileURL, fallbackDisplayName: untitledDisplayName)
    }

    /// Title shown in the window title bar (full path or filename-only based on shortTitle preference)
    private var titleBarDisplayName: String {
        if !preferencesStore.load().shortTitle, let url = fileURL {
            return url.path
        }
        return displayName
    }
}

private extension String.Encoding {
    var displayName: String {
        TextEncodingOption(encoding: self)?.displayName ?? String(
            format: Localization.string(.editorEncodingFallback, default: "Encoding %@"),
            locale: Locale.current,
            "\(rawValue)"
        )
    }
}
