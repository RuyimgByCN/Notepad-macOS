import AppKit
import NotepadMacCore

/// Handles install requests raised from the available-plugins list.
@MainActor
protocol AvailablePluginsViewControllerDelegate: AnyObject {
    func availablePluginsViewController(
        _ controller: AvailablePluginsViewController,
        didRequestInstall entry: PluginRepositoryEntry
    )
}

/// Mirrors the upstream Notepad++ PluginsAdmin "Available" tab: a searchable
/// list (Name / Version / Author / Description) with a read-only detail pane
/// and an Install button. Self-contained so the host panel keeps focusing on
/// installed-plugin/command management rather than growing further.
@MainActor
final class AvailablePluginsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    weak var delegate: AvailablePluginsViewControllerDelegate?

    private var entries: [PluginRepositoryEntry] = []
    private var filteredEntries: [PluginRepositoryEntry] = []

    private let searchField = NSSearchField()
    private let installButton = NSButton(
        title: Localization.string(.pluginsInstallSelected, default: "Install"),
        target: nil,
        action: nil
    )
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let detailScrollView = NSScrollView()
    private let detailView = NSTextView()
    private let emptyLabel = NSTextField(labelWithString: "")

    private let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    private let versionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
    private let authorColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("author"))
    private let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))

    override func loadView() {
        let container = NSView()

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = Localization.string(
            .pluginsAvailableSearchPlaceholder,
            default: "Search plugins"
        )
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true

        installButton.translatesAutoresizingMaskIntoConstraints = false
        installButton.bezelStyle = .rounded
        installButton.target = self
        installButton.action = #selector(installSelected(_:))
        installButton.isEnabled = false

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(installSelected(_:))
        configureColumns()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView

        detailView.isEditable = false
        detailView.isSelectable = true
        detailView.isRichText = false
        detailView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        detailView.textContainerInset = NSSize(width: 8, height: 8)
        detailView.string = Localization.string(
            .pluginsAvailableNoSelection,
            default: "Select a plugin to see its description."
        )

        detailScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.hasVerticalScroller = true
        detailScrollView.borderType = .bezelBorder
        detailScrollView.documentView = detailView

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.stringValue = Localization.string(
            .pluginsAvailableEmpty,
            default: "No plugins. Click Fetch Available to load the catalog."
        )
        emptyLabel.isHidden = true

        container.addSubview(searchField)
        container.addSubview(installButton)
        container.addSubview(scrollView)
        container.addSubview(detailScrollView)
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            searchField.topAnchor.constraint(equalTo: container.topAnchor),
            searchField.trailingAnchor.constraint(equalTo: installButton.leadingAnchor, constant: -8),

            installButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            installButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: detailScrollView.topAnchor, constant: -8),

            detailScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            detailScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            detailScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            // Fixed height so the description pane does not expand (via the
            // NSTextView's intrinsic content size) and starve the plugin list
            // scrollView, whose NSTableView has no intrinsic content size and
            // would otherwise collapse to zero height.
            detailScrollView.heightAnchor.constraint(equalToConstant: 96),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])

        view = container
    }

    private func configureColumns() {
        nameColumn.title = Localization.string(.pluginsColumnPlugin, default: "Name")
        versionColumn.title = Localization.string(.pluginsColumnVersion, default: "Version")
        authorColumn.title = Localization.string(.pluginsAvailableColumnAuthor, default: "Author")
        descriptionColumn.title = Localization.string(.pluginsAvailableColumnDescription, default: "Description")
        nameColumn.width = 180
        versionColumn.width = 80
        authorColumn.width = 130
        descriptionColumn.width = 260
        for column in [nameColumn, versionColumn, authorColumn, descriptionColumn] where tableView.tableColumns.contains(column) == false {
            tableView.addTableColumn(column)
        }
    }

    // MARK: - Public

    func update(entries: [PluginRepositoryEntry]) {
        self.entries = entries
        applyFilter()
    }

    func removeInstalled(identifier: String) {
        entries.removeAll { $0.identifier == identifier }
        applyFilter()
    }

    func refreshLocalization() {
        nameColumn.title = Localization.string(.pluginsColumnPlugin, default: "Name")
        versionColumn.title = Localization.string(.pluginsColumnVersion, default: "Version")
        authorColumn.title = Localization.string(.pluginsAvailableColumnAuthor, default: "Author")
        descriptionColumn.title = Localization.string(.pluginsAvailableColumnDescription, default: "Description")
        installButton.title = Localization.string(.pluginsInstallSelected, default: "Install")
        searchField.placeholderString = Localization.string(
            .pluginsAvailableSearchPlaceholder,
            default: "Search plugins"
        )
        emptyLabel.stringValue = Localization.string(
            .pluginsAvailableEmpty,
            default: "No plugins. Click Fetch Available to load the catalog."
        )
        if selectedEntry() == nil {
            detailView.string = Localization.string(
                .pluginsAvailableNoSelection,
                default: "Select a plugin to see its description."
            )
        }
    }

    // MARK: - Private

    private func applyFilter() {
        let query = searchField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        filteredEntries = query.isEmpty
            ? entries
            : entries.filter { matches($0, query: query) }
        tableView.reloadData()
        emptyLabel.isHidden = !filteredEntries.isEmpty
        renderDetail(for: selectedEntry())
        updateInstallEnabled()
    }

    private func matches(_ entry: PluginRepositoryEntry, query: String) -> Bool {
        if entry.name.lowercased().contains(query) { return true }
        if entry.identifier.lowercased().contains(query) { return true }
        if (entry.author ?? "").lowercased().contains(query) { return true }
        if (entry.description ?? "").lowercased().contains(query) { return true }
        return false
    }

    private func selectedEntry() -> PluginRepositoryEntry? {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredEntries.count else { return nil }
        return filteredEntries[row]
    }

    private func updateInstallEnabled() {
        installButton.isEnabled = selectedEntry() != nil
    }

    private func renderDetail(for entry: PluginRepositoryEntry?) {
        guard let entry else {
            detailView.string = Localization.string(
                .pluginsAvailableNoSelection,
                default: "Select a plugin to see its description."
            )
            return
        }
        var lines: [String] = [entry.name]
        if let version = entry.version, !version.isEmpty {
            lines.append("Version: \(version)")
        }
        if let author = entry.author, !author.isEmpty {
            lines.append("Author: \(author)")
        }
        if let homepage = entry.homepage, !homepage.isEmpty {
            lines.append("Homepage: \(homepage)")
        }
        if let description = entry.description, !description.isEmpty {
            lines.append("")
            lines.append(description)
        }
        detailView.string = lines.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func searchChanged(_ sender: Any?) {
        applyFilter()
    }

    @objc private func installSelected(_ sender: Any?) {
        guard let entry = selectedEntry() else { return }
        delegate?.availablePluginsViewController(self, didRequestInstall: entry)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredEntries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0, row < filteredEntries.count else { return nil }
        let entry = filteredEntries[row]
        switch tableColumn?.identifier.rawValue {
        case "name": return entry.name
        case "version": return entry.version ?? ""
        case "author": return entry.author ?? ""
        case "description": return entry.description ?? ""
        default: return ""
        }
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateInstallEnabled()
        renderDetail(for: selectedEntry())
    }
}
