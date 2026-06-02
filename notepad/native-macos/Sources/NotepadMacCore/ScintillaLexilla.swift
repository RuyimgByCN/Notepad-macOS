public extension LanguageDefinition {
    var lexillaLexerName: String? {
        NotepadPlusLexillaMapping.lexerName(for: name)
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
        "makefile": "makefile",
        "objc": "objc",
        "objective-c": "objc",
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
        "fortran",
        "json",
        "lua",
        "markdown",
        "perl",
        "python",
        "ruby",
        "rust",
        "sql",
        "toml",
        "vb",
        "yaml",
        "zig"
    ]
}
