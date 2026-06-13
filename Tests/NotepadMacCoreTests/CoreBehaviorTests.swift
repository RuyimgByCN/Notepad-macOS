import Foundation
import Testing
@testable import NotepadMacCore

@Test func detectsDominantLineEnding() {
    #expect(LineEnding.detect(in: "one\r\ntwo\r\nthree\n") == .crlf)
    #expect(LineEnding.detect(in: "one\ntwo\nthree\r\n") == .lf)
    #expect(LineEnding.detect(in: "one\rtwo\rthree") == .cr)
}

@Test func normalizesTextToSelectedLineEnding() {
    let source = "one\r\ntwo\nthree\rfour"

    #expect(LineEnding.crlf.normalize(source) == "one\r\ntwo\r\nthree\r\nfour")
    #expect(LineEnding.lf.normalize(source) == "one\ntwo\nthree\nfour")
}

@Test func detectsLanguageFromFileExtension() {
    let catalog = LanguageCatalog.fallback

    #expect(LanguageDetector.detect(url: URL(filePath: "/tmp/main.rs"), in: catalog).name == "rust")
    #expect(LanguageDetector.detect(url: URL(filePath: "/tmp/viewController.swift"), in: catalog).name == "swift")
    #expect(LanguageDetector.detect(url: URL(filePath: "/tmp/widget.cpp"), in: catalog).name == "cpp")
    #expect(LanguageDetector.detect(url: URL(filePath: "/tmp/notes.md"), in: catalog).name == "markdown")
    #expect(LanguageDetector.detect(url: URL(filePath: "/tmp/untitled.unknown"), in: catalog).name == "normal")
    #expect(LanguageDetector.detect(url: nil, in: catalog).name == "normal")
}

@Test func parsesUpstreamNotepadPlusLanguageModel() throws {
    let catalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let rust = try #require(catalog.language(named: "rust"))
    let cpp = try #require(catalog.language(named: "cpp"))

    #expect(rust.extensions == ["rs"])
    #expect(rust.lineComment == "//")
    #expect(rust.blockCommentStart == "/*")
    #expect(rust.blockCommentEnd == "*/")
    #expect(rust.allKeywords.contains("fn"))
    #expect(cpp.extensions.contains("hpp"))
    #expect(catalog.detect(url: URL(filePath: "/tmp/main.rs")).name == "rust")
    #expect(catalog.detect(url: URL(filePath: "/tmp/header.hxx")).name == "cpp")
    #expect(catalog.detect(url: URL(filePath: "/tmp/no-extension")).name == "normal")
}

@Test func mapsNotepadPlusLanguagesToLexillaLexerNames() throws {
    let catalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let expectedMappings = [
        ("bash", "bash"),
        ("cpp", "cpp"),
        ("css", "css"),
        ("html", "hypertext"),
        ("json", "json"),
        ("makefile", "makefile"),
        ("python", "python"),
        ("rust", "rust"),
        ("sql", "sql"),
        ("xml", "xml")
    ]

    for (languageName, lexerName) in expectedMappings {
        let language = try #require(catalog.language(named: languageName))
        #expect(language.lexillaLexerName == lexerName)
    }

    #expect(NotepadPlusLexillaMapping.lexerName(for: "markdown") == "markdown")
    #expect(catalog.language(named: "normal")?.lexillaLexerName == nil)
    #expect(catalog.language(named: "swift")?.lexillaLexerName == "cpp")
}

@Test func mapsUpstreamLangNameInfoArrayLanguagesToLexillaLexers() throws {
    // Mirror of upstream ScintillaEditView::_langNameInfoArray (_langName →
    // _lexerID) minus "null"-lexer and internal entries. Guards the complete
    // language → lexer table against regressions.
    let upstreamMappings: [String: String] = [
        "php": "phpscript", "c": "cpp", "cpp": "cpp", "cs": "cpp",
        "objc": "objc", "java": "cpp", "rc": "cpp", "html": "hypertext",
        "xml": "xml", "makefile": "makefile", "pascal": "pascal",
        "batch": "batch", "ini": "props", "asp": "hypertext", "sql": "sql",
        "vb": "vb", "javascript": "cpp", "css": "css", "perl": "perl",
        "python": "python", "lua": "lua", "tex": "tex", "fortran": "fortran",
        "bash": "bash", "actionscript": "cpp", "nsis": "nsis", "tcl": "tcl",
        "lisp": "lisp", "scheme": "lisp", "asm": "asm", "diff": "diff",
        "props": "props", "postscript": "ps", "ruby": "ruby",
        "smalltalk": "smalltalk", "vhdl": "vhdl", "kix": "kix",
        "autoit": "au3", "caml": "caml", "ada": "ada", "verilog": "verilog",
        "matlab": "matlab", "haskell": "haskell", "inno": "inno",
        "cmake": "cmake", "yaml": "yaml", "cobol": "COBOL",
        "gui4cli": "gui4cli", "d": "d", "powershell": "powershell", "r": "r",
        "jsp": "hypertext", "coffeescript": "coffeescript", "json": "json",
        "javascript.js": "cpp", "fortran77": "f77", "baanc": "baan",
        "srec": "srec", "ihex": "ihex", "tehex": "tehex", "swift": "cpp",
        "asn1": "asn1", "avs": "avs", "blitzbasic": "blitzbasic",
        "purebasic": "purebasic", "freebasic": "freebasic",
        "csound": "csound", "erlang": "erlang", "escript": "escript",
        "forth": "forth", "latex": "latex", "mmixal": "mmixal",
        "nim": "nimrod", "nncrontab": "nncrontab", "oscript": "oscript",
        "rebol": "rebol", "registry": "registry", "rust": "rust",
        "spice": "spice", "txt2tags": "txt2tags",
        "visualprolog": "visualprolog", "typescript": "cpp",
        "json5": "json", "mssql": "mssql", "gdscript": "gdscript",
        "hollywood": "hollywood", "go": "cpp", "raku": "raku",
        "toml": "toml", "sas": "sas", "escseq": "escseq"
    ]

    for (languageName, lexerName) in upstreamMappings {
        #expect(
            NotepadPlusLexillaMapping.lexerName(for: languageName) == lexerName,
            "\(languageName) should map to \(lexerName)"
        )
    }

    // Upstream "null"-lexer entries must keep using the native fallback.
    #expect(NotepadPlusLexillaMapping.lexerName(for: "normal") == nil)
    #expect(NotepadPlusLexillaMapping.lexerName(for: "nfo") == nil)
}

@Test func lexillaMappingCoversNearlyAllUpstreamCatalogLanguages() throws {
    let catalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let excluded: Set<String> = ["normal", "nfo", "searchresult", "errorlist", "udf"]
    let languages = catalog.languages.filter { !excluded.contains($0.name.lowercased()) }
    let mapped = languages.filter { $0.lexillaLexerName != nil }

    let coverage = Double(mapped.count) / Double(max(languages.count, 1))
    let unmappedNames = languages.filter { $0.lexillaLexerName == nil }.map(\.name)
    #expect(coverage >= 0.9, "lexer coverage \(coverage) too low; unmapped: \(unmappedNames)")
}

@Test func parsesUpstreamNotepadPlusStyleModel() throws {
    let catalog = try StyleCatalog.load(from: upstreamStyleModelURL())
    let rust = try #require(catalog.lexer(named: "rust"))
    let rustKeyword = try #require(rust.style(id: 6))
    let defaultStyle = try #require(catalog.globalStyle(named: "Default Style"))

    #expect(rust.displayName == "Rust")
    #expect(rust.styles.count >= 20)
    #expect(rustKeyword.name == "KEYWORDS 1")
    #expect(rustKeyword.foreground == StyleColor(hexRGB: "00007F"))
    #expect(rustKeyword.background == StyleColor(hexRGB: "FFFFFF"))
    #expect(rustKeyword.keywordClass == "instre1")
    #expect(rustKeyword.isBold)
    #expect(!rustKeyword.isItalic)
    #expect(defaultStyle.foreground == StyleColor(hexRGB: "000000"))
    #expect(defaultStyle.background == StyleColor(hexRGB: "FFFFFF"))
    #expect(defaultStyle.fontName == "Courier New")
    #expect(defaultStyle.fontSize == 10)
}

@Test func routesNotepadPlusWidgetStylesWithoutClobberingXmlSgmlStyles() throws {
    let catalog = try StyleCatalog.load(from: upstreamStyleModelURL())
    let xml = try #require(catalog.lexer(named: "xml"))
    let sgmlDefault = try #require(xml.style(id: 21))
    let markStyle5 = try #require(catalog.globalStyle(named: "Mark Style 5"))

    #expect(sgmlDefault.name == "SGML DEFAULT")
    #expect(markStyle5.styleID == 21)
    #expect(ScintillaStyleRouting.isNotepadPlusIndicatorStyle(markStyle5.styleID))
    #expect(!ScintillaStyleRouting.isGlobalTextStyle(markStyle5.styleID))
    #expect(ScintillaStyleRouting.isGlobalTextStyle(32))
}

@Test func mapsXmlDtdKeywordsToLexillaXmlKeywordSlot() throws {
    let catalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let xml = try #require(catalog.language(named: "xml"))
    let dtdKeywords = try #require(xml.scintillaKeywordSets.first { $0.index == 5 })
    let lexillaProperties = xml.lexillaProperties

    #expect(dtdKeywords.keywords.contains("DOCTYPE"))
    #expect(!xml.scintillaKeywordSets.contains { $0.index == 0 })
    #expect(lexillaProperties.count == 1)
    #expect(lexillaProperties[0].name == "lexer.xml.allow.scripts")
    #expect(lexillaProperties[0].value == "0")
}

@Test func representativeLexillaLanguagesHaveUpstreamStyleEntries() throws {
    let languageCatalog = try LanguageCatalog.load(from: upstreamLanguageModelURL())
    let styleCatalog = try StyleCatalog.load(from: upstreamStyleModelURL())
    let styledLanguages = [
        "bash",
        "cpp",
        "css",
        "html",
        "json",
        "makefile",
        "python",
        "rust",
        "sql",
        "xml"
    ]

    for languageName in styledLanguages {
        let language = try #require(languageCatalog.language(named: languageName))
        let lexer = try #require(styleCatalog.lexer(named: languageName))
        #expect(language.lexillaLexerName != nil)
        #expect(!lexer.styles.isEmpty)
    }

    let plainText = try #require(languageCatalog.language(named: "normal"))
    #expect(plainText.lexillaLexerName == nil)
    #expect(NotepadPlusLexillaMapping.lexerName(for: "markdown") == "markdown")
    #expect(styleCatalog.lexer(named: "normal") == nil)
    #expect(styleCatalog.lexer(named: "markdown") == nil)
}

@Test func convertsNotepadPlusRgbColorsToScintillaColorOrder() throws {
    let orange = try #require(StyleColor(hexRGB: "FF8000"))

    #expect(orange.red == 255)
    #expect(orange.green == 128)
    #expect(orange.blue == 0)
    #expect(orange.scintillaColor == 0x0080FF)
    #expect(StyleColor(hexRGB: "") == nil)
    #expect(StyleColor(hexRGB: "XYZ123") == nil)
}

@Test func stylePreferencesStorePersistsAndResolvesOverrides() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let key = StyleOverrideKey(languageName: "rust", styleID: 6)
    let base = LexerStyle(
        name: "KEYWORDS 1",
        styleID: 6,
        foreground: StyleColor(hexRGB: "00007F"),
        background: StyleColor(hexRGB: "FFFFFF"),
        fontName: nil,
        fontSize: nil,
        fontStyle: 1,
        keywordClass: "instre1"
    )
    let override = StyleOverride(
        foreground: StyleColor(hexRGB: "FF0000"),
        background: StyleColor(hexRGB: "101820"),
        fontName: "Menlo",
        fontSize: 15,
        fontStyle: 2
    )
    let saved = StylePreferences(overrides: [key: override])
    let store = StylePreferencesStore(defaults: defaults)

    #expect(store.load() == .empty)
    store.save(saved)
    #expect(store.load() == saved)
    #expect(saved.resolvedStyle(for: key, base: base).foreground == StyleColor(hexRGB: "FF0000"))
    #expect(saved.resolvedStyle(for: key, base: base).background == StyleColor(hexRGB: "101820"))
    #expect(saved.resolvedStyle(for: key, base: base).fontName == "Menlo")
    #expect(saved.resolvedStyle(for: key, base: base).fontSize == 15)
    #expect(saved.resolvedStyle(for: key, base: base).isItalic)

    store.clear()
    #expect(store.load() == .empty)
}

@Test func scansUpstreamNotepadPlusThemes() throws {
    let catalog = try ThemeCatalog.scan(directories: [upstreamThemesDirectoryURL()])
    let monokai = try #require(catalog.theme(named: "Monokai"))

    #expect(catalog.themes.contains { $0.name == "DarkModeDefault" })
    #expect(monokai.displayName == "Monokai")
    #expect(monokai.url.lastPathComponent == "Monokai.xml")
    #expect(try catalog.loadStyleCatalog(for: monokai).lexer(named: "rust") != nil)
}

@Test func themeCatalogUserDirectoryIsUnderApplicationSupport() {
    let userDir = ThemeCatalog.userThemesDirectory
    #expect(userDir.path.contains("Application Support"))
    #expect(userDir.lastPathComponent == "themes")
    #expect(userDir.deletingLastPathComponent().lastPathComponent == "NotepadMac")
}

@Test func themeCatalogScansUserDirectoryFirst() throws {
    let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: tmp) }
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

    // Write a minimal valid XML theme
    let xml = """
    <?xml version="1.0"?>
    <NotepadPlus><LexerStyles><LexerType name="normal" desc="Normal Text"><WordsStyle name="DEFAULT" styleID="0" fgColor="000000" bgColor="FFFFFF"/></LexerType></LexerStyles><GlobalStyles/></NotepadPlus>
    """
    let themeURL = tmp.appending(path: "MyCustomTheme.xml")
    try xml.write(to: themeURL, atomically: true, encoding: .utf8)

    // Scan tmp dir first, then upstream
    let catalog = try ThemeCatalog.scan(directories: [tmp, upstreamThemesDirectoryURL()])
    let custom = try #require(catalog.theme(named: "MyCustomTheme"))
    #expect(custom.displayName == "MyCustomTheme")
    // User theme should be accessible (its URL points to tmp)
    #expect(custom.url.deletingLastPathComponent().path == tmp.path)
}

@Test func storesAndLoadsSelectedThemePreference() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = ThemePreferencesStore(defaults: defaults)
    #expect(store.load().selectedThemeName == nil)

    store.save(ThemePreferences(selectedThemeName: "Monokai"))
    #expect(store.load().selectedThemeName == "Monokai")

    store.clear()
    #expect(store.load().selectedThemeName == nil)
}

@Test func bookmarkSetTogglesAndKeepsSortedUniqueLines() {
    let bookmarks = BookmarkSet()
        .toggling(line: 3)
        .toggling(line: 1)
        .toggling(line: 3)
        .toggling(line: 5)

    #expect(bookmarks.sortedLines == [1, 5])
    #expect(bookmarks.contains(line: 1))
    #expect(!bookmarks.contains(line: 3))
    #expect(BookmarkSet(lines: [0, -1, 2, 2]).sortedLines == [2])
}

@Test func bookmarkSetNavigatesWithWraparound() {
    let bookmarks = BookmarkSet(lines: [2, 5, 9])

    #expect(bookmarks.next(after: 1) == 2)
    #expect(bookmarks.next(after: 5) == 9)
    #expect(bookmarks.next(after: 9) == 2)
    #expect(bookmarks.previous(before: 9) == 5)
    #expect(bookmarks.previous(before: 2) == 9)
    #expect(BookmarkSet().next(after: 1) == nil)
}

@Test func bookmarkSetClampsToDocumentLineCount() {
    let bookmarks = BookmarkSet(lines: [1, 2, 5, 8]).clamped(toLineCount: 5)

    #expect(bookmarks.sortedLines == [1, 2, 5])
    #expect(BookmarkSet(lines: [1]).clamped(toLineCount: 0).isEmpty)
}

@Test func bookmarkSetExposesZeroBasedLinesForScintillaMarkers() {
    let bookmarks = BookmarkSet(lines: [3, 1, 3])

    #expect(bookmarks.zeroBasedLines == [0, 2])
}

@Test func textPositionComputesOneBasedLineAndColumnFromUTF16Offset() {
    #expect(TextPosition.lineAndColumn(in: "abc", utf16Location: 0) == TextPosition(line: 1, column: 1))
    #expect(TextPosition.lineAndColumn(in: "abc", utf16Location: 1) == TextPosition(line: 1, column: 2))
    #expect(TextPosition.lineAndColumn(in: "abc", utf16Location: 3) == TextPosition(line: 1, column: 4))
    #expect(TextPosition.lineAndColumn(in: "ab\ncd", utf16Location: 4) == TextPosition(line: 2, column: 2))
    #expect(TextPosition.lineAndColumn(in: "ab\r\ncd", utf16Location: 5) == TextPosition(line: 2, column: 2))
    #expect(TextPosition.lineAndColumn(in: "ab\n", utf16Location: 3) == TextPosition(line: 2, column: 1))
}

@Test func columnEditInsertsTextAcrossSelectedLinesAtColumn() throws {
    let result = try ColumnEdit.insertText(
        "| ",
        into: "alpha\nbravo\ncharlie\n",
        lineRange: 1...3,
        column: 1
    )

    #expect(result.text == "| alpha\n| bravo\n| charlie\n")
    #expect(result.insertedRanges.map(\.location) == [0, 8, 16])
    #expect(result.insertedRanges.map(\.length) == [2, 2, 2])
}

@Test func columnEditPadsShortLinesAndPreservesLineEndings() throws {
    let result = try ColumnEdit.insertText(
        "X",
        into: "a\r\nabcd\r\n",
        lineRange: 1...2,
        column: 4
    )

    #expect(result.text == "a  X\r\nabcXd\r\n")
}

@Test func columnEditInsertsDecimalNumberSequenceWithRepeat() throws {
    let result = try ColumnEdit.insertNumberSequence(
        into: "a\nb\nc\nd\n",
        lineRange: 1...4,
        column: 1,
        options: ColumnNumberOptions(initial: 10, increment: 2, repeatCount: 2, format: .decimal)
    )

    #expect(result.text == "10a\n10b\n12c\n12d\n")
    #expect(result.insertedRanges.map(\.length) == [2, 2, 2, 2])
}

@Test func columnEditFormatsNumberSequenceInCommonBasesAndPadding() throws {
    let hex = try ColumnEdit.insertNumberSequence(
        into: "x\ny\n",
        lineRange: 1...2,
        column: 2,
        options: ColumnNumberOptions(initial: 10, increment: 1, repeatCount: 1, format: .hexadecimal(uppercase: true), padding: .zeros(width: 3))
    )
    let binary = try ColumnEdit.insertNumberSequence(
        into: "x\ny\n",
        lineRange: 1...2,
        column: 1,
        options: ColumnNumberOptions(initial: 2, increment: 1, repeatCount: 1, format: .binary, padding: .spaces(width: 4))
    )

    #expect(hex.text == "x00A\ny00B\n")
    #expect(binary.text == "  10x\n  11y\n")
}

@Test func columnEditRepeatsUppercaseHexValuesBeforeIncrementing() throws {
    let result = try ColumnEdit.insertNumberSequence(
        into: "a\nb\nc\nd\n",
        lineRange: 1...4,
        column: 1,
        options: ColumnNumberOptions(
            initial: 15,
            increment: 2,
            repeatCount: 2,
            format: .hexadecimal(uppercase: true),
            padding: .zeros(width: 4)
        )
    )

    #expect(result.text == "000Fa\n000Fb\n0011c\n0011d\n")
    #expect(result.insertedRanges.map(\.length) == [4, 4, 4, 4])
}

@Test func columnEditFormatsOctalSequenceWithSpacePaddingAtColumn() throws {
    let result = try ColumnEdit.insertNumberSequence(
        into: "ab\ncdef\n",
        lineRange: 1...2,
        column: 3,
        options: ColumnNumberOptions(
            initial: 8,
            increment: 1,
            repeatCount: 1,
            format: .octal,
            padding: .spaces(width: 4)
        )
    )

    #expect(result.text == "ab  10\ncd  11ef\n")
    #expect(result.insertedRanges.map(\.location) == [2, 9])
}

@Test func columnEditRejectsOverflowingNumberSequencesAndFormatsIntMin() throws {
    #expect(throws: ColumnEditError.numberSequenceOverflow) {
        try ColumnEdit.insertNumberSequence(
            into: "\n\n",
            lineRange: 1...2,
            column: 1,
            options: ColumnNumberOptions(initial: Int.max, increment: 1)
        )
    }

    let result = try ColumnEdit.insertNumberSequence(
        into: "\n",
        lineRange: 1...1,
        column: 1,
        options: ColumnNumberOptions(initial: Int.min, increment: 0)
    )
    #expect(result.text == "\(Int.min)\n")
}

@Test func columnEditRejectsInvalidRangesAndColumns() {
    #expect(throws: ColumnEditError.invalidColumn) {
        try ColumnEdit.insertText("x", into: "one\n", lineRange: 1...1, column: 0)
    }
    #expect(throws: ColumnEditError.invalidLineRange) {
        try ColumnEdit.insertText("x", into: "one\n", lineRange: 0...1, column: 1)
    }
    #expect(throws: ColumnEditError.lineRangeOutsideDocument) {
        try ColumnEdit.insertText("x", into: "one\n", lineRange: 1...3, column: 1)
    }
    #expect(throws: ColumnEditError.invalidRepeatCount) {
        try ColumnEdit.insertNumberSequence(
            into: "one\n",
            lineRange: 1...1,
            column: 1,
            options: ColumnNumberOptions(initial: 1, increment: 1, repeatCount: 0)
        )
    }
}

@Test func writesAndReadsUtf8TextWithRequestedLineEndings() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "sample.txt")
    try TextFileCodec.write("one\ntwo\n", to: fileURL, lineEnding: .crlf)

    let raw = try Data(contentsOf: fileURL)
    #expect(String(data: raw, encoding: .utf8) == "one\r\ntwo\r\n")

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "one\r\ntwo\r\n")
    #expect(loaded.encoding == .utf8)
    #expect(loaded.lineEnding == .crlf)
}

@Test func textEncodingOptionsExposeConversionTargetsAndRoundTrip() throws {
    #expect(TextEncodingOption.allCases.map(\.displayName) == [
        "UTF-8",
        "UTF-16",
        "UTF-16 LE",
        "UTF-16 BE",
        "ASCII",
        "ISO Latin-1",
        "Windows CP1252",
        "Mac OS Roman",
        "Mac Cyrillic",
        "GBK (Simplified Chinese)",
        "Big5 (Traditional Chinese)",
        "Shift-JIS (Japanese)",
        "EUC-KR (Korean)",
        "EUC-JP (Japanese)",
        "Windows-1250 (Central European)",
        "Windows-1251 (Cyrillic)",
        "Windows-1253 (Greek)",
        "Windows-1254 (Turkish)",
        "Windows-1255 (Hebrew)",
        "Windows-1256 (Arabic)",
        "Windows-1257 (Baltic)",
        "Windows-1258 (Vietnamese)",
        "ISO 8859-2 (Central European)",
        "ISO 8859-3 (South European)",
        "ISO 8859-4 (Baltic)",
        "ISO 8859-5 (Cyrillic)",
        "ISO 8859-6 (Arabic)",
        "ISO 8859-7 (Greek)",
        "ISO 8859-8 (Hebrew)",
        "ISO 8859-9 (Turkish)",
        "ISO 8859-10 (Nordic)",
        "ISO 8859-13 (Baltic Rim)",
        "ISO 8859-14 (Celtic)",
        "ISO 8859-15 (Western European)",
        "KOI8-R (Russian)",
        "KOI8-U (Ukrainian)",
        "TIS-620 (Thai)",
        "Windows 949 (Korean)",
        "OEM-US CP437 (MS-DOS)",
        "OEM 737 (Greek)",
        "OEM 775 (Baltic Rim)",
        "OEM 850 (Western European)",
        "OEM 852 (Central European)",
        "OEM 855 (Cyrillic)",
        "OEM 857 (Turkish)",
        "OEM 860 (Portuguese)",
        "OEM 862 (Hebrew)",
        "OEM 863 (Canadian French)",
        "OEM 865 (Nordic)",
        "OEM 866 (Cyrillic)",
        "OEM 869 (Modern Greek)",
        "OEM 720 (Arabic)",
        "OEM 858 (Western European, Euro)",
        "OEM 861 (Icelandic)"
    ])
    #expect(TextEncodingOption(encoding: .utf16LittleEndian) == .utf16LittleEndian)
    #expect(TextEncodingOption(encoding: .ascii)?.displayName == "ASCII")
    #expect(TextEncodingOption(encoding: .isoLatin1)?.displayName == "ISO Latin-1")
    #expect(TextEncodingOption(encoding: .windowsCP1252)?.displayName == "Windows CP1252")
    #expect(TextEncodingOption(encoding: .macOSRoman)?.displayName == "Mac OS Roman")
    #expect(TextEncodingOption(encoding: .macCyrillicEncoding)?.displayName == "Mac Cyrillic")

    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    for option in [TextEncodingOption.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian] {
        let fileURL = directory.appending(path: "\(option.rawValue).txt")
        try TextFileCodec.write("hello\n世界", to: fileURL, encoding: option.encoding, lineEnding: .lf)

        let loaded = try TextFileCodec.read(fileURL)
        #expect(loaded.text == "hello\n世界")
        #expect(TextEncodingOption(encoding: loaded.encoding) == option)
    }
}

@Test func textEncodingReadsAndWritesWindowsCP1252Text() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "cp1252.txt")
    let text = "smart “quotes” €\n"
    try TextFileCodec.write(text, to: fileURL, encoding: .windowsCP1252, lineEnding: .lf)

    let raw = try Data(contentsOf: fileURL)
    #expect(raw.contains(0x93))
    #expect(raw.contains(0x94))
    #expect(raw.contains(0x80))

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == text)
    #expect(loaded.encoding == .windowsCP1252)
    #expect(loaded.lineEnding == .lf)
}

@Test func textEncodingRejectsUnavailableCharactersForSingleByteWrites() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    let fileURL = directory.appending(path: "ascii.txt")

    #expect(throws: TextFileCodec.ReadError.unsupportedEncoding) {
        try TextFileCodec.write("accent é", to: fileURL, encoding: .ascii)
    }
}

@Test func capturesFileChangeSnapshotFromDiskMetadata() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "watched.txt")
    try "watch".write(to: fileURL, atomically: true, encoding: .utf8)

    let snapshot = try FileChangeSnapshot.capture(fileURL)

    #expect(snapshot.url == fileURL.standardizedFileURL)
    #expect(snapshot.byteCount == 5)
    #expect(snapshot.modificationDate.timeIntervalSince1970 > 0)
}

@Test func classifiesFileChangeSnapshotDifferences() {
    let url = URL(filePath: "/tmp/watched.txt")
    let baseline = FileChangeSnapshot(
        url: url,
        modificationDate: Date(timeIntervalSince1970: 1_801_310_400),
        byteCount: 10
    )
    let same = FileChangeSnapshot(
        url: url,
        modificationDate: Date(timeIntervalSince1970: 1_801_310_400),
        byteCount: 10
    )
    let changedSize = FileChangeSnapshot(
        url: url,
        modificationDate: Date(timeIntervalSince1970: 1_801_310_400),
        byteCount: 11
    )
    let changedDate = FileChangeSnapshot(
        url: url,
        modificationDate: Date(timeIntervalSince1970: 1_801_310_401),
        byteCount: 10
    )

    #expect(baseline.changeStatus(comparedTo: same) == .unchanged)
    #expect(baseline.changeStatus(comparedTo: changedSize) == .modified(changedSize))
    #expect(baseline.changeStatus(comparedTo: changedDate) == .modified(changedDate))
    #expect(baseline.changeStatus(comparedTo: nil) == .deleted)
}

@Test func printDocumentRendersHeaderAndNumberedLines() {
    let document = PrintDocument(
        title: "main.rs",
        text: "fn main() {\r\n\tprintln!(\"hi\")\r\n}\r\n",
        languageDisplayName: "Rust",
        encodingDisplayName: "UTF-8"
    )

    #expect(document.normalizedLines == ["fn main() {", "\tprintln!(\"hi\")", "}"])
    #expect(document.renderedPlainText().contains("main.rs    Rust    UTF-8"))
    #expect(document.renderedPlainText().contains("   1  fn main() {"))
    #expect(document.renderedPlainText().contains("   2  \tprintln!(\"hi\")"))
}

@Test func printDocumentPaginatesLinesWithoutEmptyTrailingPage() {
    let document = PrintDocument(
        title: "notes.txt",
        text: "one\ntwo\nthree\nfour\n",
        languageDisplayName: "Plain Text",
        encodingDisplayName: "UTF-8"
    )

    let pages = document.pages(linesPerPage: 3)

    #expect(pages.count == 2)
    #expect(pages[0].number == 1)
    #expect(pages[0].totalPages == 2)
    #expect(pages[0].lines == ["one", "two", "three"])
    #expect(pages[1].number == 2)
    #expect(pages[1].lines == ["four"])
    #expect(document.pages(linesPerPage: 0).map(\.lines) == [["one", "two", "three", "four"]])
}

@Test func textEditMacroCommandDiffsAndReplaysInsertionsReplacementsAndDeletes() throws {
    let insert = try #require(MacroCommand.textEdit(from: "alpha", to: "alpha beta"))
    let replace = try #require(MacroCommand.textEdit(from: "alpha beta", to: "alpha BETA"))
    let delete = try #require(MacroCommand.textEdit(from: "alpha BETA", to: "BETA"))

    #expect(insert == .replaceText(range: TextEditRange(location: 5, length: 0), replacement: " beta"))
    #expect(insert.applying(to: "alpha") == "alpha beta")
    #expect(replace.applying(to: "alpha beta") == "alpha BETA")
    #expect(delete.applying(to: "alpha BETA") == "BETA")
    #expect(MacroCommand.textEdit(from: "same", to: "same") == nil)
}

@Test func macroRecordingAppendsOnlyRealTextChangesAndReplaysSequentially() throws {
    let recording = MacroRecording(name: "Last Macro")
        .recordingTextChange(from: "", to: "hello")
        .recordingTextChange(from: "hello", to: "hello")
        .recordingTextChange(from: "hello", to: "hello!")

    #expect(recording.commands.count == 2)
    #expect(recording.replaying(on: "") == "hello!")
}

@Test func macroStorePersistsLastRecording() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = MacroStore(defaults: defaults)
    let recording = MacroRecording(name: "Last Macro")
        .recordingTextChange(from: "", to: "abc")

    #expect(store.loadLastRecording() == nil)
    store.saveLastRecording(recording)
    #expect(store.loadLastRecording() == recording)
    store.clearLastRecording()
    #expect(store.loadLastRecording() == nil)
}

@Test func macroStorePersistsNamedRecordingsAndReplacesByName() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = MacroStore(defaults: defaults)
    let uppercase = MacroRecording(name: "Uppercase word")
        .recordingTextChange(from: "hello", to: "HELLO")
    let padded = MacroRecording(name: "Pad line")
        .recordingTextChange(from: "x", to: "  x")
    let replacement = MacroRecording(name: "uppercase WORD")
        .recordingTextChange(from: "hello", to: "Hello")

    #expect(store.loadNamedRecordings().isEmpty)
    store.saveNamedRecording(uppercase)
    store.saveNamedRecording(padded)
    #expect(store.loadNamedRecordings() == [uppercase, padded])

    store.saveNamedRecording(replacement)
    #expect(store.loadNamedRecordings() == [replacement, padded])
    #expect(store.loadNamedRecording(named: "UPPERCASE word") == replacement)

    store.deleteNamedRecording(named: "pad LINE")
    #expect(store.loadNamedRecordings() == [replacement])

    store.clearNamedRecordings()
    #expect(store.loadNamedRecordings().isEmpty)
}

@Test func pluginCatalogLoadsNativeManifestPlugins() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    let pluginDirectory = directory.appending(path: "NativeTools")
    try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: pluginDirectory.appending(path: "NativeTools.bundle"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "identifier": "org.notepad-plus-plus.macnative.native-tools",
      "name": "Native Tools",
      "version": "1.0.0",
      "entryPoint": "NativeTools.bundle",
      "commands": [
        { "identifier": "uppercase", "title": "Uppercase Document" }
      ]
    }
    """.write(to: pluginDirectory.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)

    let catalog = PluginCatalog.scan(directories: [directory])
    let plugin = try #require(catalog.plugin(identifier: "org.notepad-plus-plus.macnative.native-tools"))

    #expect(plugin.kind == .nativeManifest)
    #expect(plugin.displayName == "Native Tools")
    #expect(plugin.version == "1.0.0")
    #expect(plugin.compatibility == .nativeCompatible)
    #expect(plugin.commands == [PluginCommandDescriptor(identifier: "uppercase", title: "Uppercase Document")])
    #expect(plugin.entryURL?.resolvingSymlinksInPath().path == pluginDirectory.appending(path: "NativeTools.bundle").resolvingSymlinksInPath().path)
}

@Test func pluginCatalogDeduplicatesPluginsWithSharedIdentifierAcrossDirectories() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    let userDirectory = directory.appending(path: "UserPlugins")
    let resourceDirectory = directory.appending(path: "ResourcePlugins")
    try FileManager.default.createDirectory(at: userDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: resourceDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let resourcePluginDirectory = resourceDirectory.appending(path: "SharedPlugin")
    try FileManager.default.createDirectory(at: resourcePluginDirectory, withIntermediateDirectories: true)
    try """
    {
      "identifier": "org.notepad-plus-plus.macnative.shared-plugin",
      "name": "Resource Plugin",
      "version": "1.0.0",
      "entryPoint": "resource-tool",
      "commands": [
        { "identifier": "run", "title": "Run Resource Tool" }
      ]
    }
    """.write(to: resourcePluginDirectory.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)
    try "#!/bin/sh\nexit 0\n".write(
        to: resourcePluginDirectory.appending(path: "resource-tool"),
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: resourcePluginDirectory.appending(path: "resource-tool").path)

    let userPluginDirectory = userDirectory.appending(path: "SharedPlugin")
    try FileManager.default.createDirectory(at: userPluginDirectory, withIntermediateDirectories: true)
    try """
    {
      "identifier": "org.notepad-plus-plus.macnative.shared-plugin",
      "name": "User Plugin",
      "version": "2.0.0",
      "entryPoint": "user-tool",
      "commands": [
        { "identifier": "run", "title": "Run User Tool" }
      ]
    }
    """.write(to: userPluginDirectory.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)
    try "#!/bin/sh\nexit 0\n".write(to: userPluginDirectory.appending(path: "user-tool"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: userPluginDirectory.appending(path: "user-tool").path)

    let firstCatalog = PluginCatalog.scan(directories: [userDirectory, resourceDirectory])
    let firstPlugin = try #require(firstCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.shared-plugin"))

    #expect(firstCatalog.plugins.count == 1)
    #expect(firstPlugin.displayName == "User Plugin")
    #expect(firstPlugin.version == "2.0.0")
    #expect(firstPlugin.commands == [PluginCommandDescriptor(identifier: "run", title: "Run User Tool")])

    let secondCatalog = PluginCatalog.scan(directories: [resourceDirectory, userDirectory])
    let secondPlugin = try #require(secondCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.shared-plugin"))

    #expect(secondCatalog.plugins.count == 1)
    #expect(secondPlugin.displayName == "Resource Plugin")
    #expect(secondPlugin.version == "1.0.0")
    #expect(secondPlugin.commands == [PluginCommandDescriptor(identifier: "run", title: "Run Resource Tool")])
}

@Test func pluginCatalogClassifiesWindowsDllPluginsAsIncompatible() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let dll = directory.appending(path: "NppExec.dll")
    try Data([0x4D, 0x5A]).write(to: dll)

    let catalog = PluginCatalog.scan(directories: [directory])
    let plugin = try #require(catalog.plugins.first)

    #expect(plugin.kind == .windowsDLL)
    #expect(plugin.displayName == "NppExec")
    #expect(plugin.compatibility == .windowsOnly(reason: "Notepad++ plugins are Win32 DLLs and cannot be loaded by the native macOS host without Wine."))
}

@Test func pluginCatalogMarksDisabledNativeManifestPluginsUnsupported() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    let pluginDirectory = directory.appending(path: "NativeTools")
    let companionPluginDirectory = directory.appending(path: "CompanionTools")
    try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: companionPluginDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "identifier": "org.notepad-plus-plus.macnative.native-tools",
      "name": "Native Tools",
      "version": "1.0.0",
      "entryPoint": "native-tools",
      "commands": [
        { "identifier": "uppercase", "title": "Uppercase Document" }
      ]
    }
    """.write(to: pluginDirectory.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)
    try """
    {
      "identifier": "org.notepad-plus-plus.macnative.companion-tools",
      "name": "Companion Tools",
      "version": "1.0.0",
      "commands": []
    }
    """.write(to: companionPluginDirectory.appending(path: "notepad-mac-plugin.json"), atomically: true, encoding: .utf8)

    let dll = directory.appending(path: "NppExec.dll")
    try Data([0x4D, 0x5A]).write(to: dll)

    let catalog = PluginCatalog.scan(directories: [directory])
    let enabledNativePlugin = try #require(catalog.plugin(identifier: "org.notepad-plus-plus.macnative.native-tools"))
    let enabledCompanionPlugin = try #require(catalog.plugin(identifier: "org.notepad-plus-plus.macnative.companion-tools"))
    let windowsPlugin = try #require(catalog.plugin(identifier: "windows-dll:NppExec.dll"))

    #expect(enabledNativePlugin.compatibility == .nativeCompatible)
    #expect(enabledCompanionPlugin.compatibility == .nativeCompatible)
    #expect(windowsPlugin.compatibility == .windowsOnly(reason: PluginCompatibility.windowsDLLReason))

    let disabledCatalog = catalog.withDisabledPlugins([
        "org.notepad-plus-plus.macnative.native-tools",
        "windows-dll:NppExec.dll"
    ])
    let disabledNativePlugin = try #require(disabledCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.native-tools"))
    let enabledNativeCompanionPlugin = try #require(disabledCatalog.plugin(identifier: "org.notepad-plus-plus.macnative.companion-tools"))
    let disabledWindowsPlugin = try #require(disabledCatalog.plugin(identifier: "windows-dll:NppExec.dll"))

    #expect(disabledNativePlugin.compatibility == .unsupported(reason: PluginCompatibility.disabledPluginReason))
    #expect(enabledNativeCompanionPlugin.compatibility == .nativeCompatible)
    #expect(disabledWindowsPlugin.compatibility == .windowsOnly(reason: PluginCompatibility.windowsDLLReason))
}

@Test func pluginCatalogExposesUserPluginDirectoryAsFirstScanLocation() throws {
    let userPluginDirectory = try #require(PluginCatalog.userPluginDirectory())
    let directories = PluginCatalog.defaultPluginDirectories()

    #expect(userPluginDirectory.lastPathComponent == "Plugins")
    #expect(userPluginDirectory.deletingLastPathComponent().lastPathComponent == "Notepad++ Mac")
    #expect(directories.first == userPluginDirectory)
}

@Test func parsesUpstreamNotepadPlusAutoCompletionApi() throws {
    let catalog = try AutoCompletionCatalog.load(from: upstreamApiURL("rust.xml"))
    let println = try #require(catalog.keyword(named: "println!"))

    #expect(catalog.languageDisplayName == "Rust")
    #expect(catalog.environment.ignoreCase == false)
    #expect(catalog.environment.startFunction == "(")
    #expect(catalog.environment.stopFunction == ")")
    #expect(catalog.environment.parameterSeparator == ",")
    #expect(println.isFunction)
    #expect(println.overloads.first?.returnValue == "()")
    #expect(println.overloads.first?.parameters.map(\.name) == ["format string (...)"])
    #expect(catalog.completions(prefix: "prin").map(\.name) == ["print!", "println!"])
}

@Test func autoCompletionCatalogFiltersUsingLanguageCaseSensitivity() {
    let sensitive = AutoCompletionCatalog(
        languageDisplayName: "CaseSensitive",
        environment: AutoCompletionEnvironment(ignoreCase: false),
        keywords: [
            AutoCompletionKeyword(name: "Print"),
            AutoCompletionKeyword(name: "println")
        ]
    )
    let insensitive = AutoCompletionCatalog(
        languageDisplayName: "CaseInsensitive",
        environment: AutoCompletionEnvironment(ignoreCase: true),
        keywords: [
            AutoCompletionKeyword(name: "Print"),
            AutoCompletionKeyword(name: "println")
        ]
    )

    #expect(sensitive.completions(prefix: "pri").map(\.name) == ["println"])
    #expect(insensitive.completions(prefix: "pri").map(\.name) == ["Print", "println"])
}

@Test func autoCompletionCallTipUsesUpstreamFunctionMetadataAtCaret() throws {
    let catalog = try AutoCompletionCatalog.load(from: upstreamApiURL("rust.xml"))
    let text = #"fn main() { println!("value: {}", value"#
    let tip = try #require(catalog.callTip(in: text, caretLocation: (text as NSString).length))

    #expect(tip.keyword.name == "println!")
    #expect(tip.activeParameterIndex == 1)
    #expect(tip.signatures == ["println!(format string (...)) -> ()"])
    #expect(tip.details == ["Prints to standard output with newline"])
}

@Test func autoCompletionCallTipIgnoresNestedParameterSeparators() throws {
    let catalog = AutoCompletionCatalog(
        languageDisplayName: "Test",
        environment: AutoCompletionEnvironment(startFunction: "(", stopFunction: ")", parameterSeparator: ","),
        keywords: [
            AutoCompletionKeyword(
                name: "outer",
                isFunction: true,
                overloads: [
                    AutoCompletionOverload(
                        returnValue: "Int",
                        description: "Combines values",
                        parameters: [
                            AutoCompletionParameter(name: "first"),
                            AutoCompletionParameter(name: "second"),
                            AutoCompletionParameter(name: "third")
                        ]
                    )
                ]
            )
        ]
    )
    let text = "outer(first, inner(a, b), "
    let tip = try #require(catalog.callTip(in: text, caretLocation: (text as NSString).length))

    #expect(tip.keyword.name == "outer")
    #expect(tip.activeParameterIndex == 2)
    #expect(tip.signatures == ["outer(first, second, third) -> Int"])
}

@Test func autoCompletionCallTipIgnoresStringsAndCommentsWhileCountingArguments() throws {
    let catalog = AutoCompletionCatalog(
        languageDisplayName: "Test",
        environment: AutoCompletionEnvironment(startFunction: "(", stopFunction: ")", parameterSeparator: ","),
        keywords: [
            AutoCompletionKeyword(
                name: "foo",
                isFunction: true,
                overloads: [
                    AutoCompletionOverload(parameters: [
                        AutoCompletionParameter(name: "message"),
                        AutoCompletionParameter(name: "value")
                    ])
                ]
            )
        ]
    )

    let stringArgument = #"foo("),", value"#
    let stringTip = try #require(catalog.callTip(in: stringArgument, caretLocation: (stringArgument as NSString).length))
    #expect(stringTip.activeParameterIndex == 1)

    let commentArgument = "foo(first /* ignored, ) */, second"
    let commentTip = try #require(catalog.callTip(in: commentArgument, caretLocation: (commentArgument as NSString).length))
    #expect(commentTip.activeParameterIndex == 1)
}

@Test func parsesUpstreamNotepadPlusFunctionListMetadata() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("rust.xml"))

    #expect(definition.displayName == "Rust")
    #expect(definition.identifier == "rust_function")
    #expect(definition.functionPatterns.contains { $0.contains("fn") })
}

@Test func extractsNativeFunctionListSymbolsForRust() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("rust.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        pub struct App {
            value: i32,
        }

        pub fn top_level() {}

        impl App {
            async fn run(&self) {}
        }
        """,
        languageName: "rust",
        definition: definition
    )

    #expect(symbols.map(\.name) == ["App", "top_level", "run"])
    #expect(symbols.map(\.kind) == [.type, .function, .function])
    #expect(symbols.map(\.line) == [1, 5, 8])
}

@Test func extractsNativeFunctionListSymbolsForCSS() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("css.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        .container {
            display: flex;
        }
        #header {
            color: red;
        }
        @keyframes fadeIn {
            from { opacity: 0; }
        }
        """,
        languageName: "css",
        definition: definition
    )
    #expect(symbols.map(\.name).contains(".container"))
    #expect(symbols.map(\.name).contains("#header"))
    #expect(symbols.map(\.name).contains("fadeIn"))
}

@Test func extractsNativeFunctionListSymbolsForBatch() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("batch.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        @echo off
        :main
        echo hello
        :cleanup
        exit /b 0
        """,
        languageName: "batch",
        definition: definition
    )
    #expect(symbols.map(\.name).contains("main"))
    #expect(symbols.map(\.name).contains("cleanup"))
}

@Test func extractsNativeFunctionListSymbolsForFortran() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("fortran.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        program myProgram
        end program
        subroutine computeSum(a, b)
        end subroutine
        function square(x)
        end function
        """,
        languageName: "fortran",
        definition: definition
    )
    #expect(symbols.map(\.name).contains("myProgram"))
    #expect(symbols.map(\.name).contains("computeSum"))
    #expect(symbols.map(\.name).contains("square"))
}

@Test func extractsNativeFunctionListSymbolsForHaskell() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("haskell.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        data Tree a = Leaf | Node a (Tree a) (Tree a)
        class Container f where
        myFunc :: Int -> Int
        helper :: String -> Bool
        """,
        languageName: "haskell",
        definition: definition
    )
    #expect(symbols.map(\.name).contains("Tree"))
    #expect(symbols.map(\.name).contains("myFunc"))
}

@Test func extractsNativeFunctionListSymbolsForINI() throws {
    let definition = try FunctionListDefinition.load(from: upstreamFunctionListURL("ini.xml"))
    let symbols = FunctionListExtractor.extract(
        from: """
        [database]
        host=localhost
        [server]
        port=8080
        """,
        languageName: "ini",
        definition: definition
    )
    #expect(symbols.map(\.name).contains("database"))
    #expect(symbols.map(\.name).contains("server"))
}

@Test func findsNextMatchWithWrapAndCaseOptions() {
    let text = "Alpha beta alpha"
    let insensitive = TextSearch.Options(matchCase: false)
    let sensitive = TextSearch.Options(matchCase: true)

    #expect(TextSearch.findNext("alpha", in: text, from: NSRange(location: 1, length: 0), options: insensitive) == NSRange(location: 11, length: 5))
    #expect(TextSearch.findNext("alpha", in: text, from: NSRange(location: 12, length: 0), options: insensitive) == NSRange(location: 0, length: 5))
    #expect(TextSearch.findNext("alpha", in: text, from: NSRange(location: 0, length: 0), options: sensitive) == NSRange(location: 11, length: 5))
}

@Test func respectsWholeWordSearch() {
    let text = "car carpet car"
    let options = TextSearch.Options(wholeWord: true)

    #expect(TextSearch.findNext("car", in: text, from: NSRange(location: 1, length: 0), options: options) == NSRange(location: 11, length: 3))
    #expect(TextSearch.findNext("car", in: text, from: NSRange(location: 12, length: 0), options: options) == NSRange(location: 0, length: 3))
}

@Test func replacesNextAndAllMatches() {
    let options = TextSearch.Options(matchCase: false, wholeWord: true)
    let text = "cat scatter Cat cat"

    let single = TextSearch.replaceNext("cat", with: "dog", in: text, from: NSRange(location: 0, length: 0), options: options)
    #expect(single?.text == "dog scatter Cat cat")
    #expect(single?.replacedRange == NSRange(location: 0, length: 3))

    let all = TextSearch.replaceAll("cat", with: "dog", in: text, options: options)
    #expect(all.text == "dog scatter dog dog")
    #expect(all.count == 3)
}

@Test func textSearchFindsPreviousMatchAndWrapsUpward() {
    let text = "Alpha beta alpha"
    let secondMatch = NSRange(location: 11, length: 5)

    let insensitive = TextSearch.Options(matchCase: false, direction: .up)
    #expect(TextSearch.findNext("alpha", in: text, from: secondMatch, options: insensitive) == NSRange(location: 0, length: 5))

    let sensitiveNoWrap = TextSearch.Options(matchCase: true, wraps: false, direction: .up)
    #expect(TextSearch.findNext("alpha", in: text, from: secondMatch, options: sensitiveNoWrap) == nil)

    let firstMatch = NSRange(location: 0, length: 5)
    #expect(TextSearch.findNext("alpha", in: text, from: firstMatch, options: insensitive) == secondMatch)
}

@Test func textSearchReturnsNilWhenSearchingUpWithoutWrap() {
    let options = TextSearch.Options(wraps: false, direction: .up)

    #expect(TextSearch.findNext("alpha", in: "alpha beta alpha", from: NSRange(location: 0, length: 5), options: options) == nil)
}

@Test func textSearchAppliesWholeWordWhenSearchingUpward() {
    let text = "car carpet scar car"
    let options = TextSearch.Options(wholeWord: true, direction: .up)

    #expect(TextSearch.findNext("car", in: text, from: NSRange(location: 16, length: 3), options: options) == NSRange(location: 0, length: 3))
}

@Test func textSearchReplaceNextFollowsUpwardDirection() {
    let text = "alpha beta alpha"
    let options = TextSearch.Options(direction: .up)

    let result = TextSearch.replaceNext("alpha", with: "omega", in: text, from: NSRange(location: 11, length: 5), options: options)

    #expect(result?.text == "omega beta alpha")
    #expect(result?.replacedRange == NSRange(location: 0, length: 5))
}

@Test func textSearchReplaceAllIgnoresUpwardDirection() {
    let result = TextSearch.replaceAll("aa", with: "a", in: "aaaa", options: TextSearch.Options(direction: .up))

    #expect(result.text == "aa")
    #expect(result.count == 2)
}

@Test func textSearchFindsAllMatchesWithSearchOptions() {
    let text = "cat scatter Cat cat\nconcatenate cat"
    let wholeWordUpward = TextSearch.Options(matchCase: false, wholeWord: true, direction: .up)

    #expect(TextSearch.findAll("cat", in: text, options: wholeWordUpward) == [
        NSRange(location: 0, length: 3),
        NSRange(location: 12, length: 3),
        NSRange(location: 16, length: 3),
        NSRange(location: 32, length: 3)
    ])
    #expect(TextSearch.findAll("cat", in: text, options: TextSearch.Options(matchCase: true, wholeWord: true)) == [
        NSRange(location: 0, length: 3),
        NSRange(location: 16, length: 3),
        NSRange(location: 32, length: 3)
    ])
    #expect(TextSearch.findAll("", in: text).isEmpty)
}

@Test func bookmarkSetAddsLinesForSearchMatches() {
    let text = "alpha one\nbeta alpha\nALPHA again\nalphabet\n"
    let matches = TextSearch.findAll("alpha", in: text, options: TextSearch.Options(matchCase: false, wholeWord: true))

    #expect(BookmarkSet.linesContainingSearchMatches(matches, in: text) == [1, 2, 3])
    #expect(BookmarkSet.linesContainingSearchMatches(TextSearch.findAll("alpha", in: "alpha alpha\n"), in: "alpha alpha\n") == [1])
    #expect(BookmarkSet(lines: [2, 8]).addingSearchMatches(matches, in: text).sortedLines == [1, 2, 3, 8])
}

@Test func appPreferencesClampEditorFontSizeAndExposeSearchOptions() {
    let tooSmall = AppPreferences(
        editorFontSize: 4,
        wrapsLines: true,
        searchMatchCase: true,
        searchWholeWord: true,
        customDateTimeFormat: "yyyy-MM-dd"
    )
    let tooLarge = AppPreferences(editorFontSize: 40, wrapsLines: false, searchMatchCase: false, searchWholeWord: false)

    #expect(AppPreferences.defaultValue.editorFontSize == 13)
    #expect(tooSmall.editorFontSize == 9)
    #expect(tooLarge.editorFontSize == 32)
    #expect(tooSmall.searchOptions == TextSearch.Options(matchCase: true, wholeWord: true))
    #expect(tooSmall.customDateTimeFormat == "yyyy-MM-dd")
    #expect(AppPreferences.defaultValue.searchEngineChoice == .google)
    #expect(AppPreferences.defaultValue.localizationFileName == "english.xml")
    #expect(AppPreferences.defaultValue.showWhitespace == false)
    #expect(AppPreferences.defaultValue.showEOL == false)
    #expect(AppPreferences.defaultValue.showIndentGuides == true)
    #expect(AppPreferences().showIndentGuides == true)
    #expect(AppPreferences.defaultValue.highlightCurrentLine == false)
    #expect(AppPreferences.defaultValue.showWrapSymbol == false)
    #expect(AppPreferences.defaultValue.showControlCharactersAndUnicodeEOL == true)
    #expect(AppPreferences().showControlCharactersAndUnicodeEOL == true)
}

@Test func storesAndLoadsAppPreferences() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = PreferencesStore(defaults: defaults)
    #expect(store.load() == .defaultValue)

    let saved = AppPreferences(
        editorFontSize: 18,
        wrapsLines: true,
        searchMatchCase: true,
        searchWholeWord: false,
        customDateTimeFormat: "yyyy-MM-dd HH:mm",
        searchEngineChoice: .stackOverflow,
        customSearchEngineURL: "https://example.com/?q=$(CURRENT_WORD)",
        localizationFileName: "chineseSimplified.xml",
        showWhitespace: true,
        showEOL: true,
        showIndentGuides: true,
        highlightCurrentLine: true,
        showWrapSymbol: true,
        showControlCharactersAndUnicodeEOL: false
    )
    store.save(saved)
    #expect(store.load() == saved)
}

@Test func preferencesStorePersistsDisabledNativePluginIdentifiers() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = PreferencesStore(defaults: defaults)
    let disabledIdentifiers: Set<String> = [
        "org.notepad-plus-plus.macnative.native-tools",
        "org.notepad-plus-plus.macnative.companion-tools"
    ]

    #expect(store.loadDisabledNativePluginIdentifiers().isEmpty)
    store.saveDisabledNativePluginIdentifiers(disabledIdentifiers)
    #expect(store.loadDisabledNativePluginIdentifiers() == disabledIdentifiers)
    store.saveDisabledNativePluginIdentifiers([])
    #expect(store.loadDisabledNativePluginIdentifiers().isEmpty)
}

@Test func appSessionDeduplicatesFilesAndKeepsActiveFileInSession() {
    let first = URL(filePath: "/tmp/one.txt")
    let second = URL(filePath: "/tmp/two.txt")
    let outside = URL(filePath: "/tmp/outside.txt")

    let session = AppSession(openFiles: [first, second, first], activeFile: outside)

    #expect(session.openFiles == [first.standardizedFileURL, second.standardizedFileURL])
    #expect(session.activeFile == first.standardizedFileURL)
}

@Test func appSessionKeepsBookmarksForOpenFilesAndSnapshots() {
    let first = URL(filePath: "/tmp/one.txt")
    let duplicateFirst = URL(filePath: "/tmp/../tmp/one.txt")
    let outside = URL(filePath: "/tmp/outside.txt")
    let snapshot = DocumentSnapshot(
        id: "draft-1",
        displayName: "new 1",
        originalFile: nil,
        backupFile: URL(filePath: "/tmp/backup/new 1@2026-06-01_120000-draft-1.bak"),
        encoding: .utf8,
        lineEnding: .lf
    )

    let session = AppSession(
        openFiles: [first],
        activeFile: first,
        snapshots: [snapshot],
        bookmarks: [
            SessionBookmarkRecord(identity: .file(duplicateFirst), bookmarks: BookmarkSet(lines: [3, 1, 3])),
            SessionBookmarkRecord(identity: .snapshot("draft-1"), bookmarks: BookmarkSet(lines: [2])),
            SessionBookmarkRecord(identity: .file(outside), bookmarks: BookmarkSet(lines: [9])),
            SessionBookmarkRecord(identity: .snapshot("missing"), bookmarks: BookmarkSet(lines: [4])),
            SessionBookmarkRecord(identity: .file(first), bookmarks: BookmarkSet())
        ]
    )

    #expect(session.bookmarks == [
        SessionBookmarkRecord(identity: .file(first), bookmarks: BookmarkSet(lines: [1, 3])),
        SessionBookmarkRecord(identity: .snapshot("draft-1"), bookmarks: BookmarkSet(lines: [2]))
    ])
    #expect(session.bookmarkSet(for: .file(first)).sortedLines == [1, 3])
    #expect(session.bookmarkSet(for: .snapshot("draft-1")).sortedLines == [2])
    #expect(session.bookmarkSet(for: .file(outside)).isEmpty)
}

@Test func storesAndLoadsAppSession() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = URL(filePath: "/tmp/one.txt")
    let second = URL(filePath: "/tmp/two.txt")
    let store = SessionStore(defaults: defaults)
    #expect(store.load() == .empty)

    let saved = AppSession(
        openFiles: [first, second],
        activeFile: second,
        bookmarks: [
            SessionBookmarkRecord(identity: .file(first), bookmarks: BookmarkSet(lines: [2, 5]))
        ]
    )
    store.save(saved)
    #expect(store.load() == saved)

    store.clear()
    #expect(store.load() == .empty)
}

@Test func appSessionKeepsActiveSnapshotSeparateFromActiveFile() {
    let savedFile = URL(filePath: "/tmp/saved.txt")
    let snapshot = DocumentSnapshot(
        id: "draft-1",
        displayName: "new 1",
        originalFile: nil,
        backupFile: URL(filePath: "/tmp/backup/new 1@2026-06-01_120000-draft-1.bak"),
        encoding: .utf8,
        lineEnding: .lf
    )

    let session = AppSession(
        openFiles: [savedFile],
        activeFile: savedFile,
        snapshots: [snapshot],
        activeSnapshotID: "draft-1"
    )

    #expect(session.openFiles == [savedFile.standardizedFileURL])
    #expect(session.snapshots == [snapshot])
    #expect(session.activeSnapshotID == "draft-1")
    #expect(session.activeFile == nil)
}

@Test func appSessionBuildsFileFallbacksForMissingSnapshotsWithBookmarks() {
    let originalFile = URL(filePath: "/tmp/saved.txt")
    let snapshot = DocumentSnapshot(
        id: "draft-1",
        displayName: "saved.txt",
        originalFile: originalFile,
        backupFile: URL(filePath: "/tmp/backup/saved@2026-06-01_120000-draft-1.bak"),
        encoding: .utf8,
        lineEnding: .lf
    )
    let untitledSnapshot = DocumentSnapshot(
        id: "draft-2",
        displayName: "new 1",
        originalFile: nil,
        backupFile: URL(filePath: "/tmp/backup/new@2026-06-01_120000-draft-2.bak"),
        encoding: .utf8,
        lineEnding: .lf
    )
    let session = AppSession(
        openFiles: [],
        activeFile: nil,
        snapshots: [snapshot, untitledSnapshot],
        activeSnapshotID: "draft-1",
        bookmarks: [
            SessionBookmarkRecord(identity: .snapshot("draft-1"), bookmarks: BookmarkSet(lines: [2, 4]))
        ],
        folds: [
            SessionFoldRecord(identity: .snapshot("draft-1"), folds: FoldState(collapsedLines: [5, 3, 5]))
        ]
    )

    #expect(session.snapshotFileFallbacks(missingSnapshotIDs: ["draft-1", "draft-2"]) == [
        SessionSnapshotFileFallback(
            snapshotID: "draft-1",
            fileURL: originalFile.standardizedFileURL,
            bookmarks: BookmarkSet(lines: [2, 4]),
            folds: FoldState(collapsedLines: [3, 5])
        )
    ])
    #expect(session.snapshotFileFallbacks(missingSnapshotIDs: ["draft-2"]).isEmpty)
}

@Test func editorTabStateDeduplicatesDocumentsAndNormalizesActiveTab() {
    let first = URL(filePath: "/tmp/one.txt")
    let second = URL(filePath: "/tmp/two.txt")
    let duplicateFirst = URL(filePath: "/tmp/../tmp/one.txt")

    let state = EditorTabState(
        items: [
            EditorTabItem(identity: .file(first), title: "one.txt"),
            EditorTabItem(identity: .snapshot("draft-1"), title: "Unsaved"),
            EditorTabItem(identity: .file(second), title: "two.txt"),
            EditorTabItem(identity: .file(duplicateFirst), title: "one duplicate")
        ],
        activeIdentity: .file(URL(filePath: "/tmp/missing.txt"))
    )

    #expect(state.items.map(\.title) == ["one.txt", "Unsaved", "two.txt"])
    #expect(state.activeIdentity == .file(first.standardizedFileURL))
}

@Test func editorTabStatePreservesTabMetadataWhileNormalizing() throws {
    let file = URL(filePath: "/tmp/../tmp/one.txt")
    let item = EditorTabItem(
        identity: .file(file),
        title: "one.txt",
        isDirty: true,
        isPinned: true,
        tabColorIndex: 3,
        isMonitoring: true
    )

    let state = EditorTabState(items: [item], activeIdentity: item.identity)
    let normalized = try #require(state.items.first)
    let added = try #require(EditorTabState().adding(item).items.first)

    #expect(normalized.identity == .file(file.standardizedFileURL))
    #expect(normalized.isDirty)
    #expect(normalized.isPinned)
    #expect(normalized.tabColorIndex == 3)
    #expect(normalized.isMonitoring)
    #expect(added.isDirty)
    #expect(added.isPinned)
    #expect(added.tabColorIndex == 3)
    #expect(added.isMonitoring)
}

@Test func editorTabStateSelectsNeighborWhenRemovingActiveTab() {
    let first = EditorTabItem(identity: .file(URL(filePath: "/tmp/one.txt")), title: "one.txt")
    let second = EditorTabItem(identity: .snapshot("draft-1"), title: "Unsaved")
    let third = EditorTabItem(identity: .file(URL(filePath: "/tmp/two.txt")), title: "two.txt")

    let state = EditorTabState(items: [first, second, third], activeIdentity: second.identity)
    let afterRemovingMiddle = state.removing(second.identity)
    let afterRemovingFirst = afterRemovingMiddle.removing(first.identity)
    let afterRemovingLast = afterRemovingFirst.removing(third.identity)

    #expect(afterRemovingMiddle.items == [first, third])
    #expect(afterRemovingMiddle.activeIdentity == third.identity)
    #expect(afterRemovingFirst.items == [third])
    #expect(afterRemovingFirst.activeIdentity == third.identity)
    #expect(afterRemovingLast.items.isEmpty)
    #expect(afterRemovingLast.activeIdentity == nil)
}

@Test func snapshotStoreWritesLoadsAndPrunesDrafts() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = SnapshotStore(directory: directory, now: { Date(timeIntervalSince1970: 1_801_310_400) })
    let draft = DocumentSnapshotDraft(
        id: "draft-1",
        displayName: "new 1",
        originalFile: nil,
        text: "unsaved\nbuffer",
        encoding: .utf8,
        lineEnding: .lf,
        preservesByteOrderMark: true
    )

    let snapshot = try store.save(draft)

    #expect(snapshot.id == "draft-1")
    #expect(snapshot.displayName == "new 1")
    #expect(snapshot.originalFile == nil)
    #expect(snapshot.backupFile.deletingLastPathComponent().path == directory.standardizedFileURL.path)
    #expect(snapshot.preservesByteOrderMark)
    #expect(FileManager.default.fileExists(atPath: snapshot.backupFile.path))
    #expect(try store.loadText(for: snapshot) == "unsaved\nbuffer")

    try store.prune(keeping: [])
    #expect(!FileManager.default.fileExists(atPath: snapshot.backupFile.path))
}

@Test func dirtySnapshotRestorePreservesLoadedUtf8ByteOrderMarkIntent() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-bom.txt")
    try (Data([0xEF, 0xBB, 0xBF]) + Data("original\n".utf8)).write(to: fileURL)

    let loaded = try TextFileCodec.read(fileURL)
    let loadedSavePolicy = TextFileSavePolicy.loaded(loaded)
    let store = SnapshotStore(directory: directory.appending(path: "backup"))
    let snapshot = try store.save(
        DocumentSnapshotDraft(
            id: "draft-bom",
            displayName: fileURL.lastPathComponent,
            originalFile: fileURL,
            text: "dirty\n",
            encoding: loaded.encoding,
            lineEnding: loaded.lineEnding,
            preservesByteOrderMark: loadedSavePolicy.includeByteOrderMark(for: loaded.encoding)
        )
    )

    let restoredText = try store.loadText(for: snapshot)
    let restoredSavePolicy = TextFileSavePolicy(preservesByteOrderMark: snapshot.preservesByteOrderMark)
        .converted(to: snapshot.encoding)
    try TextFileCodec.write(
        restoredText,
        to: fileURL,
        encoding: snapshot.encoding,
        lineEnding: snapshot.lineEnding,
        includeByteOrderMark: restoredSavePolicy.includeByteOrderMark(for: snapshot.encoding)
    )

    let savedBytes = try Data(contentsOf: fileURL)
    #expect(savedBytes.starts(with: [0xEF, 0xBB, 0xBF]))
    #expect(try TextFileCodec.read(fileURL).text == "dirty\n")
}

@Test func loadsNotepadPlusWorkspaceXmlWithRelativeFilePaths() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory.appending(path: "src"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let workspaceURL = directory.appending(path: "sample.npproj")
    try """
    <NotepadPlus>
        <Project name="Sample">
            <Folder name="Sources">
                <File name="src/main.swift" />
            </Folder>
            <File name="/tmp/outside.txt" />
        </Project>
    </NotepadPlus>
    """.write(to: workspaceURL, atomically: true, encoding: .utf8)

    let workspace = try WorkspaceDocument.load(from: workspaceURL)

    #expect(workspace.name == "sample.npproj")
    #expect(workspace.projects.count == 1)
    #expect(workspace.projects[0].name == "Sample")
    #expect(workspace.projects[0].children[0].kind == .folder)
    #expect(workspace.projects[0].children[0].children[0].url == directory.appending(path: "src/main.swift").standardizedFileURL)
    #expect(workspace.projects[0].children[1].url == URL(filePath: "/tmp/outside.txt").standardizedFileURL)
}

@Test func writesNotepadPlusWorkspaceXmlUsingRelativePaths() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory.appending(path: "Sources"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let workspaceURL = directory.appending(path: "sample.npproj")
    let workspace = WorkspaceDocument(
        name: "sample.npproj",
        projects: [
            WorkspaceNode(
                name: "Sample",
                kind: .project,
                children: [
                    WorkspaceNode(
                        name: "Sources",
                        kind: .folder,
                        children: [
                            WorkspaceNode.file(url: directory.appending(path: "Sources/main.swift"))
                        ]
                    )
                ]
            )
        ]
    )

    try workspace.write(to: workspaceURL)
    let xml = try String(contentsOf: workspaceURL, encoding: .utf8)

    #expect(xml.contains("<Project name=\"Sample\">"))
    #expect(xml.contains("<Folder name=\"Sources\">"))
    #expect(xml.contains("<File name=\"Sources/main.swift\""))
}

@Test func buildsWorkspaceDocumentFromDirectoryTree() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory.appending(path: "Sources"), withIntermediateDirectories: true)
    try "print(1)".write(to: directory.appending(path: "Sources/main.swift"), atomically: true, encoding: .utf8)
    try "notes".write(to: directory.appending(path: "README.md"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: directory) }

    let workspace = try WorkspaceDocument.folderWorkspace(from: directory)

    #expect(workspace.projects.count == 1)
    #expect(workspace.projects[0].name == directory.lastPathComponent)
    #expect(workspace.projects[0].children.map(\.name) == ["Sources", "README.md"])
    #expect(workspace.projects[0].children[0].children[0].url == directory.appending(path: "Sources/main.swift").standardizedFileURL)
}

@Test func storesAndLoadsWorkspaceDocument() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = WorkspaceStore(defaults: defaults)
    let workspace = WorkspaceDocument(
        name: "Workspace",
        projects: [
            WorkspaceNode(
                name: "Project",
                kind: .project,
                children: [WorkspaceNode.file(url: URL(filePath: "/tmp/main.swift"))]
            )
        ]
    )

    #expect(store.load() == nil)
    store.save(workspace)
    #expect(store.load() == workspace)
    store.clear()
    #expect(store.load() == nil)
}

private func upstreamLanguageModelURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/src/langs.model.xml")
}

private func upstreamStyleModelURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/src/stylers.model.xml")
}

private func upstreamApiURL(_ fileName: String) -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/installer/APIs/\(fileName)")
}

private func upstreamFunctionListURL(_ fileName: String) -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/installer/functionList/\(fileName)")
}

private func upstreamThemesDirectoryURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "upstream/notepad-plus-plus/PowerEditor/installer/themes")
}

// MARK: - Search Extension Tests

@Test func findAllReturnsAllMatchRanges() {
    let text = "abc abc xyz abc"
    let options = TextSearch.Options(matchCase: true, wholeWord: false, wraps: false, direction: .down)
    let matches = TextSearch.findAll("abc", in: text, options: options)
    #expect(matches.count == 3)
    #expect(matches[0] == NSRange(location: 0, length: 3))
    #expect(matches[1] == NSRange(location: 4, length: 3))
    #expect(matches[2] == NSRange(location: 12, length: 3))
}

@Test func findAllRespectsCaseAndWholeWord() {
    let text = "Abc abc AbcABC"
    let caseSensitive = TextSearch.Options(matchCase: true, wholeWord: false, wraps: false, direction: .down)
    let insensitive = TextSearch.Options(matchCase: false, wholeWord: false, wraps: false, direction: .down)
    let wholeWord = TextSearch.Options(matchCase: false, wholeWord: true, wraps: false, direction: .down)

    #expect(TextSearch.findAll("abc", in: text, options: caseSensitive).count == 1)
    #expect(TextSearch.findAll("abc", in: text, options: insensitive).count == 4)
    #expect(TextSearch.findAll("abc", in: text, options: wholeWord).count == 2)
}

@Test func findNextSelectsSelectionTextAsQuery() {
    // Simulates "Select and Find Next": use selected text as query
    let text = "hello world hello world"
    let selection = NSRange(location: 0, length: 5) // "hello"
    let query = (text as NSString).substring(with: selection)
    #expect(query == "hello")

    let options = TextSearch.Options(matchCase: true, wholeWord: false, wraps: true, direction: .down)
    let fromRange = NSRange(location: NSMaxRange(selection), length: 0)
    let nextMatch = TextSearch.findNext(query, in: text, from: fromRange, options: options)
    #expect(nextMatch == NSRange(location: 12, length: 5))
}

@Test func findCharactersInRangeFindsUnicodeScalar() {
    let text = "Hello \u{03B1} World \u{03B2} End" // α and β
    let scalars = text.unicodeScalars

    // Find Greek letters (U+0370–U+03FF)
    var found = false
    var searchIndex = scalars.startIndex
    while searchIndex < scalars.endIndex {
        let value = scalars[searchIndex].value
        if value >= 0x0370 && value <= 0x03FF {
            found = true
            break
        }
        searchIndex = scalars.index(after: searchIndex)
    }
    #expect(found)
    #expect(scalars[searchIndex] == "\u{03B1}") // α
}

@Test func searchMarkStyleEnumCoversAllFiveStyles() {
    let styles = SearchMarkStyle.allCases
    #expect(styles.count == 5)
    #expect(styles[0].rawValue == 1)
    #expect(styles[4].rawValue == 5)
    for (index, style) in styles.enumerated() {
        #expect(style.displayName == "Style \(index + 1)")
    }
}

@Test func searchMarkStyleDefaultColorsAreDistinct() {
    let colors = SearchMarkStyle.allCases.map(\.defaultColor)
    let uniqueCount = Set(colors.map { "\($0.red),\($0.green),\($0.blue)" }).count
    #expect(uniqueCount == 5)
}

@Test func textSearchWithInSelectionConstraint() {
    let text = "hello world\nhello there\ngoodbye world"
    let constraint = NSRange(location: 0, length: 11) // "hello world"
    var options = TextSearch.Options()
    options.searchRange = constraint
    let result = TextSearch.findNext("hello", in: text, from: NSRange(location: 0, length: 0), options: options)
    #expect(result == NSRange(location: 0, length: 5))
    // Should NOT find "hello" in second line when constrained
    // With default wraps:true the search wraps; the match should still be inside the constraint
    let result2 = TextSearch.findNext("hello", in: text, from: NSRange(location: 5, length: 0), options: options)
    if let r = result2 {
        #expect(r.location >= 0 && NSMaxRange(r) <= 11) // stays within constraint
    }
    // With wraps:false, no match should be found after passing "hello" in the constraint
    var noWrapOptions = TextSearch.Options(wraps: false)
    noWrapOptions.searchRange = constraint
    let result3 = TextSearch.findNext("hello", in: text, from: NSRange(location: 5, length: 0), options: noWrapOptions)
    #expect(result3 == nil)
}

@Test func textSearchInSelectionWrapsWithinConstraint() {
    let text = "aa bb aa cc aa"
    let constraint = NSRange(location: 0, length: 8) // "aa bb aa"
    var options = TextSearch.Options(wraps: true)
    options.searchRange = constraint
    // Start after second "aa" - should wrap back to first
    let from = NSRange(location: 6, length: 2)
    let result = TextSearch.findNext("aa", in: text, from: from, options: options)
    #expect(result == NSRange(location: 0, length: 2))
}

@Test func appPreferencesCopyPreservesAllFields() {
    let original = AppPreferences.defaultValue
    let modified = original.withSearchOptions(TextSearch.Options(matchCase: true, wholeWord: true))
    // All non-search fields should be preserved
    #expect(modified.editorFontSize == original.editorFontSize)
    #expect(modified.wrapsLines == original.wrapsLines)
    #expect(modified.tabSize == original.tabSize)
    #expect(modified.largeFileSizeMB == original.largeFileSizeMB)
    #expect(modified.postItAlpha == original.postItAlpha)
    #expect(modified.newDocumentOnLaunch == original.newDocumentOnLaunch)
    // New fields from P9/P10 should be preserved by copy
    #expect(modified.autoCompleteMode == original.autoCompleteMode)
    #expect(modified.autoCompleteChooseSingle == original.autoCompleteChooseSingle)
    #expect(modified.inSelectionThreshold == original.inSelectionThreshold)
    #expect(modified.keepFindDialogOpen == original.keepFindDialogOpen)
    #expect(modified.findDialogTransparency == original.findDialogTransparency)
    #expect(modified.statusBarVisible == original.statusBarVisible)
    #expect(modified.shortTitle == original.shortTitle)
    #expect(modified.saveAllConfirm == original.saveAllConfirm)
    #expect(modified.autoCompleteIgnoreNumbers == original.autoCompleteIgnoreNumbers)
    #expect(modified.delimiterLeft == original.delimiterLeft)
    #expect(modified.delimiterRight == original.delimiterRight)
    #expect(modified.tabbarDoubleClickClose == original.tabbarDoubleClickClose)
    #expect(modified.tabbarMaxLabelLength == original.tabbarMaxLabelLength)
    #expect(modified.tabbarLockDragDrop == original.tabbarLockDragDrop)
    #expect(modified.tabbarExitOnLastTab == original.tabbarExitOnLastTab)
    #expect(modified.fileChangeDetectionEnabled == original.fileChangeDetectionEnabled)
    #expect(modified.urlIndicatorStyle == original.urlIndicatorStyle)
    // Only search fields should change
    #expect(modified.searchMatchCase == true)
    #expect(modified.searchWholeWord == true)
}

@Test func appPreferencesDefaults() {
    let prefs = AppPreferences.defaultValue
    #expect(prefs.statusBarVisible == true)
    #expect(prefs.shortTitle == false)
    #expect(prefs.saveAllConfirm == false)
    #expect(prefs.autoCompleteIgnoreNumbers == true)
    #expect(prefs.findDialogTransparency == 0)
    #expect(prefs.keepFindDialogOpen == true)
    #expect(prefs.inSelectionThreshold == 1024)
    #expect(prefs.autoCompleteMode == 3)
    #expect(prefs.tabbarDoubleClickClose == false)
    #expect(prefs.tabbarMaxLabelLength == 0)
    #expect(prefs.tabbarLockDragDrop == false)
    #expect(prefs.tabbarExitOnLastTab == false)
    #expect(prefs.fileChangeDetectionEnabled == true)
    #expect(prefs.copyLineWithoutSelection == true)
    #expect(prefs.urlIndicatorStyle == 0)
    #expect(prefs.printSettings.header.center == "$(FILE_NAME)")
    #expect(prefs.printSettings.footer.right == "$(PAGE) / $(PAGES)")
}

@Test func appPreferencesWithTabSizePreservesOtherFields() {
    let original = AppPreferences.defaultValue
    let modified = original.withTabSize(2)
    #expect(modified.tabSize == 2)
    #expect(modified.editorFontSize == original.editorFontSize)
    #expect(modified.searchMatchCase == original.searchMatchCase)
    #expect(modified.largeFileSizeMB == original.largeFileSizeMB)
    #expect(modified.postItAlpha == original.postItAlpha)
}

@Test func sessionCaretRecordIdentityNormalization() {
    let url = URL(fileURLWithPath: "/tmp/test.txt")
    let record = SessionCaretRecord(identity: .file(url), caretLocation: 42)
    #expect(record.caretLocation == 42)
    #expect(record.identity == EditorTabIdentity.file(url).normalized)
}

@Test func sessionTabStateRecordPreservesValues() {
    let url = URL(fileURLWithPath: "/tmp/test.txt")
    let record = SessionTabStateRecord(identity: .file(url), isPinned: true, tabColorIndex: 3)
    #expect(record.isPinned == true)
    #expect(record.tabColorIndex == 3)
}

// MARK: - Regex backward search (P1 regression tests)

@Test func regexBackwardFindsLastMatchBeforeCaret() {
    let text = "foo bar foo baz foo"
    // Caret at position 15 (after third "foo"), search backward
    let from = NSRange(location: 15, length: 0)
    let opts = TextSearch.Options(wraps: false, direction: .up, searchMode: .regex)
    let result = TextSearch.findNext("foo", in: text, from: from, options: opts)
    // Should find the second "foo" at position 8
    #expect(result == NSRange(location: 8, length: 3))
}

@Test func regexBackwardWrapsToEndWhenNoPriorMatch() {
    let text = "abc foo def"
    // Caret before "foo"
    let from = NSRange(location: 0, length: 0)
    let opts = TextSearch.Options(wraps: true, direction: .up, searchMode: .regex)
    let result = TextSearch.findNext("foo", in: text, from: from, options: opts)
    // Should wrap and find "foo" at position 4
    #expect(result == NSRange(location: 4, length: 3))
}

@Test func regexBackwardWithDatePattern() {
    let text = "2026-01-01 and 2026-06-04"
    let from = NSRange(location: text.utf16.count, length: 0)
    let opts = TextSearch.Options(wraps: false, direction: .up, searchMode: .regex)
    // Find dates backward - should find the last one first
    let result = TextSearch.findNext("\\d{4}-\\d{2}-\\d{2}", in: text, from: from, options: opts)
    #expect(result == NSRange(location: 15, length: 10))
}

@Test func regexBackwardNoMatchWithoutWrap() {
    let text = "foo bar baz"
    let from = NSRange(location: 0, length: 0)
    let opts = TextSearch.Options(wraps: false, direction: .up, searchMode: .regex)
    let result = TextSearch.findNext("foo", in: text, from: from, options: opts)
    #expect(result == nil)
}

@Test func regexBackwardCaseInsensitive() {
    let text = "Foo BAR foo bar FOO"
    let from = NSRange(location: 15, length: 0)
    let opts = TextSearch.Options(matchCase: false, wraps: false, direction: .up, searchMode: .regex)
    let result = TextSearch.findNext("foo", in: text, from: from, options: opts)
    // Should find "foo" at position 8
    #expect(result == NSRange(location: 8, length: 3))
}
