import AppKit
import NotepadMacCore

/// Shortcut Mapper panel — shows all menu shortcuts and allows custom key assignments.
@MainActor
final class ShortcutMapperPanelController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    struct Entry {
        let title: String           // menu item title
        let menuItem: NSMenuItem?   // weak-ish reference (menu items owned by NSMenu)
        var keyEquivalent: String
        var modifierFlags: Int      // NSEvent.ModifierFlags.rawValue
        var isCustom: Bool

        var displayShortcut: String {
            if keyEquivalent.isEmpty { return "" }
            var s = ""
            let raw = UInt(bitPattern: modifierFlags)
            if raw & (1 << 18) != 0 { s += "⌃" }  // control
            if raw & (1 << 19) != 0 { s += "⌥" }  // option
            if raw & (1 << 17) != 0 { s += "⇧" }  // shift
            if raw & (1 << 20) != 0 { s += "⌘" }  // command
            return s + keyEquivalent.uppercased()
        }
    }

    // MARK: - Category

    enum Category: Int {
        case mainMenu = 0, macros = 1, runCommands = 2, pluginCommands = 3
    }
    private var currentCategory: Category = .mainMenu

    private let categoryControl = NSSegmentedControl()

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let assignButton = NSButton(title: "", target: nil, action: nil)
    private let clearButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let exportImportButton = NSPopUpButton()

    private var allEntries: [Entry] = []
    private var filteredEntries: [Entry] = []

    private let shortcutStore: CustomShortcutStore
    private let macroShortcutStore: MacroShortcutStore
    private let savedRunCommandStore: SavedRunCommandStore
    private let pluginCommandShortcutStore: PluginCommandShortcutStore
    /// Plugin catalog for enumerating plugin commands in the Plugin Commands tab
    var pluginCatalog: PluginCatalog?
    var onShortcutsChanged: (() -> Void)?
    /// Called when macro menu should be rebuilt (e.g. after shortcut change)
    var onMacroShortcutsChanged: (() -> Void)?

    init(shortcutStore: CustomShortcutStore = CustomShortcutStore(),
         macroShortcutStore: MacroShortcutStore = MacroShortcutStore(),
         savedRunCommandStore: SavedRunCommandStore = SavedRunCommandStore(),
         pluginCommandShortcutStore: PluginCommandShortcutStore = PluginCommandShortcutStore()) {
        self.shortcutStore = shortcutStore
        self.macroShortcutStore = macroShortcutStore
        self.savedRunCommandStore = savedRunCommandStore
        self.pluginCommandShortcutStore = pluginCommandShortcutStore
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 500),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 420, height: 300)
        super.init(window: panel)
        buildEntries()
        filteredEntries = allEntries
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
    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    func show() {
        buildEntries()
        filteredEntries = allEntries
        tableView.reloadData()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Build entries

    func buildEntries() {
        switch currentCategory {
        case .mainMenu:
            buildMainMenuEntries()
        case .macros:
            buildMacroEntries()
        case .runCommands:
            buildRunCommandEntries()
        case .pluginCommands:
            buildPluginCommandEntries()
        }
    }

    private func buildMainMenuEntries() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let customMap = Dictionary(uniqueKeysWithValues: shortcutStore.load().map { ($0.menuItemTitle, $0) })
        var entries: [Entry] = []
        collectEntries(from: mainMenu.items, into: &entries, customMap: customMap)
        allEntries = entries
    }

    private func buildMacroEntries() {
        let shortcuts = Dictionary(uniqueKeysWithValues: macroShortcutStore.load().map { ($0.macroName.lowercased(), $0) })
        // Load from active editor's macroStore via AppDelegate
        let appDelegate = NSApp.delegate as? AppDelegate
        let macros = appDelegate?.activeEditorController()?.namedMacros() ?? []
        allEntries = macros.map { macro in
            let sc = shortcuts[macro.name.lowercased()]
            return Entry(
                title: macro.name,
                menuItem: nil,
                keyEquivalent: sc?.keyEquivalent ?? "",
                modifierFlags: sc?.modifierFlags ?? 0,
                isCustom: sc != nil
            )
        }
        // If no named macros, show a placeholder
        if allEntries.isEmpty {
            allEntries = [Entry(title: "(No saved macros)", menuItem: nil, keyEquivalent: "", modifierFlags: 0, isCustom: false)]
        }
    }

    private func buildRunCommandEntries() {
        allEntries = savedRunCommandStore.load().map { cmd in
            Entry(
                title: cmd.name,
                menuItem: nil,
                keyEquivalent: cmd.keyEquivalent,
                modifierFlags: cmd.modifierFlags,
                isCustom: !cmd.keyEquivalent.isEmpty
            )
        }
        if allEntries.isEmpty {
            allEntries = [Entry(title: "(No saved run commands)", menuItem: nil, keyEquivalent: "", modifierFlags: 0, isCustom: false)]
        }
    }

    private func buildPluginCommandEntries() {
        let catalog = pluginCatalog ?? PluginCatalog.scan(directories: PluginCatalog.defaultPluginDirectories())
        let plugins = catalog.plugins.filter { $0.commands.count > 0 }
        guard !plugins.isEmpty else {
            allEntries = [Entry(title: "(No plugin commands)", menuItem: nil, keyEquivalent: "", modifierFlags: 0, isCustom: false)]
            return
        }
        var entries: [Entry] = []
        for plugin in plugins {
            for cmd in plugin.commands {
                let sc = pluginCommandShortcutStore.shortcut(forPlugin: plugin.identifier, command: cmd.identifier)
                entries.append(Entry(
                    title: "\(plugin.displayName): \(cmd.title)",
                    menuItem: nil,
                    keyEquivalent: sc?.keyEquivalent ?? "",
                    modifierFlags: sc?.modifierFlags ?? 0,
                    isCustom: sc != nil
                ))
            }
        }
        allEntries = entries
    }

    private func collectEntries(from items: [NSMenuItem], into result: inout [Entry], customMap: [String: CustomShortcut]) {
        for item in items {
            guard !item.title.isEmpty, !item.isSeparatorItem else { continue }
            if let custom = customMap[item.title] {
                result.append(Entry(
                    title: item.title,
                    menuItem: item,
                    keyEquivalent: custom.keyEquivalent,
                    modifierFlags: custom.modifierFlags,
                    isCustom: true
                ))
            } else if !item.keyEquivalent.isEmpty {
                result.append(Entry(
                    title: item.title,
                    menuItem: item,
                    keyEquivalent: item.keyEquivalent,
                    modifierFlags: Int(item.keyEquivalentModifierMask.rawValue),
                    isCustom: false
                ))
            } else if item.submenu == nil {
                // No shortcut, still show so user can assign one
                result.append(Entry(
                    title: item.title,
                    menuItem: item,
                    keyEquivalent: "",
                    modifierFlags: 0,
                    isCustom: false
                ))
            }
            if let submenu = item.submenu {
                collectEntries(from: submenu.items, into: &result, customMap: customMap)
            }
        }
    }

    // MARK: - Apply shortcuts to menu

    func applyStoredShortcuts() {
        let stored = shortcutStore.load()
        guard let mainMenu = NSApp.mainMenu else { return }
        applyShortcuts(stored, to: mainMenu.items)
    }

    private func applyShortcuts(_ shortcuts: [CustomShortcut], to items: [NSMenuItem]) {
        let map = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.menuItemTitle, $0) })
        applyMap(map, to: items)
    }

    private func applyMap(_ map: [String: CustomShortcut], to items: [NSMenuItem]) {
        for item in items {
            if let custom = map[item.title] {
                item.keyEquivalent = custom.keyEquivalent
                item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(bitPattern: custom.modifierFlags))
            }
            if let submenu = item.submenu {
                applyMap(map, to: submenu.items)
            }
        }
    }

    // MARK: - Actions

    @objc private func assignShortcut(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredEntries.count else { return }
        let entry = filteredEntries[row]
        promptForShortcut(entry: entry)
    }

    @objc private func clearShortcut(_ sender: Any?) {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredEntries.count else { return }
        let entry = filteredEntries[row]
        guard entry.isCustom else { return }
        switch currentCategory {
        case .mainMenu:
            shortcutStore.removeShortcut(forTitle: entry.title)
            if let item = entry.menuItem {
                item.keyEquivalent = ""
                item.keyEquivalentModifierMask = []
            }
            onShortcutsChanged?()
        case .macros:
            macroShortcutStore.removeShortcut(for: entry.title)
            onMacroShortcutsChanged?()
        case .runCommands:
            var commands = savedRunCommandStore.load()
            if let idx = commands.firstIndex(where: { $0.name == entry.title }) {
                commands[idx].keyEquivalent = ""
                commands[idx].modifierFlags = 0
                savedRunCommandStore.save(commands)
            }
            onShortcutsChanged?()
        case .pluginCommands:
            let parts = entry.title.components(separatedBy: ": ")
            guard parts.count >= 2 else { break }
            let pluginName = parts[0]
            let commandTitle = parts.dropFirst().joined(separator: ": ")
            if let plugin = pluginCatalog?.plugins.first(where: { $0.displayName == pluginName }),
               let cmd = plugin.commands.first(where: { $0.title == commandTitle }) {
                pluginCommandShortcutStore.clearShortcut(forPlugin: plugin.identifier, command: cmd.identifier)
            }
        }
        buildEntries()
        applyFilter()
        statusLabel.stringValue = Localization.string(.shortcutMapperCleared, default: "Shortcut cleared.")
    }

    // MARK: - Export / Import

    @objc private func exportShortcuts(_ sender: Any?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let shortcuts = shortcutStore.load()
        guard !shortcuts.isEmpty else {
            statusLabel.stringValue = "No custom shortcuts to export."
            return
        }
        guard let data = try? encoder.encode(shortcuts) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "NotepadMac-Shortcuts.json"
        panel.title = "Export Shortcuts"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            statusLabel.stringValue = "Shortcuts exported to \(url.lastPathComponent)."
        } catch {
            statusLabel.stringValue = "Export failed: \(error.localizedDescription)"
        }
    }

    @objc private func importShortcuts(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = "Import Shortcuts"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let shortcuts = try decoder.decode([CustomShortcut].self, from: data)
            shortcutStore.save(shortcuts)
            buildEntries()
            applyFilter()
            onShortcutsChanged?()
            statusLabel.stringValue = "Imported \(shortcuts.count) shortcuts from \(url.lastPathComponent)."
        } catch {
            statusLabel.stringValue = "Import failed: \(error.localizedDescription)"
        }
    }

    private func promptForShortcut(entry: Entry) {
        let recorder = ShortcutRecorderView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        let alert = NSAlert()
        let assignTitle = Localization.string(.shortcutMapperAssignTitle, default: "Assign Shortcut")
        alert.messageText = "\(assignTitle): \(entry.title)"
        alert.informativeText = Localization.string(.shortcutMapperAssignHint, default: "Press the new key combination, then click Assign.")
        alert.accessoryView = recorder
        alert.addButton(withTitle: Localization.string(.shortcutMapperAssignButton, default: "Assign"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        alert.window.initialFirstResponder = recorder

        guard alert.runModal() == .alertFirstButtonReturn,
              !recorder.keyEquivalent.isEmpty else { return }

        let keyEq = recorder.keyEquivalent
        let mods = Int(bitPattern: UInt(recorder.modifierFlags.rawValue))

        // Conflict check against other menu items (not stores)
        if let conflictTitle = findMenuConflict(keyEquivalent: keyEq, modifiers: NSEvent.ModifierFlags(rawValue: UInt(bitPattern: mods)), excluding: entry.title) {
            let warn = NSAlert()
            warn.messageText = Localization.string(.shortcutMapperConflictTitle, default: "Shortcut Conflict")
            let conflictMsg = Localization.string(.shortcutMapperConflictMessage, default: "Already used by: ")
            warn.informativeText = "\(conflictMsg)\(conflictTitle). Assign anyway?"
            warn.addButton(withTitle: Localization.string(.shortcutMapperAssignButton, default: "Assign"))
            warn.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
            guard warn.runModal() == .alertFirstButtonReturn else { return }
        }

        let shortcutDisplay: String
        switch currentCategory {
        case .mainMenu:
            let custom = CustomShortcut(menuItemTitle: entry.title, keyEquivalent: keyEq, modifierFlags: mods)
            shortcutStore.setShortcut(custom)
            entry.menuItem?.keyEquivalent = keyEq
            entry.menuItem?.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(bitPattern: mods))
            shortcutDisplay = custom.displayString
            onShortcutsChanged?()
        case .macros:
            let sc = MacroShortcut(macroName: entry.title, keyEquivalent: keyEq, modifierFlags: mods)
            macroShortcutStore.setShortcut(sc)
            shortcutDisplay = sc.displayString
            onMacroShortcutsChanged?()
        case .runCommands:
            var commands = savedRunCommandStore.load()
            if let idx = commands.firstIndex(where: { $0.name == entry.title }) {
                commands[idx].keyEquivalent = keyEq
                commands[idx].modifierFlags = mods
                savedRunCommandStore.save(commands)
            }
            shortcutDisplay = MacroShortcut(macroName: "", keyEquivalent: keyEq, modifierFlags: mods).displayString
            onShortcutsChanged?()
        case .pluginCommands:
            let parts = entry.title.components(separatedBy: ": ")
            guard parts.count >= 2 else {
                shortcutDisplay = ""
                break
            }
            let pluginName = parts[0]
            let commandTitle = parts.dropFirst().joined(separator: ": ")
            if let plugin = pluginCatalog?.plugins.first(where: { $0.displayName == pluginName }),
               let cmd = plugin.commands.first(where: { $0.title == commandTitle }) {
                let sc = PluginCommandShortcut(
                    pluginIdentifier: plugin.identifier,
                    commandIdentifier: cmd.identifier,
                    keyEquivalent: keyEq,
                    modifierFlags: mods
                )
                pluginCommandShortcutStore.setShortcut(sc)
                shortcutDisplay = sc.displayString
            } else {
                shortcutDisplay = ""
            }
        }
        buildEntries()
        applyFilter()
        let assignedMsg = Localization.string(.shortcutMapperAssigned, default: "Assigned")
        statusLabel.stringValue = "\(assignedMsg) \(shortcutDisplay) → \(entry.title)"
    }

    private func findMenuConflict(keyEquivalent: String, modifiers: NSEvent.ModifierFlags, excluding title: String) -> String? {
        guard let mainMenu = NSApp.mainMenu else { return nil }
        return searchConflict(in: mainMenu.items, keyEquivalent: keyEquivalent, modifiers: modifiers, excluding: title)
    }

    private func searchConflict(in items: [NSMenuItem], keyEquivalent: String, modifiers: NSEvent.ModifierFlags, excluding title: String) -> String? {
        for item in items {
            if item.title != title,
               item.keyEquivalent.lowercased() == keyEquivalent.lowercased(),
               item.keyEquivalentModifierMask == modifiers {
                return item.title
            }
            if let sub = item.submenu,
               let found = searchConflict(in: sub.items, keyEquivalent: keyEquivalent, modifiers: modifiers, excluding: title) {
                return found
            }
        }
        return nil
    }

    // MARK: - Search

    @objc private func searchChanged(_ sender: NSSearchField) {
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredEntries = allEntries
        } else {
            filteredEntries = allEntries.filter {
                $0.title.lowercased().contains(query) ||
                $0.displayShortcut.lowercased().contains(query)
            }
        }
        tableView.reloadData()
        updateButtonStates()
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int { filteredEntries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredEntries.count else { return nil }
        let entry = filteredEntries[row]
        let id = tableColumn?.identifier.rawValue ?? "action"
        let text: String
        switch id {
        case "action":    text = entry.title
        case "shortcut":  text = entry.displayShortcut
        default:          text = ""
        }
        let cell = NSTextField(labelWithString: text)
        cell.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        if entry.isCustom && id == "shortcut" {
            cell.textColor = .systemBlue
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonStates()
    }

    // MARK: - Localization / refresh

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.shortcutMapperTitle, default: "Shortcut Mapper")
        searchField.placeholderString = Localization.string(.shortcutMapperSearch, default: "Filter shortcuts...")
        assignButton.title = Localization.string(.shortcutMapperAssignButton, default: "Assign...")
        clearButton.title = Localization.string(.shortcutMapperClear, default: "Clear")
    }

    private func updateButtonStates() {
        let row = tableView.selectedRow
        let hasSelection = row >= 0 && row < filteredEntries.count
        assignButton.isEnabled = hasSelection
        clearButton.isEnabled = hasSelection && row < filteredEntries.count && filteredEntries[row].isCustom
    }

    // MARK: - Category switching

    @objc private func categoryChanged(_ sender: NSSegmentedControl) {
        currentCategory = Category(rawValue: sender.selectedSegment) ?? .mainMenu
        buildEntries()
        filteredEntries = allEntries
        searchField.stringValue = ""
        tableView.reloadData()
        updateButtonStates()
        statusLabel.stringValue = ""
    }

    // MARK: - Configure content

    private func configureContent() {
        guard let root = window?.contentView else { return }

        categoryControl.segmentCount = 4
        categoryControl.setLabel("Main Menu", forSegment: 0)
        categoryControl.setLabel("Macros", forSegment: 1)
        categoryControl.setLabel("Run Commands", forSegment: 2)
        categoryControl.setLabel("Plugins", forSegment: 3)
        categoryControl.trackingMode = .selectOne
        categoryControl.selectedSegment = 0
        categoryControl.target = self
        categoryControl.action = #selector(categoryChanged(_:))

        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.sendsSearchStringImmediately = true

        let actionCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionCol.title = Localization.string(.shortcutMapperColAction, default: "Action")
        actionCol.width = 320
        let shortcutCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutCol.title = Localization.string(.shortcutMapperColShortcut, default: "Shortcut")
        shortcutCol.width = 160
        tableView.addTableColumn(actionCol)
        tableView.addTableColumn(shortcutCol)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 18
        tableView.allowsMultipleSelection = false
        tableView.doubleAction = #selector(assignShortcut(_:))
        tableView.target = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        assignButton.bezelStyle = .rounded
        assignButton.target = self
        assignButton.action = #selector(assignShortcut(_:))
        assignButton.isEnabled = false

        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearShortcut(_:))
        clearButton.isEnabled = false

        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        exportImportButton.pullsDown = true
        exportImportButton.bezelStyle = .rounded
        exportImportButton.addItem(withTitle: "⚙")
        exportImportButton.addItem(withTitle: "Export Shortcuts...")
        exportImportButton.addItem(withTitle: "Import Shortcuts...")
        exportImportButton.item(at: 0)?.title = "⚙"
        exportImportButton.item(withTitle: "Export Shortcuts...")?.target = self
        exportImportButton.item(withTitle: "Export Shortcuts...")?.action = #selector(exportShortcuts(_:))
        exportImportButton.item(withTitle: "Import Shortcuts...")?.target = self
        exportImportButton.item(withTitle: "Import Shortcuts...")?.action = #selector(importShortcuts(_:))

        for v in [categoryControl, searchField, scrollView, assignButton, clearButton, statusLabel, exportImportButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(v)
        }

        NSLayoutConstraint.activate([
            categoryControl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            categoryControl.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),

            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: categoryControl.bottomAnchor, constant: 8),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: assignButton.topAnchor, constant: -10),

            assignButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            assignButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            assignButton.widthAnchor.constraint(equalToConstant: 100),

            clearButton.leadingAnchor.constraint(equalTo: assignButton.trailingAnchor, constant: 8),
            clearButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            clearButton.widthAnchor.constraint(equalToConstant: 80),

            statusLabel.leadingAnchor.constraint(equalTo: clearButton.trailingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: exportImportButton.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: assignButton.centerYAnchor),

            exportImportButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            exportImportButton.centerYAnchor.constraint(equalTo: assignButton.centerYAnchor),
            exportImportButton.widthAnchor.constraint(equalToConstant: 44),
        ])
    }
}

// MARK: - Shortcut Recorder view

/// A custom view that captures the next key press as a shortcut.
@MainActor
final class ShortcutRecorderView: NSView {
    private(set) var keyEquivalent: String = ""
    private(set) var modifierFlags: NSEvent.ModifierFlags = []
    private let label = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        label.stringValue = Localization.string(.shortcutMapperRecorderHint, default: "Click, then press a key combo")
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return true
    }

    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        // Ignore modifier-only events
        let code = event.keyCode
        let modOnly: [UInt16] = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63] // cmd, shift, opt, ctrl variants
        guard !modOnly.contains(code), let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            return
        }
        var mods = event.modifierFlags.intersection([.command, .shift, .option, .control, .function])
        // Require at least one modifier for single-char keys (to avoid eating normal typing)
        if !mods.contains(.command) && !mods.contains(.control) && !mods.contains(.option) {
            mods.insert(.command)
        }
        keyEquivalent = chars.lowercased()
        modifierFlags = mods
        let display = CustomShortcut(menuItemTitle: "", keyEquivalent: keyEquivalent, modifierFlags: Int(bitPattern: UInt(mods.rawValue))).displayString
        label.stringValue = display
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        keyDown(with: event)
        return true
    }
}
