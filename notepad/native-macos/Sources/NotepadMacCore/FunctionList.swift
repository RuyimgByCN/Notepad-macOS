import Foundation

public struct FunctionListDefinition: Equatable, Sendable {
    public let displayName: String
    public let identifier: String
    public let functionPatterns: [String]
    public let classRangePatterns: [String]

    public init(
        displayName: String,
        identifier: String,
        functionPatterns: [String] = [],
        classRangePatterns: [String] = []
    ) {
        self.displayName = displayName
        self.identifier = identifier
        self.functionPatterns = functionPatterns
        self.classRangePatterns = classRangePatterns
    }

    public static func load(from url: URL) throws -> FunctionListDefinition {
        let parser = XMLParser(contentsOf: url)
        guard let parser else {
            throw FunctionListError.unreadableModel(url.path)
        }

        let delegate = FunctionListModelParser(fallbackName: url.deletingPathExtension().lastPathComponent)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw FunctionListError.invalidModel(parser.parserError?.localizedDescription ?? "Unknown XML parser error")
        }

        return delegate.definition
    }

    public static func loadDefault(languageName: String) -> FunctionListDefinition? {
        for url in defaultFunctionListCandidates(languageName: languageName) where FileManager.default.fileExists(atPath: url.path) {
            if let definition = try? load(from: url) {
                return definition
            }
        }
        return nil
    }

    private static func defaultFunctionListCandidates(languageName: String) -> [URL] {
        let fileName = functionListFileName(for: languageName)
        let sourceURL = URL(filePath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appending(path: "functionList").appending(path: fileName))
        }
        urls.append(projectRoot.appending(path: "notepad-plus-plus/PowerEditor/installer/functionList/\(fileName)"))

        let cwd = URL(filePath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appending(path: "notepad-plus-plus/PowerEditor/installer/functionList/\(fileName)"))
        urls.append(cwd.appending(path: "../notepad-plus-plus/PowerEditor/installer/functionList/\(fileName)").standardizedFileURL)
        return urls
    }

    private static func functionListFileName(for languageName: String) -> String {
        switch languageName.lowercased() {
        case "javascript", "javascript.js", "js", "jsx", "mjs":
            "javascript.js.xml"
        case "objective-c", "objc":
            "objc.xml"
        case "bash", "shell", "sh":
            "bash.xml"
        default:
            "\(languageName.lowercased()).xml"
        }
    }
}

public enum FunctionListError: Error, Equatable, Sendable {
    case unreadableModel(String)
    case invalidModel(String)
}

public enum FunctionListSymbolKind: String, Equatable, Sendable {
    case function
    case type
}

public struct FunctionListSymbol: Equatable, Identifiable, Sendable {
    public let name: String
    public let kind: FunctionListSymbolKind
    public let line: Int
    public let range: NSRange

    public var id: String { "\(line):\(kind.rawValue):\(name)" }

    public init(name: String, kind: FunctionListSymbolKind, line: Int, range: NSRange) {
        self.name = name
        self.kind = kind
        self.line = line
        self.range = range
    }
}

public enum FunctionListExtractor {
    public static func extract(
        from text: String,
        languageName: String,
        definition: FunctionListDefinition? = nil
    ) -> [FunctionListSymbol] {
        switch languageName.lowercased() {
        case "bash", "shell", "sh":
            extractBash(from: text)
        case "rust":
            extractRust(from: text)
        case "python":
            extractPython(from: text)
        case "swift":
            extractSwift(from: text)
        case "javascript", "javascript.js", "js", "jsx", "mjs":
            extractJavaScript(from: text)
        case "php", "php3", "php4", "php5", "phtml":
            extractPHP(from: text)
        case "ruby", "rb":
            extractRuby(from: text)
        case "cpp", "c", "cs", "java", "typescript":
            extractCStyle(from: text)
        default:
            definition == nil ? [] : extractCStyle(from: text)
        }
    }

    private static func extractRust(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:pub(?:\([^)]*\))?\s+)?(?:struct|enum|trait)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:pub(?:\([^)]*\))?|async|const|unsafe)\s+)*(?:extern\s+"[^"]+"\s+)?fn\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractBash(from text: String) -> [FunctionListSymbol] {
        let keywordExclusions = #"(?!(?:do(?:ne)?|el(?:if|se)|esac|fi|for|function|if|in|select|then|time|until|while)\b)"#
        let functionKeywordSymbols = matches(
            pattern: #"(?m)^[ \t]*function[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*(?:\([^)]*\))?[ \t]*[^{;\n]*\{"#,
            in: text,
            kind: .function
        )
        let parenthesizedSymbols = matches(
            pattern: #"(?m)^[ \t]*\#(keywordExclusions)([A-Za-z_][A-Za-z0-9_]*)[ \t]*\([^)]*\)[ \t]*[^{;\n]*\{"#,
            in: text,
            kind: .function
        )
        return sortedUnique(functionKeywordSymbols + parenthesizedSymbols)
    }

    private static func extractPython(from text: String) -> [FunctionListSymbol] {
        let classSymbols = matches(
            pattern: #"(?m)^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(classSymbols + functionSymbols)
    }

    private static func extractSwift(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:public|private|internal|fileprivate|open)?\s*(?:actor|class|struct|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:public|private|internal|fileprivate|open|static|class|mutating|nonmutating|override|final)?(?:\s+(?:public|private|internal|fileprivate|open|static|class|mutating|nonmutating|override|final))*\s*func\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractJavaScript(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*class\s+([A-Za-z_$][A-Za-z0-9_$]*)[^{]*\{"#,
            in: text,
            kind: .type
        )
        let classMethodSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:static|async)\s+)*(?!(?:if|while|for|switch)\b)([A-Za-z_$][A-Za-z0-9_$]*)\s*\([^;{}=]*\)\s*\{"#,
            in: text,
            kind: .function
        )
        let functionDeclarationSymbols = matches(
            pattern: #"(?m)^\s*(?:export\s+(?:default\s+)?)?(?:async\s+)?function\s*\*?\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\([^;{}]*\)\s*\{"#,
            in: text,
            kind: .function
        )
        let assignedFunctionSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:var|let|const)\s+)?(?:[A-Za-z_$][A-Za-z0-9_$]*\.)*([A-Za-z_$][A-Za-z0-9_$]*)\s*[=:]\s*(?:async\s+)?function(?:\s+[A-Za-z_$][A-Za-z0-9_$]*)?\s*\([^;{}]*\)\s*\{"#,
            in: text,
            kind: .function
        )
        return sortedUnique(typeSymbols + classMethodSymbols + functionDeclarationSymbols + assignedFunctionSymbols)
    }

    private static func extractPHP(from text: String) -> [FunctionListSymbol] {
        let identifier = #"[A-Za-z_][A-Za-z0-9_]*"#
        let typeSymbols = matches(
            pattern: #"(?m)^[ \t]*(?:(?:abstract|final)[ \t]+)?(?:readonly[ \t]+)?(?:class|interface|trait)[ \t]+("# + identifier + #")\b[^{]*(?:\{|$)"#,
            in: text,
            kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^[ \t]*(?:(?:public|protected|private|abstract|final|static)[ \t]+)*function[ \t]+&?[ \t]*("# + identifier + #")[ \t]*\([^;{]*(?:\{|;)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractRuby(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^[ \t]*class[ \t]+([A-Za-z_][A-Za-z0-9_:]*)\b"#,
            in: text,
            kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^[ \t]*def[ \t]+(?:self\.)?([A-Za-z_][A-Za-z0-9_!?=]*)\b"#,
            in: text,
            kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractCStyle(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:class|struct|interface|enum)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text,
            kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:[A-Za-z_][A-Za-z0-9_:<>\*&\[\]\s]+\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*(?:const\s*)?(?:\{|;)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func matches(pattern: String, in text: String, kind: FunctionListSymbolKind) -> [FunctionListSymbol] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, range: fullRange).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound else { return nil }
            let name = nsText.substring(with: nameRange)
            return FunctionListSymbol(
                name: name,
                kind: kind,
                line: lineNumber(at: nameRange.location, in: nsText),
                range: nameRange
            )
        }
    }

    private static func lineNumber(at utf16Location: Int, in text: NSString) -> Int {
        guard utf16Location > 0 else { return 1 }
        let prefix = text.substring(with: NSRange(location: 0, length: min(utf16Location, text.length)))
        var line = 1
        var previousWasCarriageReturn = false

        for scalar in prefix.unicodeScalars {
            switch scalar {
            case "\n":
                if !previousWasCarriageReturn {
                    line += 1
                }
                previousWasCarriageReturn = false
            case "\r":
                line += 1
                previousWasCarriageReturn = true
            default:
                previousWasCarriageReturn = false
            }
        }
        return line
    }

    private static func sortedUnique(_ symbols: [FunctionListSymbol]) -> [FunctionListSymbol] {
        var seen: Set<String> = []
        return symbols
            .sorted { lhs, rhs in
                if lhs.range.location == rhs.range.location {
                    return lhs.name < rhs.name
                }
                return lhs.range.location < rhs.range.location
            }
            .filter { symbol in
                let key = "\(symbol.range.location):\(symbol.name):\(symbol.kind.rawValue)"
                return seen.insert(key).inserted
            }
    }
}

private final class FunctionListModelParser: NSObject, XMLParserDelegate {
    private let fallbackName: String
    private var displayName: String?
    private var identifier: String?
    private var functionPatterns: [String] = []
    private var classRangePatterns: [String] = []
    private var parserDepth = 0

    var definition: FunctionListDefinition {
        FunctionListDefinition(
            displayName: displayName ?? fallbackName,
            identifier: identifier ?? fallbackName,
            functionPatterns: functionPatterns,
            classRangePatterns: classRangePatterns
        )
    }

    init(fallbackName: String) {
        self.fallbackName = fallbackName
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "parser":
            guard parserDepth == 0 else { return }
            parserDepth += 1
            displayName = attributeDict["displayName"]?.nilIfEmpty ?? fallbackName
            identifier = attributeDict["id"]?.nilIfEmpty ?? fallbackName
        case "function":
            guard let pattern = attributeDict["mainExpr"]?.nilIfEmpty else { return }
            functionPatterns.append(pattern)
        case "classRange":
            guard let pattern = attributeDict["mainExpr"]?.nilIfEmpty else { return }
            classRangePatterns.append(pattern)
        default:
            return
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "parser", parserDepth > 0 {
            parserDepth -= 1
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
