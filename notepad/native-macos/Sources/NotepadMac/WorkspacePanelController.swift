import AppKit
import NotepadMacCore

@MainActor
final class WorkspacePanelController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let onOpenFile: (URL) -> Void

    private var workspace: WorkspaceDocument?

    init(onOpenFile: @escaping (URL) -> Void) {
        self.onOpenFile = onOpenFile

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = Localization.string(.workspacePanelTitle)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        configureContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(workspace: WorkspaceDocument) {
        self.workspace = workspace
        window?.title = workspace.name
        outlineView.reloadData()
        expandAll()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func clear() {
        workspace = nil
        outlineView.reloadData()
        close()
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

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("WorkspaceColumn"))
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

        scrollView.documentView = outlineView
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
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
        for project in workspace?.projects ?? [] {
            outlineView.expandItem(project, expandChildren: true)
        }
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
