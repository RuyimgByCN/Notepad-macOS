import Foundation

public struct AutoCompletionEnvironment: Equatable, Sendable {
    public let ignoreCase: Bool
    public let startFunction: String?
    public let stopFunction: String?
    public let parameterSeparator: String?
    public let terminal: String?
    public let additionalWordCharacters: String?

    public init(
        ignoreCase: Bool = false,
        startFunction: String? = nil,
        stopFunction: String? = nil,
        parameterSeparator: String? = nil,
        terminal: String? = nil,
        additionalWordCharacters: String? = nil
    ) {
        self.ignoreCase = ignoreCase
        self.startFunction = startFunction?.nilIfEmpty
        self.stopFunction = stopFunction?.nilIfEmpty
        self.parameterSeparator = parameterSeparator?.nilIfEmpty
        self.terminal = terminal?.nilIfEmpty
        self.additionalWordCharacters = additionalWordCharacters?.nilIfEmpty
    }
}

public struct AutoCompletionParameter: Equatable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct AutoCompletionOverload: Equatable, Sendable {
    public let returnValue: String?
    public let description: String?
    public let parameters: [AutoCompletionParameter]

    public init(
        returnValue: String? = nil,
        description: String? = nil,
        parameters: [AutoCompletionParameter] = []
    ) {
        self.returnValue = returnValue?.nilIfEmpty
        self.description = description?.nilIfEmpty
        self.parameters = parameters
    }
}

public struct AutoCompletionKeyword: Equatable, Identifiable, Sendable {
    public let name: String
    public let isFunction: Bool
    public let overloads: [AutoCompletionOverload]

    public var id: String { name }

    public init(name: String, isFunction: Bool = false, overloads: [AutoCompletionOverload] = []) {
        self.name = name
        self.isFunction = isFunction
        self.overloads = overloads
    }
}

public struct AutoCompletionCallTip: Equatable, Sendable {
    public let keyword: AutoCompletionKeyword
    public let activeParameterIndex: Int
    public let startFunction: String
    public let stopFunction: String
    public let parameterSeparator: String

    public init(
        keyword: AutoCompletionKeyword,
        activeParameterIndex: Int,
        startFunction: String = "(",
        stopFunction: String = ")",
        parameterSeparator: String = ","
    ) {
        self.keyword = keyword
        self.activeParameterIndex = activeParameterIndex
        self.startFunction = startFunction
        self.stopFunction = stopFunction
        self.parameterSeparator = parameterSeparator
    }

    public var signatures: [String] {
        guard !keyword.overloads.isEmpty else {
            return ["\(keyword.name)\(startFunction)\(stopFunction)"]
        }

        return keyword.overloads.map { overload in
            let parameters = overload.parameters.map(\.name).joined(separator: displayParameterSeparator)
            let returnSuffix = overload.returnValue.map { " -> \($0)" } ?? ""
            return "\(keyword.name)\(startFunction)\(parameters)\(stopFunction)\(returnSuffix)"
        }
    }

    public var details: [String] {
        keyword.overloads.compactMap(\.description)
    }

    private var displayParameterSeparator: String {
        parameterSeparator == "," ? ", " : parameterSeparator
    }
}

public struct AutoCompletionCatalog: Equatable, Sendable {
    public let languageDisplayName: String
    public let environment: AutoCompletionEnvironment
    public let keywords: [AutoCompletionKeyword]

    private let byName: [String: AutoCompletionKeyword]

    public init(
        languageDisplayName: String,
        environment: AutoCompletionEnvironment = AutoCompletionEnvironment(),
        keywords: [AutoCompletionKeyword]
    ) {
        self.languageDisplayName = languageDisplayName
        self.environment = environment
        self.keywords = keywords.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        self.byName = Dictionary(uniqueKeysWithValues: self.keywords.map { ($0.name, $0) })
    }

    private enum CodingKeys: String, CodingKey {
        case languageDisplayName
        case environment
        case keywords
    }

    public func keyword(named name: String) -> AutoCompletionKeyword? {
        byName[name]
    }

    public func completions(prefix: String, limit: Int = 200) -> [AutoCompletionKeyword] {
        let normalizedPrefix = environment.ignoreCase ? prefix.lowercased() : prefix
        guard !normalizedPrefix.isEmpty else {
            return Array(keywords.prefix(limit))
        }

        return Array(
            keywords
                .filter { keyword in
                    let candidate = environment.ignoreCase ? keyword.name.lowercased() : keyword.name
                    return candidate.hasPrefix(normalizedPrefix)
                }
                .prefix(limit)
        )
    }

    public func callTip(in text: String, caretLocation: Int) -> AutoCompletionCallTip? {
        let startFunction = environment.startFunction ?? "("
        let stopFunction = environment.stopFunction ?? ")"
        let parameterSeparator = environment.parameterSeparator ?? ","
        let nsText = text as NSString
        let clampedCaret = max(0, min(caretLocation, nsText.length))
        let prefix = nsText.substring(to: clampedCaret) as NSString

        guard let startRange = lastUnclosedStartFunction(in: prefix, startFunction: startFunction, stopFunction: stopFunction) else {
            return nil
        }

        let functionPrefix = prefix.substring(to: startRange.location)
        guard let keyword = functionKeyword(before: functionPrefix) else {
            return nil
        }

        let argumentsStart = startRange.location + startRange.length
        let argumentText = nsText.substring(with: NSRange(location: argumentsStart, length: clampedCaret - argumentsStart)) as NSString
        return AutoCompletionCallTip(
            keyword: keyword,
            activeParameterIndex: activeParameterIndex(
                in: argumentText,
                startFunction: startFunction,
                stopFunction: stopFunction,
                parameterSeparator: parameterSeparator
            ),
            startFunction: startFunction,
            stopFunction: stopFunction,
            parameterSeparator: parameterSeparator
        )
    }

    public static func load(from url: URL) throws -> AutoCompletionCatalog {
        let parser = XMLParser(contentsOf: url)
        guard let parser else {
            throw AutoCompletionCatalogError.unreadableModel(url.path)
        }

        let delegate = AutoCompletionModelParser(fallbackLanguageName: url.deletingPathExtension().lastPathComponent)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw AutoCompletionCatalogError.invalidModel(parser.parserError?.localizedDescription ?? "Unknown XML parser error")
        }

        return AutoCompletionCatalog(
            languageDisplayName: delegate.languageDisplayName,
            environment: delegate.environment,
            keywords: delegate.keywords
        )
    }

    public static func loadDefault(languageName: String) -> AutoCompletionCatalog? {
        for url in defaultAPICandidates(languageName: languageName) where FileManager.default.fileExists(atPath: url.path) {
            if let catalog = try? load(from: url) {
                return catalog
            }
        }
        return nil
    }

    private static func defaultAPICandidates(languageName: String) -> [URL] {
        let fileName = apiFileName(for: languageName)
        let sourceURL = URL(filePath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appending(path: "APIs").appending(path: fileName))
        }
        urls.append(projectRoot.appending(path: "notepad-plus-plus/PowerEditor/installer/APIs/\(fileName)"))

        let cwd = URL(filePath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appending(path: "notepad-plus-plus/PowerEditor/installer/APIs/\(fileName)"))
        urls.append(cwd.appending(path: "upstream/notepad-plus-plus/PowerEditor/installer/APIs/\(fileName)").standardizedFileURL)
        return urls
    }

    private static func apiFileName(for languageName: String) -> String {
        switch languageName.lowercased() {
        case "javascript", "js":
            "javascript.xml"
        case "typescript", "ts":
            "typescript.xml"
        case "objective-c", "objc":
            "objc.xml"
        default:
            "\(languageName.lowercased()).xml"
        }
    }

    private func functionKeyword(before prefix: String) -> AutoCompletionKeyword? {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = environment.ignoreCase ? trimmed.lowercased() : trimmed

        return keywords
            .filter(\.isFunction)
            .filter { keyword in
                let name = environment.ignoreCase ? keyword.name.lowercased() : keyword.name
                return source.hasSuffix(name) && hasFunctionBoundary(source: source, keywordLength: (name as NSString).length)
            }
            .max { lhs, rhs in
                (lhs.name as NSString).length < (rhs.name as NSString).length
            }
    }

    private func hasFunctionBoundary(source: String, keywordLength: Int) -> Bool {
        let nsSource = source as NSString
        let start = nsSource.length - keywordLength
        guard start > 0 else { return true }

        let range = nsSource.rangeOfComposedCharacterSequence(at: start - 1)
        let fragment = nsSource.substring(with: range)
        let allowedScalars = Set((environment.additionalWordCharacters ?? "").unicodeScalars)
        return !fragment.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || allowedScalars.contains(scalar)
        }
    }

    private func lastUnclosedStartFunction(
        in text: NSString,
        startFunction: String,
        stopFunction: String
    ) -> NSRange? {
        var stack: [NSRange] = []
        var location = 0

        while location < text.length {
            if let skippedLocation = text.skipLiteralOrComment(from: location) {
                location = skippedLocation
            } else if text.matches(startFunction, at: location) {
                stack.append(NSRange(location: location, length: (startFunction as NSString).length))
                location += (startFunction as NSString).length
            } else if text.matches(stopFunction, at: location) {
                if !stack.isEmpty {
                    stack.removeLast()
                }
                location += (stopFunction as NSString).length
            } else {
                location = text.rangeOfComposedCharacterSequence(at: location).upperBound
            }
        }

        return stack.last
    }

    private func activeParameterIndex(
        in text: NSString,
        startFunction: String,
        stopFunction: String,
        parameterSeparator: String
    ) -> Int {
        var depth = 0
        var index = 0
        var location = 0

        while location < text.length {
            if let skippedLocation = text.skipLiteralOrComment(from: location) {
                location = skippedLocation
            } else if text.matches(startFunction, at: location) {
                depth += 1
                location += (startFunction as NSString).length
            } else if text.matches(stopFunction, at: location) {
                depth = max(0, depth - 1)
                location += (stopFunction as NSString).length
            } else if depth == 0, text.matches(parameterSeparator, at: location) {
                index += 1
                location += (parameterSeparator as NSString).length
            } else {
                location = text.rangeOfComposedCharacterSequence(at: location).upperBound
            }
        }

        return index
    }
}

public enum AutoCompletionCatalogError: Error, Equatable, Sendable {
    case unreadableModel(String)
    case invalidModel(String)
}

private final class AutoCompletionModelParser: NSObject, XMLParserDelegate {
    private struct PendingKeyword {
        let name: String
        let isFunction: Bool
        var overloads: [AutoCompletionOverload] = []
    }

    private struct PendingOverload {
        let returnValue: String?
        let description: String?
        var parameters: [AutoCompletionParameter] = []
    }

    private let fallbackLanguageName: String

    private(set) var languageDisplayName: String
    private(set) var environment = AutoCompletionEnvironment()
    private(set) var keywords: [AutoCompletionKeyword] = []

    private var currentKeyword: PendingKeyword?
    private var currentOverload: PendingOverload?

    init(fallbackLanguageName: String) {
        self.fallbackLanguageName = fallbackLanguageName
        self.languageDisplayName = fallbackLanguageName
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "AutoComplete":
            languageDisplayName = attributeDict["language"]?.nilIfEmpty ?? fallbackLanguageName
        case "Environment":
            environment = AutoCompletionEnvironment(
                ignoreCase: attributeDict["ignoreCase"]?.lowercased() == "yes",
                startFunction: attributeDict["startFunc"],
                stopFunction: attributeDict["stopFunc"],
                parameterSeparator: attributeDict["paramSeparator"],
                terminal: attributeDict["terminal"],
                additionalWordCharacters: attributeDict["additionalWordChar"]
            )
        case "KeyWord":
            guard let name = attributeDict["name"]?.nilIfEmpty else { return }
            currentKeyword = PendingKeyword(name: name, isFunction: attributeDict["func"]?.lowercased() == "yes")
        case "Overload":
            currentOverload = PendingOverload(
                returnValue: attributeDict["retVal"],
                description: attributeDict["descr"]
            )
        case "Param":
            guard let name = attributeDict["name"]?.nilIfEmpty else { return }
            currentOverload?.parameters.append(AutoCompletionParameter(name: name))
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
        switch elementName {
        case "Overload":
            guard let overload = currentOverload else { return }
            currentKeyword?.overloads.append(
                AutoCompletionOverload(
                    returnValue: overload.returnValue,
                    description: overload.description,
                    parameters: overload.parameters
                )
            )
            currentOverload = nil
        case "KeyWord":
            guard let keyword = currentKeyword else { return }
            keywords.append(
                AutoCompletionKeyword(
                    name: keyword.name,
                    isFunction: keyword.isFunction,
                    overloads: keyword.overloads
                )
            )
            currentKeyword = nil
        default:
            return
        }
    }
}

private extension NSString {
    func matches(_ token: String, at location: Int) -> Bool {
        let tokenLength = (token as NSString).length
        guard tokenLength > 0, location + tokenLength <= length else {
            return false
        }
        return substring(with: NSRange(location: location, length: tokenLength)) == token
    }

    func skipLiteralOrComment(from location: Int) -> Int? {
        if matches("//", at: location) {
            return endOfLineComment(from: location + 2)
        }
        if matches("/*", at: location) {
            return endOfBlockComment(from: location + 2)
        }
        if matches("\"", at: location) {
            return endOfQuotedLiteral(from: location + 1, quote: "\"")
        }
        if matches("'", at: location) {
            return endOfQuotedLiteral(from: location + 1, quote: "'")
        }
        return nil
    }

    private func endOfLineComment(from location: Int) -> Int {
        var index = location
        while index < length {
            let range = rangeOfComposedCharacterSequence(at: index)
            let fragment = substring(with: range)
            if fragment == "\n" || fragment == "\r" {
                return range.upperBound
            }
            index = range.upperBound
        }
        return length
    }

    private func endOfBlockComment(from location: Int) -> Int {
        var index = location
        while index < length {
            if matches("*/", at: index) {
                return index + 2
            }
            index = rangeOfComposedCharacterSequence(at: index).upperBound
        }
        return length
    }

    private func endOfQuotedLiteral(from location: Int, quote: String) -> Int {
        var index = location
        while index < length {
            if matches("\\", at: index) {
                let next = index + 1
                index = next < length ? rangeOfComposedCharacterSequence(at: next).upperBound : length
            } else if matches(quote, at: index) {
                return index + 1
            } else {
                index = rangeOfComposedCharacterSequence(at: index).upperBound
            }
        }
        return length
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
