import Foundation

public struct StyleColor: Codable, Equatable, Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hexRGB: String?) {
        guard let hexRGB, hexRGB.count == 6, let value = UInt32(hexRGB, radix: 16) else {
            return nil
        }

        self.red = UInt8((value >> 16) & 0xFF)
        self.green = UInt8((value >> 8) & 0xFF)
        self.blue = UInt8(value & 0xFF)
    }

    public var hexRGB: String {
        String(format: "%02X%02X%02X", red, green, blue)
    }

    public var scintillaColor: Int32 {
        Int32(red) | (Int32(green) << 8) | (Int32(blue) << 16)
    }
}

public struct LexerStyle: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let styleID: Int
    public let foreground: StyleColor?
    public let background: StyleColor?
    public let fontName: String?
    public let fontSize: Int?
    public let fontStyle: Int
    public let keywordClass: String?

    public var id: Int { styleID }
    public var isBold: Bool { (fontStyle & 1) != 0 }
    public var isItalic: Bool { (fontStyle & 2) != 0 }

    public init(
        name: String,
        styleID: Int,
        foreground: StyleColor? = nil,
        background: StyleColor? = nil,
        fontName: String? = nil,
        fontSize: Int? = nil,
        fontStyle: Int = 0,
        keywordClass: String? = nil
    ) {
        self.name = name
        self.styleID = styleID
        self.foreground = foreground
        self.background = background
        self.fontName = fontName?.nilIfEmpty
        self.fontSize = fontSize
        self.fontStyle = fontStyle
        self.keywordClass = keywordClass?.nilIfEmpty
    }

    public func applying(_ override: StyleOverride?) -> LexerStyle {
        guard let override else { return self }
        return LexerStyle(
            name: name,
            styleID: styleID,
            foreground: override.foreground ?? foreground,
            background: override.background ?? background,
            fontName: override.fontName ?? fontName,
            fontSize: override.fontSize ?? fontSize,
            fontStyle: override.fontStyle ?? fontStyle,
            keywordClass: keywordClass
        )
    }
}

public struct StyleLexer: Codable, Equatable, Identifiable, Sendable {
    public let name: String
    public let displayName: String
    public let styles: [LexerStyle]

    public var id: String { name }

    public init(name: String, displayName: String? = nil, styles: [LexerStyle]) {
        self.name = name
        self.displayName = displayName?.nilIfEmpty ?? name
        self.styles = styles
    }

    public func style(id styleID: Int) -> LexerStyle? {
        styles.first { $0.styleID == styleID }
    }
}

public struct StyleCatalog: Codable, Equatable, Sendable {
    public let lexers: [StyleLexer]
    public let globalStyles: [LexerStyle]

    private let lexersByName: [String: StyleLexer]
    private let globalStylesByName: [String: LexerStyle]

    public init(lexers: [StyleLexer], globalStyles: [LexerStyle] = []) {
        self.lexers = lexers
        self.globalStyles = globalStyles
        self.lexersByName = Dictionary(uniqueKeysWithValues: lexers.map { ($0.name, $0) })
        self.globalStylesByName = Dictionary(uniqueKeysWithValues: globalStyles.map { ($0.name, $0) })
    }

    private enum CodingKeys: String, CodingKey {
        case lexers
        case globalStyles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            lexers: try container.decode([StyleLexer].self, forKey: .lexers),
            globalStyles: try container.decode([LexerStyle].self, forKey: .globalStyles)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lexers, forKey: .lexers)
        try container.encode(globalStyles, forKey: .globalStyles)
    }

    public func lexer(named name: String) -> StyleLexer? {
        lexersByName[name]
    }

    public func globalStyle(named name: String) -> LexerStyle? {
        globalStylesByName[name]
    }

    public static func load(from url: URL) throws -> StyleCatalog {
        let parser = XMLParser(contentsOf: url)
        guard let parser else {
            throw StyleCatalogError.unreadableModel(url.path)
        }

        let delegate = StyleModelParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw StyleCatalogError.invalidModel(parser.parserError?.localizedDescription ?? "Unknown XML parser error")
        }

        return StyleCatalog(lexers: delegate.lexers, globalStyles: delegate.globalStyles)
    }

    public static func loadDefault() -> StyleCatalog {
        for url in defaultStyleModelCandidates() where FileManager.default.fileExists(atPath: url.path) {
            if let catalog = try? load(from: url) {
                return catalog
            }
        }
        return .empty
    }

    public static let empty = StyleCatalog(lexers: [])

    private static func defaultStyleModelCandidates() -> [URL] {
        let sourceURL = URL(filePath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appending(path: "stylers.model.xml"))
        }
        urls.append(projectRoot.appending(path: "notepad-plus-plus/PowerEditor/src/stylers.model.xml"))

        let cwd = URL(filePath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appending(path: "notepad-plus-plus/PowerEditor/src/stylers.model.xml"))
        urls.append(cwd.appending(path: "../notepad-plus-plus/PowerEditor/src/stylers.model.xml").standardizedFileURL)
        return urls
    }
}

public enum ScintillaStyleRouting {
    public static func isGlobalTextStyle(_ styleID: Int) -> Bool {
        globalTextStyleIDs.contains(styleID)
    }

    public static func isNotepadPlusIndicatorStyle(_ styleID: Int) -> Bool {
        (21...31).contains(styleID)
    }

    private static let globalTextStyleIDs: Set<Int> = [32, 33, 34, 35, 37]
}

public enum StyleCatalogError: Error, Equatable, Sendable {
    case unreadableModel(String)
    case invalidModel(String)
}

public struct StyleOverrideKey: Codable, Equatable, Hashable, Sendable {
    public let languageName: String
    public let styleID: Int

    public init(languageName: String, styleID: Int) {
        self.languageName = languageName
        self.styleID = styleID
    }
}

public struct StyleOverride: Codable, Equatable, Sendable {
    public let foreground: StyleColor?
    public let background: StyleColor?
    public let fontName: String?
    public let fontSize: Int?
    public let fontStyle: Int?

    public init(
        foreground: StyleColor? = nil,
        background: StyleColor? = nil,
        fontName: String? = nil,
        fontSize: Int? = nil,
        fontStyle: Int? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.fontName = fontName?.nilIfEmpty
        self.fontSize = fontSize
        self.fontStyle = fontStyle
    }
}

public struct StylePreferences: Codable, Equatable, Sendable {
    public static let empty = StylePreferences(overrides: [:])

    public let overrides: [StyleOverrideKey: StyleOverride]

    public init(overrides: [StyleOverrideKey: StyleOverride] = [:]) {
        self.overrides = overrides
    }

    public func override(for key: StyleOverrideKey) -> StyleOverride? {
        overrides[key]
    }

    public func resolvedStyle(for key: StyleOverrideKey, base: LexerStyle) -> LexerStyle {
        base.applying(overrides[key])
    }

    public func setting(_ override: StyleOverride, for key: StyleOverrideKey) -> StylePreferences {
        var next = overrides
        next[key] = override
        return StylePreferences(overrides: next)
    }

    public func removingOverride(for key: StyleOverrideKey) -> StylePreferences {
        var next = overrides
        next.removeValue(forKey: key)
        return StylePreferences(overrides: next)
    }
}

public final class StylePreferencesStore {
    private enum Key {
        static let data = "notepadMac.stylePreferences"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> StylePreferences {
        guard let data = defaults.data(forKey: Key.data),
              let preferences = try? decoder.decode(StylePreferences.self, from: data)
        else {
            return .empty
        }
        return preferences
    }

    public func save(_ preferences: StylePreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: Key.data)
        defaults.synchronize()
    }

    public func clear() {
        defaults.removeObject(forKey: Key.data)
        defaults.synchronize()
    }
}

private final class StyleModelParser: NSObject, XMLParserDelegate {
    private struct PendingLexer {
        let name: String
        let displayName: String?
        var styles: [LexerStyle] = []
    }

    private(set) var lexers: [StyleLexer] = []
    private(set) var globalStyles: [LexerStyle] = []
    private var currentLexer: PendingLexer?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "LexerType":
            guard let name = attributeDict["name"] else { return }
            currentLexer = PendingLexer(name: name, displayName: attributeDict["desc"])
        case "WordsStyle":
            guard let style = parseStyle(attributes: attributeDict) else { return }
            currentLexer?.styles.append(style)
        case "WidgetStyle":
            guard let style = parseStyle(attributes: attributeDict) else { return }
            globalStyles.append(style)
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
        guard elementName == "LexerType", let lexer = currentLexer else { return }
        lexers.append(StyleLexer(name: lexer.name, displayName: lexer.displayName, styles: lexer.styles))
        currentLexer = nil
    }

    private func parseStyle(attributes: [String: String]) -> LexerStyle? {
        guard let name = attributes["name"],
              let rawStyleID = attributes["styleID"],
              let styleID = Int(rawStyleID)
        else {
            return nil
        }

        return LexerStyle(
            name: name,
            styleID: styleID,
            foreground: StyleColor(hexRGB: attributes["fgColor"]),
            background: StyleColor(hexRGB: attributes["bgColor"]),
            fontName: attributes["fontName"]?.nilIfEmpty,
            fontSize: Int(attributes["fontSize"] ?? ""),
            fontStyle: Int(attributes["fontStyle"] ?? "") ?? 0,
            keywordClass: attributes["keywordClass"]?.nilIfEmpty
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
