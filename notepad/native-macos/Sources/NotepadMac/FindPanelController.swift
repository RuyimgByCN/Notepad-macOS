import AppKit
import NotepadMacCore

@MainActor
final class FindPanelController: NSWindowController, NSWindowDelegate {
    private weak var editor: EditorWindowController?
    private let preferencesStore: PreferencesStore

    private let findField = NSTextField(string: "")
    private let replaceField = NSTextField(string: "")
    private let findLabel = NSTextField(labelWithString: "")
    private let replaceLabel = NSTextField(labelWithString: "")
    private let directionLabel = NSTextField(labelWithString: "")
    private let matchCaseButton = NSButton(
        checkboxWithTitle: Localization.string(.findMatchCase, default: "Match Case"),
        target: nil,
        action: nil
    )
    private let wholeWordButton = NSButton(
        checkboxWithTitle: Localization.string(.findWholeWord, default: "Whole Word"),
        target: nil,
        action: nil
    )
    private let wrapAroundButton = NSButton(
        checkboxWithTitle: Localization.string(.findWrapAround, default: "Wrap Around"),
        target: nil,
        action: nil
    )
    private let inSelectionButton = NSButton(
        checkboxWithTitle: Localization.string(.findInSelection, default: "In Selection"),
        target: nil,
        action: nil
    )
    /// The selection range captured when "In Selection" is first activated.
    private var inSelectionAnchor: NSRange?
    private let directionControl = NSSegmentedControl()
    private let searchModeControl = NSSegmentedControl()
    private let dotMatchesNewlineButton = NSButton(checkboxWithTitle: ". matches newline", target: nil, action: nil)
    private let statusField = NSTextField(labelWithString: "")
    private let findButton = NSButton(title: "", target: nil, action: nil)
    private let replaceButton = NSButton(title: "", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "", target: nil, action: nil)
    private let bookmarkAllButton = NSButton(title: "", target: nil, action: nil)
    private let replaceAllInAllButton = NSButton(title: "", target: nil, action: nil)
    private lazy var historyButton = NSButton(title: "\u{25BE}", target: self, action: #selector(showFindHistory(_:)))
    private lazy var replaceHistoryButton = NSButton(title: "\u{25BE}", target: self, action: #selector(showReplaceHistory(_:)))

    init(editor: EditorWindowController, preferencesStore: PreferencesStore) {
        self.editor = editor
        self.preferencesStore = preferencesStore

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 295),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

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

    func show(focusedOnReplace: Bool = false) {
        loadPreferences()
        // Auto-fill find field with selected text or word under caret
        if let editor, !focusedOnReplace {
            let surface = editor.editorSurface
            let selection = surface.selectedRange
            let text = surface.text as NSString
            // Auto-check "In Selection" when selection spans multiple lines or meets the configured threshold
            let threshold = preferencesStore.load().inSelectionThreshold
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
            if selection.length > 0, NSMaxRange(selection) <= text.length {
                findField.stringValue = selHasNewline ? "" : selText
            } else {
                // Auto-select word under caret
                let loc = min(selection.location, text.length)
                var start = loc
                var end = loc
                while start > 0 {
                    let ch = text.character(at: start - 1)
                    if !isWordChar(ch) { break }
                    start -= 1
                }
                while end < text.length {
                    let ch = text.character(at: end)
                    if !isWordChar(ch) { break }
                    end += 1
                }
                if end > start {
                    let wordRange = NSRange(location: start, length: end - start)
                    surface.setSelectedRange(wordRange)
                    findField.stringValue = text.substring(with: wordRange)
                }
            }
        }
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(focusedOnReplace ? replaceField : findField)
        if !focusedOnReplace {
            findField.selectText(nil)
        }
    }

    private func isWordChar(_ ch: UInt16) -> Bool {
        guard let scalar = Unicode.Scalar(ch) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == Unicode.Scalar("_")
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    func findNextFromMenu() {
        guard !findField.stringValue.isEmpty else {
            show()
            return
        }
        performFind(options: options)
    }

    func findPreviousFromMenu() {
        guard !findField.stringValue.isEmpty else {
            show()
            return
        }
        performFind(options: makeOptions(direction: .up))
    }

    @objc private func findNext(_ sender: Any?) {
        performFind(options: options)
    }

    private func performFind(options searchOptions: TextSearch.Options) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        if editor?.performFind(query: findField.stringValue, options: searchOptions) == true {
            statusField.stringValue = Localization.string(.findStatusFound, default: "Found.")
        } else {
            statusField.stringValue = Localization.string(.findStatusNoMatches, default: "No matches.")
        }
    }

    private func addToFindHistory(_ query: String) {
        var history = preferencesStore.loadFindHistory()
        history.removeAll { $0 == query }
        history.insert(query, at: 0)
        preferencesStore.saveFindHistory(history)
    }

    private func addToReplaceHistory(_ query: String) {
        guard !query.isEmpty else { return }
        var history = preferencesStore.loadReplaceHistory()
        history.removeAll { $0 == query }
        history.insert(query, at: 0)
        preferencesStore.saveReplaceHistory(history)
    }

    @objc private func showFindHistory(_ sender: Any?) {
        let history = preferencesStore.loadFindHistory()
        guard !history.isEmpty else { return }

        let menu = NSMenu()
        for query in history {
            let item = NSMenuItem(title: query, action: #selector(selectFindHistoryItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = query
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: Localization.string(.findHistoryClear, default: "Clear History"), action: #selector(clearFindHistory(_:)), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        if let button = sender as? NSButton {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    @objc private func selectFindHistoryItem(_ sender: NSMenuItem) {
        if let query = sender.representedObject as? String {
            findField.stringValue = query
        }
    }

    @objc private func clearFindHistory(_ sender: Any?) {
        preferencesStore.saveFindHistory([])
    }

    @objc private func showReplaceHistory(_ sender: Any?) {
        let history = preferencesStore.loadReplaceHistory()
        guard !history.isEmpty else { return }
        let menu = NSMenu()
        for query in history {
            let item = NSMenuItem(title: query, action: #selector(selectReplaceHistoryItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = query
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: Localization.string(.findHistoryClear, default: "Clear History"), action: #selector(clearReplaceHistory(_:)), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        if let button = sender as? NSButton {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    @objc private func selectReplaceHistoryItem(_ sender: NSMenuItem) {
        if let query = sender.representedObject as? String {
            replaceField.stringValue = query
        }
    }

    @objc private func clearReplaceHistory(_ sender: Any?) {
        preferencesStore.saveReplaceHistory([])
    }

    @objc private func replaceNext(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        addToReplaceHistory(replaceField.stringValue)
        if editor?.performReplace(query: findField.stringValue, replacement: replaceField.stringValue, options: options) == true {
            statusField.stringValue = Localization.string(.findStatusReplaced, default: "Replaced.")
        } else {
            statusField.stringValue = Localization.string(.findStatusNoMatches, default: "No matches.")
        }
    }

    @objc private func replaceAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        addToFindHistory(findField.stringValue)
        addToReplaceHistory(replaceField.stringValue)
        let count = editor?.performReplaceAll(query: findField.stringValue, replacement: replaceField.stringValue, options: options) ?? 0
        statusField.stringValue = localizedString(
            .findStatusReplacementCount,
            default: "%d replacement(s).",
            count
        )
        if !preferencesStore.load().keepFindDialogOpen {
            close()
        }
    }

    @objc private func replaceAllInAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }
        saveSearchPreferences()
        let query = findField.stringValue
        let replacement = replaceField.stringValue
        let searchOptions = options

        // Ask AppDelegate to replace in all open windows
        var totalCount = 0
        if let appDelegate = NSApp.delegate as? AppDelegate {
            totalCount = appDelegate.replaceInAllOpenDocuments(query: query, replacement: replacement, options: searchOptions)
        }
        statusField.stringValue = localizedString(
            .findStatusReplacementCount,
            default: "%d replacement(s).",
            totalCount
        )
    }

    @objc private func bookmarkAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        let result = editor?.performBookmarkAllMatches(query: findField.stringValue, options: options) ?? (matchCount: 0, lineCount: 0)
        guard result.matchCount > 0 else {
            statusField.stringValue = Localization.string(.findStatusNoMatches, default: "No matches.")
            return
        }

        statusField.stringValue = localizedString(
            .findStatusBookmarkCount,
            default: "Bookmarked %d match(es) on %d line(s).",
            result.matchCount,
            result.lineCount
        )
    }

    private var options: TextSearch.Options {
        makeOptions(direction: nil)
    }

    private func makeOptions(direction: TextSearch.Direction?) -> TextSearch.Options {
        let modes: [TextSearch.SearchMode] = [.normal, .extended, .regex]
        let modeIndex = max(0, min(searchModeControl.selectedSegment, modes.count - 1))
        let useInSelection = inSelectionButton.state == .on
        if useInSelection, inSelectionAnchor == nil {
            inSelectionAnchor = editor?.editorSurface.selectedRange
        }
        if !useInSelection { inSelectionAnchor = nil }
        return TextSearch.Options(
            matchCase: matchCaseButton.state == .on,
            wholeWord: wholeWordButton.state == .on,
            wraps: wrapAroundButton.state == .on,
            direction: direction ?? (directionControl.selectedSegment == 1 ? .up : .down),
            searchMode: modes[modeIndex],
            dotMatchesLineSeparators: dotMatchesNewlineButton.state == .on,
            searchRange: inSelectionAnchor
        )
    }

    private func loadPreferences() {
        let preferences = preferencesStore.load()
        matchCaseButton.state = preferences.searchMatchCase ? .on : .off
        wholeWordButton.state = preferences.searchWholeWord ? .on : .off
        let extended = preferencesStore.loadFindPanelExtendedState()
        searchModeControl.selectedSegment = extended.searchMode
        dotMatchesNewlineButton.state = extended.dotMatchesNewline ? .on : .off
        wrapAroundButton.state = extended.wrapAround ? .on : .off
    }

    private func saveSearchPreferences() {
        preferencesStore.save(preferencesStore.load().withSearchOptions(options))
        let modeIndex = searchModeControl.selectedSegment
        preferencesStore.saveFindPanelExtendedState(
            searchMode: modeIndex,
            dotMatchesNewline: dotMatchesNewlineButton.state == .on,
            wrapAround: wrapAroundButton.state == .on
        )
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        directionControl.segmentCount = 2
        directionControl.trackingMode = .selectOne
        directionControl.selectedSegment = 0
        searchModeControl.segmentCount = 3
        searchModeControl.trackingMode = .selectOne
        searchModeControl.selectedSegment = 0
        searchModeControl.setLabel(Localization.string(.findModeNormal, default: "Normal"), forSegment: 0)
        searchModeControl.setLabel(Localization.string(.findModeExtended, default: "Extended"), forSegment: 1)
        searchModeControl.setLabel(Localization.string(.findModeRegex, default: "Regex"), forSegment: 2)
        wrapAroundButton.state = .on
        findButton.target = self
        findButton.action = #selector(findNext(_:))
        replaceButton.target = self
        replaceButton.action = #selector(replaceNext(_:))
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAll(_:))
        bookmarkAllButton.target = self
        bookmarkAllButton.action = #selector(bookmarkAll(_:))
        replaceAllInAllButton.target = self
        replaceAllInAllButton.action = #selector(replaceAllInAll(_:))

        historyButton.translatesAutoresizingMaskIntoConstraints = false
        historyButton.bezelStyle = .inline
        historyButton.isBordered = false
        historyButton.font = .systemFont(ofSize: 11)
        historyButton.setAccessibilityLabel("Find History")

        dotMatchesNewlineButton.toolTip = "Only applies to Regex search mode"
        [findLabel, replaceLabel, directionLabel, findField, replaceField, matchCaseButton, wholeWordButton, wrapAroundButton, inSelectionButton, directionControl, searchModeControl, dotMatchesNewlineButton, findButton, replaceButton, replaceAllButton, replaceAllInAllButton, bookmarkAllButton, statusField, historyButton, replaceHistoryButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        statusField.textColor = .secondaryLabelColor
        findButton.keyEquivalent = "\r"

        NSLayoutConstraint.activate([
            findLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            findLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            findLabel.widthAnchor.constraint(equalToConstant: 70),

            historyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            historyButton.centerYAnchor.constraint(equalTo: findLabel.centerYAnchor),
            historyButton.widthAnchor.constraint(equalToConstant: 20),

            findField.leadingAnchor.constraint(equalTo: findLabel.trailingAnchor, constant: 10),
            findField.trailingAnchor.constraint(equalTo: historyButton.leadingAnchor, constant: -4),
            findField.centerYAnchor.constraint(equalTo: findLabel.centerYAnchor),

            replaceLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            replaceLabel.topAnchor.constraint(equalTo: findLabel.bottomAnchor, constant: 16),
            replaceLabel.widthAnchor.constraint(equalTo: findLabel.widthAnchor),

            replaceHistoryButton.trailingAnchor.constraint(equalTo: historyButton.trailingAnchor),
            replaceHistoryButton.centerYAnchor.constraint(equalTo: replaceLabel.centerYAnchor),
            replaceHistoryButton.widthAnchor.constraint(equalToConstant: 20),

            replaceField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            replaceField.trailingAnchor.constraint(equalTo: replaceHistoryButton.leadingAnchor, constant: -4),
            replaceField.centerYAnchor.constraint(equalTo: replaceLabel.centerYAnchor),

            matchCaseButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            matchCaseButton.topAnchor.constraint(equalTo: replaceField.bottomAnchor, constant: 14),

            wholeWordButton.leadingAnchor.constraint(equalTo: matchCaseButton.trailingAnchor, constant: 20),
            wholeWordButton.centerYAnchor.constraint(equalTo: matchCaseButton.centerYAnchor),

            directionLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            directionLabel.topAnchor.constraint(equalTo: matchCaseButton.bottomAnchor, constant: 14),
            directionLabel.widthAnchor.constraint(equalTo: findLabel.widthAnchor),

            directionControl.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            directionControl.centerYAnchor.constraint(equalTo: directionLabel.centerYAnchor),

            wrapAroundButton.leadingAnchor.constraint(equalTo: directionControl.trailingAnchor, constant: 20),
            wrapAroundButton.centerYAnchor.constraint(equalTo: directionControl.centerYAnchor),

            inSelectionButton.leadingAnchor.constraint(equalTo: wrapAroundButton.trailingAnchor, constant: 20),
            inSelectionButton.centerYAnchor.constraint(equalTo: directionControl.centerYAnchor),

            searchModeControl.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            searchModeControl.topAnchor.constraint(equalTo: directionControl.bottomAnchor, constant: 10),

            dotMatchesNewlineButton.leadingAnchor.constraint(equalTo: searchModeControl.trailingAnchor, constant: 16),
            dotMatchesNewlineButton.centerYAnchor.constraint(equalTo: searchModeControl.centerYAnchor),

            findButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            findButton.topAnchor.constraint(equalTo: searchModeControl.bottomAnchor, constant: 16),

            replaceButton.leadingAnchor.constraint(equalTo: findButton.trailingAnchor, constant: 10),
            replaceButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            replaceAllButton.leadingAnchor.constraint(equalTo: replaceButton.trailingAnchor, constant: 10),
            replaceAllButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            replaceAllInAllButton.leadingAnchor.constraint(equalTo: replaceAllButton.trailingAnchor, constant: 10),
            replaceAllInAllButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            bookmarkAllButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            bookmarkAllButton.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 10),

            statusField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            statusField.trailingAnchor.constraint(equalTo: findField.trailingAnchor),
            statusField.topAnchor.constraint(equalTo: bookmarkAllButton.bottomAnchor, constant: 12)
        ])
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.findPanelTitle, default: "Find and Replace")
        findLabel.stringValue = Localization.string(.findLabel, default: "Find")
        replaceLabel.stringValue = Localization.string(.findReplaceLabel, default: "Replace")
        directionLabel.stringValue = Localization.string(.findDirectionLabel, default: "Direction")
        matchCaseButton.title = Localization.string(.findMatchCase, default: "Match Case")
        wholeWordButton.title = Localization.string(.findWholeWord, default: "Whole Word")
        wrapAroundButton.title = Localization.string(.findWrapAround, default: "Wrap Around")
        inSelectionButton.title = Localization.string(.findInSelection, default: "In Selection")
        directionControl.setLabel(Localization.string(.findDirectionDown, default: "Down"), forSegment: 0)
        directionControl.setLabel(Localization.string(.findDirectionUp, default: "Up"), forSegment: 1)
        searchModeControl.setLabel(Localization.string(.findModeNormal, default: "Normal"), forSegment: 0)
        searchModeControl.setLabel(Localization.string(.findModeExtended, default: "Extended"), forSegment: 1)
        searchModeControl.setLabel(Localization.string(.findModeRegex, default: "Regex"), forSegment: 2)
        findButton.title = Localization.string(.findNextButton, default: "Find Next")
        replaceButton.title = Localization.string(.findReplaceButton, default: "Replace")
        replaceAllButton.title = Localization.string(.findReplaceAllButton, default: "Replace All")
        replaceAllInAllButton.title = Localization.string(.findReplaceAllInAllButton, default: "In All Open Docs")
        bookmarkAllButton.title = Localization.string(.findBookmarkAllButton, default: "Bookmark All")
    }

    private func localizedString(_ key: Localization.Key, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: Localization.string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }

    // MARK: - NSWindowDelegate (transparency on focus change)

    func windowDidBecomeKey(_ notification: Notification) {
        window?.alphaValue = 1.0
    }

    func windowDidResignKey(_ notification: Notification) {
        let t = preferencesStore.load().findDialogTransparency
        if t > 0 {
            window?.alphaValue = max(0.1, 1.0 - t)
        }
    }
}
