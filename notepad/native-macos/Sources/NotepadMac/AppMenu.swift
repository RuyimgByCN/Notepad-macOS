import AppKit
import NotepadMacCore

enum AppMenu {
    @MainActor
    private static weak var installedThemeMenu: NSMenu?
    @MainActor
    private static weak var installedLanguageMenu: NSMenu?
    @MainActor
    private static weak var installedDelegate: AppDelegate?

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
        appMenu.addItem(
            withTitle: Localization.string(.appPreferences, default: "Preferences..."),
            action: #selector(AppDelegate.showPreferences(_:)),
            keyEquivalent: ","
        ).target = delegate
        appMenu.addItem(
            withTitle: Localization.string(.appStyleConfigurator, default: "Style Configurator..."),
            action: #selector(AppDelegate.showStyleConfigurator(_:)),
            keyEquivalent: ""
        ).target = delegate
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
        fileMenu.addItem(withTitle: Localization.string(.fileOpen, default: "Open..."), action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o").target = delegate
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: Localization.string(.fileSave, default: "Save"), action: #selector(EditorWindowController.saveDocument(_:)), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(
            withTitle: Localization.string(.fileSaveAs, default: "Save As..."),
            action: #selector(EditorWindowController.saveDocumentAs(_:)),
            keyEquivalent: "S"
        )
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: Localization.string(.filePrint, default: "Print..."), action: #selector(EditorWindowController.printDocument(_:)), keyEquivalent: "p")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: Localization.string(.fileClose, default: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

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
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(
            withTitle: Localization.string(.editDuplicateLineOrSelection, default: "Duplicate Line/Selection"),
            action: #selector(EditorWindowController.duplicateLineOrSelection(_:)),
            keyEquivalent: "d"
        )
        editMenu.addItem(
            withTitle: Localization.string(.editDeleteLineOrSelection, default: "Delete Line/Selection"),
            action: #selector(EditorWindowController.deleteLineOrSelection(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editMoveLineUp, default: "Move Line Up"),
            action: #selector(EditorWindowController.moveLineUp(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editMoveLineDown, default: "Move Line Down"),
            action: #selector(EditorWindowController.moveLineDown(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editJoinLines, default: "Join Lines"),
            action: #selector(EditorWindowController.joinSelectedLines(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editRemoveEmptyLines, default: "Remove Empty Lines"),
            action: #selector(EditorWindowController.removeEmptyLines(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editRemoveBlankLines, default: "Remove Blank Lines"),
            action: #selector(EditorWindowController.removeBlankLines(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editRemoveDuplicateLines, default: "Remove Duplicate Lines"),
            action: #selector(EditorWindowController.removeDuplicateLines(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editRemoveConsecutiveDuplicateLines, default: "Remove Consecutive Duplicate Lines"),
            action: #selector(EditorWindowController.removeConsecutiveDuplicateLines(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editSortLinesAscending, default: "Sort Lines Ascending"),
            action: #selector(EditorWindowController.sortLinesAscending(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editSortLinesDescending, default: "Sort Lines Descending"),
            action: #selector(EditorWindowController.sortLinesDescending(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editUppercase, default: "UPPERCASE"),
            action: #selector(EditorWindowController.uppercaseSelection(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editLowercase, default: "lowercase"),
            action: #selector(EditorWindowController.lowercaseSelection(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editInvertCase, default: "Invert Case"),
            action: #selector(EditorWindowController.invertSelectionCase(_:)),
            keyEquivalent: ""
        )
        let trimTrailingWhitespace = editMenu.addItem(
            withTitle: Localization.string(.editTrimTrailingWhitespace, default: "Trim Trailing Whitespace"),
            action: #selector(EditorWindowController.trimTrailingWhitespace(_:)),
            keyEquivalent: "t"
        )
        trimTrailingWhitespace.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(
            withTitle: Localization.string(.editToggleLineComment, default: "Toggle Line Comment"),
            action: #selector(EditorWindowController.toggleLineComment(_:)),
            keyEquivalent: "/"
        )
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: Localization.string(.searchFind, default: "Find..."), action: #selector(EditorWindowController.showFindPanel(_:)), keyEquivalent: "f")
        editMenu.addItem(withTitle: Localization.string(.searchFindNext, default: "Find Next"), action: #selector(EditorWindowController.findNext(_:)), keyEquivalent: "g")
        let editFindPrevious = editMenu.addItem(
            withTitle: Localization.string(.searchFindPrevious, default: "Find Previous"),
            action: #selector(EditorWindowController.findPrevious(_:)),
            keyEquivalent: "G"
        )
        editFindPrevious.keyEquivalentModifierMask = [.command, .shift]
        let replace = editMenu.addItem(
            withTitle: Localization.string(.searchReplace, default: "Replace..."),
            action: #selector(EditorWindowController.showReplacePanel(_:)),
            keyEquivalent: "f"
        )
        replace.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(
            withTitle: Localization.string(.editAutoCompletion, default: "Auto Completion..."),
            action: #selector(EditorWindowController.showAutoCompletion(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editFunctionCallTip, default: "Function Call Tip..."),
            action: #selector(EditorWindowController.showCallTip(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editColumnEditor, default: "Column Editor..."),
            action: #selector(EditorWindowController.showColumnEditor(_:)),
            keyEquivalent: ""
        )
        editMenu.addItem(
            withTitle: Localization.string(.editRectangularSelection, default: "Rectangular Selection..."),
            action: #selector(EditorWindowController.showRectangularSelectionPanel(_:)),
            keyEquivalent: ""
        )

        let encodingMenuItem = NSMenuItem()
        mainMenu.addItem(encodingMenuItem)
        let encodingMenu = NSMenu(title: Localization.string(.encodingMenu, default: "Encoding"))
        encodingMenuItem.submenu = encodingMenu
        for option in TextEncodingOption.allCases {
            let item = NSMenuItem(
                title: String(format: Localization.string(.encodingConvertToFormat, default: "Convert to %@"), option.displayName),
                action: #selector(EditorWindowController.convertEncoding(_:)),
                keyEquivalent: ""
            )
            item.representedObject = option.rawValue
            encodingMenu.addItem(item)
        }
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

        let pluginsMenuItem = NSMenuItem()
        mainMenu.addItem(pluginsMenuItem)
        let pluginsMenu = NSMenu(title: Localization.string(.pluginsMenu, default: "Plugins"))
        pluginsMenuItem.submenu = pluginsMenu
        pluginsMenu.addItem(
            withTitle: Localization.string(.pluginAdmin, default: "Plugin Admin..."),
            action: #selector(AppDelegate.showPluginAdmin(_:)),
            keyEquivalent: ""
        ).target = delegate

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: Localization.string(.viewMenu, default: "View"))
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(
            withTitle: Localization.string(.viewToggleLineWrap, default: "Toggle Line Wrap"),
            action: #selector(EditorWindowController.toggleLineWrap(_:)),
            keyEquivalent: "l"
        )
        let foldingMenuItem = NSMenuItem(title: Localization.string(.foldingMenu, default: "Folding"), action: nil, keyEquivalent: "")
        let foldingMenu = NSMenu(title: Localization.string(.foldingMenu, default: "Folding"))
        foldingMenuItem.submenu = foldingMenu
        viewMenu.addItem(foldingMenuItem)
        foldingMenu.addItem(
            withTitle: Localization.string(.foldingToggle, default: "Toggle Fold"),
            action: #selector(EditorWindowController.toggleFoldAtCurrentLine(_:)),
            keyEquivalent: ""
        )
        foldingMenu.addItem(NSMenuItem.separator())
        foldingMenu.addItem(
            withTitle: Localization.string(.foldingFoldAll, default: "Fold All"),
            action: #selector(EditorWindowController.foldAll(_:)),
            keyEquivalent: ""
        )
        foldingMenu.addItem(
            withTitle: Localization.string(.foldingUnfoldAll, default: "Unfold All"),
            action: #selector(EditorWindowController.unfoldAll(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(
            withTitle: Localization.string(.viewBiggerText, default: "Bigger Text"),
            action: #selector(EditorWindowController.increaseFontSize(_:)),
            keyEquivalent: "+"
        )
        viewMenu.addItem(
            withTitle: Localization.string(.viewSmallerText, default: "Smaller Text"),
            action: #selector(EditorWindowController.decreaseFontSize(_:)),
            keyEquivalent: "-"
        )
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(
            withTitle: Localization.string(.viewFunctionList, default: "Function List..."),
            action: #selector(EditorWindowController.showFunctionList(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(
            withTitle: Localization.string(.viewDocumentStatistics, default: "Document Statistics..."),
            action: #selector(EditorWindowController.showDocumentStatistics(_:)),
            keyEquivalent: ""
        )
        viewMenu.addItem(NSMenuItem.separator())
        let themeMenuItem = NSMenuItem(title: Localization.string(.themeMenu, default: "Theme"), action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: Localization.string(.themeMenu, default: "Theme"))
        themeMenuItem.submenu = themeMenu
        viewMenu.addItem(themeMenuItem)
        installedThemeMenu = themeMenu
        populateThemes(
            menu: themeMenu,
            delegate: delegate,
            themeCatalog: themeCatalog,
            selectedThemeName: selectedThemeName
        )

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

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: Localization.string(.windowMenu, default: "Window"))
        windowMenuItem.submenu = windowMenu
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
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: Localization.string(.windowMergeAllWindows, default: "Merge All Windows"),
            action: #selector(NSWindow.mergeAllWindows(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: Localization.string(.windowMinimize, default: "Minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: Localization.string(.windowBringAllToFront, default: "Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
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
    static func refreshLanguages(catalog: LanguageCatalog) {
        guard let installedLanguageMenu, let installedDelegate else { return }

        installedLanguageMenu.removeAllItems()
        populateLanguages(menu: installedLanguageMenu, delegate: installedDelegate, catalog: catalog)
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
    }

    @MainActor
    private static func populateLanguages(
        menu: NSMenu,
        delegate: AppDelegate,
        catalog: LanguageCatalog
    ) {
        menu.addItem(
            withTitle: Localization.string(.languageUserDefined, default: "User Defined Languages..."),
            action: #selector(AppDelegate.showUserDefinedLanguages(_:)),
            keyEquivalent: ""
        ).target = delegate
        menu.addItem(NSMenuItem.separator())

        for language in catalog.languages.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(EditorWindowController.setSyntaxLanguage(_:)),
                keyEquivalent: ""
            )
            item.representedObject = language.name
            menu.addItem(item)
        }
    }
}
