import Foundation

struct AppLocalizationOption: Equatable, Sendable {
    let displayName: String
    let fileName: String
}

enum AppLocalizationCatalog {
    static func loadBundledOptions(bundle: Bundle = Localization.resourceBundle) -> [AppLocalizationOption] {
        let fileManager = FileManager.default
        let xmlURLs = (try? fileManager.contentsOfDirectory(
            at: bundle.resourceURL ?? bundle.bundleURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension.lowercased() == "xml" } ?? []

        let parsedOptions = xmlURLs.compactMap(loadOption)
        let optionsByFileName = Dictionary(uniqueKeysWithValues: parsedOptions.map { ($0.fileName.lowercased(), $0) })
        let order = preferredOrder(bundle: bundle)

        var orderedOptions: [AppLocalizationOption] = []
        var consumed = Set<String>()

        for fileName in order {
            let lowercasedFileName = fileName.lowercased()
            if let option = optionsByFileName[lowercasedFileName] {
                orderedOptions.append(option)
                consumed.insert(lowercasedFileName)
            }
        }

        let remaining = parsedOptions
            .filter { !consumed.contains($0.fileName.lowercased()) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        return orderedOptions + remaining
    }

    private static func preferredOrder(bundle: Bundle) -> [String] {
        guard let orderURL = bundle.url(forResource: "localization-order", withExtension: "txt"),
              let text = try? String(contentsOf: orderURL, encoding: .utf8)
        else {
            return []
        }

        return text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func loadOption(from xmlURL: URL) -> AppLocalizationOption? {
        guard let metadata = NativeLangMetadataParser.parse(xmlURL) else { return nil }
        return AppLocalizationOption(displayName: metadata.name, fileName: metadata.fileName)
    }
}

private struct NativeLangMetadata: Equatable, Sendable {
    let name: String
    let fileName: String
}

private final class NativeLangMetadataParser: NSObject, XMLParserDelegate {
    private var metadata: NativeLangMetadata?

    static func parse(_ url: URL) -> NativeLangMetadata? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = NativeLangMetadataParser()
        parser.delegate = delegate
        return parser.parse() ? delegate.metadata : delegate.metadata
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard metadata == nil, elementName == "Native-Langue" else { return }
        guard let name = attributeDict["name"], let fileName = attributeDict["filename"] else { return }
        metadata = NativeLangMetadata(name: name, fileName: fileName)
        parser.abortParsing()
    }
}
