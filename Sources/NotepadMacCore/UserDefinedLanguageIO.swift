import Foundation

public enum UserDefinedLanguageIO {
    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidXML
        case invalidUserDefinedLanguage
    }

    public static func importLanguage(from xml: String) throws -> UserDefinedLanguage {
        try importLanguage(from: Data(xml.utf8))
    }

    public static func importLanguage(from data: Data) throws -> UserDefinedLanguage {
        let parser = XMLParser(data: data)
        let delegate = UserDefinedLanguageXMLParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw Error.invalidXML
        }

        guard let rawLanguage = delegate.language,
              let language = UserDefinedLanguage(
                name: rawLanguage.name,
                extensions: rawLanguage.extensions,
                keywords: rawLanguage.keywords,
                wordStyles: rawLanguage.wordStyles,
                additionalKeywordLists: rawLanguage.additionalKeywordLists
              )
        else {
            throw Error.invalidUserDefinedLanguage
        }

        return language
    }

    public static func exportLanguage(_ language: UserDefinedLanguage) -> String {
        let name = escapeXMLAttribute(language.name)
        let extensions = escapeXMLAttribute(language.extensions.joined(separator: " "))
        let keywords = escapeXMLText(language.keywords.joined(separator: " "))

        var keywordLines = ["        <Keywords name=\"Keywords1\">\(keywords)</Keywords>"]
        // Write additional keyword lists in alphabetical order (Keywords2-8 first, then others)
        let orderedKeys = language.additionalKeywordLists.keys.sorted { a, b in
            let aIsKw = a.hasPrefix("Keywords")
            let bIsKw = b.hasPrefix("Keywords")
            if aIsKw && bIsKw { return a < b }
            if aIsKw { return true }
            if bIsKw { return false }
            return a < b
        }
        for key in orderedKeys {
            let value = escapeXMLText(language.additionalKeywordLists[key] ?? "")
            keywordLines.append("        <Keywords name=\"\(escapeXMLAttribute(key))\">\(value)</Keywords>")
        }

        var lines = [
            "<UserLang name=\"\(name)\" ext=\"\(extensions)\">",
            "    <KeywordLists>"
        ]
        lines.append(contentsOf: keywordLines)
        lines.append("    </KeywordLists>")
        if !language.wordStyles.isEmpty {
            lines.append("    <Styles>")
            lines.append(contentsOf: language.wordStyles.map { "        \(wordsStyleXML($0))" })
            lines.append("    </Styles>")
        }
        lines.append("</UserLang>")
        return lines.joined(separator: "\n")
    }

    private static func wordsStyleXML(_ style: UserDefinedLanguageWordStyle) -> String {
        let attributes = orderedWordsStyleAttributes(style)
            .map { key, value in "\(key)=\"\(escapeXMLAttribute(value))\"" }
            .joined(separator: " ")
        return "<WordsStyle \(attributes) />"
    }

    private static func orderedWordsStyleAttributes(_ style: UserDefinedLanguageWordStyle) -> [(String, String)] {
        var attributes: [(String, String)] = [("name", style.name)]
        appendStyleAttribute("fgColor", style.fgColor, to: &attributes)
        appendStyleAttribute("bgColor", style.bgColor, to: &attributes)
        appendStyleAttribute("fontName", style.fontName, to: &attributes)
        appendStyleAttribute("fontStyle", style.fontStyle, to: &attributes)
        appendStyleAttribute("nesting", style.nesting, to: &attributes)

        for key in style.attributes.keys.sorted() {
            guard let value = style.attributes[key] else { continue }
            attributes.append((key, value))
        }
        return attributes
    }

    private static func appendStyleAttribute(
        _ key: String,
        _ value: String?,
        to attributes: inout [(String, String)]
    ) {
        guard let value else { return }
        attributes.append((key, value))
    }

    private static func escapeXMLAttribute(_ value: String) -> String {
        escapeXMLText(value)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func escapeXMLText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class UserDefinedLanguageXMLParser: NSObject, XMLParserDelegate {
    struct RawLanguage {
        let name: String
        let extensions: [String]
        let keywords: [String]
        let wordStyles: [UserDefinedLanguageWordStyle]
        let additionalKeywordLists: [String: String]
    }

    private(set) var language: RawLanguage?

    private var activeLanguageName: String?
    private var activeExtensions: [String] = []
    private var activeKeywords: [String] = []
    private var activeWordStyles: [UserDefinedLanguageWordStyle] = []
    private var activeAdditionalLists: [String: String] = [:]
    private var activeLanguageDepth: Int?
    private var activeKeywordDepth: Int?
    private var activeKeywordListName: String?
    private var activeStylesDepth: Int?
    private var activeKeywordText = ""
    private var depth = 0

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        depth += 1

        if activeLanguageDepth == nil, language == nil, elementName.isUserDefinedLanguageElement {
            activeLanguageName = attributeDict["name"]
            activeExtensions = [
                attributeDict["ext"],
                attributeDict["extensions"],
                attributeDict["extension"]
            ].compactMap { $0 }
                .joined(separator: " ")
                .splitExtensionList()
            activeKeywords = []
            activeWordStyles = []
            activeAdditionalLists = [:]
            activeLanguageDepth = depth
            return
        }

        guard activeLanguageDepth != nil else {
            return
        }

        if elementName == "Styles" {
            activeStylesDepth = depth
            return
        }

        if elementName == "WordsStyle", let style = parseWordStyle(attributes: attributeDict) {
            activeWordStyles.append(style)
            return
        }

        guard elementName == "Keywords", let listName = attributeDict["name"] else { return }
        activeKeywordDepth = depth
        activeKeywordListName = listName
        activeKeywordText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard activeKeywordDepth != nil else { return }
        activeKeywordText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer { depth -= 1 }

        if activeKeywordDepth == depth, elementName == "Keywords" {
            let listName = activeKeywordListName ?? "Keywords1"
            let text = activeKeywordText.trimmingCharacters(in: .whitespacesAndNewlines)
            if listName.isUserDefinedLanguageKeywordList1 {
                activeKeywords.append(contentsOf: activeKeywordText.splitKeywordList())
            } else if !text.isEmpty {
                // Store other keyword lists (Keywords2-8, Comments, Operators, etc.) as raw strings
                let existing = activeAdditionalLists[listName]
                activeAdditionalLists[listName] = existing.map { $0 + " " + text } ?? text
            }
            activeKeywordDepth = nil
            activeKeywordListName = nil
            activeKeywordText = ""
            return
        }

        if activeStylesDepth == depth, elementName == "Styles" {
            activeStylesDepth = nil
            return
        }

        guard activeLanguageDepth == depth, elementName.isUserDefinedLanguageElement else { return }
        if let name = activeLanguageName {
            language = RawLanguage(
                name: name,
                extensions: activeExtensions,
                keywords: activeKeywords,
                wordStyles: activeWordStyles,
                additionalKeywordLists: activeAdditionalLists
            )
        }
        activeLanguageName = nil
        activeExtensions = []
        activeKeywords = []
        activeWordStyles = []
        activeAdditionalLists = [:]
        activeLanguageDepth = nil
        activeStylesDepth = nil
    }

    private func parseWordStyle(attributes: [String: String]) -> UserDefinedLanguageWordStyle? {
        guard let name = attributes["name"] else { return nil }
        return UserDefinedLanguageWordStyle(
            name: name,
            fgColor: attributes["fgColor"],
            bgColor: attributes["bgColor"],
            fontName: attributes["fontName"],
            fontStyle: attributes["fontStyle"],
            nesting: attributes["nesting"],
            attributes: attributes
        )
    }
}

private extension String {
    var isUserDefinedLanguageElement: Bool {
        self == "UserLang" || self == "UserDefinedLanguage"
    }

    var isUserDefinedLanguageKeywordList: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("Keywords") else { return false }
        let suffix = normalized.dropFirst("Keywords".count)
        guard let index = Int(suffix) else { return false }
        return (1...8).contains(index)
    }

    var isUserDefinedLanguageKeywordList1: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines) == "Keywords1"
    }

    func splitExtensionList() -> [String] {
        split { character in
            character.isWhitespace || character == "," || character == ";"
        }
        .map(String.init)
        .filter { !$0.isEmpty }
    }

    func splitKeywordList() -> [String] {
        split { $0.isWhitespace }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
