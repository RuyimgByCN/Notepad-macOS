import Foundation

public struct LanguageWordStyle: Equatable, Sendable {
    public let name: String
    public let foreground: StyleColor?

    public init(name: String, foreground: StyleColor? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.foreground = foreground
    }

    public init?(name: String, foregroundHexRGB: String?) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return nil }

        self.name = normalizedName
        self.foreground = StyleColor(hexRGB: foregroundHexRGB?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    fileprivate var normalizedNameKey: String {
        Self.normalizedNameKey(name)
    }

    fileprivate static func normalizedNameKey(_ name: String) -> String {
        name
            .filter { !$0.isWhitespace }
            .uppercased()
    }
}

public struct LanguageDefinition: Equatable, Identifiable, Sendable {
    public let name: String
    public let displayName: String
    public let extensions: [String]
    public let lineComment: String?
    public let blockCommentStart: String?
    public let blockCommentEnd: String?
    public let keywordGroups: [String: [String]]
    public let wordStyles: [LanguageWordStyle]
    /// UDL only: maps Scintilla style ID → nesting bitmask (sent via SCI_SETPROPERTY "userDefine.nesting.XX").
    public let nestingProperties: [Int: Int]

    public var id: String { name }

    public var allKeywords: [String] {
        Array(Set(keywordGroups.values.flatMap { $0 })).sorted()
    }

    public init(
        name: String,
        displayName: String? = nil,
        extensions: [String] = [],
        lineComment: String? = nil,
        blockCommentStart: String? = nil,
        blockCommentEnd: String? = nil,
        keywordGroups: [String: [String]] = [:],
        wordStyles: [LanguageWordStyle] = [],
        nestingProperties: [Int: Int] = [:]
    ) {
        self.name = name
        self.displayName = displayName ?? LanguageDefinition.defaultDisplayName(for: name)
        self.extensions = extensions
        self.lineComment = lineComment?.nilIfEmpty
        self.blockCommentStart = blockCommentStart?.nilIfEmpty
        self.blockCommentEnd = blockCommentEnd?.nilIfEmpty
        self.keywordGroups = keywordGroups
        self.wordStyles = wordStyles
        self.nestingProperties = nestingProperties
    }

    public static let plainText = LanguageDefinition(name: "normal", displayName: "Plain Text", extensions: ["txt"])

    public var userDefinedKeywordForeground: StyleColor? {
        foreground(forWordStyleNamed: "KEYWORDS1") ?? foreground(forWordStyleNamed: "KEYWORDS")
    }

    public func wordStyle(named name: String) -> LanguageWordStyle? {
        let nameKey = LanguageWordStyle.normalizedNameKey(name)
        return wordStyles.first { $0.normalizedNameKey == nameKey }
    }

    private static func defaultDisplayName(for name: String) -> String {
        switch name {
        case "normal":
            "Plain Text"
        case "cpp":
            "C++"
        case "cs":
            "C#"
        case "html":
            "HTML"
        case "json":
            "JSON"
        case "xml":
            "XML"
        case "escseq":
            "Escape Sequence"
        case "errorlist":
            "Error List"
        case "asn1":
            "ASN.1"
        case "avs":
            "AviSynth"
        case "baanc":
            "BaanC"
        case "blitzbasic":
            "BlitzBasic"
        case "coffeescript":
            "CoffeeScript"
        case "csound":
            "CSound"
        case "freebasic":
            "FreeBasic"
        case "gdscript":
            "GDScript"
        case "gui4cli":
            "Gui4Cli"
        case "ihex":
            "Intel HEX"
        case "javascript.js":
            "JavaScript"
        case "mmixal":
            "MMIXAL"
        case "mssql":
            "MS-SQL"
        case "nfo":
            "NFO"
        case "nim":
            "Nim"
        case "nncrontab":
            "NNCronTab"
        case "nsis":
            "NSIS"
        case "objc":
            "Objective-C"
        case "oscript":
            "OScript"
        case "postscript":
            "PostScript"
        case "powershell":
            "PowerShell"
        case "purebasic":
            "PureBasic"
        case "r":
            "R"
        case "rc":
            "Resource File"
        case "rebol":
            "REBOL"
        case "sas":
            "SAS"
        case "searchResult":
            "Search Result"
        case "smalltalk":
            "Smalltalk"
        case "spice":
            "SPICE"
        case "sql":
            "SQL"
        case "srec":
            "Motorola S-Record"
        case "tcl":
            "TCL"
        case "tehex":
            "TE HEX"
        case "tex":
            "TeX"
        case "txt2tags":
            "Txt2tags"
        case "typescript":
            "TypeScript"
        case "vb":
            "Visual Basic"
        case "verilog":
            "Verilog"
        case "vhdl":
            "VHDL"
        case "visualprolog":
            "Visual Prolog"
        case "yaml":
            "YAML"
        default:
            name
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    private func foreground(forWordStyleNamed name: String) -> StyleColor? {
        let nameKey = LanguageWordStyle.normalizedNameKey(name)
        return wordStyles.first { $0.normalizedNameKey == nameKey && $0.foreground != nil }?.foreground
    }
}

public struct LanguageCatalog: Sendable {
    public let languages: [LanguageDefinition]

    private let byName: [String: LanguageDefinition]
    private let byExtension: [String: LanguageDefinition]

    public var defaultLanguage: LanguageDefinition {
        language(named: "normal") ?? .plainText
    }

    public init(languages: [LanguageDefinition]) {
        let normalized = Self.deduplicatedByName(languages.isEmpty ? [.plainText] : languages)
        self.languages = normalized

        var nameIndex: [String: LanguageDefinition] = [:]
        for language in normalized {
            nameIndex[Self.normalizedNameKey(language.name)] = language
        }
        self.byName = nameIndex

        var extensionIndex: [String: LanguageDefinition] = [:]
        for language in normalized {
            for ext in language.extensions {
                guard let normalizedExtension = UserDefinedLanguage.normalizedExtension(ext) else { continue }
                extensionIndex[normalizedExtension] = language
            }
        }
        self.byExtension = extensionIndex
    }

    public func language(named name: String) -> LanguageDefinition? {
        byName[Self.normalizedNameKey(name)]
    }

    public func language(for fileExtension: String) -> LanguageDefinition? {
        guard let normalizedExtension = UserDefinedLanguage.normalizedExtension(fileExtension) else {
            return nil
        }
        return byExtension[normalizedExtension]
    }

    public func detect(url: URL?) -> LanguageDefinition {
        // 1. Try filename-based detection first for special files (Makefile, Dockerfile, CMakeLists.txt, etc.)
        //    This takes priority over generic extensions like .txt
        if let filename = url?.lastPathComponent, !filename.isEmpty {
            if let match = detectByFilename(filename) {
                return match
            }
        }
        // 2. Try extension-based detection
        if let ext = url?.pathExtension, !ext.isEmpty,
           let match = language(for: ext) {
            return match
        }
        return defaultLanguage
    }

    /// Detect language by filename (without extension) for special files like Makefile, Dockerfile, etc.
    private func detectByFilename(_ filename: String) -> LanguageDefinition? {
        let lower = filename.lowercased()
        let filenameMap: [String: String] = [
            "makefile": "makefile",
            "gnumakefile": "makefile",
            "makefile.in": "makefile",
            "makefile.am": "makefile",
            "cmakelists.txt": "cmake",
            "dockerfile": "dockerfile",
            "dockerfile.dev": "dockerfile",
            "dockerfile.prod": "dockerfile",
            "dockerfile.test": "dockerfile",
            "dockerfile.*": "dockerfile",
            "gemfile": "ruby",
            "rakefile": "ruby",
            "vagrantfile": "ruby",
            "brewfile": "ruby",
            "podfile": "ruby",
            "guardfile": "ruby",
            "capfile": "ruby",
            "jenkinsfile": "groovy",
            ".gitignore": "bash",
            ".dockerignore": "bash",
            ".npmignore": "bash",
            ".editorconfig": "ini",
            ".env": "bash",
            ".env.local": "bash",
            ".env.production": "bash",
            ".babelrc": "json",
            ".eslintrc": "json",
            ".prettierrc": "json",
            ".tsconfig": "json",
            "tsconfig.json": "json",
            "package.json": "json",
            "composer.json": "json",
            "cargo.toml": "toml",
            "pyproject.toml": "toml",
            "go.mod": "go",
            "go.sum": "go",
        ]
        // Exact match first
        if let langName = filenameMap[lower], let lang = language(named: langName) {
            return lang
        }
        // Dockerfile.* pattern
        if lower.hasPrefix("dockerfile."), let lang = language(named: "dockerfile") {
            return lang
        }
        // *.tf / *.tfvars handled by extension
        return nil
    }

    /// Detect language from file content (shebang line, XML declaration, etc.)
    public func detectFromContent(_ text: String) -> LanguageDefinition? {
        guard let firstLine = text.split(separator: "\n", maxSplits: 1).first, !firstLine.isEmpty else {
            return nil
        }
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)

        // Shebang detection
        if trimmed.hasPrefix("#!") {
            let shebang = trimmed.lowercased()
            if shebang.contains("/bash") || shebang.contains("/sh") {
                return language(named: "bash")
            } else if shebang.contains("/python") {
                return language(named: "python")
            } else if shebang.contains("/perl") {
                return language(named: "perl")
            } else if shebang.contains("/ruby") || shebang.contains("ruby") {
                return language(named: "ruby")
            } else if shebang.contains("/node") || shebang.contains("/deno") || shebang.contains("nodejs") {
                return language(named: "javascript")
            } else if shebang.contains("/php") {
                return language(named: "php")
            } else if shebang.contains("/lua") {
                return language(named: "lua")
            } else if shebang.contains("/tclsh") || shebang.contains("/wish") {
                return language(named: "tcl")
            } else if shebang.contains("/awk") || shebang.contains("/gawk") {
                return language(named: "bash")
            } else if shebang.contains("/sed") {
                return language(named: "bash")
            } else if shebang.contains("env python") || shebang.contains("python3") {
                return language(named: "python")
            } else if shebang.contains("env bash") {
                return language(named: "bash")
            } else if shebang.contains("env ruby") {
                return language(named: "ruby")
            } else if shebang.contains("env perl") {
                return language(named: "perl")
            } else if shebang.contains("env node") {
                return language(named: "javascript")
            } else if shebang.contains("env php") {
                return language(named: "php")
            } else if shebang.contains("env lua") {
                return language(named: "lua")
            } else if shebang.contains("env go") {
                return language(named: "go")
            } else if shebang.contains("env rust") || shebang.contains("cargo") {
                return language(named: "rust")
            } else if shebang.contains("env swift") || shebang.contains("swift") {
                return language(named: "swift")
            } else if shebang.contains("env r") || shebang.contains("/rscript") {
                return language(named: "r")
            } else if shebang.contains("env scala") {
                return language(named: "scala")
            }
        }

        // XML declaration
        if trimmed.hasPrefix("<?xml") {
            return language(named: "xml")
        }

        // HTML doctype
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<!doctype") {
            if trimmed.lowercased().contains("html") {
                return language(named: "html")
            }
            return language(named: "xml")
        }

        // HTML <html tag
        if trimmed.hasPrefix("<html") || trimmed.hasPrefix("<HTML") {
            return language(named: "html")
        }

        return nil
    }

    public func appendingUserDefinedLanguages(_ userDefinedLanguages: [UserDefinedLanguage]) -> LanguageCatalog {
        guard !userDefinedLanguages.isEmpty else {
            return self
        }

        var merged = languages
        var indexesByName: [String: Int] = [:]
        for (index, language) in merged.enumerated() {
            indexesByName[Self.normalizedNameKey(language.name)] = index
        }

        for language in userDefinedLanguages.map(LanguageDefinition.init(userDefinedLanguage:)) {
            let nameKey = Self.normalizedNameKey(language.name)
            if let existingIndex = indexesByName[nameKey] {
                merged[existingIndex] = language
            } else {
                indexesByName[nameKey] = merged.count
                merged.append(language)
            }
        }

        return LanguageCatalog(languages: merged)
    }

    /// Folds in built-in languages declared in ``fallback`` that the bundled
    /// ``langs.model.xml`` does not provide. Upstream Notepad++ ships some
    /// languages (e.g. Markdown) as user-defined languages rather than entries
    /// in `langs.model.xml`, so they never reach the runtime catalog loaded
    /// from that file; this keeps them available without patching the
    /// upstream-sourced model. Languages already present are left untouched.
    public func appendingFallbackLanguages() -> LanguageCatalog {
        var merged = languages
        var known = Set(merged.map { Self.normalizedNameKey($0.name) })
        for language in LanguageCatalog.fallback.languages {
            let key = Self.normalizedNameKey(language.name)
            guard !known.contains(key) else { continue }
            // Only restore languages whose Lexilla lexer is resolvable. A few
            // `fallback` entries (e.g. Groovy, Dockerfile) name languages for
            // which no Lexilla lexer is built, so listing them would add menu
            // items and detection labels with no syntax highlighting.
            guard language.lexillaLexerName != nil else { continue }
            merged.append(language)
            known.insert(key)
        }
        return LanguageCatalog(languages: merged)
    }

    public static func load(from url: URL) throws -> LanguageCatalog {
        let parser = XMLParser(contentsOf: url)
        guard let parser else {
            throw LanguageCatalogError.unreadableModel(url.path)
        }

        let delegate = LanguageModelParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw LanguageCatalogError.invalidModel(parser.parserError?.localizedDescription ?? "Unknown XML parser error")
        }

        return LanguageCatalog(languages: delegate.languages)
    }

    public static func loadDefault() -> LanguageCatalog {
        for url in defaultLanguageModelCandidates() where FileManager.default.fileExists(atPath: url.path) {
            if let catalog = try? load(from: url) {
                return catalog.appendingFallbackLanguages()
            }
        }
        return fallback
    }

    public static let fallback = LanguageCatalog(languages: [
        .plainText,
        LanguageDefinition(
            name: "cpp",
            displayName: "C++",
            extensions: ["cpp", "cxx", "cc", "h", "hh", "hpp", "hxx"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["break", "case", "class", "const", "else", "for", "if", "namespace", "return", "struct", "switch", "template", "while"]]
        ),
        LanguageDefinition(
            name: "xml",
            displayName: "XML",
            extensions: ["xml", "xaml", "xsl", "xslt", "xsd", "xul", "kml", "svg", "mxml", "wsdl", "xlf", "xliff", "gml", "gpx", "plist", "slnx", "targets", "vcxproj", "csproj"],
            lineComment: nil,
            blockCommentStart: "<!--",
            blockCommentEnd: "-->",
            keywordGroups: ["instre1": ["ATTLIST", "DOCTYPE", "ELEMENT", "ENTITY", "NOTATION"]]
        ),
        LanguageDefinition(
            name: "html",
            displayName: "HTML",
            extensions: ["html", "htm", "shtml", "shtm", "xhtml"],
            keywordGroups: ["instre1": ["a", "body", "div", "head", "html", "img", "meta", "script", "span", "style", "table", "td", "th", "title", "tr"]]
        ),
        LanguageDefinition(
            name: "json",
            displayName: "JSON",
            extensions: ["json", "jsonc", "har"],
            keywordGroups: ["instre1": ["false", "null", "true"]]
        ),
        LanguageDefinition(
            name: "markdown",
            displayName: "Markdown",
            extensions: ["md", "markdown"],
            keywordGroups: ["instre1": ["TODO", "NOTE", "WARNING"]]
        ),
        LanguageDefinition(
            name: "python",
            displayName: "Python",
            extensions: ["py", "pyw", "pyi"],
            lineComment: "#",
            keywordGroups: ["instre1": ["class", "def", "else", "False", "for", "if", "import", "in", "None", "return", "True", "while"]]
        ),
        LanguageDefinition(
            name: "rust",
            displayName: "Rust",
            extensions: ["rs"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["async", "await", "enum", "false", "fn", "for", "if", "impl", "let", "match", "mut", "pub", "return", "struct", "trait", "true", "use"]]
        ),
        LanguageDefinition(
            name: "swift",
            displayName: "Swift",
            extensions: ["swift"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["actor", "class", "enum", "false", "for", "func", "guard", "if", "import", "let", "nil", "return", "struct", "true", "var"]]
        ),
        LanguageDefinition(
            name: "javascript",
            displayName: "JavaScript",
            extensions: ["js", "jsx", "mjs", "cjs"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["async", "await", "break", "case", "catch", "class", "const", "continue", "default", "delete", "else", "export", "extends", "false", "for", "function", "if", "import", "in", "let", "new", "null", "of", "return", "switch", "this", "throw", "true", "try", "typeof", "undefined", "var", "while"]]
        ),
        LanguageDefinition(
            name: "css",
            displayName: "CSS",
            extensions: ["css", "scss", "less"],
            blockCommentStart: "/*",
            blockCommentEnd: "*/"
        ),
        LanguageDefinition(
            name: "bash",
            displayName: "Bash/Shell",
            extensions: ["sh", "bash", "zsh", "fish", "ksh"],
            lineComment: "#"
        ),
        LanguageDefinition(
            name: "makefile",
            displayName: "Makefile",
            extensions: ["mak", "mk"],
            lineComment: "#"
        ),
        LanguageDefinition(
            name: "perl",
            displayName: "Perl",
            extensions: ["pl", "pm", "t"],
            lineComment: "#"
        ),
        LanguageDefinition(
            name: "php",
            displayName: "PHP",
            extensions: ["php", "php3", "php4", "php5", "phtml"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["class", "echo", "else", "false", "for", "foreach", "function", "if", "null", "private", "protected", "public", "return", "static", "true", "while"]]
        ),
        LanguageDefinition(
            name: "ruby",
            displayName: "Ruby",
            extensions: ["rb", "rbw", "rake", "gemspec"],
            lineComment: "#",
            keywordGroups: ["instre1": ["begin", "class", "def", "else", "end", "false", "if", "module", "nil", "rescue", "return", "true", "unless", "when"]]
        ),
        LanguageDefinition(
            name: "yaml",
            displayName: "YAML",
            extensions: ["yml", "yaml"],
            lineComment: "#",
            keywordGroups: ["instre1": ["false", "no", "true", "yes"]]
        ),
        LanguageDefinition(
            name: "toml",
            displayName: "TOML",
            extensions: ["toml"],
            lineComment: "#",
            keywordGroups: ["instre1": ["false", "true"]]
        ),
        LanguageDefinition(
            name: "sql",
            displayName: "SQL",
            extensions: ["sql"],
            lineComment: "--",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["ALTER", "CREATE", "DELETE", "DROP", "FROM", "GROUP", "HAVING", "INSERT", "INTO", "JOIN", "KEY", "LEFT", "LIMIT", "ORDER", "PRIMARY", "RIGHT", "SELECT", "SET", "TABLE", "UPDATE", "VALUES", "WHERE"]]
        ),
        LanguageDefinition(
            name: "lua",
            displayName: "Lua",
            extensions: ["lua"],
            lineComment: "--",
            blockCommentStart: "--[[",
            blockCommentEnd: "]]",
            keywordGroups: ["instre1": ["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"]]
        ),
        LanguageDefinition(
            name: "cmake",
            displayName: "CMake",
            extensions: ["cmake"],
            lineComment: "#",
            keywordGroups: ["instre1": ["add_executable", "add_library", "cmake_minimum_required", "find_package", "if", "else", "endif", "include", "message", "project", "set", "target_link_libraries"]]
        ),
        LanguageDefinition(
            name: "dockerfile",
            displayName: "Dockerfile",
            extensions: ["dockerfile"],
            lineComment: "#",
            keywordGroups: ["instre1": ["ADD", "ARG", "CMD", "COPY", "ENTRYPOINT", "ENV", "EXPOSE", "FROM", "HEALTHCHECK", "LABEL", "MAINTAINER", "ONBUILD", "RUN", "SHELL", "STOPSIGNAL", "USER", "VOLUME", "WORKDIR"]]
        ),
        LanguageDefinition(
            name: "ini",
            displayName: "INI",
            extensions: ["ini", "cfg", "conf"]
        ),
        LanguageDefinition(
            name: "groovy",
            displayName: "Groovy",
            extensions: ["groovy"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["class", "def", "else", "false", "for", "if", "in", "null", "return", "true", "void", "while"]]
        ),
        LanguageDefinition(
            name: "go",
            displayName: "Go",
            extensions: ["go", "mod", "sum"],
            lineComment: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            keywordGroups: ["instre1": ["break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var"]]
        ),
        LanguageDefinition(
            name: "diff",
            displayName: "Diff",
            extensions: ["diff", "patch"]
        )
    ])

    private static func defaultLanguageModelCandidates() -> [URL] {
        let sourceURL = URL(filePath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appending(path: "langs.model.xml"))
        }
        urls.append(projectRoot.appending(path: "notepad-plus-plus/PowerEditor/src/langs.model.xml"))

        let cwd = URL(filePath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appending(path: "notepad-plus-plus/PowerEditor/src/langs.model.xml"))
        urls.append(cwd.appending(path: "upstream/notepad-plus-plus/PowerEditor/src/langs.model.xml").standardizedFileURL)
        return urls
    }

    private static func deduplicatedByName(_ languages: [LanguageDefinition]) -> [LanguageDefinition] {
        var deduplicated: [LanguageDefinition] = []
        var indexesByName: [String: Int] = [:]

        for language in languages {
            let nameKey = normalizedNameKey(language.name)
            if let existingIndex = indexesByName[nameKey] {
                deduplicated[existingIndex] = language
            } else {
                indexesByName[nameKey] = deduplicated.count
                deduplicated.append(language)
            }
        }

        return deduplicated
    }

    private static func normalizedNameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public enum LanguageDetector {
    public static func detect(url: URL?, in catalog: LanguageCatalog = .fallback) -> LanguageDefinition {
        catalog.detect(url: url)
    }

    /// Detect language from URL + content (shebang/XML decl). Falls back to URL-only detection.
    public static func detect(url: URL?, content: String, in catalog: LanguageCatalog = .fallback) -> LanguageDefinition {
        // Try extension/filename first
        let urlBased = catalog.detect(url: url)
        if urlBased.name != catalog.defaultLanguage.name {
            return urlBased
        }
        // Extension/filename didn't match; try content-based detection
        if let contentBased = catalog.detectFromContent(content) {
            return contentBased
        }
        return urlBased
    }
}

public enum LanguageCatalogError: Error, Equatable, Sendable {
    case unreadableModel(String)
    case invalidModel(String)
}

private final class LanguageModelParser: NSObject, XMLParserDelegate {
    private struct PendingLanguage {
        let name: String
        let extensions: [String]
        let lineComment: String?
        let blockCommentStart: String?
        let blockCommentEnd: String?
        var keywordGroups: [String: [String]] = [:]
    }

    private(set) var languages: [LanguageDefinition] = []
    private var currentLanguage: PendingLanguage?
    private var currentKeywordName: String?
    private var currentKeywordText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "Language":
            guard let name = attributeDict["name"] else { return }
            currentLanguage = PendingLanguage(
                name: name,
                extensions: attributeDict["ext"].splitWords(),
                lineComment: attributeDict["commentLine"],
                blockCommentStart: attributeDict["commentStart"],
                blockCommentEnd: attributeDict["commentEnd"]
            )
        case "Keywords":
            currentKeywordName = attributeDict["name"]
            currentKeywordText = ""
        default:
            return
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentKeywordName != nil else { return }
        currentKeywordText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "Keywords":
            if let name = currentKeywordName {
                let keywords = currentKeywordText.splitWords()
                if !keywords.isEmpty {
                    currentLanguage?.keywordGroups[name] = keywords
                }
            }
            currentKeywordName = nil
            currentKeywordText = ""
        case "Language":
            guard let language = currentLanguage else { return }
            languages.append(
                LanguageDefinition(
                    name: language.name,
                    extensions: language.extensions,
                    lineComment: language.lineComment,
                    blockCommentStart: language.blockCommentStart,
                    blockCommentEnd: language.blockCommentEnd,
                    keywordGroups: language.keywordGroups
                )
            )
            currentLanguage = nil
        default:
            return
        }
    }
}

private extension Optional where Wrapped == String {
    func splitWords() -> [String] {
        self?.splitWords() ?? []
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func splitWords() -> [String] {
        split { $0.isWhitespace }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
