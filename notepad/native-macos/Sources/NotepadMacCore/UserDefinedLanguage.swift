import Foundation

public enum UserDefinedLanguageWordStyleFieldUpdate<Value: Equatable & Sendable>: Equatable, Sendable {
    case unchanged
    case value(Value?)
}

public struct UserDefinedLanguageWordStyle: Codable, Equatable, Sendable {
    public let name: String
    public let fgColor: String?
    public let bgColor: String?
    public let fontName: String?
    public let fontStyle: String?
    public let nesting: String?
    public let attributes: [String: String]

    public init(
        name: String,
        fgColor: String? = nil,
        bgColor: String? = nil,
        fontName: String? = nil,
        fontStyle: String? = nil,
        nesting: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.name = name
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.fontName = fontName
        self.fontStyle = fontStyle
        self.nesting = nesting
        self.attributes = attributes.filter { !Self.knownAttributeNames.contains($0.key) }
    }

    private static let knownAttributeNames: Set<String> = [
        "name",
        "fgColor",
        "bgColor",
        "fontName",
        "fontStyle",
        "nesting"
    ]
}

public struct UserDefinedLanguageWordStyleStructuredUpdate: Equatable, Sendable {
    public let name: String
    public let fgColor: String?
    public let bgColor: String?
    public let fontName: String?
    public let fontStyle: String?
    public let nesting: String?

    public init(
        name: String,
        fgColor: String? = nil,
        bgColor: String? = nil,
        fontName: String? = nil,
        fontStyle: String? = nil,
        nesting: String? = nil
    ) {
        self.name = name.trimmed
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.fontName = fontName
        self.fontStyle = fontStyle
        self.nesting = nesting
    }

    fileprivate var hasStructuredValue: Bool {
        fgColor != nil ||
        bgColor != nil ||
        fontName != nil ||
        fontStyle != nil ||
        nesting != nil
    }
}

private extension UserDefinedLanguageWordStyle {
    func updating(
        fgColor: UserDefinedLanguageWordStyleFieldUpdate<String>,
        bgColor: UserDefinedLanguageWordStyleFieldUpdate<String>,
        fontName: UserDefinedLanguageWordStyleFieldUpdate<String>,
        fontStyle: UserDefinedLanguageWordStyleFieldUpdate<String>,
        nesting: UserDefinedLanguageWordStyleFieldUpdate<String>
    ) -> Self {
        Self(
            name: name,
            fgColor: fgColor.applying(to: self.fgColor),
            bgColor: bgColor.applying(to: self.bgColor),
            fontName: fontName.applying(to: self.fontName),
            fontStyle: fontStyle.applying(to: self.fontStyle),
            nesting: nesting.applying(to: self.nesting),
            attributes: attributes
        )
    }
}

private extension UserDefinedLanguageWordStyleFieldUpdate {
    var initialValue: Value? {
        switch self {
        case .unchanged:
            return nil
        case .value(let value):
            return value
        }
    }

    func applying(to currentValue: Value?) -> Value? {
        switch self {
        case .unchanged:
            return currentValue
        case .value(let value):
            return value
        }
    }
}

public struct UserDefinedLanguage: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let displayName: String
    public let extensions: [String]
    public let keywords: [String]   // Keywords1
    public let wordStyles: [UserDefinedLanguageWordStyle]
    /// Additional keyword lists beyond Keywords1. Keys are canonical names:
    /// "Keywords2"–"Keywords8", "Operators1", "Operators2",
    /// "Comments" (raw comment-descriptor string), etc.
    public let additionalKeywordLists: [String: String]

    public var id: String { name }
    public var editableExtensionsText: String { extensions.joined(separator: " ") }
    public var editableKeywordsText: String { keywords.joined(separator: " ") }
    public var editableWordStylesText: String { Self.editableWordStylesText(for: wordStyles) }

    private static let keywordForegroundWordStyleName = "KEYWORDS1"

    public init?(
        name: String,
        displayName: String? = nil,
        extensions: [String],
        keywords: [String] = [],
        wordStyles: [UserDefinedLanguageWordStyle] = [],
        additionalKeywordLists: [String: String] = [:]
    ) {
        let normalizedName = name.trimmed
        let normalizedExtensions = Self.normalizedUnique(extensions, using: Self.normalizedExtension)

        guard !normalizedName.isEmpty else {
            return nil
        }

        self.name = normalizedName
        self.displayName = displayName?.trimmed.nilIfEmpty ?? normalizedName
        self.extensions = normalizedExtensions
        self.keywords = Self.normalizedUnique(keywords) { keyword in
            keyword.trimmed.nilIfEmpty
        }
        self.wordStyles = wordStyles
        self.additionalKeywordLists = additionalKeywordLists
    }

    public func updating(
        extensionsText: String,
        keywordsText: String
    ) -> Self? {
        Self(
            name: name,
            displayName: displayName,
            extensions: Self.splitEditorList(extensionsText),
            keywords: Self.splitEditorList(keywordsText),
            wordStyles: wordStyles,
            additionalKeywordLists: additionalKeywordLists
        )
    }

    public func updatingKeywordForeground(_ fgColor: String?) -> Self {
        guard fgColor != nil || wordStyles.contains(where: { $0.name == Self.keywordForegroundWordStyleName }) else {
            return self
        }

        return updatingWordStyle(
            named: Self.keywordForegroundWordStyleName,
            fgColor: .value(fgColor)
        )
    }

    public func updatingWordStyle(
        named styleName: String,
        fgColor: UserDefinedLanguageWordStyleFieldUpdate<String> = .unchanged,
        bgColor: UserDefinedLanguageWordStyleFieldUpdate<String> = .unchanged,
        fontName: UserDefinedLanguageWordStyleFieldUpdate<String> = .unchanged,
        fontStyle: UserDefinedLanguageWordStyleFieldUpdate<String> = .unchanged,
        nesting: UserDefinedLanguageWordStyleFieldUpdate<String> = .unchanged
    ) -> Self {
        var didUpdateStyle = false
        let updatedWordStyles = wordStyles.map { style in
            guard style.name == styleName else { return style }

            didUpdateStyle = true
            return style.updating(
                fgColor: fgColor,
                bgColor: bgColor,
                fontName: fontName,
                fontStyle: fontStyle,
                nesting: nesting
            )
        }

        guard !didUpdateStyle else {
            return replacingWordStyles(updatedWordStyles)
        }

        return replacingWordStyles(
            updatedWordStyles + [
                UserDefinedLanguageWordStyle(
                    name: styleName,
                    fgColor: fgColor.initialValue,
                    bgColor: bgColor.initialValue,
                    fontName: fontName.initialValue,
                    fontStyle: fontStyle.initialValue,
                    nesting: nesting.initialValue
                )
            ]
        )
    }

    public func applyingStructuredWordStyleUpdates(
        _ updates: [UserDefinedLanguageWordStyleStructuredUpdate]
    ) -> Self {
        var language = self

        for update in updates {
            guard !update.name.isEmpty,
                  language.wordStyle(named: update.name) != nil || update.hasStructuredValue
            else { continue }

            language = language.updatingWordStyle(
                named: update.name,
                fgColor: .value(update.fgColor),
                bgColor: .value(update.bgColor),
                fontName: .value(update.fontName),
                fontStyle: .value(update.fontStyle),
                nesting: .value(update.nesting)
            )
        }

        return language
    }

    public func wordStyle(named styleName: String) -> UserDefinedLanguageWordStyle? {
        wordStyles.first { $0.name == styleName }
    }

    public func updating(
        extensionsText: String,
        keywordsText: String,
        wordStylesText: String,
        additionalKeywordLists: [String: String]? = nil
    ) -> Self? {
        guard let wordStyles = Self.parseEditableWordStylesText(wordStylesText) else {
            return nil
        }

        return Self(
            name: name,
            displayName: displayName,
            extensions: Self.splitEditorList(extensionsText),
            keywords: Self.splitEditorList(keywordsText),
            wordStyles: wordStyles,
            additionalKeywordLists: additionalKeywordLists ?? self.additionalKeywordLists
        )
    }

    public static func editableWordStylesText(for wordStyles: [UserDefinedLanguageWordStyle]) -> String {
        wordStyles
            .map(editableWordStyleText)
            .joined(separator: "\n")
    }

    public static func parseEditableWordStylesText(_ text: String) -> [UserDefinedLanguageWordStyle]? {
        var wordStyles: [UserDefinedLanguageWordStyle] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmed
            guard !line.isEmpty else { continue }
            guard let attributes = parseEditableWordStyleAttributes(line),
                  let name = attributes["name"],
                  !name.isEmpty
            else {
                return nil
            }

            wordStyles.append(
                UserDefinedLanguageWordStyle(
                    name: name,
                    fgColor: attributes["fgColor"],
                    bgColor: attributes["bgColor"],
                    fontName: attributes["fontName"],
                    fontStyle: attributes["fontStyle"],
                    nesting: attributes["nesting"],
                    attributes: attributes
                )
            )
        }

        return wordStyles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        let extensions = try container.decode([String].self, forKey: .extensions)
        let keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        let wordStyles = try container.decodeIfPresent([UserDefinedLanguageWordStyle].self, forKey: .wordStyles) ?? []

        guard let language = Self(
            name: name,
            displayName: displayName,
            extensions: extensions,
            keywords: keywords,
            wordStyles: wordStyles
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "User-defined languages require a non-empty name."
                )
            )
        }

        self = language
    }

    private func replacingWordStyles(_ wordStyles: [UserDefinedLanguageWordStyle]) -> Self {
        Self(
            name: name,
            displayName: displayName,
            extensions: extensions,
            keywords: keywords,
            wordStyles: wordStyles
        ) ?? self
    }

    static func normalizedExtension(_ rawExtension: String) -> String? {
        var extensionValue = rawExtension.trimmed.lowercased()
        while extensionValue.first == "." {
            extensionValue.removeFirst()
        }
        return extensionValue.nilIfEmpty
    }

    private static func splitEditorList(_ text: String) -> [String] {
        text.split { character in
            character.isWhitespace || character == "," || character == ";"
        }
        .map(String.init)
    }

    private static func normalizedUnique(
        _ values: [String],
        using normalize: (String) -> String?
    ) -> [String] {
        var seen: Set<String> = []
        var normalized: [String] = []

        for value in values {
            guard let next = normalize(value), !seen.contains(next) else { continue }
            seen.insert(next)
            normalized.append(next)
        }

        return normalized
    }

    private static func editableWordStyleText(_ style: UserDefinedLanguageWordStyle) -> String {
        var attributes: [(String, String)] = [("name", style.name)]
        appendEditableWordStyleAttribute("fgColor", style.fgColor, to: &attributes)
        appendEditableWordStyleAttribute("bgColor", style.bgColor, to: &attributes)
        appendEditableWordStyleAttribute("fontName", style.fontName, to: &attributes)
        appendEditableWordStyleAttribute("fontStyle", style.fontStyle, to: &attributes)
        appendEditableWordStyleAttribute("nesting", style.nesting, to: &attributes)

        for key in style.attributes.keys.sorted() {
            guard let value = style.attributes[key] else { continue }
            attributes.append((key, value))
        }

        return attributes
            .map { key, value in "\(key)=\(editableWordStyleValue(value))" }
            .joined(separator: " ")
    }

    private static func appendEditableWordStyleAttribute(
        _ key: String,
        _ value: String?,
        to attributes: inout [(String, String)]
    ) {
        guard let value else { return }
        attributes.append((key, value))
    }

    private static func editableWordStyleValue(_ value: String) -> String {
        let canUsePlainValue = !value.isEmpty && value.allSatisfy { character in
            !character.isWhitespace && character != "\"" && character != "\\"
        }
        guard !canUsePlainValue else { return value }

        var escaped = ""
        for character in value {
            switch character {
            case "\\":
                escaped += "\\\\"
            case "\"":
                escaped += "\\\""
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    private static func parseEditableWordStyleAttributes(_ line: String) -> [String: String]? {
        var attributes: [String: String] = [:]
        var index = line.startIndex

        while index < line.endIndex {
            skipEditableWordStyleWhitespace(in: line, index: &index)
            guard index < line.endIndex else { break }

            let keyStart = index
            while index < line.endIndex,
                  line[index] != "=",
                  !line[index].isWhitespace {
                index = line.index(after: index)
            }

            guard keyStart < index,
                  index < line.endIndex,
                  line[index] == "="
            else {
                return nil
            }

            let key = String(line[keyStart..<index])
            index = line.index(after: index)

            guard let value = parseEditableWordStyleValue(in: line, index: &index) else {
                return nil
            }

            attributes[key] = value

            if index < line.endIndex, !line[index].isWhitespace {
                return nil
            }
        }

        return attributes
    }

    private static func skipEditableWordStyleWhitespace(in line: String, index: inout String.Index) {
        while index < line.endIndex, line[index].isWhitespace {
            index = line.index(after: index)
        }
    }

    private static func parseEditableWordStyleValue(in line: String, index: inout String.Index) -> String? {
        guard index < line.endIndex else { return "" }

        if line[index] != "\"" {
            let start = index
            while index < line.endIndex, !line[index].isWhitespace {
                index = line.index(after: index)
            }
            return String(line[start..<index])
        }

        index = line.index(after: index)
        var value = ""

        while index < line.endIndex {
            let character = line[index]
            index = line.index(after: index)

            switch character {
            case "\"":
                return value
            case "\\":
                guard index < line.endIndex else { return nil }
                let escaped = line[index]
                index = line.index(after: index)

                switch escaped {
                case "n":
                    value.append("\n")
                case "r":
                    value.append("\r")
                case "t":
                    value.append("\t")
                default:
                    value.append(escaped)
                }
            default:
                value.append(character)
            }
        }

        return nil
    }
}

public final class UserDefinedLanguageStore {
    private enum Key {
        static let data = "notepadMac.userDefinedLanguages"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [UserDefinedLanguage] {
        guard let data = defaults.data(forKey: Key.data),
              let languages = try? decoder.decode([UserDefinedLanguage].self, from: data)
        else {
            return []
        }
        return languages
    }

    public func save(_ languages: [UserDefinedLanguage]) {
        guard let data = try? encoder.encode(languages) else { return }
        defaults.set(data, forKey: Key.data)
        defaults.synchronize()
    }

    public func clear() {
        defaults.removeObject(forKey: Key.data)
        defaults.synchronize()
    }
}

extension LanguageDefinition {
    init(userDefinedLanguage language: UserDefinedLanguage) {
        var keywordGroups: [String: [String]] = [:]
        if !language.keywords.isEmpty {
            keywordGroups["udlkw1"] = language.keywords
        }
        for i in 2...8 {
            let listKey = "Keywords\(i)"
            if let text = language.additionalKeywordLists[listKey], !text.isEmpty {
                let words = text.split(separator: " ").map(String.init).filter { !$0.isEmpty }
                if !words.isEmpty {
                    keywordGroups["udlkw\(i)"] = words
                }
            }
        }
        self.init(
            name: language.name,
            displayName: language.displayName,
            extensions: language.extensions,
            keywordGroups: keywordGroups,
            wordStyles: language.wordStyles.compactMap {
                LanguageWordStyle(name: $0.name, foregroundHexRGB: $0.fgColor)
            }
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
