public extension LanguageDefinition {
    var lexillaLexerName: String? {
        // User-defined languages (UDL) detected by their keyword group naming convention.
        if keywordGroups.keys.contains(where: { $0.hasPrefix("udlkw") || $0.hasPrefix("udl_") }) {
            return "user"
        }
        return NotepadPlusLexillaMapping.lexerName(for: name)
    }

    /// Returns (scintillaKeywordSetIndex, keywords) pairs in ascending index order.
    /// UDL keyword sets map to SCE_USER_KWLIST_* slots; standard languages keep
    /// Notepad++ keyword class priority unless a Lexilla lexer needs a fixed slot.
    var scintillaKeywordSets: [(index: Int, keywords: [String])] {
        if isUserDefinedLanguage {
            return keywordGroups
                .compactMap { name, words -> (Int, [String])? in
                    guard let idx = udlKeywordSetIndex(name), !words.isEmpty else { return nil }
                    return (idx, words)
                }
                .sorted { $0.index < $1.index }
        }

        if name.lowercased() == "xml" {
            return keywordGroups
                .compactMap { name, words -> (Int, [String])? in
                    guard !words.isEmpty, let idx = xmlKeywordSetIndex(name) else { return nil }
                    return (idx, words)
                }
                .sorted { $0.index < $1.index }
        }

        return keywordGroups
            .sorted { keywordGroupPriority($0.key) < keywordGroupPriority($1.key) }
            .filter { !$1.isEmpty }
            .enumerated()
            .map { (index: $0.offset, keywords: $0.element.value) }
    }

    var lexillaProperties: [(name: String, value: String)] {
        switch name.lowercased() {
        case "xml":
            return [("lexer.xml.allow.scripts", "0")]
        default:
            return []
        }
    }

    private var isUserDefinedLanguage: Bool {
        keywordGroups.keys.contains { $0.hasPrefix("udlkw") || $0.hasPrefix("udl_") }
    }

    private func xmlKeywordSetIndex(_ name: String) -> Int? {
        // Lexilla's XML lexer reads SGML/DTD words from keyword set 5.
        name == "instre1" ? 5 : nil
    }

    private func udlKeywordSetIndex(_ name: String) -> Int? {
        switch name {
        case "udl_comments":            return 0
        case "udl_num_prefix1":         return 1
        case "udl_num_prefix2":         return 2
        case "udl_num_extras1":         return 3
        case "udl_num_extras2":         return 4
        case "udl_num_suffix1":         return 5
        case "udl_num_suffix2":         return 6
        case "udl_num_range":           return 7
        case "udl_operators1":          return 8
        case "udl_operators2":          return 9
        case "udl_fold_code1_open":     return 10
        case "udl_fold_code1_middle":   return 11
        case "udl_fold_code1_close":    return 12
        case "udl_fold_code2_open":     return 13
        case "udl_fold_code2_middle":   return 14
        case "udl_fold_code2_close":    return 15
        case "udl_fold_comment_open":   return 16
        case "udl_fold_comment_middle": return 17
        case "udl_fold_comment_close":  return 18
        case "udl_delimiters":          return 27
        default: break
        }
        if name.hasPrefix("udlkw"), let n = Int(name.dropFirst(5)), (1...8).contains(n) {
            return 18 + n  // udlkw1 -> 19 (SCE_USER_KWLIST_KEYWORDS1), ..., udlkw8 -> 26
        }
        return nil
    }

    private func keywordGroupPriority(_ name: String) -> Int {
        if name == "instre1" { return 0 }
        if name == "instre2" { return 1 }
        if name.hasPrefix("type"), let number = Int(name.dropFirst("type".count)) {
            return 1 + number
        }
        if name.hasPrefix("substyle"), let number = Int(name.dropFirst("substyle".count)) {
            return 20 + number
        }
        return 100
    }
}

public enum ScintillaKeywordSet {
    public static let maximumSets = 30
}

public enum NotepadPlusLexillaMapping {
    public static func lexerName(for notepadLanguageName: String) -> String? {
        lexerNames[notepadLanguageName.lowercased()]
    }

    /// Notepad++ language name (langs.model.xml, lowercased) → Lexilla lexer
    /// name. Mirrors upstream `ScintillaEditView::_langNameInfoArray`
    /// (_langName → _lexerID); every lexer name below was verified present in
    /// the bundled Lexilla build's lexer catalogue. Languages absent from this
    /// table fall back to the native SyntaxHighlighter. Upstream "null"-lexer
    /// entries (normal, nfo) and internal views (searchresult, errorlist) are
    /// intentionally unmapped; user-defined languages are resolved to "user"
    /// before this table is consulted.
    private static let lexerNames: [String: String] = [
        // C-family languages share the cpp lexer, as upstream does.
        "c": "cpp",
        "cpp": "cpp",
        "cs": "cpp",
        "java": "cpp",
        "rc": "cpp",
        "javascript": "cpp",
        "javascript.js": "cpp",
        "typescript": "cpp",
        "actionscript": "cpp",
        "swift": "cpp",
        "go": "cpp",
        // Web / markup
        "php": "phpscript",
        "html": "hypertext",
        "asp": "hypertext",
        "jsp": "hypertext",
        "xml": "xml",
        "css": "css",
        // Scripting
        "bash": "bash",
        "batch": "batch",
        "perl": "perl",
        "python": "python",
        "lua": "lua",
        "ruby": "ruby",
        "tcl": "tcl",
        "powershell": "powershell",
        "coffeescript": "coffeescript",
        "autoit": "au3",
        "kix": "kix",
        "gui4cli": "gui4cli",
        "escript": "escript",
        "oscript": "oscript",
        "gdscript": "gdscript",
        "hollywood": "hollywood",
        "raku": "raku",
        "avs": "avs",
        "csound": "csound",
        "nncrontab": "nncrontab",
        // Data / config
        "ini": "props",
        "props": "props",
        "json": "json",
        "json5": "json",
        "yaml": "yaml",
        "toml": "toml",
        "registry": "registry",
        "makefile": "makefile",
        "cmake": "cmake",
        "nsis": "nsis",
        "inno": "inno",
        "diff": "diff",
        // Compiled languages
        "objc": "objc",
        "d": "d",
        "rust": "rust",
        "pascal": "pascal",
        "ada": "ada",
        "fortran": "fortran",
        "fortran77": "f77",
        "cobol": "COBOL",
        "haskell": "haskell",
        "caml": "caml",
        "erlang": "erlang",
        "forth": "forth",
        "lisp": "lisp",
        "scheme": "lisp",
        "smalltalk": "smalltalk",
        "nim": "nimrod",
        "visualprolog": "visualprolog",
        "baanc": "baan",
        "sas": "sas",
        "spice": "spice",
        // Basic dialects
        "vb": "vb",
        "blitzbasic": "blitzbasic",
        "purebasic": "purebasic",
        "freebasic": "freebasic",
        // SQL
        "sql": "sql",
        "mssql": "mssql",
        // Hardware description
        "vhdl": "vhdl",
        "verilog": "verilog",
        // Assembly / low level
        "asm": "asm",
        "mmixal": "mmixal",
        "srec": "srec",
        "ihex": "ihex",
        "tehex": "tehex",
        "asn1": "asn1",
        // Typesetting / documents
        "tex": "tex",
        "latex": "latex",
        "postscript": "ps",
        "txt2tags": "txt2tags",
        // Statistics / math
        "matlab": "matlab",
        "r": "r",
        // Extras supported by the bundled Lexilla but absent upstream
        "dart": "dart",
        "markdown": "markdown",
        "zig": "zig",
        "rebol": "rebol"
    ]
}
