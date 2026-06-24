import AppKit
import NotepadMacCore
import UniformTypeIdentifiers

@MainActor
final class PluginsPanelController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, AvailablePluginsViewControllerDelegate {
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
    private let tableScrollView = NSScrollView()
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
    private let installFromURLButton = NSButton(
        title: Localization.string(.pluginsInstallFromURL, default: "Install from URL..."),
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
    private let fetchAvailableButton = NSButton(
        title: Localization.string(.pluginsFetchAvailable, default: "Fetch Available"),
        target: nil,
        action: nil
    )
    private let checkUpdatesButton = NSButton(
        title: Localization.string(.pluginsCheckUpdates, default: "Check Updates"),
        target: nil,
        action: nil
    )
    private let installAvailableButton = NSButton(
        title: Localization.string(.pluginsInstallSelected, default: "Install Selected"),
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
    /// Applies a validated plugin edit script to the active editor buffer.
    /// Returns an error description, or nil on success.
    private let editScriptApplier: (PluginEditScript) -> String?
    private var pendingEditScriptURL: URL?
    private let runtime = PluginCommandRuntime()
    private let pluginColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("plugin"))
    private let commandColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
    private let identifierColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("identifier"))
    private let versionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))

    private var directories: [URL] = []
    private var catalog = PluginCatalog(plugins: [])
    private var runnableCommands: [RunnablePluginCommand] = []
    private var disabledNativePluginIdentifiers: Set<String> = []
    private var runningTask: Task<Void, Never>?
    private var stopRequested = false
    private var remoteCatalog: PluginRepositoryCatalog?
    private var availablePlugins: [PluginRepositoryEntry] = []
    private var updatePlugins: [(remote: PluginRepositoryEntry, installed: PluginDescriptor)] = []
    private let listModeSegmented = NSSegmentedControl()
    private let availablePluginsContainer = NSView()
    private var availablePluginsViewController: AvailablePluginsViewController?

    init(
        preferencesStore: PreferencesStore = PreferencesStore(),
        documentURLProvider: @escaping () -> URL? = { nil },
        selectionProvider: @escaping () -> PluginCommandSelectionContext? = { nil },
        editScriptApplier: @escaping (PluginEditScript) -> String? = { _ in
            Localization.string(.pluginsEditScriptNoEditor, default: "No active editor to apply plugin edits to.")
        }
    ) {
        self.preferencesStore = preferencesStore
        self.documentURLProvider = documentURLProvider
        self.selectionProvider = selectionProvider
        self.editScriptApplier = editScriptApplier

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = Localization.string(.pluginsPanelTitle, default: "Plugin Admin")
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
        if runningTask == nil {
            reload()
        }
        refreshLocalizedStrings()
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

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
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

        installFromURLButton.translatesAutoresizingMaskIntoConstraints = false
        installFromURLButton.bezelStyle = .rounded
        installFromURLButton.target = self
        installFromURLButton.action = #selector(installPluginFromURL(_:))

        removePluginButton.translatesAutoresizingMaskIntoConstraints = false
        removePluginButton.bezelStyle = .rounded
        removePluginButton.target = self
        removePluginButton.action = #selector(removeSelectedNativePlugin(_:))

        openPluginFolderButton.translatesAutoresizingMaskIntoConstraints = false
        openPluginFolderButton.bezelStyle = .rounded
        openPluginFolderButton.target = self
        openPluginFolderButton.action = #selector(openUserPluginFolder(_:))

        fetchAvailableButton.translatesAutoresizingMaskIntoConstraints = false
        fetchAvailableButton.bezelStyle = .rounded
        fetchAvailableButton.target = self
        fetchAvailableButton.action = #selector(fetchAvailablePlugins(_:))

        checkUpdatesButton.translatesAutoresizingMaskIntoConstraints = false
        checkUpdatesButton.bezelStyle = .rounded
        checkUpdatesButton.target = self
        checkUpdatesButton.action = #selector(checkForUpdates(_:))

        installAvailableButton.translatesAutoresizingMaskIntoConstraints = false
        installAvailableButton.bezelStyle = .rounded
        installAvailableButton.target = self
        installAvailableButton.action = #selector(installSelectedAvailablePlugin(_:))

        runButton.translatesAutoresizingMaskIntoConstraints = false
        runButton.bezelStyle = .rounded
        runButton.target = self
        runButton.action = #selector(runSelectedCommand(_:))

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
        pluginColumn.width = 210
        commandColumn.width = 230
        identifierColumn.width = 220
        versionColumn.width = 80
        tableView.addTableColumn(pluginColumn)
        tableView.addTableColumn(commandColumn)
        tableView.addTableColumn(identifierColumn)
        tableView.addTableColumn(versionColumn)
        tableScrollView.documentView = tableView

        listModeSegmented.translatesAutoresizingMaskIntoConstraints = false
        listModeSegmented.segmentCount = 2
        listModeSegmented.segmentStyle = .texturedRounded
        listModeSegmented.target = self
        listModeSegmented.action = #selector(listModeChanged(_:))
        listModeSegmented.selectedSegment = 0
        listModeSegmented.setLabel(
            Localization.string(.pluginsTabInstalled, default: "Installed Commands"),
            forSegment: 0
        )
        listModeSegmented.setLabel(
            Localization.string(.pluginsTabAvailable, default: "Available"),
            forSegment: 1
        )

        let availableController = AvailablePluginsViewController()
        availableController.delegate = self
        availablePluginsViewController = availableController

        availablePluginsContainer.translatesAutoresizingMaskIntoConstraints = false
        availablePluginsContainer.isHidden = true
        let availableView = availableController.view
        availableView.translatesAutoresizingMaskIntoConstraints = false
        availablePluginsContainer.addSubview(availableView)

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
        contentView.addSubview(installFromURLButton)
        contentView.addSubview(removePluginButton)
        contentView.addSubview(openPluginFolderButton)
        contentView.addSubview(fetchAvailableButton)
        contentView.addSubview(checkUpdatesButton)
        contentView.addSubview(installAvailableButton)
        contentView.addSubview(runButton)
        contentView.addSubview(tableScrollView)
        contentView.addSubview(listModeSegmented)
        contentView.addSubview(availablePluginsContainer)
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

            installFromURLButton.trailingAnchor.constraint(equalTo: installPluginButton.leadingAnchor, constant: -8),
            installFromURLButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            runButton.trailingAnchor.constraint(equalTo: installFromURLButton.leadingAnchor, constant: -8),
            runButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),

            nativePluginLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            nativePluginLabel.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 12),

            nativePluginPopUpButton.leadingAnchor.constraint(equalTo: nativePluginLabel.trailingAnchor, constant: 8),
            nativePluginPopUpButton.trailingAnchor.constraint(lessThanOrEqualTo: toggleNativePluginButton.leadingAnchor, constant: -8),
            nativePluginPopUpButton.centerYAnchor.constraint(equalTo: nativePluginLabel.centerYAnchor),
            nativePluginPopUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),

            toggleNativePluginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            toggleNativePluginButton.centerYAnchor.constraint(equalTo: nativePluginLabel.centerYAnchor),

            fetchAvailableButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            fetchAvailableButton.topAnchor.constraint(equalTo: nativePluginPopUpButton.bottomAnchor, constant: 10),

            checkUpdatesButton.leadingAnchor.constraint(equalTo: fetchAvailableButton.trailingAnchor, constant: 8),
            checkUpdatesButton.centerYAnchor.constraint(equalTo: fetchAvailableButton.centerYAnchor),

            installAvailableButton.leadingAnchor.constraint(equalTo: checkUpdatesButton.trailingAnchor, constant: 8),
            installAvailableButton.centerYAnchor.constraint(equalTo: fetchAvailableButton.centerYAnchor),

            argumentsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            argumentsLabel.topAnchor.constraint(equalTo: fetchAvailableButton.bottomAnchor, constant: 10),

            argumentsField.leadingAnchor.constraint(equalTo: argumentsLabel.trailingAnchor, constant: 8),
            argumentsField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            argumentsField.centerYAnchor.constraint(equalTo: argumentsLabel.centerYAnchor),

            tableScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            tableScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            listModeSegmented.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            listModeSegmented.topAnchor.constraint(equalTo: argumentsField.bottomAnchor, constant: 12),
            listModeSegmented.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),

            tableScrollView.topAnchor.constraint(equalTo: listModeSegmented.bottomAnchor, constant: 10),
            tableScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),

            availablePluginsContainer.leadingAnchor.constraint(equalTo: tableScrollView.leadingAnchor),
            availablePluginsContainer.trailingAnchor.constraint(equalTo: tableScrollView.trailingAnchor),
            availablePluginsContainer.topAnchor.constraint(equalTo: tableScrollView.topAnchor),
            availablePluginsContainer.bottomAnchor.constraint(equalTo: tableScrollView.bottomAnchor),
            availableView.leadingAnchor.constraint(equalTo: availablePluginsContainer.leadingAnchor),
            availableView.trailingAnchor.constraint(equalTo: availablePluginsContainer.trailingAnchor),
            availableView.topAnchor.constraint(equalTo: availablePluginsContainer.topAnchor),
            availableView.bottomAnchor.constraint(equalTo: availablePluginsContainer.bottomAnchor),

            statusScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            statusScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            statusScrollView.topAnchor.constraint(equalTo: tableScrollView.bottomAnchor, constant: 10),
            statusScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            statusScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.pluginsPanelTitle, default: "Plugin Admin")
        nativePluginLabel.stringValue = Localization.string(.pluginsNativePluginLabel, default: "Native plugin:")
        argumentsLabel.stringValue = Localization.string(.pluginsArgumentsLabel, default: "Arguments:")
        refreshButton.title = Localization.string(.pluginsRefresh, default: "Rescan")
        installPluginButton.title = Localization.string(.pluginsInstallOrUpdate, default: "Install/Update...")
        installFromURLButton.title = Localization.string(.pluginsInstallFromURL, default: "Install from URL...")
        removePluginButton.title = Localization.string(.pluginsRemove, default: "Remove")
        openPluginFolderButton.title = Localization.string(.pluginsOpenUserPluginFolder, default: "Open Plugin Folder")
        fetchAvailableButton.title = Localization.string(.pluginsFetchAvailable, default: "Fetch Available")
        checkUpdatesButton.title = Localization.string(.pluginsCheckUpdates, default: "Check Updates")
        installAvailableButton.title = Localization.string(.pluginsInstallSelected, default: "Install Selected")
        pluginColumn.title = Localization.string(.pluginsColumnPlugin, default: "Plugin")
        commandColumn.title = Localization.string(.pluginsColumnCommand, default: "Command")
        identifierColumn.title = Localization.string(.pluginsColumnIdentifier, default: "Identifier")
        versionColumn.title = Localization.string(.pluginsColumnVersion, default: "Version")
        listModeSegmented.setLabel(
            Localization.string(.pluginsTabInstalled, default: "Installed Commands"),
            forSegment: 0
        )
        listModeSegmented.setLabel(
            Localization.string(.pluginsTabAvailable, default: "Available"),
            forSegment: 1
        )
        availablePluginsViewController?.refreshLocalization()

        if let selectedIdentifier = selectedNativePluginIdentifier() {
            reloadNativePluginMenu(preferredIdentifier: selectedIdentifier)
        } else {
            reloadNativePluginMenu(preferredIdentifier: nil)
        }

        if runningTask == nil {
            summaryField.stringValue = localizedSummary()
            statusView.string = render(catalog: catalog, directories: directories)
        }

        updateControls()
    }

    private func localizedSummary() -> String {
        let summaryKey: Localization.Key = runnableCommands.count == 1
            ? .pluginsSummaryRunnableCommand
            : .pluginsSummaryRunnableCommands
        let summaryDefault = runnableCommands.count == 1
            ? "%d runnable native command"
            : "%d runnable native commands"
        return String(
            format: Localization.string(summaryKey, default: summaryDefault),
            runnableCommands.count
        )
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

        summaryField.stringValue = localizedSummary()
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
                default: "Native plugins declare commands via notepad-mac-plugin.json and can be executed directly."
            ),
            Localization.string(
                .pluginsReportWindowsDllCompatibility,
                default: "Windows Notepad++ DLL plugins are detected for compatibility reporting only; they cannot be loaded on macOS."
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
            if let desc = plugin.pluginDescription, !desc.isEmpty {
                lines.append("  " + desc)
            }
            lines.append("  " + String(
                format: Localization.string(.pluginsReportKind, default: "Kind: %@"),
                plugin.kind.displayName
            ))
            lines.append("  " + String(
                format: Localization.string(.pluginsReportStatus, default: "Status: %@"),
                plugin.compatibility.displayText
            ))
            if let author = plugin.author, !author.isEmpty {
                lines.append("  " + String(
                    format: Localization.string(.pluginsReportAuthor, default: "Author: %@"),
                    author
                ))
            }
            if let homepage = plugin.homepage, !homepage.isEmpty {
                lines.append("  " + String(
                    format: Localization.string(.pluginsReportHomepage, default: "Homepage: %@"),
                    homepage
                ))
            }
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
        installFromURLButton.isEnabled = runningTask == nil && PluginCatalog.userPluginDirectory() != nil
        removePluginButton.isEnabled = runningTask == nil
            && PluginCatalog.userPluginDirectory() != nil
            && selectedNativePluginIdentifier() != nil
        openPluginFolderButton.isEnabled = PluginCatalog.userPluginDirectory() != nil
        fetchAvailableButton.isEnabled = runningTask == nil
        checkUpdatesButton.isEnabled = runningTask == nil
        installAvailableButton.isEnabled = runningTask == nil && !availablePlugins.isEmpty
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

    func importPlugin(from sourceURL: URL) {
        guard let userPluginDirectory = PluginCatalog.userPluginDirectory() else { return }
        show()
        guard runningTask == nil else {
            appendStatus(Localization.string(
                .pluginsStatusInstallSkippedWhileRunning,
                default: "Install skipped: a plugin command is still running."
            ))
            return
        }
        do {
            let result = sourceURL.pathExtension.lowercased() == "zip"
                ? try PluginCatalog.installNativePlugin(fromArchive: sourceURL, into: userPluginDirectory)
                : try PluginCatalog.installNativePlugin(from: sourceURL, into: userPluginDirectory)
            reload(preferredNativePluginIdentifier: result.plugin.identifier)
            appendStatus(installationStatusText(for: result))
        } catch {
            appendStatus(String(
                format: Localization.string(.pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                error.displayText
            ))
        }
    }

    /// Status line for an installation result, including the version
    /// transition for updates when both versions are known.
    private func installationStatusText(for result: PluginInstallationResult) -> String {
        switch result.action {
        case .installed:
            return String(
                format: Localization.string(
                    .pluginsStatusInstalledNativePlugin, default: "Installed native plugin %@ to %@"),
                result.plugin.displayName,
                result.destinationURL.path
            )
        case .updated:
            if let previous = result.previousVersion,
               let current = result.plugin.version,
               previous != current {
                return String(
                    format: Localization.string(
                        .pluginsStatusUpdatedNativePluginVersion,
                        default: "Updated native plugin %@ from %@ to %@"),
                    result.plugin.displayName,
                    previous,
                    current
                )
            }
            return String(
                format: Localization.string(
                    .pluginsStatusUpdatedNativePlugin, default: "Updated native plugin %@ at %@"),
                result.plugin.displayName,
                result.destinationURL.path
            )
        case .unchanged:
            return String(
                format: Localization.string(
                    .pluginsStatusNativePluginAlreadyInstalled,
                    default: "Native plugin %@ is already installed at %@"),
                result.plugin.displayName,
                result.destinationURL.path
            )
        }
    }

    @objc private func installPluginFromURL(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(
                .pluginsStatusInstallSkippedWhileRunning,
                default: "Install skipped: a plugin command is still running."
            ))
            return
        }
        guard PluginCatalog.userPluginDirectory() != nil else {
            appendStatus(Localization.string(
                .pluginsStatusOpenUserPluginFolderUnavailable,
                default: "User plugin folder is unavailable."
            ))
            return
        }

        let alert = NSAlert()
        alert.messageText = Localization.string(
            .pluginsInstallFromURLTitle, default: "Install Plugin from URL")
        alert.informativeText = Localization.string(
            .pluginsInstallFromURLMessage,
            default: "Enter the URL of a plugin .zip archive.")
        let field = NSTextField(string: "")
        field.placeholderString = "https://example.com/plugin.zip"
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: Localization.string(.pluginsInstallPanelPrompt, default: "Install"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let urlText = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remoteURL = URL(string: urlText),
              let scheme = remoteURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            appendStatus(String(
                format: Localization.string(
                    .pluginsStatusInstallURLInvalid, default: "Invalid plugin URL: %@"),
                urlText
            ))
            return
        }

        appendStatus(String(
            format: Localization.string(
                .pluginsStatusDownloadingPlugin, default: "Downloading plugin from %@ ..."),
            remoteURL.absoluteString
        ))

        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] location, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.appendStatus(String(
                        format: Localization.string(
                            .pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                        error.localizedDescription
                    ))
                    return
                }
                guard let location,
                      let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode)
                else {
                    self.appendStatus(String(
                        format: Localization.string(
                            .pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                        "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    ))
                    return
                }
                // Keep a .zip path extension so the archive path is taken.
                let stagedURL = FileManager.default.temporaryDirectory
                    .appending(path: "notepad-mac-plugin-download-\(UUID().uuidString).zip")
                do {
                    try FileManager.default.moveItem(at: location, to: stagedURL)
                    defer { try? FileManager.default.removeItem(at: stagedURL) }
                    let result = try PluginCatalog.installNativePlugin(fromArchive: stagedURL)
                    self.reload(preferredNativePluginIdentifier: result.plugin.identifier)
                    self.appendStatus(self.installationStatusText(for: result))
                } catch {
                    self.appendStatus(String(
                        format: Localization.string(
                            .pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                        error.displayText
                    ))
                }
            }
        }
        task.resume()
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
            default: "Choose a folder containing notepad-mac-plugin.json, or a .zip archive of one."
        )
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            return
        }

        do {
            let result = sourceURL.pathExtension.lowercased() == "zip"
                ? try PluginCatalog.installNativePlugin(fromArchive: sourceURL, into: userPluginDirectory)
                : try PluginCatalog.installNativePlugin(from: sourceURL, into: userPluginDirectory)
            reload(preferredNativePluginIdentifier: result.plugin.identifier)
            appendStatus(installationStatusText(for: result))
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

    @objc private func listModeChanged(_ sender: NSSegmentedControl) {
        let showAvailable = sender.selectedSegment == 1
        tableScrollView.isHidden = showAvailable
        availablePluginsContainer.isHidden = !showAvailable
        updateControls()
    }

    private func installAvailableEntry(_ entry: PluginRepositoryEntry) {
        guard runningTask == nil else {
            appendStatus(Localization.string(.pluginsStatusBusy, default: "Action skipped: a plugin command is still running."))
            return
        }

        appendStatus(String(
            format: Localization.string(.pluginsStatusInstallingFromRepo, default: "Installing %@ from repository..."),
            entry.name
        ))

        let task = Task { @MainActor in
            do {
                let result = try await PluginRepository.installFromRepository(entry: entry)
                self.reload(preferredNativePluginIdentifier: result.plugin.identifier)
                self.appendStatus(self.installationStatusText(for: result))
                if let remoteCatalog = self.remoteCatalog {
                    let comparison = PluginRepository.compare(remote: remoteCatalog, installed: self.catalog)
                    self.availablePlugins = comparison.available
                    self.updatePlugins = comparison.updates
                    self.availablePluginsViewController?.update(entries: comparison.available)
                }
            } catch {
                self.appendStatus(String(
                    format: Localization.string(.pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                    error.localizedDescription
                ))
            }
            self.runningTask = nil
            self.stopRequested = false
            self.updateControls()
        }
        runningTask = task
        stopRequested = false
        updateControls()
    }

    // MARK: - AvailablePluginsViewControllerDelegate

    func availablePluginsViewController(
        _ controller: AvailablePluginsViewController,
        didRequestInstall entry: PluginRepositoryEntry
    ) {
        installAvailableEntry(entry)
    }

    @objc private func fetchAvailablePlugins(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(.pluginsStatusBusy, default: "Action skipped: a plugin command is still running."))
            return
        }

        appendStatus(Localization.string(.pluginsStatusFetchingAvailable, default: "Fetching available plugin catalog..."))
        let task = Task { @MainActor in
            let fetched = await PluginRepository.fetchCatalog()
            self.remoteCatalog = fetched
            if let fetched {
                let comparison = PluginRepository.compare(remote: fetched, installed: self.catalog)
                self.availablePlugins = comparison.available
                self.updatePlugins = comparison.updates
                self.availablePluginsViewController?.update(entries: comparison.available)

                self.appendStatus(String(
                    format: Localization.string(
                        .pluginsStatusFetchSuccess,
                        default: "Catalog loaded: %d available, %d updates."
                    ),
                    self.availablePlugins.count,
                    self.updatePlugins.count
                ))
                self.renderRemoteInfo()
                self.listModeSegmented.selectedSegment = 1
                self.listModeChanged(self.listModeSegmented)
            } else {
                self.appendStatus(Localization.string(
                    .pluginsStatusFetchFailed,
                    default: "Failed to fetch plugin catalog. Check network connection."
                ))
            }
            self.runningTask = nil
            self.stopRequested = false
            self.updateControls()
        }
        runningTask = task
        stopRequested = false
        updateControls()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(.pluginsStatusBusy, default: "Action skipped: a plugin command is still running."))
            return
        }

        // If catalog hasn been fetched, fetch first
        if remoteCatalog == nil {
            fetchAvailablePlugins(sender)
            return
        }

        if updatePlugins.isEmpty {
            appendStatus(Localization.string(
                .pluginsStatusNoUpdates,
                default: "No plugin updates available."
            ))
            return
        }

        appendStatus(Localization.string(.pluginsReportUpdatesHeader, default: "Available updates:"))
        for update in updatePlugins {
            appendStatus("  \(update.remote.name) \(update.remote.version ?? "?") → \(update.installed.version ?? "?")")
        }
    }

    @objc private func installSelectedAvailablePlugin(_ sender: Any?) {
        guard runningTask == nil else {
            appendStatus(Localization.string(.pluginsStatusBusy, default: "Action skipped: a plugin command is still running."))
            return
        }

        guard !availablePlugins.isEmpty else {
            appendStatus(Localization.string(
                .pluginsStatusNoAvailable,
                default: "No available plugins to install. Fetch the catalog first."
            ))
            return
        }

        // Show selection dialog
        let alert = NSAlert()
        alert.messageText = Localization.string(
            .pluginsInstallAvailableTitle,
            default: "Install Available Plugin"
        )
        alert.informativeText = Localization.string(
            .pluginsInstallAvailableMessage,
            default: "Select a plugin to install from the catalog."
        )
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        for entry in availablePlugins {
            popup.addItem(withTitle: "\(entry.name) (\(entry.version ?? "latest"))")
            popup.lastItem?.representedObject = entry.identifier
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: Localization.string(.pluginsInstallPanelPrompt, default: "Install"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let selectedIdentifier = popup.selectedItem?.representedObject as? String,
              let entry = availablePlugins.first(where: { $0.identifier == selectedIdentifier })
        else { return }

        appendStatus(String(
            format: Localization.string(.pluginsStatusInstallingFromRepo, default: "Installing %@ from repository..."),
            entry.name
        ))

        let task = Task { @MainActor in
            do {
                let result = try await PluginRepository.installFromRepository(entry: entry)
                self.reload(preferredNativePluginIdentifier: result.plugin.identifier)
                self.appendStatus(self.installationStatusText(for: result))
                // Re-compare after install
                if let remoteCatalog = self.remoteCatalog {
                    let comparison = PluginRepository.compare(remote: remoteCatalog, installed: self.catalog)
                    self.availablePlugins = comparison.available
                    self.updatePlugins = comparison.updates
                }
            } catch {
                self.appendStatus(String(
                    format: Localization.string(.pluginsStatusInstallFailed, default: "Install/update failed: %@"),
                    error.localizedDescription
                ))
            }
            self.runningTask = nil
            self.stopRequested = false
            self.updateControls()
        }
        runningTask = task
        stopRequested = false
        updateControls()
    }

    private func renderRemoteInfo() {
        if availablePlugins.isEmpty && updatePlugins.isEmpty { return }

        if !availablePlugins.isEmpty {
            appendStatus("")
            appendStatus(Localization.string(.pluginsReportAvailableHeader, default: "Available plugins (not installed):"))
            for entry in availablePlugins {
                var line = "  \(entry.name) (\(entry.version ?? "latest"))"
                if let desc = entry.description, !desc.isEmpty {
                    line += " — \(desc)"
                }
                appendStatus(line)
            }
        }

        if !updatePlugins.isEmpty {
            appendStatus("")
            appendStatus(Localization.string(.pluginsReportUpdatesHeader, default: "Available updates:"))
            for update in updatePlugins {
                appendStatus("  \(update.remote.name): installed \(update.installed.version ?? "?") → available \(update.remote.version ?? "?")")
            }
        }

        // Show upstream Windows DLL reference info
        if let remoteCatalog {
            let upstreamDLLs = remoteCatalog.plugins.filter { $0.upstreamWindowsDLL == true }
            if !upstreamDLLs.isEmpty {
                appendStatus("")
                appendStatus(Localization.string(
                    .pluginsReportUpstreamDLLs,
                    default: "Upstream Windows DLL plugins (not loadable on macOS, listed for reference):"
                ))
                for entry in upstreamDLLs {
                    var line = "  \(entry.name) (\(entry.version ?? "?"))"
                    if let desc = entry.description, !desc.isEmpty {
                        let shortDesc = desc.count > 80 ? String(desc.prefix(77)) + "..." : desc
                        line += " — \(shortDesc)"
                    }
                    appendStatus(line)
                }
            }
        }
    }

    @objc private func runSelectedCommand(_ sender: Any?) {
        guard runningTask == nil, let item = selectedCommand() else {
            return
        }

        do {
            let arguments = try commandArguments()
            let editScriptURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("notepad-mac-edit-script-\(UUID().uuidString).json")
            pendingEditScriptURL = editScriptURL
            let invocation = PluginCommandInvocation(
                pluginIdentifier: item.plugin.identifier,
                commandIdentifier: item.command.identifier,
                arguments: arguments,
                documentURL: documentURLProvider(),
                selection: selectionProvider(),
                editScriptFileURL: editScriptURL
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
        processPendingEditScript(
            commandSucceeded: !wasCancelled
                && result.terminationReason == .exit
                && result.terminationStatus == 0
        )
        updateControls()
    }

    /// Reads, validates, and applies the edit script the plugin may have left
    /// at the host-provided path, then removes the temp file.
    private func processPendingEditScript(commandSucceeded: Bool) {
        guard let url = pendingEditScriptURL else { return }
        pendingEditScriptURL = nil
        defer { try? FileManager.default.removeItem(at: url) }

        guard commandSucceeded,
              let data = try? Data(contentsOf: url),
              !data.isEmpty
        else { return }

        let script: PluginEditScript
        do {
            script = try PluginEditScript.decode(data)
        } catch {
            appendStatus(String(
                format: Localization.string(.pluginsEditScriptInvalid, default: "Edit script rejected: %@"),
                String(describing: error)
            ))
            return
        }

        if let problem = editScriptApplier(script) {
            appendStatus(String(
                format: Localization.string(.pluginsEditScriptApplyFailed, default: "Edit script not applied: %@"),
                problem
            ))
        } else {
            appendStatus(String(
                format: Localization.string(.pluginsEditScriptApplied, default: "Applied %d buffer edit(s) from plugin."),
                script.edits.count
            ))
        }
    }

    private func failRunningCommand(
        _ commandDescription: String,
        error: Swift.Error,
        wasCancelled: Bool
    ) {
        runningTask = nil
        stopRequested = false
        processPendingEditScript(commandSucceeded: false)
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
            case let .archiveExtractionFailed(url, reason):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallArchiveExtractionFailed,
                        default: "Could not extract plugin archive %@: %@"
                    ),
                    url.lastPathComponent,
                    reason
                )
            case let .archiveMissingManifest(url):
                return String(
                    format: Localization.string(
                        .pluginsErrorInstallArchiveMissingManifest,
                        default: "Archive does not contain notepad-mac-plugin.json: %@"
                    ),
                    url.lastPathComponent
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
