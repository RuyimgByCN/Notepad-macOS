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
        case "typescript", "ts", "tsx":
            "typescript.xml"
        case "go", "golang":
            "go.xml"
        case "kotlin", "kt", "kts":
            "kotlin.xml"
        case "sql", "mysql", "plsql", "mssql":
            "sql.xml"
        case "powershell", "ps1", "psm1", "psd1":
            "powershell.xml"
        case "perl", "pm", "pl":
            "perl.xml"
        case "vb", "vbs", "bas":
            "vb.xml"
        case "css", "scss", "less", "sass":
            "css.xml"
        case "batch", "bat", "cmd":
            "batch.xml"
        case "fortran", "f", "f77", "f90", "f95", "for", "fpp":
            "fortran.xml"
        case "haskell", "hs", "lhs":
            "haskell.xml"
        case "pascal", "pas", "delphi", "dfm":
            "pascal.xml"
        case "ini", "inf", "cfg":
            "ini.xml"
        case "toml":
            "toml.xml"
        case "nim", "nims":
            "nim.xml"
        case "ada", "adb", "ads":
            "ada.xml"
        case "nsis", "nsh", "nsi":
            "nsis.xml"
        case "latex", "tex", "sty", "cls":
            "tex.xml"
        case "d", "di":
            "d.xml"
        case "xml", "xsl", "xslt", "xsd", "dtd":
            "xml.xml"
        case "makefile", "make", "mak", "gnumakefile", "mk":
            "makefile.xml"
        case "gdscript", "gd":
            "gdscript.xml"
        case "vhdl", "vhd":
            "vhdl.xml"
        case "raku", "rk", "rakumod", "rakudoc", "rakutest", "pm6", "pl6", "p6":
            "raku.xml"
        case "sas":
            "sas.xml"
        case "asm", "assembly", "nasm", "masm", "fasm", "gas":
            "asm.xml"
        case "autoit", "au3":
            "autoit.xml"
        case "cobol", "cbl", "cob", "cpy":
            "cobol.xml"
        case "inno", "iss":
            "inno.xml"
        case "baanc", "bc":
            "baanc.xml"
        case "hollywood", "hws":
            "hollywood.xml"
        case "krl":
            "krl.xml"
        case "universe_basic", "uv", "uvb":
            "universe_basic.xml"
        case "sinumerik", "spf", "mpf":
            "sinumerik.xml"
        case "nppexec":
            "nppexec.xml"
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
        case "cpp", "c", "cs", "java":
            extractCStyle(from: text)
        case "typescript", "ts", "tsx":
            extractTypeScript(from: text)
        case "go", "golang":
            extractGo(from: text)
        case "kotlin", "kt", "kts":
            extractKotlin(from: text)
        case "lua":
            extractLua(from: text)
        case "sql", "mysql", "plsql", "mssql":
            extractSQL(from: text)
        case "r":
            extractR(from: text)
        case "scala":
            extractScala(from: text)
        case "powershell", "ps1", "psm1", "psd1":
            extractPowerShell(from: text)
        case "perl", "pm", "pl":
            extractPerl(from: text)
        case "markdown", "md", "mkd", "mdown":
            extractMarkdown(from: text)
        case "vb", "vbs", "bas", "vba":
            extractVisualBasic(from: text)
        case "css", "scss", "less", "sass":
            extractCSS(from: text)
        case "batch", "bat", "cmd":
            extractBatch(from: text)
        case "fortran", "f", "f77", "f90", "f95", "for", "fpp":
            extractFortran(from: text)
        case "haskell", "hs", "lhs":
            extractHaskell(from: text)
        case "pascal", "pas", "delphi", "dfm":
            extractPascal(from: text)
        case "ini", "inf", "cfg":
            extractINI(from: text)
        case "toml":
            extractTOML(from: text)
        case "nim", "nims":
            extractNim(from: text)
        case "ada", "adb", "ads":
            extractAda(from: text)
        case "nsis", "nsh", "nsi":
            extractNSIS(from: text)
        case "latex", "tex", "sty", "cls":
            extractLaTeX(from: text)
        case "d", "di":
            extractDLang(from: text)
        case "xml", "xsl", "xslt", "xsd", "dtd":
            extractXML(from: text)
        case "makefile", "make", "mak", "gnumakefile", "mk":
            extractMakefile(from: text)
        case "gdscript", "gd":
            extractGDScript(from: text)
        case "vhdl", "vhd":
            extractVHDL(from: text)
        case "raku", "rk", "rakumod", "rakudoc", "rakutest", "pm6", "pl6", "p6":
            extractRaku(from: text)
        case "sas":
            extractSAS(from: text)
        case "asm", "assembly", "nasm", "masm", "fasm", "gas":
            extractAssembly(from: text)
        case "autoit", "au3":
            extractAutoIt(from: text)
        case "cobol", "cbl", "cob", "cpy":
            extractCOBOL(from: text)
        case "inno", "iss":
            extractInnoSetup(from: text)
        case "baanc", "bc":
            extractBaanC(from: text)
        case "hollywood", "hws":
            extractHollywood(from: text)
        case "krl":
            extractKRL(from: text)
        case "universe_basic", "uv", "uvb":
            extractUniverseBasic(from: text)
        case "sinumerik", "spf", "mpf":
            extractSinumerik(from: text)
        case "nppexec":
            extractNppExec(from: text)
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

    private static func extractTypeScript(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:export\s+)?(?:abstract\s+)?(?:class|interface|type|enum)\s+([A-Za-z_$][A-Za-z0-9_$]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:export\s+)?(?:async\s+)?function\s*\*?\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*[<(]"#,
            in: text, kind: .function
        )
        let methodSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:public|private|protected|static|abstract|async|override)\s+)*([A-Za-z_$][A-Za-z0-9_$]*)\s*\([^;{}=]*\)\s*(?::\s*[^{;]+)?\s*\{"#,
            in: text, kind: .function
        )
        let arrowSymbols = matches(
            pattern: #"(?m)^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?::[^=]+)?\s*=\s*(?:async\s+)?\([^)]*\)\s*=>"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols + methodSymbols + arrowSymbols)
    }

    private static func extractGo(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^type\s+([A-Za-z_][A-Za-z0-9_]*)\s+(?:struct|interface)\b"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^func\s+(?:\([^)]*\)\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\("#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractKotlin(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:public|private|internal|protected|abstract|open|sealed|data|inner|companion)\s+)*(?:class|interface|object|enum\s+class)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:public|private|internal|protected|override|suspend|inline|infix|operator|open|abstract|final|tailrec)\s+)*fun\s+(?:<[^>]*>\s+)?(?:[A-Za-z_][A-Za-z0-9_.]*\.)?([A-Za-z_][A-Za-z0-9_]*)\s*[<(]"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractLua(from text: String) -> [FunctionListSymbol] {
        let functionKeywordSymbols = matches(
            pattern: #"(?m)^\s*(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_.]*)\s*\("#,
            in: text, kind: .function
        )
        let assignedFunctionSymbols = matches(
            pattern: #"(?m)^\s*(?:local\s+)?([A-Za-z_][A-Za-z0-9_.]*)\s*=\s*function\s*\("#,
            in: text, kind: .function
        )
        return sortedUnique(functionKeywordSymbols + assignedFunctionSymbols)
    }

    private static func extractSQL(from text: String) -> [FunctionListSymbol] {
        let functionSymbols = matches(
            pattern: #"(?mi)^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+([A-Za-z_][A-Za-z0-9_.]*)"#,
            in: text, kind: .function
        )
        let viewSymbols = matches(
            pattern: #"(?mi)^\s*CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+([A-Za-z_][A-Za-z0-9_.]*)"#,
            in: text, kind: .type
        )
        let tableSymbols = matches(
            pattern: #"(?mi)^\s*CREATE\s+(?:TEMP\s+|TEMPORARY\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z_][A-Za-z0-9_.]*)"#,
            in: text, kind: .type
        )
        return sortedUnique(functionSymbols + viewSymbols + tableSymbols)
    }

    private static func extractR(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^([A-Za-z_.][A-Za-z0-9_.]*)\s*<-\s*function\s*\("#,
            in: text, kind: .function
        )
    }

    private static func extractScala(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:abstract|sealed|final|case|implicit|private|protected)\s+)*(?:class|trait|object|type)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:(?:override|private|protected|abstract|implicit|lazy|final)\s+)*def\s+([A-Za-z_][A-Za-z0-9_]*)\b"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractPowerShell(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?mi)^[ \t]*(?:class)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?mi)^[ \t]*(?:function|filter)\s+(?:[A-Za-z]+-)?([A-Za-z_][A-Za-z0-9_-]*)"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractPerl(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^[ \t]*package\s+([A-Za-z_][A-Za-z0-9_:]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^[ \t]*sub\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractMarkdown(from text: String) -> [FunctionListSymbol] {
        // Use headings (## Title) as navigation anchors, mapped to .function kind
        let h1 = matches(pattern: #"(?m)^#\s+(.+)$"#, in: text, kind: .type)
        let h2 = matches(pattern: #"(?m)^##\s+(.+)$"#, in: text, kind: .function)
        let h3 = matches(pattern: #"(?m)^###\s+(.+)$"#, in: text, kind: .function)
        return sortedUnique(h1 + h2 + h3)
    }

    private static func extractVisualBasic(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?mi)^[ \t]*(?:(?:Public|Private|Friend|Protected)\s+)?(?:Class|Module)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?mi)^[ \t]*(?:(?:Public|Private|Protected|Friend|Static)\s+)*(?:Sub|Function|Property\s+(?:Get|Set|Let))\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .function
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

    private static func extractCSS(from text: String) -> [FunctionListSymbol] {
        let selectorSymbols = matches(
            pattern: #"(?m)^([#\.]?[A-Za-z][A-Za-z0-9_\-]*)\s*\{"#,
            in: text, kind: .type
        )
        let keyframeSymbols = matches(
            pattern: #"(?m)@(?:keyframes|-\w+-keyframes)\s+([A-Za-z_][A-Za-z0-9_\-]*)"#,
            in: text, kind: .function
        )
        return sortedUnique(selectorSymbols + keyframeSymbols)
    }

    private static func extractBatch(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)^:([A-Za-z_][A-Za-z0-9_\-\.]*)"#,
            in: text, kind: .function
        )
    }

    private static func extractFortran(from text: String) -> [FunctionListSymbol] {
        let functionSymbols = matches(
            pattern: #"(?mi)^\s*(?:(?:pure|elemental|recursive|integer|real|double\s+precision|complex|logical|character)\s+)?(?:function|subroutine)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .function
        )
        let moduleSymbols = matches(
            pattern: #"(?mi)^\s*(?:module|program)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        return sortedUnique(functionSymbols + moduleSymbols)
    }

    private static func extractHaskell(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^(?:data|newtype|type|class)\s+([A-Z][A-Za-z0-9_']*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^([a-z_][A-Za-z0-9_']*)\s*::"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractPascal(from text: String) -> [FunctionListSymbol] {
        let functionSymbols = matches(
            pattern: #"(?mi)^\s*(?:function|procedure)\s+([A-Za-z_][A-Za-z0-9_\.]*)"#,
            in: text, kind: .function
        )
        let typeSymbols = matches(
            pattern: #"(?mi)^\s*(?:class|interface|type)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        return sortedUnique(functionSymbols + typeSymbols)
    }

    private static func extractINI(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^\[([^\]]+)\]"#,
            in: text, kind: .type
        )
    }

    private static func extractTOML(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^\[+([^\]\n]+)\]+"#,
            in: text, kind: .type
        )
    }

    private static func extractNim(from text: String) -> [FunctionListSymbol] {
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:proc|func|method|template|macro|iterator|converter)\s+([A-Za-z_][A-Za-z0-9_]*)\*?"#,
            in: text, kind: .function
        )
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:type)\s*\n\s*([A-Za-z_][A-Za-z0-9_]*)|(?m)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:object|enum|ref object|tuple)"#,
            in: text, kind: .type
        )
        return sortedUnique(functionSymbols + typeSymbols)
    }

    private static func extractAda(from text: String) -> [FunctionListSymbol] {
        let functionSymbols = matches(
            pattern: #"(?mi)^\s*(?:procedure|function)\s+([A-Za-z_][A-Za-z0-9_\.]*)"#,
            in: text, kind: .function
        )
        let typeSymbols = matches(
            pattern: #"(?mi)^\s*(?:package|task|protected)\s+(?:body\s+)?([A-Za-z_][A-Za-z0-9_\.]*)"#,
            in: text, kind: .type
        )
        return sortedUnique(functionSymbols + typeSymbols)
    }

    private static func extractNSIS(from text: String) -> [FunctionListSymbol] {
        let functionSymbols = matches(
            pattern: #"(?mi)^Function\s+([A-Za-z_\.][A-Za-z0-9_\.]*)"#,
            in: text, kind: .function
        )
        let sectionSymbols = matches(
            pattern: #"(?mi)^Section\s+(?:Un\.)?(?:"([^"]+)"|(\S+))"#,
            in: text, kind: .type
        )
        return sortedUnique(functionSymbols + sectionSymbols)
    }

    private static func extractLaTeX(from text: String) -> [FunctionListSymbol] {
        let sectionSymbols = matches(
            pattern: #"\\(?:chapter|section|subsection|subsubsection)\{([^}]+)\}"#,
            in: text, kind: .type
        )
        let commandSymbols = matches(
            pattern: #"\\(?:newcommand|renewcommand|newenvironment)\{\\([A-Za-z]+)\}"#,
            in: text, kind: .function
        )
        return sortedUnique(sectionSymbols + commandSymbols)
    }

    private static func extractDLang(from text: String) -> [FunctionListSymbol] {
        let typeSymbols = matches(
            pattern: #"(?m)^\s*(?:class|struct|interface|enum|union|template)\s+([A-Za-z_][A-Za-z0-9_]*)"#,
            in: text, kind: .type
        )
        let functionSymbols = matches(
            pattern: #"(?m)^\s*(?:[A-Za-z_][A-Za-z0-9_\!]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{]*\)\s*\{"#,
            in: text, kind: .function
        )
        return sortedUnique(typeSymbols + functionSymbols)
    }

    private static func extractXML(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"<([A-Za-z][A-Za-z0-9_\-]*)(?:\s[^>]*)?\s*(?:>|/>)"#,
            in: text, kind: .type
        )
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

extension FunctionListExtractor {
    private static func extractMakefile(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^([\w$\(\)\-\/\.]+)\s*:"#,
            in: text,
            kind: .function
        )
    }

    private static func extractGDScript(from text: String) -> [FunctionListSymbol] {
        let classSymbols = matches(
            pattern: #"(?m)^class\s+(\w+)"#,
            in: text,
            kind: .type
        )
        let funcSymbols = matches(
            pattern: #"(?m)^(?:\t| {4})*func\s+(\w+)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(classSymbols + funcSymbols)
    }

    private static func extractVHDL(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)^\h*(?:\w+\h*:)?\h*(?:ENTITY|ARCHITECTURE|COMPONENT|PROCESS|BLOCK)\h+(\w[\w\s,\(\)\.]*?)(?:\h+(?:IS|OF)\b|$)"#,
            in: text,
            kind: .function
        )
    }

    private static func extractRaku(from text: String) -> [FunctionListSymbol] {
        let classSymbols = matches(
            pattern: #"(?m)^\s*(?:class|role|module|grammar|package)\s+([A-Za-z_]\w*(?:::[A-Za-z_]\w*)*)"#,
            in: text,
            kind: .type
        )
        let funcSymbols = matches(
            pattern: #"(?m)^\s*(?:sub|method|multi sub|multi method)\s+([A-Za-z_]\w*)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(classSymbols + funcSymbols)
    }

    private static func extractSAS(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)^\h*(?:%macro|function)\h+(\w+)"#,
            in: text,
            kind: .function
        )
    }

    private static func extractAssembly(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^\h*([A-Za-z_$][\w$]*)(?=\s*:)"#,
            in: text,
            kind: .function
        )
    }

    private static func extractAutoIt(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)^\h*Func\h+([A-Za-z_]\w*)\h*\("#,
            in: text,
            kind: .function
        )
    }

    private static func extractCOBOL(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)^.{0,7}\h{0,3}(\b[\w-]+\b)(?:\h+SECTION)?\."#,
            in: text,
            kind: .function
        )
    }

    private static func extractInnoSetup(from text: String) -> [FunctionListSymbol] {
        let sectionSymbols = matches(
            pattern: #"(?m)^\[(\w+)\]"#,
            in: text,
            kind: .type
        )
        let funcSymbols = matches(
            pattern: #"(?mi)^\h*function\h+([A-Za-z_]\w*)\h*\("#,
            in: text,
            kind: .function
        )
        let procSymbols = matches(
            pattern: #"(?mi)^\h*procedure\h+([A-Za-z_]\w*)\h*[;(]"#,
            in: text,
            kind: .function
        )
        return sortedUnique(sectionSymbols + funcSymbols + procSymbols)
    }

    private static func extractBaanC(from text: String) -> [FunctionListSymbol] {
        let sectionSymbols = matches(
            pattern: #"(?m)^\h*((?:after|before)\.(?:report\.\d+|\w+(?:\.\w+)*\.\d+)|(?:field|zoom\.from)\.(?:all|other|\w+(?:\.\w+)*)|(?:footer|group|header)\.\d+|choice\.\w+(?:\.\w+)*|detail\.\d+|form\.(?:all|other|\d+)|functions|main\.table\.io):"#,
            in: text,
            kind: .type
        )
        let funcSymbols = matches(
            pattern: #"(?mi)^\h*function\s+(?:extern\s+)?(?:boolean|double|long|string|void|domain\s+\w+(?:\.\w+)*)?\s*(\w+(?:\.\w+)*)\s*\("#,
            in: text,
            kind: .function
        )
        return sortedUnique(sectionSymbols + funcSymbols)
    }

    private static func extractHollywood(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)\bfunction\s+([A-Za-z_$][\w$:.]*)\s*\("#,
            in: text,
            kind: .function
        )
    }

    private static func extractKRL(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?mi)^\h*(?:GLOBAL\h+)?DEF(?:FCT\h+(?:BOOL|CHAR|INT|REAL|\w+)(?:\h*\[\h*\d*\h*\])?)?\h+(\w+)\h*\("#,
            in: text,
            kind: .function
        )
    }

    private static func extractUniverseBasic(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^(?:\d+\b|[A-Za-z_][\w.$%]*(?=:))"#,
            in: text,
            kind: .function
        )
    }

    private static func extractSinumerik(from text: String) -> [FunctionListSymbol] {
        matches(
            pattern: #"(?m)^%_N_([A-Za-z_]\w*)"#,
            in: text,
            kind: .function
        )
    }

    private static func extractNppExec(from text: String) -> [FunctionListSymbol] {
        let scriptSymbols = matches(
            pattern: #"(?m)^\h*::(.+)"#,
            in: text,
            kind: .type
        )
        let labelSymbols = matches(
            pattern: #"(?m)^\h*:(?!:)(.+)"#,
            in: text,
            kind: .function
        )
        return sortedUnique(scriptSymbols + labelSymbols)
    }
}
