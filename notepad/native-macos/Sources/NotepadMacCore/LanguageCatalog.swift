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
        wordStyles: [LanguageWordStyle] = []
    ) {
        self.name = name
        self.displayName = displayName ?? LanguageDefinition.defaultDisplayName(for: name)
        self.extensions = extensions
        self.lineComment = lineComment?.nilIfEmpty
        self.blockCommentStart = blockCommentStart?.nilIfEmpty
        self.blockCommentEnd = blockCommentEnd?.nilIfEmpty
        self.keywordGroups = keywordGroups
        self.wordStyles = wordStyles
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
        guard let ext = url?.pathExtension, !ext.isEmpty else {
            return defaultLanguage
        }
        return language(for: ext) ?? defaultLanguage
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
                return catalog
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
            name: "markdown",
            displayName: "Markdown",
            extensions: ["md", "markdown"],
            keywordGroups: ["instre1": ["TODO", "NOTE", "WARNING"]]
        ),
        LanguageDefinition(
            name: "python",
            displayName: "Python",
            extensions: ["py", "pyw"],
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
        urls.append(cwd.appending(path: "../notepad-plus-plus/PowerEditor/src/langs.model.xml").standardizedFileURL)
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
