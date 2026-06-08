public extension LanguageDefinition {
    var lexillaLexerName: String? {
        // User-defined languages (UDL) detected by their keyword group naming convention.
        // EditorSurface also uses isUserDefinedLanguage (private) for the same check.
        if keywordGroups.keys.contains(where: { $0.hasPrefix("udlkw") || $0.hasPrefix("udl_") }) {
            return "user"
        }
        return NotepadPlusLexillaMapping.lexerName(for: name)
    }
}

public enum NotepadPlusLexillaMapping {
    public static func lexerName(for notepadLanguageName: String) -> String? {
        let normalizedName = notepadLanguageName.lowercased()
        if let alias = aliases[normalizedName] {
            return alias
        }
        if directNames.contains(normalizedName) {
            return normalizedName
        }
        return nil
    }

    private static let aliases: [String: String] = [
        "html": "hypertext",
        "ini": "props",
        "makefile": "makefile",
        "php": "phpscript",
        "xml": "xml"
    ]

    /// Lexer names verified present in this Lexilla build (see _lm* symbols).
    /// Names NOT in this set or aliases will return nil → no lexer → SyntaxHighlighter fallback.
    private static let directNames: Set<String> = [
        "ada",
        "asm",
        "bash",
        "batch",
        "cmake",
        "coffeescript",
        "cpp",
        "css",
        "dart",
        "diff",
        "fortran",
        "json",
        "lua",
        "markdown",
        "perl",
        "powershell",
        "python",
        "r",
        "ruby",
        "rust",
        "sql",
        "tcl",
        "toml",
        "vb",
        "yaml",
        "zig"
    ]
}
