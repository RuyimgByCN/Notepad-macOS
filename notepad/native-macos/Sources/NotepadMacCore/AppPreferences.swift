import Foundation

public enum SearchEngineChoice: String, Codable, Equatable, Sendable, CaseIterable {
    case custom
    case duckDuckGo
    case google
    case bing
    case yahoo
    case stackOverflow
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let minimumEditorFontSize = 9.0
    public static let maximumEditorFontSize = 32.0
    public static let defaultCustomDateTimeFormat = "yyyy-MM-dd HH:mm:ss"
    public static let minimumCaretWidth = 1
    public static let maximumCaretWidth = 3
    public static let minimumLargeFileMB = 1
    public static let maximumLargeFileMB = 4096
    public static let defaultLargeFileMB = 50

    public static let defaultValue = AppPreferences(
        editorFontSize: 13,
        wrapsLines: false,
        searchMatchCase: false,
        searchWholeWord: false,
        customDateTimeFormat: defaultCustomDateTimeFormat,
        searchEngineChoice: .google,
        customSearchEngineURL: "",
        localizationFileName: "english.xml",
        showWhitespace: false,
        showEOL: false,
        showIndentGuides: false,
        highlightCurrentLine: false,
        showWrapSymbol: false,
        showChangeHistory: false,
        tabSize: 4,
        insertSpacesInsteadOfTabs: false,
        showLineNumberMargin: true,
        showEdgeLine: false,
        edgeLineColumn: 80,
        enableAutoPair: true,
        enableXmlTagMatch: true,
        enableClickableLinks: true,
        defaultNewDocumentEncoding: "utf8",
        defaultNewDocumentLineEnding: "lf",
        rememberLastSession: true,
        showNpcCharacters: false,
        smartHighlightMatchCase: false,
        smartHighlightWholeWord: true,
        caretWidth: 1,
        enableVirtualSpace: false,
        backspaceUnindents: true,
        autoIndent: true,
        largeFileSizeMB: defaultLargeFileMB,
        scrollBeyondLastLine: false,
        autoCompleteFromNthChar: 3,
        linePadding: 0,
        openDirectoryFollowsDocument: false,
        defaultNewDocumentLanguageName: "",
        folderDropOpensAsWorkspace: false,
        extraURLSchemes: "",
        newDocumentOnLaunch: true,
        postItAlpha: 0.75
    )

    public let editorFontSize: Double
    public let wrapsLines: Bool
    public let searchMatchCase: Bool
    public let searchWholeWord: Bool
    public let customDateTimeFormat: String
    public let searchEngineChoice: SearchEngineChoice
    public let customSearchEngineURL: String
    public let localizationFileName: String
    public let showWhitespace: Bool
    public let showEOL: Bool
    public let showIndentGuides: Bool
    public let highlightCurrentLine: Bool
    public let showWrapSymbol: Bool
    public let showChangeHistory: Bool
    public let tabSize: Int
    public let insertSpacesInsteadOfTabs: Bool
    public let showLineNumberMargin: Bool
    public let showEdgeLine: Bool
    public let edgeLineColumn: Int
    public let enableAutoPair: Bool
    /// Auto-insert matching parentheses ( )
    public let autoPairParentheses: Bool
    /// Auto-insert matching square brackets [ ]
    public let autoPairBrackets: Bool
    /// Auto-insert matching curly braces { }
    public let autoPairCurlyBrackets: Bool
    /// Auto-insert matching single quotes ' '
    public let autoPairSingleQuotes: Bool
    /// Auto-insert matching double quotes " "
    public let autoPairDoubleQuotes: Bool
    /// User-defined custom matched pairs; each element is [openChar, closeChar]
    public let customMatchedPairs: [[String]]
    public let enableXmlTagMatch: Bool
    public let enableClickableLinks: Bool
    public let defaultNewDocumentEncoding: String   // TextEncodingOption.rawValue
    public let defaultNewDocumentLineEnding: String // LineEnding.rawValue
    public let rememberLastSession: Bool
    public let showNpcCharacters: Bool
    public let smartHighlightMatchCase: Bool
    public let smartHighlightWholeWord: Bool
    /// When true, "Mark All" respects match-case
    public let markAllMatchCase: Bool
    /// When true, "Mark All" matches whole words only
    public let markAllWholeWord: Bool
    /// When true, compress the Language menu by hiding rarely-used entries
    public let langMenuCompact: Bool
    public let caretWidth: Int      // 1 = thin, 2 = medium, 3 = thick
    public let enableVirtualSpace: Bool
    public let backspaceUnindents: Bool
    public let autoIndent: Bool
    /// Auto-indent mode: 0=none, 1=basic (copy prev line indent), 2=advanced (basic + bracket-aware)
    public let autoIndentMode: Int
    /// File auto-detection mode: 0=disabled, 1=check on tab activate, 2=real-time monitoring
    public let fileAutoDetection: Int
    /// When true, externally modified files are auto-reloaded without a confirmation dialog
    public let updateSilently: Bool
    public let largeFileSizeMB: Int  // Files above this threshold skip syntax highlight and URL scan
    /// When true, auto-complete is disabled while a large file is open
    public let largeFileSuppressAutoComplete: Bool
    /// When true, smart highlighting is disabled while a large file is open
    public let largeFileSuppressSmartHighlight: Bool
    /// When true, brace/bracket matching is disabled while a large file is open
    public let largeFileSuppressBraceMatch: Bool
    /// When true, word wrap is disabled while a large file is open
    public let largeFileSuppressWordWrap: Bool
    /// When true, syntax highlighting (lexer) is disabled while a large file is open
    public let largeFileSuppressSyntaxHighlight: Bool
    public let scrollBeyondLastLine: Bool
    public let autoCompleteFromNthChar: Int  // 0 = disabled, 1+ = trigger after N chars typed
    public let caretNoBlink: Bool
    /// Caret blink period in milliseconds (100-2000). Ignored when caretNoBlink is true.
    public let caretBlinkRate: Int
    public let currentLineFrameWidth: Int   // 0 = fill, 1-4 = frame width in pixels
    public let lineWrapIndent: Int          // 0=fixed, 1=same, 2=indent, 3=deepindent
    public let foldMarginStyle: Int         // 0=simple arrows, 1=box tree, 2=circle tree
    public let useFirstLineAsTabName: Bool
    public let recentFilesMaxCount: Int     // 1-50
    public let recentFilesShowFullPath: Bool
    /// When true, Recent Files are shown in a submenu rather than in the File menu directly
    public let recentFilesInSubmenu: Bool
    /// Custom display length for recent file paths (0 = show full path, >0 = trim to N chars from end)
    public let recentFilesCustomDisplayLength: Int
    public let noCheckRecentAtLaunch: Bool
    public let keepAbsentFilesInSession: Bool
    public let autoReloadOnExternalChange: Bool
    public let backupOnSaveMode: BackupOnSaveMode
    public let snapshotModeEnabled: Bool
    public let periodicBackupIntervalSeconds: Int
    public let useCustomBackupDirectory: Bool
    public let customBackupDirectory: String
    /// Comma-separated list of additional vertical edge columns (e.g. "80,120")
    public let additionalEdgeColumns: String
    public let linePadding: Int   // extra pixels above each line (SCI_SETEXTRAASCENT), 0-5
    /// 0 = remember last used (NSOpenPanel default), 1 = follow current document's directory
    public let openDirectoryFollowsDocument: Bool
    /// Language name for new untitled documents; empty = use catalog default (Normal Text)
    public let defaultNewDocumentLanguageName: String
    /// Additional URI schemes to treat as clickable links (space-separated, e.g. "ssh svn")
    public let extraURLSchemes: String
    /// When a folder is dropped or passed as argument, open it as a workspace instead of failing
    public let folderDropOpensAsWorkspace: Bool
    /// When true, dropping a folder recursively opens all files within it (instead of ignoring)
    public let folderDropRecursiveOpen: Bool
    /// When session restore is off and no files are provided, create a new empty document on launch
    public let newDocumentOnLaunch: Bool
    /// Opacity for Post-It mode window (0.0=transparent, 1.0=opaque)
    public let postItAlpha: Double
    /// Print line numbers alongside document content
    public let printLineNumbers: Bool
    /// Auto-complete mode: 0=off, 1=function API only, 2=document words only, 3=both (default)
    public let autoCompleteMode: Int
    /// Automatically accept the only available auto-complete item without showing the list
    public let autoCompleteChooseSingle: Bool
    /// Use Tab key as a fill-up character to commit the selected auto-complete item
    public let autoCompleteTABFillup: Bool
    /// Use Enter key to also commit the selected auto-complete item
    public let autoCompleteEnterCommit: Bool
    /// Show brief (compressed) auto-complete list without function prototypes
    public let autoCompleteBrief: Bool
    /// Selection length threshold (chars) for auto-checking "In Selection" in Find dialog
    public let inSelectionThreshold: Int
    /// Double-clicking a tab closes it
    public let tabbarDoubleClickClose: Bool
    /// Max characters to show in a tab label (0 = no limit)
    public let tabbarMaxLabelLength: Int
    /// Keep the Find dialog open after Replace All
    public let keepFindDialogOpen: Bool
    /// Transparency of Find dialog when unfocused (0.0 = opaque, 1.0 = fully transparent)
    public let findDialogTransparency: Double
    /// Print header/footer and margin settings
    public let printSettings: PrintSettings
    /// Delimiter for "Select between delimiters": left char (empty = whitespace)
    public let delimiterLeft: String
    /// Delimiter for "Select between delimiters": right char (empty = whitespace)
    public let delimiterRight: String
    /// Show status bar at bottom of editor window
    public let statusBarVisible: Bool
    /// Show only the filename (not full path) in the window title bar
    public let shortTitle: Bool
    /// Prompt before "Save All" operation
    public let saveAllConfirm: Bool
    /// Exclude words starting with a digit from inline auto-complete suggestions
    public let autoCompleteIgnoreNumbers: Bool
    /// After Replace, keep caret at original position instead of moving to replaced range
    public let replaceDoesNotMove: Bool
    /// When false, skip starting the file-system watcher entirely (no external-change prompts)
    public let fileChangeDetectionEnabled: Bool
    /// Use a monospaced font in the Find/Replace text fields
    public let findDialogMonospace: Bool
    /// When true, Ctrl+C/Cmd+C with no selection copies the entire current line (Scintilla)
    public let copyLineWithoutSelection: Bool
    /// When true, opening Find dialog auto-fills the search field with selected text
    public let fillFindFromSelection: Bool
    /// When true, opening Find dialog with no selection auto-selects the word under the caret
    public let autoSelectWordUnderCaret: Bool
    /// When true, Find in Files ignores unsaved changes in open documents
    public let findInFilesIgnoreUnsaved: Bool
    /// When true, smart highlighting uses the Find dialog's match-case/whole-word settings
    public let smartHighlightUseFindSettings: Bool
    /// URL highlight style: 0=underline, 1=box, 2=full-box
    public let urlIndicatorStyle: Int
    /// Per-language tab overrides, comma-separated, e.g. "python:4s,html:2s,c:8t"
    /// Format: langname:sizeX where X is 's' (spaces) or 't' (tabs)
    public let languageTabOverrides: String
    /// When true, prevent tab reordering by drag-and-drop
    public let tabbarLockDragDrop: Bool
    /// When true, closing the last tab exits the app instead of creating a new empty document
    public let tabbarExitOnLastTab: Bool
    /// When true, automatically insert the matching HTML/XML close tag after typing '>'
    public let htmlXmlCloseTagEnabled: Bool
    /// When true, mute all application sounds (e.g., bell on invalid action)
    public let muteAllSounds: Bool
    /// When false, dragging selected text within the editor is disabled
    public let selectedTextDragDrop: Bool
    /// When true, the line number margin width adjusts dynamically based on line count
    public let lineNumberDynamicWidth: Bool
    /// When true, column selection mode converts to multi-cursor editing
    public let columnSelectionToMultiEditing: Bool
    /// Appearance override: 0=follow system, 1=always light, 2=always dark
    public let appearanceMode: Int
    /// Comma-separated list of tags for the Task List scanner (empty = use defaults)
    public let taskListCustomTags: String
    /// When false, the toolbar is hidden on editor windows
    public let toolbarVisible: Bool
    /// When false, the bookmark/margin marker column is hidden
    public let showBookmarkMargin: Bool
    /// When false, skip the confirmation dialog before "Replace All in Open Documents"
    public let confirmReplaceInAllDocs: Bool
    /// Max number of entries kept in the Find/Replace history dropdowns (1-50)
    public let maxFindHistoryCount: Int
    /// When true, the tab bar is hidden
    public let tabbarHide: Bool
    /// After an external file reload, scroll to restore the last caret position
    public let reloadScrollToLastCaret: Bool
    /// Font face name for the editor (empty = use default "Menlo")
    public let editorFontName: String
    /// When true, the editor font is rendered in bold weight
    public let editorFontBold: Bool
    /// When false, the close (×) button is hidden on every tab
    public let tabbarShowCloseButton: Bool
    /// When true, trailing whitespace is stripped from every line automatically on save
    public let trimTrailingSpacesOnSave: Bool
    /// When true, line endings in pasted text are converted to match the current document's EOL style
    public let pasteConvertEndings: Bool
    /// Caret sticky mode: 0=disabled, 1=enabled, 2=enabled for whitespace only
    public let caretStickyMode: Int
    /// When true, the fold margin is shown and code folding is active
    public let enableCodeFolding: Bool
    /// When true, auto-complete matching ignores case (case-insensitive)
    public let autoCompleteIgnoreCase: Bool
    /// Whitespace display mode: 0=invisible, 1=visible always, 2=visible after indent, 3=visible only in indent
    public let whitespaceDisplayMode: Int
    /// Bidirectional text mode: 0=default, 1=left-to-right, 2=right-to-left
    public let bidiMode: Int
    /// When true, text is rendered with antialiased (smooth) font quality
    public let smoothFont: Bool
    /// When true, multiple selections are enabled in the editor
    public let multiEditEnabled: Bool
    /// Multi-paste mode: 0=paste once (into main selection), 1=paste into each selection
    public let multiPasteMode: Int
    /// Indent guide display mode: 0=none, 1=real, 2=lookForward, 3=lookBoth
    public let indentGuideMode: Int
    /// Word wrap mode: 0=none, 1=word, 2=whitespace, 3=character
    public let wordWrapMode: Int
    /// When true, the tab bar uses compact/reduced style (smaller height and font)
    public let tabbarCompact: Bool
    /// When true, show tab index numbers (1-9) in tab labels for ⌘1-⌘9 reference
    public let tabbarShowIndexNumbers: Bool
    /// When true, zoom changes in one tab are automatically applied to all open tabs
    public let zoomSyncToAllTabs: Bool
    /// When true, keyboard shortcut indicators are hidden from menu items
    public let hideMenuShortcuts: Bool
    /// When true, after monitoring-reload scroll to the last line of the file
    public let scrollToLastLineOnMonitorReload: Bool
    /// Alpha value for additional (non-primary) selections in multi-select mode (0-255, 256=opaque)
    public let additionalSelAlpha: Int
    /// When true, additional carets in multi-select mode blink in sync with the primary caret
    public let additionalCaretsBlink: Bool
    /// When true, additional carets in multi-select mode are drawn
    public let additionalCaretsVisible: Bool
    /// When true, the current line highlight remains visible even when the editor is unfocused
    public let caretLineVisibleAlways: Bool
    /// Dot size for whitespace markers in pixels (1-5); SCI_SETWHITESPACESIZE
    public let whitespaceSize: Int
    /// Alpha for primary selection background (0-255 transparent, 256=opaque); SCI_SETSELALPHA
    public let selectionAlpha: Int
    /// Control character display: 0=show as glyph, 1-6=use defined symbol; SCI_SETCONTROLCHARSYMBOL
    public let controlCharDisplay: Int
    /// When true, ANSI-encoded files are automatically opened as UTF-8 (upstream openAnsiAsUTF8)
    public let openAnsiAsUtf8: Bool
    /// When true, XML/HTML tag attributes are highlighted alongside tag-name matching (upstream TagAttrHighLight)
    public let xmlTagAttributeHighlight: Bool
    /// When true, XML tag matching is applied even in non-HTML/PHP/ASP zones (upstream HighLightNonHtmlZone)
    public let highlightNonHtmlZone: Bool
    /// Custom default directory for Save/Open dialogs (empty = use system default)
    public let defaultSaveDirectory: String
    /// Toolbar icon size: 0=regular (default), 1=small (compact)
    public let toolbarIconSizeStyle: Int
    /// Scintilla rendering technology: 0=default, 1=direct (SCI_SETTECHNOLOGY)
    public let scintillaRenderingTechnology: Int
    /// When true, disable advanced scrolling (upstream Performance: disableAdvancedScrolling)
    public let disableAdvancedScrolling: Bool
    /// When true, right-click keeps the current selection instead of moving caret (upstream Editing2)
    public let rightClickKeepSelection: Bool
    /// Edge line visual style: 0=none, 1=line, 2=background highlight (SCI_SETEDGEMODE)
    public let edgeMode: Int
    /// Fold flags bitmask: SC_FOLDFLAG_LINEBEFORE_EXPANDED=2, LINEBEFORE_CONTRACTED=4, LINEAFTER_EXPANDED=8, LINEAFTER_CONTRACTED=16
    public let foldFlags: Int

    public var searchOptions: TextSearch.Options {
        TextSearch.Options(matchCase: searchMatchCase, wholeWord: searchWholeWord)
    }

    public init(
        editorFontSize: Double = 13,
        wrapsLines: Bool = false,
        searchMatchCase: Bool = false,
        searchWholeWord: Bool = false,
        customDateTimeFormat: String = "yyyy-MM-dd HH:mm:ss",
        searchEngineChoice: SearchEngineChoice = .google,
        customSearchEngineURL: String = "",
        localizationFileName: String = "english.xml",
        showWhitespace: Bool = false,
        showEOL: Bool = false,
        showIndentGuides: Bool = false,
        highlightCurrentLine: Bool = false,
        showWrapSymbol: Bool = false,
        showChangeHistory: Bool = false,
        tabSize: Int = 4,
        insertSpacesInsteadOfTabs: Bool = false,
        showLineNumberMargin: Bool = true,
        showEdgeLine: Bool = false,
        edgeLineColumn: Int = 80,
        enableAutoPair: Bool = true,
        autoPairParentheses: Bool = true,
        autoPairBrackets: Bool = true,
        autoPairCurlyBrackets: Bool = true,
        autoPairSingleQuotes: Bool = false,
        autoPairDoubleQuotes: Bool = false,
        customMatchedPairs: [[String]] = [],
        enableXmlTagMatch: Bool = true,
        enableClickableLinks: Bool = true,
        defaultNewDocumentEncoding: String = "utf8",
        defaultNewDocumentLineEnding: String = "lf",
        rememberLastSession: Bool = true,
        showNpcCharacters: Bool = false,
        smartHighlightMatchCase: Bool = false,
        smartHighlightWholeWord: Bool = true,
        markAllMatchCase: Bool = false,
        markAllWholeWord: Bool = false,
        langMenuCompact: Bool = true,
        caretWidth: Int = 1,
        enableVirtualSpace: Bool = false,
        backspaceUnindents: Bool = true,
        autoIndent: Bool = true,
        autoIndentMode: Int = 1,
        fileAutoDetection: Int = 1,
        updateSilently: Bool = false,
        largeFileSizeMB: Int = AppPreferences.defaultLargeFileMB,
        largeFileSuppressAutoComplete: Bool = true,
        largeFileSuppressSmartHighlight: Bool = true,
        largeFileSuppressBraceMatch: Bool = true,
        largeFileSuppressWordWrap: Bool = true,
        largeFileSuppressSyntaxHighlight: Bool = true,
        scrollBeyondLastLine: Bool = false,
        autoCompleteFromNthChar: Int = 3,
        caretNoBlink: Bool = false,
        caretBlinkRate: Int = 500,
        currentLineFrameWidth: Int = 0,
        lineWrapIndent: Int = 0,
        foldMarginStyle: Int = 0,
        useFirstLineAsTabName: Bool = false,
        recentFilesMaxCount: Int = 20,
        recentFilesShowFullPath: Bool = false,
        recentFilesInSubmenu: Bool = false,
        recentFilesCustomDisplayLength: Int = 0,
        noCheckRecentAtLaunch: Bool = false,
        keepAbsentFilesInSession: Bool = false,
        autoReloadOnExternalChange: Bool = false,
        backupOnSaveMode: BackupOnSaveMode = .none,
        snapshotModeEnabled: Bool = true,
        periodicBackupIntervalSeconds: Int = 7,
        useCustomBackupDirectory: Bool = false,
        customBackupDirectory: String = "",
        additionalEdgeColumns: String = "",
        linePadding: Int = 0,
        openDirectoryFollowsDocument: Bool = false,
        defaultNewDocumentLanguageName: String = "",
        folderDropOpensAsWorkspace: Bool = false,
        folderDropRecursiveOpen: Bool = false,
        extraURLSchemes: String = "",
        newDocumentOnLaunch: Bool = true,
        postItAlpha: Double = 0.75,
        printLineNumbers: Bool = true,
        autoCompleteMode: Int = 3,
        autoCompleteChooseSingle: Bool = true,
        autoCompleteTABFillup: Bool = false,
        autoCompleteEnterCommit: Bool = true,
        autoCompleteBrief: Bool = false,
        inSelectionThreshold: Int = 1024,
        tabbarDoubleClickClose: Bool = false,
        tabbarMaxLabelLength: Int = 0,
        keepFindDialogOpen: Bool = true,
        findDialogTransparency: Double = 0,
        printSettings: PrintSettings = .defaultValue,
        delimiterLeft: String = "",
        delimiterRight: String = "",
        statusBarVisible: Bool = true,
        shortTitle: Bool = false,
        saveAllConfirm: Bool = false,
        autoCompleteIgnoreNumbers: Bool = true,
        replaceDoesNotMove: Bool = false,
        fileChangeDetectionEnabled: Bool = true,
        findDialogMonospace: Bool = false,
        copyLineWithoutSelection: Bool = true,
        fillFindFromSelection: Bool = true,
        autoSelectWordUnderCaret: Bool = false,
        findInFilesIgnoreUnsaved: Bool = false,
        smartHighlightUseFindSettings: Bool = false,
        urlIndicatorStyle: Int = 0,
        languageTabOverrides: String = "",
        tabbarLockDragDrop: Bool = false,
        tabbarExitOnLastTab: Bool = false,
        htmlXmlCloseTagEnabled: Bool = false,
        muteAllSounds: Bool = false,
        selectedTextDragDrop: Bool = true,
        lineNumberDynamicWidth: Bool = false,
        columnSelectionToMultiEditing: Bool = false,
        appearanceMode: Int = 0,
        taskListCustomTags: String = "",
        toolbarVisible: Bool = true,
        showBookmarkMargin: Bool = true,
        confirmReplaceInAllDocs: Bool = true,
        maxFindHistoryCount: Int = 20,
        tabbarHide: Bool = false,
        reloadScrollToLastCaret: Bool = false,
        editorFontName: String = "",
        editorFontBold: Bool = false,
        tabbarShowCloseButton: Bool = true,
        trimTrailingSpacesOnSave: Bool = false,
        pasteConvertEndings: Bool = true,
        caretStickyMode: Int = 0,
        enableCodeFolding: Bool = true,
        autoCompleteIgnoreCase: Bool = true,
        whitespaceDisplayMode: Int = 0,
        bidiMode: Int = 0,
        smoothFont: Bool = true,
        multiEditEnabled: Bool = true,
        multiPasteMode: Int = 1,
        indentGuideMode: Int = 2,
        wordWrapMode: Int = 1,
        tabbarCompact: Bool = false,
        tabbarShowIndexNumbers: Bool = false,
        zoomSyncToAllTabs: Bool = false,
        hideMenuShortcuts: Bool = false,
        scrollToLastLineOnMonitorReload: Bool = false,
        additionalSelAlpha: Int = 256,
        additionalCaretsBlink: Bool = true,
        additionalCaretsVisible: Bool = true,
        caretLineVisibleAlways: Bool = false,
        whitespaceSize: Int = 1,
        selectionAlpha: Int = 256,
        controlCharDisplay: Int = 0,
        openAnsiAsUtf8: Bool = false,
        xmlTagAttributeHighlight: Bool = true,
        highlightNonHtmlZone: Bool = false,
        defaultSaveDirectory: String = "",
        toolbarIconSizeStyle: Int = 0,
        scintillaRenderingTechnology: Int = 0,
        disableAdvancedScrolling: Bool = false,
        rightClickKeepSelection: Bool = true,
        edgeMode: Int = 1,
        foldFlags: Int = 0
    ) {
        self.editorFontSize = min(max(editorFontSize, Self.minimumEditorFontSize), Self.maximumEditorFontSize)
        self.wrapsLines = wrapsLines
        self.searchMatchCase = searchMatchCase
        self.searchWholeWord = searchWholeWord
        self.customDateTimeFormat = customDateTimeFormat.isEmpty
            ? Self.defaultCustomDateTimeFormat
            : customDateTimeFormat
        self.searchEngineChoice = searchEngineChoice
        self.customSearchEngineURL = customSearchEngineURL
        self.localizationFileName = localizationFileName.isEmpty
            ? "english.xml"
            : localizationFileName
        self.showWhitespace = showWhitespace
        self.showEOL = showEOL
        self.showIndentGuides = showIndentGuides
        self.highlightCurrentLine = highlightCurrentLine
        self.showWrapSymbol = showWrapSymbol
        self.showChangeHistory = showChangeHistory
        self.tabSize = max(1, min(tabSize, 8))
        self.insertSpacesInsteadOfTabs = insertSpacesInsteadOfTabs
        self.showLineNumberMargin = showLineNumberMargin
        self.showEdgeLine = showEdgeLine
        self.edgeLineColumn = max(1, edgeLineColumn)
        self.enableAutoPair = enableAutoPair
        self.autoPairParentheses = autoPairParentheses
        self.autoPairBrackets = autoPairBrackets
        self.autoPairCurlyBrackets = autoPairCurlyBrackets
        self.autoPairSingleQuotes = autoPairSingleQuotes
        self.autoPairDoubleQuotes = autoPairDoubleQuotes
        self.customMatchedPairs = customMatchedPairs
        self.enableXmlTagMatch = enableXmlTagMatch
        self.enableClickableLinks = enableClickableLinks
        self.defaultNewDocumentEncoding = defaultNewDocumentEncoding.isEmpty ? "utf8" : defaultNewDocumentEncoding
        self.defaultNewDocumentLineEnding = defaultNewDocumentLineEnding.isEmpty ? "lf" : defaultNewDocumentLineEnding
        self.rememberLastSession = rememberLastSession
        self.showNpcCharacters = showNpcCharacters
        self.smartHighlightMatchCase = smartHighlightMatchCase
        self.smartHighlightWholeWord = smartHighlightWholeWord
        self.markAllMatchCase = markAllMatchCase
        self.markAllWholeWord = markAllWholeWord
        self.langMenuCompact = langMenuCompact
        self.caretWidth = max(Self.minimumCaretWidth, min(caretWidth, Self.maximumCaretWidth))
        self.enableVirtualSpace = enableVirtualSpace
        self.backspaceUnindents = backspaceUnindents
        self.autoIndent = autoIndent
        self.autoIndentMode = max(0, min(2, autoIndentMode))
        self.fileAutoDetection = max(0, min(2, fileAutoDetection))
        self.updateSilently = updateSilently
        self.largeFileSizeMB = max(Self.minimumLargeFileMB, min(largeFileSizeMB, Self.maximumLargeFileMB))
        self.largeFileSuppressAutoComplete = largeFileSuppressAutoComplete
        self.largeFileSuppressSmartHighlight = largeFileSuppressSmartHighlight
        self.largeFileSuppressBraceMatch = largeFileSuppressBraceMatch
        self.largeFileSuppressWordWrap = largeFileSuppressWordWrap
        self.largeFileSuppressSyntaxHighlight = largeFileSuppressSyntaxHighlight
        self.scrollBeyondLastLine = scrollBeyondLastLine
        self.autoCompleteFromNthChar = max(0, autoCompleteFromNthChar)
        self.caretNoBlink = caretNoBlink
        self.caretBlinkRate = max(100, min(2000, caretBlinkRate))
        self.currentLineFrameWidth = max(0, min(4, currentLineFrameWidth))
        self.lineWrapIndent = max(0, min(3, lineWrapIndent))
        self.foldMarginStyle = max(0, min(2, foldMarginStyle))
        self.useFirstLineAsTabName = useFirstLineAsTabName
        self.recentFilesMaxCount = max(1, min(50, recentFilesMaxCount))
        self.recentFilesShowFullPath = recentFilesShowFullPath
        self.recentFilesInSubmenu = recentFilesInSubmenu
        self.recentFilesCustomDisplayLength = max(0, recentFilesCustomDisplayLength)
        self.noCheckRecentAtLaunch = noCheckRecentAtLaunch
        self.keepAbsentFilesInSession = keepAbsentFilesInSession
        self.autoReloadOnExternalChange = autoReloadOnExternalChange
        self.backupOnSaveMode = backupOnSaveMode
        self.snapshotModeEnabled = snapshotModeEnabled
        self.periodicBackupIntervalSeconds = min(max(periodicBackupIntervalSeconds, 1), 3600)
        self.useCustomBackupDirectory = useCustomBackupDirectory
        self.customBackupDirectory = customBackupDirectory
        self.additionalEdgeColumns = additionalEdgeColumns
        self.linePadding = max(0, min(5, linePadding))
        self.openDirectoryFollowsDocument = openDirectoryFollowsDocument
        self.defaultNewDocumentLanguageName = defaultNewDocumentLanguageName
        self.folderDropOpensAsWorkspace = folderDropOpensAsWorkspace
        self.folderDropRecursiveOpen = folderDropRecursiveOpen
        self.extraURLSchemes = extraURLSchemes
        self.newDocumentOnLaunch = newDocumentOnLaunch
        self.postItAlpha = max(0.2, min(1.0, postItAlpha))
        self.printLineNumbers = printLineNumbers
        self.autoCompleteMode = max(0, min(3, autoCompleteMode))
        self.autoCompleteChooseSingle = autoCompleteChooseSingle
        self.autoCompleteTABFillup = autoCompleteTABFillup
        self.autoCompleteEnterCommit = autoCompleteEnterCommit
        self.autoCompleteBrief = autoCompleteBrief
        self.inSelectionThreshold = max(1, inSelectionThreshold)
        self.tabbarDoubleClickClose = tabbarDoubleClickClose
        self.tabbarMaxLabelLength = max(0, tabbarMaxLabelLength)
        self.keepFindDialogOpen = keepFindDialogOpen
        self.findDialogTransparency = max(0, min(0.9, findDialogTransparency))
        self.printSettings = printSettings
        self.delimiterLeft = delimiterLeft
        self.delimiterRight = delimiterRight
        self.statusBarVisible = statusBarVisible
        self.shortTitle = shortTitle
        self.saveAllConfirm = saveAllConfirm
        self.autoCompleteIgnoreNumbers = autoCompleteIgnoreNumbers
        self.replaceDoesNotMove = replaceDoesNotMove
        self.fileChangeDetectionEnabled = fileChangeDetectionEnabled
        self.findDialogMonospace = findDialogMonospace
        self.copyLineWithoutSelection = copyLineWithoutSelection
        self.fillFindFromSelection = fillFindFromSelection
        self.autoSelectWordUnderCaret = autoSelectWordUnderCaret
        self.findInFilesIgnoreUnsaved = findInFilesIgnoreUnsaved
        self.smartHighlightUseFindSettings = smartHighlightUseFindSettings
        self.urlIndicatorStyle = max(0, min(2, urlIndicatorStyle))
        self.languageTabOverrides = languageTabOverrides
        self.tabbarLockDragDrop = tabbarLockDragDrop
        self.tabbarExitOnLastTab = tabbarExitOnLastTab
        self.htmlXmlCloseTagEnabled = htmlXmlCloseTagEnabled
        self.muteAllSounds = muteAllSounds
        self.selectedTextDragDrop = selectedTextDragDrop
        self.lineNumberDynamicWidth = lineNumberDynamicWidth
        self.columnSelectionToMultiEditing = columnSelectionToMultiEditing
        self.appearanceMode = max(0, min(2, appearanceMode))
        self.taskListCustomTags = taskListCustomTags
        self.toolbarVisible = toolbarVisible
        self.showBookmarkMargin = showBookmarkMargin
        self.confirmReplaceInAllDocs = confirmReplaceInAllDocs
        self.maxFindHistoryCount = max(1, min(50, maxFindHistoryCount))
        self.tabbarHide = tabbarHide
        self.reloadScrollToLastCaret = reloadScrollToLastCaret
        self.editorFontName = editorFontName
        self.editorFontBold = editorFontBold
        self.tabbarShowCloseButton = tabbarShowCloseButton
        self.trimTrailingSpacesOnSave = trimTrailingSpacesOnSave
        self.pasteConvertEndings = pasteConvertEndings
        self.caretStickyMode = max(0, min(2, caretStickyMode))
        self.enableCodeFolding = enableCodeFolding
        self.autoCompleteIgnoreCase = autoCompleteIgnoreCase
        self.whitespaceDisplayMode = max(0, min(3, whitespaceDisplayMode))
        self.bidiMode = max(0, min(2, bidiMode))
        self.smoothFont = smoothFont
        self.multiEditEnabled = multiEditEnabled
        self.multiPasteMode = max(0, min(1, multiPasteMode))
        self.indentGuideMode = max(0, min(3, indentGuideMode))
        self.wordWrapMode = max(0, min(3, wordWrapMode))
        self.tabbarCompact = tabbarCompact
        self.tabbarShowIndexNumbers = tabbarShowIndexNumbers
        self.zoomSyncToAllTabs = zoomSyncToAllTabs
        self.hideMenuShortcuts = hideMenuShortcuts
        self.scrollToLastLineOnMonitorReload = scrollToLastLineOnMonitorReload
        self.additionalSelAlpha = max(0, min(256, additionalSelAlpha))
        self.additionalCaretsBlink = additionalCaretsBlink
        self.additionalCaretsVisible = additionalCaretsVisible
        self.caretLineVisibleAlways = caretLineVisibleAlways
        self.whitespaceSize = max(1, min(5, whitespaceSize))
        self.selectionAlpha = max(0, min(256, selectionAlpha))
        self.controlCharDisplay = max(0, min(6, controlCharDisplay))
        self.openAnsiAsUtf8 = openAnsiAsUtf8
        self.xmlTagAttributeHighlight = xmlTagAttributeHighlight
        self.highlightNonHtmlZone = highlightNonHtmlZone
        self.defaultSaveDirectory = defaultSaveDirectory
        self.toolbarIconSizeStyle = max(0, min(1, toolbarIconSizeStyle))
        self.scintillaRenderingTechnology = max(0, min(1, scintillaRenderingTechnology))
        self.disableAdvancedScrolling = disableAdvancedScrolling
        self.rightClickKeepSelection = rightClickKeepSelection
        self.edgeMode = max(0, min(2, edgeMode))
        self.foldFlags = max(0, min(30, foldFlags))
    }

    /// Parse languageTabOverrides string into a dictionary.
    /// Format: "python:4s,html:2s,c:8t" → ["python": (4, spaces), "html": (2, spaces), "c": (8, tabs)]
    public func parsedLanguageTabOverrides() -> [String: (tabSize: Int, insertSpaces: Bool)] {
        var result: [String: (Int, Bool)] = [:]
        for entry in languageTabOverrides.split(separator: ",") {
            let parts = entry.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let lang = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
            let sizeStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !lang.isEmpty, !sizeStr.isEmpty else { continue }
            let usesSpaces = sizeStr.last?.lowercased() == "s"
            let usesTabs = sizeStr.last?.lowercased() == "t"
            guard usesSpaces || usesTabs else { continue }
            let numStr = String(sizeStr.dropLast())
            guard let size = Int(numStr), size >= 1, size <= 16 else { continue }
            result[lang] = (size, usesSpaces)
        }
        return result
    }

    /// Combined URL schemes: defaults + user-configured extras
    public var effectiveURLSchemes: [String] {
        let extras = extraURLSchemes.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if extras.isEmpty { return URLScanner.defaultSchemes }
        return URLScanner.defaultSchemes + extras.filter { !URLScanner.defaultSchemes.contains($0) }
    }

    public func withEditorFontSize(_ editorFontSize: Double) -> AppPreferences {
        copy(editorFontSize: editorFontSize)
    }

    public func withWrapsLines(_ wrapsLines: Bool) -> AppPreferences {
        copy(wrapsLines: wrapsLines)
    }

    /// Returns a copy of this AppPreferences with only searchMatchCase and searchWholeWord changed.
    public func withSearchOptions(_ options: TextSearch.Options) -> AppPreferences {
        copy(searchMatchCase: options.matchCase, searchWholeWord: options.wholeWord)
    }

    public func withCustomDateTimeFormat(_ customDateTimeFormat: String) -> AppPreferences {
        copy(customDateTimeFormat: customDateTimeFormat)
    }

    public func withSearchEngineChoice(_ searchEngineChoice: SearchEngineChoice) -> AppPreferences {
        copy(searchEngineChoice: searchEngineChoice)
    }

    public func withCustomSearchEngineURL(_ customSearchEngineURL: String) -> AppPreferences {
        copy(customSearchEngineURL: customSearchEngineURL)
    }

    public func withLocalizationFileName(_ localizationFileName: String) -> AppPreferences {
        copy(localizationFileName: localizationFileName)
    }

    private func copy(
        editorFontSize: Double? = nil,
        wrapsLines: Bool? = nil,
        searchMatchCase: Bool? = nil,
        searchWholeWord: Bool? = nil,
        customDateTimeFormat: String? = nil,
        searchEngineChoice: SearchEngineChoice? = nil,
        customSearchEngineURL: String? = nil,
        localizationFileName: String? = nil,
        tabSize: Int? = nil,
        insertSpacesInsteadOfTabs: Bool? = nil,
        smartHighlightMatchCase: Bool? = nil,
        smartHighlightWholeWord: Bool? = nil,
        caretWidth: Int? = nil,
        enableVirtualSpace: Bool? = nil,
        autoIndentMode: Int? = nil,
        fileAutoDetection: Int? = nil,
        updateSilently: Bool? = nil,
        showBookmarkMargin: Bool? = nil,
        largeFileSuppressAutoComplete: Bool? = nil,
        largeFileSuppressSmartHighlight: Bool? = nil,
        largeFileSuppressBraceMatch: Bool? = nil,
        largeFileSuppressWordWrap: Bool? = nil,
        largeFileSuppressSyntaxHighlight: Bool? = nil,
        confirmReplaceInAllDocs: Bool? = nil,
        maxFindHistoryCount: Int? = nil,
        tabbarHide: Bool? = nil,
        reloadScrollToLastCaret: Bool? = nil,
        editorFontName: String? = nil,
        editorFontBold: Bool? = nil,
        tabbarShowCloseButton: Bool? = nil,
        trimTrailingSpacesOnSave: Bool? = nil,
        pasteConvertEndings: Bool? = nil,
        caretStickyMode: Int? = nil,
        enableCodeFolding: Bool? = nil,
        autoCompleteIgnoreCase: Bool? = nil,
        whitespaceDisplayMode: Int? = nil,
        bidiMode: Int? = nil,
        smoothFont: Bool? = nil,
        multiEditEnabled: Bool? = nil,
        multiPasteMode: Int? = nil,
        indentGuideMode: Int? = nil,
        wordWrapMode: Int? = nil,
        tabbarCompact: Bool? = nil,
        tabbarShowIndexNumbers: Bool? = nil,
        zoomSyncToAllTabs: Bool? = nil,
        hideMenuShortcuts: Bool? = nil,
        scrollToLastLineOnMonitorReload: Bool? = nil,
        additionalSelAlpha: Int? = nil,
        additionalCaretsBlink: Bool? = nil,
        additionalCaretsVisible: Bool? = nil,
        caretLineVisibleAlways: Bool? = nil,
        whitespaceSize: Int? = nil,
        selectionAlpha: Int? = nil,
        controlCharDisplay: Int? = nil,
        openAnsiAsUtf8: Bool? = nil,
        xmlTagAttributeHighlight: Bool? = nil,
        highlightNonHtmlZone: Bool? = nil,
        defaultSaveDirectory: String? = nil,
        toolbarIconSizeStyle: Int? = nil,
        scintillaRenderingTechnology: Int? = nil,
        disableAdvancedScrolling: Bool? = nil,
        rightClickKeepSelection: Bool? = nil,
        edgeMode: Int? = nil,
        foldFlags: Int? = nil
    ) -> AppPreferences {
        AppPreferences(
            editorFontSize: editorFontSize ?? self.editorFontSize,
            wrapsLines: wrapsLines ?? self.wrapsLines,
            searchMatchCase: searchMatchCase ?? self.searchMatchCase,
            searchWholeWord: searchWholeWord ?? self.searchWholeWord,
            customDateTimeFormat: customDateTimeFormat ?? self.customDateTimeFormat,
            searchEngineChoice: searchEngineChoice ?? self.searchEngineChoice,
            customSearchEngineURL: customSearchEngineURL ?? self.customSearchEngineURL,
            localizationFileName: localizationFileName ?? self.localizationFileName,
            showWhitespace: showWhitespace,
            showEOL: showEOL,
            showIndentGuides: showIndentGuides,
            highlightCurrentLine: highlightCurrentLine,
            showWrapSymbol: showWrapSymbol,
            showChangeHistory: showChangeHistory,
            tabSize: tabSize ?? self.tabSize,
            insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs ?? self.insertSpacesInsteadOfTabs,
            showLineNumberMargin: showLineNumberMargin,
            showEdgeLine: showEdgeLine,
            edgeLineColumn: edgeLineColumn,
            enableAutoPair: enableAutoPair,
            autoPairParentheses: autoPairParentheses,
            autoPairBrackets: autoPairBrackets,
            autoPairCurlyBrackets: autoPairCurlyBrackets,
            autoPairSingleQuotes: autoPairSingleQuotes,
            autoPairDoubleQuotes: autoPairDoubleQuotes,
            enableXmlTagMatch: enableXmlTagMatch,
            enableClickableLinks: enableClickableLinks,
            defaultNewDocumentEncoding: defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaultNewDocumentLineEnding,
            rememberLastSession: rememberLastSession,
            showNpcCharacters: showNpcCharacters,
            smartHighlightMatchCase: smartHighlightMatchCase ?? self.smartHighlightMatchCase,
            smartHighlightWholeWord: smartHighlightWholeWord ?? self.smartHighlightWholeWord,
            markAllMatchCase: markAllMatchCase,
            markAllWholeWord: markAllWholeWord,
            langMenuCompact: langMenuCompact,
            caretWidth: caretWidth ?? self.caretWidth,
            enableVirtualSpace: enableVirtualSpace ?? self.enableVirtualSpace,
            backspaceUnindents: backspaceUnindents,
            autoIndent: autoIndent,
            autoIndentMode: autoIndentMode ?? self.autoIndentMode,
            fileAutoDetection: fileAutoDetection ?? self.fileAutoDetection,
            updateSilently: updateSilently ?? self.updateSilently,
            largeFileSizeMB: largeFileSizeMB,
            largeFileSuppressAutoComplete: largeFileSuppressAutoComplete ?? self.largeFileSuppressAutoComplete,
            largeFileSuppressSmartHighlight: largeFileSuppressSmartHighlight ?? self.largeFileSuppressSmartHighlight,
            largeFileSuppressBraceMatch: largeFileSuppressBraceMatch ?? self.largeFileSuppressBraceMatch,
            largeFileSuppressWordWrap: largeFileSuppressWordWrap ?? self.largeFileSuppressWordWrap,
            largeFileSuppressSyntaxHighlight: largeFileSuppressSyntaxHighlight ?? self.largeFileSuppressSyntaxHighlight,
            scrollBeyondLastLine: scrollBeyondLastLine,
            autoCompleteFromNthChar: autoCompleteFromNthChar,
            caretNoBlink: caretNoBlink,
            caretBlinkRate: caretBlinkRate,
            currentLineFrameWidth: currentLineFrameWidth,
            lineWrapIndent: lineWrapIndent,
            foldMarginStyle: foldMarginStyle,
            useFirstLineAsTabName: useFirstLineAsTabName,
            recentFilesMaxCount: recentFilesMaxCount,
            recentFilesShowFullPath: recentFilesShowFullPath,
            recentFilesInSubmenu: recentFilesInSubmenu,
            recentFilesCustomDisplayLength: recentFilesCustomDisplayLength,
            noCheckRecentAtLaunch: noCheckRecentAtLaunch,
            keepAbsentFilesInSession: keepAbsentFilesInSession,
            autoReloadOnExternalChange: autoReloadOnExternalChange,
            backupOnSaveMode: backupOnSaveMode,
            snapshotModeEnabled: snapshotModeEnabled,
            periodicBackupIntervalSeconds: periodicBackupIntervalSeconds,
            useCustomBackupDirectory: useCustomBackupDirectory,
            customBackupDirectory: customBackupDirectory,
            additionalEdgeColumns: additionalEdgeColumns,
            linePadding: linePadding,
            openDirectoryFollowsDocument: openDirectoryFollowsDocument,
            defaultNewDocumentLanguageName: defaultNewDocumentLanguageName,
            folderDropOpensAsWorkspace: folderDropOpensAsWorkspace,
            folderDropRecursiveOpen: folderDropRecursiveOpen,
            extraURLSchemes: extraURLSchemes,
            newDocumentOnLaunch: newDocumentOnLaunch,
            postItAlpha: postItAlpha,
            printLineNumbers: printLineNumbers,
            autoCompleteMode: autoCompleteMode,
            autoCompleteChooseSingle: autoCompleteChooseSingle,
            autoCompleteTABFillup: autoCompleteTABFillup,
            autoCompleteEnterCommit: autoCompleteEnterCommit,
            autoCompleteBrief: autoCompleteBrief,
            inSelectionThreshold: inSelectionThreshold,
            tabbarDoubleClickClose: tabbarDoubleClickClose,
            tabbarMaxLabelLength: tabbarMaxLabelLength,
            keepFindDialogOpen: keepFindDialogOpen,
            findDialogTransparency: findDialogTransparency,
            printSettings: printSettings,
            delimiterLeft: delimiterLeft,
            delimiterRight: delimiterRight,
            statusBarVisible: statusBarVisible,
            shortTitle: shortTitle,
            saveAllConfirm: saveAllConfirm,
            autoCompleteIgnoreNumbers: autoCompleteIgnoreNumbers,
            replaceDoesNotMove: replaceDoesNotMove,
            fileChangeDetectionEnabled: fileChangeDetectionEnabled,
            findDialogMonospace: findDialogMonospace,
            copyLineWithoutSelection: copyLineWithoutSelection,
            fillFindFromSelection: fillFindFromSelection,
            autoSelectWordUnderCaret: autoSelectWordUnderCaret,
            findInFilesIgnoreUnsaved: findInFilesIgnoreUnsaved,
            smartHighlightUseFindSettings: smartHighlightUseFindSettings,
            urlIndicatorStyle: urlIndicatorStyle,
            languageTabOverrides: languageTabOverrides,
            tabbarLockDragDrop: tabbarLockDragDrop,
            tabbarExitOnLastTab: tabbarExitOnLastTab,
            htmlXmlCloseTagEnabled: htmlXmlCloseTagEnabled,
            muteAllSounds: muteAllSounds,
            selectedTextDragDrop: selectedTextDragDrop,
            lineNumberDynamicWidth: lineNumberDynamicWidth,
            columnSelectionToMultiEditing: columnSelectionToMultiEditing,
            taskListCustomTags: taskListCustomTags,
            toolbarVisible: toolbarVisible,
            showBookmarkMargin: showBookmarkMargin ?? self.showBookmarkMargin,
            confirmReplaceInAllDocs: confirmReplaceInAllDocs ?? self.confirmReplaceInAllDocs,
            maxFindHistoryCount: maxFindHistoryCount ?? self.maxFindHistoryCount,
            tabbarHide: tabbarHide ?? self.tabbarHide,
            reloadScrollToLastCaret: reloadScrollToLastCaret ?? self.reloadScrollToLastCaret,
            editorFontName: editorFontName ?? self.editorFontName,
            editorFontBold: editorFontBold ?? self.editorFontBold,
            tabbarShowCloseButton: tabbarShowCloseButton ?? self.tabbarShowCloseButton,
            trimTrailingSpacesOnSave: trimTrailingSpacesOnSave ?? self.trimTrailingSpacesOnSave,
            pasteConvertEndings: pasteConvertEndings ?? self.pasteConvertEndings,
            caretStickyMode: caretStickyMode ?? self.caretStickyMode,
            enableCodeFolding: enableCodeFolding ?? self.enableCodeFolding,
            autoCompleteIgnoreCase: autoCompleteIgnoreCase ?? self.autoCompleteIgnoreCase,
            whitespaceDisplayMode: whitespaceDisplayMode ?? self.whitespaceDisplayMode,
            bidiMode: bidiMode ?? self.bidiMode,
            smoothFont: smoothFont ?? self.smoothFont,
            multiEditEnabled: multiEditEnabled ?? self.multiEditEnabled,
            multiPasteMode: multiPasteMode ?? self.multiPasteMode,
            indentGuideMode: indentGuideMode ?? self.indentGuideMode,
            wordWrapMode: wordWrapMode ?? self.wordWrapMode,
            tabbarCompact: tabbarCompact ?? self.tabbarCompact,
            tabbarShowIndexNumbers: tabbarShowIndexNumbers ?? self.tabbarShowIndexNumbers,
            zoomSyncToAllTabs: zoomSyncToAllTabs ?? self.zoomSyncToAllTabs,
            hideMenuShortcuts: hideMenuShortcuts ?? self.hideMenuShortcuts,
            scrollToLastLineOnMonitorReload: scrollToLastLineOnMonitorReload ?? self.scrollToLastLineOnMonitorReload,
            additionalSelAlpha: additionalSelAlpha ?? self.additionalSelAlpha,
            additionalCaretsBlink: additionalCaretsBlink ?? self.additionalCaretsBlink,
            additionalCaretsVisible: additionalCaretsVisible ?? self.additionalCaretsVisible,
            caretLineVisibleAlways: caretLineVisibleAlways ?? self.caretLineVisibleAlways,
            whitespaceSize: whitespaceSize ?? self.whitespaceSize,
            selectionAlpha: selectionAlpha ?? self.selectionAlpha,
            controlCharDisplay: controlCharDisplay ?? self.controlCharDisplay,
            openAnsiAsUtf8: openAnsiAsUtf8 ?? self.openAnsiAsUtf8,
            xmlTagAttributeHighlight: xmlTagAttributeHighlight ?? self.xmlTagAttributeHighlight,
            highlightNonHtmlZone: highlightNonHtmlZone ?? self.highlightNonHtmlZone,
            defaultSaveDirectory: defaultSaveDirectory ?? self.defaultSaveDirectory,
            toolbarIconSizeStyle: toolbarIconSizeStyle ?? self.toolbarIconSizeStyle,
            scintillaRenderingTechnology: scintillaRenderingTechnology ?? self.scintillaRenderingTechnology,
            disableAdvancedScrolling: disableAdvancedScrolling ?? self.disableAdvancedScrolling,
            rightClickKeepSelection: rightClickKeepSelection ?? self.rightClickKeepSelection,
            edgeMode: edgeMode ?? self.edgeMode,
            foldFlags: foldFlags ?? self.foldFlags
        )
    }

    public func withViewToggles(
        showWhitespace: Bool,
        showEOL: Bool,
        showIndentGuides: Bool,
        highlightCurrentLine: Bool,
        showWrapSymbol: Bool,
        showChangeHistory: Bool,
        showLineNumberMargin: Bool,
        showEdgeLine: Bool,
        edgeLineColumn: Int,
        enableAutoPair: Bool,
        enableXmlTagMatch: Bool,
        enableClickableLinks: Bool,
        showNpcCharacters: Bool,
        showBookmarkMargin: Bool
    ) -> AppPreferences {
        // Use copy() to ensure all newer fields are preserved
        AppPreferences(
            editorFontSize: editorFontSize,
            wrapsLines: wrapsLines,
            searchMatchCase: searchMatchCase,
            searchWholeWord: searchWholeWord,
            customDateTimeFormat: customDateTimeFormat,
            searchEngineChoice: searchEngineChoice,
            customSearchEngineURL: customSearchEngineURL,
            localizationFileName: localizationFileName,
            showWhitespace: showWhitespace,
            showEOL: showEOL,
            showIndentGuides: showIndentGuides,
            highlightCurrentLine: highlightCurrentLine,
            showWrapSymbol: showWrapSymbol,
            showChangeHistory: showChangeHistory,
            tabSize: tabSize,
            insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs,
            showLineNumberMargin: showLineNumberMargin,
            showEdgeLine: showEdgeLine,
            edgeLineColumn: edgeLineColumn,
            enableAutoPair: enableAutoPair,
            autoPairParentheses: autoPairParentheses,
            autoPairBrackets: autoPairBrackets,
            autoPairCurlyBrackets: autoPairCurlyBrackets,
            autoPairSingleQuotes: autoPairSingleQuotes,
            autoPairDoubleQuotes: autoPairDoubleQuotes,
            customMatchedPairs: customMatchedPairs,
            enableXmlTagMatch: enableXmlTagMatch,
            enableClickableLinks: enableClickableLinks,
            defaultNewDocumentEncoding: defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaultNewDocumentLineEnding,
            rememberLastSession: rememberLastSession,
            showNpcCharacters: showNpcCharacters,
            smartHighlightMatchCase: smartHighlightMatchCase,
            smartHighlightWholeWord: smartHighlightWholeWord,
            markAllMatchCase: markAllMatchCase,
            markAllWholeWord: markAllWholeWord,
            langMenuCompact: langMenuCompact,
            caretWidth: caretWidth,
            enableVirtualSpace: enableVirtualSpace,
            backspaceUnindents: backspaceUnindents,
            autoIndent: autoIndent,
            autoIndentMode: autoIndentMode,
            fileAutoDetection: fileAutoDetection,
            updateSilently: updateSilently,
            largeFileSizeMB: largeFileSizeMB,
            largeFileSuppressAutoComplete: largeFileSuppressAutoComplete,
            largeFileSuppressSmartHighlight: largeFileSuppressSmartHighlight,
            largeFileSuppressBraceMatch: largeFileSuppressBraceMatch,
            largeFileSuppressWordWrap: largeFileSuppressWordWrap,
            largeFileSuppressSyntaxHighlight: largeFileSuppressSyntaxHighlight,
            scrollBeyondLastLine: scrollBeyondLastLine,
            autoCompleteFromNthChar: autoCompleteFromNthChar,
            caretNoBlink: caretNoBlink,
            caretBlinkRate: caretBlinkRate,
            currentLineFrameWidth: currentLineFrameWidth,
            lineWrapIndent: lineWrapIndent,
            foldMarginStyle: foldMarginStyle,
            useFirstLineAsTabName: useFirstLineAsTabName,
            recentFilesMaxCount: recentFilesMaxCount,
            recentFilesShowFullPath: recentFilesShowFullPath,
            recentFilesInSubmenu: recentFilesInSubmenu,
            recentFilesCustomDisplayLength: recentFilesCustomDisplayLength,
            noCheckRecentAtLaunch: noCheckRecentAtLaunch,
            keepAbsentFilesInSession: keepAbsentFilesInSession,
            autoReloadOnExternalChange: autoReloadOnExternalChange,
            backupOnSaveMode: backupOnSaveMode,
            snapshotModeEnabled: snapshotModeEnabled,
            periodicBackupIntervalSeconds: periodicBackupIntervalSeconds,
            useCustomBackupDirectory: useCustomBackupDirectory,
            customBackupDirectory: customBackupDirectory,
            additionalEdgeColumns: additionalEdgeColumns,
            linePadding: linePadding,
            openDirectoryFollowsDocument: openDirectoryFollowsDocument,
            defaultNewDocumentLanguageName: defaultNewDocumentLanguageName,
            folderDropOpensAsWorkspace: folderDropOpensAsWorkspace,
            folderDropRecursiveOpen: folderDropRecursiveOpen,
            extraURLSchemes: extraURLSchemes,
            newDocumentOnLaunch: newDocumentOnLaunch,
            postItAlpha: postItAlpha,
            printLineNumbers: printLineNumbers,
            autoCompleteMode: autoCompleteMode,
            autoCompleteChooseSingle: autoCompleteChooseSingle,
            autoCompleteTABFillup: autoCompleteTABFillup,
            autoCompleteEnterCommit: autoCompleteEnterCommit,
            autoCompleteBrief: autoCompleteBrief,
            inSelectionThreshold: inSelectionThreshold,
            tabbarDoubleClickClose: tabbarDoubleClickClose,
            tabbarMaxLabelLength: tabbarMaxLabelLength,
            keepFindDialogOpen: keepFindDialogOpen,
            findDialogTransparency: findDialogTransparency,
            printSettings: printSettings,
            delimiterLeft: delimiterLeft,
            delimiterRight: delimiterRight,
            statusBarVisible: statusBarVisible,
            shortTitle: shortTitle,
            saveAllConfirm: saveAllConfirm,
            autoCompleteIgnoreNumbers: autoCompleteIgnoreNumbers,
            replaceDoesNotMove: replaceDoesNotMove,
            fileChangeDetectionEnabled: fileChangeDetectionEnabled,
            findDialogMonospace: findDialogMonospace,
            copyLineWithoutSelection: copyLineWithoutSelection,
            fillFindFromSelection: fillFindFromSelection,
            autoSelectWordUnderCaret: autoSelectWordUnderCaret,
            findInFilesIgnoreUnsaved: findInFilesIgnoreUnsaved,
            smartHighlightUseFindSettings: smartHighlightUseFindSettings,
            urlIndicatorStyle: urlIndicatorStyle,
            languageTabOverrides: languageTabOverrides,
            tabbarLockDragDrop: tabbarLockDragDrop,
            tabbarExitOnLastTab: tabbarExitOnLastTab,
            htmlXmlCloseTagEnabled: htmlXmlCloseTagEnabled,
            muteAllSounds: muteAllSounds,
            selectedTextDragDrop: selectedTextDragDrop,
            lineNumberDynamicWidth: lineNumberDynamicWidth,
            columnSelectionToMultiEditing: columnSelectionToMultiEditing,
            taskListCustomTags: taskListCustomTags,
            toolbarVisible: toolbarVisible,
            showBookmarkMargin: showBookmarkMargin,
            confirmReplaceInAllDocs: confirmReplaceInAllDocs,
            maxFindHistoryCount: maxFindHistoryCount,
            tabbarHide: tabbarHide,
            reloadScrollToLastCaret: reloadScrollToLastCaret,
            editorFontName: editorFontName,
            editorFontBold: editorFontBold,
            tabbarShowCloseButton: tabbarShowCloseButton,
            trimTrailingSpacesOnSave: trimTrailingSpacesOnSave,
            pasteConvertEndings: pasteConvertEndings,
            caretStickyMode: caretStickyMode,
            enableCodeFolding: enableCodeFolding,
            autoCompleteIgnoreCase: autoCompleteIgnoreCase,
            whitespaceDisplayMode: whitespaceDisplayMode,
            bidiMode: bidiMode,
            smoothFont: smoothFont,
            multiEditEnabled: multiEditEnabled,
            multiPasteMode: multiPasteMode,
            indentGuideMode: indentGuideMode,
            wordWrapMode: wordWrapMode,
            tabbarCompact: tabbarCompact,
            tabbarShowIndexNumbers: tabbarShowIndexNumbers,
            zoomSyncToAllTabs: zoomSyncToAllTabs,
            hideMenuShortcuts: hideMenuShortcuts,
            scrollToLastLineOnMonitorReload: scrollToLastLineOnMonitorReload,
            openAnsiAsUtf8: openAnsiAsUtf8,
            xmlTagAttributeHighlight: xmlTagAttributeHighlight,
            highlightNonHtmlZone: highlightNonHtmlZone,
            defaultSaveDirectory: defaultSaveDirectory,
            toolbarIconSizeStyle: toolbarIconSizeStyle,
            scintillaRenderingTechnology: scintillaRenderingTechnology,
            disableAdvancedScrolling: disableAdvancedScrolling,
            rightClickKeepSelection: rightClickKeepSelection,
            edgeMode: edgeMode,
            foldFlags: foldFlags
        )
    }

    public func withBookmarkMarginVisible(_ visible: Bool) -> AppPreferences {
        copy(showBookmarkMargin: visible)
    }

    public func withSmartHighlightOptions(matchCase: Bool, wholeWord: Bool) -> AppPreferences {
        copy(smartHighlightMatchCase: matchCase, smartHighlightWholeWord: wholeWord)
    }

    public func withCaretSettings(width: Int, virtualSpace: Bool) -> AppPreferences {
        copy(caretWidth: width, enableVirtualSpace: virtualSpace)
    }

    public func withTabSize(_ tabSize: Int) -> AppPreferences {
        copy(tabSize: tabSize)
    }

    public func withInsertSpacesInsteadOfTabs(_ insertSpacesInsteadOfTabs: Bool) -> AppPreferences {
        copy(insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs)
    }

    public func withLargeFileSuppressAutoComplete(_ suppress: Bool) -> AppPreferences {
        copy(largeFileSuppressAutoComplete: suppress)
    }

    public func withLargeFileSuppressSmartHighlight(_ suppress: Bool) -> AppPreferences {
        copy(largeFileSuppressSmartHighlight: suppress)
    }

    public func withLargeFileSuppressBraceMatch(_ suppress: Bool) -> AppPreferences {
        copy(largeFileSuppressBraceMatch: suppress)
    }

    public func withLargeFileSuppressWordWrap(_ suppress: Bool) -> AppPreferences {
        copy(largeFileSuppressWordWrap: suppress)
    }

    public func withLargeFileSuppressSyntaxHighlight(_ suppress: Bool) -> AppPreferences {
        copy(largeFileSuppressSyntaxHighlight: suppress)
    }

    public func withConfirmReplaceInAllDocs(_ confirm: Bool) -> AppPreferences {
        copy(confirmReplaceInAllDocs: confirm)
    }

    public func withMaxFindHistoryCount(_ count: Int) -> AppPreferences {
        copy(maxFindHistoryCount: count)
    }

    public func withTabbarHide(_ hide: Bool) -> AppPreferences {
        copy(tabbarHide: hide)
    }

    public func withReloadScrollToLastCaret(_ scroll: Bool) -> AppPreferences {
        copy(reloadScrollToLastCaret: scroll)
    }

    public func withEditorFontName(_ name: String) -> AppPreferences {
        copy(editorFontName: name)
    }

    public func withEditorFontBold(_ bold: Bool) -> AppPreferences {
        copy(editorFontBold: bold)
    }

    public func withTabbarShowCloseButton(_ show: Bool) -> AppPreferences {
        copy(tabbarShowCloseButton: show)
    }

    public func withTrimTrailingSpacesOnSave(_ trim: Bool) -> AppPreferences {
        copy(trimTrailingSpacesOnSave: trim)
    }

    public func withPasteConvertEndings(_ convert: Bool) -> AppPreferences {
        copy(pasteConvertEndings: convert)
    }

    public func withCaretStickyMode(_ mode: Int) -> AppPreferences {
        copy(caretStickyMode: mode)
    }

    public func withEnableCodeFolding(_ enabled: Bool) -> AppPreferences {
        copy(enableCodeFolding: enabled)
    }

    public func withAutoCompleteIgnoreCase(_ ignore: Bool) -> AppPreferences {
        copy(autoCompleteIgnoreCase: ignore)
    }

    public func withWhitespaceDisplayMode(_ mode: Int) -> AppPreferences {
        copy(whitespaceDisplayMode: max(0, min(3, mode)))
    }

    public func withBidiMode(_ mode: Int) -> AppPreferences {
        copy(bidiMode: max(0, min(2, mode)))
    }

    public func withSmoothFont(_ on: Bool) -> AppPreferences {
        copy(smoothFont: on)
    }

    public func withMultiEditEnabled(_ on: Bool) -> AppPreferences {
        copy(multiEditEnabled: on)
    }

    public func withMultiPasteMode(_ mode: Int) -> AppPreferences {
        copy(multiPasteMode: max(0, min(1, mode)))
    }

    public func withIndentGuideMode(_ mode: Int) -> AppPreferences {
        copy(indentGuideMode: max(0, min(3, mode)))
    }

    public func withWordWrapMode(_ mode: Int) -> AppPreferences {
        copy(wordWrapMode: max(0, min(3, mode)))
    }

    public func withTabbarCompact(_ on: Bool) -> AppPreferences {
        copy(tabbarCompact: on)
    }

    public func withTabbarShowIndexNumbers(_ on: Bool) -> AppPreferences {
        copy(tabbarShowIndexNumbers: on)
    }

    public func withZoomSyncToAllTabs(_ on: Bool) -> AppPreferences {
        copy(zoomSyncToAllTabs: on)
    }

    public func withHideMenuShortcuts(_ on: Bool) -> AppPreferences {
        copy(hideMenuShortcuts: on)
    }

    public func withScrollToLastLineOnMonitorReload(_ on: Bool) -> AppPreferences {
        copy(scrollToLastLineOnMonitorReload: on)
    }

    public func withAdditionalSelAlpha(_ alpha: Int) -> AppPreferences {
        copy(additionalSelAlpha: max(0, min(256, alpha)))
    }

    public func withAdditionalCaretsBlink(_ on: Bool) -> AppPreferences {
        copy(additionalCaretsBlink: on)
    }

    public func withAdditionalCaretsVisible(_ on: Bool) -> AppPreferences {
        copy(additionalCaretsVisible: on)
    }

    public func withCaretLineVisibleAlways(_ on: Bool) -> AppPreferences {
        copy(caretLineVisibleAlways: on)
    }

    public func withWhitespaceSize(_ size: Int) -> AppPreferences {
        copy(whitespaceSize: max(1, min(5, size)))
    }

    public func withSelectionAlpha(_ alpha: Int) -> AppPreferences {
        copy(selectionAlpha: max(0, min(256, alpha)))
    }

    public func withControlCharDisplay(_ mode: Int) -> AppPreferences {
        copy(controlCharDisplay: max(0, min(6, mode)))
    }

    public func withOpenAnsiAsUtf8(_ on: Bool) -> AppPreferences {
        copy(openAnsiAsUtf8: on)
    }

    public func withXmlTagAttributeHighlight(_ on: Bool) -> AppPreferences {
        copy(xmlTagAttributeHighlight: on)
    }

    public func withHighlightNonHtmlZone(_ on: Bool) -> AppPreferences {
        copy(highlightNonHtmlZone: on)
    }

    public func withDefaultSaveDirectory(_ dir: String) -> AppPreferences {
        copy(defaultSaveDirectory: dir)
    }

    public func withToolbarIconSizeStyle(_ style: Int) -> AppPreferences {
        copy(toolbarIconSizeStyle: max(0, min(1, style)))
    }

    public func withScintillaRenderingTechnology(_ tech: Int) -> AppPreferences {
        copy(scintillaRenderingTechnology: max(0, min(1, tech)))
    }

    public func withDisableAdvancedScrolling(_ on: Bool) -> AppPreferences {
        copy(disableAdvancedScrolling: on)
    }

    public func withRightClickKeepSelection(_ on: Bool) -> AppPreferences {
        copy(rightClickKeepSelection: on)
    }

    public func withEdgeMode(_ mode: Int) -> AppPreferences {
        copy(edgeMode: max(0, min(2, mode)))
    }

    public func withFoldFlags(_ flags: Int) -> AppPreferences {
        copy(foldFlags: max(0, min(30, flags)))
    }

    public func withAutoIndentMode(_ mode: Int) -> AppPreferences {
        copy(autoIndentMode: max(0, min(2, mode)))
    }

    public func withFileAutoDetection(_ mode: Int) -> AppPreferences {
        copy(fileAutoDetection: max(0, min(2, mode)))
    }

    public func withUpdateSilently(_ on: Bool) -> AppPreferences {
        copy(updateSilently: on)
    }
}

public final class PreferencesStore {
    private enum Key {
        static let editorFontSize = "notepadMac.editorFontSize"
        static let wrapsLines = "notepadMac.wrapsLines"
        static let searchMatchCase = "notepadMac.searchMatchCase"
        static let searchWholeWord = "notepadMac.searchWholeWord"
        static let customDateTimeFormat = "notepadMac.customDateTimeFormat"
        static let searchEngineChoice = "notepadMac.searchEngineChoice"
        static let customSearchEngineURL = "notepadMac.customSearchEngineURL"
        static let localizationFileName = "notepadMac.localizationFileName"
        static let showWhitespace = "notepadMac.showWhitespace"
        static let showEOL = "notepadMac.showEOL"
        static let showIndentGuides = "notepadMac.showIndentGuides"
        static let highlightCurrentLine = "notepadMac.highlightCurrentLine"
        static let showWrapSymbol = "notepadMac.showWrapSymbol"
        static let showChangeHistory = "notepadMac.showChangeHistory"
        static let tabSize = "notepadMac.tabSize"
        static let insertSpacesInsteadOfTabs = "notepadMac.insertSpacesInsteadOfTabs"
        static let showLineNumberMargin = "notepadMac.showLineNumberMargin"
        static let showEdgeLine = "notepadMac.showEdgeLine"
        static let edgeLineColumn = "notepadMac.edgeLineColumn"
        static let enableAutoPair = "notepadMac.enableAutoPair"
        static let autoPairParentheses = "notepadMac.autoPairParentheses"
        static let autoPairBrackets = "notepadMac.autoPairBrackets"
        static let autoPairCurlyBrackets = "notepadMac.autoPairCurlyBrackets"
        static let autoPairSingleQuotes = "notepadMac.autoPairSingleQuotes"
        static let autoPairDoubleQuotes = "notepadMac.autoPairDoubleQuotes"
        static let customMatchedPairs = "notepadMac.customMatchedPairs"
        static let enableXmlTagMatch = "notepadMac.enableXmlTagMatch"
        static let enableClickableLinks = "notepadMac.enableClickableLinks"
        static let defaultNewDocumentEncoding = "notepadMac.defaultNewDocumentEncoding"
        static let defaultNewDocumentLineEnding = "notepadMac.defaultNewDocumentLineEnding"
        static let rememberLastSession = "notepadMac.rememberLastSession"
        static let showNpcCharacters = "notepadMac.showNpcCharacters"
        static let smartHighlightMatchCase = "notepadMac.smartHighlightMatchCase"
        static let smartHighlightWholeWord = "notepadMac.smartHighlightWholeWord"
        static let markAllMatchCase = "notepadMac.markAllMatchCase"
        static let markAllWholeWord = "notepadMac.markAllWholeWord"
        static let langMenuCompact = "notepadMac.langMenuCompact"
        static let caretWidth = "notepadMac.caretWidth"
        static let enableVirtualSpace = "notepadMac.enableVirtualSpace"
        static let backspaceUnindents = "notepadMac.backspaceUnindents"
        static let autoIndent = "notepadMac.autoIndent"
        static let autoIndentMode = "notepadMac.autoIndentMode"
        static let fileAutoDetection = "notepadMac.fileAutoDetection"
        static let updateSilently = "notepadMac.updateSilently"
        static let largeFileSizeMB = "notepadMac.largeFileSizeMB"
        static let largeFileSuppressAutoComplete = "notepadMac.largeFileSuppressAutoComplete"
        static let largeFileSuppressSmartHighlight = "notepadMac.largeFileSuppressSmartHighlight"
        static let largeFileSuppressBraceMatch = "notepadMac.largeFileSuppressBraceMatch"
        static let largeFileSuppressWordWrap = "notepadMac.largeFileSuppressWordWrap"
        static let largeFileSuppressSyntaxHighlight = "notepadMac.largeFileSuppressSyntaxHighlight"
        static let scrollBeyondLastLine = "notepadMac.scrollBeyondLastLine"
        static let autoCompleteFromNthChar = "notepadMac.autoCompleteFromNthChar"
        static let caretNoBlink = "notepadMac.caretNoBlink"
        static let caretBlinkRate = "notepadMac.caretBlinkRate"
        static let currentLineFrameWidth = "notepadMac.currentLineFrameWidth"
        static let lineWrapIndent = "notepadMac.lineWrapIndent"
        static let foldMarginStyle = "notepadMac.foldMarginStyle"
        static let useFirstLineAsTabName = "notepadMac.useFirstLineAsTabName"
        static let recentFilesMaxCount = "notepadMac.recentFilesMaxCount"
        static let recentFilesShowFullPath = "notepadMac.recentFilesShowFullPath"
        static let recentFilesInSubmenu = "notepadMac.recentFilesInSubmenu"
        static let recentFilesCustomDisplayLength = "notepadMac.recentFilesCustomDisplayLength"
        static let noCheckRecentAtLaunch = "notepadMac.noCheckRecentAtLaunch"
        static let keepAbsentFilesInSession = "notepadMac.keepAbsentFilesInSession"
        static let autoReloadOnExternalChange = "notepadMac.autoReloadOnExternalChange"
        static let backupOnSave = "notepadMac.backupOnSave"
        static let backupOnSaveMode = "notepadMac.backupOnSaveMode"
        static let snapshotModeEnabled = "notepadMac.snapshotModeEnabled"
        static let periodicBackupIntervalSeconds = "notepadMac.periodicBackupIntervalSeconds"
        static let useCustomBackupDirectory = "notepadMac.useCustomBackupDirectory"
        static let customBackupDirectory = "notepadMac.customBackupDirectory"
        static let additionalEdgeColumns = "notepadMac.additionalEdgeColumns"
        static let linePadding = "notepadMac.linePadding"
        static let openDirectoryFollowsDocument = "notepadMac.openDirectoryFollowsDocument"
        static let defaultNewDocumentLanguageName = "notepadMac.defaultNewDocumentLanguageName"
        static let folderDropOpensAsWorkspace = "notepadMac.folderDropOpensAsWorkspace"
        static let folderDropRecursiveOpen = "notepadMac.folderDropRecursiveOpen"
        static let extraURLSchemes = "notepadMac.extraURLSchemes"
        static let newDocumentOnLaunch = "notepadMac.newDocumentOnLaunch"
        static let postItAlpha = "notepadMac.postItAlpha"
        static let printLineNumbers = "notepadMac.printLineNumbers"
        static let autoCompleteMode = "notepadMac.autoCompleteMode"
        static let autoCompleteChooseSingle = "notepadMac.autoCompleteChooseSingle"
        static let autoCompleteTABFillup = "notepadMac.autoCompleteTABFillup"
        static let autoCompleteEnterCommit = "notepadMac.autoCompleteEnterCommit"
        static let autoCompleteBrief = "notepadMac.autoCompleteBrief"
        static let inSelectionThreshold = "notepadMac.inSelectionThreshold"
        static let tabbarDoubleClickClose = "notepadMac.tabbarDoubleClickClose"
        static let tabbarMaxLabelLength = "notepadMac.tabbarMaxLabelLength"
        static let keepFindDialogOpen = "notepadMac.keepFindDialogOpen"
        static let findDialogTransparency = "notepadMac.findDialogTransparency"
        static let printSettings = "notepadMac.printSettings"
        static let delimiterLeft = "notepadMac.delimiterLeft"
        static let delimiterRight = "notepadMac.delimiterRight"
        static let statusBarVisible = "notepadMac.statusBarVisible"
        static let shortTitle = "notepadMac.shortTitle"
        static let saveAllConfirm = "notepadMac.saveAllConfirm"
        static let autoCompleteIgnoreNumbers = "notepadMac.autoCompleteIgnoreNumbers"
        static let replaceDoesNotMove = "notepadMac.replaceDoesNotMove"
        static let disabledNativePluginIdentifiers = "notepadMac.disabledNativePluginIdentifiers"
        static let findHistory = "notepadMac.findHistory"
        static let replaceHistory = "notepadMac.replaceHistory"
        static let findSearchMode = "notepadMac.find.searchMode"
        static let findDotMatchesNewline = "notepadMac.find.dotMatchesNewline"
        static let findWrapAround = "notepadMac.find.wrapAround"
        static let fileChangeDetectionEnabled = "notepadMac.fileChangeDetectionEnabled"
        static let findDialogMonospace = "notepadMac.findDialogMonospace"
        static let copyLineWithoutSelection = "notepadMac.copyLineWithoutSelection"
        static let fillFindFromSelection = "notepadMac.fillFindFromSelection"
        static let autoSelectWordUnderCaret = "notepadMac.autoSelectWordUnderCaret"
        static let findInFilesIgnoreUnsaved = "notepadMac.findInFilesIgnoreUnsaved"
        static let smartHighlightUseFindSettings = "notepadMac.smartHighlightUseFindSettings"
        static let urlIndicatorStyle = "notepadMac.urlIndicatorStyle"
        static let languageTabOverrides = "notepadMac.languageTabOverrides"
        static let tabbarLockDragDrop = "notepadMac.tabbarLockDragDrop"
        static let tabbarExitOnLastTab = "notepadMac.tabbarExitOnLastTab"
        static let htmlXmlCloseTagEnabled = "notepadMac.htmlXmlCloseTagEnabled"
        static let muteAllSounds = "notepadMac.muteAllSounds"
        static let selectedTextDragDrop = "notepadMac.selectedTextDragDrop"
        static let lineNumberDynamicWidth = "notepadMac.lineNumberDynamicWidth"
        static let columnSelectionToMultiEditing = "notepadMac.columnSelectionToMultiEditing"
        static let appearanceMode = "notepadMac.appearanceMode"
        static let taskListCustomTags = "notepadMac.taskListCustomTags"
        static let toolbarVisible = "notepadMac.toolbarVisible"
        static let showBookmarkMargin = "notepadMac.showBookmarkMargin"
        static let confirmReplaceInAllDocs = "notepadMac.confirmReplaceInAllDocs"
        static let maxFindHistoryCount = "notepadMac.maxFindHistoryCount"
        static let tabbarHide = "notepadMac.tabbarHide"
        static let reloadScrollToLastCaret = "notepadMac.reloadScrollToLastCaret"
        static let editorFontName = "notepadMac.editorFontName"
        static let editorFontBold = "notepadMac.editorFontBold"
        static let tabbarShowCloseButton = "notepadMac.tabbarShowCloseButton"
        static let trimTrailingSpacesOnSave = "notepadMac.trimTrailingSpacesOnSave"
        static let pasteConvertEndings = "notepadMac.pasteConvertEndings"
        static let caretStickyMode = "notepadMac.caretStickyMode"
        static let enableCodeFolding = "notepadMac.enableCodeFolding"
        static let autoCompleteIgnoreCase = "notepadMac.autoCompleteIgnoreCase"
        static let whitespaceDisplayMode = "notepadMac.whitespaceDisplayMode"
        static let bidiMode = "notepadMac.bidiMode"
        static let smoothFont = "notepadMac.smoothFont"
        static let multiEditEnabled = "notepadMac.multiEditEnabled"
        static let multiPasteMode = "notepadMac.multiPasteMode"
        static let indentGuideMode = "notepadMac.indentGuideMode"
        static let wordWrapMode = "notepadMac.wordWrapMode"
        static let tabbarCompact = "notepadMac.tabbarCompact"
        static let tabbarShowIndexNumbers = "notepadMac.tabbarShowIndexNumbers"
        static let zoomSyncToAllTabs = "notepadMac.zoomSyncToAllTabs"
        static let hideMenuShortcuts = "notepadMac.hideMenuShortcuts"
        static let scrollToLastLineOnMonitorReload = "notepadMac.scrollToLastLineOnMonitorReload"
        static let additionalSelAlpha = "notepadMac.additionalSelAlpha"
        static let additionalCaretsBlink = "notepadMac.additionalCaretsBlink"
        static let additionalCaretsVisible = "notepadMac.additionalCaretsVisible"
        static let caretLineVisibleAlways = "notepadMac.caretLineVisibleAlways"
        static let whitespaceSize = "notepadMac.whitespaceSize"
        static let selectionAlpha = "notepadMac.selectionAlpha"
        static let controlCharDisplay = "notepadMac.controlCharDisplay"
        static let openAnsiAsUtf8 = "notepadMac.openAnsiAsUtf8"
        static let xmlTagAttributeHighlight = "notepadMac.xmlTagAttributeHighlight"
        static let highlightNonHtmlZone = "notepadMac.highlightNonHtmlZone"
        static let defaultSaveDirectory = "notepadMac.defaultSaveDirectory"
        static let toolbarIconSizeStyle = "notepadMac.toolbarIconSizeStyle"
        static let scintillaRenderingTechnology = "notepadMac.scintillaRenderingTechnology"
        static let disableAdvancedScrolling = "notepadMac.disableAdvancedScrolling"
        static let rightClickKeepSelection = "notepadMac.rightClickKeepSelection"
        static let edgeMode = "notepadMac.edgeMode"
        static let foldFlags = "notepadMac.foldFlags"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppPreferences {
        AppPreferences(
            editorFontSize: defaults.object(forKey: Key.editorFontSize) as? Double ?? AppPreferences.defaultValue.editorFontSize,
            wrapsLines: defaults.object(forKey: Key.wrapsLines) as? Bool ?? AppPreferences.defaultValue.wrapsLines,
            searchMatchCase: defaults.object(forKey: Key.searchMatchCase) as? Bool ?? AppPreferences.defaultValue.searchMatchCase,
            searchWholeWord: defaults.object(forKey: Key.searchWholeWord) as? Bool ?? AppPreferences.defaultValue.searchWholeWord,
            customDateTimeFormat: defaults.string(forKey: Key.customDateTimeFormat) ?? AppPreferences.defaultValue.customDateTimeFormat,
            searchEngineChoice: SearchEngineChoice(rawValue: defaults.string(forKey: Key.searchEngineChoice) ?? "") ?? AppPreferences.defaultValue.searchEngineChoice,
            customSearchEngineURL: defaults.string(forKey: Key.customSearchEngineURL) ?? AppPreferences.defaultValue.customSearchEngineURL,
            localizationFileName: defaults.string(forKey: Key.localizationFileName) ?? AppPreferences.defaultValue.localizationFileName,
            showWhitespace: defaults.object(forKey: Key.showWhitespace) as? Bool ?? AppPreferences.defaultValue.showWhitespace,
            showEOL: defaults.object(forKey: Key.showEOL) as? Bool ?? AppPreferences.defaultValue.showEOL,
            showIndentGuides: defaults.object(forKey: Key.showIndentGuides) as? Bool ?? AppPreferences.defaultValue.showIndentGuides,
            highlightCurrentLine: defaults.object(forKey: Key.highlightCurrentLine) as? Bool ?? AppPreferences.defaultValue.highlightCurrentLine,
            showWrapSymbol: defaults.object(forKey: Key.showWrapSymbol) as? Bool ?? AppPreferences.defaultValue.showWrapSymbol,
            showChangeHistory: defaults.object(forKey: Key.showChangeHistory) as? Bool ?? AppPreferences.defaultValue.showChangeHistory,
            tabSize: defaults.object(forKey: Key.tabSize) as? Int ?? AppPreferences.defaultValue.tabSize,
            insertSpacesInsteadOfTabs: defaults.object(forKey: Key.insertSpacesInsteadOfTabs) as? Bool ?? AppPreferences.defaultValue.insertSpacesInsteadOfTabs,
            showLineNumberMargin: defaults.object(forKey: Key.showLineNumberMargin) as? Bool ?? AppPreferences.defaultValue.showLineNumberMargin,
            showEdgeLine: defaults.object(forKey: Key.showEdgeLine) as? Bool ?? AppPreferences.defaultValue.showEdgeLine,
            edgeLineColumn: defaults.object(forKey: Key.edgeLineColumn) as? Int ?? AppPreferences.defaultValue.edgeLineColumn,
            enableAutoPair: defaults.object(forKey: Key.enableAutoPair) as? Bool ?? AppPreferences.defaultValue.enableAutoPair,
            autoPairParentheses: defaults.object(forKey: Key.autoPairParentheses) as? Bool ?? AppPreferences.defaultValue.autoPairParentheses,
            autoPairBrackets: defaults.object(forKey: Key.autoPairBrackets) as? Bool ?? AppPreferences.defaultValue.autoPairBrackets,
            autoPairCurlyBrackets: defaults.object(forKey: Key.autoPairCurlyBrackets) as? Bool ?? AppPreferences.defaultValue.autoPairCurlyBrackets,
            autoPairSingleQuotes: defaults.object(forKey: Key.autoPairSingleQuotes) as? Bool ?? AppPreferences.defaultValue.autoPairSingleQuotes,
            autoPairDoubleQuotes: defaults.object(forKey: Key.autoPairDoubleQuotes) as? Bool ?? AppPreferences.defaultValue.autoPairDoubleQuotes,
            customMatchedPairs: (defaults.object(forKey: Key.customMatchedPairs) as? [[String]]) ?? [],
            enableXmlTagMatch: defaults.object(forKey: Key.enableXmlTagMatch) as? Bool ?? AppPreferences.defaultValue.enableXmlTagMatch,
            enableClickableLinks: defaults.object(forKey: Key.enableClickableLinks) as? Bool ?? AppPreferences.defaultValue.enableClickableLinks,
            defaultNewDocumentEncoding: defaults.string(forKey: Key.defaultNewDocumentEncoding) ?? AppPreferences.defaultValue.defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaults.string(forKey: Key.defaultNewDocumentLineEnding) ?? AppPreferences.defaultValue.defaultNewDocumentLineEnding,
            rememberLastSession: defaults.object(forKey: Key.rememberLastSession) as? Bool ?? AppPreferences.defaultValue.rememberLastSession,
            showNpcCharacters: defaults.object(forKey: Key.showNpcCharacters) as? Bool ?? AppPreferences.defaultValue.showNpcCharacters,
            smartHighlightMatchCase: defaults.object(forKey: Key.smartHighlightMatchCase) as? Bool ?? AppPreferences.defaultValue.smartHighlightMatchCase,
            smartHighlightWholeWord: defaults.object(forKey: Key.smartHighlightWholeWord) as? Bool ?? AppPreferences.defaultValue.smartHighlightWholeWord,
            markAllMatchCase: defaults.object(forKey: Key.markAllMatchCase) as? Bool ?? AppPreferences.defaultValue.markAllMatchCase,
            markAllWholeWord: defaults.object(forKey: Key.markAllWholeWord) as? Bool ?? AppPreferences.defaultValue.markAllWholeWord,
            langMenuCompact: defaults.object(forKey: Key.langMenuCompact) as? Bool ?? AppPreferences.defaultValue.langMenuCompact,
            caretWidth: defaults.object(forKey: Key.caretWidth) as? Int ?? AppPreferences.defaultValue.caretWidth,
            enableVirtualSpace: defaults.object(forKey: Key.enableVirtualSpace) as? Bool ?? AppPreferences.defaultValue.enableVirtualSpace,
            backspaceUnindents: defaults.object(forKey: Key.backspaceUnindents) as? Bool ?? AppPreferences.defaultValue.backspaceUnindents,
            autoIndent: defaults.object(forKey: Key.autoIndent) as? Bool ?? AppPreferences.defaultValue.autoIndent,
            autoIndentMode: defaults.object(forKey: Key.autoIndentMode) as? Int ?? 1,
            fileAutoDetection: defaults.object(forKey: Key.fileAutoDetection) as? Int ?? 1,
            updateSilently: defaults.object(forKey: Key.updateSilently) as? Bool ?? false,
            largeFileSizeMB: defaults.object(forKey: Key.largeFileSizeMB) as? Int ?? AppPreferences.defaultValue.largeFileSizeMB,
            largeFileSuppressAutoComplete: defaults.object(forKey: Key.largeFileSuppressAutoComplete) as? Bool ?? AppPreferences.defaultValue.largeFileSuppressAutoComplete,
            largeFileSuppressSmartHighlight: defaults.object(forKey: Key.largeFileSuppressSmartHighlight) as? Bool ?? AppPreferences.defaultValue.largeFileSuppressSmartHighlight,
            largeFileSuppressBraceMatch: defaults.object(forKey: Key.largeFileSuppressBraceMatch) as? Bool ?? AppPreferences.defaultValue.largeFileSuppressBraceMatch,
            largeFileSuppressWordWrap: defaults.object(forKey: Key.largeFileSuppressWordWrap) as? Bool ?? AppPreferences.defaultValue.largeFileSuppressWordWrap,
            largeFileSuppressSyntaxHighlight: defaults.object(forKey: Key.largeFileSuppressSyntaxHighlight) as? Bool ?? AppPreferences.defaultValue.largeFileSuppressSyntaxHighlight,
            scrollBeyondLastLine: defaults.object(forKey: Key.scrollBeyondLastLine) as? Bool ?? AppPreferences.defaultValue.scrollBeyondLastLine,
            autoCompleteFromNthChar: defaults.object(forKey: Key.autoCompleteFromNthChar) as? Int ?? AppPreferences.defaultValue.autoCompleteFromNthChar,
            caretNoBlink: defaults.object(forKey: Key.caretNoBlink) as? Bool ?? false,
            caretBlinkRate: defaults.object(forKey: Key.caretBlinkRate) as? Int ?? 500,
            currentLineFrameWidth: defaults.object(forKey: Key.currentLineFrameWidth) as? Int ?? 0,
            lineWrapIndent: defaults.object(forKey: Key.lineWrapIndent) as? Int ?? 0,
            foldMarginStyle: defaults.object(forKey: Key.foldMarginStyle) as? Int ?? 0,
            useFirstLineAsTabName: defaults.object(forKey: Key.useFirstLineAsTabName) as? Bool ?? false,
            recentFilesMaxCount: defaults.object(forKey: Key.recentFilesMaxCount) as? Int ?? 20,
            recentFilesShowFullPath: defaults.object(forKey: Key.recentFilesShowFullPath) as? Bool ?? false,
            recentFilesInSubmenu: defaults.object(forKey: Key.recentFilesInSubmenu) as? Bool ?? false,
            recentFilesCustomDisplayLength: defaults.object(forKey: Key.recentFilesCustomDisplayLength) as? Int ?? 0,
            noCheckRecentAtLaunch: defaults.object(forKey: Key.noCheckRecentAtLaunch) as? Bool ?? false,
            keepAbsentFilesInSession: defaults.object(forKey: Key.keepAbsentFilesInSession) as? Bool ?? false,
            autoReloadOnExternalChange: defaults.object(forKey: Key.autoReloadOnExternalChange) as? Bool ?? false,
            backupOnSaveMode: Self.loadBackupOnSaveMode(from: defaults),
            snapshotModeEnabled: defaults.object(forKey: Key.snapshotModeEnabled) as? Bool ?? AppPreferences.defaultValue.snapshotModeEnabled,
            periodicBackupIntervalSeconds: defaults.object(forKey: Key.periodicBackupIntervalSeconds) as? Int ?? AppPreferences.defaultValue.periodicBackupIntervalSeconds,
            useCustomBackupDirectory: defaults.object(forKey: Key.useCustomBackupDirectory) as? Bool ?? false,
            customBackupDirectory: defaults.string(forKey: Key.customBackupDirectory) ?? "",
            additionalEdgeColumns: defaults.string(forKey: Key.additionalEdgeColumns) ?? "",
            linePadding: defaults.object(forKey: Key.linePadding) as? Int ?? 0,
            openDirectoryFollowsDocument: defaults.object(forKey: Key.openDirectoryFollowsDocument) as? Bool ?? false,
            defaultNewDocumentLanguageName: defaults.string(forKey: Key.defaultNewDocumentLanguageName) ?? "",
            folderDropOpensAsWorkspace: defaults.object(forKey: Key.folderDropOpensAsWorkspace) as? Bool ?? false,
            folderDropRecursiveOpen: defaults.object(forKey: Key.folderDropRecursiveOpen) as? Bool ?? false,
            extraURLSchemes: defaults.string(forKey: Key.extraURLSchemes) ?? "",
            newDocumentOnLaunch: defaults.object(forKey: Key.newDocumentOnLaunch) as? Bool ?? true,
            postItAlpha: defaults.object(forKey: Key.postItAlpha) as? Double ?? 0.75,
            printLineNumbers: defaults.object(forKey: Key.printLineNumbers) as? Bool ?? true,
            autoCompleteMode: defaults.object(forKey: Key.autoCompleteMode) as? Int ?? 3,
            autoCompleteChooseSingle: defaults.object(forKey: Key.autoCompleteChooseSingle) as? Bool ?? true,
            autoCompleteTABFillup: defaults.object(forKey: Key.autoCompleteTABFillup) as? Bool ?? false,
            autoCompleteEnterCommit: defaults.object(forKey: Key.autoCompleteEnterCommit) as? Bool ?? true,
            autoCompleteBrief: defaults.object(forKey: Key.autoCompleteBrief) as? Bool ?? false,
            inSelectionThreshold: defaults.object(forKey: Key.inSelectionThreshold) as? Int ?? 1024,
            tabbarDoubleClickClose: defaults.object(forKey: Key.tabbarDoubleClickClose) as? Bool ?? false,
            tabbarMaxLabelLength: defaults.object(forKey: Key.tabbarMaxLabelLength) as? Int ?? 0,
            keepFindDialogOpen: defaults.object(forKey: Key.keepFindDialogOpen) as? Bool ?? true,
            findDialogTransparency: defaults.object(forKey: Key.findDialogTransparency) as? Double ?? 0,
            printSettings: Self.loadPrintSettings(from: defaults),
            delimiterLeft: defaults.string(forKey: Key.delimiterLeft) ?? "",
            delimiterRight: defaults.string(forKey: Key.delimiterRight) ?? "",
            statusBarVisible: defaults.object(forKey: Key.statusBarVisible) as? Bool ?? true,
            shortTitle: defaults.object(forKey: Key.shortTitle) as? Bool ?? false,
            saveAllConfirm: defaults.object(forKey: Key.saveAllConfirm) as? Bool ?? false,
            autoCompleteIgnoreNumbers: defaults.object(forKey: Key.autoCompleteIgnoreNumbers) as? Bool ?? true,
            replaceDoesNotMove: defaults.object(forKey: Key.replaceDoesNotMove) as? Bool ?? false,
            fileChangeDetectionEnabled: defaults.object(forKey: Key.fileChangeDetectionEnabled) as? Bool ?? true,
            findDialogMonospace: defaults.object(forKey: Key.findDialogMonospace) as? Bool ?? false,
            copyLineWithoutSelection: defaults.object(forKey: Key.copyLineWithoutSelection) as? Bool ?? true,
            fillFindFromSelection: defaults.object(forKey: Key.fillFindFromSelection) as? Bool ?? true,
            autoSelectWordUnderCaret: defaults.object(forKey: Key.autoSelectWordUnderCaret) as? Bool ?? false,
            findInFilesIgnoreUnsaved: defaults.object(forKey: Key.findInFilesIgnoreUnsaved) as? Bool ?? false,
            smartHighlightUseFindSettings: defaults.object(forKey: Key.smartHighlightUseFindSettings) as? Bool ?? false,
            urlIndicatorStyle: defaults.object(forKey: Key.urlIndicatorStyle) as? Int ?? 0,
            languageTabOverrides: defaults.string(forKey: Key.languageTabOverrides) ?? "",
            tabbarLockDragDrop: defaults.object(forKey: Key.tabbarLockDragDrop) as? Bool ?? false,
            tabbarExitOnLastTab: defaults.object(forKey: Key.tabbarExitOnLastTab) as? Bool ?? false,
            htmlXmlCloseTagEnabled: defaults.object(forKey: Key.htmlXmlCloseTagEnabled) as? Bool ?? false,
            muteAllSounds: defaults.object(forKey: Key.muteAllSounds) as? Bool ?? false,
            selectedTextDragDrop: defaults.object(forKey: Key.selectedTextDragDrop) as? Bool ?? true,
            lineNumberDynamicWidth: defaults.object(forKey: Key.lineNumberDynamicWidth) as? Bool ?? false,
            columnSelectionToMultiEditing: defaults.object(forKey: Key.columnSelectionToMultiEditing) as? Bool ?? false,
            appearanceMode: defaults.object(forKey: Key.appearanceMode) as? Int ?? 0,
            taskListCustomTags: defaults.string(forKey: Key.taskListCustomTags) ?? "",
            toolbarVisible: defaults.object(forKey: Key.toolbarVisible) as? Bool ?? true,
            showBookmarkMargin: defaults.object(forKey: Key.showBookmarkMargin) as? Bool ?? true,
            confirmReplaceInAllDocs: defaults.object(forKey: Key.confirmReplaceInAllDocs) as? Bool ?? true,
            maxFindHistoryCount: defaults.object(forKey: Key.maxFindHistoryCount) as? Int ?? 20,
            tabbarHide: defaults.object(forKey: Key.tabbarHide) as? Bool ?? false,
            reloadScrollToLastCaret: defaults.object(forKey: Key.reloadScrollToLastCaret) as? Bool ?? false,
            editorFontName: defaults.string(forKey: Key.editorFontName) ?? "",
            editorFontBold: defaults.object(forKey: Key.editorFontBold) as? Bool ?? false,
            tabbarShowCloseButton: defaults.object(forKey: Key.tabbarShowCloseButton) as? Bool ?? true,
            trimTrailingSpacesOnSave: defaults.object(forKey: Key.trimTrailingSpacesOnSave) as? Bool ?? false,
            pasteConvertEndings: defaults.object(forKey: Key.pasteConvertEndings) as? Bool ?? true,
            caretStickyMode: defaults.object(forKey: Key.caretStickyMode) as? Int ?? 0,
            enableCodeFolding: defaults.object(forKey: Key.enableCodeFolding) as? Bool ?? true,
            autoCompleteIgnoreCase: defaults.object(forKey: Key.autoCompleteIgnoreCase) as? Bool ?? true,
            whitespaceDisplayMode: defaults.object(forKey: Key.whitespaceDisplayMode) as? Int ?? 0,
            bidiMode: defaults.object(forKey: Key.bidiMode) as? Int ?? 0,
            smoothFont: defaults.object(forKey: Key.smoothFont) as? Bool ?? true,
            multiEditEnabled: defaults.object(forKey: Key.multiEditEnabled) as? Bool ?? true,
            multiPasteMode: defaults.object(forKey: Key.multiPasteMode) as? Int ?? 1,
            indentGuideMode: defaults.object(forKey: Key.indentGuideMode) as? Int ?? 2,
            wordWrapMode: defaults.object(forKey: Key.wordWrapMode) as? Int ?? 1,
            tabbarCompact: defaults.object(forKey: Key.tabbarCompact) as? Bool ?? false,
            tabbarShowIndexNumbers: defaults.object(forKey: Key.tabbarShowIndexNumbers) as? Bool ?? false,
            zoomSyncToAllTabs: defaults.object(forKey: Key.zoomSyncToAllTabs) as? Bool ?? false,
            hideMenuShortcuts: defaults.object(forKey: Key.hideMenuShortcuts) as? Bool ?? false,
            scrollToLastLineOnMonitorReload: defaults.object(forKey: Key.scrollToLastLineOnMonitorReload) as? Bool ?? false,
            additionalSelAlpha: defaults.object(forKey: Key.additionalSelAlpha) as? Int ?? 256,
            additionalCaretsBlink: defaults.object(forKey: Key.additionalCaretsBlink) as? Bool ?? true,
            additionalCaretsVisible: defaults.object(forKey: Key.additionalCaretsVisible) as? Bool ?? true,
            caretLineVisibleAlways: defaults.object(forKey: Key.caretLineVisibleAlways) as? Bool ?? false,
            whitespaceSize: defaults.object(forKey: Key.whitespaceSize) as? Int ?? 1,
            selectionAlpha: defaults.object(forKey: Key.selectionAlpha) as? Int ?? 256,
            controlCharDisplay: defaults.object(forKey: Key.controlCharDisplay) as? Int ?? 0,
            openAnsiAsUtf8: defaults.object(forKey: Key.openAnsiAsUtf8) as? Bool ?? false,
            xmlTagAttributeHighlight: defaults.object(forKey: Key.xmlTagAttributeHighlight) as? Bool ?? true,
            highlightNonHtmlZone: defaults.object(forKey: Key.highlightNonHtmlZone) as? Bool ?? false,
            defaultSaveDirectory: defaults.string(forKey: Key.defaultSaveDirectory) ?? "",
            toolbarIconSizeStyle: defaults.object(forKey: Key.toolbarIconSizeStyle) as? Int ?? 0,
            scintillaRenderingTechnology: defaults.object(forKey: Key.scintillaRenderingTechnology) as? Int ?? 0,
            disableAdvancedScrolling: defaults.object(forKey: Key.disableAdvancedScrolling) as? Bool ?? false,
            rightClickKeepSelection: defaults.object(forKey: Key.rightClickKeepSelection) as? Bool ?? true,
            edgeMode: defaults.object(forKey: Key.edgeMode) as? Int ?? 1,
            foldFlags: defaults.object(forKey: Key.foldFlags) as? Int ?? 0
        )
    }

    private static func loadPrintSettings(from defaults: UserDefaults) -> PrintSettings {
        guard let data = defaults.data(forKey: Key.printSettings),
              let ps = try? JSONDecoder().decode(PrintSettings.self, from: data) else {
            return .defaultValue
        }
        return ps
    }

    public func save(_ preferences: AppPreferences) {
        defaults.set(preferences.editorFontSize, forKey: Key.editorFontSize)
        defaults.set(preferences.wrapsLines, forKey: Key.wrapsLines)
        defaults.set(preferences.searchMatchCase, forKey: Key.searchMatchCase)
        defaults.set(preferences.searchWholeWord, forKey: Key.searchWholeWord)
        defaults.set(preferences.customDateTimeFormat, forKey: Key.customDateTimeFormat)
        defaults.set(preferences.searchEngineChoice.rawValue, forKey: Key.searchEngineChoice)
        defaults.set(preferences.customSearchEngineURL, forKey: Key.customSearchEngineURL)
        defaults.set(preferences.localizationFileName, forKey: Key.localizationFileName)
        defaults.set(preferences.showWhitespace, forKey: Key.showWhitespace)
        defaults.set(preferences.showEOL, forKey: Key.showEOL)
        defaults.set(preferences.showIndentGuides, forKey: Key.showIndentGuides)
        defaults.set(preferences.highlightCurrentLine, forKey: Key.highlightCurrentLine)
        defaults.set(preferences.showWrapSymbol, forKey: Key.showWrapSymbol)
        defaults.set(preferences.showChangeHistory, forKey: Key.showChangeHistory)
        defaults.set(preferences.tabSize, forKey: Key.tabSize)
        defaults.set(preferences.insertSpacesInsteadOfTabs, forKey: Key.insertSpacesInsteadOfTabs)
        defaults.set(preferences.showLineNumberMargin, forKey: Key.showLineNumberMargin)
        defaults.set(preferences.showEdgeLine, forKey: Key.showEdgeLine)
        defaults.set(preferences.edgeLineColumn, forKey: Key.edgeLineColumn)
        defaults.set(preferences.enableAutoPair, forKey: Key.enableAutoPair)
        defaults.set(preferences.autoPairParentheses, forKey: Key.autoPairParentheses)
        defaults.set(preferences.autoPairBrackets, forKey: Key.autoPairBrackets)
        defaults.set(preferences.autoPairCurlyBrackets, forKey: Key.autoPairCurlyBrackets)
        defaults.set(preferences.autoPairSingleQuotes, forKey: Key.autoPairSingleQuotes)
        defaults.set(preferences.autoPairDoubleQuotes, forKey: Key.autoPairDoubleQuotes)
        defaults.set(preferences.customMatchedPairs, forKey: Key.customMatchedPairs)
        defaults.set(preferences.enableXmlTagMatch, forKey: Key.enableXmlTagMatch)
        defaults.set(preferences.enableClickableLinks, forKey: Key.enableClickableLinks)
        defaults.set(preferences.defaultNewDocumentEncoding, forKey: Key.defaultNewDocumentEncoding)
        defaults.set(preferences.defaultNewDocumentLineEnding, forKey: Key.defaultNewDocumentLineEnding)
        defaults.set(preferences.rememberLastSession, forKey: Key.rememberLastSession)
        defaults.set(preferences.showNpcCharacters, forKey: Key.showNpcCharacters)
        defaults.set(preferences.smartHighlightMatchCase, forKey: Key.smartHighlightMatchCase)
        defaults.set(preferences.smartHighlightWholeWord, forKey: Key.smartHighlightWholeWord)
        defaults.set(preferences.markAllMatchCase, forKey: Key.markAllMatchCase)
        defaults.set(preferences.markAllWholeWord, forKey: Key.markAllWholeWord)
        defaults.set(preferences.langMenuCompact, forKey: Key.langMenuCompact)
        defaults.set(preferences.caretWidth, forKey: Key.caretWidth)
        defaults.set(preferences.enableVirtualSpace, forKey: Key.enableVirtualSpace)
        defaults.set(preferences.backspaceUnindents, forKey: Key.backspaceUnindents)
        defaults.set(preferences.autoIndent, forKey: Key.autoIndent)
        defaults.set(preferences.autoIndentMode, forKey: Key.autoIndentMode)
        defaults.set(preferences.fileAutoDetection, forKey: Key.fileAutoDetection)
        defaults.set(preferences.updateSilently, forKey: Key.updateSilently)
        defaults.set(preferences.largeFileSizeMB, forKey: Key.largeFileSizeMB)
        defaults.set(preferences.largeFileSuppressAutoComplete, forKey: Key.largeFileSuppressAutoComplete)
        defaults.set(preferences.largeFileSuppressSmartHighlight, forKey: Key.largeFileSuppressSmartHighlight)
        defaults.set(preferences.largeFileSuppressBraceMatch, forKey: Key.largeFileSuppressBraceMatch)
        defaults.set(preferences.largeFileSuppressWordWrap, forKey: Key.largeFileSuppressWordWrap)
        defaults.set(preferences.largeFileSuppressSyntaxHighlight, forKey: Key.largeFileSuppressSyntaxHighlight)
        defaults.set(preferences.scrollBeyondLastLine, forKey: Key.scrollBeyondLastLine)
        defaults.set(preferences.autoCompleteFromNthChar, forKey: Key.autoCompleteFromNthChar)
        defaults.set(preferences.caretNoBlink, forKey: Key.caretNoBlink)
        defaults.set(preferences.caretBlinkRate, forKey: Key.caretBlinkRate)
        defaults.set(preferences.currentLineFrameWidth, forKey: Key.currentLineFrameWidth)
        defaults.set(preferences.lineWrapIndent, forKey: Key.lineWrapIndent)
        defaults.set(preferences.foldMarginStyle, forKey: Key.foldMarginStyle)
        defaults.set(preferences.useFirstLineAsTabName, forKey: Key.useFirstLineAsTabName)
        defaults.set(preferences.recentFilesMaxCount, forKey: Key.recentFilesMaxCount)
        defaults.set(preferences.recentFilesShowFullPath, forKey: Key.recentFilesShowFullPath)
        defaults.set(preferences.recentFilesInSubmenu, forKey: Key.recentFilesInSubmenu)
        defaults.set(preferences.recentFilesCustomDisplayLength, forKey: Key.recentFilesCustomDisplayLength)
        defaults.set(preferences.noCheckRecentAtLaunch, forKey: Key.noCheckRecentAtLaunch)
        defaults.set(preferences.keepAbsentFilesInSession, forKey: Key.keepAbsentFilesInSession)
        defaults.set(preferences.autoReloadOnExternalChange, forKey: Key.autoReloadOnExternalChange)
        defaults.set(preferences.backupOnSaveMode.rawValue, forKey: Key.backupOnSaveMode)
        defaults.set(preferences.backupOnSaveMode != .none, forKey: Key.backupOnSave)
        defaults.set(preferences.snapshotModeEnabled, forKey: Key.snapshotModeEnabled)
        defaults.set(preferences.periodicBackupIntervalSeconds, forKey: Key.periodicBackupIntervalSeconds)
        defaults.set(preferences.useCustomBackupDirectory, forKey: Key.useCustomBackupDirectory)
        defaults.set(preferences.customBackupDirectory, forKey: Key.customBackupDirectory)
        defaults.set(preferences.additionalEdgeColumns, forKey: Key.additionalEdgeColumns)
        defaults.set(preferences.linePadding, forKey: Key.linePadding)
        defaults.set(preferences.openDirectoryFollowsDocument, forKey: Key.openDirectoryFollowsDocument)
        defaults.set(preferences.defaultNewDocumentLanguageName, forKey: Key.defaultNewDocumentLanguageName)
        defaults.set(preferences.folderDropOpensAsWorkspace, forKey: Key.folderDropOpensAsWorkspace)
        defaults.set(preferences.folderDropRecursiveOpen, forKey: Key.folderDropRecursiveOpen)
        defaults.set(preferences.extraURLSchemes, forKey: Key.extraURLSchemes)
        defaults.set(preferences.newDocumentOnLaunch, forKey: Key.newDocumentOnLaunch)
        defaults.set(preferences.postItAlpha, forKey: Key.postItAlpha)
        defaults.set(preferences.printLineNumbers, forKey: Key.printLineNumbers)
        defaults.set(preferences.autoCompleteMode, forKey: Key.autoCompleteMode)
        defaults.set(preferences.autoCompleteChooseSingle, forKey: Key.autoCompleteChooseSingle)
        defaults.set(preferences.autoCompleteTABFillup, forKey: Key.autoCompleteTABFillup)
        defaults.set(preferences.autoCompleteEnterCommit, forKey: Key.autoCompleteEnterCommit)
        defaults.set(preferences.autoCompleteBrief, forKey: Key.autoCompleteBrief)
        defaults.set(preferences.inSelectionThreshold, forKey: Key.inSelectionThreshold)
        defaults.set(preferences.tabbarDoubleClickClose, forKey: Key.tabbarDoubleClickClose)
        defaults.set(preferences.tabbarMaxLabelLength, forKey: Key.tabbarMaxLabelLength)
        defaults.set(preferences.keepFindDialogOpen, forKey: Key.keepFindDialogOpen)
        defaults.set(preferences.findDialogTransparency, forKey: Key.findDialogTransparency)
        if let data = try? JSONEncoder().encode(preferences.printSettings) {
            defaults.set(data, forKey: Key.printSettings)
        }
        defaults.set(preferences.delimiterLeft, forKey: Key.delimiterLeft)
        defaults.set(preferences.delimiterRight, forKey: Key.delimiterRight)
        defaults.set(preferences.statusBarVisible, forKey: Key.statusBarVisible)
        defaults.set(preferences.shortTitle, forKey: Key.shortTitle)
        defaults.set(preferences.saveAllConfirm, forKey: Key.saveAllConfirm)
        defaults.set(preferences.autoCompleteIgnoreNumbers, forKey: Key.autoCompleteIgnoreNumbers)
        defaults.set(preferences.replaceDoesNotMove, forKey: Key.replaceDoesNotMove)
        defaults.set(preferences.fileChangeDetectionEnabled, forKey: Key.fileChangeDetectionEnabled)
        defaults.set(preferences.findDialogMonospace, forKey: Key.findDialogMonospace)
        defaults.set(preferences.copyLineWithoutSelection, forKey: Key.copyLineWithoutSelection)
        defaults.set(preferences.fillFindFromSelection, forKey: Key.fillFindFromSelection)
        defaults.set(preferences.autoSelectWordUnderCaret, forKey: Key.autoSelectWordUnderCaret)
        defaults.set(preferences.findInFilesIgnoreUnsaved, forKey: Key.findInFilesIgnoreUnsaved)
        defaults.set(preferences.smartHighlightUseFindSettings, forKey: Key.smartHighlightUseFindSettings)
        defaults.set(preferences.urlIndicatorStyle, forKey: Key.urlIndicatorStyle)
        defaults.set(preferences.languageTabOverrides, forKey: Key.languageTabOverrides)
        defaults.set(preferences.tabbarLockDragDrop, forKey: Key.tabbarLockDragDrop)
        defaults.set(preferences.tabbarExitOnLastTab, forKey: Key.tabbarExitOnLastTab)
        defaults.set(preferences.htmlXmlCloseTagEnabled, forKey: Key.htmlXmlCloseTagEnabled)
        defaults.set(preferences.muteAllSounds, forKey: Key.muteAllSounds)
        defaults.set(preferences.selectedTextDragDrop, forKey: Key.selectedTextDragDrop)
        defaults.set(preferences.lineNumberDynamicWidth, forKey: Key.lineNumberDynamicWidth)
        defaults.set(preferences.columnSelectionToMultiEditing, forKey: Key.columnSelectionToMultiEditing)
        defaults.set(preferences.appearanceMode, forKey: Key.appearanceMode)
        defaults.set(preferences.taskListCustomTags, forKey: Key.taskListCustomTags)
        defaults.set(preferences.toolbarVisible, forKey: Key.toolbarVisible)
        defaults.set(preferences.showBookmarkMargin, forKey: Key.showBookmarkMargin)
        defaults.set(preferences.confirmReplaceInAllDocs, forKey: Key.confirmReplaceInAllDocs)
        defaults.set(preferences.maxFindHistoryCount, forKey: Key.maxFindHistoryCount)
        defaults.set(preferences.tabbarHide, forKey: Key.tabbarHide)
        defaults.set(preferences.reloadScrollToLastCaret, forKey: Key.reloadScrollToLastCaret)
        defaults.set(preferences.editorFontName, forKey: Key.editorFontName)
        defaults.set(preferences.editorFontBold, forKey: Key.editorFontBold)
        defaults.set(preferences.tabbarShowCloseButton, forKey: Key.tabbarShowCloseButton)
        defaults.set(preferences.trimTrailingSpacesOnSave, forKey: Key.trimTrailingSpacesOnSave)
        defaults.set(preferences.pasteConvertEndings, forKey: Key.pasteConvertEndings)
        defaults.set(preferences.caretStickyMode, forKey: Key.caretStickyMode)
        defaults.set(preferences.enableCodeFolding, forKey: Key.enableCodeFolding)
        defaults.set(preferences.autoCompleteIgnoreCase, forKey: Key.autoCompleteIgnoreCase)
        defaults.set(preferences.whitespaceDisplayMode, forKey: Key.whitespaceDisplayMode)
        defaults.set(preferences.bidiMode, forKey: Key.bidiMode)
        defaults.set(preferences.smoothFont, forKey: Key.smoothFont)
        defaults.set(preferences.multiEditEnabled, forKey: Key.multiEditEnabled)
        defaults.set(preferences.multiPasteMode, forKey: Key.multiPasteMode)
        defaults.set(preferences.indentGuideMode, forKey: Key.indentGuideMode)
        defaults.set(preferences.wordWrapMode, forKey: Key.wordWrapMode)
        defaults.set(preferences.tabbarCompact, forKey: Key.tabbarCompact)
        defaults.set(preferences.tabbarShowIndexNumbers, forKey: Key.tabbarShowIndexNumbers)
        defaults.set(preferences.zoomSyncToAllTabs, forKey: Key.zoomSyncToAllTabs)
        defaults.set(preferences.hideMenuShortcuts, forKey: Key.hideMenuShortcuts)
        defaults.set(preferences.scrollToLastLineOnMonitorReload, forKey: Key.scrollToLastLineOnMonitorReload)
        defaults.set(preferences.additionalSelAlpha, forKey: Key.additionalSelAlpha)
        defaults.set(preferences.additionalCaretsBlink, forKey: Key.additionalCaretsBlink)
        defaults.set(preferences.additionalCaretsVisible, forKey: Key.additionalCaretsVisible)
        defaults.set(preferences.caretLineVisibleAlways, forKey: Key.caretLineVisibleAlways)
        defaults.set(preferences.whitespaceSize, forKey: Key.whitespaceSize)
        defaults.set(preferences.selectionAlpha, forKey: Key.selectionAlpha)
        defaults.set(preferences.controlCharDisplay, forKey: Key.controlCharDisplay)
        defaults.set(preferences.openAnsiAsUtf8, forKey: Key.openAnsiAsUtf8)
        defaults.set(preferences.xmlTagAttributeHighlight, forKey: Key.xmlTagAttributeHighlight)
        defaults.set(preferences.highlightNonHtmlZone, forKey: Key.highlightNonHtmlZone)
        defaults.set(preferences.defaultSaveDirectory, forKey: Key.defaultSaveDirectory)
        defaults.set(preferences.toolbarIconSizeStyle, forKey: Key.toolbarIconSizeStyle)
        defaults.set(preferences.scintillaRenderingTechnology, forKey: Key.scintillaRenderingTechnology)
        defaults.set(preferences.disableAdvancedScrolling, forKey: Key.disableAdvancedScrolling)
        defaults.set(preferences.rightClickKeepSelection, forKey: Key.rightClickKeepSelection)
        defaults.set(preferences.edgeMode, forKey: Key.edgeMode)
        defaults.set(preferences.foldFlags, forKey: Key.foldFlags)
        defaults.synchronize()
    }

    public func loadFindHistory() -> [String] {
        defaults.stringArray(forKey: Key.findHistory) ?? []
    }

    public func saveFindHistory(_ history: [String]) {
        let limit = load().maxFindHistoryCount
        let capped = Array(history.prefix(limit))
        defaults.set(capped, forKey: Key.findHistory)
        defaults.synchronize()
    }

    public func loadReplaceHistory() -> [String] {
        defaults.stringArray(forKey: Key.replaceHistory) ?? []
    }

    public func saveReplaceHistory(_ history: [String]) {
        let limit = load().maxFindHistoryCount
        let capped = Array(history.prefix(limit))
        defaults.set(capped, forKey: Key.replaceHistory)
        defaults.synchronize()
    }

    public func loadFindPanelExtendedState() -> (searchMode: Int, dotMatchesNewline: Bool, wrapAround: Bool) {
        let mode = defaults.integer(forKey: Key.findSearchMode)   // 0=normal, 1=extended, 2=regex
        let dot = defaults.bool(forKey: Key.findDotMatchesNewline)
        let wrap = defaults.object(forKey: Key.findWrapAround) as? Bool ?? true
        return (mode, dot, wrap)
    }

    public func saveFindPanelExtendedState(searchMode: Int, dotMatchesNewline: Bool, wrapAround: Bool) {
        defaults.set(searchMode, forKey: Key.findSearchMode)
        defaults.set(dotMatchesNewline, forKey: Key.findDotMatchesNewline)
        defaults.set(wrapAround, forKey: Key.findWrapAround)
        defaults.synchronize()
    }

    public func loadDisabledNativePluginIdentifiers() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.disabledNativePluginIdentifiers) ?? [])
    }

    public func saveDisabledNativePluginIdentifiers(_ identifiers: Set<String>) {
        if identifiers.isEmpty {
            defaults.removeObject(forKey: Key.disabledNativePluginIdentifiers)
        } else {
            defaults.set(identifiers.sorted(), forKey: Key.disabledNativePluginIdentifiers)
        }
        defaults.synchronize()
    }

    private static func loadBackupOnSaveMode(from defaults: UserDefaults) -> BackupOnSaveMode {
        if let raw = defaults.string(forKey: Key.backupOnSaveMode),
           let mode = BackupOnSaveMode(rawValue: raw) {
            return mode
        }
        if defaults.object(forKey: Key.backupOnSave) as? Bool == true {
            return .simple
        }
        return .none
    }
}
