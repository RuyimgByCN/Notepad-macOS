import AppKit
import NotepadMacCore

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation, NSToolbarItemValidation {
    static let editorTabbingIdentifier = "org.notepad-plus-plus.macnative.editor"

    var onClose: (() -> Void)?
    var onContentChange: (() -> Void)?
    var onSessionStateChange: (() -> Void)?
    var onActivate: (() -> Void)?

    private let editorSurface: EditorSurface
    private let statusField = NSTextField(labelWithString: "")
    private let highlighter = SyntaxHighlighter()
    private var languageCatalog: LanguageCatalog
    private var styleCatalog: StyleCatalog
    private let stylePreferencesStore: StylePreferencesStore
    private let preferencesStore: PreferencesStore
    private let macroStore = MacroStore()
    private lazy var findPanel = FindPanelController(editor: self, preferencesStore: preferencesStore)
    private lazy var autoCompletionPanel = AutoCompletionPanelController()
    private lazy var callTipPanel = CallTipPanelController()
    private lazy var functionListPanel = FunctionListPanelController()
    private lazy var columnEditorPanel = ColumnEditorPanelController()
    private lazy var rectangularSelectionPanel = RectangularSelectionPanelController()
    private lazy var editorToolbar = EditorWindowToolbar(controller: self)

    private var fileURL: URL?
    private var encoding: String.Encoding = .utf8
    private var savePolicy = TextFileSavePolicy.newFile
    private var lineEnding: LineEnding = .lf
    private var language: LanguageDefinition
    private var fontSize: CGFloat = 13
    private var isDirty = false
    private var wrapsLines = false
    private var stylePreferences: StylePreferences
    private var fileChangeSnapshot: FileChangeSnapshot?
    private var fileMonitor: FileMonitor?
    private var isPresentingFileChangeAlert = false
    private var activeMacroRecording: MacroRecording?
    private var macroBaselineText: String?
    private var isReplayingMacro = false
    private var snapshotID: String?
    private var bookmarks = BookmarkSet()
    private let untitledID = UUID().uuidString
    private var untitledDisplayName = "Untitled"

    var sessionFileURL: URL? {
        fileURL?.standardizedFileURL
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
        EditorTabItem(identity: tabIdentity, title: displayName)
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

    var supportsToolbarFoldingCommands: Bool {
        editorSurface.supportsFolding
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
        languageCatalog: LanguageCatalog = .fallback,
        styleCatalog: StyleCatalog = .empty,
        preferencesStore: PreferencesStore = PreferencesStore(),
        stylePreferencesStore: StylePreferencesStore = StylePreferencesStore()
    ) {
        self.languageCatalog = languageCatalog
        self.styleCatalog = styleCatalog
        self.preferencesStore = preferencesStore
        self.stylePreferencesStore = stylePreferencesStore
        self.language = languageCatalog.defaultLanguage
        self.editorSurface = EditorSurfaceFactory.make()
        let preferences = preferencesStore.load()
        let stylePreferences = stylePreferencesStore.load()
        self.fontSize = CGFloat(preferences.editorFontSize)
        self.wrapsLines = preferences.wrapsLines
        self.stylePreferences = stylePreferences

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "Untitled - Notepad++ Mac"
        window.delegate = self
        window.nextResponder = self
        window.tabbingMode = .preferred
        window.tabbingIdentifier = Self.editorTabbingIdentifier
        window.center()
        configureContent()
        configureToolbar()
        observeEditorNotifications()
        observeEditorSurfaceInteractions()
        updateTitle()
        updateStatus()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillClose(_ notification: Notification) {
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
        updateTitle()
        highlight()
        updateStatus()
        onContentChange?()
    }

    @objc private func editorSelectionDidChange(_ notification: Notification) {
        updateStatus()
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
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.txt"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.save(to: url)
        }
    }

    @objc func printDocument(_ sender: Any?) {
        let document = PrintDocument(
            title: displayName,
            text: editorSurface.text,
            languageDisplayName: language.displayName,
            encodingDisplayName: encoding.displayName
        )
        let printView = PrintTextView(document: document, fontSize: fontSize)
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let operation = NSPrintOperation(view: printView, printInfo: printInfo)
        operation.jobTitle = displayName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true

        if let window {
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

    @objc func increaseFontSize(_ sender: Any?) {
        fontSize = min(fontSize + 1, 32)
        saveCurrentEditorPreferences()
        applyFont()
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        fontSize = max(fontSize - 1, 9)
        saveCurrentEditorPreferences()
        applyFont()
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
        highlight()
        updateStatus()
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

    @objc func showDocumentStatistics(_ sender: Any?) {
        let summary = TextStatistics.summary(for: editorSurface.text)
        let alert = NSAlert()
        alert.messageText = Localization.string(.statisticsPanelTitle, default: "Document Statistics")
        alert.informativeText = String(
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
        alert.addButton(withTitle: Localization.string(.alertOK, default: "OK"))

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
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

    @objc func startMacroRecording(_ sender: Any?) {
        activeMacroRecording = MacroRecording(name: "Last Macro")
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
        nameField.stringValue = recording.name == "Last Macro" ? "" : recording.name
        alert.accessoryView = nameField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        macroStore.saveNamedRecording(MacroRecording(name: name, commands: recording.commands))
        updateStatus()
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
    }

    @objc func clearLastMacro(_ sender: Any?) {
        macroStore.clearLastRecording()
        activeMacroRecording = nil
        macroBaselineText = nil
        updateStatus()
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
        guard let range = TextSearch.findNext(query, in: editorSurface.text, from: editorSurface.selectedRange, options: options) else {
            return false
        }
        editorSurface.setSelectedRange(range)
        updateStatus()
        return true
    }

    func performReplace(query: String, replacement: String, options: TextSearch.Options) -> Bool {
        guard let result = TextSearch.replaceNext(query, with: replacement, in: editorSurface.text, from: editorSurface.selectedRange, options: options) else {
            return false
        }
        applyEditedText(result.text, selectedRange: result.replacedRange)
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

    func applyPreferences(_ preferences: AppPreferences) {
        fontSize = CGFloat(preferences.editorFontSize)
        wrapsLines = preferences.wrapsLines
        applyFont()
        applyLineWrapping()
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
        if menuItem.action == #selector(convertLineEnding(_:)),
           let rawValue = menuItem.representedObject as? String,
           let itemLineEnding = LineEnding(rawValue: rawValue) {
            menuItem.state = itemLineEnding == lineEnding ? .on : .off
        }

        switch menuItem.action {
        case #selector(toggleBookmark(_:)):
            menuItem.state = bookmarks.contains(line: caretLocation().line) ? .on : .off
            return true
        case #selector(nextBookmark(_:)), #selector(previousBookmark(_:)), #selector(clearBookmarks(_:)):
            return !bookmarks.isEmpty
        case #selector(toggleLineWrap(_:)):
            menuItem.state = wrapsLines ? .on : .off
            return true
        case #selector(toggleFoldAtCurrentLine(_:)), #selector(foldAll(_:)), #selector(unfoldAll(_:)):
            return editorSurface.supportsFolding
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
        default:
            break
        }

        return true
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        EditorWindowToolbar.validate(toolbarItem: item, using: self)
    }

    private func configureToolbar() {
        window?.toolbar = editorToolbar.makeToolbar()
    }

    private func configureContent() {
        guard let window else { return }

        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootView

        statusField.translatesAutoresizingMaskIntoConstraints = false
        statusField.lineBreakMode = .byTruncatingTail
        statusField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusField.textColor = .secondaryLabelColor

        rootView.addSubview(editorSurface.view)
        rootView.addSubview(statusField)

        NSLayoutConstraint.activate([
            editorSurface.view.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            editorSurface.view.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            editorSurface.view.topAnchor.constraint(equalTo: rootView.topAnchor),
            editorSurface.view.bottomAnchor.constraint(equalTo: statusField.topAnchor),

            statusField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            statusField.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -5),
            statusField.heightAnchor.constraint(equalToConstant: 18)
        ])

        applyFont()
        applyLineWrapping()
        window.makeFirstResponder(editorSurface.firstResponder)
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
    }

    private func observeEditorSurfaceInteractions() {
        editorSurface.setMarginClickHandler { [weak self] click in
            self?.handleEditorMarginClick(click)
        }
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

    private func load(_ url: URL) throws {
        let loaded = try TextFileCodec.read(url)
        fileURL = url
        snapshotID = nil
        encoding = loaded.encoding
        savePolicy = TextFileSavePolicy.loaded(loaded)
        lineEnding = loaded.lineEnding
        language = LanguageDetector.detect(url: url, in: languageCatalog)
        editorSurface.text = loaded.text
        bookmarks = bookmarks.clamped(toLineCount: documentLineCount())
        editorSurface.syncBookmarkMarkers(bookmarks)
        isDirty = false
        updateTitle()
        highlight()
        updateStatus()
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
        do {
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
            .withEditorFontSize(Double(fontSize))
            .withWrapsLines(wrapsLines)
        preferencesStore.save(preferences)
    }

    private func updateTitle() {
        window?.title = "\(isDirty ? "*" : "")\(displayName) - Notepad++ Mac"
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
            language.displayName,
            lineEnding.displayName,
            encoding.displayName,
            editorSurface.displayName
        ]
        if let activeMacroRecording {
            parts.append(String(
                format: Localization.string(.editorStatusRecording, default: "REC %d"),
                locale: Locale.current,
                activeMacroRecording.commands.count
            ))
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

    private func goToLine(_ line: Int) {
        editorSurface.setSelectedRange(selectionRange(forLine: line))
        updateStatus()
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
        editorSurface.applyFont(size: fontSize)
        highlight()
    }

    private func applyLineWrapping() {
        editorSurface.applyLineWrapping(wrapsLines, width: window?.contentView?.bounds.width ?? 0)
    }

    private func highlight() {
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
        guard !isPresentingFileChangeAlert,
              let fileURL,
              let baseline = fileChangeSnapshot
        else {
            return
        }

        let current = FileChangeSnapshot.captureIfPresent(fileURL)
        let status = baseline.changeStatus(comparedTo: current)

        switch status {
        case .unchanged:
            return
        case .modified, .deleted:
            presentFileChangeAlert(status)
        }
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

        do {
            try load(fileURL)
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

    private var displayName: String {
        fileURL?.lastPathComponent ?? untitledDisplayName
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
