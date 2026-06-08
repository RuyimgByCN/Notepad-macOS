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
        "objc": "objc",
        "objective-c": "objc",
        "php": "hypertext",
        "powershell": "powershell",
        "xml": "xml"
    ]

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
        "dockerfile",
        "fortran",
        "go",
        "groovy",
        "javascript",
        "json",
        "lua",
        "markdown",
        "perl",
        "python",
        "r",
        "ruby",
        "rust",
        "scala",
        "sql",
        "swift",
        "tcl",
        "toml",
        "vb",
        "yaml",
        "zig"
    ]
}
