import AppKit
import NotepadMacCore
import UniformTypeIdentifiers

@MainActor
final class UserDefinedLanguagePanelController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private struct StructuredStyleDescriptor {
        let primaryName: String
        let aliases: [String]

        var candidateNames: [String] {
            [primaryName] + aliases
        }

        func wordStyle(in language: UserDefinedLanguage) -> UserDefinedLanguageWordStyle? {
            candidateNames.lazy.compactMap { language.wordStyle(named: $0) }.first
        }

        func resolvedName(in language: UserDefinedLanguage) -> String {
            wordStyle(in: language)?.name ?? primaryName
        }
    }

    private struct StructuredStyleFields {
        let descriptor: StructuredStyleDescriptor
        let fgColorField: NSTextField
        let bgColorField: NSTextField
        let fontNameField: NSTextField
        let fontStyleField: NSTextField
        let nestingField: NSTextField

        var textFields: [NSTextField] {
            [fgColorField, bgColorField, fontNameField, fontStyleField, nestingField]
        }

        @MainActor var hasStructuredValue: Bool {
            textFields.contains { $0.stringValue.trimmedNilIfEmpty != nil }
        }

        @MainActor
        func update(styleName: String) -> UserDefinedLanguageWordStyleStructuredUpdate {
            UserDefinedLanguageWordStyleStructuredUpdate(
                name: styleName,
                fgColor: fgColorField.stringValue.trimmedNilIfEmpty,
                bgColor: bgColorField.stringValue.trimmedNilIfEmpty,
                fontName: fontNameField.stringValue.trimmedNilIfEmpty,
                fontStyle: fontStyleField.stringValue.trimmedNilIfEmpty,
                nesting: nestingField.stringValue.trimmedNilIfEmpty
            )
        }
    }

    private struct ImportResult: Sendable {
        let languages: [UserDefinedLanguage]
        let failedFiles: [String]
    }

    private struct ExportResult: Sendable {
        let error: ExportError?
    }

    private struct ExportError: @unchecked Sendable {
        let underlying: Error
    }

    private static let structuredStyleDescriptors = [
        StructuredStyleDescriptor(primaryName: "DEFAULT", aliases: []),
        StructuredStyleDescriptor(primaryName: "COMMENTS", aliases: ["COMMENT"]),
        StructuredStyleDescriptor(primaryName: "NUMBER", aliases: ["NUMBERS"]),
        StructuredStyleDescriptor(primaryName: "OPERATOR", aliases: ["OPERATORS"]),
        StructuredStyleDescriptor(primaryName: "FOLDEROPEN", aliases: ["FOLDER IN CODE1"]),
        StructuredStyleDescriptor(primaryName: "FOLDERCLOSE", aliases: []),
        StructuredStyleDescriptor(primaryName: "KEYWORDS1", aliases: ["KEYWORD1"])
    ]

    private let store: UserDefinedLanguageStore
    private let onChange: () -> Void
    private let tableView = NSTableView()
    private let statusField = NSTextField(labelWithString: "")
    private let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    private let extensionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("extensions"))
    private let keywordsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("keywords"))
    private let importButton = NSButton(
        title: Localization.string(.udlImport, default: "Import..."),
        target: nil,
        action: nil
    )
    private let exportButton = NSButton(
        title: Localization.string(.udlExport, default: "Export..."),
        target: nil,
        action: nil
    )
    private let editButton = NSButton(
        title: Localization.string(.udlEdit, default: "Edit..."),
        target: nil,
        action: nil
    )
    private let deleteButton = NSButton(
        title: Localization.string(.udlDelete, default: "Delete"),
        target: nil,
        action: nil
    )
    private var languages: [UserDefinedLanguage] = []

    init(store: UserDefinedLanguageStore, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = Localization.string(.udlPanelTitle, default: "User Defined Languages")
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        refreshLocalizedStrings()
        reload()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        languages.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < languages.count else { return nil }
        let language = languages[row]

        switch tableColumn?.identifier.rawValue {
        case "name":
            return language.displayName
        case "extensions":
            return language.extensions.joined(separator: " ")
        case "keywords":
            return "\(language.keywords.count)"
        default:
            return language.name
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateControls()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        let selectedLanguageName = selectedLanguage()?.name
        refreshLocalizedStrings()
        reload(selecting: selectedLanguageName)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.setAccessibilityLabel(Localization.string(.udlTableAccessibilityLabel, default: "User-defined languages"))
        nameColumn.width = 230
        extensionsColumn.width = 260
        keywordsColumn.width = 90
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(extensionsColumn)
        tableView.addTableColumn(keywordsColumn)
        scrollView.documentView = tableView

        importButton.target = self
        importButton.action = #selector(importLanguage(_:))
        importButton.setAccessibilityLabel(Localization.string(.udlImportAccessibilityLabel, default: "Import user-defined language"))
        exportButton.target = self
        exportButton.action = #selector(exportLanguage(_:))
        exportButton.setAccessibilityLabel(Localization.string(.udlExportAccessibilityLabel, default: "Export selected language"))
        editButton.target = self
        editButton.action = #selector(editLanguage(_:))
        editButton.setAccessibilityLabel(Localization.string(.udlEditAccessibilityLabel, default: "Edit selected language"))
        deleteButton.target = self
        deleteButton.action = #selector(deleteLanguage(_:))
        deleteButton.setAccessibilityLabel(Localization.string(.udlDeleteAccessibilityLabel, default: "Delete selected language"))
        statusField.setAccessibilityLabel(Localization.string(.udlStatusAccessibilityLabel, default: "User-defined language status"))

        for view in [scrollView, statusField, importButton, exportButton, editButton, deleteButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: importButton.topAnchor, constant: -12),

            statusField.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            statusField.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -12),
            statusField.centerYAnchor.constraint(equalTo: importButton.centerYAnchor),

            deleteButton.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            editButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            editButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),

            exportButton.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -8),
            exportButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),

            importButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -8),
            importButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor)
        ])
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.udlPanelTitle, default: "User Defined Languages")
        tableView.setAccessibilityLabel(Localization.string(.udlTableAccessibilityLabel, default: "User-defined languages"))
        nameColumn.title = Localization.string(.udlNameColumn, default: "Name")
        extensionsColumn.title = Localization.string(.udlExtensionsColumn, default: "Extensions")
        keywordsColumn.title = Localization.string(.udlKeywordsColumn, default: "Keywords")
        importButton.title = Localization.string(.udlImport, default: "Import...")
        exportButton.title = Localization.string(.udlExport, default: "Export...")
        editButton.title = Localization.string(.udlEdit, default: "Edit...")
        deleteButton.title = Localization.string(.udlDelete, default: "Delete")
        importButton.setAccessibilityLabel(Localization.string(.udlImportAccessibilityLabel, default: "Import user-defined language"))
        exportButton.setAccessibilityLabel(Localization.string(.udlExportAccessibilityLabel, default: "Export selected language"))
        editButton.setAccessibilityLabel(Localization.string(.udlEditAccessibilityLabel, default: "Edit selected language"))
        deleteButton.setAccessibilityLabel(Localization.string(.udlDeleteAccessibilityLabel, default: "Delete selected language"))
        statusField.setAccessibilityLabel(Localization.string(.udlStatusAccessibilityLabel, default: "User-defined language status"))
    }

    private func reload(selecting languageName: String? = nil) {
        languages = store.load().sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        tableView.reloadData()

        if let languageName,
           let index = languages.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(languageName) == .orderedSame }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else if languages.isEmpty {
            tableView.deselectAll(nil)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        statusField.stringValue = languages.isEmpty
            ? Localization.string(.udlEmptyStatus, default: "No user-defined languages saved.")
            : localizedStatus(.udlLoadedStatus, default: "%d user-defined language(s) saved.", languages.count)
        updateControls()
    }

    private func selectedLanguage() -> UserDefinedLanguage? {
        let row = tableView.selectedRow
        guard row >= 0, row < languages.count else { return nil }
        return languages[row]
    }

    private func updateControls() {
        let hasSelection = selectedLanguage() != nil
        exportButton.isEnabled = hasSelection
        editButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
    }

    private func saveReplacing(_ language: UserDefinedLanguage) {
        var nextLanguages = store.load()
        nextLanguages.removeAll { $0.name.localizedCaseInsensitiveCompare(language.name) == .orderedSame }
        nextLanguages.append(language)
        store.save(nextLanguages)
        reload(selecting: language.name)
        onChange()
    }

    @objc private func importLanguage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.xml]
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await Self.loadImportResult(from: panel.urls)
                self.completeImport(result)
            }
        }
    }

    private func completeImport(_ result: ImportResult) {
        for language in result.languages {
            saveReplacing(language)
        }

        let importedCount = result.languages.count
        let failedFiles = result.failedFiles

        if failedFiles.isEmpty {
            if importedCount == 1 {
                let localizedMessage = Localization.messageBox(
                    tag: "UDL_importSuccessful",
                    defaultTitle: "User Defined Language",
                    defaultMessage: "Import successful."
                )
                statusField.stringValue = localizedMessage.message
            } else {
                statusField.stringValue = localizedStatus(
                    .udlImportedStatus,
                    default: "Imported %d language(s).",
                    importedCount
                )
            }
        } else {
            statusField.stringValue = localizedStatus(
                .udlImportFailedStatus,
                default: "Imported %d; failed: %@.",
                importedCount,
                failedFiles.joined(separator: ", ")
            )
        }
    }

    @objc private func exportLanguage(_ sender: Any?) {
        guard let language = selectedLanguage() else {
            statusField.stringValue = Localization.string(.udlSelectLanguageStatus, default: "Select a language first.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.xml]
        panel.nameFieldStringValue = "\(language.name).xml"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await Self.writeExport(language, to: url)
                self.completeExport(language, result: result)
            }
        }
    }

    @objc private func editLanguage(_ sender: Any?) {
        guard let language = selectedLanguage() else {
            statusField.stringValue = Localization.string(.udlSelectLanguageStatus, default: "Select a language first.")
            return
        }
        presentEditSheet(for: language)
    }

    private func completeExport(_ language: UserDefinedLanguage, result: ExportResult) {
        if let error = result.error {
            statusField.stringValue = Localization.string(.udlExportFailedStatus, default: "Export failed.")
            presentPanelError(error.underlying)
        } else {
            statusField.stringValue = Localization.messageBox(
                tag: "UDL_exportSuccessful",
                defaultTitle: "User Defined Language",
                defaultMessage: "Export successful."
            )
            .message
        }
    }

    @objc private func deleteLanguage(_ sender: Any?) {
        guard let language = selectedLanguage() else {
            statusField.stringValue = Localization.string(.udlSelectLanguageStatus, default: "Select a language first.")
            return
        }
        var nextLanguages = store.load()
        nextLanguages.removeAll { $0.name.localizedCaseInsensitiveCompare(language.name) == .orderedSame }
        store.save(nextLanguages)
        reload()
        onChange()
        statusField.stringValue = localizedStatus(.udlDeletedStatus, default: "Deleted %@.", language.displayName)
    }

    private func presentPanelError(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func presentEditSheet(for language: UserDefinedLanguage) {
        let extensionsField = NSTextField(string: language.editableExtensionsText)
        extensionsField.setAccessibilityLabel(
            Localization.string(.udlExtensionsFieldAccessibilityLabel, default: "Language extensions")
        )
        let keywordsField = NSTextField(string: language.editableKeywordsText)
        keywordsField.setAccessibilityLabel(
            Localization.string(.udlKeywordsFieldAccessibilityLabel, default: "Language keywords")
        )
        let styleFieldSets = Self.structuredStyleDescriptors.map { descriptor in
            Self.structuredStyleFields(for: descriptor, language: language)
        }
        let styleGrid = Self.structuredStylesGrid(for: styleFieldSets)
        styleGrid.setAccessibilityLabel(
            Localization.string(.udlStructuredStylesAccessibilityLabel, default: "Structured WordsStyle fields")
        )
        let wordStylesTextView = NSTextView(frame: .zero)
        wordStylesTextView.string = language.editableWordStylesText
        wordStylesTextView.isRichText = false
        wordStylesTextView.isAutomaticQuoteSubstitutionEnabled = false
        wordStylesTextView.isAutomaticDashSubstitutionEnabled = false
        wordStylesTextView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        wordStylesTextView.isVerticallyResizable = true
        wordStylesTextView.isHorizontallyResizable = true
        wordStylesTextView.autoresizingMask = [.width]
        wordStylesTextView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        wordStylesTextView.textContainer?.widthTracksTextView = false
        wordStylesTextView.setAccessibilityLabel(
            Localization.string(.udlRawWordsStyleAccessibilityLabel, default: "Raw WordsStyle XML")
        )

        let wordStylesScrollView = NSScrollView()
        wordStylesScrollView.translatesAutoresizingMaskIntoConstraints = false
        wordStylesScrollView.borderType = .bezelBorder
        wordStylesScrollView.hasVerticalScroller = true
        wordStylesScrollView.hasHorizontalScroller = true
        wordStylesScrollView.documentView = wordStylesTextView

        let labels = [
            Localization.string(.udlExtensionsColumn, default: "Extensions"),
            Localization.string(.udlKeywordsColumn, default: "Keywords"),
            Localization.string(.udlStructuredWordsStyle, default: "Structured WordsStyle"),
            Localization.string(.udlWordsStyleRaw, default: "Raw WordsStyle")
        ].map { label -> NSTextField in
            let field = NSTextField(labelWithString: label)
            field.alignment = .right
            return field
        }

        let grid = NSGridView(views: [
            [labels[0], extensionsField],
            [labels[1], keywordsField],
            [labels[2], styleGrid],
            [labels[3], wordStylesScrollView]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.xPlacement = .fill
        for rowIndex in 0..<2 {
            grid.row(at: rowIndex).yPlacement = .center
        }
        grid.row(at: 2).yPlacement = .top
        grid.row(at: 3).yPlacement = .top

        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 650, height: 430))
        accessoryView.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: accessoryView.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: accessoryView.trailingAnchor),
            grid.topAnchor.constraint(equalTo: accessoryView.topAnchor),
            grid.bottomAnchor.constraint(equalTo: accessoryView.bottomAnchor),
            wordStylesScrollView.heightAnchor.constraint(equalToConstant: 112)
        ])

        let alert = NSAlert()
        alert.messageText = Localization.string(.udlEditPanelTitle, default: "Edit User Defined Language")
        alert.informativeText = language.name
        alert.alertStyle = .informational
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: Localization.string(.udlEditSave, default: "Save"))
        alert.addButton(withTitle: Localization.string(.udlEditCancel, default: "Cancel"))

        let saveEdit = {
            guard let editedBase = language.updating(
                extensionsText: extensionsField.stringValue,
                keywordsText: keywordsField.stringValue,
                wordStylesText: wordStylesTextView.string
            ) else {
                self.statusField.stringValue = Localization.string(
                    .udlSaveFailedStatus,
                    default: "Failed to save the selected language."
                )
                return
            }
            let structuredUpdates = styleFieldSets.compactMap { fieldSet -> UserDefinedLanguageWordStyleStructuredUpdate? in
                let styleName = fieldSet.descriptor.resolvedName(in: editedBase)
                guard editedBase.wordStyle(named: styleName) != nil || fieldSet.hasStructuredValue else {
                    return nil
                }
                return fieldSet.update(styleName: styleName)
            }
            let edited = editedBase.applyingStructuredWordStyleUpdates(structuredUpdates)
            self.saveReplacing(edited)
            self.statusField.stringValue = self.localizedStatus(.udlSavedStatus, default: "Saved %@.", edited.displayName)
        }

        if let window {
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else { return }
                saveEdit()
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            saveEdit()
        }
    }

    private static func structuredStyleFields(
        for descriptor: StructuredStyleDescriptor,
        language: UserDefinedLanguage
    ) -> StructuredStyleFields {
        let style = descriptor.wordStyle(in: language)
        let styleName = descriptor.primaryName
        return StructuredStyleFields(
            descriptor: descriptor,
            fgColorField: styleTextField(
                value: style?.fgColor,
                accessibilityLabel: structuredStyleFieldAccessibilityLabel(
                    styleName: styleName,
                    fieldName: Localization.string(.udlStructuredFgColor, default: "fgColor")
                )
            ),
            bgColorField: styleTextField(
                value: style?.bgColor,
                accessibilityLabel: structuredStyleFieldAccessibilityLabel(
                    styleName: styleName,
                    fieldName: Localization.string(.udlStructuredBgColor, default: "bgColor")
                )
            ),
            fontNameField: styleTextField(
                value: style?.fontName,
                accessibilityLabel: structuredStyleFieldAccessibilityLabel(
                    styleName: styleName,
                    fieldName: Localization.string(.udlStructuredFontName, default: "fontName")
                )
            ),
            fontStyleField: styleTextField(
                value: style?.fontStyle,
                accessibilityLabel: structuredStyleFieldAccessibilityLabel(
                    styleName: styleName,
                    fieldName: Localization.string(.udlStructuredFontStyle, default: "fontStyle")
                )
            ),
            nestingField: styleTextField(
                value: style?.nesting,
                accessibilityLabel: structuredStyleFieldAccessibilityLabel(
                    styleName: styleName,
                    fieldName: Localization.string(.udlStructuredNesting, default: "nesting")
                )
            )
        )
    }

    private static func structuredStylesGrid(for fieldSets: [StructuredStyleFields]) -> NSGridView {
        let headerTitles = [
            Localization.string(.udlStructuredStyleName, default: "Style"),
            Localization.string(.udlStructuredFgColor, default: "fgColor"),
            Localization.string(.udlStructuredBgColor, default: "bgColor"),
            Localization.string(.udlStructuredFontName, default: "fontName"),
            Localization.string(.udlStructuredFontStyle, default: "fontStyle"),
            Localization.string(.udlStructuredNesting, default: "nesting")
        ]
        let header = headerTitles.map { title -> NSTextField in
            let field = NSTextField(labelWithString: title)
            field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            return field
        }
        let rows: [[NSView]] = [header] + fieldSets.map { fieldSet in
            let nameField = NSTextField(labelWithString: fieldSet.descriptor.primaryName)
            nameField.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            return [nameField] + fieldSet.textFields
        }
        let grid = NSGridView(views: rows)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 4
        grid.columnSpacing = 6
        grid.xPlacement = .fill
        return grid
    }

    private static func styleTextField(value: String?, accessibilityLabel: String) -> NSTextField {
        let field = NSTextField(string: value ?? "")
        field.controlSize = .small
        field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true
        field.setAccessibilityLabel(accessibilityLabel)
        return field
    }

    private static func structuredStyleFieldAccessibilityLabel(styleName: String, fieldName: String) -> String {
        String(
            format: Localization.string(.udlStructuredStyleFieldAccessibilityLabel, default: "%@ %@ field"),
            locale: Locale.current,
            arguments: [styleName, fieldName]
        )
    }

    private func localizedStatus(_ key: Localization.Key, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: Localization.string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }

    nonisolated private static func loadImportResult(from urls: [URL]) async -> ImportResult {
        await Task.detached(priority: .userInitiated) {
            var languages: [UserDefinedLanguage] = []
            var failedFiles: [String] = []

            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let language = try UserDefinedLanguageIO.importLanguage(from: data)
                    languages.append(language)
                } catch {
                    failedFiles.append(url.lastPathComponent)
                }
            }

            return ImportResult(languages: languages, failedFiles: failedFiles)
        }.value
    }

    nonisolated private static func writeExport(_ language: UserDefinedLanguage, to url: URL) async -> ExportResult {
        await Task.detached(priority: .userInitiated) {
            do {
                try UserDefinedLanguageIO.exportLanguage(language)
                    .write(to: url, atomically: true, encoding: .utf8)
                return ExportResult(error: nil)
            } catch {
                return ExportResult(error: ExportError(underlying: error))
            }
        }.value
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
