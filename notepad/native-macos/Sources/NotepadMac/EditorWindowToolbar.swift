import AppKit

@MainActor
final class EditorWindowToolbar: NSObject, NSToolbarDelegate {
    private enum CommandTarget: Equatable {
        case controller
        case appDelegate
        case responderChain

        @MainActor
        func resolve(using controller: EditorWindowController?) -> AnyObject? {
            switch self {
            case .controller:
                return controller
            case .appDelegate:
                return NSApp.delegate as AnyObject?
            case .responderChain:
                return nil
            }
        }
    }

    private struct Command {
        let identifier: NSToolbarItem.Identifier
        let label: String
        let paletteLabel: String
        let toolTip: String
        let symbolName: String
        let action: Selector
        let target: CommandTarget
    }

    private weak var controller: EditorWindowController?
    private let includesFoldingCommands: Bool

    init(controller: EditorWindowController) {
        self.controller = controller
        self.includesFoldingCommands = controller.supportsToolbarFoldingCommands
        super.init()
    }

    func makeToolbar(sizeStyle: Int = 0) -> NSToolbar {
        let toolbar = NSToolbar(identifier: .editorWindow)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = sizeStyle == 1 ? .small : .regular
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = false
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.defaultItemIdentifiers(includesFoldingCommands: includesFoldingCommands)
    }

    static func upstreamDefaultItemIdentifierRawValues(includesFoldingCommands: Bool) -> [String] {
        defaultItemIdentifiers(includesFoldingCommands: includesFoldingCommands).map(\.rawValue)
    }

    private static func defaultItemIdentifiers(includesFoldingCommands: Bool) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = [
            .editorNew,
            .editorOpen,
            .editorSave,
            .editorSaveAll,
            .editorClose,
            .editorCloseAll,
            .space,
            .editorPrint,
            .space,
            .editorCut,
            .editorCopy,
            .editorPaste,
            .space,
            .editorUndo,
            .editorRedo,
            .space,
            .editorFind,
            .editorReplace,
            .space,
            .editorToggleBookmark,
            .editorPreviousBookmark,
            .editorNextBookmark,
            .space,
            .editorToggleLineWrap,
            .editorFunctionList
        ]

        if includesFoldingCommands {
            identifiers.append(contentsOf: [
                .space,
                .editorToggleFold,
                .editorFoldAll,
                .editorUnfoldAll
            ])
        }

        return identifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var identifiers = toolbarDefaultItemIdentifiers(toolbar)
        identifiers.append(.flexibleSpace)
        return identifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let command = Self.command(for: itemIdentifier) else {
            return nil
        }
        let target = command.target.resolve(using: controller)
        if command.target == .controller, target == nil {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = command.label
        item.paletteLabel = command.paletteLabel
        item.toolTip = command.toolTip
        item.image = NSImage(systemSymbolName: command.symbolName, accessibilityDescription: command.label)
        item.target = target
        item.action = command.action

        let menuItem = NSMenuItem(title: command.paletteLabel, action: command.action, keyEquivalent: "")
        menuItem.target = target
        item.menuFormRepresentation = menuItem

        return item
    }

    static func validate(toolbarItem: NSToolbarItem, using controller: EditorWindowController) -> Bool {
        guard let action = toolbarItem.action else {
            return true
        }

        let validationItem = NSMenuItem(title: toolbarItem.label, action: action, keyEquivalent: "")
        let isEnabled: Bool
        if toolbarItem.target == nil {
            isEnabled = NSApp.target(forAction: action, to: nil, from: toolbarItem) != nil
        } else if let appDelegate = toolbarItem.target as? AppDelegate {
            isEnabled = appDelegate.validateMenuItem(validationItem)
        } else {
            isEnabled = controller.validateMenuItem(validationItem)
        }
        toolbarItem.menuFormRepresentation?.state = validationItem.state
        toolbarItem.menuFormRepresentation?.isEnabled = isEnabled
        return isEnabled
    }

    private static func command(for identifier: NSToolbarItem.Identifier) -> Command? {
        commands.first { $0.identifier == identifier }
    }

    private static let commands: [Command] = [
        Command(
            identifier: .editorNew,
            label: Localization.string(.fileNew, default: "New"),
            paletteLabel: Localization.string(.fileNew, default: "New"),
            toolTip: Localization.string(.fileNew, default: "New"),
            symbolName: "doc.badge.plus",
            action: #selector(AppDelegate.newDocument(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorOpen,
            label: Localization.string(.fileOpen, default: "Open..."),
            paletteLabel: Localization.string(.fileOpen, default: "Open..."),
            toolTip: Localization.string(.fileOpen, default: "Open..."),
            symbolName: "folder",
            action: #selector(AppDelegate.openDocument(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorSave,
            label: Localization.string(.toolbarSaveLabel, default: "Save"),
            paletteLabel: Localization.string(.toolbarSaveLabel, default: "Save"),
            toolTip: Localization.string(.toolbarSaveTooltip, default: "Save the current document"),
            symbolName: "square.and.arrow.down",
            action: #selector(EditorWindowController.saveDocument(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorSaveAll,
            label: Localization.string(.fileSaveAll, default: "Save All"),
            paletteLabel: Localization.string(.fileSaveAll, default: "Save All"),
            toolTip: Localization.string(.fileSaveAll, default: "Save All"),
            symbolName: "square.and.arrow.down.on.square",
            action: #selector(AppDelegate.saveAllDocuments(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorClose,
            label: Localization.string(.fileClose, default: "Close"),
            paletteLabel: Localization.string(.fileClose, default: "Close"),
            toolTip: Localization.string(.fileClose, default: "Close"),
            symbolName: "xmark",
            action: #selector(NSWindow.performClose(_:)),
            target: .responderChain
        ),
        Command(
            identifier: .editorCloseAll,
            label: Localization.string(.fileCloseAll, default: "Close All"),
            paletteLabel: Localization.string(.fileCloseAll, default: "Close All"),
            toolTip: Localization.string(.fileCloseAll, default: "Close All"),
            symbolName: "xmark.rectangle",
            action: #selector(AppDelegate.closeAllDocuments(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorPrint,
            label: Localization.string(.toolbarPrintLabel, default: "Print"),
            paletteLabel: Localization.string(.toolbarPrintLabel, default: "Print"),
            toolTip: Localization.string(.toolbarPrintTooltip, default: "Print the current document"),
            symbolName: "printer",
            action: #selector(EditorWindowController.printDocument(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorCut,
            label: Localization.string(.editCut, default: "Cut"),
            paletteLabel: Localization.string(.editCut, default: "Cut"),
            toolTip: Localization.string(.editCut, default: "Cut"),
            symbolName: "scissors",
            action: #selector(NSText.cut(_:)),
            target: .responderChain
        ),
        Command(
            identifier: .editorCopy,
            label: Localization.string(.editCopy, default: "Copy"),
            paletteLabel: Localization.string(.editCopy, default: "Copy"),
            toolTip: Localization.string(.editCopy, default: "Copy"),
            symbolName: "doc.on.doc",
            action: #selector(NSText.copy(_:)),
            target: .responderChain
        ),
        Command(
            identifier: .editorPaste,
            label: Localization.string(.editPaste, default: "Paste"),
            paletteLabel: Localization.string(.editPaste, default: "Paste"),
            toolTip: Localization.string(.editPaste, default: "Paste"),
            symbolName: "clipboard",
            action: #selector(NSText.paste(_:)),
            target: .responderChain
        ),
        Command(
            identifier: .editorUndo,
            label: Localization.string(.editUndo, default: "Undo"),
            paletteLabel: Localization.string(.editUndo, default: "Undo"),
            toolTip: Localization.string(.editUndo, default: "Undo"),
            symbolName: "arrow.uturn.backward",
            action: Selector(("undo:")),
            target: .responderChain
        ),
        Command(
            identifier: .editorRedo,
            label: Localization.string(.editRedo, default: "Redo"),
            paletteLabel: Localization.string(.editRedo, default: "Redo"),
            toolTip: Localization.string(.editRedo, default: "Redo"),
            symbolName: "arrow.uturn.forward",
            action: Selector(("redo:")),
            target: .responderChain
        ),
        Command(
            identifier: .editorFind,
            label: Localization.string(.toolbarFindLabel, default: "Find"),
            paletteLabel: Localization.string(.toolbarFindLabel, default: "Find"),
            toolTip: Localization.string(.toolbarFindTooltip, default: "Show the Find panel"),
            symbolName: "magnifyingglass",
            action: #selector(EditorWindowController.showFindPanel(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorReplace,
            label: Localization.string(.toolbarReplaceLabel, default: "Replace"),
            paletteLabel: Localization.string(.toolbarReplaceLabel, default: "Replace"),
            toolTip: Localization.string(.toolbarReplaceTooltip, default: "Show the Replace panel"),
            symbolName: "arrow.triangle.2.circlepath",
            action: #selector(EditorWindowController.showReplacePanel(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorToggleBookmark,
            label: Localization.string(.toolbarToggleBookmarkLabel, default: "Bookmark"),
            paletteLabel: Localization.string(.toolbarToggleBookmarkPalette, default: "Toggle Bookmark"),
            toolTip: Localization.string(.toolbarToggleBookmarkTooltip, default: "Toggle a bookmark on the current line"),
            symbolName: "bookmark",
            action: #selector(EditorWindowController.toggleBookmark(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorPreviousBookmark,
            label: Localization.string(.toolbarPreviousBookmarkLabel, default: "Prev Mark"),
            paletteLabel: Localization.string(.toolbarPreviousBookmarkPalette, default: "Previous Bookmark"),
            toolTip: Localization.string(.toolbarPreviousBookmarkTooltip, default: "Go to the previous bookmark"),
            symbolName: "bookmark.fill",
            action: #selector(EditorWindowController.previousBookmark(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorNextBookmark,
            label: Localization.string(.toolbarNextBookmarkLabel, default: "Next Mark"),
            paletteLabel: Localization.string(.toolbarNextBookmarkPalette, default: "Next Bookmark"),
            toolTip: Localization.string(.toolbarNextBookmarkTooltip, default: "Go to the next bookmark"),
            symbolName: "bookmark.fill",
            action: #selector(EditorWindowController.nextBookmark(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorToggleLineWrap,
            label: Localization.string(.toolbarToggleLineWrapLabel, default: "Wrap"),
            paletteLabel: Localization.string(.toolbarToggleLineWrapPalette, default: "Toggle Line Wrap"),
            toolTip: Localization.string(.toolbarToggleLineWrapTooltip, default: "Toggle line wrapping"),
            symbolName: "text.alignleft",
            action: #selector(EditorWindowController.toggleLineWrap(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorFunctionList,
            label: Localization.string(.toolbarFunctionListLabel, default: "Functions"),
            paletteLabel: Localization.string(.toolbarFunctionListLabel, default: "Functions"),
            toolTip: Localization.string(.toolbarFunctionListTooltip, default: "Show the function list"),
            symbolName: "list.bullet.rectangle",
            action: #selector(EditorWindowController.showFunctionList(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorToggleFold,
            label: Localization.string(.toolbarToggleFoldLabel, default: "Fold"),
            paletteLabel: Localization.string(.toolbarToggleFoldLabel, default: "Fold"),
            toolTip: Localization.string(.toolbarToggleFoldTooltip, default: "Toggle folding at the current line"),
            symbolName: "chevron.right.square",
            action: #selector(EditorWindowController.toggleFoldAtCurrentLine(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorFoldAll,
            label: Localization.string(.toolbarFoldAllLabel, default: "Fold All"),
            paletteLabel: Localization.string(.toolbarFoldAllLabel, default: "Fold All"),
            toolTip: Localization.string(.toolbarFoldAllTooltip, default: "Fold all foldable regions"),
            symbolName: "arrow.down.right.and.arrow.up.left",
            action: #selector(EditorWindowController.foldAll(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorUnfoldAll,
            label: Localization.string(.toolbarUnfoldAllLabel, default: "Unfold"),
            paletteLabel: Localization.string(.toolbarUnfoldAllPalette, default: "Unfold All"),
            toolTip: Localization.string(.toolbarUnfoldAllTooltip, default: "Unfold all folded regions"),
            symbolName: "arrow.up.left.and.arrow.down.right",
            action: #selector(EditorWindowController.unfoldAll(_:)),
            target: .controller
        )
    ]
}

private extension NSToolbar.Identifier {
    static let editorWindow = NSToolbar.Identifier("org.notepad-plus-plus.macnative.editor.toolbar")
}

private extension NSToolbarItem.Identifier {
    static let editorNew = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.new")
    static let editorOpen = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.open")
    static let editorSave = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.save")
    static let editorSaveAll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.save-all")
    static let editorClose = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.close")
    static let editorCloseAll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.close-all")
    static let editorPrint = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.print")
    static let editorCut = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.cut")
    static let editorCopy = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.copy")
    static let editorPaste = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.paste")
    static let editorUndo = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.undo")
    static let editorRedo = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.redo")
    static let editorFind = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.find")
    static let editorReplace = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.replace")
    static let editorToggleBookmark = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.bookmark.toggle")
    static let editorPreviousBookmark = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.bookmark.previous")
    static let editorNextBookmark = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.bookmark.next")
    static let editorToggleLineWrap = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.wrap.toggle")
    static let editorFunctionList = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.function-list")
    static let editorToggleFold = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.fold.toggle")
    static let editorFoldAll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.fold.all")
    static let editorUnfoldAll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.fold.unfold-all")
}
