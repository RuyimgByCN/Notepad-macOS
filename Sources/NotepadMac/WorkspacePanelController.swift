import AppKit
import CoreServices
import NotepadMacCore

@MainActor
final class WorkspacePanelController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("WorkspaceColumn"))
    private let onOpenFile: (URL) -> Void
    var onFindInFiles: ((URL) -> Void)?

    private var workspace: WorkspaceDocument?
    /// URL the current workspace was loaded from / last saved to. Nil if never saved.
    private var currentWorkspaceURL: URL?
    private var watchedURL: URL?
    private var fsEventStream: FSEventStreamRef?
    private var reloadWorkspace: (() -> Void)?

    /// Root path used as the expand-state key (Folder as Workspace / watched folder / workspace file).
    private var expandStateRootPath: String?
    private let expandStateStore = WorkspaceExpandStateStore()
    /// Suppresses persist callbacks while programmatically restoring expand state.
    private var isRestoringExpandState = false

    init(onOpenFile: @escaping (URL) -> Void) {
        self.onOpenFile = onOpenFile

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// - Parameters:
    ///   - workspace: Tree to display.
    ///   - url: Optional workspace document URL (`.xml` project file).
    ///   - expandStateRoot: Optional root used for expand/collapse persistence
    ///     (Folder as Workspace directory). When nil, falls back to `url`, the
    ///     watched folder, or the first project URL.
    func show(workspace: WorkspaceDocument, url: URL? = nil, expandStateRoot: URL? = nil) {
        // Capture expand state of the previous tree before replacing it (same-root reloads).
        if let previousRoot = expandStateRootPath {
            persistExpandedPaths(forRoot: previousRoot)
        }

        self.workspace = workspace
        if url != nil {
            self.currentWorkspaceURL = url
        }

        let resolvedRoot = resolveExpandStateRoot(
            explicit: expandStateRoot,
            workspaceURL: url ?? currentWorkspaceURL,
            workspace: workspace
        )
        expandStateRootPath = resolvedRoot

        window?.title = url?.lastPathComponent ?? workspace.name
        outlineView.reloadData()
        restoreExpandStateOrExpandAll()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func startWatching(url: URL, reload: @escaping () -> Void) {
        stopFSEventStream()
        watchedURL = url
        if expandStateRootPath == nil {
            expandStateRootPath = url.standardizedFileURL.path
        }
        reloadWorkspace = reload

        let path = url.path as CFString
        let paths = [path] as CFArray
        let context = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        var ctx = FSEventStreamContext(version: 0, info: context, retain: nil, release: { ptr in
            if let ptr { Unmanaged<WorkspacePanelController>.fromOpaque(ptr).release() }
        }, copyDescription: nil)

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let controller = Unmanaged<WorkspacePanelController>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { @MainActor [weak controller] in
                controller?.handleFSEvent()
            }
        }

        fsEventStream = FSEventStreamCreate(nil, callback, &ctx, paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, flags)
        if let stream = fsEventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    private func stopFSEventStream() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
        }
    }

    private func handleFSEvent() {
        guard let reload = reloadWorkspace else { return }
        reload()
    }

    func locateFile(_ url: URL) {
        guard workspace != nil else { return }
        // Walk the tree to find and select the matching file node
        func search(in items: [WorkspaceNode]) -> Bool {
            for node in items {
                if node.url == url {
                    outlineView.expandItem(node)
                    let row = outlineView.row(forItem: node)
                    if row >= 0 {
                        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                        outlineView.scrollRowToVisible(row)
                    }
                    return true
                }
                if search(in: node.children) { return true }
            }
            return false
        }
        _ = search(in: workspace?.projects ?? [])
    }

    func clear() {
        if let root = expandStateRootPath {
            persistExpandedPaths(forRoot: root)
        }
        stopFSEventStream()
        workspace = nil
        expandStateRootPath = nil
        outlineView.reloadData()
        refreshLocalizedStrings()
        close()
    }

    // MARK: - Expand / collapse persistence (upstream FaW 8.9.7)

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !isRestoringExpandState else { return }
        persistCurrentExpandState()
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isRestoringExpandState else { return }
        persistCurrentExpandState()
    }

    private func resolveExpandStateRoot(
        explicit: URL?,
        workspaceURL: URL?,
        workspace: WorkspaceDocument
    ) -> String? {
        if let explicit {
            return explicit.standardizedFileURL.path
        }
        if let watchedURL {
            return watchedURL.standardizedFileURL.path
        }
        if let workspaceURL {
            return workspaceURL.standardizedFileURL.path
        }
        if let projectURL = workspace.projects.first?.url {
            return projectURL.standardizedFileURL.path
        }
        return nil
    }

    private func restoreExpandStateOrExpandAll() {
        guard let root = expandStateRootPath else {
            expandAll()
            return
        }
        let saved = expandStateStore.expandedPaths(forRoot: root)
        if saved.isEmpty {
            expandAll()
            persistCurrentExpandState()
            return
        }
        applyExpandedPaths(saved)
    }

    private func applyExpandedPaths(_ paths: Set<String>) {
        isRestoringExpandState = true
        defer { isRestoringExpandState = false }

        func visit(_ nodes: [WorkspaceNode]) {
            for node in nodes {
                if let key = expandKey(for: node), paths.contains(key) {
                    outlineView.expandItem(node)
                }
                if !node.children.isEmpty {
                    visit(node.children)
                }
            }
        }
        visit(workspace?.projects ?? [])
    }

    private func persistCurrentExpandState() {
        guard let root = expandStateRootPath else { return }
        persistExpandedPaths(forRoot: root)
    }

    private func persistExpandedPaths(forRoot root: String) {
        var paths = Set<String>()
        collectExpandedPaths(from: workspace?.projects ?? [], into: &paths)
        // Always record the root itself when anything is expanded, so reopening
        // can distinguish "never saved" from "user collapsed everything".
        if !paths.isEmpty {
            paths.insert(root)
        }
        expandStateStore.setExpandedPaths(paths, forRoot: root)
    }

    private func collectExpandedPaths(from nodes: [WorkspaceNode], into paths: inout Set<String>) {
        for node in nodes {
            if outlineView.isItemExpanded(node), let key = expandKey(for: node) {
                paths.insert(key)
            }
            if !node.children.isEmpty {
                collectExpandedPaths(from: node.children, into: &paths)
            }
        }
    }

    private func expandKey(for node: WorkspaceNode) -> String? {
        if let url = node.url {
            return url.standardizedFileURL.path
        }
        // Project nodes without a URL (classic workspace XML): use name under root.
        if node.kind == .project, let root = expandStateRootPath {
            return root + "#project:" + node.name
        }
        return nil
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        node(from: item)?.children.count ?? workspace?.projects.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = node(from: item) {
            return node.children[index]
        }
        return workspace?.projects[index] ?? WorkspaceNode(
            name: Localization.string(.workspaceFallbackName),
            kind: .project
        )
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        node(from: item)?.children.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = node(from: item) else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("WorkspaceCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: identifier)
        cell.textField?.stringValue = node.name
        cell.imageView?.image = image(for: node)
        return cell
    }

    @objc private func openSelectedItem(_ sender: Any?) {
        guard
            let item = outlineView.item(atRow: outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow),
            let node = node(from: item),
            node.kind == .file,
            let url = node.url
        else {
            return
        }

        onOpenFile(url)
    }

    private func contextMenuNode() -> WorkspaceNode? {
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) else { return nil }
        return node(from: item)
    }

    @objc private func revealInFinder(_ sender: Any?) {
        guard let url = contextMenuNode()?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func openInTerminal(_ sender: Any?) {
        guard let node = contextMenuNode(), let url = node.url else { return }
        let dirURL = node.kind == .file ? url.deletingLastPathComponent() : url
        let term = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
        if let term {
            NSWorkspace.shared.open([dirURL], withApplicationAt: term, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    @objc private func openWithDefaultApp(_ sender: Any?) {
        guard let url = contextMenuNode()?.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func copyPath(_ sender: Any?) {
        guard let url = contextMenuNode()?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    @objc private func copyFilename(_ sender: Any?) {
        guard let url = contextMenuNode()?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        // Toolbar row: New | Open | Save | Save As | — | Add Files | Add Folder
        let toolbarView = NSView()
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarView)

        func makeToolbarButton(image: String, tip: String, selector: Selector) -> NSButton {
            let b = NSButton()
            b.translatesAutoresizingMaskIntoConstraints = false
            b.bezelStyle = .inline
            b.isBordered = false
            b.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
            b.toolTip = tip
            b.target = self
            b.action = selector
            b.setAccessibilityLabel(tip)
            return b
        }

        let btnNew       = makeToolbarButton(image: "doc.badge.plus",    tip: "New Workspace",          selector: #selector(newWorkspace(_:)))
        let btnOpen      = makeToolbarButton(image: "folder",            tip: "Open Workspace...",      selector: #selector(openWorkspace(_:)))
        let btnReload    = makeToolbarButton(image: "arrow.clockwise",   tip: "Reload Workspace",       selector: #selector(reloadWorkspaceFromDisk(_:)))
        let btnSave      = makeToolbarButton(image: "square.and.arrow.down", tip: "Save Workspace",     selector: #selector(saveWorkspace(_:)))
        let btnSaveAs    = makeToolbarButton(image: "square.and.arrow.down.on.square", tip: "Save Workspace As...", selector: #selector(saveWorkspaceAs(_:)))
        let btnSaveCopy  = makeToolbarButton(image: "doc.on.doc",        tip: "Save Copy As...",        selector: #selector(saveCopyAs(_:)))
        let btnAddProject = makeToolbarButton(image: "shippingbox.fill", tip: "Add Project...",         selector: #selector(addProject(_:)))
        let btnAddFiles  = makeToolbarButton(image: "doc.badge.plus",    tip: "Add Files...",           selector: #selector(addFilesFromToolbar(_:)))
        let btnAddFolder = makeToolbarButton(image: "folder.badge.plus", tip: "Add Folder...",          selector: #selector(addFolderFromToolbar(_:)))

        for btn in [btnNew, btnOpen, btnReload, btnSave, btnSaveAs, btnSaveCopy, btnAddProject, btnAddFiles, btnAddFolder] {
            toolbarView.addSubview(btn)
        }

        let btnW: CGFloat = 26
        let spacing: CGFloat = 2
        NSLayoutConstraint.activate([
            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 28),

            btnNew.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 4),
            btnNew.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnNew.widthAnchor.constraint(equalToConstant: btnW),
            btnNew.heightAnchor.constraint(equalToConstant: btnW),

            btnOpen.leadingAnchor.constraint(equalTo: btnNew.trailingAnchor, constant: spacing),
            btnOpen.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnOpen.widthAnchor.constraint(equalToConstant: btnW),
            btnOpen.heightAnchor.constraint(equalToConstant: btnW),

            btnReload.leadingAnchor.constraint(equalTo: btnOpen.trailingAnchor, constant: spacing),
            btnReload.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnReload.widthAnchor.constraint(equalToConstant: btnW),
            btnReload.heightAnchor.constraint(equalToConstant: btnW),

            btnSave.leadingAnchor.constraint(equalTo: btnReload.trailingAnchor, constant: spacing),
            btnSave.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnSave.widthAnchor.constraint(equalToConstant: btnW),
            btnSave.heightAnchor.constraint(equalToConstant: btnW),

            btnSaveAs.leadingAnchor.constraint(equalTo: btnSave.trailingAnchor, constant: spacing),
            btnSaveAs.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnSaveAs.widthAnchor.constraint(equalToConstant: btnW),
            btnSaveAs.heightAnchor.constraint(equalToConstant: btnW),

            btnSaveCopy.leadingAnchor.constraint(equalTo: btnSaveAs.trailingAnchor, constant: spacing),
            btnSaveCopy.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnSaveCopy.widthAnchor.constraint(equalToConstant: btnW),
            btnSaveCopy.heightAnchor.constraint(equalToConstant: btnW),

            btnAddProject.leadingAnchor.constraint(equalTo: btnSaveCopy.trailingAnchor, constant: 8),
            btnAddProject.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnAddProject.widthAnchor.constraint(equalToConstant: btnW),
            btnAddProject.heightAnchor.constraint(equalToConstant: btnW),

            btnAddFiles.leadingAnchor.constraint(equalTo: btnAddProject.trailingAnchor, constant: spacing),
            btnAddFiles.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnAddFiles.widthAnchor.constraint(equalToConstant: btnW),
            btnAddFiles.heightAnchor.constraint(equalToConstant: btnW),

            btnAddFolder.leadingAnchor.constraint(equalTo: btnAddFiles.trailingAnchor, constant: spacing),
            btnAddFolder.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),
            btnAddFolder.widthAnchor.constraint(equalToConstant: btnW),
            btnAddFolder.heightAnchor.constraint(equalToConstant: btnW),
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder

        column.title = Localization.string(.workspaceColumnTitle)
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .medium
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.doubleAction = #selector(openSelectedItem(_:))
        outlineView.target = self
        outlineView.setAccessibilityLabel(Localization.string(.workspaceOutlineAccessibilityLabel))
        outlineView.menu = buildContextMenu()

        scrollView.documentView = outlineView
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Workspace file operations

    @objc private func newWorkspace(_ sender: Any?) {
        workspace = WorkspaceDocument(name: "Workspace", projects: [
            WorkspaceNode(name: "Project A", kind: .project)
        ])
        currentWorkspaceURL = nil
        window?.title = Localization.string(.workspacePanelTitle)
        outlineView.reloadData()
        expandAll()
    }

    @objc private func openWorkspace(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.title = Localization.string(.workspaceOpenPanelTitle, default: "Open Workspace")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let doc = try WorkspaceDocument.load(from: url)
            show(workspace: doc, url: url)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func saveWorkspace(_ sender: Any?) {
        if let url = currentWorkspaceURL {
            saveToURL(url)
        } else {
            saveWorkspaceAs(sender)
        }
    }

    @objc private func saveWorkspaceAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = (workspace?.name ?? "Workspace") + ".xml"
        panel.title = Localization.string(.workspaceSavePanelTitle, default: "Save Workspace")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        currentWorkspaceURL = url
        window?.title = url.lastPathComponent
        saveToURL(url)
    }

    @objc private func saveCopyAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = (workspace?.name ?? "Workspace") + " Copy.xml"
        panel.title = Localization.string(.workspaceSaveCopyPanelTitle, default: "Save Copy of Workspace As...")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveToURL(url)
        // currentWorkspaceURL stays unchanged (it's a copy)
    }

    @objc private func reloadWorkspaceFromDisk(_ sender: Any?) {
        guard let url = currentWorkspaceURL else { return }
        do {
            let doc = try WorkspaceDocument.load(from: url)
            show(workspace: doc, url: url)
        } catch {
            NSApp.presentError(error)
        }
    }

    private func saveToURL(_ url: URL) {
        guard let workspace else { return }
        do {
            try workspace.write(to: url)
        } catch {
            NSApp.presentError(error)
        }
    }

    // MARK: - Add files / folders

    private func targetProjectIndex(for node: WorkspaceNode?) -> Int {
        guard let workspace else { return 0 }
        guard let node else { return 0 }
        if node.kind == .project {
            return workspace.projects.firstIndex(of: node) ?? 0
        }
        // For non-project nodes, find the project that contains them (use first project as fallback)
        for (i, project) in workspace.projects.enumerated() {
            if nodeIsDescendant(node, of: project) { return i }
        }
        return 0
    }

    private func nodeIsDescendant(_ target: WorkspaceNode, of ancestor: WorkspaceNode) -> Bool {
        ancestor.children.contains(target) ||
        ancestor.children.contains { nodeIsDescendant(target, of: $0) }
    }

    private func addFiles(toProjectAt projectIndex: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = Localization.string(.workspaceAddFilesPanelTitle, default: "Add Files to Workspace")
        guard panel.runModal() == .OK else { return }
        workspace = workspace?.addingFiles(panel.urls, toProjectAt: projectIndex)
        outlineView.reloadData()
        expandAll()
    }

    private func addFolder(toProjectAt projectIndex: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = Localization.string(.workspaceAddFolderPanelTitle, default: "Add Folder to Workspace")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        workspace = workspace?.addingFolder(url, recursive: true, toProjectAt: projectIndex)
        outlineView.reloadData()
        expandAll()
    }

    @objc private func addProject(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = Localization.string(.workspaceNewProjectTitle, default: "New Project")
        alert.informativeText = Localization.string(.workspaceNewProjectMessage, default: "Enter a name for the new project:")
        alert.alertStyle = .informational
        alert.addButton(withTitle: Localization.string(.workspaceNewProjectAdd, default: "Add"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        let field = NSTextField(string: Localization.string(.workspaceNewProjectDefaultName, default: "New Project"))
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 22)
        alert.accessoryView = field
        guard let window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let name = field.stringValue.isEmpty ? Localization.string(.workspaceNewProjectDefaultName, default: "New Project") : field.stringValue
            let node = WorkspaceNode(name: name, kind: .project)
            self.workspace = self.workspace?.addingProject(node)
            self.outlineView.reloadData()
        }
    }

    @objc private func addFilesFromToolbar(_ sender: Any?) {
        addFiles(toProjectAt: 0)
    }

    @objc private func addFolderFromToolbar(_ sender: Any?) {
        addFolder(toProjectAt: 0)
    }

    @objc private func addFilesHere(_ sender: Any?) {
        let idx = targetProjectIndex(for: contextMenuNode())
        addFiles(toProjectAt: idx)
    }

    @objc private func addFolderHere(_ sender: Any?) {
        let idx = targetProjectIndex(for: contextMenuNode())
        addFolder(toProjectAt: idx)
    }

    @objc private func removeNode(_ sender: Any?) {
        guard let node = contextMenuNode() else { return }
        workspace = workspace?.removingNode(node)
        outlineView.reloadData()
    }

    @objc private func renameNode(_ sender: Any?) {
        guard let node = contextMenuNode() else { return }
        let alert = NSAlert()
        alert.messageText = Localization.string(.workspaceRenameTitle, default: "Rename")
        alert.informativeText = String(format: Localization.string(.workspaceRenameMessage, default: "Enter new name for \"%@\":"), node.name)
        alert.alertStyle = .informational
        alert.addButton(withTitle: Localization.string(.workspaceRenameConfirm, default: "Rename"))
        alert.addButton(withTitle: Localization.string(.alertCancel, default: "Cancel"))
        let field = NSTextField(string: node.name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 22)
        alert.accessoryView = field
        guard let window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            self.workspace = self.workspace?.renamingNode(node, to: field.stringValue)
            self.outlineView.reloadData()
        }
    }

    @objc private func moveNodeUp(_ sender: Any?) {
        guard let node = contextMenuNode() else { return }
        workspace = workspace?.movingNodeUp(node)
        outlineView.reloadData()
    }

    @objc private func moveNodeDown(_ sender: Any?) {
        guard let node = contextMenuNode() else { return }
        workspace = workspace?.movingNodeDown(node)
        outlineView.reloadData()
    }

    private func refreshLocalizedStrings() {
        if workspace == nil {
            window?.title = Localization.string(.workspacePanelTitle)
        }
        column.title = Localization.string(.workspaceColumnTitle)
        outlineView.setAccessibilityLabel(Localization.string(.workspaceOutlineAccessibilityLabel))
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let imageView = NSImageView()
        let textField = NSTextField(labelWithString: "")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingMiddle

        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func expandAll() {
        isRestoringExpandState = true
        defer { isRestoringExpandState = false }
        for project in workspace?.projects ?? [] {
            outlineView.expandItem(project, expandChildren: true)
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Edit operations
        menu.addItem(withTitle: Localization.string(.workspaceMenuAddProject, default: "Add Project..."), action: #selector(addProject(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceMenuAddFiles, default: "Add Files..."), action: #selector(addFilesHere(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceMenuAddFolder, default: "Add Folder..."), action: #selector(addFolderHere(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceMenuRename, default: "Rename..."), action: #selector(renameNode(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceMenuRemove, default: "Remove from Workspace"), action: #selector(removeNode(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceMenuMoveUp, default: "Move Up"), action: #selector(moveNodeUp(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceMenuMoveDown, default: "Move Down"), action: #selector(moveNodeDown(_:)), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: Localization.string(.workspaceContextRevealInFinder, default: "Reveal in Finder"),
                     action: #selector(revealInFinder(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceContextOpenInTerminal, default: "Open in Terminal"),
                     action: #selector(openInTerminal(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceContextOpenWithDefaultApp, default: "Open with Default Application"),
                     action: #selector(openWithDefaultApp(_:)), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        let findItem = menu.addItem(
            withTitle: Localization.string(.workspaceContextFindInFiles, default: "Find in Files Here..."),
            action: #selector(findInFilesHere(_:)), keyEquivalent: "")
        findItem.target = self
        findItem.isHidden = onFindInFiles == nil
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: Localization.string(.workspaceContextCopyPath, default: "Copy Full Path"),
                     action: #selector(copyPath(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localization.string(.workspaceContextCopyFilename, default: "Copy Filename"),
                     action: #selector(copyFilename(_:)), keyEquivalent: "").target = self
        return menu
    }

    @objc private func findInFilesHere(_ sender: Any?) {
        guard let node = contextMenuNode(), let url = node.url else { return }
        let dirURL = node.kind == .file ? url.deletingLastPathComponent() : url
        onFindInFiles?(dirURL)
    }

    private func node(from item: Any?) -> WorkspaceNode? {
        item as? WorkspaceNode
    }

    private func image(for node: WorkspaceNode) -> NSImage? {
        switch node.kind {
        case .project:
            NSImage(
                systemSymbolName: "shippingbox",
                accessibilityDescription: Localization.string(.workspaceProjectIconAccessibilityDescription)
            )
        case .folder:
            NSImage(
                systemSymbolName: "folder",
                accessibilityDescription: Localization.string(.workspaceFolderIconAccessibilityDescription)
            )
        case .file:
            NSImage(
                systemSymbolName: "doc.text",
                accessibilityDescription: Localization.string(.workspaceFileIconAccessibilityDescription)
            )
        }
    }
}
