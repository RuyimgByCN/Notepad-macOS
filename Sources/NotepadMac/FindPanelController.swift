import AppKit
import NotepadMacCore

/// Upstream-style Find/Replace dialog: a tabbed window (Find, Replace,
/// Find in Files, Find in Projects, Mark) with a shared option area,
/// backward-direction checkbox, search-mode radio group, in-selection
/// scope, transparency controls, a collapse toggle, and a status line —
/// mirroring Notepad++'s FindReplaceDlg layout and behavior.
@MainActor
final class FindPanelController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {
    private weak var editor: EditorWindowController?
    private let preferencesStore: PreferencesStore

    enum Tab: Int {
        case find = 0
        case replace = 1
        case findInFiles = 2
        case findInProjects = 3
        case mark = 4
    }

    // MARK: - Controls

    private let tabView = NSTabView()
    /// Shared container re-parented into the selected tab.
    private let sharedContainer = NSView()

    private let findLabel = NSTextField(labelWithString: "")
    private let replaceLabel = NSTextField(labelWithString: "")
    private let findField = NSComboBox()
    private let replaceField = NSComboBox()

    // Option checkboxes (left column, upstream order)
    private let backwardButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wholeWordButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let matchCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wrapAroundButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // Mark-tab-only options
    private let bookmarkLineButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let purgeButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // In-selection scope
    private let inSelectionButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var inSelectionAnchor: NSRange?

    // Search mode group (radio buttons, upstream "Search Mode" box)
    private let searchModeBox = NSBox()
    private let modeNormalButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let modeExtendedButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let modeRegexButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let dotMatchesNewlineButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // Find in Files specific controls
    private let directoryLabel = NSTextField(labelWithString: "")
    private let directoryField = NSComboBox()
    private let browseDirectoryButton = NSButton(title: "", target: nil, action: nil)
    private let filterLabel = NSTextField(labelWithString: "")
    private let filterField = NSComboBox()
    private let purgeBeforeSearchButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    // Find in Files action buttons (right column)
    private let findInFilesFindAllButton = NSButton(title: "", target: nil, action: nil)
    private let findInFilesReplaceAllButton = NSButton(title: "", target: nil, action: nil)

    /// Options area stack view — hidden arranged subviews collapse
    /// automatically, so switching tabs only needs show/hide toggles.
    private let optionsStack = NSStackView()
    /// Horizontal rows inside optionsStack for second-column Mark options.
    private let rowBackward = NSStackView()   // backward + bookmarkLine
    private let rowWholeWord = NSStackView()  // wholeWord + purge

    // Transparency group
    private let transparencyBox = NSBox()
    private let transparencyCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let transparencyOnFocusRadio = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let transparencyAlwaysRadio = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let transparencySlider = NSSlider(value: 0.75, minValue: 0.2, maxValue: 1.0, target: nil, action: nil)

    // Right-hand button column
    private let findNextButton = NSButton(title: "", target: nil, action: nil)
    private let countButton = NSButton(title: "", target: nil, action: nil)
    private let findAllCurrentButton = NSButton(title: "", target: nil, action: nil)
    private let findAllOpenButton = NSButton(title: "", target: nil, action: nil)
    private let replaceButton = NSButton(title: "", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "", target: nil, action: nil)
    private let replaceAllInAllButton = NSButton(title: "", target: nil, action: nil)
    private let markAllButton = NSButton(title: "", target: nil, action: nil)
    private let clearMarksButton = NSButton(title: "", target: nil, action: nil)
    private let copyMarkedTextButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)

    // Bottom bar
    private let collapseButton = NSButton(title: "˄", target: nil, action: nil)
    private let statusField = NSTextField(labelWithString: "")

    private var bottomSectionConstraints: [NSLayoutConstraint] = []
    private var collapsedBottomConstraint: NSLayoutConstraint?
    private var isCollapsed = false

    /// Toggled between normal and Find-in-Files modes.
    private var normalOptionsTop: NSLayoutConstraint!
    private var fifOptionsTop: NSLayoutConstraint!

    private var currentTab: Tab = .find

    // MARK: - Init

    init(editor: EditorWindowController, preferencesStore: PreferencesStore) {
        self.editor = editor
        self.preferencesStore = preferencesStore

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 430),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.minSize = NSSize(width: 660, height: 300)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false

        super.init(window: panel)
        panel.delegate = self
        configureContent()
        refreshLocalizedStrings()
        loadPreferences()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localizationDidChange(_:)),
            name: Localization.localizationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    func show(focusedOnReplace: Bool = false) {
        show(tab: focusedOnReplace ? .replace : .find)
    }

    func show(tab: Tab) {
        loadPreferences()
        selectTab(tab)
        // Auto-fill find field with selected text or word under caret
        if let editor, tab != .replace {
            let surface = editor.editorSurface
            let selection = surface.selectedRange
            let text = surface.text as NSString
            let prefs = preferencesStore.load()
            let threshold = prefs.inSelectionThreshold
            let selText = selection.length > 0 && NSMaxRange(selection) <= text.length
                ? text.substring(with: selection) : ""
            let selHasNewline = selText.contains("\n") || selText.contains("\r")
            if selHasNewline || selection.length >= threshold {
                inSelectionButton.state = .on
                inSelectionAnchor = selection
            } else {
                inSelectionButton.state = .off
                inSelectionAnchor = nil
            }
            updateInSelectionEnabled()
            if selection.length > 0, NSMaxRange(selection) <= text.length {
                if prefs.fillFindFromSelection, !selHasNewline {
                    findField.stringValue = selText
                }
            } else if prefs.autoSelectWordUnderCaret {
                let loc = min(selection.location, text.length)
                var start = loc
                var end = loc
                while start > 0 {
                    if !isWordChar(text.character(at: start - 1)) { break }
                    start -= 1
                }
                while end < text.length {
                    if !isWordChar(text.character(at: end)) { break }
                    end += 1
                }
                if end > start {
                    let wordRange = NSRange(location: start, length: end - start)
                    surface.setSelectedRange(wordRange)
                    findField.stringValue = text.substring(with: wordRange)
                }
            }
        }
        reloadHistoryItems()
        showWindow(nil)
        if window?.isVisible != true { window?.center() }
        window?.makeKeyAndOrderFront(nil)
        applyTransparencyForKeyState(isKey: true)
        window?.makeFirstResponder(tab == .replace ? replaceField : findField)
        if tab != .replace {
            findField.selectText(nil)
        }
    }

    func findNextFromMenu() {
        guard !findField.stringValue.isEmpty else {
            show()
            return
        }
        performFind(options: makeOptions(direction: nil))
    }

    func findPreviousFromMenu() {
        guard !findField.stringValue.isEmpty else {
            show()
            return
        }
        performFind(options: makeOptions(direction: .up))
    }

    func applyMonospaceFont(_ enabled: Bool) {
        let font: NSFont = enabled
            ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            : .systemFont(ofSize: NSFont.systemFontSize)
        findField.font = font
        replaceField.font = font
    }

    // MARK: - Tab handling

    private func selectTab(_ tab: Tab) {
        guard tab != .findInProjects else { return }
        tabView.selectTabViewItem(at: tab.rawValue)
    }

    func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        guard let tabViewItem, let index = tabViewItem.identifier as? Int,
              let tab = Tab(rawValue: index) else { return true }
        switch tab {
        case .findInFiles:
            // Show Find in Files content within this dialog (upstream behavior).
            return true
        case .findInProjects:
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showFindInProjectsPanel(nil)
            }
            return false
        default:
            return true
        }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let tabViewItem, let index = tabViewItem.identifier as? Int,
              let tab = Tab(rawValue: index) else { return }
        currentTab = tab
        moveSharedContainer(into: tabViewItem)
        applyTabVisibility()
        refreshWindowTitle()
    }

    private func moveSharedContainer(into tabViewItem: NSTabViewItem) {
        guard let host = tabViewItem.view else { return }
        sharedContainer.removeFromSuperview()
        host.addSubview(sharedContainer)
        NSLayoutConstraint.activate([
            sharedContainer.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            sharedContainer.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            sharedContainer.topAnchor.constraint(equalTo: host.topAnchor),
            sharedContainer.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
    }

    /// Shows/hides per-tab controls inside the shared container.
    private func applyTabVisibility() {
        let isFind = currentTab == .find
        let isReplace = currentTab == .replace
        let isMark = currentTab == .mark
        let isFindInFiles = currentTab == .findInFiles

        // Replace field: shown in Replace and Find in Files tabs
        replaceLabel.isHidden = !(isReplace || isFindInFiles)
        replaceField.isHidden = !(isReplace || isFindInFiles)

        // Find in Files specific fields
        directoryLabel.isHidden = !isFindInFiles
        directoryField.isHidden = !isFindInFiles
        browseDirectoryButton.isHidden = !isFindInFiles
        filterLabel.isHidden = !isFindInFiles
        filterField.isHidden = !isFindInFiles
        purgeBeforeSearchButton.isHidden = !isFindInFiles

        // Toggle constraint: optionsStack below replaceField (normal)
        // or below filterField (Find in Files).
        normalOptionsTop?.isActive = !isFindInFiles
        fifOptionsTop?.isActive = isFindInFiles

        // Options visibility (optionsStack auto-collapses hidden items)
        rowBackward.isHidden = isFindInFiles
        wrapAroundButton.isHidden = isFindInFiles
        inSelectionButton.isHidden = isFindInFiles || isMark
        bookmarkLineButton.isHidden = !isMark
        purgeButton.isHidden = !isMark

        // Regular action buttons
        findNextButton.isHidden = isMark || isFindInFiles
        countButton.isHidden = !isFind
        findAllCurrentButton.isHidden = !isFind
        findAllOpenButton.isHidden = !isFind
        replaceButton.isHidden = !isReplace
        replaceAllButton.isHidden = !isReplace
        replaceAllInAllButton.isHidden = !isReplace
        markAllButton.isHidden = !isMark
        clearMarksButton.isHidden = !isMark
        copyMarkedTextButton.isHidden = !isMark

        // Find in Files action buttons
        findInFilesFindAllButton.isHidden = !isFindInFiles
        findInFilesReplaceAllButton.isHidden = !isFindInFiles

        // Transparency not applicable to Find in Files
        transparencyBox.isHidden = isFindInFiles

        // Default button: Find Next / Mark All / Find All
        findNextButton.keyEquivalent = (isMark || isFindInFiles) ? "" : "\r"
        markAllButton.keyEquivalent = isMark ? "\r" : ""
        findInFilesFindAllButton.keyEquivalent = isFindInFiles ? "\r" : ""

        // Auto-fill directory from active document in FiF mode
        if isFindInFiles, directoryField.stringValue.isEmpty,
           let editorURL = editor?.sessionFileURL {
            directoryField.stringValue = editorURL.deletingLastPathComponent().path
        }
    }

    private func refreshWindowTitle() {
        switch currentTab {
        case .replace:
            window?.title = Localization.string(.findTabReplace, default: "Replace")
        case .findInFiles:
            window?.title = Localization.string(.findTabFindInFiles, default: "Find in Files")
        case .mark:
            window?.title = Localization.string(.findTabMark, default: "Mark")
        default:
            window?.title = Localization.string(.findTabFind, default: "Find")
        }
    }

    // MARK: - Actions

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    @objc private func findNext(_ sender: Any?) {
        performFind(options: makeOptions(direction: nil))
    }

    private func performFind(options searchOptions: TextSearch.Options) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        if editor?.performFind(query: findField.stringValue, options: searchOptions) == true {
            setStatus(Localization.string(.findStatusFound, default: "Found."))
        } else if searchOptions.searchMode == .regex,
                  let problem = TextSearch.regexPatternProblem(findField.stringValue) {
            setStatus(
                String(format: Localization.string(.findStatusInvalidRegex, default: "Invalid regex — %@"), problem),
                isError: true
            )
        } else {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
        }
    }

    @objc private func replaceNext(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        addToReplaceHistory(replaceField.stringValue)
        if editor?.performReplace(
            query: findField.stringValue,
            replacement: replaceField.stringValue,
            options: makeOptions(direction: nil)
        ) == true {
            setStatus(Localization.string(.findStatusReplaced, default: "Replaced."))
        } else {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
        }
    }

    @objc private func replaceAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        addToReplaceHistory(replaceField.stringValue)
        let count = editor?.performReplaceAll(
            query: findField.stringValue,
            replacement: replaceField.stringValue,
            options: makeOptions(direction: nil)
        ) ?? 0
        setStatus(localizedString(.findStatusReplacementCount, default: "%d replacement(s).", count))
        if !preferencesStore.load().keepFindDialogOpen {
            close()
        }
    }

    @objc private func replaceAllInAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        let query = findField.stringValue
        let replacement = replaceField.stringValue
        let searchOptions = makeOptions(direction: nil)

        if preferencesStore.load().confirmReplaceInAllDocs {
            let alert = NSAlert()
            alert.messageText = Localization.string(.findReplaceAllInAllConfirmMessage, default: "Replace All in Open Documents")
            alert.informativeText = String(
                format: Localization.string(.findReplaceAllInAllConfirmDetail, default: "Replace all occurrences of \"%@\" with \"%@\" in all open documents?"),
                query, replacement
            )
            alert.addButton(withTitle: Localization.string(.findReplaceAllInAllButton, default: "Replace All"))
            alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        var totalCount = 0
        if let appDelegate = NSApp.delegate as? AppDelegate {
            totalCount = appDelegate.replaceInAllOpenDocuments(query: query, replacement: replacement, options: searchOptions)
        }
        setStatus(localizedString(.findStatusReplacementCount, default: "%d replacement(s).", totalCount))
    }

    @objc private func countMatches(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        let text = editor?.editorSurface.text ?? ""
        let matches = TextSearch.findAll(findField.stringValue, in: text, options: makeOptions(direction: nil))
        if matches.isEmpty {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
        } else {
            setStatus(localizedString(.findStatusMatchCount, default: "%d match(es).", matches.count))
        }
    }

    @objc private func findAllInCurrentDocument(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        guard let editor else { return }
        let path = editor.sessionFileURL?.path ?? editor.windowListSortName
        let matches = DocumentMatchLocator.matches(
            query: findField.stringValue,
            in: editor.editorSurface.text,
            filePath: path,
            options: makeOptions(direction: nil)
        )
        guard !matches.isEmpty else {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
            return
        }
        (NSApp.delegate as? AppDelegate)?.publishFoundResults(matches)
        setStatus(localizedString(.findStatusMatchCount, default: "%d match(es).", matches.count))
    }

    @objc private func findAllInOpenDocuments(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        let matches = appDelegate.findAllInOpenDocuments(
            query: findField.stringValue,
            options: makeOptions(direction: nil)
        )
        guard !matches.isEmpty else {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
            return
        }
        appDelegate.publishFoundResults(matches)
        setStatus(localizedString(.findStatusMatchCount, default: "%d match(es).", matches.count))
    }

    @objc private func markAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        guard let editor else { return }
        if purgeButton.state == .on {
            editor.editorSurface.clearSearchIndicator(.style1)
        }
        let options = makeOptions(direction: nil)
        let matches = TextSearch.findAll(findField.stringValue, in: editor.editorSurface.text, options: options)
        guard !matches.isEmpty else {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
            return
        }
        editor.editorSurface.markAllWithIndicator(.style1, ranges: matches)
        if bookmarkLineButton.state == .on {
            _ = editor.performBookmarkAllMatches(query: findField.stringValue, options: options)
        }
        setStatus(localizedString(.findStatusMarkCount, default: "%d mark(s).", matches.count))
    }

    @objc private func clearAllMarks(_ sender: Any?) {
        editor?.editorSurface.clearSearchIndicator(.style1)
        setStatus(Localization.string(.findStatusMarksCleared, default: "Marks cleared."))
    }

    @objc private func copyMarkedText(_ sender: Any?) {
        guard let editor else { return }
        let ranges = editor.editorSurface.indicatorRanges(.style1)
        guard !ranges.isEmpty else {
            setStatus(Localization.string(.findStatusNoMarks, default: "No marks."), isError: true)
            return
        }
        let text = editor.editorSurface.text as NSString
        let pieces = ranges.compactMap { range -> String? in
            guard NSMaxRange(range) <= text.length else { return nil }
            return text.substring(with: range)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pieces.joined(separator: "\n"), forType: .string)
        setStatus(localizedString(.findStatusCopiedMarks, default: "Copied %d marked item(s).", pieces.count))
    }

    @objc private func closeDialog(_ sender: Any?) {
        close()
    }

    // MARK: - Find in Files Actions

    @objc private func findInFilesFindAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            setStatus(Localization.string(.findStatusEnterText, default: "Enter text to find."), isError: true)
            return
        }
        saveSearchPreferences()
        addToFindHistory(findField.stringValue)

        let directory = directoryField.stringValue
        guard !directory.isEmpty else {
            NSSound.beepUnlessMuted()
            return
        }
        let dirURL = URL(fileURLWithPath: directory)
        guard FileManager.default.fileExists(atPath: directory),
              (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else {
            setStatus(Localization.string(.findInFilesInvalidDirectory, default: "Invalid directory"), isError: true)
            return
        }

        let matchCase = matchCaseButton.state == .on
        let wholeWord = wholeWordButton.state == .on
        let searchMode = currentSearchMode()
        let filters = FindInFilesSearch.parseFilters(filterField.stringValue)
        let perLine = preferencesStore.load().perLineResultInFind
        let purge = purgeBeforeSearchButton.state == .on

        setStatus(Localization.string(.findInFilesSearching, default: "Searching..."))

        let results = FindInFilesSearch.searchInDirectory(
            dirURL,
            query: findField.stringValue,
            filters: filters,
            matchCase: matchCase,
            wholeWord: wholeWord,
            searchMode: searchMode,
            skipPaths: [],
            perLineResult: perLine
        )

        if results.isEmpty {
            setStatus(Localization.string(.findStatusNoMatches, default: "No matches."), isError: true)
        } else {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.findInFilesResultsStore.setResults(results, purgeFirst: purge)
                appDelegate.showFoundResultsPanel()
            }
            setStatus(localizedString(.findStatusMatchCount, default: "%d match(es).", results.count))
        }
    }

    @objc private func findInFilesReplaceAll(_ sender: Any?) {
        let query = findField.stringValue
        let replacement = replaceField.stringValue
        let directory = directoryField.stringValue
        guard !query.isEmpty, !directory.isEmpty else {
            NSSound.beepUnlessMuted()
            return
        }

        let dirURL = URL(fileURLWithPath: directory)
        guard FileManager.default.fileExists(atPath: directory),
              (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else {
            setStatus(Localization.string(.findInFilesInvalidDirectory, default: "Invalid directory"), isError: true)
            return
        }

        let alert = NSAlert()
        alert.messageText = Localization.string(.findInFilesReplaceAllButton, default: "Replace All")
        alert.informativeText = String(
            format: Localization.string(.findInFilesReplaceConfirm, default: "Replace all occurrences of \"%@\" with \"%@\" in \"%@\"?"),
            query, replacement, directory
        )
        alert.addButton(withTitle: Localization.string(.findInFilesReplaceAllButton, default: "Replace All"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let matchCase = matchCaseButton.state == .on
        let wholeWord = wholeWordButton.state == .on
        let searchMode = currentSearchMode()
        let filters = FindInFilesSearch.parseFilters(filterField.stringValue)
        let options = TextSearch.Options(matchCase: matchCase, wholeWord: wholeWord, wraps: false, direction: .down, searchMode: searchMode)

        statusField.stringValue = Localization.string(.findInFilesSearching, default: "Replacing...")
        var totalReplaced = 0
        var filesModified = 0

        guard let enumerator = FileManager.default.enumerator(
            at: dirURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard let rv = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  rv.isRegularFile == true else { continue }
            if !filters.isEmpty, !FindInFilesSearch.matchesFilter(fileURL.lastPathComponent, filters: filters) { continue }
            guard let loaded = try? TextFileCodec.read(fileURL) else { continue }
            let result = TextSearch.replaceAll(query, with: replacement, in: loaded.text, options: options)
            guard result.count > 0 else { continue }
            try? TextFileCodec.write(result.text, to: fileURL, encoding: loaded.encoding, lineEnding: loaded.lineEnding,
                                     includeByteOrderMark: loaded.hasByteOrderMark)
            totalReplaced += result.count
            filesModified += 1
        }

        statusField.stringValue = String(
            format: Localization.string(.findInFilesReplaceResult, default: "%d replacement(s) in %d file(s)"),
            totalReplaced, filesModified
        )
    }

    @objc private func browseDirectory(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        directoryField.stringValue = url.path
    }

    /// Helper to extract the current search mode from radio buttons.
    private func currentSearchMode() -> TextSearch.SearchMode {
        if modeRegexButton.state == .on { return .regex }
        if modeExtendedButton.state == .on { return .extended }
        return .normal
    }

    @objc private func inSelectionToggled(_ sender: Any?) {
        guard inSelectionButton.state == .on, let editor else {
            inSelectionAnchor = nil
            return
        }
        let surface = editor.editorSurface
        let selection = surface.selectedRange
        let threshold = preferencesStore.load().inSelectionThreshold
        let text = surface.text as NSString
        let selText = selection.length > 0 && NSMaxRange(selection) <= text.length
            ? text.substring(with: selection) : ""
        let selHasNewline = selText.contains("\n") || selText.contains("\r")
        if !selHasNewline && selection.length < threshold {
            setStatus(Localization.string(
                .findInSelectionSmallWarning,
                default: "Warning: Selection is smaller than the In Selection threshold."
            ), isError: true)
        }
        inSelectionAnchor = selection.length > 0 ? selection : nil
    }

    @objc private func searchModeChanged(_ sender: Any?) {
        // Manual radio coordination: modeRegexButton is nested inside a
        // horizontal NSStackView (for ". matches newline"), so AppKit's
        // automatic radio-group sibling walk never reaches modeNormalButton
        // or modeExtendedButton.
        guard let clicked = sender as? NSButton else { return }
        if clicked != modeNormalButton { modeNormalButton.state = .off }
        if clicked != modeExtendedButton { modeExtendedButton.state = .off }
        if clicked != modeRegexButton { modeRegexButton.state = .off }
        clicked.state = .on
        dotMatchesNewlineButton.isEnabled = modeRegexButton.state == .on
    }

    @objc private func transparencySettingChanged(_ sender: Any?) {
        let enabled = transparencyCheckbox.state == .on
        transparencyOnFocusRadio.isEnabled = enabled
        transparencyAlwaysRadio.isEnabled = enabled
        transparencySlider.isEnabled = enabled
        saveFindDialogState()
        applyTransparencyForKeyState(isKey: window?.isKeyWindow ?? true)
    }

    @objc private func toggleCollapse(_ sender: Any?) {
        setCollapsed(!isCollapsed)
        saveFindDialogState()
    }

    private func setCollapsed(_ collapsed: Bool) {
        isCollapsed = collapsed
        searchModeBox.isHidden = collapsed
        transparencyBox.isHidden = collapsed
        collapseButton.title = collapsed ? "˅" : "˄"
        bottomSectionConstraints.forEach { $0.isActive = !collapsed }
        collapsedBottomConstraint?.isActive = collapsed
        if let window {
            window.layoutIfNeeded()
            let targetHeight: CGFloat = collapsed ? 300 : 430
            var frame = window.frame
            let delta = targetHeight - window.contentLayoutRect.height
            frame.origin.y -= delta
            frame.size.height += delta
            window.setFrame(frame, display: true, animate: window.isVisible)
        }
    }

    // MARK: - History

    private func addToFindHistory(_ query: String) {
        var history = preferencesStore.loadFindHistory()
        history.removeAll { $0 == query }
        history.insert(query, at: 0)
        preferencesStore.saveFindHistory(history)
        reloadHistoryItems()
    }

    private func addToReplaceHistory(_ query: String) {
        guard !query.isEmpty else { return }
        var history = preferencesStore.loadReplaceHistory()
        history.removeAll { $0 == query }
        history.insert(query, at: 0)
        preferencesStore.saveReplaceHistory(history)
        reloadHistoryItems()
    }

    private func reloadHistoryItems() {
        let findValue = findField.stringValue
        findField.removeAllItems()
        findField.addItems(withObjectValues: preferencesStore.loadFindHistory())
        findField.stringValue = findValue

        let replaceValue = replaceField.stringValue
        replaceField.removeAllItems()
        replaceField.addItems(withObjectValues: preferencesStore.loadReplaceHistory())
        replaceField.stringValue = replaceValue
    }

    // MARK: - Options

    private func makeOptions(direction: TextSearch.Direction?) -> TextSearch.Options {
        let mode: TextSearch.SearchMode
        if modeRegexButton.state == .on {
            mode = .regex
        } else if modeExtendedButton.state == .on {
            mode = .extended
        } else {
            mode = .normal
        }
        let useInSelection = inSelectionButton.state == .on
        if useInSelection, inSelectionAnchor == nil {
            inSelectionAnchor = editor?.editorSurface.selectedRange
        }
        if !useInSelection { inSelectionAnchor = nil }
        return TextSearch.Options(
            matchCase: matchCaseButton.state == .on,
            wholeWord: wholeWordButton.state == .on,
            wraps: wrapAroundButton.state == .on,
            direction: direction ?? (backwardButton.state == .on ? .up : .down),
            searchMode: mode,
            dotMatchesLineSeparators: dotMatchesNewlineButton.state == .on,
            searchRange: useInSelection ? inSelectionAnchor : nil
        )
    }

    private func updateInSelectionEnabled() {
        let selection = editor?.editorSurface.selectedRange ?? NSRange(location: 0, length: 0)
        inSelectionButton.isEnabled = selection.length > 0 || inSelectionButton.state == .on
    }

    // MARK: - Preferences

    private func loadPreferences() {
        let preferences = preferencesStore.load()
        matchCaseButton.state = preferences.searchMatchCase ? .on : .off
        wholeWordButton.state = preferences.searchWholeWord ? .on : .off
        let extended = preferencesStore.loadFindPanelExtendedState()
        switch extended.searchMode {
        case 1: modeExtendedButton.state = .on
        case 2: modeRegexButton.state = .on
        default: modeNormalButton.state = .on
        }
        dotMatchesNewlineButton.state = extended.dotMatchesNewline ? .on : .off
        dotMatchesNewlineButton.isEnabled = extended.searchMode == 2
        wrapAroundButton.state = extended.wrapAround ? .on : .off

        let dialogState = preferencesStore.loadFindDialogState()
        backwardButton.state = dialogState.backwardDirection ? .on : .off
        transparencyCheckbox.state = dialogState.transparencyEnabled ? .on : .off
        transparencyOnFocusRadio.state = dialogState.transparencyOnLosingFocusOnly ? .on : .off
        transparencyAlwaysRadio.state = dialogState.transparencyOnLosingFocusOnly ? .off : .on
        transparencySlider.doubleValue = dialogState.transparencyOpacity
        transparencyOnFocusRadio.isEnabled = dialogState.transparencyEnabled
        transparencyAlwaysRadio.isEnabled = dialogState.transparencyEnabled
        transparencySlider.isEnabled = dialogState.transparencyEnabled
        bookmarkLineButton.state = dialogState.markBookmarkLine ? .on : .off
        purgeButton.state = dialogState.markPurgeForEachSearch ? .on : .off
        if dialogState.collapsed != isCollapsed {
            setCollapsed(dialogState.collapsed)
        }
        applyMonospaceFont(preferences.findDialogMonospace)
    }

    private func saveSearchPreferences() {
        preferencesStore.save(preferencesStore.load().withSearchOptions(makeOptions(direction: nil)))
        let modeIndex = modeRegexButton.state == .on ? 2 : (modeExtendedButton.state == .on ? 1 : 0)
        preferencesStore.saveFindPanelExtendedState(
            searchMode: modeIndex,
            dotMatchesNewline: dotMatchesNewlineButton.state == .on,
            wrapAround: wrapAroundButton.state == .on
        )
        saveFindDialogState()
    }

    private func saveFindDialogState() {
        preferencesStore.saveFindDialogState(FindDialogState(
            backwardDirection: backwardButton.state == .on,
            transparencyEnabled: transparencyCheckbox.state == .on,
            transparencyOnLosingFocusOnly: transparencyOnFocusRadio.state == .on,
            transparencyOpacity: transparencySlider.doubleValue,
            markBookmarkLine: bookmarkLineButton.state == .on,
            markPurgeForEachSearch: purgeButton.state == .on,
            collapsed: isCollapsed
        ))
    }

    // MARK: - Layout

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.delegate = self
        for tab in [Tab.find, .replace, .findInFiles, .findInProjects, .mark] {
            let item = NSTabViewItem(identifier: tab.rawValue)
            item.view = NSView()
            tabView.addTabViewItem(item)
        }

        sharedContainer.translatesAutoresizingMaskIntoConstraints = false

        // Field config
        findField.usesDataSource = false
        findField.completes = true
        replaceField.usesDataSource = false
        replaceField.completes = true

        // Button targets
        findNextButton.target = self
        findNextButton.action = #selector(findNext(_:))
        countButton.target = self
        countButton.action = #selector(countMatches(_:))
        findAllCurrentButton.target = self
        findAllCurrentButton.action = #selector(findAllInCurrentDocument(_:))
        findAllOpenButton.target = self
        findAllOpenButton.action = #selector(findAllInOpenDocuments(_:))
        replaceButton.target = self
        replaceButton.action = #selector(replaceNext(_:))
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAll(_:))
        replaceAllInAllButton.target = self
        replaceAllInAllButton.action = #selector(replaceAllInAll(_:))
        markAllButton.target = self
        markAllButton.action = #selector(markAll(_:))
        clearMarksButton.target = self
        clearMarksButton.action = #selector(clearAllMarks(_:))
        copyMarkedTextButton.target = self
        copyMarkedTextButton.action = #selector(copyMarkedText(_:))
        closeButton.target = self
        closeButton.action = #selector(closeDialog(_:))
        closeButton.keyEquivalent = "\u{1b}"
        inSelectionButton.target = self
        inSelectionButton.action = #selector(inSelectionToggled(_:))
        collapseButton.target = self
        collapseButton.action = #selector(toggleCollapse(_:))
        collapseButton.bezelStyle = .smallSquare
        collapseButton.setButtonType(.momentaryPushIn)

        // Find in Files button targets
        findInFilesFindAllButton.target = self
        findInFilesFindAllButton.action = #selector(findInFilesFindAll(_:))
        findInFilesReplaceAllButton.target = self
        findInFilesReplaceAllButton.action = #selector(findInFilesReplaceAll(_:))
        browseDirectoryButton.target = self
        browseDirectoryButton.action = #selector(browseDirectory(_:))

        for radio in [modeNormalButton, modeExtendedButton, modeRegexButton] {
            radio.target = self
            radio.action = #selector(searchModeChanged(_:))
        }
        for control in [transparencyCheckbox, transparencyOnFocusRadio, transparencyAlwaysRadio] {
            control.target = self
            control.action = #selector(transparencySettingChanged(_:))
        }
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySettingChanged(_:))

        // Find in Files field config
        directoryField.usesDataSource = false
        directoryField.completes = true
        filterField.usesDataSource = false
        filterField.completes = true
        filterField.stringValue = "*"

        // Options stack view — only contains checkbox rows.
        // Hidden arranged subviews detach automatically.
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 6
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.detachesHiddenViews = true

        // Find in Files rows (initially hidden — separate from optionsStack
        // so they use independent constraints with proper field widths)
        directoryLabel.isHidden = true
        directoryField.isHidden = true
        browseDirectoryButton.isHidden = true
        filterLabel.isHidden = true
        filterField.isHidden = true
        purgeBeforeSearchButton.isHidden = true

        // Horizontal rows: backward+bookmarkLine, wholeWord+purge
        // (second column for Mark-tab options, hidden when not needed)
        rowBackward.orientation = .horizontal
        rowBackward.spacing = 0
        rowBackward.alignment = .centerY
        rowBackward.translatesAutoresizingMaskIntoConstraints = false
        rowBackward.addArrangedSubview(backwardButton)
        let spacer1 = NSView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rowBackward.addArrangedSubview(spacer1)
        rowBackward.addArrangedSubview(bookmarkLineButton)

        rowWholeWord.orientation = .horizontal
        rowWholeWord.spacing = 0
        rowWholeWord.alignment = .centerY
        rowWholeWord.translatesAutoresizingMaskIntoConstraints = false
        rowWholeWord.addArrangedSubview(wholeWordButton)
        let spacer2 = NSView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rowWholeWord.addArrangedSubview(spacer2)
        rowWholeWord.addArrangedSubview(purgeButton)

        // Initially hide Mark-tab-only options
        bookmarkLineButton.isHidden = true
        purgeButton.isHidden = true

        // Assemble options stack (checkbox rows only)
        optionsStack.addArrangedSubview(rowBackward)
        optionsStack.addArrangedSubview(rowWholeWord)
        optionsStack.addArrangedSubview(matchCaseButton)
        optionsStack.addArrangedSubview(wrapAroundButton)

        // Search mode group
        searchModeBox.titlePosition = .atTop
        let modeStack = NSStackView(views: [modeNormalButton, modeExtendedButton, modeRegexHStack()])
        modeStack.orientation = .vertical
        modeStack.alignment = .leading
        modeStack.spacing = 4
        modeStack.translatesAutoresizingMaskIntoConstraints = false
        searchModeBox.contentView = NSView()
        searchModeBox.contentView?.addSubview(modeStack)
        NSLayoutConstraint.activate([
            modeStack.leadingAnchor.constraint(equalTo: searchModeBox.contentView!.leadingAnchor, constant: 8),
            modeStack.trailingAnchor.constraint(lessThanOrEqualTo: searchModeBox.contentView!.trailingAnchor, constant: -8),
            modeStack.topAnchor.constraint(equalTo: searchModeBox.contentView!.topAnchor, constant: 4),
            modeStack.bottomAnchor.constraint(equalTo: searchModeBox.contentView!.bottomAnchor, constant: -6),
        ])

        // Transparency group
        transparencyBox.titlePosition = .noTitle
        let transparencyStack = NSStackView(views: [
            transparencyCheckbox, transparencyOnFocusRadio, transparencyAlwaysRadio, transparencySlider,
        ])
        transparencyStack.orientation = .vertical
        transparencyStack.alignment = .leading
        transparencyStack.spacing = 4
        transparencyStack.translatesAutoresizingMaskIntoConstraints = false
        transparencyBox.contentView = NSView()
        transparencyBox.contentView?.addSubview(transparencyStack)
        NSLayoutConstraint.activate([
            transparencyStack.leadingAnchor.constraint(equalTo: transparencyBox.contentView!.leadingAnchor, constant: 8),
            transparencyStack.trailingAnchor.constraint(lessThanOrEqualTo: transparencyBox.contentView!.trailingAnchor, constant: -8),
            transparencyStack.topAnchor.constraint(equalTo: transparencyBox.contentView!.topAnchor, constant: 4),
            transparencyStack.bottomAnchor.constraint(equalTo: transparencyBox.contentView!.bottomAnchor, constant: -6),
            transparencySlider.widthAnchor.constraint(equalToConstant: 140),
            transparencyOnFocusRadio.leadingAnchor.constraint(equalTo: transparencyCheckbox.leadingAnchor, constant: 18),
            transparencyAlwaysRadio.leadingAnchor.constraint(equalTo: transparencyCheckbox.leadingAnchor, constant: 18),
        ])

        statusField.textColor = .secondaryLabelColor
        statusField.lineBreakMode = .byTruncatingTail

        // Assemble shared container
        let shared: [NSView] = [
            findLabel, findField, replaceLabel, replaceField,
            directoryLabel, directoryField, browseDirectoryButton,
            filterLabel, filterField,
            purgeBeforeSearchButton,
            optionsStack,
            inSelectionButton,
            searchModeBox, transparencyBox,
            findNextButton, countButton, findAllCurrentButton, findAllOpenButton,
            replaceButton, replaceAllButton, replaceAllInAllButton,
            findInFilesFindAllButton, findInFilesReplaceAllButton,
            markAllButton, clearMarksButton, copyMarkedTextButton,
            closeButton,
        ]
        shared.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            sharedContainer.addSubview($0)
        }

        contentView.addSubview(tabView)
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        statusField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(collapseButton)
        contentView.addSubview(statusField)

        let buttonColumnWidth: CGFloat = 240

        // Two alternative constraints for optionsStack top anchor:
        // normal mode → below replaceField;  FiF mode → below filterField.
        normalOptionsTop = optionsStack.topAnchor.constraint(
            equalTo: replaceField.bottomAnchor, constant: 18)
        fifOptionsTop = optionsStack.topAnchor.constraint(
            equalTo: filterField.bottomAnchor, constant: 12)
        normalOptionsTop.isActive = true

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),

            statusField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            statusField.trailingAnchor.constraint(lessThanOrEqualTo: collapseButton.leadingAnchor, constant: -8),
            statusField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            statusField.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 6),

            collapseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            collapseButton.centerYAnchor.constraint(equalTo: statusField.centerYAnchor),
            collapseButton.widthAnchor.constraint(equalToConstant: 28),
            collapseButton.heightAnchor.constraint(equalToConstant: 20),

            // Find target row. The label column has a fixed width so both
            // fields share one stable left edge; the combo box pins both
            // edges (leading == label trailing) so it can't collapse.
            findLabel.leadingAnchor.constraint(equalTo: sharedContainer.leadingAnchor, constant: 12),
            findLabel.centerYAnchor.constraint(equalTo: findField.centerYAnchor),
            findLabel.widthAnchor.constraint(equalToConstant: 88),

            findField.leadingAnchor.constraint(equalTo: findLabel.trailingAnchor, constant: 8),
            findField.topAnchor.constraint(equalTo: sharedContainer.topAnchor, constant: 14),
            findField.trailingAnchor.constraint(equalTo: findNextButton.leadingAnchor, constant: -12),

            // Replace row
            replaceLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            replaceLabel.centerYAnchor.constraint(equalTo: replaceField.centerYAnchor),
            replaceLabel.widthAnchor.constraint(equalTo: findLabel.widthAnchor),
            replaceField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            replaceField.trailingAnchor.constraint(equalTo: findField.trailingAnchor),
            replaceField.topAnchor.constraint(equalTo: findField.bottomAnchor, constant: 10),

            // Find in Files: Directory row (between replace and optionsStack)
            directoryLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            directoryLabel.centerYAnchor.constraint(equalTo: directoryField.centerYAnchor),
            directoryLabel.widthAnchor.constraint(equalToConstant: 88),
            directoryField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            directoryField.trailingAnchor.constraint(equalTo: browseDirectoryButton.leadingAnchor, constant: -8),
            directoryField.topAnchor.constraint(equalTo: replaceField.bottomAnchor, constant: 10),
            browseDirectoryButton.trailingAnchor.constraint(equalTo: findField.trailingAnchor),
            browseDirectoryButton.centerYAnchor.constraint(equalTo: directoryField.centerYAnchor),

            // Find in Files: Filter row
            filterLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            filterLabel.centerYAnchor.constraint(equalTo: filterField.centerYAnchor),
            filterLabel.widthAnchor.constraint(equalToConstant: 88),
            filterField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            filterField.trailingAnchor.constraint(equalTo: findField.trailingAnchor),
            filterField.topAnchor.constraint(equalTo: directoryField.bottomAnchor, constant: 10),

            // Find in Files: Purge checkbox
            purgeBeforeSearchButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            purgeBeforeSearchButton.topAnchor.constraint(equalTo: filterField.bottomAnchor, constant: 8),

            // Options stack (positioned by normalOptionsTop / fifOptionsTop)
            optionsStack.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),

            // In selection (next to the button column, upstream placement)
            inSelectionButton.trailingAnchor.constraint(equalTo: findNextButton.leadingAnchor, constant: -12),
            inSelectionButton.centerYAnchor.constraint(equalTo: findAllCurrentButton.centerYAnchor),

            // Right button column
            findNextButton.topAnchor.constraint(equalTo: sharedContainer.topAnchor, constant: 12),
            findNextButton.trailingAnchor.constraint(equalTo: sharedContainer.trailingAnchor, constant: -12),
            findNextButton.widthAnchor.constraint(equalToConstant: buttonColumnWidth),

            countButton.topAnchor.constraint(equalTo: findNextButton.bottomAnchor, constant: 8),
            countButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            countButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            findAllCurrentButton.topAnchor.constraint(equalTo: countButton.bottomAnchor, constant: 8),
            findAllCurrentButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            findAllCurrentButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            findAllOpenButton.topAnchor.constraint(equalTo: findAllCurrentButton.bottomAnchor, constant: 8),
            findAllOpenButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            findAllOpenButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            replaceButton.topAnchor.constraint(equalTo: findNextButton.bottomAnchor, constant: 8),
            replaceButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            replaceButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            replaceAllButton.topAnchor.constraint(equalTo: replaceButton.bottomAnchor, constant: 8),
            replaceAllButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            replaceAllButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            replaceAllInAllButton.topAnchor.constraint(equalTo: replaceAllButton.bottomAnchor, constant: 8),
            replaceAllInAllButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            replaceAllInAllButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            // Find in Files buttons (same column, shown when tab active)
            findInFilesFindAllButton.topAnchor.constraint(equalTo: sharedContainer.topAnchor, constant: 12),
            findInFilesFindAllButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            findInFilesFindAllButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            findInFilesReplaceAllButton.topAnchor.constraint(equalTo: findInFilesFindAllButton.bottomAnchor, constant: 8),
            findInFilesReplaceAllButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            findInFilesReplaceAllButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            markAllButton.topAnchor.constraint(equalTo: sharedContainer.topAnchor, constant: 12),
            markAllButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            markAllButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            clearMarksButton.topAnchor.constraint(equalTo: markAllButton.bottomAnchor, constant: 8),
            clearMarksButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            clearMarksButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            copyMarkedTextButton.topAnchor.constraint(equalTo: clearMarksButton.bottomAnchor, constant: 8),
            copyMarkedTextButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            copyMarkedTextButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            closeButton.topAnchor.constraint(equalTo: findAllOpenButton.bottomAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            closeButton.widthAnchor.constraint(equalTo: findNextButton.widthAnchor),

            // Bottom groups
            searchModeBox.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            searchModeBox.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 12),

            transparencyBox.trailingAnchor.constraint(equalTo: findNextButton.trailingAnchor),
            transparencyBox.topAnchor.constraint(equalTo: searchModeBox.topAnchor),
            transparencyBox.leadingAnchor.constraint(greaterThanOrEqualTo: searchModeBox.trailingAnchor, constant: 16),
        ])

        // Constraints released when collapsing the lower section.
        let expandedBottom = sharedContainer.bottomAnchor.constraint(greaterThanOrEqualTo: searchModeBox.bottomAnchor, constant: 14)
        let expandedBottom2 = sharedContainer.bottomAnchor.constraint(greaterThanOrEqualTo: transparencyBox.bottomAnchor, constant: 14)
        let expandedBottom3 = sharedContainer.bottomAnchor.constraint(greaterThanOrEqualTo: closeButton.bottomAnchor, constant: 14)
        bottomSectionConstraints = [expandedBottom, expandedBottom2, expandedBottom3]
        NSLayoutConstraint.activate(bottomSectionConstraints)
        let collapsedBottom = sharedContainer.bottomAnchor.constraint(greaterThanOrEqualTo: optionsStack.bottomAnchor, constant: 14)
        collapsedBottomConstraint = collapsedBottom

        // Initial tab
        tabView.selectTabViewItem(at: 0)
        currentTab = .find
        if let item = tabView.selectedTabViewItem {
            moveSharedContainer(into: item)
        }
        applyTabVisibility()
    }

    private func modeRegexHStack() -> NSStackView {
        let stack = NSStackView(views: [modeRegexButton, dotMatchesNewlineButton])
        stack.orientation = .horizontal
        stack.spacing = 12
        return stack
    }

    private func setStatus(_ message: String, isError: Bool = false) {
        statusField.stringValue = message
        statusField.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    // MARK: - Localization

    private func refreshLocalizedStrings() {
        refreshWindowTitle()
        let items = tabView.tabViewItems
        if items.count == 5 {
            items[0].label = Localization.string(.findTabFind, default: "Find")
            items[1].label = Localization.string(.findTabReplace, default: "Replace")
            items[2].label = Localization.string(.findTabFindInFiles, default: "Find in Files")
            items[3].label = Localization.string(.findTabFindInProjects, default: "Find in Projects")
            items[4].label = Localization.string(.findTabMark, default: "Mark")
        }
        findLabel.stringValue = Localization.string(.findWhatLabel, default: "Find what:")
        replaceLabel.stringValue = Localization.string(.findReplaceWithLabel, default: "Replace with:")
        backwardButton.title = Localization.string(.findBackwardDirection, default: "Backward direction")
        wholeWordButton.title = Localization.string(.findWholeWordOnly, default: "Match whole word only")
        matchCaseButton.title = Localization.string(.findMatchCase, default: "Match case")
        wrapAroundButton.title = Localization.string(.findWrapAround, default: "Wrap around")
        inSelectionButton.title = Localization.string(.findInSelection, default: "In selection")
        bookmarkLineButton.title = Localization.string(.findMarkBookmarkLine, default: "Bookmark line")
        purgeButton.title = Localization.string(.findMarkPurge, default: "Purge for each search")
        searchModeBox.title = Localization.string(.findSearchModeLabel, default: "Search Mode")
        modeNormalButton.title = Localization.string(.findModeNormal, default: "Normal")
        modeExtendedButton.title = Localization.string(
            .findModeExtendedFull, default: "Extended (\\n, \\r, \\t, \\0, \\x...)")
        modeRegexButton.title = Localization.string(.findModeRegexFull, default: "Regular expression")
        dotMatchesNewlineButton.title = Localization.string(.findDotMatchesNewline, default: ". matches newline")
        transparencyCheckbox.title = Localization.string(.findTransparency, default: "Transparency")
        transparencyOnFocusRadio.title = Localization.string(.findTransparencyOnFocus, default: "On losing focus")
        transparencyAlwaysRadio.title = Localization.string(.findTransparencyAlways, default: "Always")
        findNextButton.title = Localization.string(.findNextButton, default: "Find Next")
        countButton.title = Localization.string(.findCountButton, default: "Count")
        findAllCurrentButton.title = Localization.string(.findAllInCurrentButton, default: "Find All in Current Document")
        findAllOpenButton.title = Localization.string(.findAllInOpenButton, default: "Find All in All Opened Documents")
        replaceButton.title = Localization.string(.findReplaceButton, default: "Replace")
        replaceAllButton.title = Localization.string(.findReplaceAllButton, default: "Replace All")
        replaceAllInAllButton.title = Localization.string(
            .findReplaceAllInAllDocsButton, default: "Replace All in All Opened Documents")
        markAllButton.title = Localization.string(.findMarkAllButton, default: "Mark All")
        clearMarksButton.title = Localization.string(.findClearMarksButton, default: "Clear all marks")
        copyMarkedTextButton.title = Localization.string(.findCopyMarkedTextButton, default: "Copy Marked Text")
        closeButton.title = Localization.string(.findCloseButton, default: "Close")
        // Find in Files controls
        directoryLabel.stringValue = Localization.string(.findInFilesDirectoryLabel, default: "Directory:")
        browseDirectoryButton.title = Localization.string(.findInFilesBrowse, default: "Browse...")
        filterLabel.stringValue = Localization.string(.findInFilesFilterLabel, default: "Filter:")
        purgeBeforeSearchButton.title = Localization.string(.findInFilesPurgeBeforeSearch, default: "Purge before each search")
        findInFilesFindAllButton.title = Localization.string(.findInFilesFindButton, default: "Find All")
        findInFilesReplaceAllButton.title = Localization.string(.findInFilesReplaceAllButton, default: "Replace All")
    }

    private func localizedString(_ key: Localization.Key, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: Localization.string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }

    private func isWordChar(_ ch: UInt16) -> Bool {
        guard let scalar = Unicode.Scalar(ch) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == Unicode.Scalar("_")
    }

    // MARK: - NSWindowDelegate (transparency)

    private func applyTransparencyForKeyState(isKey: Bool) {
        guard transparencyCheckbox.state == .on else {
            window?.alphaValue = 1.0
            return
        }
        let opacity = CGFloat(transparencySlider.doubleValue)
        if transparencyAlwaysRadio.state == .on {
            window?.alphaValue = opacity
        } else {
            window?.alphaValue = isKey ? 1.0 : opacity
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        applyTransparencyForKeyState(isKey: true)
        updateInSelectionEnabled()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Legacy preference (slider in Preferences) still wins when set.
        let legacy = preferencesStore.load().findDialogTransparency
        if transparencyCheckbox.state == .off, legacy > 0 {
            window?.alphaValue = max(0.1, 1.0 - legacy)
            return
        }
        applyTransparencyForKeyState(isKey: false)
    }
}
