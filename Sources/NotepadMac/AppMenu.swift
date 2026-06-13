import AppKit
import NotepadMacCore

enum AppMenu {
    static let upstreamTopLevelMenuDefaultTitles: [String] = [
        "File",
        "Edit",
        "Search",
        "View",
        "Encoding",
        "Language",
        "Settings",
        "Tools",
        "Macro",
        "Run",
        "Plugins",
        "Window",
        "?"
    ]

    struct ShowSymbolMenuItemSpec {
        let localizationKey: Localization.Key?
        let defaultTitle: String
        let action: Selector?
        let isSeparator: Bool

        static func item(_ localizationKey: Localization.Key, _ defaultTitle: String, _ action: Selector) -> ShowSymbolMenuItemSpec {
            ShowSymbolMenuItemSpec(localizationKey: localizationKey, defaultTitle: defaultTitle, action: action, isSeparator: false)
        }

        static let separator = ShowSymbolMenuItemSpec(localizationKey: nil, defaultTitle: "", action: nil, isSeparator: true)
    }

    static let showSymbolMenuItemSpecs: [ShowSymbolMenuItemSpec] = [
        .item(.viewShowWhitespace, "Show Space and Tab", #selector(EditorWindowController.toggleShowWhitespace(_:))),
        .item(.viewShowEOL, "Show End of Line", #selector(EditorWindowController.toggleShowEOL(_:))),
        .item(.viewShowNpcCharacters, "Show Non-Printing Characters", #selector(EditorWindowController.toggleNpcDisplay(_:))),
        .item(.viewShowControlCharactersAndUnicodeEOL, "Show Control Characters && Unicode EOL", #selector(EditorWindowController.toggleControlCharactersAndUnicodeEOL(_:))),
        .item(.viewShowAllCharacters, "Show All Characters", #selector(EditorWindowController.toggleShowAllCharacters(_:))),
        .separator,
        .item(.viewShowIndentGuide, "Show Indent Guide", #selector(EditorWindowController.toggleIndentGuides(_:))),
        .item(.viewShowWrapSymbol, "Show Wrap Symbol", #selector(EditorWindowController.toggleWrapSymbol(_:)))
    ]

    enum WindowSortMode: Int {
        case none
        case nameAsc
        case nameDesc
        case pathAsc
        case pathDesc
        case typeAsc
        case typeDesc
        case sizeAsc
        case sizeDesc
        case dateAsc
        case dateDesc
        case contentLengthAsc
        case contentLengthDesc
    }

    @MainActor
    private static weak var installedThemeMenu: NSMenu?
    @MainActor
    private static weak var installedLanguageMenu: NSMenu?
    @MainActor
    private static weak var installedDelegate: AppDelegate?
    @MainActor
    private static weak var installedOpenRecentMenu: NSMenu?
    @MainActor
    private static weak var installedOpenRecentItem: NSMenuItem?
    @MainActor
    private static weak var installedFileMenu: NSMenu?
    private static let inlineRecentTag = 9900
    @MainActor
    private static weak var installedWindowMenu: NSMenu?
    @MainActor
    private static weak var installedWindowListMenu: NSMenu?
    @MainActor
    private static weak var installedWindowSortMenu: NSMenu?
    @MainActor
    private static weak var installedWindowPinMenu: NSMenuItem?
    @MainActor
    private static weak var installedWindowTabColorMenu: NSMenu?
    @MainActor
    private static weak var installedRunMenu: NSMenu?
    @MainActor
    private static weak var installedMacroMenu: NSMenu?

    @MainActor
    static func install(
        delegate: AppDelegate,
        catalog: LanguageCatalog,
        themeCatalog: ThemeCatalog,
        selectedThemeName: String?
    ) {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        installedDelegate = delegate

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        installSettingsMenuItems(in: appMenu, delegate: delegate)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: Localization.string(.appQuit, default: "Quit Notepad++ Mac"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: Localization.string(.fileMenu, default: "File"))
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: Localization.string(.fileNew, default: "New"), action: #selector(AppDelegate.newDocument(_:)), keyEquivalent: "n").target = delegate
        fileMenu.addItem(withTitle: Localization.string(.fileNewAndPaste, default: "New and Paste"), action: #selector(AppDelegate.newDocumentAndPaste(_:)), keyEquivalent: "").target = delegate
        fileMenu.addItem(withTitle: Localization.string(.fileOpen, default: "Open..."), action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o").target = delegate
        let recentItem = NSMenuItem(
            title: Localization.string(.fileOpenRecent, default: "Open Recent"),
            action: nil,
            keyEquivalent: ""
        )
        let recentMenu = NSMenu(title: Localization.string(.fileOpenRecent, default: "Open Recent"))
        recentItem.submenu = recentMenu
        recentItem.isEnabled = true
        installedOpenRecentMenu = recentMenu
        installedOpenRecentItem = recentItem
        installedFileMenu = fileMenu
        refreshRecentFiles()
        fileMenu.addItem(recentItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: Localization.string(.fileSave, default: "Save"), action: #selector(EditorWindowController.saveDocument(_:)), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(
            withTitle: Localization.string(.fileSaveAs, default: "Save As..."),
            action: #selector(EditorWindowController.saveDocumentAs(_:)),
            keyEquivalent: "S"
        )
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(
            withTitle: Localization.string(.fileSaveCopyAs, default: "Save Copy As..."),
            action: #selector(EditorWindowController.saveCopyAs(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileSaveAll, default: "Save All"),
            action: #selector(AppDelegate.saveAllDocuments(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(
            withTitle: Localization.string(.fileReloadFromDisk, default: "Reload from Disk"),
            action: #selector(EditorWindowController.reloadFromDisk(_:)),
            keyEquivalent: "r"
        ).keyEquivalentModifierMask = [.command, .option]
        fileMenu.addItem(
            withTitle: Localization.string(.fileRename, default: "Rename"),
            action: #selector(EditorWindowController.renameDocument(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileMoveToTrash, default: "Move to Trash"),
            action: #selector(EditorWindowController.moveToTrash(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileOpenContainingFolder, default: "Open Containing Folder"),
            action: #selector(EditorWindowController.openContainingFolder(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileOpenContainingFolderInTerminal, default: "Open Containing Folder in Terminal"),
            action: #selector(EditorWindowController.openContainingFolderInTerminal(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileOpenContainingFolderAsWorkspace, default: "Open Containing Folder as Workspace"),
            action: #selector(EditorWindowController.openContainingFolderAsWorkspace(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileOpenInDefaultViewer, default: "Open in Default Viewer"),
            action: #selector(EditorWindowController.openInDefaultViewer(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(
            withTitle: Localization.string(.fileInsertFile, default: "Insert File..."),
            action: #selector(EditorWindowController.insertFile(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: Localization.string(.filePrint, default: "Print..."), action: #selector(EditorWindowController.printDocument(_:)), keyEquivalent: "p")
        fileMenu.addItem(withTitle: Localization.string(.filePrintSelection, default: "Print Selection..."), action: #selector(EditorWindowController.printSelection(_:)), keyEquivalent: "")
        fileMenu.addItem(
            withTitle: Localization.string(.filePrintNow, default: "Print Now"),
            action: #selector(AppDelegate.printNow(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: Localization.string(.fileClose, default: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(
            withTitle: Localization.string(.fileCloseAll, default: "Close All"),
            action: #selector(AppDelegate.closeAllDocuments(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.fileCloseOthers, default: "Close Others"),
            action: #selector(AppDelegate.closeOtherDocuments(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.fileCloseUnchanged, default: "Close Unchanged"),
            action: #selector(AppDelegate.closeUnchangedDocuments(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.fileCloseAllToLeft, default: "Close All to Left"),
            action: #selector(AppDelegate.closeDocumentsToLeft(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.fileCloseAllToRight, default: "Close All to Right"),
            action: #selector(AppDelegate.closeDocumentsToRight(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.fileCloseAllButPinned, default: "Close All but Pinned"),
            action: #selector(AppDelegate.closeAllButPinnedDocuments(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(
            withTitle: Localization.string(.fileRestoreLastClosed, default: "Restore Last Closed File"),
            action: #selector(AppDelegate.restoreLastClosedDocument(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(
            withTitle: Localization.string(.fileLoadSession, default: "Load Session..."),
            action: #selector(AppDelegate.loadSession(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.fileSaveSession, default: "Save Session..."),
            action: #selector(AppDelegate.saveSessionToFile(_:)),
            keyEquivalent: ""
        ).target = delegate
        fileMenu.addItem(
            withTitle: Localization.string(.workspaceOpenFolder, default: "Open Folder as Workspace..."),
            action: #selector(AppDelegate.openFolderAsWorkspace(_:)),
            keyEquivalent: ""
        ).target = delegate

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: Localization.string(.editMenu, default: "Edit"))
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: Localization.string(.editUndo, default: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: Localization.string(.editRedo, default: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: Localization.string(.editCut, default: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: Localization.string(.editCopy, default: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: Localization.string(.editPaste, default: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: Localization.string(.editSelectAll, default: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(
            withTitle: Localization.string(.editBeginSelect, default: "Begin Select"),
            action: #selector(EditorWindowController.beginOrEndSelect(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editBeginSelectColumnMode, default: "Begin Select in Column Mode"),
            action: #selector(EditorWindowController.beginOrEndSelectInColumnMode(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editSelectBetweenDelimiters, default: "Select Between Delimiters"),
            action: #selector(EditorWindowController.selectBetweenDelimiters(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(NSMenuItem.separator())

        // Insert submenu
        func makeSubmenu(_ title: Localization.Key, _ defaultTitle: String) -> (NSMenuItem, NSMenu) {
            let item = NSMenuItem(title: Localization.string(title, default: defaultTitle), action: nil, keyEquivalent: "")
            let menu = NSMenu(title: Localization.string(title, default: defaultTitle))
            item.submenu = menu
            return (item, menu)
        }

        let (insertItem, insertMenu) = makeSubmenu(.editInsertMenu, "Insert")
        insertMenu.addItem(withTitle: Localization.string(.editInsertDateTimeShort, default: "Date Time (Short)"), action: #selector(EditorWindowController.insertDateTimeShort(_:)), keyEquivalent: "")
        insertMenu.addItem(withTitle: Localization.string(.editInsertDateTimeLong, default: "Date Time (Long)"), action: #selector(EditorWindowController.insertDateTimeLong(_:)), keyEquivalent: "")
        insertMenu.addItem(withTitle: Localization.string(.editInsertDateTimeCustomized, default: "Date Time (Customized)"), action: #selector(EditorWindowController.insertDateTimeCustomized(_:)), keyEquivalent: "")
        editMenu.addItem(insertItem)

        // Copy to Clipboard submenu
        let (copyClipItem, copyClipMenu) = makeSubmenu(.editCopyToClipboardMenu, "Copy to Clipboard")
        copyClipMenu.addItem(withTitle: Localization.string(.editCopyCurrentFullPath, default: "Copy Current Full File Path"), action: #selector(EditorWindowController.copyCurrentFullPath(_:)), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: Localization.string(.editCopyCurrentFilename, default: "Copy Current Filename"), action: #selector(EditorWindowController.copyCurrentFilename(_:)), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: Localization.string(.editCopyCurrentDirectoryPath, default: "Copy Current Dir. Path"), action: #selector(EditorWindowController.copyCurrentDirectoryPath(_:)), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: Localization.string(.editCopyLink, default: "Copy Link"), action: #selector(EditorWindowController.copyLink(_:)), keyEquivalent: "")
        copyClipMenu.addItem(NSMenuItem.separator())
        copyClipMenu.addItem(withTitle: Localization.string(.editCopyAllFilenames, default: "Copy All Filenames"), action: #selector(AppDelegate.copyAllFilenames(_:)), keyEquivalent: "").target = delegate
        copyClipMenu.addItem(withTitle: Localization.string(.editCopyAllFilePaths, default: "Copy All File Paths"), action: #selector(AppDelegate.copyAllFilePaths(_:)), keyEquivalent: "").target = delegate
        editMenu.addItem(copyClipItem)

        // Indent submenu
        let (indentItem, indentMenu) = makeSubmenu(.editIndentMenu, "Indent")
        indentMenu.addItem(withTitle: Localization.string(.editIncreaseLineIndent, default: "Increase Line Indent"), action: #selector(EditorWindowController.increaseLineIndent(_:)), keyEquivalent: "")
        indentMenu.addItem(withTitle: Localization.string(.editDecreaseLineIndent, default: "Decrease Line Indent"), action: #selector(EditorWindowController.decreaseLineIndent(_:)), keyEquivalent: "")
        editMenu.addItem(indentItem)

        // Convert Case to submenu
        let (caseItem, caseMenu) = makeSubmenu(.editConvertCaseMenu, "Convert Case to")
        caseMenu.addItem(withTitle: Localization.string(.editUppercase, default: "UPPERCASE"), action: #selector(EditorWindowController.uppercaseSelection(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editLowercase, default: "lowercase"), action: #selector(EditorWindowController.lowercaseSelection(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editProperCase, default: "Proper Case"), action: #selector(EditorWindowController.properCaseSelection(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editProperCaseBlend, default: "Proper Case (blend)"), action: #selector(EditorWindowController.properCaseBlendSelection(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editSentenceCase, default: "Sentence case"), action: #selector(EditorWindowController.sentenceCaseSelection(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editSentenceCaseBlend, default: "Sentence case (blend)"), action: #selector(EditorWindowController.sentenceCaseBlendSelection(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editInvertCase, default: "Invert Case"), action: #selector(EditorWindowController.invertSelectionCase(_:)), keyEquivalent: "")
        caseMenu.addItem(withTitle: Localization.string(.editRandomCase, default: "ranDOm CasE"), action: #selector(EditorWindowController.randomCaseSelection(_:)), keyEquivalent: "")
        editMenu.addItem(caseItem)

        // Line Operations submenu
        let (lineOpsItem, lineOpsMenu) = makeSubmenu(.editLineOperationsMenu, "Line Operations")
        lineOpsMenu.addItem(withTitle: Localization.string(.editDuplicateLineOrSelection, default: "Duplicate Line/Selection"), action: #selector(EditorWindowController.duplicateLineOrSelection(_:)), keyEquivalent: "d")
        lineOpsMenu.addItem(withTitle: Localization.string(.editRemoveDuplicateLines, default: "Remove Duplicate Lines"), action: #selector(EditorWindowController.removeDuplicateLines(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editRemoveConsecutiveDuplicateLines, default: "Remove Consecutive Duplicate Lines"), action: #selector(EditorWindowController.removeConsecutiveDuplicateLines(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSplitLines, default: "Split Lines"), action: #selector(EditorWindowController.splitLines(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editJoinLines, default: "Join Lines"), action: #selector(EditorWindowController.joinSelectedLines(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editMoveLineUp, default: "Move Line Up"), action: #selector(EditorWindowController.moveLineUp(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editMoveLineDown, default: "Move Line Down"), action: #selector(EditorWindowController.moveLineDown(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editRemoveEmptyLines, default: "Remove Empty Lines"), action: #selector(EditorWindowController.removeEmptyLines(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editRemoveBlankLines, default: "Remove Blank Lines"), action: #selector(EditorWindowController.removeBlankLines(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editDeleteLineOrSelection, default: "Delete Line/Selection"), action: #selector(EditorWindowController.deleteLineOrSelection(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editInsertBlankLineAboveCurrentLine, default: "Insert Line Above"), action: #selector(EditorWindowController.insertBlankLineAboveCurrentLine(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editInsertBlankLineBelowCurrentLine, default: "Insert Line Below"), action: #selector(EditorWindowController.insertBlankLineBelowCurrentLine(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editTransposeLine, default: "Transpose Line"), action: #selector(EditorWindowController.transposeLine(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesReverseOrder, default: "Reverse Line Order"), action: #selector(EditorWindowController.reverseLineOrder(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesRandomOrder, default: "Randomize Line Order"), action: #selector(EditorWindowController.randomizeLineOrder(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(NSMenuItem.separator())
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesAscending, default: "Sort Lines Ascending"), action: #selector(EditorWindowController.sortLinesAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesCaseInsensitiveAscending, default: "Sort Lines Lex. Ascending Ignoring Case"), action: #selector(EditorWindowController.sortLinesCaseInsensitiveAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesLocaleAscending, default: "Sort Lines In Locale Order Ascending"), action: #selector(EditorWindowController.sortLinesLocaleAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesIntegerAscending, default: "Sort Lines As Integers Ascending"), action: #selector(EditorWindowController.sortLinesIntegerAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesDecimalCommaAscending, default: "Sort Lines As Decimals (Comma) Ascending"), action: #selector(EditorWindowController.sortLinesDecimalCommaAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesDecimalDotAscending, default: "Sort Lines As Decimals (Dot) Ascending"), action: #selector(EditorWindowController.sortLinesDecimalDotAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesLengthAscending, default: "Sort Lines By Length Ascending"), action: #selector(EditorWindowController.sortLinesLengthAscending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(NSMenuItem.separator())
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesDescending, default: "Sort Lines Descending"), action: #selector(EditorWindowController.sortLinesDescending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesCaseInsensitiveDescending, default: "Sort Lines Lex. Descending Ignoring Case"), action: #selector(EditorWindowController.sortLinesCaseInsensitiveDescending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesLocaleDescending, default: "Sort Lines In Locale Order Descending"), action: #selector(EditorWindowController.sortLinesLocaleDescending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesIntegerDescending, default: "Sort Lines As Integers Descending"), action: #selector(EditorWindowController.sortLinesIntegerDescending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesDecimalCommaDescending, default: "Sort Lines As Decimals (Comma) Descending"), action: #selector(EditorWindowController.sortLinesDecimalCommaDescending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesDecimalDotDescending, default: "Sort Lines As Decimals (Dot) Descending"), action: #selector(EditorWindowController.sortLinesDecimalDotDescending(_:)), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: Localization.string(.editSortLinesLengthDescending, default: "Sort Lines By Length Descending"), action: #selector(EditorWindowController.sortLinesLengthDescending(_:)), keyEquivalent: "")
        editMenu.addItem(lineOpsItem)

        // Comment/Uncomment submenu
        let (commentItem, commentMenu) = makeSubmenu(.editCommentMenu, "Comment/Uncomment")
        commentMenu.addItem(withTitle: Localization.string(.editToggleLineComment, default: "Toggle Line Comment"), action: #selector(EditorWindowController.toggleLineComment(_:)), keyEquivalent: "/")
        commentMenu.addItem(withTitle: Localization.string(.editSetBlockComments, default: "Block Comment Set"), action: #selector(EditorWindowController.setBlockComments(_:)), keyEquivalent: "")
        commentMenu.addItem(withTitle: Localization.string(.editRemoveBlockComments, default: "Block Uncomment"), action: #selector(EditorWindowController.removeBlockComments(_:)), keyEquivalent: "")
        commentMenu.addItem(withTitle: Localization.string(.editStreamComment, default: "Stream Comment"), action: #selector(EditorWindowController.streamComment(_:)), keyEquivalent: "")
        commentMenu.addItem(withTitle: Localization.string(.editStreamUncomment, default: "Stream Uncomment"), action: #selector(EditorWindowController.streamUncomment(_:)), keyEquivalent: "")
        editMenu.addItem(commentItem)

        // Auto-Completion submenu
        let (autoCompleteItem, autoCompleteMenu) = makeSubmenu(.editAutoCompletionMenu, "Auto-Completion")
        autoCompleteMenu.addItem(withTitle: Localization.string(.editAutoCompletion, default: "Function Completion"), action: #selector(EditorWindowController.showAutoCompletion(_:)), keyEquivalent: "")
        autoCompleteMenu.addItem(withTitle: Localization.string(.editAutoCompleteCurrentFile, default: "Word Completion"), action: #selector(EditorWindowController.showCurrentFileAutoCompletion(_:)), keyEquivalent: "")
        autoCompleteMenu.addItem(withTitle: Localization.string(.editFunctionCallTip, default: "Function Parameters Hint"), action: #selector(EditorWindowController.showCallTip(_:)), keyEquivalent: "")
        let nextHintItem = autoCompleteMenu.addItem(withTitle: Localization.string(.editFunctionCallTipNext, default: "Function Parameters Next Hint"), action: #selector(EditorWindowController.showNextCallTipSignature(_:)), keyEquivalent: String(UnicodeScalar(NSEvent.SpecialKey.downArrow.rawValue)!))
        nextHintItem.keyEquivalentModifierMask = [.option]
        let previousHintItem = autoCompleteMenu.addItem(withTitle: Localization.string(.editFunctionCallTipPrevious, default: "Function Parameters Previous Hint"), action: #selector(EditorWindowController.showPreviousCallTipSignature(_:)), keyEquivalent: String(UnicodeScalar(NSEvent.SpecialKey.upArrow.rawValue)!))
        previousHintItem.keyEquivalentModifierMask = [.option]
        autoCompleteMenu.addItem(withTitle: Localization.string(.editAutoCompletePath, default: "Path Completion"), action: #selector(EditorWindowController.showPathAutoCompletion(_:)), keyEquivalent: "")
        editMenu.addItem(autoCompleteItem)

        // Blank Operations submenu
        let (blankItem, blankMenu) = makeSubmenu(.editBlankOperationsMenu, "Blank Operations")
        let trimTrailingItem = blankMenu.addItem(withTitle: Localization.string(.editTrimTrailingWhitespace, default: "Trim Trailing Whitespace"), action: #selector(EditorWindowController.trimTrailingWhitespace(_:)), keyEquivalent: "t")
        trimTrailingItem.keyEquivalentModifierMask = [.command, .option]
        blankMenu.addItem(withTitle: Localization.string(.editTrimLeadingWhitespace, default: "Trim Leading Whitespace"), action: #selector(EditorWindowController.trimLeadingWhitespace(_:)), keyEquivalent: "")
        blankMenu.addItem(withTitle: Localization.string(.editTrimLeadingAndTrailingWhitespace, default: "Trim Leading and Trailing Whitespace"), action: #selector(EditorWindowController.trimLeadingAndTrailingWhitespace(_:)), keyEquivalent: "")
        blankMenu.addItem(withTitle: Localization.string(.editEolToWhitespace, default: "EOL to Whitespace"), action: #selector(EditorWindowController.eolToWhitespace(_:)), keyEquivalent: "")
        blankMenu.addItem(withTitle: Localization.string(.editTrimAll, default: "Trim All"), action: #selector(EditorWindowController.trimAll(_:)), keyEquivalent: "")
        blankMenu.addItem(NSMenuItem.separator())
        blankMenu.addItem(withTitle: Localization.string(.editTabToSpaces, default: "Tab to Spaces"), action: #selector(EditorWindowController.tabToSpaces(_:)), keyEquivalent: "")
        blankMenu.addItem(withTitle: Localization.string(.editSpaceToTabsAll, default: "Space to Tab (All)"), action: #selector(EditorWindowController.spaceToTabsAll(_:)), keyEquivalent: "")
        blankMenu.addItem(withTitle: Localization.string(.editSpaceToTabsLeading, default: "Space to Tab (Leading)"), action: #selector(EditorWindowController.spaceToTabsLeading(_:)), keyEquivalent: "")
        editMenu.addItem(blankItem)

        // Paste Special submenu
        let (pasteSpecialItem, pasteSpecialMenu) = makeSubmenu(.editPasteSpecialMenu, "Paste Special")
        pasteSpecialMenu.addItem(withTitle: Localization.string(.editPasteAsPlainText, default: "Paste as Plain Text"), action: #selector(EditorWindowController.pasteAsPlainText(_:)), keyEquivalent: "V").keyEquivalentModifierMask = [.command, .shift, .option]
        pasteSpecialMenu.addItem(NSMenuItem.separator())
        pasteSpecialMenu.addItem(withTitle: Localization.string(.editPasteHTMLContent, default: "Paste HTML Content"), action: #selector(EditorWindowController.pasteHtmlContent(_:)), keyEquivalent: "")
        pasteSpecialMenu.addItem(withTitle: Localization.string(.editPasteRTFContent, default: "Paste RTF Content"), action: #selector(EditorWindowController.pasteRtfContent(_:)), keyEquivalent: "")
        pasteSpecialMenu.addItem(NSMenuItem.separator())
        pasteSpecialMenu.addItem(withTitle: Localization.string(.editCopyBinaryContent, default: "Copy Binary Content"), action: #selector(EditorWindowController.copyBinaryContent(_:)), keyEquivalent: "")
        pasteSpecialMenu.addItem(withTitle: Localization.string(.editCutBinaryContent, default: "Cut Binary Content"), action: #selector(EditorWindowController.cutBinaryContent(_:)), keyEquivalent: "")
        pasteSpecialMenu.addItem(withTitle: Localization.string(.editPasteBinaryContent, default: "Paste Binary Content"), action: #selector(EditorWindowController.pasteBinaryContent(_:)), keyEquivalent: "")
        editMenu.addItem(pasteSpecialItem)

        // Copy Special submenu
        let (copySpecialItem, copySpecialMenu) = makeSubmenu(.editCopySpecialMenu, "Copy Special")
        copySpecialMenu.addItem(withTitle: Localization.string(.editCopyAsHTML, default: "Copy as HTML"), action: #selector(EditorWindowController.copySelectionAsHTML(_:)), keyEquivalent: "")
        copySpecialMenu.addItem(withTitle: Localization.string(.editCopyAsRTF, default: "Copy as RTF"), action: #selector(EditorWindowController.copySelectionAsRTF(_:)), keyEquivalent: "")
        editMenu.addItem(copySpecialItem)

        // On Selection submenu
        let (onSelItem, onSelMenu) = makeSubmenu(.editOnSelectionMenu, "On Selection")
        onSelMenu.addItem(withTitle: Localization.string(.editOpenSelectedFile, default: "Open File"), action: #selector(EditorWindowController.openSelectedFile(_:)), keyEquivalent: "")
        onSelMenu.addItem(withTitle: Localization.string(.editOpenSelectedContainingFolder, default: "Open Containing Folder"), action: #selector(EditorWindowController.openSelectedContainingFolder(_:)), keyEquivalent: "")
        onSelMenu.addItem(NSMenuItem.separator())
        onSelMenu.addItem(withTitle: Localization.string(.editRedactSelection, default: "Redact Selection"), action: #selector(EditorWindowController.redactSelection(_:)), keyEquivalent: "")
        onSelMenu.addItem(NSMenuItem.separator())
        onSelMenu.addItem(withTitle: Localization.string(.editSearchOnInternet, default: "Search on Internet"), action: #selector(EditorWindowController.searchOnInternet(_:)), keyEquivalent: "")
        onSelMenu.addItem(withTitle: Localization.string(.editChangeSearchEngine, default: "Change Search Engine..."), action: #selector(EditorWindowController.changeSearchEngine(_:)), keyEquivalent: "")
        editMenu.addItem(onSelItem)

        editMenu.addItem(NSMenuItem.separator())

        // Multi-Select submenu
        let multiSelectMenuItem = NSMenuItem(title: Localization.string(.editMultiSelectMenu, default: "Multi-Select"), action: nil, keyEquivalent: "")
        let multiSelectMenu = NSMenu(title: Localization.string(.editMultiSelectMenu, default: "Multi-Select"))
        multiSelectMenuItem.submenu = multiSelectMenu
        editMenu.addItem(multiSelectMenuItem)
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectAll, default: "Select All Occurrences"), action: #selector(EditorWindowController.multiSelectAll(_:)), keyEquivalent: "a").keyEquivalentModifierMask = [.control, .command]
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectAllMatchCase, default: "Select All Occurrences (Match Case)"), action: #selector(EditorWindowController.multiSelectAllMatchCase(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectAllWholeWord, default: "Select All Occurrences (Whole Word)"), action: #selector(EditorWindowController.multiSelectAllWholeWord(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectAllMatchCaseWholeWord, default: "Select All Occurrences (Match Case & Whole Word)"), action: #selector(EditorWindowController.multiSelectAllMatchCaseWholeWord(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(NSMenuItem.separator())
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectNext, default: "Add Next Occurrence"), action: #selector(EditorWindowController.multiSelectNext(_:)), keyEquivalent: "d").keyEquivalentModifierMask = [.control, .command]
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectNextMatchCase, default: "Add Next Occurrence (Match Case)"), action: #selector(EditorWindowController.multiSelectNextMatchCase(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectNextWholeWord, default: "Add Next Occurrence (Whole Word)"), action: #selector(EditorWindowController.multiSelectNextWholeWord(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectNextMatchCaseWholeWord, default: "Add Next Occurrence (Match Case & Whole Word)"), action: #selector(EditorWindowController.multiSelectNextMatchCaseWholeWord(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(NSMenuItem.separator())
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectUndo, default: "Undo Last Multi-Select"), action: #selector(EditorWindowController.multiSelectUndo(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(withTitle: Localization.string(.editMultiSelectSkip, default: "Skip and Add Next"), action: #selector(EditorWindowController.multiSelectSkip(_:)), keyEquivalent: "")
        multiSelectMenu.addItem(withTitle: Localization.string(.editColumnSelectionToMultiCursor, default: "Column Selection to Multi-Editing"), action: #selector(EditorWindowController.columnSelectionToMultiCursor(_:)), keyEquivalent: "")

        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: Localization.string(.editColumnEditor, default: "Column Editor..."), action: #selector(EditorWindowController.showColumnEditor(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: Localization.string(.editRectangularSelection, default: "Rectangular Selection..."), action: #selector(EditorWindowController.showRectangularSelectionPanel(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: Localization.string(.editSelectLine, default: "Select Line"), action: #selector(EditorWindowController.selectCurrentLine(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: Localization.string(.editCharacterPanel, default: "Character Panel"), action: #selector(EditorWindowController.showCharacterPanel(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: Localization.string(.editClipboardHistory, default: "Clipboard History"), action: #selector(EditorWindowController.showClipboardHistoryPanel(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: Localization.string(.editIncreaseNumber, default: "Increase Number"), action: #selector(EditorWindowController.increaseNumberAtCaret(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: Localization.string(.editDecreaseNumber, default: "Decrease Number"), action: #selector(EditorWindowController.decreaseNumberAtCaret(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())

        // Read-Only submenu
        let (readOnlyItem, readOnlyMenu) = makeSubmenu(.editReadOnlyMenu, "Read-Only")
        readOnlyMenu.addItem(withTitle: Localization.string(.editToggleReadOnly, default: "Read-Only on Current Document"), action: #selector(EditorWindowController.toggleReadOnly(_:)), keyEquivalent: "")
        readOnlyMenu.addItem(withTitle: Localization.string(.editSetReadOnlyAll, default: "Read-Only for All Documents"), action: #selector(AppDelegate.setReadOnlyForAll(_:)), keyEquivalent: "").target = delegate
        readOnlyMenu.addItem(withTitle: Localization.string(.editClearReadOnlyAll, default: "Clear Read-Only for All Documents"), action: #selector(AppDelegate.clearReadOnlyForAll(_:)), keyEquivalent: "").target = delegate
        editMenu.addItem(readOnlyItem)

        // --- Text direction ---
        editMenu.addItem(NSMenuItem.separator())
        let (directionItem, directionMenu) = makeSubmenu(.editTextDirectionMenu, "Text Direction")
        directionMenu.addItem(withTitle: Localization.string(.editTextDirectionRTL, default: "Right-to-Left"), action: #selector(EditorWindowController.setTextDirectionRTL(_:)), keyEquivalent: "")
        directionMenu.addItem(withTitle: Localization.string(.editTextDirectionLTR, default: "Left-to-Right"), action: #selector(EditorWindowController.setTextDirectionLTR(_:)), keyEquivalent: "")
        editMenu.addItem(directionItem)

        let encodingMenuItem = NSMenuItem()
        mainMenu.addItem(encodingMenuItem)
        let encodingMenu = NSMenu(title: Localization.string(.encodingMenu, default: "Encoding"))
        encodingMenuItem.submenu = encodingMenu

        // Convert to: change encoding tag, re-save with new encoding
        let convertToMenuItem = NSMenuItem(title: Localization.string(.encodingConvertToMenu, default: "Convert to"), action: nil, keyEquivalent: "")
        let convertToMenu = NSMenu(title: Localization.string(.encodingConvertToMenu, default: "Convert to"))
        convertToMenuItem.submenu = convertToMenu
        populateEncodingMenu(convertToMenu, action: #selector(EditorWindowController.convertEncoding(_:)))
        encodingMenu.addItem(convertToMenuItem)

        // Encode in: re-read file with different encoding
        let encodeInMenuItem = NSMenuItem(title: Localization.string(.encodingEncodeInMenu, default: "Encode in"), action: nil, keyEquivalent: "")
        let encodeInMenu = NSMenu(title: Localization.string(.encodingEncodeInMenu, default: "Encode in"))
        encodeInMenuItem.submenu = encodeInMenu
        populateEncodingMenu(encodeInMenu, action: #selector(EditorWindowController.encodeInEncoding(_:)))
        encodingMenu.addItem(encodeInMenuItem)

        // Auto-detect encoding
        encodingMenu.addItem(
            withTitle: Localization.string(.encodingAutoDetect, default: "Auto-Detect Encoding"),
            action: #selector(EditorWindowController.autoDetectEncoding(_:)),
            keyEquivalent: ""
        )
        // BOM toggle
        encodingMenu.addItem(
            withTitle: Localization.string(.encodingToggleBOM, default: "Add / Remove UTF-8 BOM"),
            action: #selector(EditorWindowController.toggleByteOrderMark(_:)),
            keyEquivalent: ""
        )
        // Reload as Encoding submenu
        let reloadAsItem = NSMenuItem(title: Localization.string(.encodingReloadAs, default: "Reload as Encoding"), action: nil, keyEquivalent: "")
        let reloadAsMenu = NSMenu(title: Localization.string(.encodingReloadAs, default: "Reload as Encoding"))
        reloadAsItem.submenu = reloadAsMenu
        populateEncodingMenu(reloadAsMenu, action: #selector(EditorWindowController.reloadAsEncoding(_:)), excludeASCII: true)
        encodingMenu.addItem(reloadAsItem)
        encodingMenu.addItem(NSMenuItem.separator())
        let lineEndingMenuItem = NSMenuItem(
            title: Localization.string(.lineEndingMenu, default: "EOL Conversion"),
            action: nil,
            keyEquivalent: ""
        )
        let lineEndingMenu = NSMenu(title: Localization.string(.lineEndingMenu, default: "EOL Conversion"))
        lineEndingMenuItem.submenu = lineEndingMenu
        encodingMenu.addItem(lineEndingMenuItem)
        for lineEnding in LineEnding.allCases {
            let item = NSMenuItem(
                title: String(
                    format: Localization.string(.lineEndingConvertToFormat, default: "Convert to %@"),
                    lineEnding.displayName
                ),
                action: #selector(EditorWindowController.convertLineEnding(_:)),
                keyEquivalent: ""
            )
            item.representedObject = lineEnding.rawValue
            lineEndingMenu.addItem(item)
        }

        let searchMenuItem = NSMenuItem()
        mainMenu.addItem(searchMenuItem)
        let searchMenu = NSMenu(title: Localization.string(.searchMenu, default: "Search"))
        searchMenuItem.submenu = searchMenu
        searchMenu.addItem(withTitle: Localization.string(.searchFind, default: "Find..."), action: #selector(EditorWindowController.showFindPanel(_:)), keyEquivalent: "f")
        searchMenu.addItem(withTitle: Localization.string(.searchFindNext, default: "Find Next"), action: #selector(EditorWindowController.findNext(_:)), keyEquivalent: "g")
        let searchFindPrevious = searchMenu.addItem(
            withTitle: Localization.string(.searchFindPrevious, default: "Find Previous"),
            action: #selector(EditorWindowController.findPrevious(_:)),
            keyEquivalent: "G"
        )
        searchFindPrevious.keyEquivalentModifierMask = [.command, .shift]
        let searchReplace = searchMenu.addItem(
            withTitle: Localization.string(.searchReplace, default: "Replace..."),
            action: #selector(EditorWindowController.showReplacePanel(_:)),
            keyEquivalent: "f"
        )
        searchReplace.keyEquivalentModifierMask = [.command, .option]
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(
            withTitle: Localization.string(.searchFindInFiles, default: "Find in Files..."),
            action: #selector(EditorWindowController.showFindInFilesPanel(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.command, .shift]
        searchMenu.addItem(
            withTitle: Localization.string(.searchFindInProjects, default: "Find in Projects..."),
            action: #selector(AppDelegate.showFindInProjectsPanel(_:)),
            keyEquivalent: ""
        ).target = delegate
        searchMenu.addItem(
            withTitle: Localization.string(.searchFindInFinder, default: "Find in Search Results..."),
            action: #selector(AppDelegate.showFindInFinderPanel(_:)),
            keyEquivalent: ""
        ).target = delegate
        let goToLine = searchMenu.addItem(
            withTitle: Localization.string(.searchGoToLine, default: "Go To Line..."),
            action: #selector(EditorWindowController.showGoToLinePanel(_:)),
            keyEquivalent: "l"
        )
        goToLine.keyEquivalentModifierMask = [.command]
        searchMenu.addItem(
            withTitle: Localization.string(.searchGoToMatchingBrace, default: "Go to Matching Brace"),
            action: #selector(EditorWindowController.goToMatchingBrace(_:)),
            keyEquivalent: "b"
        )
        searchMenu.addItem(
            withTitle: Localization.string(.searchSelectToMatchingBrace, default: "Select to Matching Brace"),
            action: #selector(EditorWindowController.selectToMatchingBrace(_:)),
            keyEquivalent: "B"
        ).keyEquivalentModifierMask = [.command, .shift]
        searchMenu.addItem(
            withTitle: Localization.string(.searchSelectAllBetweenBraces, default: "Select All Between Braces"),
            action: #selector(EditorWindowController.selectAllBetweenMatchingBraces(_:)),
            keyEquivalent: ""
        )
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(
            withTitle: Localization.string(.searchSetAndFindNext, default: "Set and Find Next"),
            action: #selector(EditorWindowController.setAndFindNext(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.command, .control]
        searchMenu.addItem(
            withTitle: Localization.string(.searchSetAndFindPrevious, default: "Set and Find Previous"),
            action: #selector(EditorWindowController.setAndFindPrevious(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.command, .control, .shift]
        searchMenu.addItem(
            withTitle: Localization.string(.searchVolatileFindNext, default: "Find Next (Volatile)"),
            action: #selector(EditorWindowController.volatileFindNext(_:)),
            keyEquivalent: "g"
        ).keyEquivalentModifierMask = [.control]
        searchMenu.addItem(
            withTitle: Localization.string(.searchVolatileFindPrevious, default: "Find Previous (Volatile)"),
            action: #selector(EditorWindowController.volatileFindPrevious(_:)),
            keyEquivalent: "g"
        ).keyEquivalentModifierMask = [.control, .shift]
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(
            withTitle: Localization.string(.searchIncrementalSearch, default: "Incremental Search"),
            action: #selector(EditorWindowController.showIncrementalSearch(_:)),
            keyEquivalent: "i"
        ).keyEquivalentModifierMask = [.command, .option]
        searchMenu.addItem(
            withTitle: Localization.string(.searchSelectAndFindNext, default: "Select and Find Next"),
            action: #selector(EditorWindowController.selectAndFindNext(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.control, .command]
        searchMenu.addItem(
            withTitle: Localization.string(.searchSelectAndFindPrevious, default: "Select and Find Previous"),
            action: #selector(EditorWindowController.selectAndFindPrevious(_:)),
            keyEquivalent: "f"
        ).keyEquivalentModifierMask = [.control, .command, .shift]
        searchMenu.addItem(
            withTitle: Localization.string(.searchFindCharactersInRange, default: "Find Characters in Range..."),
            action: #selector(EditorWindowController.showFindCharRangePanel(_:)),
            keyEquivalent: ""
        )
        searchMenu.addItem(NSMenuItem.separator())
        let markMenuItem = NSMenuItem(title: Localization.string(.searchMarkMenu, default: "Mark"), action: nil, keyEquivalent: "")
        let markMenu = NSMenu(title: Localization.string(.searchMarkMenu, default: "Mark"))
        markMenuItem.submenu = markMenu
        searchMenu.addItem(markMenuItem)
        markMenu.addItem(
            withTitle: Localization.string(.searchCutMarkedLines, default: "Cut Marked Lines"),
            action: #selector(EditorWindowController.cutMarkedLines(_:)),
            keyEquivalent: ""
        )
        markMenu.addItem(
            withTitle: Localization.string(.searchCopyMarkedLines, default: "Copy Marked Lines"),
            action: #selector(EditorWindowController.copyMarkedLines(_:)),
            keyEquivalent: ""
        )
        markMenu.addItem(
            withTitle: Localization.string(.searchPasteMarkedLines, default: "Paste Marked Lines"),
            action: #selector(EditorWindowController.pasteMarkedLines(_:)),
            keyEquivalent: ""
        )
        markMenu.addItem(
            withTitle: Localization.string(.searchDeleteMarkedLines, default: "Delete Marked Lines"),
            action: #selector(EditorWindowController.deleteMarkedLines(_:)),
            keyEquivalent: ""
        )
        markMenu.addItem(
            withTitle: Localization.string(.searchDeleteUnmarkedLines, default: "Delete Unmarked Lines"),
            action: #selector(EditorWindowController.deleteUnmarkedLines(_:)),
            keyEquivalent: ""
        )
        markMenu.addItem(NSMenuItem.separator())
        markMenu.addItem(
            withTitle: Localization.string(.searchInverseBookmarkMarks, default: "Inverse Bookmark"),
            action: #selector(EditorWindowController.inverseBookmarkMarks(_:)),
            keyEquivalent: ""
        )
        markMenu.addItem(NSMenuItem.separator())
        markMenu.addItem(
            withTitle: Localization.string(.searchCopyMarkedText, default: "Copy Marked Text"),
            action: #selector(EditorWindowController.copyMarkedText(_:)),
            keyEquivalent: ""
        )
        searchMenu.addItem(NSMenuItem.separator())
        let bookmarkMenuItem = NSMenuItem(title: Localization.string(.bookmarkMenu, default: "Bookmark"), action: nil, keyEquivalent: "")
        let bookmarkMenu = NSMenu(title: Localization.string(.bookmarkMenu, default: "Bookmark"))
        bookmarkMenuItem.submenu = bookmarkMenu
        searchMenu.addItem(bookmarkMenuItem)
        bookmarkMenu.addItem(
            withTitle: Localization.string(.bookmarkToggle, default: "Toggle Bookmark"),
            action: #selector(EditorWindowController.toggleBookmark(_:)),
            keyEquivalent: ""
        )
        bookmarkMenu.addItem(
            withTitle: Localization.string(.bookmarkNext, default: "Next Bookmark"),
            action: #selector(EditorWindowController.nextBookmark(_:)),
            keyEquivalent: ""
        )
        bookmarkMenu.addItem(
            withTitle: Localization.string(.bookmarkPrevious, default: "Previous Bookmark"),
            action: #selector(EditorWindowController.previousBookmark(_:)),
            keyEquivalent: ""
        )
        bookmarkMenu.addItem(NSMenuItem.separator())
        bookmarkMenu.addItem(
            withTitle: Localization.string(.bookmarkClearAll, default: "Clear All Bookmarks"),
            action: #selector(EditorWindowController.clearBookmarks(_:)),
            keyEquivalent: ""
        )
        bookmarkMenu.addItem(NSMenuItem.separator())
        bookmarkMenu.addItem(
            withTitle: Localization.string(.bookmarkAllMatches, default: "Bookmark All Matches..."),
            action: #selector(EditorWindowController.bookmarkAllMatchesFromMenu(_:)),
            keyEquivalent: ""
        )
        bookmarkMenu.addItem(NSMenuItem.separator())
        bookmarkMenu.addItem(withTitle: Localization.string(.bookmarkCutMarkedLines, default: "Cut Bookmarked Lines"), action: #selector(EditorWindowController.cutMarkedLines(_:)), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: Localization.string(.bookmarkCopyMarkedLines, default: "Copy Bookmarked Lines"), action: #selector(EditorWindowController.copyMarkedLines(_:)), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: Localization.string(.bookmarkPasteMarkedLines, default: "Paste to (Replace) Bookmarked Lines"), action: #selector(EditorWindowController.pasteMarkedLines(_:)), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: Localization.string(.bookmarkDeleteMarkedLines, default: "Remove Bookmarked Lines"), action: #selector(EditorWindowController.deleteMarkedLines(_:)), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: Localization.string(.bookmarkDeleteUnmarkedLines, default: "Remove Non-Bookmarked Lines"), action: #selector(EditorWindowController.deleteUnmarkedLines(_:)), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: Localization.string(.bookmarkInverseBookmarks, default: "Inverse Bookmarks"), action: #selector(EditorWindowController.inverseBookmarks(_:)), keyEquivalent: "")
        searchMenu.addItem(NSMenuItem.separator())

        let styles: [(SearchMarkStyle, String)] = [(.style1, "1st Style"), (.style2, "2nd Style"), (.style3, "3rd Style"), (.style4, "4th Style"), (.style5, "5th Style")]

        // Style All Occurrences of Token
        let styleAllItem = NSMenuItem(title: Localization.string(.searchStyleMenu, default: "Style All Occurrences of Token"), action: nil, keyEquivalent: "")
        let styleAllMenu = NSMenu(title: Localization.string(.searchStyleMenu, default: "Style All Occurrences of Token"))
        styleAllItem.submenu = styleAllMenu
        searchMenu.addItem(styleAllItem)
        for (style, label) in styles {
            styleAllMenu.addItem(withTitle: label, action: #selector(EditorWindowController.markAllUsingStyle(_:)), keyEquivalent: "").representedObject = style
        }

        // Style One Token
        let styleOneItem = NSMenuItem(title: Localization.string(.searchStyleOneToken, default: "Style One Token"), action: nil, keyEquivalent: "")
        let styleOneMenu = NSMenu(title: Localization.string(.searchStyleOneToken, default: "Style One Token"))
        styleOneItem.submenu = styleOneMenu
        searchMenu.addItem(styleOneItem)
        for (style, label) in styles {
            styleOneMenu.addItem(withTitle: label, action: #selector(EditorWindowController.markOneUsingStyle(_:)), keyEquivalent: "").representedObject = style
        }

        // Clear Style
        let clearStyleItem = NSMenuItem(title: Localization.string(.searchClearStyle, default: "Clear Style"), action: nil, keyEquivalent: "")
        let clearStyleMenu = NSMenu(title: Localization.string(.searchClearStyle, default: "Clear Style"))
        clearStyleItem.submenu = clearStyleMenu
        searchMenu.addItem(clearStyleItem)
        for (style, label) in styles {
            clearStyleMenu.addItem(withTitle: label, action: #selector(EditorWindowController.unmarkAllUsingStyle(_:)), keyEquivalent: "").representedObject = style
        }
        clearStyleMenu.addItem(withTitle: Localization.string(.searchClearAllStyles, default: "Clear All Styles"), action: #selector(EditorWindowController.clearAllStyles(_:)), keyEquivalent: "")

        // Jump Up (Previous)
        let jumpUpItem = NSMenuItem(title: Localization.string(.searchJumpUpStyle, default: "Jump Up"), action: nil, keyEquivalent: "")
        let jumpUpMenu = NSMenu(title: Localization.string(.searchJumpUpStyle, default: "Jump Up"))
        jumpUpItem.submenu = jumpUpMenu
        searchMenu.addItem(jumpUpItem)
        for (style, label) in styles {
            jumpUpMenu.addItem(withTitle: label, action: #selector(EditorWindowController.goToPreviousStyle(_:)), keyEquivalent: "").representedObject = style
        }

        // Jump Down (Next)
        let jumpDownItem = NSMenuItem(title: Localization.string(.searchJumpDownStyle, default: "Jump Down"), action: nil, keyEquivalent: "")
        let jumpDownMenu = NSMenu(title: Localization.string(.searchJumpDownStyle, default: "Jump Down"))
        jumpDownItem.submenu = jumpDownMenu
        searchMenu.addItem(jumpDownItem)
        for (style, label) in styles {
            jumpDownMenu.addItem(withTitle: label, action: #selector(EditorWindowController.goToNextStyle(_:)), keyEquivalent: "").representedObject = style
        }

        // Copy Styled Text
        let copyStyledItem = NSMenuItem(title: Localization.string(.searchCopyStyledText, default: "Copy Styled Text"), action: nil, keyEquivalent: "")
        let copyStyledMenu = NSMenu(title: Localization.string(.searchCopyStyledText, default: "Copy Styled Text"))
        copyStyledItem.submenu = copyStyledMenu
        searchMenu.addItem(copyStyledItem)
        for (style, label) in styles {
            copyStyledMenu.addItem(withTitle: label, action: #selector(EditorWindowController.copyStyledText(_:)), keyEquivalent: "").representedObject = style
        }
        copyStyledMenu.addItem(withTitle: Localization.string(.searchCopyAllStyles, default: "Copy All Styled Text"), action: #selector(EditorWindowController.copyAllStyledText(_:)), keyEquivalent: "")
        copyStyledMenu.addItem(withTitle: Localization.string(.searchDeleteLinesNotContainingStyle, default: "Delete Lines Not Containing Style"), action: #selector(EditorWindowController.deleteLinesNotContainingStyle(_:)), keyEquivalent: "")

        // Found Results navigation
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(
            withTitle: Localization.string(.searchFocusFoundResults, default: "Focus on Found Results"),
            action: #selector(EditorWindowController.focusFoundResults(_:)),
            keyEquivalent: ""
        )
        searchMenu.addItem(
            withTitle: Localization.string(.searchGoToNextFound, default: "Go to Next Found"),
            action: #selector(EditorWindowController.goToNextFound(_:)),
            keyEquivalent: ""
        )
        searchMenu.addItem(
            withTitle: Localization.string(.searchGoToPrevFound, default: "Go to Previous Found"),
            action: #selector(EditorWindowController.goToPreviousFound(_:)),
            keyEquivalent: ""
        )

        // Change History submenu
        searchMenu.addItem(NSMenuItem.separator())
        let changeHistoryItem = NSMenuItem(title: Localization.string(.searchChangeHistoryMenu, default: "Change History"), action: nil, keyEquivalent: "")
        let changeHistoryMenu = NSMenu(title: Localization.string(.searchChangeHistoryMenu, default: "Change History"))
        changeHistoryItem.submenu = changeHistoryMenu
        searchMenu.addItem(changeHistoryItem)
        changeHistoryMenu.addItem(withTitle: Localization.string(.searchChangedNext, default: "Go to Next Change"), action: #selector(EditorWindowController.goToNextChangedLine(_:)), keyEquivalent: "")
        changeHistoryMenu.addItem(withTitle: Localization.string(.searchChangedPrevious, default: "Go to Previous Change"), action: #selector(EditorWindowController.goToPreviousChangedLine(_:)), keyEquivalent: "")
        changeHistoryMenu.addItem(withTitle: Localization.string(.searchClearChangeHistory, default: "Clear Change History"), action: #selector(EditorWindowController.clearChangeHistory(_:)), keyEquivalent: "")

        let toolsMenuItem = NSMenuItem()
        mainMenu.addItem(toolsMenuItem)
        let toolsMenu = NSMenu(title: Localization.string(.menuTools, default: "Tools"))
        toolsMenuItem.submenu = toolsMenu
        installHashSubmenu(
            in: toolsMenu,
            title: Localization.string(.toolsMD5, default: "MD5"),
            showAction: #selector(AppDelegate.showMD5Generator(_:)),
            generateFromFilesAction: #selector(AppDelegate.generateMD5FromFiles(_:)),
            selectionAction: #selector(EditorWindowController.generateMD5SelectionIntoClipboard(_:)),
            delegate: delegate
        )
        installHashSubmenu(
            in: toolsMenu,
            title: Localization.string(.toolsSHA1, default: "SHA-1"),
            showAction: #selector(AppDelegate.showSHA1Generator(_:)),
            generateFromFilesAction: #selector(AppDelegate.generateSHA1FromFiles(_:)),
            selectionAction: #selector(EditorWindowController.generateSHA1SelectionIntoClipboard(_:)),
            delegate: delegate
        )
        installHashSubmenu(
            in: toolsMenu,
            title: Localization.string(.toolsSHA256, default: "SHA-256"),
            showAction: #selector(AppDelegate.showSHA256Generator(_:)),
            generateFromFilesAction: #selector(AppDelegate.generateSHA256FromFiles(_:)),
            selectionAction: #selector(EditorWindowController.generateSHA256SelectionIntoClipboard(_:)),
            delegate: delegate
        )
        installHashSubmenu(
            in: toolsMenu,
            title: Localization.string(.toolsSHA512, default: "SHA-512"),
            showAction: #selector(AppDelegate.showSHA512Generator(_:)),
            generateFromFilesAction: #selector(AppDelegate.generateSHA512FromFiles(_:)),
            selectionAction: #selector(EditorWindowController.generateSHA512SelectionIntoClipboard(_:)),
            delegate: delegate
        )

        let macroMenuItem = NSMenuItem()
        mainMenu.addItem(macroMenuItem)
        let macroMenu = NSMenu(title: Localization.string(.macroMenu, default: "Macro"))
        macroMenuItem.submenu = macroMenu
        macroMenu.addItem(
            withTitle: Localization.string(.macroStartRecording, default: "Start Recording"),
            action: #selector(EditorWindowController.startMacroRecording(_:)),
            keyEquivalent: ""
        )
        macroMenu.addItem(
            withTitle: Localization.string(.macroStopRecording, default: "Stop Recording"),
            action: #selector(EditorWindowController.stopMacroRecording(_:)),
            keyEquivalent: ""
        )
        macroMenu.addItem(NSMenuItem.separator())
        let playMacro = macroMenu.addItem(
            withTitle: Localization.string(.macroPlayLast, default: "Play Last Macro"),
            action: #selector(EditorWindowController.playLastMacro(_:)),
            keyEquivalent: "r"
        )
        playMacro.keyEquivalentModifierMask = [.command, .option]
        macroMenu.addItem(
            withTitle: Localization.string(.macroSaveLastAs, default: "Save Last Macro..."),
            action: #selector(EditorWindowController.saveLastMacroAsNamedMacro(_:)),
            keyEquivalent: ""
        )
        macroMenu.addItem(
            withTitle: Localization.string(.macroPlaySaved, default: "Play Saved Macro..."),
            action: #selector(EditorWindowController.playNamedMacro(_:)),
            keyEquivalent: ""
        )
        macroMenu.addItem(
            withTitle: Localization.string(.macroDeleteSaved, default: "Delete Saved Macro..."),
            action: #selector(EditorWindowController.deleteNamedMacro(_:)),
            keyEquivalent: ""
        )
        macroMenu.addItem(
            withTitle: Localization.string(.macroClearLast, default: "Clear Last Macro"),
            action: #selector(EditorWindowController.clearLastMacro(_:)),
            keyEquivalent: ""
        )
        macroMenu.addItem(
            withTitle: Localization.string(.macroRunMultipleTimes, default: "Run a Macro Multiple Times..."),
            action: #selector(EditorWindowController.runMacroMultipleTimes(_:)),
            keyEquivalent: ""
        )
        installedMacroMenu = macroMenu

        let runMenuItem = NSMenuItem()
        mainMenu.addItem(runMenuItem)
        let runMenu = NSMenu(title: Localization.string(.menuRun, default: "Run"))
        runMenuItem.submenu = runMenu
        runMenu.addItem(
            withTitle: Localization.string(.runMenuCommand, default: "Run..."),
            action: #selector(AppDelegate.showRunCommandPanel(_:)),
            keyEquivalent: ""
        ).target = delegate
        installedRunMenu = runMenu

        let pluginsMenuItem = NSMenuItem()
        mainMenu.addItem(pluginsMenuItem)
        let pluginsMenu = NSMenu(title: Localization.string(.pluginsMenu, default: "Plugins"))
        pluginsMenuItem.submenu = pluginsMenu
        pluginsMenu.addItem(
            withTitle: Localization.string(.pluginAdmin, default: "Plugin Admin..."),
            action: #selector(AppDelegate.showPluginAdmin(_:)),
            keyEquivalent: ""
        ).target = delegate
        pluginsMenu.addItem(
            withTitle: Localization.string(.pluginsOpenFolder, default: "Open Plugins Folder"),
            action: #selector(AppDelegate.openPluginsFolder(_:)),
            keyEquivalent: ""
        ).target = delegate
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: Localization.string(.viewMenu, default: "View"))
        viewMenuItem.submenu = viewMenu

        // --- Presentation modes (top, matching upstream order) ---
        viewMenu.addItem(withTitle: Localization.string(.viewAlwaysOnTop, default: "Always on Top"), action: #selector(EditorWindowController.toggleAlwaysOnTop(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewToggleFullScreen, default: "Toggle Full Screen Mode"), action: #selector(EditorWindowController.toggleFullScreenMode(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewPostIt, default: "Post-It"), action: #selector(EditorWindowController.togglePostItMode(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewDistractionFree, default: "Distraction Free Mode"), action: #selector(EditorWindowController.toggleDistractionFreeMode(_:)), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())

        // --- View Current File in Browser ---
        // Upstream offers specific browsers (Firefox/Chrome/Edge/IE); on macOS
        // we surface a "Launch in Browser ▸" submenu with the default browser
        // plus each installed browser discovered by bundle identifier.
        let launchInBrowserItem = NSMenuItem(
            title: Localization.string(.viewLaunchInBrowser, default: "Launch in Browser"),
            action: nil,
            keyEquivalent: ""
        )
        let launchInBrowserMenu = NSMenu(title: launchInBrowserItem.title)
        launchInBrowserItem.submenu = launchInBrowserMenu
        viewMenu.addItem(launchInBrowserItem)
        populateLaunchInBrowserMenu(launchInBrowserMenu)
        viewMenu.addItem(NSMenuItem.separator())

        // --- Show Symbol submenu ---
        let showSymbolItem = NSMenuItem(title: Localization.string(.viewShowSymbolMenu, default: "Show Symbol"), action: nil, keyEquivalent: "")
        let showSymbolMenu = NSMenu(title: Localization.string(.viewShowSymbolMenu, default: "Show Symbol"))
        showSymbolItem.submenu = showSymbolMenu
        for spec in showSymbolMenuItemSpecs {
            if spec.isSeparator {
                showSymbolMenu.addItem(NSMenuItem.separator())
                continue
            }
            guard let key = spec.localizationKey, let action = spec.action else { continue }
            showSymbolMenu.addItem(
                withTitle: Localization.string(key, default: spec.defaultTitle),
                action: action,
                keyEquivalent: ""
            )
        }
        viewMenu.addItem(showSymbolItem)

        // --- Zoom submenu ---
        let zoomItem = NSMenuItem(title: Localization.string(.viewZoomMenu, default: "Zoom"), action: nil, keyEquivalent: "")
        let zoomMenu = NSMenu(title: Localization.string(.viewZoomMenu, default: "Zoom"))
        zoomItem.submenu = zoomMenu
        zoomMenu.addItem(withTitle: Localization.string(.viewBiggerText, default: "Zoom In"), action: #selector(EditorWindowController.increaseFontSize(_:)), keyEquivalent: "+")
        zoomMenu.addItem(withTitle: Localization.string(.viewSmallerText, default: "Zoom Out"), action: #selector(EditorWindowController.decreaseFontSize(_:)), keyEquivalent: "-")
        zoomMenu.addItem(withTitle: Localization.string(.viewZoomRestore, default: "Restore Default Zoom"), action: #selector(EditorWindowController.zoomRestore(_:)), keyEquivalent: "0").keyEquivalentModifierMask = [.command]
        zoomMenu.addItem(NSMenuItem.separator())
        zoomMenu.addItem(withTitle: Localization.string(.viewZoomSync, default: "Sync Zoom to All Windows"), action: #selector(AppDelegate.syncZoomToAll(_:)), keyEquivalent: "").target = delegate
        viewMenu.addItem(zoomItem)
        viewMenu.addItem(NSMenuItem.separator())

        // --- Editor display toggles ---
        viewMenu.addItem(withTitle: Localization.string(.viewToggleLineWrap, default: "Toggle Line Wrap"), action: #selector(EditorWindowController.toggleLineWrap(_:)), keyEquivalent: "l")
        viewMenu.addItem(withTitle: Localization.string(.viewHighlightCurrentLine, default: "Highlight Current Line"), action: #selector(EditorWindowController.toggleCurrentLineHighlight(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewShowLineNumberMargin, default: "Show Line Number Margin"), action: #selector(EditorWindowController.toggleLineNumberMargin(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewShowBookmarkMargin, default: "Show Bookmark Margin"), action: #selector(EditorWindowController.toggleBookmarkMargin(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewShowEdgeLine, default: "Show Edge Line"), action: #selector(EditorWindowController.toggleEdgeLine(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewChangeHistory, default: "Change History"), action: #selector(EditorWindowController.toggleChangeHistory(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewSmartHighlight, default: "Smart Highlight"), action: #selector(EditorWindowController.toggleSmartHighlight(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewXmlTagMatch, default: "Highlight Matching XML Tags"), action: #selector(EditorWindowController.toggleXmlTagMatch(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewAutoPair, default: "Auto-Insert Matching Pairs"), action: #selector(EditorWindowController.toggleAutoPair(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewClickableLinks, default: "Clickable Links"), action: #selector(EditorWindowController.toggleClickableLinks(_:)), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())

        // --- Folding submenu ---
        let foldingMenuItem = NSMenuItem(title: Localization.string(.foldingMenu, default: "Folding"), action: nil, keyEquivalent: "")
        let foldingMenu = NSMenu(title: Localization.string(.foldingMenu, default: "Folding"))
        foldingMenuItem.submenu = foldingMenu
        viewMenu.addItem(foldingMenuItem)
        foldingMenu.addItem(withTitle: Localization.string(.foldingToggle, default: "Toggle Fold"), action: #selector(EditorWindowController.toggleFoldAtCurrentLine(_:)), keyEquivalent: "")
        foldingMenu.addItem(NSMenuItem.separator())
        foldingMenu.addItem(withTitle: Localization.string(.foldingFoldAll, default: "Fold All"), action: #selector(EditorWindowController.foldAll(_:)), keyEquivalent: "")
        foldingMenu.addItem(withTitle: Localization.string(.foldingUnfoldAll, default: "Unfold All"), action: #selector(EditorWindowController.unfoldAll(_:)), keyEquivalent: "")
        foldingMenu.addItem(NSMenuItem.separator())
        foldingMenu.addItem(withTitle: Localization.string(.foldingFoldCurrentLevel, default: "Fold Current Level"), action: #selector(EditorWindowController.foldCurrentLevel(_:)), keyEquivalent: "")
        foldingMenu.addItem(withTitle: Localization.string(.foldingUnfoldCurrentLevel, default: "Unfold Current Level"), action: #selector(EditorWindowController.unfoldCurrentLevel(_:)), keyEquivalent: "")
        foldingMenu.addItem(NSMenuItem.separator())
        let foldLevelMenuItem = NSMenuItem(title: Localization.string(.foldingFoldLevel, default: "Fold Level"), action: nil, keyEquivalent: "")
        let foldLevelMenu = NSMenu(title: Localization.string(.foldingFoldLevel, default: "Fold Level"))
        foldLevelMenuItem.submenu = foldLevelMenu
        foldingMenu.addItem(foldLevelMenuItem)
        let unfoldLevelMenuItem = NSMenuItem(title: Localization.string(.foldingUnfoldLevel, default: "Unfold Level"), action: nil, keyEquivalent: "")
        let unfoldLevelMenu = NSMenu(title: Localization.string(.foldingUnfoldLevel, default: "Unfold Level"))
        unfoldLevelMenuItem.submenu = unfoldLevelMenu
        foldingMenu.addItem(unfoldLevelMenuItem)
        let foldingLevelKeys: [Localization.Key] = [.foldingLevel1, .foldingLevel2, .foldingLevel3, .foldingLevel4, .foldingLevel5, .foldingLevel6, .foldingLevel7, .foldingLevel8]
        let foldingLevelDefaults = ["Level 1", "Level 2", "Level 3", "Level 4", "Level 5", "Level 6", "Level 7", "Level 8"]
        for (index, (key, defaultTitle)) in zip(foldingLevelKeys, foldingLevelDefaults).enumerated() {
            let level = index + 1
            let foldItem = NSMenuItem(title: Localization.string(key, default: defaultTitle), action: #selector(EditorWindowController.foldAtLevel(_:)), keyEquivalent: "")
            foldItem.representedObject = level
            foldLevelMenu.addItem(foldItem)
            let unfoldItem = NSMenuItem(title: Localization.string(key, default: defaultTitle), action: #selector(EditorWindowController.unfoldAtLevel(_:)), keyEquivalent: "")
            unfoldItem.representedObject = level
            unfoldLevelMenu.addItem(unfoldItem)
        }
        viewMenu.addItem(withTitle: Localization.string(.viewHideLines, default: "Hide Lines"), action: #selector(EditorWindowController.hideSelectedLines(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewShowAllHiddenLines, default: "Show All Hidden Lines"), action: #selector(EditorWindowController.showAllHiddenLines(_:)), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())

        // --- Panels ---
        viewMenu.addItem(withTitle: Localization.string(.viewDocumentList, default: "Document List..."), action: #selector(AppDelegate.showDocumentList(_:)), keyEquivalent: "").target = delegate
        viewMenu.addItem(withTitle: Localization.string(.viewDocumentMap, default: "Document Map..."), action: #selector(EditorWindowController.showDocumentMap(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewTaskList, default: "Task List..."), action: #selector(EditorWindowController.showTaskList(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewFileBrowser, default: "File Browser..."), action: #selector(AppDelegate.showFileBrowser(_:)), keyEquivalent: "").target = delegate
        viewMenu.addItem(withTitle: Localization.string(.viewLocateCurrentFile, default: "Locate Current File"), action: #selector(AppDelegate.locateCurrentFile(_:)), keyEquivalent: "").target = delegate
        // Project Panel 2 and 3 (additional workspace panels)
        viewMenu.addItem(
            withTitle: Localization.string(.viewProjectPanel2, default: "Project Panel 2..."),
            action: #selector(AppDelegate.showProjectPanel2(_:)),
            keyEquivalent: ""
        ).target = delegate
        viewMenu.addItem(
            withTitle: Localization.string(.viewProjectPanel3, default: "Project Panel 3..."),
            action: #selector(AppDelegate.showProjectPanel3(_:)),
            keyEquivalent: ""
        ).target = delegate
        viewMenu.addItem(withTitle: Localization.string(.viewFunctionList, default: "Function List..."), action: #selector(EditorWindowController.showFunctionList(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewExportFunctionList, default: "Export Function List..."), action: #selector(EditorWindowController.exportFunctionList(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewFoundResults, default: "Found Results..."), action: #selector(AppDelegate.showFoundResultsPanel(_:)), keyEquivalent: "").target = delegate
        viewMenu.addItem(withTitle: Localization.string(.viewDocumentStatistics, default: "Document Statistics..."), action: #selector(EditorWindowController.showDocumentStatistics(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewMonitoring, default: "Monitoring (tail -f)"), action: #selector(EditorWindowController.toggleMonitoringMode(_:)), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())

        // --- Dual view (clone) ---
        viewMenu.addItem(
            withTitle: Localization.string(.viewMoveToOtherView, default: "Move to Other View"),
            action: #selector(AppDelegate.moveToOtherView(_:)),
            keyEquivalent: ""
        ).target = delegate
        viewMenu.addItem(
            withTitle: Localization.string(.viewCloneToOtherView, default: "Clone to Other View"),
            action: #selector(EditorWindowController.toggleCloneToOtherView(_:)),
            keyEquivalent: ""
        )
        let focusOtherViewItem = viewMenu.addItem(
            withTitle: Localization.string(.viewFocusOtherView, default: "Focus on Another View"),
            action: #selector(EditorWindowController.focusOtherView(_:)),
            keyEquivalent: String(UnicodeScalar(UInt32(NSF8FunctionKey))!)
        )
        focusOtherViewItem.keyEquivalentModifierMask = []
        viewMenu.addItem(NSMenuItem.separator())

        // --- Scroll sync ---
        viewMenu.addItem(
            withTitle: Localization.string(.viewSyncVerticalScroll, default: "Synchronize Vertical Scrolling"),
            action: #selector(EditorWindowController.toggleSynchronizedVerticalScrolling(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(
            withTitle: Localization.string(.viewSyncHorizontalScroll, default: "Synchronize Horizontal Scrolling"),
            action: #selector(EditorWindowController.toggleSynchronizedHorizontalScrolling(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(NSMenuItem.separator())

        // --- Window chrome ---
        viewMenu.addItem(withTitle: Localization.string(.viewShowTabBar, default: "Show Tab Bar"), action: #selector(EditorWindowController.toggleTabBarVisibility(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewShowToolbar, default: "Show Toolbar"), action: #selector(EditorWindowController.toggleToolbarVisibility(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: Localization.string(.viewToggleStatusBar, default: "Show Status Bar"), action: #selector(EditorWindowController.toggleStatusBar(_:)), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())

        // --- Theme ---
        let themeMenuItem = NSMenuItem(title: Localization.string(.themeMenu, default: "Theme"), action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: Localization.string(.themeMenu, default: "Theme"))
        themeMenuItem.submenu = themeMenu
        viewMenu.addItem(themeMenuItem)
        installedThemeMenu = themeMenu
        populateThemes(menu: themeMenu, delegate: delegate, themeCatalog: themeCatalog, selectedThemeName: selectedThemeName)

        let workspaceMenuItem = NSMenuItem()
        mainMenu.addItem(workspaceMenuItem)
        let workspaceMenu = NSMenu(title: Localization.string(.workspaceMenu, default: "Workspace"))
        workspaceMenuItem.submenu = workspaceMenu
        workspaceMenu.addItem(
            withTitle: Localization.string(.workspaceOpenFile, default: "Open Workspace File..."),
            action: #selector(AppDelegate.openWorkspaceFile(_:)),
            keyEquivalent: ""
        ).target = delegate
        workspaceMenu.addItem(
            withTitle: Localization.string(.workspaceOpenFolder, default: "Open Folder as Workspace..."),
            action: #selector(AppDelegate.openFolderAsWorkspace(_:)),
            keyEquivalent: ""
        ).target = delegate
        workspaceMenu.addItem(NSMenuItem.separator())
        workspaceMenu.addItem(
            withTitle: Localization.string(.workspaceSave, default: "Save Workspace"),
            action: #selector(AppDelegate.saveWorkspace(_:)),
            keyEquivalent: ""
        ).target = delegate
        workspaceMenu.addItem(
            withTitle: Localization.string(.workspaceSaveAs, default: "Save Workspace As..."),
            action: #selector(AppDelegate.saveWorkspaceAs(_:)),
            keyEquivalent: ""
        ).target = delegate
        workspaceMenu.addItem(NSMenuItem.separator())
        workspaceMenu.addItem(
            withTitle: Localization.string(.workspaceClose, default: "Close Workspace"),
            action: #selector(AppDelegate.closeWorkspace(_:)),
            keyEquivalent: ""
        ).target = delegate

        let languageMenuItem = NSMenuItem()
        mainMenu.addItem(languageMenuItem)
        let languageMenu = NSMenu(title: Localization.string(.languageMenu, default: "Language"))
        languageMenuItem.submenu = languageMenu
        installedLanguageMenu = languageMenu
        populateLanguages(menu: languageMenu, delegate: delegate, catalog: catalog)

        let settingsMenuItem = NSMenuItem()
        mainMenu.addItem(settingsMenuItem)
        let settingsMenu = NSMenu(title: Localization.string(.settingsMenu, default: "Settings"))
        settingsMenuItem.submenu = settingsMenu
        installSettingsMenuItems(in: settingsMenu, delegate: delegate)

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: Localization.string(.windowMenu, default: "Window"))
        windowMenuItem.submenu = windowMenu
        installedWindowMenu = windowMenu
        let previousTab = windowMenu.addItem(
            withTitle: Localization.string(.windowShowPreviousTab, default: "Show Previous Tab"),
            action: #selector(NSWindow.selectPreviousTab(_:)),
            keyEquivalent: "["
        )
        previousTab.keyEquivalentModifierMask = [.command, .shift]
        let nextTab = windowMenu.addItem(
            withTitle: Localization.string(.windowShowNextTab, default: "Show Next Tab"),
            action: #selector(NSWindow.selectNextTab(_:)),
            keyEquivalent: "]"
        )
        nextTab.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(
            withTitle: Localization.string(.windowMoveTabToNewWindow, default: "Move Tab to New Window"),
            action: #selector(NSWindow.moveTabToNewWindow(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(
            withTitle: Localization.string(.windowOpenInNewInstance, default: "Open in New Instance"),
            action: #selector(AppDelegate.openInNewInstance(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowMoveToNewInstance, default: "Move to New Instance"),
            action: #selector(AppDelegate.moveToNewInstance(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: Localization.string(.windowMergeAllWindows, default: "Merge All Windows"),
            action: #selector(NSWindow.mergeAllWindows(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(NSMenuItem.separator())

        // Tab navigation
        windowMenu.addItem(
            withTitle: Localization.string(.windowNextTab, default: "Next Tab"),
            action: #selector(AppDelegate.activateNextTab(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowPreviousTab, default: "Previous Tab"),
            action: #selector(AppDelegate.activatePreviousTab(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowFirstTab, default: "First Tab"),
            action: #selector(AppDelegate.activateFirstTab(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowLastTab, default: "Last Tab"),
            action: #selector(AppDelegate.activateLastTab(_:)),
            keyEquivalent: ""
        ).target = delegate
        // 1st-9th tab
        for i in 1...9 {
            let tabItem = windowMenu.addItem(
                withTitle: "\(i)\u{00B9}\(i == 1 ? "st" : i == 2 ? "nd" : i == 3 ? "rd" : "th") Tab",
                action: #selector(AppDelegate.activateTabByIndex(_:)),
                keyEquivalent: "\(i)"
            )
            tabItem.keyEquivalentModifierMask = [.command]
            tabItem.target = delegate
            tabItem.representedObject = i - 1
        }

        windowMenu.addItem(NSMenuItem.separator())

        // Tab reorder
        windowMenu.addItem(
            withTitle: Localization.string(.windowMoveTabForward, default: "Move Tab Forward"),
            action: #selector(AppDelegate.moveTabForward(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowMoveTabBackward, default: "Move Tab Backward"),
            action: #selector(AppDelegate.moveTabBackward(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowMoveTabToStart, default: "Move Tab to Start"),
            action: #selector(AppDelegate.moveTabToStart(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(
            withTitle: Localization.string(.windowMoveTabToEnd, default: "Move Tab to End"),
            action: #selector(AppDelegate.moveTabToEnd(_:)),
            keyEquivalent: ""
        ).target = delegate

        windowMenu.addItem(NSMenuItem.separator())

        let windowList = NSMenuItem(
            title: Localization.string(.windowList, default: "Window List"),
            action: nil,
            keyEquivalent: ""
        )
        let windowListMenu = NSMenu(title: Localization.string(.windowList, default: "Window List"))
        windowList.submenu = windowListMenu
        windowMenu.addItem(windowList)
        installedWindowListMenu = windowListMenu

        let copyAllDocumentNames = windowMenu.addItem(
            withTitle: Localization.string(.windowCopyAllDocumentNames, default: "Copy All Document Names"),
            action: #selector(AppDelegate.copyAllDocumentNames(_:)),
            keyEquivalent: ""
        )
        copyAllDocumentNames.target = delegate

        let copyAllDocumentPaths = windowMenu.addItem(
            withTitle: Localization.string(.windowCopyAllDocumentPaths, default: "Copy All Document Paths"),
            action: #selector(AppDelegate.copyAllDocumentPaths(_:)),
            keyEquivalent: ""
        )
        copyAllDocumentPaths.target = delegate

        windowMenu.addItem(NSMenuItem.separator())

        let windowSort = NSMenuItem(
            title: Localization.string(.windowSortWindows, default: "Sort Windows"),
            action: nil,
            keyEquivalent: ""
        )
        let windowSortMenu = NSMenu(title: Localization.string(.windowSortWindows, default: "Sort Windows"))
        for (key, mode) in [
            (Localization.Key.windowSortWindowsNone, AppMenu.WindowSortMode.none),
            (Localization.Key.windowSortWindowsByNameAsc, AppMenu.WindowSortMode.nameAsc),
            (Localization.Key.windowSortWindowsByNameDesc, AppMenu.WindowSortMode.nameDesc),
            (Localization.Key.windowSortWindowsByPathAsc, AppMenu.WindowSortMode.pathAsc),
            (Localization.Key.windowSortWindowsByPathDesc, AppMenu.WindowSortMode.pathDesc),
            (Localization.Key.windowSortWindowsByTypeAsc, AppMenu.WindowSortMode.typeAsc),
            (Localization.Key.windowSortWindowsByTypeDesc, AppMenu.WindowSortMode.typeDesc),
            (Localization.Key.windowSortWindowsBySizeAsc, AppMenu.WindowSortMode.sizeAsc),
            (Localization.Key.windowSortWindowsBySizeDesc, AppMenu.WindowSortMode.sizeDesc),
            (Localization.Key.windowSortWindowsByDateAsc, AppMenu.WindowSortMode.dateAsc),
            (Localization.Key.windowSortWindowsByDateDesc, AppMenu.WindowSortMode.dateDesc),
            (Localization.Key.windowSortWindowsByContentLengthAsc, AppMenu.WindowSortMode.contentLengthAsc),
            (Localization.Key.windowSortWindowsByContentLengthDesc, AppMenu.WindowSortMode.contentLengthDesc)
        ] {
            let item = NSMenuItem(
                title: Localization.string(
                    key,
                    default: windowSortMenuDefaultTitle(for: mode)
                ),
                action: #selector(AppDelegate.setWindowSort(_:)),
                keyEquivalent: ""
            )
            item.target = delegate
            item.tag = mode.rawValue
            windowSortMenu.addItem(item)
        }
        windowSort.submenu = windowSortMenu
        windowMenu.addItem(windowSort)
        installedWindowSortMenu = windowSortMenu

        let pinTab = windowMenu.addItem(
            withTitle: Localization.string(.windowPinTab, default: "Pin Tab"),
            action: #selector(AppDelegate.toggleWindowTabPin(_:)),
            keyEquivalent: ""
        )
        pinTab.target = delegate
        installedWindowPinMenu = pinTab

        let tabColor = NSMenuItem(
            title: Localization.string(.windowTabColor, default: "Tab Color"),
            action: nil,
            keyEquivalent: ""
        )
        let tabColorMenu = NSMenu(title: Localization.string(.windowTabColor, default: "Tab Color"))
        let tabColorItems: [(Localization.Key, Int)] = [
            (.windowTabColorNone, 0),
            (.windowTabColor1, 1),
            (.windowTabColor2, 2),
            (.windowTabColor3, 3),
            (.windowTabColor4, 4),
            (.windowTabColor5, 5),
            (.windowTabColor6, 6)
        ]
        for (key, tag) in tabColorItems {
            let item = NSMenuItem(
                title: Localization.string(
                    key,
                    default: windowTabColorDefaultTitle(for: tag)
                ),
                action: #selector(AppDelegate.setWindowTabColor(_:)),
                keyEquivalent: ""
            )
            item.target = delegate
            item.tag = tag
            tabColorMenu.addItem(item)
        }
        tabColor.submenu = tabColorMenu
        windowMenu.addItem(tabColor)
        installedWindowTabColorMenu = tabColorMenu

        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: Localization.string(.windowWindowsDialog, default: "Windows..."),
            action: #selector(AppDelegate.showWindowsDialog(_:)),
            keyEquivalent: ""
        ).target = delegate
        windowMenu.addItem(withTitle: Localization.string(.windowMinimize, default: "Minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: Localization.string(.windowBringAllToFront, default: "Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "?")
        helpMenuItem.submenu = helpMenu
        helpMenu.addItem(
            withTitle: Localization.string(.helpCommandLineArguments, default: "Command Line Arguments..."),
            action: #selector(AppDelegate.showCommandLineArguments(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(
            withTitle: Localization.string(.helpHome, default: "Notepad++ Home"),
            action: #selector(AppDelegate.openHomePage(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(
            withTitle: Localization.string(.helpProjectPage, default: "Notepad++ Project Page"),
            action: #selector(AppDelegate.openProjectPage(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(
            withTitle: Localization.string(.helpOnlineUserManual, default: "Notepad++ Online User Manual"),
            action: #selector(AppDelegate.openOnlineUserManual(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(
            withTitle: Localization.string(.helpForum, default: "Notepad++ Community (Forum)"),
            action: #selector(AppDelegate.openForum(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(
            withTitle: Localization.string(.helpUpdate, default: "Update Notepad++"),
            action: #selector(AppDelegate.checkForUpdates(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(
            withTitle: Localization.string(.helpSetUpdaterProxy, default: "Set Updater Proxy..."),
            action: #selector(AppDelegate.setUpdaterProxy(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(
            withTitle: Localization.string(.helpDebugInfo, default: "Debug Info..."),
            action: #selector(AppDelegate.showDebugInfo(_:)),
            keyEquivalent: ""
        ).target = delegate
        helpMenu.addItem(
            withTitle: Localization.string(.helpAbout, default: "About Notepad++ Mac"),
            action: #selector(AppDelegate.showAbout(_:)),
            keyEquivalent: ""
        ).target = delegate
        NSApp.helpMenu = helpMenu

        refreshWindowMenu(
            windows: [],
            activeIdentity: nil,
            sortMode: .none
        )
        applyUpstreamTopLevelMenuOrder(
            mainMenu: mainMenu,
            appMenuItem: appMenuItem,
            orderedItems: [
                fileMenuItem,
                editMenuItem,
                searchMenuItem,
                viewMenuItem,
                encodingMenuItem,
                languageMenuItem,
                settingsMenuItem,
                toolsMenuItem,
                macroMenuItem,
                runMenuItem,
                pluginsMenuItem,
                windowMenuItem,
                helpMenuItem
            ]
        )
    }

    @MainActor
    /// Populates an encoding menu in upstream Notepad++ style: Unicode options
    /// at the top level, then region-grouped legacy encodings under a
    /// "Character sets" submenu.
    private static func populateEncodingMenu(_ menu: NSMenu, action: Selector, excludeASCII: Bool = false) {
        for option in TextEncodingOption.unicodeMenuOptions where !(excludeASCII && option.encoding == .ascii) {
            let item = NSMenuItem(title: option.displayName, action: action, keyEquivalent: "")
            item.representedObject = option.rawValue
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let charSetsTitle = Localization.string(.encodingCharacterSetsMenu, default: "Character sets")
        let charSetsItem = NSMenuItem(title: charSetsTitle, action: nil, keyEquivalent: "")
        let charSetsMenu = NSMenu(title: charSetsTitle)
        charSetsItem.submenu = charSetsMenu
        for section in TextEncodingOption.characterSetMenuSections {
            let regionItem = NSMenuItem(title: section.name, action: nil, keyEquivalent: "")
            let regionMenu = NSMenu(title: section.name)
            regionItem.submenu = regionMenu
            for option in section.options {
                let item = NSMenuItem(title: option.displayName, action: action, keyEquivalent: "")
                item.representedObject = option.rawValue
                regionMenu.addItem(item)
            }
            charSetsMenu.addItem(regionItem)
        }
        menu.addItem(charSetsItem)
    }

    // Upstream Settings menu: Preferences... / Style Configurator... /
    // Shortcut Mapper... / ─ / Import ▸ / ─ / Edit Popup ContextMenu
    private static func installSettingsMenuItems(in menu: NSMenu, delegate: AppDelegate) {
        menu.addItem(
            withTitle: Localization.string(.appPreferences, default: "Preferences..."),
            action: #selector(AppDelegate.showPreferences(_:)),
            keyEquivalent: ","
        ).target = delegate
        menu.addItem(
            withTitle: Localization.string(.appStyleConfigurator, default: "Style Configurator..."),
            action: #selector(AppDelegate.showStyleConfigurator(_:)),
            keyEquivalent: ""
        ).target = delegate
        menu.addItem(
            withTitle: Localization.string(.appShortcutMapper, default: "Shortcut Mapper..."),
            action: #selector(AppDelegate.showShortcutMapper(_:)),
            keyEquivalent: ""
        ).target = delegate
        menu.addItem(NSMenuItem.separator())

        let importItem = NSMenuItem()
        importItem.title = Localization.string(.settingsImport, default: "Import")
        let importMenu = NSMenu(title: importItem.title)
        importItem.submenu = importMenu
        menu.addItem(importItem)
        importMenu.addItem(
            withTitle: Localization.string(.pluginsImport, default: "Import Plugin(s)..."),
            action: #selector(AppDelegate.importPlugin(_:)),
            keyEquivalent: ""
        ).target = delegate
        importMenu.addItem(
            withTitle: Localization.string(.settingsImportTheme, default: "Import Style Theme(s)..."),
            action: #selector(AppDelegate.importStyleTheme(_:)),
            keyEquivalent: ""
        ).target = delegate

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: Localization.string(.appEditContextMenu, default: "Edit Popup ContextMenu"),
            action: #selector(AppDelegate.editContextMenuXML(_:)),
            keyEquivalent: ""
        ).target = delegate
    }

    @MainActor
    static func applyUpstreamTopLevelMenuOrder(
        mainMenu: NSMenu,
        appMenuItem: NSMenuItem,
        orderedItems: [NSMenuItem]
    ) {
        for item in mainMenu.items.reversed() where item !== appMenuItem {
            mainMenu.removeItem(item)
        }

        for item in orderedItems {
            mainMenu.addItem(item)
        }
    }

    @MainActor
    static func refreshThemes(themeCatalog: ThemeCatalog, selectedThemeName: String?) {
        guard let installedThemeMenu, let installedDelegate else { return }

        installedThemeMenu.removeAllItems()
        populateThemes(
            menu: installedThemeMenu,
            delegate: installedDelegate,
            themeCatalog: themeCatalog,
            selectedThemeName: selectedThemeName
        )
    }

    @MainActor
    static func refreshRecentFiles(
        maxCount: Int = 20,
        showFullPath: Bool = false,
        customDisplayLength: Int = 0,
        inSubmenu: Bool = true
    ) {
        guard let installedOpenRecentMenu, let installedDelegate else { return }

        // Remove any previously inserted inline items from File menu
        installedFileMenu?.items
            .filter { $0.tag == inlineRecentTag }
            .forEach { installedFileMenu?.removeItem($0) }

        installedOpenRecentItem?.isHidden = !inSubmenu
        installedOpenRecentMenu.removeAllItems()

        let recentURLs = NSDocumentController.shared.recentDocumentURLs
            .filter(\.isFileURL)

        func makeTitle(for url: URL) -> String {
            let fullPath = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            if !showFullPath { return url.lastPathComponent }
            if customDisplayLength > 0 && fullPath.count > customDisplayLength {
                return "..." + String(fullPath.suffix(customDisplayLength))
            }
            return fullPath
        }

        if recentURLs.isEmpty {
            if inSubmenu {
                let noRecentItem = NSMenuItem(
                    title: Localization.string(.fileNoRecentFiles, default: "No recent files"),
                    action: nil, keyEquivalent: ""
                )
                noRecentItem.isEnabled = false
                installedOpenRecentMenu.addItem(noRecentItem)
                installedOpenRecentMenu.addItem(NSMenuItem.separator())
                let clearItem = NSMenuItem(
                    title: Localization.string(.fileClearRecentFiles, default: "Clear Menu"),
                    action: #selector(AppDelegate.clearRecentFiles(_:)), keyEquivalent: ""
                )
                clearItem.target = installedDelegate
                installedOpenRecentMenu.addItem(clearItem)
            }
            return
        }

        let capped = min(max(1, maxCount), recentURLs.count)

        if inSubmenu {
            for url in recentURLs.prefix(capped) {
                let item = NSMenuItem(title: makeTitle(for: url),
                                     action: #selector(AppDelegate.openRecentFile(_:)),
                                     keyEquivalent: "")
                item.target = installedDelegate
                item.representedObject = url.path
                item.toolTip = url.path
                installedOpenRecentMenu.addItem(item)
            }
            installedOpenRecentMenu.addItem(NSMenuItem.separator())
            installedOpenRecentMenu.addItem(
                withTitle: Localization.string(.fileClearRecentFiles, default: "Clear Menu"),
                action: #selector(AppDelegate.clearRecentFiles(_:)),
                keyEquivalent: ""
            ).target = installedDelegate
        } else {
            // Inline mode: insert items directly into File menu after "Open..."
            guard let fileMenu = installedFileMenu,
                  let openItem = fileMenu.items.first(where: { $0.action == #selector(AppDelegate.openDocument(_:)) }) else { return }
            var insertIdx = (fileMenu.index(of: openItem)) + 1
            for url in recentURLs.prefix(capped) {
                let item = NSMenuItem(title: makeTitle(for: url),
                                     action: #selector(AppDelegate.openRecentFile(_:)),
                                     keyEquivalent: "")
                item.target = installedDelegate
                item.representedObject = url.path
                item.toolTip = url.path
                item.tag = inlineRecentTag
                fileMenu.insertItem(item, at: insertIdx)
                insertIdx += 1
            }
            let sepItem = NSMenuItem.separator()
            sepItem.tag = inlineRecentTag
            fileMenu.insertItem(sepItem, at: insertIdx)
            insertIdx += 1
            let clearItem = NSMenuItem(
                title: Localization.string(.fileClearRecentFiles, default: "Clear Menu"),
                action: #selector(AppDelegate.clearRecentFiles(_:)),
                keyEquivalent: ""
            )
            clearItem.target = installedDelegate
            clearItem.tag = inlineRecentTag
            fileMenu.insertItem(clearItem, at: insertIdx)
        }
    }

    @MainActor
    static func refreshLanguages(catalog: LanguageCatalog, compact: Bool = false) {
        guard let installedLanguageMenu, let installedDelegate else { return }

        installedLanguageMenu.removeAllItems()
        populateLanguages(menu: installedLanguageMenu, delegate: installedDelegate, catalog: catalog, compact: compact)
    }

    @MainActor
    static func refreshWindowMenu(
        windows: [EditorWindowController],
        activeIdentity: EditorTabIdentity?,
        sortMode: WindowSortMode
    ) {
        guard
            let installedWindowListMenu,
            let installedWindowSortMenu,
            let installedWindowPinMenu,
            let installedWindowTabColorMenu
        else {
            return
        }

        let activeNormalized = activeIdentity?.normalized
        let activeController = windows.first { $0.tabIdentity.normalized == activeNormalized }

        installedWindowListMenu.removeAllItems()
        if windows.isEmpty {
            let noWindowsItem = NSMenuItem(
                title: Localization.string(.windowNoWindows, default: "No Windows"),
                action: nil,
                keyEquivalent: ""
            )
            noWindowsItem.isEnabled = false
            installedWindowListMenu.addItem(noWindowsItem)
        } else {
            for window in windows {
                let item = NSMenuItem(
                    title: window.windowListTitle,
                    action: #selector(AppDelegate.activateWindowFromList(_:)),
                    keyEquivalent: ""
                )
                item.target = installedDelegate
                item.representedObject = window
                item.state = window.tabIdentity.normalized == activeNormalized ? .on : .off
                installedWindowListMenu.addItem(item)
            }
        }

        installedWindowPinMenu.isEnabled = activeController != nil
        installedWindowPinMenu.state = activeController?.isPinnedToTab == true ? .on : .off

        let sortModeRaw = sortMode.rawValue
        for item in installedWindowSortMenu.items {
            item.state = item.tag == sortModeRaw ? .on : .off
        }

        let selectedColorTag = activeController?.tabColorIndex ?? 0
        for item in installedWindowTabColorMenu.items {
            item.state = item.tag == selectedColorTag ? .on : .off
        }
    }

    @MainActor
    private static func windowSortMenuDefaultTitle(for mode: WindowSortMode) -> String {
        switch mode {
        case .none: return "None"
        case .nameAsc: return "Name (Ascending)"
        case .nameDesc: return "Name (Descending)"
        case .pathAsc: return "Path (Ascending)"
        case .pathDesc: return "Path (Descending)"
        case .typeAsc: return "File Type (Ascending)"
        case .typeDesc: return "File Type (Descending)"
        case .sizeAsc: return "File Size (Ascending)"
        case .sizeDesc: return "File Size (Descending)"
        case .dateAsc: return "Modified Date (Ascending)"
        case .dateDesc: return "Modified Date (Descending)"
        case .contentLengthAsc: return "Content Length (Ascending)"
        case .contentLengthDesc: return "Content Length (Descending)"
        }
    }

    @MainActor
    private static func windowTabColorDefaultTitle(for tag: Int) -> String {
        switch tag {
        case 0: return "None"
        case 1: return "Yellow"
        case 2: return "Green"
        case 3: return "Blue"
        case 4: return "Red"
        case 5: return "Orange"
        case 6: return "Purple"
        default: return "None"
        }
    }

    @MainActor
    private static func populateThemes(
        menu: NSMenu,
        delegate: AppDelegate,
        themeCatalog: ThemeCatalog,
        selectedThemeName: String?
    ) {
        let defaultItem = NSMenuItem(
            title: Localization.string(.themeDefaultStyle, default: "Default Style"),
            action: #selector(AppDelegate.selectTheme(_:)),
            keyEquivalent: ""
        )
        defaultItem.target = delegate
        defaultItem.state = selectedThemeName == nil ? .on : .off
        menu.addItem(defaultItem)

        guard !themeCatalog.themes.isEmpty else { return }
        menu.addItem(NSMenuItem.separator())

        for theme in themeCatalog.themes {
            let item = NSMenuItem(
                title: theme.displayName,
                action: #selector(AppDelegate.selectTheme(_:)),
                keyEquivalent: ""
            )
            item.target = delegate
            item.representedObject = theme.name
            item.state = theme.name == selectedThemeName ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        let setDarkItem = NSMenuItem(
            title: Localization.string(.themeSetAsDarkMode, default: "Set Current Theme as Dark Mode Theme"),
            action: #selector(AppDelegate.setCurrentThemeAsDarkMode(_:)),
            keyEquivalent: ""
        )
        setDarkItem.target = delegate
        menu.addItem(setDarkItem)
        let clearDarkItem = NSMenuItem(
            title: Localization.string(.themeClearDarkMode, default: "Clear Dark Mode Theme"),
            action: #selector(AppDelegate.clearDarkModeTheme(_:)),
            keyEquivalent: ""
        )
        clearDarkItem.target = delegate
        menu.addItem(clearDarkItem)
    }

    @MainActor
    private static func installHashSubmenu(
        in toolsMenu: NSMenu,
        title: String,
        showAction: Selector,
        generateFromFilesAction: Selector,
        selectionAction: Selector,
        delegate: AppDelegate
    ) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        item.submenu = submenu
        toolsMenu.addItem(item)

        submenu.addItem(
            withTitle: Localization.string(.toolsGenerate, default: "Generate..."),
            action: showAction,
            keyEquivalent: ""
        ).target = delegate
        submenu.addItem(
            withTitle: Localization.string(.toolsGenerateFromFiles, default: "Generate from files..."),
            action: generateFromFilesAction,
            keyEquivalent: ""
        ).target = delegate
        submenu.addItem(
            withTitle: Localization.string(.toolsGenerateSelectionToClipboard, default: "Generate from selection into clipboard"),
            action: selectionAction,
            keyEquivalent: ""
        )
    }

    @MainActor
    /// Fills the "Launch in Browser" submenu with a "Default Browser" entry
    /// followed by one item per installed browser, discovered by bundle
    /// identifier through `NSWorkspace`. The detection logic itself lives in
    /// `BrowserLauncher` so it can be unit-tested without AppKit.
    private static func populateLaunchInBrowserMenu(_ menu: NSMenu) {
        let defaultItem = NSMenuItem(
            title: Localization.string(.viewLaunchInDefaultBrowser, default: "Default Browser"),
            action: #selector(EditorWindowController.launchInBrowser(_:)),
            keyEquivalent: ""
        )
        menu.addItem(defaultItem)

        let installed = BrowserLauncher.installedBrowsers { bundleID in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
        guard !installed.isEmpty else { return }

        menu.addItem(NSMenuItem.separator())
        for browser in installed {
            let item = NSMenuItem(
                title: browser.displayName,
                action: #selector(EditorWindowController.launchInSpecificBrowser(_:)),
                keyEquivalent: ""
            )
            item.representedObject = browser.bundleIdentifier
            menu.addItem(item)
        }
    }

    @MainActor
    // Languages shown in the top-level menu when compact mode is on
    private static let commonLanguageNames: Set<String> = [
        "normal", "c", "cpp", "csharp", "java", "javascript", "typescript",
        "python", "ruby", "php", "swift", "go", "rust", "bash", "html",
        "xml", "json", "yaml", "toml", "css", "sql", "markdown"
    ]

    @MainActor
    private static func populateLanguages(
        menu: NSMenu,
        delegate: AppDelegate,
        catalog: LanguageCatalog,
        compact: Bool = false
    ) {
        menu.addItem(
            withTitle: Localization.string(.languageUserDefined, default: "User Defined Languages..."),
            action: #selector(AppDelegate.showUserDefinedLanguages(_:)),
            keyEquivalent: ""
        ).target = delegate
        menu.addItem(
            withTitle: Localization.string(.languageOpenUDLDirectory, default: "Open UDL Directory..."),
            action: #selector(AppDelegate.openUDLDirectory(_:)),
            keyEquivalent: ""
        ).target = delegate
        menu.addItem(NSMenuItem.separator())

        let sorted = catalog.languages.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
        if compact {
            let common = sorted.filter { commonLanguageNames.contains($0.name) }
            let rare = sorted.filter { !commonLanguageNames.contains($0.name) }
            for language in common {
                let item = NSMenuItem(title: language.displayName, action: #selector(EditorWindowController.setSyntaxLanguage(_:)), keyEquivalent: "")
                item.representedObject = language.name
                menu.addItem(item)
            }
            if !rare.isEmpty {
                menu.addItem(NSMenuItem.separator())
                let othersMenu = NSMenu(title: "")
                for language in rare {
                    let item = NSMenuItem(title: language.displayName, action: #selector(EditorWindowController.setSyntaxLanguage(_:)), keyEquivalent: "")
                    item.representedObject = language.name
                    othersMenu.addItem(item)
                }
                let othersItem = NSMenuItem(title: Localization.string(.languageMenuOthers, default: "Others"), action: nil, keyEquivalent: "")
                othersItem.submenu = othersMenu
                menu.addItem(othersItem)
            }
        } else {
            for language in sorted {
                let item = NSMenuItem(title: language.displayName, action: #selector(EditorWindowController.setSyntaxLanguage(_:)), keyEquivalent: "")
                item.representedObject = language.name
                menu.addItem(item)
            }
        }
    }

    @MainActor
    static func refreshRunMenu(delegate: AppDelegate, savedCommands: [SavedRunCommand]) {
        guard let menu = installedRunMenu else { return }
        // Remove all items except the first "Run..." item
        while menu.items.count > 1 {
            menu.removeItem(at: 1)
        }
        guard !savedCommands.isEmpty else { return }
        menu.addItem(NSMenuItem.separator())
        for command in savedCommands {
            let item = NSMenuItem(
                title: command.name,
                action: #selector(AppDelegate.executeSavedRunCommand(_:)),
                keyEquivalent: command.keyEquivalent
            )
            if !command.keyEquivalent.isEmpty {
                item.keyEquivalentModifierMask = NSEvent.ModifierFlags(
                    rawValue: UInt(bitPattern: command.modifierFlags)
                )
            }
            item.target = delegate
            item.representedObject = command
            menu.addItem(item)
        }
    }

    /// The fixed items count in the macro menu before dynamic named-macro entries.
    static let macroMenuStaticCount = 9   // items before the separator + named macros

    @MainActor
    static func refreshMacroMenu(
        delegate: AppDelegate,
        namedMacros: [MacroRecording],
        shortcuts: [MacroShortcut]
    ) {
        guard let menu = installedMacroMenu else { return }
        // Remove dynamic macro items (keep static ones)
        while menu.items.count > macroMenuStaticCount {
            menu.removeItem(at: macroMenuStaticCount)
        }
        guard !namedMacros.isEmpty else { return }
        menu.addItem(NSMenuItem.separator())
        let shortcutMap = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.macroName.lowercased(), $0) })
        for macro in namedMacros {
            let sc = shortcutMap[macro.name.lowercased()]
            let item = NSMenuItem(
                title: macro.name,
                action: #selector(AppDelegate.playNamedMacroFromMenu(_:)),
                keyEquivalent: sc?.keyEquivalent ?? ""
            )
            if let sc, !sc.keyEquivalent.isEmpty {
                item.keyEquivalentModifierMask = NSEvent.ModifierFlags(
                    rawValue: UInt(bitPattern: sc.modifierFlags)
                )
            }
            item.target = delegate
            item.representedObject = macro.name
            menu.addItem(item)
        }
    }
}
