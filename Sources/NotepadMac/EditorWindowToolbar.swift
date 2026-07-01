import AppKit

@MainActor
final class EditorWindowToolbar: NSObject, NSToolbarDelegate {
    static let contentRowAccessibilityIdentifier = "org.notepad-plus-plus.macnative.editor.toolbar.content-row"

    private enum CommandTarget: Equatable {
        case controller
        case appDelegate
        case responderChain
        case unavailable

        @MainActor
        func resolve(using controller: EditorWindowController?) -> AnyObject? {
            switch self {
            case .controller:
                return controller
            case .appDelegate:
                return NSApp.delegate as AnyObject?
            case .responderChain, .unavailable:
                return nil
            }
        }

        var isUnavailable: Bool {
            self == .unavailable
        }
    }

    private struct Command {
        let identifier: NSToolbarItem.Identifier
        let label: String
        let paletteLabel: String
        let toolTip: String
        let symbolName: String
        let action: Selector?
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

    func makeContentRow(sizeStyle: Int = 0) -> NSView {
        let row = EditorToolbarContentRowView()
        row.setAccessibilityIdentifier(Self.contentRowAccessibilityIdentifier)

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.spacing = 2

        for identifier in Self.defaultItemIdentifiers(includesFoldingCommands: includesFoldingCommands) {
            if identifier == .space {
                stackView.addArrangedSubview(EditorToolbarSeparatorView(sizeStyle: sizeStyle))
                continue
            }

            guard let command = Self.command(for: identifier) else { continue }
            let button = makeButton(for: command, sizeStyle: sizeStyle)
            stackView.addArrangedSubview(button)
        }

        row.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            stackView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -4)
        ])

        return row
    }

    static func contentRowHeight(sizeStyle: Int = 0) -> CGFloat {
        sizeStyle == 1 ? 24 : 30
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.defaultItemIdentifiers(includesFoldingCommands: includesFoldingCommands)
    }

    static func upstreamDefaultItemIdentifierRawValues(includesFoldingCommands: Bool) -> [String] {
        defaultItemIdentifiers(includesFoldingCommands: includesFoldingCommands).map(\.rawValue)
    }

    static func upstreamToolbarBitmapResourceNames() -> [String] {
        defaultItemIdentifiers(includesFoldingCommands: false).compactMap {
            upstreamBitmapResourceNamesByIdentifier[$0]
        }
    }

    private static func defaultItemIdentifiers(includesFoldingCommands: Bool) -> [NSToolbarItem.Identifier] {
        [
            .editorNew,
            .editorOpen,
            .editorSave,
            .editorSaveAll,
            .editorClose,
            .editorCloseAll,
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
            .editorFileCompare,
            .space,
            .editorZoomIn,
            .editorZoomOut,
            .space,
            .editorSyncVerticalScroll,
            .editorSyncHorizontalScroll,
            .space,
            .editorToggleLineWrap,
            .editorShowAllCharacters,
            .editorIndentGuide,
            .space,
            .editorUserDefinedLanguage,
            .editorDocumentMap,
            .editorDocumentList,
            .editorFunctionList,
            .editorFileBrowser,
            .space,
            .editorMonitoring,
            .space,
            .editorMacroStartRecording,
            .editorMacroStopRecording,
            .editorMacroPlayRecorded,
            .editorMacroRunMultiple,
            .editorMacroSaveCurrent
        ]
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
        item.image = Self.upstreamToolbarImage(for: command.identifier)
            ?? NSImage(systemSymbolName: command.symbolName, accessibilityDescription: command.label)
        item.target = target
        item.action = command.action
        item.isEnabled = !command.target.isUnavailable

        let menuItem = NSMenuItem(title: command.paletteLabel, action: command.action, keyEquivalent: "")
        menuItem.target = target
        menuItem.isEnabled = !command.target.isUnavailable
        item.menuFormRepresentation = menuItem

        return item
    }

    static func validate(toolbarItem: NSToolbarItem, using controller: EditorWindowController) -> Bool {
        guard let action = toolbarItem.action else {
            toolbarItem.menuFormRepresentation?.isEnabled = false
            return false
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

    private func makeButton(for command: Command, sizeStyle: Int) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.identifier = NSUserInterfaceItemIdentifier(command.identifier.rawValue)
        button.title = ""
        button.image = Self.upstreamToolbarImage(for: command.identifier)
            ?? NSImage(systemSymbolName: command.symbolName, accessibilityDescription: command.label)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.bezelStyle = .inline
        button.isBordered = false
        button.toolTip = command.toolTip
        button.target = command.target.resolve(using: controller)
        button.action = command.action
        button.isEnabled = !command.target.isUnavailable
        button.setAccessibilityLabel(command.label)

        let side = sizeStyle == 1 ? CGFloat(20) : CGFloat(24)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: side),
            button.heightAnchor.constraint(equalToConstant: side)
        ])

        return button
    }

    private static func upstreamToolbarImage(for identifier: NSToolbarItem.Identifier) -> NSImage? {
        guard let resourceName = upstreamBitmapResourceNamesByIdentifier[identifier] else {
            return nil
        }
        return UpstreamToolbarBitmap.image(named: resourceName)
    }

    private static let upstreamBitmapResourceNamesByIdentifier: [NSToolbarItem.Identifier: String] = [
        .editorNew: "newFile",
        .editorOpen: "openFile",
        .editorSave: "saveFile",
        .editorSaveAll: "saveAll",
        .editorClose: "closeFile",
        .editorCloseAll: "closeAll",
        .editorPrint: "print",
        .editorCut: "cut",
        .editorCopy: "copy",
        .editorPaste: "paste",
        .editorUndo: "undo",
        .editorRedo: "redo",
        .editorFind: "find",
        .editorReplace: "findReplace",
        .editorFileCompare: "cmpfile",
        .editorZoomIn: "zoomIn",
        .editorZoomOut: "zoomOut",
        .editorSyncVerticalScroll: "syncV",
        .editorSyncHorizontalScroll: "syncH",
        .editorToggleLineWrap: "wrap",
        .editorShowAllCharacters: "allChars",
        .editorIndentGuide: "indentGuide",
        .editorUserDefinedLanguage: "udl",
        .editorDocumentMap: "docMap",
        .editorDocumentList: "docList",
        .editorFunctionList: "funcList",
        .editorFileBrowser: "fileBrowser",
        .editorMonitoring: "monitoring",
        .editorMacroStartRecording: "startRecord",
        .editorMacroStopRecording: "stopRecord",
        .editorMacroPlayRecorded: "playRecord",
        .editorMacroRunMultiple: "playRecord_m",
        .editorMacroSaveCurrent: "saveRecord"
    ]

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
            identifier: .editorFileCompare,
            label: Localization.string(.diffToolbarFileCompare, default: "File Compare"),
            paletteLabel: Localization.string(.diffToolbarFileCompare, default: "File Compare"),
            toolTip: Localization.string(.diffToolbarFileCompare, default: "Compare two files"),
            symbolName: "doc.on.doc.fill",
            action: #selector(AppDelegate.compareFiles(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorZoomIn,
            label: Localization.string(.viewBiggerText, default: "Zoom In"),
            paletteLabel: Localization.string(.viewBiggerText, default: "Zoom In"),
            toolTip: Localization.string(.viewBiggerText, default: "Zoom In"),
            symbolName: "plus.magnifyingglass",
            action: #selector(EditorWindowController.increaseFontSize(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorZoomOut,
            label: Localization.string(.viewSmallerText, default: "Zoom Out"),
            paletteLabel: Localization.string(.viewSmallerText, default: "Zoom Out"),
            toolTip: Localization.string(.viewSmallerText, default: "Zoom Out"),
            symbolName: "minus.magnifyingglass",
            action: #selector(EditorWindowController.decreaseFontSize(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorSyncVerticalScroll,
            label: Localization.string(.viewSyncVerticalScroll, default: "Synchronize Vertical Scrolling"),
            paletteLabel: Localization.string(.viewSyncVerticalScroll, default: "Synchronize Vertical Scrolling"),
            toolTip: Localization.string(.viewSyncVerticalScroll, default: "Synchronize Vertical Scrolling"),
            symbolName: "arrow.up.arrow.down",
            action: #selector(EditorWindowController.toggleSynchronizedVerticalScrolling(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorSyncHorizontalScroll,
            label: Localization.string(.viewSyncHorizontalScroll, default: "Synchronize Horizontal Scrolling"),
            paletteLabel: Localization.string(.viewSyncHorizontalScroll, default: "Synchronize Horizontal Scrolling"),
            toolTip: Localization.string(.viewSyncHorizontalScroll, default: "Synchronize Horizontal Scrolling"),
            symbolName: "arrow.left.arrow.right",
            action: #selector(EditorWindowController.toggleSynchronizedHorizontalScrolling(_:)),
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
            identifier: .editorShowAllCharacters,
            label: Localization.string(.viewShowAllCharacters, default: "Show All Characters"),
            paletteLabel: Localization.string(.viewShowAllCharacters, default: "Show All Characters"),
            toolTip: Localization.string(.viewShowAllCharacters, default: "Show All Characters"),
            symbolName: "paragraphsign",
            action: #selector(EditorWindowController.toggleShowAllCharacters(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorIndentGuide,
            label: Localization.string(.viewShowIndentGuide, default: "Show Indent Guide"),
            paletteLabel: Localization.string(.viewShowIndentGuide, default: "Show Indent Guide"),
            toolTip: Localization.string(.viewShowIndentGuide, default: "Show Indent Guide"),
            symbolName: "increase.indent",
            action: #selector(EditorWindowController.toggleIndentGuides(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorUserDefinedLanguage,
            label: Localization.string(.languageUserDefined, default: "User Defined Languages..."),
            paletteLabel: Localization.string(.languageUserDefined, default: "User Defined Languages..."),
            toolTip: Localization.string(.languageUserDefined, default: "User Defined Languages..."),
            symbolName: "person.crop.rectangle",
            action: #selector(AppDelegate.showUserDefinedLanguages(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorDocumentMap,
            label: Localization.string(.viewDocumentMap, default: "Document Map..."),
            paletteLabel: Localization.string(.viewDocumentMap, default: "Document Map..."),
            toolTip: Localization.string(.viewDocumentMap, default: "Document Map..."),
            symbolName: "map",
            action: #selector(EditorWindowController.showDocumentMap(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorDocumentList,
            label: Localization.string(.viewDocumentList, default: "Document List..."),
            paletteLabel: Localization.string(.viewDocumentList, default: "Document List..."),
            toolTip: Localization.string(.viewDocumentList, default: "Document List..."),
            symbolName: "doc.plaintext",
            action: #selector(AppDelegate.showDocumentList(_:)),
            target: .appDelegate
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
            identifier: .editorFileBrowser,
            label: Localization.string(.viewFileBrowser, default: "File Browser..."),
            paletteLabel: Localization.string(.viewFileBrowser, default: "File Browser..."),
            toolTip: Localization.string(.viewFileBrowser, default: "File Browser..."),
            symbolName: "folder.badge.gearshape",
            action: #selector(AppDelegate.showFileBrowser(_:)),
            target: .appDelegate
        ),
        Command(
            identifier: .editorMonitoring,
            label: Localization.string(.viewMonitoring, default: "Monitoring (tail -f)"),
            paletteLabel: Localization.string(.viewMonitoring, default: "Monitoring (tail -f)"),
            toolTip: Localization.string(.viewMonitoring, default: "Monitoring (tail -f)"),
            symbolName: "eye",
            action: #selector(EditorWindowController.toggleMonitoringMode(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorMacroStartRecording,
            label: Localization.string(.macroStartRecording, default: "Start Recording"),
            paletteLabel: Localization.string(.macroStartRecording, default: "Start Recording"),
            toolTip: Localization.string(.macroStartRecording, default: "Start Recording"),
            symbolName: "record.circle",
            action: #selector(EditorWindowController.startMacroRecording(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorMacroStopRecording,
            label: Localization.string(.macroStopRecording, default: "Stop Recording"),
            paletteLabel: Localization.string(.macroStopRecording, default: "Stop Recording"),
            toolTip: Localization.string(.macroStopRecording, default: "Stop Recording"),
            symbolName: "stop.circle",
            action: #selector(EditorWindowController.stopMacroRecording(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorMacroPlayRecorded,
            label: Localization.string(.macroPlayLast, default: "Play Last Macro"),
            paletteLabel: Localization.string(.macroPlayLast, default: "Play Last Macro"),
            toolTip: Localization.string(.macroPlayLast, default: "Play Last Macro"),
            symbolName: "play.circle",
            action: #selector(EditorWindowController.playLastMacro(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorMacroRunMultiple,
            label: Localization.string(.macroRunMultipleTimes, default: "Run a Macro Multiple Times..."),
            paletteLabel: Localization.string(.macroRunMultipleTimes, default: "Run a Macro Multiple Times..."),
            toolTip: Localization.string(.macroRunMultipleTimes, default: "Run a Macro Multiple Times..."),
            symbolName: "repeat",
            action: #selector(EditorWindowController.runMacroMultipleTimes(_:)),
            target: .controller
        ),
        Command(
            identifier: .editorMacroSaveCurrent,
            label: Localization.string(.macroSaveLastAs, default: "Save Last Macro..."),
            paletteLabel: Localization.string(.macroSaveLastAs, default: "Save Last Macro..."),
            toolTip: Localization.string(.macroSaveLastAs, default: "Save Last Macro..."),
            symbolName: "square.and.arrow.down.badge.clock",
            action: #selector(EditorWindowController.saveLastMacroAsNamedMacro(_:)),
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
    static let editorFileCompare = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.file-compare")
    static let editorZoomIn = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.zoom-in")
    static let editorZoomOut = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.zoom-out")
    static let editorSyncVerticalScroll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.sync-vertical-scroll")
    static let editorSyncHorizontalScroll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.sync-horizontal-scroll")
    static let editorShowAllCharacters = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.show-all-characters")
    static let editorIndentGuide = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.indent-guide")
    static let editorUserDefinedLanguage = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.user-defined-language")
    static let editorDocumentMap = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.document-map")
    static let editorDocumentList = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.document-list")
    static let editorFileBrowser = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.file-browser")
    static let editorMonitoring = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.monitoring")
    static let editorMacroStartRecording = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.macro.start-recording")
    static let editorMacroStopRecording = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.macro.stop-recording")
    static let editorMacroPlayRecorded = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.macro.play-recorded")
    static let editorMacroRunMultiple = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.macro.run-multiple")
    static let editorMacroSaveCurrent = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.macro.save-current")
    static let editorToggleBookmark = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.bookmark.toggle")
    static let editorPreviousBookmark = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.bookmark.previous")
    static let editorNextBookmark = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.bookmark.next")
    static let editorToggleLineWrap = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.wrap.toggle")
    static let editorFunctionList = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.function-list")
    static let editorToggleFold = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.fold.toggle")
    static let editorFoldAll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.fold.all")
    static let editorUnfoldAll = NSToolbarItem.Identifier("org.notepad-plus-plus.macnative.editor.toolbar.fold.unfold-all")
}

private final class EditorToolbarContentRowView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        NSColor.separatorColor.withAlphaComponent(0.5).setFill()
        NSRect(x: 0, y: bounds.maxY - 0.5, width: bounds.width, height: 0.5).fill()
    }
}

private final class EditorToolbarSeparatorView: NSView {
    private let separator = NSBox()

    init(sizeStyle: Int) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        addSubview(separator)

        let height = sizeStyle == 1 ? CGFloat(14) : CGFloat(18)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 8),
            separator.centerXAnchor.constraint(equalTo: centerXAnchor),
            separator.centerYAnchor.constraint(equalTo: centerYAnchor),
            separator.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
