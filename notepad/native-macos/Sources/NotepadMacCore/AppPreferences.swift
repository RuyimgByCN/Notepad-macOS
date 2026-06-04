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
    public let enableXmlTagMatch: Bool
    public let enableClickableLinks: Bool
    public let defaultNewDocumentEncoding: String   // TextEncodingOption.rawValue
    public let defaultNewDocumentLineEnding: String // LineEnding.rawValue
    public let rememberLastSession: Bool
    public let showNpcCharacters: Bool
    public let smartHighlightMatchCase: Bool
    public let smartHighlightWholeWord: Bool
    public let caretWidth: Int      // 1 = thin, 2 = medium, 3 = thick
    public let enableVirtualSpace: Bool
    public let backspaceUnindents: Bool
    public let autoIndent: Bool
    public let largeFileSizeMB: Int  // Files above this threshold skip syntax highlight and URL scan
    public let scrollBeyondLastLine: Bool
    public let autoCompleteFromNthChar: Int  // 0 = disabled, 1+ = trigger after N chars typed
    public let caretNoBlink: Bool
    public let currentLineFrameWidth: Int   // 0 = fill, 1-4 = frame width in pixels
    public let lineWrapIndent: Int          // 0=fixed, 1=same, 2=indent, 3=deepindent
    public let foldMarginStyle: Int         // 0=simple arrows, 1=box tree, 2=circle tree
    public let useFirstLineAsTabName: Bool
    public let recentFilesMaxCount: Int     // 1-50
    public let recentFilesShowFullPath: Bool
    public let noCheckRecentAtLaunch: Bool
    public let keepAbsentFilesInSession: Bool
    public let autoReloadOnExternalChange: Bool
    public let backupOnSave: Bool
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
    /// When session restore is off and no files are provided, create a new empty document on launch
    public let newDocumentOnLaunch: Bool
    /// Opacity for Post-It mode window (0.0=transparent, 1.0=opaque)
    public let postItAlpha: Double

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
        enableXmlTagMatch: Bool = true,
        enableClickableLinks: Bool = true,
        defaultNewDocumentEncoding: String = "utf8",
        defaultNewDocumentLineEnding: String = "lf",
        rememberLastSession: Bool = true,
        showNpcCharacters: Bool = false,
        smartHighlightMatchCase: Bool = false,
        smartHighlightWholeWord: Bool = true,
        caretWidth: Int = 1,
        enableVirtualSpace: Bool = false,
        backspaceUnindents: Bool = true,
        autoIndent: Bool = true,
        largeFileSizeMB: Int = AppPreferences.defaultLargeFileMB,
        scrollBeyondLastLine: Bool = false,
        autoCompleteFromNthChar: Int = 3,
        caretNoBlink: Bool = false,
        currentLineFrameWidth: Int = 0,
        lineWrapIndent: Int = 0,
        foldMarginStyle: Int = 0,
        useFirstLineAsTabName: Bool = false,
        recentFilesMaxCount: Int = 20,
        recentFilesShowFullPath: Bool = false,
        noCheckRecentAtLaunch: Bool = false,
        keepAbsentFilesInSession: Bool = false,
        autoReloadOnExternalChange: Bool = false,
        backupOnSave: Bool = false,
        additionalEdgeColumns: String = "",
        linePadding: Int = 0,
        openDirectoryFollowsDocument: Bool = false,
        defaultNewDocumentLanguageName: String = "",
        folderDropOpensAsWorkspace: Bool = false,
        extraURLSchemes: String = "",
        newDocumentOnLaunch: Bool = true,
        postItAlpha: Double = 0.75
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
        self.enableXmlTagMatch = enableXmlTagMatch
        self.enableClickableLinks = enableClickableLinks
        self.defaultNewDocumentEncoding = defaultNewDocumentEncoding.isEmpty ? "utf8" : defaultNewDocumentEncoding
        self.defaultNewDocumentLineEnding = defaultNewDocumentLineEnding.isEmpty ? "lf" : defaultNewDocumentLineEnding
        self.rememberLastSession = rememberLastSession
        self.showNpcCharacters = showNpcCharacters
        self.smartHighlightMatchCase = smartHighlightMatchCase
        self.smartHighlightWholeWord = smartHighlightWholeWord
        self.caretWidth = max(Self.minimumCaretWidth, min(caretWidth, Self.maximumCaretWidth))
        self.enableVirtualSpace = enableVirtualSpace
        self.backspaceUnindents = backspaceUnindents
        self.autoIndent = autoIndent
        self.largeFileSizeMB = max(Self.minimumLargeFileMB, min(largeFileSizeMB, Self.maximumLargeFileMB))
        self.scrollBeyondLastLine = scrollBeyondLastLine
        self.autoCompleteFromNthChar = max(0, autoCompleteFromNthChar)
        self.caretNoBlink = caretNoBlink
        self.currentLineFrameWidth = max(0, min(4, currentLineFrameWidth))
        self.lineWrapIndent = max(0, min(3, lineWrapIndent))
        self.foldMarginStyle = max(0, min(2, foldMarginStyle))
        self.useFirstLineAsTabName = useFirstLineAsTabName
        self.recentFilesMaxCount = max(1, min(50, recentFilesMaxCount))
        self.recentFilesShowFullPath = recentFilesShowFullPath
        self.noCheckRecentAtLaunch = noCheckRecentAtLaunch
        self.keepAbsentFilesInSession = keepAbsentFilesInSession
        self.autoReloadOnExternalChange = autoReloadOnExternalChange
        self.backupOnSave = backupOnSave
        self.additionalEdgeColumns = additionalEdgeColumns
        self.linePadding = max(0, min(5, linePadding))
        self.openDirectoryFollowsDocument = openDirectoryFollowsDocument
        self.defaultNewDocumentLanguageName = defaultNewDocumentLanguageName
        self.folderDropOpensAsWorkspace = folderDropOpensAsWorkspace
        self.extraURLSchemes = extraURLSchemes
        self.newDocumentOnLaunch = newDocumentOnLaunch
        self.postItAlpha = max(0.2, min(1.0, postItAlpha))
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
        localizationFileName: String? = nil
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
            tabSize: tabSize,
            insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs,
            showLineNumberMargin: showLineNumberMargin,
            showEdgeLine: showEdgeLine,
            edgeLineColumn: edgeLineColumn,
            enableAutoPair: enableAutoPair,
            enableXmlTagMatch: enableXmlTagMatch,
            enableClickableLinks: enableClickableLinks,
            defaultNewDocumentEncoding: defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaultNewDocumentLineEnding,
            rememberLastSession: rememberLastSession,
            showNpcCharacters: showNpcCharacters,
            smartHighlightMatchCase: smartHighlightMatchCase,
            smartHighlightWholeWord: smartHighlightWholeWord,
            caretWidth: caretWidth,
            enableVirtualSpace: enableVirtualSpace,
            backspaceUnindents: backspaceUnindents,
            autoIndent: autoIndent,
            largeFileSizeMB: largeFileSizeMB,
            scrollBeyondLastLine: scrollBeyondLastLine,
            autoCompleteFromNthChar: autoCompleteFromNthChar,
            caretNoBlink: caretNoBlink,
            currentLineFrameWidth: currentLineFrameWidth,
            lineWrapIndent: lineWrapIndent,
            foldMarginStyle: foldMarginStyle,
            useFirstLineAsTabName: useFirstLineAsTabName,
            recentFilesMaxCount: recentFilesMaxCount,
            recentFilesShowFullPath: recentFilesShowFullPath,
            noCheckRecentAtLaunch: noCheckRecentAtLaunch,
            keepAbsentFilesInSession: keepAbsentFilesInSession,
            autoReloadOnExternalChange: autoReloadOnExternalChange,
            backupOnSave: backupOnSave,
            additionalEdgeColumns: additionalEdgeColumns,
            linePadding: linePadding,
            openDirectoryFollowsDocument: openDirectoryFollowsDocument,
            defaultNewDocumentLanguageName: defaultNewDocumentLanguageName,
            folderDropOpensAsWorkspace: folderDropOpensAsWorkspace,
            extraURLSchemes: extraURLSchemes,
            newDocumentOnLaunch: newDocumentOnLaunch,
            postItAlpha: postItAlpha
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
        showNpcCharacters: Bool
    ) -> AppPreferences {
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
            enableXmlTagMatch: enableXmlTagMatch,
            enableClickableLinks: enableClickableLinks,
            defaultNewDocumentEncoding: defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaultNewDocumentLineEnding,
            rememberLastSession: rememberLastSession,
            showNpcCharacters: showNpcCharacters,
            smartHighlightMatchCase: smartHighlightMatchCase,
            smartHighlightWholeWord: smartHighlightWholeWord,
            caretWidth: caretWidth,
            enableVirtualSpace: enableVirtualSpace,
            backspaceUnindents: backspaceUnindents,
            autoIndent: autoIndent,
            largeFileSizeMB: largeFileSizeMB,
            scrollBeyondLastLine: scrollBeyondLastLine,
            autoCompleteFromNthChar: autoCompleteFromNthChar
        )
    }

    public func withSmartHighlightOptions(matchCase: Bool, wholeWord: Bool) -> AppPreferences {
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
            enableXmlTagMatch: enableXmlTagMatch,
            enableClickableLinks: enableClickableLinks,
            defaultNewDocumentEncoding: defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaultNewDocumentLineEnding,
            rememberLastSession: rememberLastSession,
            showNpcCharacters: showNpcCharacters,
            smartHighlightMatchCase: matchCase,
            smartHighlightWholeWord: wholeWord,
            caretWidth: caretWidth,
            enableVirtualSpace: enableVirtualSpace,
            backspaceUnindents: backspaceUnindents,
            autoIndent: autoIndent,
            largeFileSizeMB: largeFileSizeMB,
            scrollBeyondLastLine: scrollBeyondLastLine,
            autoCompleteFromNthChar: autoCompleteFromNthChar
        )
    }

    public func withCaretSettings(width: Int, virtualSpace: Bool) -> AppPreferences {
        AppPreferences(
            editorFontSize: editorFontSize, wrapsLines: wrapsLines,
            searchMatchCase: searchMatchCase, searchWholeWord: searchWholeWord,
            customDateTimeFormat: customDateTimeFormat, searchEngineChoice: searchEngineChoice,
            customSearchEngineURL: customSearchEngineURL, localizationFileName: localizationFileName,
            showWhitespace: showWhitespace, showEOL: showEOL, showIndentGuides: showIndentGuides,
            highlightCurrentLine: highlightCurrentLine, showWrapSymbol: showWrapSymbol,
            showChangeHistory: showChangeHistory, tabSize: tabSize,
            insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs,
            showLineNumberMargin: showLineNumberMargin, showEdgeLine: showEdgeLine,
            edgeLineColumn: edgeLineColumn, enableAutoPair: enableAutoPair,
            enableXmlTagMatch: enableXmlTagMatch, enableClickableLinks: enableClickableLinks,
            defaultNewDocumentEncoding: defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaultNewDocumentLineEnding,
            rememberLastSession: rememberLastSession, showNpcCharacters: showNpcCharacters,
            smartHighlightMatchCase: smartHighlightMatchCase,
            smartHighlightWholeWord: smartHighlightWholeWord,
            caretWidth: width, enableVirtualSpace: virtualSpace,
            backspaceUnindents: backspaceUnindents,
            autoIndent: autoIndent,
            largeFileSizeMB: largeFileSizeMB,
            scrollBeyondLastLine: scrollBeyondLastLine,
            autoCompleteFromNthChar: autoCompleteFromNthChar
        )
    }

    public func withTabSize(_ tabSize: Int) -> AppPreferences {
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
            insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs
        )
    }

    public func withInsertSpacesInsteadOfTabs(_ insertSpacesInsteadOfTabs: Bool) -> AppPreferences {
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
            insertSpacesInsteadOfTabs: insertSpacesInsteadOfTabs
        )
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
        static let enableXmlTagMatch = "notepadMac.enableXmlTagMatch"
        static let enableClickableLinks = "notepadMac.enableClickableLinks"
        static let defaultNewDocumentEncoding = "notepadMac.defaultNewDocumentEncoding"
        static let defaultNewDocumentLineEnding = "notepadMac.defaultNewDocumentLineEnding"
        static let rememberLastSession = "notepadMac.rememberLastSession"
        static let showNpcCharacters = "notepadMac.showNpcCharacters"
        static let smartHighlightMatchCase = "notepadMac.smartHighlightMatchCase"
        static let smartHighlightWholeWord = "notepadMac.smartHighlightWholeWord"
        static let caretWidth = "notepadMac.caretWidth"
        static let enableVirtualSpace = "notepadMac.enableVirtualSpace"
        static let backspaceUnindents = "notepadMac.backspaceUnindents"
        static let autoIndent = "notepadMac.autoIndent"
        static let largeFileSizeMB = "notepadMac.largeFileSizeMB"
        static let scrollBeyondLastLine = "notepadMac.scrollBeyondLastLine"
        static let autoCompleteFromNthChar = "notepadMac.autoCompleteFromNthChar"
        static let caretNoBlink = "notepadMac.caretNoBlink"
        static let currentLineFrameWidth = "notepadMac.currentLineFrameWidth"
        static let lineWrapIndent = "notepadMac.lineWrapIndent"
        static let foldMarginStyle = "notepadMac.foldMarginStyle"
        static let useFirstLineAsTabName = "notepadMac.useFirstLineAsTabName"
        static let recentFilesMaxCount = "notepadMac.recentFilesMaxCount"
        static let recentFilesShowFullPath = "notepadMac.recentFilesShowFullPath"
        static let noCheckRecentAtLaunch = "notepadMac.noCheckRecentAtLaunch"
        static let keepAbsentFilesInSession = "notepadMac.keepAbsentFilesInSession"
        static let autoReloadOnExternalChange = "notepadMac.autoReloadOnExternalChange"
        static let backupOnSave = "notepadMac.backupOnSave"
        static let additionalEdgeColumns = "notepadMac.additionalEdgeColumns"
        static let linePadding = "notepadMac.linePadding"
        static let openDirectoryFollowsDocument = "notepadMac.openDirectoryFollowsDocument"
        static let defaultNewDocumentLanguageName = "notepadMac.defaultNewDocumentLanguageName"
        static let folderDropOpensAsWorkspace = "notepadMac.folderDropOpensAsWorkspace"
        static let extraURLSchemes = "notepadMac.extraURLSchemes"
        static let disabledNativePluginIdentifiers = "notepadMac.disabledNativePluginIdentifiers"
        static let findHistory = "notepadMac.findHistory"
        static let replaceHistory = "notepadMac.replaceHistory"
        static let findSearchMode = "notepadMac.find.searchMode"
        static let findDotMatchesNewline = "notepadMac.find.dotMatchesNewline"
        static let findWrapAround = "notepadMac.find.wrapAround"
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
            enableXmlTagMatch: defaults.object(forKey: Key.enableXmlTagMatch) as? Bool ?? AppPreferences.defaultValue.enableXmlTagMatch,
            enableClickableLinks: defaults.object(forKey: Key.enableClickableLinks) as? Bool ?? AppPreferences.defaultValue.enableClickableLinks,
            defaultNewDocumentEncoding: defaults.string(forKey: Key.defaultNewDocumentEncoding) ?? AppPreferences.defaultValue.defaultNewDocumentEncoding,
            defaultNewDocumentLineEnding: defaults.string(forKey: Key.defaultNewDocumentLineEnding) ?? AppPreferences.defaultValue.defaultNewDocumentLineEnding,
            rememberLastSession: defaults.object(forKey: Key.rememberLastSession) as? Bool ?? AppPreferences.defaultValue.rememberLastSession,
            showNpcCharacters: defaults.object(forKey: Key.showNpcCharacters) as? Bool ?? AppPreferences.defaultValue.showNpcCharacters,
            smartHighlightMatchCase: defaults.object(forKey: Key.smartHighlightMatchCase) as? Bool ?? AppPreferences.defaultValue.smartHighlightMatchCase,
            smartHighlightWholeWord: defaults.object(forKey: Key.smartHighlightWholeWord) as? Bool ?? AppPreferences.defaultValue.smartHighlightWholeWord,
            caretWidth: defaults.object(forKey: Key.caretWidth) as? Int ?? AppPreferences.defaultValue.caretWidth,
            enableVirtualSpace: defaults.object(forKey: Key.enableVirtualSpace) as? Bool ?? AppPreferences.defaultValue.enableVirtualSpace,
            backspaceUnindents: defaults.object(forKey: Key.backspaceUnindents) as? Bool ?? AppPreferences.defaultValue.backspaceUnindents,
            autoIndent: defaults.object(forKey: Key.autoIndent) as? Bool ?? AppPreferences.defaultValue.autoIndent,
            largeFileSizeMB: defaults.object(forKey: Key.largeFileSizeMB) as? Int ?? AppPreferences.defaultValue.largeFileSizeMB,
            scrollBeyondLastLine: defaults.object(forKey: Key.scrollBeyondLastLine) as? Bool ?? AppPreferences.defaultValue.scrollBeyondLastLine,
            autoCompleteFromNthChar: defaults.object(forKey: Key.autoCompleteFromNthChar) as? Int ?? AppPreferences.defaultValue.autoCompleteFromNthChar,
            caretNoBlink: defaults.object(forKey: Key.caretNoBlink) as? Bool ?? false,
            currentLineFrameWidth: defaults.object(forKey: Key.currentLineFrameWidth) as? Int ?? 0,
            lineWrapIndent: defaults.object(forKey: Key.lineWrapIndent) as? Int ?? 0,
            foldMarginStyle: defaults.object(forKey: Key.foldMarginStyle) as? Int ?? 0,
            useFirstLineAsTabName: defaults.object(forKey: Key.useFirstLineAsTabName) as? Bool ?? false,
            recentFilesMaxCount: defaults.object(forKey: Key.recentFilesMaxCount) as? Int ?? 20,
            recentFilesShowFullPath: defaults.object(forKey: Key.recentFilesShowFullPath) as? Bool ?? false,
            noCheckRecentAtLaunch: defaults.object(forKey: Key.noCheckRecentAtLaunch) as? Bool ?? false,
            keepAbsentFilesInSession: defaults.object(forKey: Key.keepAbsentFilesInSession) as? Bool ?? false,
            autoReloadOnExternalChange: defaults.object(forKey: Key.autoReloadOnExternalChange) as? Bool ?? false,
            backupOnSave: defaults.object(forKey: Key.backupOnSave) as? Bool ?? false,
            additionalEdgeColumns: defaults.string(forKey: Key.additionalEdgeColumns) ?? "",
            linePadding: defaults.object(forKey: Key.linePadding) as? Int ?? 0,
            openDirectoryFollowsDocument: defaults.object(forKey: Key.openDirectoryFollowsDocument) as? Bool ?? false,
            defaultNewDocumentLanguageName: defaults.string(forKey: Key.defaultNewDocumentLanguageName) ?? "",
            folderDropOpensAsWorkspace: defaults.object(forKey: Key.folderDropOpensAsWorkspace) as? Bool ?? false,
            extraURLSchemes: defaults.string(forKey: Key.extraURLSchemes) ?? ""
        )
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
        defaults.set(preferences.enableXmlTagMatch, forKey: Key.enableXmlTagMatch)
        defaults.set(preferences.enableClickableLinks, forKey: Key.enableClickableLinks)
        defaults.set(preferences.defaultNewDocumentEncoding, forKey: Key.defaultNewDocumentEncoding)
        defaults.set(preferences.defaultNewDocumentLineEnding, forKey: Key.defaultNewDocumentLineEnding)
        defaults.set(preferences.rememberLastSession, forKey: Key.rememberLastSession)
        defaults.set(preferences.showNpcCharacters, forKey: Key.showNpcCharacters)
        defaults.set(preferences.smartHighlightMatchCase, forKey: Key.smartHighlightMatchCase)
        defaults.set(preferences.smartHighlightWholeWord, forKey: Key.smartHighlightWholeWord)
        defaults.set(preferences.caretWidth, forKey: Key.caretWidth)
        defaults.set(preferences.enableVirtualSpace, forKey: Key.enableVirtualSpace)
        defaults.set(preferences.backspaceUnindents, forKey: Key.backspaceUnindents)
        defaults.set(preferences.autoIndent, forKey: Key.autoIndent)
        defaults.set(preferences.largeFileSizeMB, forKey: Key.largeFileSizeMB)
        defaults.set(preferences.scrollBeyondLastLine, forKey: Key.scrollBeyondLastLine)
        defaults.set(preferences.autoCompleteFromNthChar, forKey: Key.autoCompleteFromNthChar)
        defaults.set(preferences.caretNoBlink, forKey: Key.caretNoBlink)
        defaults.set(preferences.currentLineFrameWidth, forKey: Key.currentLineFrameWidth)
        defaults.set(preferences.lineWrapIndent, forKey: Key.lineWrapIndent)
        defaults.set(preferences.foldMarginStyle, forKey: Key.foldMarginStyle)
        defaults.set(preferences.useFirstLineAsTabName, forKey: Key.useFirstLineAsTabName)
        defaults.set(preferences.recentFilesMaxCount, forKey: Key.recentFilesMaxCount)
        defaults.set(preferences.recentFilesShowFullPath, forKey: Key.recentFilesShowFullPath)
        defaults.set(preferences.noCheckRecentAtLaunch, forKey: Key.noCheckRecentAtLaunch)
        defaults.set(preferences.keepAbsentFilesInSession, forKey: Key.keepAbsentFilesInSession)
        defaults.set(preferences.autoReloadOnExternalChange, forKey: Key.autoReloadOnExternalChange)
        defaults.set(preferences.backupOnSave, forKey: Key.backupOnSave)
        defaults.set(preferences.additionalEdgeColumns, forKey: Key.additionalEdgeColumns)
        defaults.set(preferences.linePadding, forKey: Key.linePadding)
        defaults.set(preferences.openDirectoryFollowsDocument, forKey: Key.openDirectoryFollowsDocument)
        defaults.set(preferences.defaultNewDocumentLanguageName, forKey: Key.defaultNewDocumentLanguageName)
        defaults.set(preferences.folderDropOpensAsWorkspace, forKey: Key.folderDropOpensAsWorkspace)
        defaults.set(preferences.extraURLSchemes, forKey: Key.extraURLSchemes)
        defaults.synchronize()
    }

    public func loadFindHistory() -> [String] {
        defaults.stringArray(forKey: Key.findHistory) ?? []
    }

    public func saveFindHistory(_ history: [String]) {
        let capped = Array(history.prefix(20))
        defaults.set(capped, forKey: Key.findHistory)
        defaults.synchronize()
    }

    public func loadReplaceHistory() -> [String] {
        defaults.stringArray(forKey: Key.replaceHistory) ?? []
    }

    public func saveReplaceHistory(_ history: [String]) {
        let capped = Array(history.prefix(20))
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
}
