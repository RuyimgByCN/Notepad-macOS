import AppKit
import NotepadMacCore

@MainActor
final class PluginsPanelController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let summaryField = NSTextField(labelWithString: "")
    private let nativePluginLabel = NSTextField(
        labelWithString: Localization.string(.pluginsNativePluginLabel, default: "Native plugin:")
    )
    private let nativePluginPopUpButton = NSPopUpButton()
    private let toggleNativePluginButton = NSButton(
        title: Localization.string(.pluginsDisable, default: "Disable"),
        target: nil,
        action: nil
    )
    private let argumentsLabel = NSTextField(
        labelWithString: Localization.string(.pluginsArgumentsLabel, default: "Arguments:")
    )
    private let argumentsField = NSTextField(string: "")
    private let tableView = NSTableView()
    private let statusView = NSTextView()
    private let refreshButton = NSButton(
        title: Localization.string(.pluginsRefresh, default: "Rescan"),
        target: nil,
        action: nil
    )
    private let installPluginButton = NSButton(
        title: Localization.string(.pluginsInstallOrUpdate, default: "Install/Update..."),
        target: nil,
        action: nil
    )
    private let removePluginButton = NSButton(
        title: Localization.string(.pluginsRemove, default: "Remove"),
        target: nil,
        action: nil
    )
    private let openPluginFolderButton = NSButton(
        title: Localization.string(.pluginsOpenUserPluginFolder, default: "Open Plugin Folder"),
        target: nil,
        action: nil
    )
    private let runButton = NSButton(
        title: Localization.string(.pluginsRun, default: "Run"),
        target: nil,
        action: nil
    )
    private let preferencesStore: PreferencesStore
    private let documentURLProvider: () -> URL?
    private let selectionProvider: () -> PluginCommandSelectionContext?
    private let runtime = PluginCommandRuntime()

    private var directories: [URL] = []
    private var catalog = PluginCatalog(plugins: [])
    private var runnableCommands: [RunnablePluginCommand] = []
    private var disabledNativePluginIdentifiers: Set<String> = []
    private var runningTask: Task<Void, Never>?
    private var stopRequested = false

    init(
        preferencesStore: PreferencesStore = PreferencesStore(),
        documentURLProvider: @escaping () -> URL? = { nil },
        selectionProvider: @escaping () -> PluginCommandSelectionContext? = { nil }
    ) {
        self.preferencesStore = preferencesStore
        self.documentURLProvider = documentURLProvider
        self.selectionProvider = selectionProvider

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = Localization.string(.pluginsPanelTitle, default: "Plugin Admin")
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        if runningTask == nil {
            reload()
        }
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        runnableCommands.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < runnableCommands.count else { return nil }
        let item = runnableCommands[row]

        switch tableColumn?.identifier.rawValue {
        case "plugin":
            return item.plugin.displayName
        case "command":
            return item.command.title
        case "identifier":
            return item.command.identifier
        default:
            return item.plugin.version ?? ""
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateControls()
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        summaryField.translatesAutoresizingMaskIntoConstraints = false
        summaryField.lineBreakMode = .byTruncatingMiddle

        nativePluginLabel.translatesAutoresizingMaskIntoConstraints = false

        nativePluginPopUpButton.translatesAutoresizingMaskIntoConstraints = false
        nativePluginPopUpButton.target = self
        nativePluginPopUpButton.action = #selector(nativePluginSelectionChanged(_:))

        toggleNativePluginButton.translatesAutoresizingMaskIntoConstraints = false
        toggleNativePluginButton.bezelStyle = .rounded
        toggleNativePluginButton.target = self
        toggleNativePluginButton.action = #selector(toggleSelectedNativePlugin(_:))

        argumentsLabel.translatesAutoresizingMaskIntoConstraints = false

        argumentsField.translatesAutoresizingMaskIntoConstraints = false
        argumentsField.placeholderString = Localization.string(
            .pluginsArgumentsPlaceholder,
            default: #"Optional arguments, e.g. --selection "Hello world""#
        )
        argumentsField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshPlugins(_:))

        installPluginButton.translatesAutoresizingMaskIntoConstraints = false
        installPluginButton.bezelStyle = .rounded
        installPluginButton.target = self
        installPluginButton.action = #selector(installOrUpdateNativePlugin(_:))

        removePluginButton.translatesAutoresizingMaskIntoConstraints = false
        removePluginButton.bezelStyle = .rounded
        removePluginButton.target = self
        removePluginButton.action = #selector(removeSelectedNativePlugin(_:))

        openPluginFolderButton.translatesAutoresizingMaskIntoConstraints = false
        openPluginFolderButton.bezelStyle = .rounded
        openPluginFolderButton.target = self
        openPluginFolderButton.action = #selector(openUserPluginFolder(_:))

        runButton.translatesAutoresizingMaskIntoConstraints = false
        runButton.bezelStyle = .rounded
        runButton.target = self
        runButton.action = #selector(runSelectedCommand(_:))

        let tableScrollView = NSScrollView()
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        tableScrollView.hasVerticalScroller = true
        tableScrollView.hasHorizontalScroller = true
        tableScrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(runSelectedCommand(_:))
        tableView.addTableColumn(column(
            identifier: "plugin",
            title: Localization.string(.pluginsColumnPlugin, default: "Plugin"),
            width: 210
        ))
        tableView.addTableColumn(column(
            identifier: "command",
            title: Localization.string(.pluginsColumnCommand, default: "Command"),
            width: 230
        ))
        tableView.addTableColumn(column(
            identifier: "identifier",
            title: Localization.string(.pluginsColumnIdentifier, default: "Identifier"),
            width: 220
        ))
        tableView.addTableColumn(column(
            identifier: "version",
            title: Localization.string(.pluginsColumnVersion, default: "Version"),
            width: 80
        ))
        tableScrollView.documentView = tableView

        let statusScrollView = NSScrollView()
        statusScrollView.translatesAutoresizingMaskIntoConstraints = false
        statusScrollView.hasVerticalScroller = true
        statusScrollView.hasHorizontalScroller = true
        statusScrollView.borderType = .bezelBorder

        statusView.isEditable = false
        statusView.isSelectable = true
        statusView.isRichText = false
        statusView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusView.textContainerInset = NSSize(width: 10, height: 10)
        statusView.autoresizingMask = [.width, .height]
        statusScrollView.documentView = statusView

        contentView.addSubview(summaryField)
        contentView.addSubview(nativePluginLabel)
        contentView.addSubview(nativePluginPopUpButton)
        contentView.addSubview(toggleNativePluginButton)
        contentView.addSubview(argumentsLabel)
        contentView.addSubview(argumentsField)
        contentView.addSubview(refreshButton)
        contentView.addSubview(installPluginButton)
        contentView.addSubview(removePluginButton)
        contentView.addSubview(openPluginFolderButton)
        contentView.addSubview(runButton)
        contentView.addSubview(tableScrollView)
        contentView.addSubview(statusScrollView)

        NSLayoutConstraint.activate([
            summaryField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            summaryField.trailingAnchor.constraint(lessThanOrEqualTo: runButton.leadingAnchor, constant: -12),
            summaryField.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            summaryField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            refreshButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            refreshButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            openPluginFolderButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -8),
            openPluginFolderButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            removePluginButton.trailingAnchor.constraint(equalTo: openPluginFolderButton.leadingAnchor, constant: -8),
            removePluginButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            installPluginButton.trailingAnchor.constraint(equalTo: removePluginButton.leadingAnchor, constant: -8),
            installPluginButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            runButton.trailingAnchor.constraint(equalTo: installPluginButton.leadingAnchor, constant: -8),
            runButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            nativePluginLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            nativePluginLabel.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 12),

            nativePluginPopUpButton.leadingAnchor.constraint(equalTo: nativePluginLabel.trailingAnchor, constant: 8),
            nativePluginPopUpButton.trailingAnchor.constraint(lessThanOrEqualTo: toggleNativePluginButton.leadingAnchor, constant: -8),
            nativePluginPopUpButton.centerYAnchor.constraint(equalTo: nativePluginLabel.centerYAnchor),
            nativePluginPopUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),

            toggleNativePluginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            toggleNativePluginButton.centerYAnchor.constraint(equalTo: nativePluginLabel.centerYAnchor),

            argumentsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            argumentsLabel.topAnchor.constraint(equalTo: nativePluginPopUpButton.bottomAnchor, constant: 12),

            argumentsField.leadingAnchor.constraint(equalTo: argumentsLabel.trailingAnchor, constant: 8),
            argumentsField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            argumentsField.centerYAnchor.constraint(equalTo: argumentsLabel.centerYAnchor),

            tableScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            tableScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            tableScrollView.topAnchor.constraint(equalTo: argumentsField.bottomAnchor, constant: 12),
            tableScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),

            statusScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            statusScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            statusScrollView.topAnchor.constraint(equalTo: tableScrollView.bottomAnchor, constant: 10),
            statusScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            statusScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
    }

    private func reload(preferredNativePluginIdentifier: String? = nil) {
        let preferredSelectionKey = selectedCommand()?.selectionKey
        let preferredNativePluginIdentifier = preferredNativePluginIdentifier ?? selectedNativePluginIdentifier()
        directories = PluginCatalog.defaultPluginDirectories()
        disabledNativePluginIdentifiers = preferencesStore.loadDisabledNativePluginIdentifiers()
        catalog = PluginCatalog
            .scan(directories: directories)
            .withDisabledPlugins(disabledNativePluginIdentifiers)
        runnableCommands = catalog.plugins.flatMap { plugin -> [RunnablePluginCommand] in
            guard plugin.kind == .nativeManifest, plugin.compatibility == .nativeCompatible else {
                return []
            }

            return plugin.commands.map { command in
                RunnablePluginCommand(plugin: plugin, command: command)
            }
        }

        let summaryKey: Localization.Key = runnableCommands.count == 1
            ? .pluginsSummaryRunnableCommand
            : .pluginsSummaryRunnableCommands
        let summaryDefault = runnableCommands.count == 1
            ? "%d runnable native command"
            : "%d runnable native commands"
        summaryField.stringValue = String(
            format: Localization.string(summaryKey, default: summaryDefault),
            runnableCommands.count
        )
        reloadNativePluginMenu(preferredIdentifier: preferredNativePluginIdentifier)
        tableView.reloadData()
        restoreSelection(preferredSelectionKey)
        statusView.string = render(catalog: catalog, directories: directories)
        updateControls()
    }

    private func render(catalog: PluginCatalog, directories: [URL]) -> String {
        var lines: [String] = [
            Localization.string(.pluginsReportTitle, default: "Plugin Admin"),
            "============",
            "",
            Localization.string(
                .pluginsReportNativeManifests,
                default: "Native plugin manifests: notepad-mac-plugin.json"
            ),
            Localization.string(
                .pluginsReportWindowsDllCompatibility,
                default: "Windows Notepad++ DLL plugins are reported for compatibility only and are not loaded."
            ),
            "",
            Localization.string(.pluginsReportScanLocations, default: "Scan locations:")
        ]

        lines += directories.map { "  - \($0.path)" }
        lines.append("")

        guard !catalog.plugins.isEmpty else {
            lines += [
                Localization.string(.pluginsReportNoPlugins, default: "No plugins found."),
                "",
                Localization.string(
                    .pluginsReportInstallHint,
                    default: "Install native plugins as directories containing notepad-mac-plugin.json under the user plugin folder."
                )
            ]
            return lines.joined(separator: "\n")
        }

        lines.append(String(
            format: Localization.string(.pluginsReportRunnableCommands, default: "Runnable native commands: %d"),
            runnableCommands.count
        ))
        lines.append("")

        for plugin in catalog.plugins {
            lines.append("\(plugin.displayName)\(plugin.version.map { " \($0)" } ?? "")")
            lines.append("  " + String(
                format: Localization.string(.pluginsReportKind, default: "Kind: %@"),
                plugin.kind.displayName
            ))
            lines.append("  " + String(
                format: Localization.string(.pluginsReportStatus, default: "Status: %@"),
                plugin.compatibility.displayText
            ))
            lines.append("  " + String(
                format: Localization.string(.pluginsReportLocation, default: "Location: %@"),
                plugin.directoryURL.path
            ))
            if let entryURL = plugin.entryURL {
                lines.append("  " + String(
                    format: Localization.string(.pluginsReportEntry, default: "Entry: %@"),
                    entryURL.path
                ))
            }
            if plugin.kind == .nativeManifest, plugin.compatibility == .nativeCompatible {
                if plugin.commands.isEmpty {
                    lines.append("  " + Localization.string(
                        .pluginsReportCommandsNone,
                        default: "Commands: (none declared)"
                    ))
                } else {
                    lines.append("  " + Localization.string(.pluginsReportCommandsHeader, default: "Commands:"))
                    lines += plugin.commands.map { "    - \($0.title) (\($0.identifier))" }
                }
            } else {
                lines.append("  " + Localization.string(
                    .pluginsReportCommandsNotRunnable,
                    default: "Commands: not runnable in this host"
                ))
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func column(identifier: String, title: String, width: CGFloat) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        return column
    }

    private func selectedCommand() -> RunnablePluginCommand? {
        let row = tableView.selectedRow
        guard row >= 0, row < runnableCommands.count else { return nil }
        return runnableCommands[row]
    }

    private func nativeLifecyclePlugins() -> [PluginDescriptor] {
        catalog.plugins.filter { plugin in
            guard plugin.kind == .nativeManifest else {
                return false
            }

            return plugin.compatibility == .nativeCompatible
                || plugin.compatibility == .unsupported(reason: PluginCompatibility.disabledPluginReason)
        }
    }

    private func reloadNativePluginMenu(preferredIdentifier: String?) {
        let plugins = nativeLifecyclePlugins()
        nativePluginPopUpButton.removeAllItems()

        guard !plugins.isEmpty else {
            nativePluginPopUpButton.addItem(withTitle: Localization.string(
                .pluginsNativePluginEmpty,
                default: "No native manifest plugins"
            ))
            return
        }

        for plugin in plugins {
            let state = disabledNativePluginIdentifiers.contains(plugin.identifier)
                ? Localization.string(.pluginsNativePluginStateDisabled, default: "Disabled")
                : Localization.string(.pluginsNativePluginStateEnabled, default: "Enabled")
            nativePluginPopUpButton.addItem(withTitle: "\(plugin.displayName) (\(state))")
            nativePluginPopUpButton.lastItem?.representedObject = plugin.identifier
        }

        if let preferredIdentifier,
           let index = plugins.firstIndex(where: { $0.identifier == preferredIdentifier }) {
            nativePluginPopUpButton.selectItem(at: index)
        } else {
            nativePluginPopUpButton.selectItem(at: 0)
        }
    }

    private func selectedNativePluginIdentifier() -> String? {
        nativePluginPopUpButton.selectedItem?.representedObject as? String
    }

    private func restoreSelection(_ preferredSelectionKey: PluginCommandSelectionKey?) {
        guard !runnableCommands.isEmpty else {
            tableView.deselectAll(nil)
            return
        }

        let row = preferredSelectionKey
            .flatMap { key in runnableCommands.firstIndex { $0.selectionKey == key } }
            ?? 0
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func updateControls() {
        let canRun = selectedCommand() != nil
        if runningTask == nil {
            runButton.title = Localization.string(.pluginsRun, default: "Run")
            runButton.action = #selector(runSelectedCommand(_:))
            runButton.isEnabled = canRun
        } else {
            runButton.title = stopRequested
                ? Localization.string(.pluginsStopping, default: "Stopping…")
                : Localization.string(.pluginsStop, default: "Stop")
            runButton.action = #selector(stopRunningCommand(_:))
            runButton.isEnabled = !stopRequested
        }
        refreshButton.isEnabled = runningTask == nil
        installPluginButton.isEnabled = runningTask == nil && PluginCatalog.userPluginDirectory() != nil
        removePluginButton.isEnabled = runningTask == nil
            && PluginCatalog.userPluginDirectory() != nil
            && selectedNativePluginIdentifier() != nil
        openPluginFolderButton.isEnabled = PluginCatalog.userPluginDirectory() != nil
        tableView.isEnabled = runningTask == nil
        nativePluginPopUpButton.isEnabled = runningTask == nil && selectedNativePluginIdentifier() != nil
        toggleNativePluginButton.isEnabled = runningTask == nil && selectedNativePluginIdentifier() != nil
        if let selectedNativePluginIdentifier = selectedNativePluginIdentifier() {
            toggleNativePluginButton.title = disabledNativePluginIdentifiers.contains(selectedNativePluginIdentifier)
                ? Localization.string(.pluginsEnable, default: "Enable")
                : Localization.string(.pluginsDisable, default: "Disable")
        } else {
            toggleNativePluginButton.title = Localization.string(.pluginsDisable, default: "Disable")
        }
        argumentsField.isEnabled = runningTask == nil && canRun
        if let item = selectedCommand() {
            argumentsField.placeholderString = String(
                format: Localization.string(
                    .pluginsArgumentsPlaceholderForCommand,
                    default: #"Optional arguments for %@, e.g. --selection "Hello world""#
                ),
                item.command.identifier
            )
        } else {
            argumentsField.placeholderString = Localization.string(
                .pluginsArgumentsPlaceholder,
                default: #"Optional arguments, e.g. --selection "Hello world""#
            )
        }
    }

    private func appendStatus(_ message: String) {
        let separator = statusView.string.isEmpty ? "" : "\n"
        statusView.string += "\(separator)\(message)"
        statusView.scrollToEndOfDocument(nil)
    }

    private func appendOutput(_ event: PluginCommandOutputEvent) {
        let prefix = event.stream == .standardOutput
            ? Localization.string(.pluginsOutputStandardOutput, default: "[stdout]")
            : Localization.string(.pluginsOutputStandardError, default: "[stderr]")
        let text = event.text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .newlines)

        guard !text.isEmpty else {
            return
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            appendStatus("\(prefix) \(line)")
        }
    }

    private func commandArguments() throws -> [String] {
        try PluginCommandArgumentParser.parse(argumentsField.stringValue)
    }

    @objc private func nativePluginSelectionChanged(_ sender: Any?) {
        updateControls()
    }

    @objc private func toggleSelectedNativePlugin(_ sender: Any?) {
        guard runningTask == nil, let identifier = selectedNativePluginIdentifier() else {
            return
        }

        let displayName = catalog.plugin(identifier: identifier)?.displayName ?? identifier
        let didDisable: Bool
        if disabledNativePluginIdentifiers.contains(identifier) {
            disabledNativePluginIdentifiers.remove(identifier)
            didDisable = false
        } else {
            disabledNativePluginIdentifiers.insert(identifier)
            didDisable = true
        }

        preferencesStore.saveDisabledNativePluginIdentifiers(disabledNativePluginIdentifiers)
        reload(preferredNativePluginIdentifier: identifier)
        appendStatus(String(
            format: Localization.string(
                didDisable ? .pluginsStatusDisabledNativePlugin : .pluginsStatusEnabledNativePlugin,
                default: didDisable ? "Disabled native plugin: %@" : "Enabled native plugin: %@"
            ),
            displayName
        ))
    }

    @objc private func refreshPlugins(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(
                .pluginsStatusRefreshSkipped,
                default: "Rescan skipped: a plugin command is still running."
            ))
            return
        }

        reload()
        appendStatus(String(
            format: Localization.string(.pluginsStatusRescanned, default: "Rescanned plugin folders: %d plugins found."),
            catalog.plugins.count
        ))
    }

    @objc private func installOrUpdateNativePlugin(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(
                .pluginsStatusRefreshSkipped,
                default: "Rescan skipped: a plugin command is still running."
            ))
            return
        }
        guard let userPluginDirectory = PluginCatalog.userPluginDirectory() else {
            appendStatus(Localization.string(
                .pluginsStatusOpenUserPluginFolderUnavailable,
                default: "User plugin folder is unavailable."
            ))
            return
        }

        let panel = NSOpenPanel()
        panel.title = Localization.string(.pluginsInstallPanelTitle, default: "Install Native Plugin")
        panel.prompt = Localization.string(.pluginsInstallPanelPrompt, default: "Install")
        panel.message = Localization.string(
            .pluginsInstallPanelMessage,
            default: "Choose a folder containing notepad-mac-plugin.json."
        )
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let sourceDirectory = panel.url else {
            return
        }

        do {
            let result = try PluginCatalog.installNativePlugin(from: sourceDirectory, into: userPluginDirectory)
            reload(preferredNativePluginIdentifier: result.plugin.identifier)
            let status: (Localization.Key, String)
            switch result.action {
            case .installed:
                status = (.pluginsStatusInstalledNativePlugin, "Installed native plugin %@ to %@")
            case .updated:
                status = (.pluginsStatusUpdatedNativePlugin, "Updated native plugin %@ at %@")
            case .unchanged:
                status = (.pluginsStatusNativePluginAlreadyInstalled, "Native plugin %@ is already installed at %@")
            }
            appendStatus(String(
                format: Localization.string(status.0, default: status.1),
                result.plugin.displayName,
                result.destinationURL.path
            ))
        } catch {
            appendStatus(String(
                format: Localization.string(.pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                error.displayText
            ))
        }
    }

    @objc private func removeSelectedNativePlugin(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(
                .pluginsStatusRemoveSkipped,
                default: "Remove skipped: a plugin command is still running."
            ))
            return
        }
        guard let identifier = selectedNativePluginIdentifier() else {
            appendStatus(String(
                format: Localization.string(.pluginsStatusRemoveFailed, default: "Remove failed: %@"),
                Localization.string(.pluginsNativePluginEmpty, default: "No native manifest plugins")
            ))
            return
        }
        guard let plugin = catalog.plugin(identifier: identifier) else {
            let message = String(
                format: Localization.string(.pluginsErrorPluginNotFound, default: "Plugin not found: %@"),
                identifier
            )
            appendStatus(String(
                format: Localization.string(.pluginsStatusRemoveFailed, default: "Remove failed: %@"),
                message
            ))
            return
        }

        do {
            let result = try PluginCatalog.removeNativePlugin(plugin)
            if disabledNativePluginIdentifiers.remove(result.plugin.identifier) != nil {
                preferencesStore.saveDisabledNativePluginIdentifiers(disabledNativePluginIdentifiers)
            }
            reload()
            appendStatus(String(
                format: Localization.string(
                    .pluginsStatusRemovedNativePlugin,
                    default: "Removed native plugin %@ from %@"
                ),
                result.plugin.displayName,
                result.removedURL.path
            ))
        } catch {
            if let removalError = error as? PluginRemovalError,
               case .missingPluginDirectory = removalError {
                reload()
            }
            appendStatus(String(
                format: Localization.string(.pluginsStatusRemoveFailed, default: "Remove failed: %@"),
                error.displayText
            ))
        }
    }

    @objc private func openUserPluginFolder(_ sender: Any?) {
        guard let directory = PluginCatalog.userPluginDirectory() else {
            appendStatus(Localization.string(
                .pluginsStatusOpenUserPluginFolderUnavailable,
                default: "User plugin folder is unavailable."
            ))
            return
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if NSWorkspace.shared.open(directory) {
                appendStatus(String(
                    format: Localization.string(
                        .pluginsStatusOpenedUserPluginFolder,
                        default: "Opened user plugin folder: %@"
                    ),
                    directory.path
                ))
            } else {
                appendStatus(String(
                    format: Localization.string(
                        .pluginsStatusOpenUserPluginFolderFailed,
                        default: "Could not open user plugin folder: %@"
                    ),
                    directory.path
                ))
            }
        } catch {
            appendStatus(String(
                format: Localization.string(
                    .pluginsStatusOpenUserPluginFolderFailed,
                    default: "Could not open user plugin folder: %@"
                ),
                error.localizedDescription
            ))
        }
    }

    @objc private func runSelectedCommand(_ sender: Any?) {
        guard runningTask == nil, let item = selectedCommand() else {
            return
        }

        do {
            let arguments = try commandArguments()
            let invocation = PluginCommandInvocation(
                pluginIdentifier: item.plugin.identifier,
                commandIdentifier: item.command.identifier,
                arguments: arguments,
                documentURL: documentURLProvider(),
                selection: selectionProvider()
            )
            let result = try runtime.planExecutableCommand(invocation, in: catalog)

            let commandDescription = "\(result.plugin.displayName) / \(result.command.title)"
            let task = Task { [weak self, runtime] in
                do {
                    let execution = try await runtime.executePlannedCommand(
                        result,
                        onOutput: { [weak self] event in
                            self?.appendOutput(event)
                        }
                    )
                    await MainActor.run { [weak self] in
                        self?.finishRunningCommand(
                            commandDescription,
                            result: execution,
                            wasCancelled: Task.isCancelled,
                            outputWasStreamed: true
                        )
                    }
                } catch {
                    await MainActor.run { [weak self] in
                        self?.failRunningCommand(
                            commandDescription,
                            error: error,
                            wasCancelled: Task.isCancelled
                        )
                    }
                }
            }

            stopRequested = false
            runningTask = task
            appendStatus(String(
                format: Localization.string(.pluginsStatusRunning, default: "Running %@"),
                commandDescription
            ))
            appendStatus(String(
                format: Localization.string(.pluginsStatusExecutable, default: "Executable: %@"),
                result.processPlan.executableURL.path
            ))
            let commandArguments = result.processPlan.arguments.dropFirst(2)
            let argumentsDescription = commandArguments.isEmpty
                ? Localization.string(.pluginsStatusArgumentsNone, default: "(none)")
                : commandArguments.joined(separator: " ")
            appendStatus(String(
                format: Localization.string(.pluginsStatusArguments, default: "Arguments: %@"),
                argumentsDescription
            ))
            updateControls()
        } catch {
            appendStatus(String(
                format: Localization.string(.pluginsStatusRunFailed, default: "Run failed: %@"),
                error.displayText
            ))
            updateControls()
        }
    }

    @objc private func stopRunningCommand(_ sender: Any?) {
        guard let runningTask, !stopRequested else {
            return
        }

        stopRequested = true
        appendStatus(Localization.string(.pluginsStatusStoppingCurrent, default: "Stopping current command…"))
        runningTask.cancel()
        updateControls()
    }

    private func finishRunningCommand(
        _ commandDescription: String,
        result: PluginCommandExecutionResult,
        wasCancelled: Bool,
        outputWasStreamed: Bool
    ) {
        runningTask = nil
        stopRequested = false
        appendStatus(String(
            format: wasCancelled
                ? Localization.string(.pluginsStatusCancelled, default: "Cancelled %@")
                : Localization.string(.pluginsStatusFinished, default: "Finished %@"),
            commandDescription
        ))
        appendStatus(String(
            format: Localization.string(.pluginsStatusTermination, default: "Termination: %@; exit code: %d"),
            result.terminationReason.displayText,
            result.terminationStatus
        ))
        if !outputWasStreamed, !result.standardOutput.isEmpty {
            appendOutput(PluginCommandOutputEvent(stream: .standardOutput, text: result.standardOutput))
        }
        if !outputWasStreamed, !result.standardError.isEmpty {
            appendOutput(PluginCommandOutputEvent(stream: .standardError, text: result.standardError))
        }
        updateControls()
    }

    private func failRunningCommand(
        _ commandDescription: String,
        error: Swift.Error,
        wasCancelled: Bool
    ) {
        runningTask = nil
        stopRequested = false
        if wasCancelled {
            appendStatus(String(
                format: Localization.string(.pluginsStatusCancelledWithError, default: "Cancelled %@: %@"),
                commandDescription,
                error.displayText
            ))
        } else {
            appendStatus(String(
                format: Localization.string(.pluginsStatusRunFailedFor, default: "Run failed for %@: %@"),
                commandDescription,
                error.displayText
            ))
        }
        updateControls()
    }
}

private struct RunnablePluginCommand {
    let plugin: PluginDescriptor
    let command: PluginCommandDescriptor

    var selectionKey: PluginCommandSelectionKey {
        PluginCommandSelectionKey(
            pluginIdentifier: plugin.identifier,
            commandIdentifier: command.identifier
        )
    }
}

private struct PluginCommandSelectionKey: Equatable {
    let pluginIdentifier: String
    let commandIdentifier: String
}

private extension PluginCommandTerminationReason {
    var displayText: String {
        switch self {
        case .exit:
            Localization.string(.pluginsTerminationExit, default: "exit")
        case .uncaughtSignal:
            Localization.string(.pluginsTerminationUncaughtSignal, default: "uncaught signal")
        case .unknown:
            Localization.string(.pluginsTerminationUnknown, default: "unknown")
        }
    }
}

private extension Swift.Error {
    var displayText: String {
        if let parseError = self as? PluginCommandArgumentParser.Error {
            switch parseError {
            case .danglingEscape:
                return Localization.string(
                    .pluginsErrorArgumentsDanglingEscape,
                    default: "Arguments end with a dangling escape. Finish the escaped character or remove the trailing backslash."
                )
            case .unterminatedQuote:
                return Localization.string(
                    .pluginsErrorArgumentsUnterminatedQuote,
                    default: "Arguments contain an unterminated quote. Close the quote before running the command."
                )
            }
        }

        if let installationError = self as? PluginInstallationError {
            switch installationError {
            case .userPluginDirectoryUnavailable:
                return Localization.string(
                    .pluginsErrorInstallUserPluginDirectoryUnavailable,
                    default: "User plugin folder is unavailable."
                )
            case let .sourceNotDirectory(url):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallSourceNotDirectory,
                        default: "Selected path is not a folder: %@"
                    ),
                    url.path
                )
            case let .missingManifest(url):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallMissingManifest,
                        default: "Selected folder does not contain notepad-mac-plugin.json: %@"
                    ),
                    url.path
                )
            case let .invalidManifest(_, reason):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallInvalidManifest,
                        default: "Selected plugin manifest is invalid: %@"
                    ),
                    reason
                )
            case let .windowsDLLOnly(url):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallWindowsDLLOnly,
                        default: "Selected folder appears to contain only a Windows DLL plugin. Native macOS plugins need a native entry point: %@"
                    ),
                    url.path
                )
            case let .invalidDestinationName(sourceFolderName, pluginIdentifier):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallInvalidDestinationName,
                        default: "Could not derive a safe plugin folder name from %@ or %@"
                    ),
                    sourceFolderName,
                    pluginIdentifier
                )
            }
        }

        if let removalError = self as? PluginRemovalError {
            switch removalError {
            case .userPluginDirectoryUnavailable:
                return Localization.string(
                    .pluginsErrorRemoveUserPluginDirectoryUnavailable,
                    default: "User plugin folder is unavailable."
                )
            case let .windowsOnlyPlugin(url):
                return String(
                    format: Localization.string(
                        .pluginsErrorRemoveWindowsOnly,
                        default: "Windows DLL plugins cannot be removed through the native manifest lifecycle: %@"
                    ),
                    url.path
                )
            case let .nonNativeManifestPlugin(identifier, kind):
                return String(
                    format: Localization.string(
                        .pluginsErrorRemoveNonNativeManifest,
                        default: "Plugin %@ is not a native manifest plugin: %@"
                    ),
                    identifier,
                    kind.displayName
                )
            case let .nonUserPluginLocation(pluginDirectoryURL, userPluginDirectoryURL):
                return String(
                    format: Localization.string(
                        .pluginsErrorRemoveNonUserLocation,
                        default: "Plugin folder %@ is outside the user plugin folder %@"
                    ),
                    pluginDirectoryURL.path,
                    userPluginDirectoryURL.path
                )
            case let .unsafePluginDirectoryName(directoryName):
                return String(
                    format: Localization.string(
                        .pluginsErrorRemoveUnsafeDirectoryName,
                        default: "Plugin folder name is not safe to remove: %@"
                    ),
                    directoryName
                )
            case let .missingPluginDirectory(url):
                return String(
                    format: Localization.string(
                        .pluginsErrorRemoveMissingPluginDirectory,
                        default: "Plugin folder no longer exists: %@"
                    ),
                    url.path
                )
            }
        }

        guard let runtimeError = self as? PluginCommandRuntime.Error else {
            return localizedDescription
        }

        switch runtimeError {
        case let .pluginNotFound(identifier):
            return String(
                format: Localization.string(
                    .pluginsErrorPluginNotFound,
                    default: "Plugin not found: %@"
                ),
                identifier
            )
        case let .incompatiblePlugin(pluginIdentifier, reason):
            return String(
                format: Localization.string(
                    .pluginsErrorPluginNotRunnable,
                    default: "Plugin %@ is not runnable: %@"
                ),
                pluginIdentifier,
                reason
            )
        case let .commandNotFound(pluginIdentifier, commandIdentifier):
            return String(
                format: Localization.string(
                    .pluginsErrorCommandNotFound,
                    default: "Command %@ was not found in plugin %@"
                ),
                commandIdentifier,
                pluginIdentifier
            )
        case let .missingEntryPoint(pluginIdentifier):
            return String(
                format: Localization.string(
                    .pluginsErrorMissingEntryPoint,
                    default: "Plugin %@ does not declare an entry point"
                ),
                pluginIdentifier
            )
        case let .entryPointMissing(url):
            return String(
                format: Localization.string(
                    .pluginsErrorEntryPointMissing,
                    default: "Entry point does not exist: %@"
                ),
                url.path
            )
        case let .entryPointOutsidePluginDirectory(entryURL, pluginDirectoryURL):
            return String(
                format: Localization.string(
                    .pluginsErrorEntryPointOutsideDirectory,
                    default: "Entry point %@ is outside plugin directory %@"
                ),
                entryURL.path,
                pluginDirectoryURL.path
            )
        case let .entryPointNotExecutable(url):
            return String(
                format: Localization.string(
                    .pluginsErrorEntryPointNotExecutable,
                    default: "Entry point is not executable: %@"
                ),
                url.path
            )
        }
    }
}

private extension PluginKind {
    var displayName: String {
        switch self {
        case .nativeManifest:
            Localization.string(.pluginsKindNativeManifest, default: "Native manifest")
        case .windowsDLL:
            Localization.string(.pluginsKindWindowsDLL, default: "Windows DLL")
        case .macOSBundle:
            Localization.string(.pluginsKindMacOSBundle, default: "macOS bundle")
        case .unsupported:
            Localization.string(.pluginsKindUnsupported, default: "Unsupported")
        }
    }
}

private extension PluginCompatibility {
    var displayText: String {
        switch self {
        case .nativeCompatible:
            Localization.string(.pluginsCompatibilityNativeCompatible, default: "Native compatible")
        case let .windowsOnly(reason):
            String(
                format: Localization.string(
                    .pluginsCompatibilityWindowsOnly,
                    default: "Windows only: %@"
                ),
                reason
            )
        case let .unsupported(reason):
            String(
                format: Localization.string(
                    .pluginsCompatibilityUnsupported,
                    default: "Unsupported: %@"
                ),
                reason
            )
        case let .invalidManifest(reason):
            String(
                format: Localization.string(
                    .pluginsCompatibilityInvalidManifest,
                    default: "Invalid manifest: %@"
                ),
                reason
            )
        }
    }
}
