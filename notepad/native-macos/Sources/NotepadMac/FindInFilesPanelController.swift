import AppKit
import NotepadMacCore

@MainActor
final class FindInFilesPanelController: NSWindowController {
    private weak var editor: EditorWindowController?

    private let findField = NSTextField(string: "")
    private let directoryField = NSTextField(string: "")
    private let filterField = NSTextField(string: "")
    private let findLabel = NSTextField(labelWithString: "")
    private let directoryLabel = NSTextField(labelWithString: "")
    private let filterLabel = NSTextField(labelWithString: "")
    private let matchCaseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wholeWordButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let searchModeControl = NSSegmentedControl()
    private let replaceField = NSTextField(string: "")
    private let replaceLabel = NSTextField(labelWithString: "")
    private let findButton = NSButton(title: "", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let browseButton = NSButton(title: "", target: nil, action: nil)
    private let statusField = NSTextField(labelWithString: "")
    private let resultsScrollView = NSScrollView()
    private let resultsTable = NSTableView()
    private var results: [FindInFilesResult] = []

    private struct FindInFilesResult {
        let filePath: String
        let line: Int
        let column: Int
        let lineText: String
    }

    init(editor: EditorWindowController) {
        self.editor = editor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 500, height: 350)

        super.init(window: panel)
        configureContent()
        refreshLocalizedStrings()
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

    func show(searchRoot: URL? = nil) {
        refreshLocalizedStrings()
        if let root = searchRoot {
            directoryField.stringValue = root.path
        } else if directoryField.stringValue.isEmpty,
                  let editorURL = editor?.sessionFileURL {
            // Auto-fill directory from active document's directory
            directoryField.stringValue = editorURL.deletingLastPathComponent().path
        }
        // Auto-fill find field from current selection
        if let editor {
            let sel = editor.editorSurface.selectedRange
            let text = editor.editorSurface.text as NSString
            if sel.length > 0, NSMaxRange(sel) <= text.length {
                findField.stringValue = text.substring(with: sel)
            }
        }
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(findField)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.findInFilesPanelTitle, default: "Find in Files")
        findLabel.stringValue = Localization.string(.findInFilesFindLabel, default: "Find what:")
        directoryLabel.stringValue = Localization.string(.findInFilesDirectoryLabel, default: "Directory:")
        filterLabel.stringValue = Localization.string(.findInFilesFilterLabel, default: "Filter:")
        matchCaseButton.title = Localization.string(.findMatchCase, default: "Match Case")
        wholeWordButton.title = Localization.string(.findWholeWord, default: "Whole Word")
        searchModeControl.setLabel(Localization.string(.findModeNormal, default: "Normal"), forSegment: 0)
        searchModeControl.setLabel(Localization.string(.findModeExtended, default: "Extended"), forSegment: 1)
        searchModeControl.setLabel(Localization.string(.findModeRegex, default: "Regex"), forSegment: 2)
        findButton.title = Localization.string(.findInFilesFindButton, default: "Find All")
        replaceAllButton.title = Localization.string(.findInFilesReplaceAllButton, default: "Replace All")
        cancelButton.title = Localization.string(.alertCancel, default: "Cancel")
        browseButton.title = Localization.string(.findInFilesBrowse, default: "Browse...")
        replaceLabel.stringValue = Localization.string(.findReplaceLabel, default: "Replace:")
        replaceField.placeholderString = Localization.string(.findInFilesReplacePlaceholder, default: "Replacement text")
        findField.placeholderString = Localization.string(.findInFilesFindPlaceholder, default: "Search term")
        directoryField.placeholderString = Localization.string(.findInFilesDirectoryPlaceholder, default: "Directory path")
        filterField.placeholderString = Localization.string(.findInFilesFilterPlaceholder, default: "*.txt, *.swift")
        findField.setAccessibilityLabel(Localization.string(.findInFilesFindLabel, default: "Find what:"))
        directoryField.setAccessibilityLabel(Localization.string(.findInFilesDirectoryLabel, default: "Directory:"))
        filterField.setAccessibilityLabel(Localization.string(.findInFilesFilterLabel, default: "Filter:"))
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        findButton.target = self
        findButton.action = #selector(performFind(_:))
        replaceAllButton.target = self
        replaceAllButton.action = #selector(performReplaceAll(_:))
        replaceAllButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(closePanel(_:))
        browseButton.target = self
        browseButton.action = #selector(browseDirectory(_:))

        filterField.stringValue = "*"

        // Configure results table
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.title = ""
        resultsTable.addTableColumn(column)
        resultsTable.headerView = nil
        resultsTable.style = .plain
        resultsTable.usesAlternatingRowBackgroundColors = true
        resultsTable.target = self
        resultsTable.doubleAction = #selector(resultDoubleClicked(_:))
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.menu = buildResultsContextMenu()
        resultsScrollView.documentView = resultsTable
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.borderType = .bezelBorder

        searchModeControl.segmentCount = 3
        searchModeControl.trackingMode = .selectOne
        searchModeControl.selectedSegment = 0
        searchModeControl.setLabel(Localization.string(.findModeNormal, default: "Normal"), forSegment: 0)
        searchModeControl.setLabel(Localization.string(.findModeExtended, default: "Extended"), forSegment: 1)
        searchModeControl.setLabel(Localization.string(.findModeRegex, default: "Regex"), forSegment: 2)

        let allViews: [NSView] = [
            findLabel, findField,
            replaceLabel, replaceField,
            directoryLabel, directoryField, browseButton,
            filterLabel, filterField,
            matchCaseButton, wholeWordButton, searchModeControl,
            findButton, replaceAllButton, cancelButton,
            statusField,
            resultsScrollView
        ]

        for view in allViews {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            // Find field
            findLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            findLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            findLabel.widthAnchor.constraint(equalToConstant: 72),

            findField.leadingAnchor.constraint(equalTo: findLabel.trailingAnchor, constant: 8),
            findField.centerYAnchor.constraint(equalTo: findLabel.centerYAnchor),
            findField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            // Replace field
            replaceLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            replaceLabel.topAnchor.constraint(equalTo: findLabel.bottomAnchor, constant: 12),
            replaceLabel.widthAnchor.constraint(equalToConstant: 72),

            replaceField.leadingAnchor.constraint(equalTo: replaceLabel.trailingAnchor, constant: 8),
            replaceField.centerYAnchor.constraint(equalTo: replaceLabel.centerYAnchor),
            replaceField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            // Directory field
            directoryLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            directoryLabel.topAnchor.constraint(equalTo: replaceLabel.bottomAnchor, constant: 12),
            directoryLabel.widthAnchor.constraint(equalToConstant: 72),

            directoryField.leadingAnchor.constraint(equalTo: directoryLabel.trailingAnchor, constant: 8),
            directoryField.centerYAnchor.constraint(equalTo: directoryLabel.centerYAnchor),
            directoryField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -8),

            browseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            browseButton.centerYAnchor.constraint(equalTo: directoryField.centerYAnchor),

            // Filter field
            filterLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            filterLabel.topAnchor.constraint(equalTo: directoryLabel.bottomAnchor, constant: 12),
            filterLabel.widthAnchor.constraint(equalToConstant: 72),

            filterField.leadingAnchor.constraint(equalTo: filterLabel.trailingAnchor, constant: 8),
            filterField.centerYAnchor.constraint(equalTo: filterLabel.centerYAnchor),
            filterField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            // Checkboxes
            matchCaseButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            matchCaseButton.topAnchor.constraint(equalTo: filterLabel.bottomAnchor, constant: 12),

            wholeWordButton.leadingAnchor.constraint(equalTo: matchCaseButton.trailingAnchor, constant: 20),
            wholeWordButton.centerYAnchor.constraint(equalTo: matchCaseButton.centerYAnchor),

            searchModeControl.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            searchModeControl.topAnchor.constraint(equalTo: matchCaseButton.bottomAnchor, constant: 10),

            // Buttons
            findButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            findButton.topAnchor.constraint(equalTo: searchModeControl.bottomAnchor, constant: 14),

            replaceAllButton.trailingAnchor.constraint(equalTo: findButton.leadingAnchor, constant: -12),
            replaceAllButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            cancelButton.trailingAnchor.constraint(equalTo: replaceAllButton.leadingAnchor, constant: -12),
            cancelButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            // Status
            statusField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statusField.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 14),

            // Results
            resultsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            resultsScrollView.topAnchor.constraint(equalTo: statusField.bottomAnchor, constant: 8),
            resultsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            resultsScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])
    }

    @objc private func performReplaceAll(_ sender: Any?) {
        let query = findField.stringValue
        let replacement = replaceField.stringValue
        let directory = directoryField.stringValue

        guard !query.isEmpty, !directory.isEmpty else {
            NSSound.beep()
            return
        }

        let dirURL = URL(fileURLWithPath: directory)
        guard FileManager.default.fileExists(atPath: directory),
              (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else {
            statusField.stringValue = Localization.string(.findInFilesInvalidDirectory, default: "Invalid directory")
            return
        }

        // Confirm before replacing
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
        let modes: [TextSearch.SearchMode] = [.normal, .extended, .regex]
        let searchMode = modes[max(0, min(searchModeControl.selectedSegment, modes.count - 1))]
        let filters = parseFilters(filterField.stringValue)
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
            if !filters.isEmpty, !matchesFilter(fileURL.lastPathComponent, filters: filters) { continue }
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
        results.removeAll()
        resultsTable.reloadData()
    }

    @objc private func performFind(_ sender: Any?) {
        let query = findField.stringValue
        let directory = directoryField.stringValue
        let filter = filterField.stringValue

        guard !query.isEmpty, !directory.isEmpty else {
            NSSound.beep()
            return
        }

        let dirURL = URL(fileURLWithPath: directory)
        guard FileManager.default.fileExists(atPath: directory),
              (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else {
            statusField.stringValue = Localization.string(.findInFilesInvalidDirectory, default: "Invalid directory")
            return
        }

        statusField.stringValue = Localization.string(.findInFilesSearching, default: "Searching...")
        results.removeAll()
        resultsTable.reloadData()

        let matchCase = matchCaseButton.state == .on
        let wholeWord = wholeWordButton.state == .on
        let modes: [TextSearch.SearchMode] = [.normal, .extended, .regex]
        let searchMode = modes[max(0, min(searchModeControl.selectedSegment, modes.count - 1))]
        let filters = parseFilters(filter)

        let foundResults = searchInDirectory(
            dirURL,
            query: query,
            filters: filters,
            matchCase: matchCase,
            wholeWord: wholeWord,
            searchMode: searchMode
        )

        results = foundResults
        resultsTable.reloadData()

        if results.isEmpty {
            statusField.stringValue = Localization.string(.findInFilesNoResults, default: "No results found")
        } else {
            statusField.stringValue = String(
                format: Localization.string(.findInFilesResultCount, default: "%d result(s) found"),
                results.count
            )
        }
    }

    private func buildResultsContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open All Files", action: #selector(openAllResultFiles(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Copy Pathnames", action: #selector(copyResultPathnames(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Copy All", action: #selector(copyAllResults(_:)), keyEquivalent: "").target = self
        return menu
    }

    @objc private func openAllResultFiles(_ sender: Any?) {
        let paths = Set(results.map { $0.filePath })
        for path in paths {
            NotificationCenter.default.post(
                name: .findInFilesOpenFile,
                object: nil,
                userInfo: ["filePath": path, "line": 1]
            )
        }
    }

    @objc private func copyResultPathnames(_ sender: Any?) {
        let paths = Array(Set(results.map { $0.filePath })).sorted()
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    @objc private func copyAllResults(_ sender: Any?) {
        let text = results.map { "\($0.filePath):\($0.line): \($0.lineText)" }.joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func closePanel(_ sender: Any?) {
        window?.close()
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

    @objc private func resultDoubleClicked(_ sender: Any?) {
        let row = resultsTable.clickedRow
        guard row >= 0, row < results.count else { return }

        let result = results[row]
        let fileURL = URL(fileURLWithPath: result.filePath)

        // Ask the delegate to open the file at the specific line
        NotificationCenter.default.post(
            name: .findInFilesOpenFile,
            object: nil,
            userInfo: [
                "filePath": fileURL.path,
                "line": result.line
            ]
        )
    }

    private func parseFilters(_ filter: String) -> [String] {
        filter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func searchInDirectory(
        _ directory: URL,
        query: String,
        filters: [String],
        matchCase: Bool,
        wholeWord: Bool,
        searchMode: TextSearch.SearchMode = .normal
    ) -> [FindInFilesResult] {
        var allResults: [FindInFilesResult] = []
        let fileManager = FileManager.default
        let options: TextSearch.Options = TextSearch.Options(
            matchCase: matchCase,
            wholeWord: wholeWord,
            wraps: false,
            direction: .down,
            searchMode: searchMode
        )

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else { continue }

            if !filters.isEmpty, !matchesFilter(fileURL.lastPathComponent, filters: filters) {
                continue
            }

            // Try auto-detecting encoding via TextFileCodec, fall back to UTF-8
            let content: String
            if let loaded = try? TextFileCodec.read(fileURL) {
                content = loaded.text
            } else if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
                content = s
            } else {
                continue
            }

            let fileResults = searchInContent(content, query: query, options: options, filePath: fileURL.path)
            allResults.append(contentsOf: fileResults)
        }

        return allResults
    }

    private func matchesFilter(_ filename: String, filters: [String]) -> Bool {
        for filter in filters {
            let pattern = filter
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: "?", with: ".")
            if filename.range(of: "^\(pattern)$", options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private func searchInContent(
        _ content: String,
        query: String,
        options: TextSearch.Options,
        filePath: String
    ) -> [FindInFilesResult] {
        var results: [FindInFilesResult] = []
        let nsContent = content as NSString
        var searchFrom = NSRange(location: 0, length: 0)

        while let range = TextSearch.findNext(query, in: content, from: searchFrom, options: options) {
            let lineRange = nsContent.lineRange(for: range)
            let lineNumber = nsContent.substring(with: NSRange(location: 0, length: lineRange.location)).components(separatedBy: .newlines).count
            let lineText = nsContent.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let column = range.location - lineRange.location + 1

            results.append(FindInFilesResult(
                filePath: filePath,
                line: lineNumber,
                column: column,
                lineText: lineText
            ))

            searchFrom = NSRange(location: range.location + range.length, length: 0)
        }

        return results
    }
}

extension Notification.Name {
    static let findInFilesOpenFile = Notification.Name("findInFilesOpenFile")
}

// MARK: - NSTableView DataSource & Delegate

extension FindInFilesPanelController: NSTableViewDataSource, NSTableViewDelegate {
    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated { results.count }
    }

    nonisolated func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        MainActor.assumeIsolated {
            guard row < results.count else { return nil }

            let result = results[row]
            let cellIdentifier = NSUserInterfaceItemIdentifier("ResultCell")

            let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
                ?? {
                    let newCell = NSTableCellView()
                    newCell.identifier = cellIdentifier
                    let textField = NSTextField(labelWithString: "")
                    textField.lineBreakMode = .byTruncatingTail
                    textField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                    newCell.addSubview(textField)
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                        textField.topAnchor.constraint(equalTo: newCell.topAnchor, constant: 2),
                        textField.bottomAnchor.constraint(equalTo: newCell.bottomAnchor, constant: -2)
                    ])
                    newCell.textField = textField
                    return newCell
                }()

            let displayName = (result.filePath as NSString).lastPathComponent
            cell.textField?.stringValue = "\(displayName):\(result.line): \(result.lineText)"
            cell.toolTip = result.filePath
            return cell
        }
    }

    nonisolated func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        20
    }
}
