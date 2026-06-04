import Foundation
import Testing
@testable import NotepadMacCore

@Test func userDefinedLanguageNormalizesExtensionsAndRejectsNamelessDefinitions() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "  MyUDL  ",
            displayName: "  My UDL  ",
            extensions: [".FOO", "Bar", " foo ", "", "."],
            keywords: ["alpha", " beta ", ""]
        )
    )

    #expect(language.name == "MyUDL")
    #expect(language.displayName == "My UDL")
    #expect(language.extensions == ["foo", "bar"])
    #expect(language.keywords == ["alpha", "beta"])
    #expect(UserDefinedLanguage(name: "  ", extensions: ["txt"], keywords: []) == nil)

    let extensionless = try #require(UserDefinedLanguage(name: "manual", extensions: ["", "."], keywords: []))
    #expect(extensionless.name == "manual")
    #expect(extensionless.extensions == [])
}

@Test func userDefinedLanguageStorePersistsRoundTrip() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let language = try #require(
        UserDefinedLanguage(
            name: "todo",
            displayName: "Todo Notes",
            extensions: [".todo", "TASK"],
            keywords: ["TODO", "DONE"]
        )
    )
    let store = UserDefinedLanguageStore(defaults: defaults)

    #expect(store.load() == [])
    store.save([language])
    #expect(store.load() == [language])

    store.clear()
    #expect(store.load() == [])
}

@Test func userDefinedLanguagePreservesWordStylesThroughCodableAndStore() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let wordStyle = UserDefinedLanguageWordStyle(
        name: "KEYWORDS1",
        fgColor: "112233",
        bgColor: "445566",
        fontName: "",
        fontStyle: "3",
        nesting: "1",
        attributes: [
            "alpha": "first",
            "colorStyle": "1"
        ]
    )
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            keywords: ["TODO"],
            wordStyles: [wordStyle]
        )
    )
    let encoded = try JSONEncoder().encode(language)
    let decoded = try JSONDecoder().decode(UserDefinedLanguage.self, from: encoded)
    let store = UserDefinedLanguageStore(defaults: defaults)

    #expect(decoded == language)
    store.save([language])
    #expect(store.load() == [language])
    #expect(store.load().first?.wordStyles == [wordStyle])
}

@Test func userDefinedLanguageWordStylesEditableTextRoundTripsKnownFields() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            keywords: ["TODO"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "DEFAULT",
                    fgColor: "000000",
                    bgColor: "FFFFFF",
                    fontName: "",
                    fontStyle: "0",
                    nesting: "0"
                ),
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "FF8800",
                    bgColor: "101010",
                    fontName: "Menlo Mono",
                    fontStyle: "3",
                    nesting: "1"
                )
            ]
        )
    )

    #expect(language.editableWordStylesText == """
    name=DEFAULT fgColor=000000 bgColor=FFFFFF fontName="" fontStyle=0 nesting=0
    name=KEYWORDS1 fgColor=FF8800 bgColor=101010 fontName="Menlo Mono" fontStyle=3 nesting=1
    """)

    let edited = try #require(
        language.updating(
            extensionsText: language.editableExtensionsText,
            keywordsText: language.editableKeywordsText,
            wordStylesText: language.editableWordStylesText
        )
    )

    #expect(edited.wordStyles == language.wordStyles)
}

@Test func userDefinedLanguageWordStylesEditableTextPreservesUnknownAttributes() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "AA5500",
                    bgColor: nil,
                    fontName: "Menlo \"Mono\"",
                    fontStyle: "1",
                    nesting: nil,
                    attributes: [
                        "alpha": "first value",
                        "zeta": "last\\value"
                    ]
                )
            ]
        )
    )

    #expect(language.editableWordStylesText == """
    name=KEYWORDS1 fgColor=AA5500 fontName="Menlo \\"Mono\\"" fontStyle=1 alpha="first value" zeta="last\\\\value"
    """)

    let edited = try #require(
        language.updating(
            extensionsText: language.editableExtensionsText,
            keywordsText: language.editableKeywordsText,
            wordStylesText: language.editableWordStylesText
        )
    )

    #expect(edited.wordStyles == language.wordStyles)
    #expect(edited.wordStyles.first?.attributes == [
        "alpha": "first value",
        "zeta": "last\\value"
    ])
}

@Test func userDefinedLanguageKeywordForegroundHelperAddsKeywords1Style() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"]
        )
    )

    let edited = language.updatingKeywordForeground("336699")

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(name: "KEYWORDS1", fgColor: "336699")
    ])
}

@Test func userDefinedLanguageKeywordForegroundHelperPreservesUnknownAttributesWhenUpdating() throws {
    let keywordStyle = UserDefinedLanguageWordStyle(
        name: "KEYWORDS1",
        fgColor: "112233",
        bgColor: "445566",
        fontName: "Menlo",
        fontStyle: "3",
        nesting: "1",
        attributes: [
            "alpha": "first",
            "colorStyle": "1"
        ]
    )
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "000000"),
                keywordStyle
            ]
        )
    )

    let edited = language.updatingKeywordForeground("AABBCC")

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "000000"),
        UserDefinedLanguageWordStyle(
            name: "KEYWORDS1",
            fgColor: "AABBCC",
            bgColor: "445566",
            fontName: "Menlo",
            fontStyle: "3",
            nesting: "1",
            attributes: [
                "alpha": "first",
                "colorStyle": "1"
            ]
        )
    ])
}

@Test func userDefinedLanguageWordStyleHelperUpdatesExistingStyleAndPreservesUnknownAttributes() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "112233",
                    bgColor: "445566",
                    fontName: "Menlo",
                    fontStyle: "3",
                    nesting: "1",
                    attributes: [
                        "alpha": "first",
                        "colorStyle": "1"
                    ]
                )
            ]
        )
    )

    let edited = language.updatingWordStyle(
        named: "KEYWORDS1",
        fgColor: .value("AABBCC"),
        bgColor: .value("101010"),
        fontName: .value("SF Mono"),
        fontStyle: .value("2"),
        nesting: .value("0")
    )

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(
            name: "KEYWORDS1",
            fgColor: "AABBCC",
            bgColor: "101010",
            fontName: "SF Mono",
            fontStyle: "2",
            nesting: "0",
            attributes: [
                "alpha": "first",
                "colorStyle": "1"
            ]
        )
    ])
}

@Test func userDefinedLanguageWordStyleHelperAddsMissingStyle() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "000000")
            ]
        )
    )

    let edited = language.updatingWordStyle(
        named: "STRINGS",
        fgColor: .value("AA5500"),
        bgColor: .value("101010"),
        fontName: .value("Menlo"),
        fontStyle: .value("1"),
        nesting: .value("0")
    )

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "000000"),
        UserDefinedLanguageWordStyle(
            name: "STRINGS",
            fgColor: "AA5500",
            bgColor: "101010",
            fontName: "Menlo",
            fontStyle: "1",
            nesting: "0"
        )
    ])
}

@Test func userDefinedLanguageWordStyleHelperPreservesUnspecifiedFieldsAndOnlyClearsExplicitNil() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "112233",
                    bgColor: "445566",
                    fontName: "Menlo",
                    fontStyle: "3",
                    nesting: "1"
                )
            ]
        )
    )

    let edited = language.updatingWordStyle(
        named: "KEYWORDS1",
        bgColor: .value(nil),
        fontStyle: .value("2")
    )

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(
            name: "KEYWORDS1",
            fgColor: "112233",
            bgColor: nil,
            fontName: "Menlo",
            fontStyle: "2",
            nesting: "1"
        )
    ])
}

@Test func userDefinedLanguageStructuredWordStyleUpdatesMultipleExistingStylesAndPreserveUnknownAttributes() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "DEFAULT",
                    fgColor: "111111",
                    bgColor: "FFFFFF",
                    fontName: "",
                    fontStyle: "0",
                    attributes: ["styleID": "0"]
                ),
                UserDefinedLanguageWordStyle(
                    name: "COMMENTS",
                    fgColor: "008000",
                    bgColor: "FFFFFF",
                    fontStyle: "0",
                    attributes: ["legacy": "comment"]
                ),
                UserDefinedLanguageWordStyle(
                    name: "NUMBER",
                    fgColor: "FF8000",
                    attributes: ["styleID": "3"]
                ),
                UserDefinedLanguageWordStyle(
                    name: "OPERATOR",
                    fgColor: "000080",
                    fontStyle: "1"
                ),
                UserDefinedLanguageWordStyle(
                    name: "FOLDEROPEN",
                    fgColor: "AA0000",
                    attributes: ["fold": "open"]
                ),
                UserDefinedLanguageWordStyle(
                    name: "FOLDERCLOSE",
                    fgColor: "00AA00",
                    attributes: ["fold": "close"]
                ),
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "0000FF",
                    attributes: ["keywordClass": "substyle1"]
                )
            ]
        )
    )

    let edited = language.applyingStructuredWordStyleUpdates([
        UserDefinedLanguageWordStyleStructuredUpdate(name: "DEFAULT", fgColor: "222222", bgColor: "EFEFEF"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "COMMENTS", fgColor: "228833", fontStyle: "2"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "NUMBER", fgColor: "CC6600"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "OPERATOR", fgColor: "003366", fontStyle: nil),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "FOLDEROPEN", fgColor: "660000", nesting: "1"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "FOLDERCLOSE", fgColor: "006600", nesting: "0"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "KEYWORDS1", fgColor: "5533AA", fontStyle: "1")
    ])

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(
            name: "DEFAULT",
            fgColor: "222222",
            bgColor: "EFEFEF",
            fontName: nil,
            fontStyle: nil,
            attributes: ["styleID": "0"]
        ),
        UserDefinedLanguageWordStyle(
            name: "COMMENTS",
            fgColor: "228833",
            bgColor: nil,
            fontStyle: "2",
            attributes: ["legacy": "comment"]
        ),
        UserDefinedLanguageWordStyle(
            name: "NUMBER",
            fgColor: "CC6600",
            attributes: ["styleID": "3"]
        ),
        UserDefinedLanguageWordStyle(name: "OPERATOR", fgColor: "003366"),
        UserDefinedLanguageWordStyle(
            name: "FOLDEROPEN",
            fgColor: "660000",
            nesting: "1",
            attributes: ["fold": "open"]
        ),
        UserDefinedLanguageWordStyle(
            name: "FOLDERCLOSE",
            fgColor: "006600",
            nesting: "0",
            attributes: ["fold": "close"]
        ),
        UserDefinedLanguageWordStyle(
            name: "KEYWORDS1",
            fgColor: "5533AA",
            fontStyle: "1",
            attributes: ["keywordClass": "substyle1"]
        )
    ])
}

@Test func userDefinedLanguageStructuredWordStyleUpdatesSkipBlankMissingStyles() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "111111")
            ]
        )
    )

    let edited = language.applyingStructuredWordStyleUpdates([
        UserDefinedLanguageWordStyleStructuredUpdate(name: "COMMENTS"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "NUMBER", fgColor: "CC6600")
    ])

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "111111"),
        UserDefinedLanguageWordStyle(name: "NUMBER", fgColor: "CC6600")
    ])
}

@Test func userDefinedLanguageKeywordForegroundHelperClearsColorAndPreservesOtherFields() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "112233",
                    bgColor: "445566",
                    fontName: "Menlo",
                    fontStyle: "3",
                    nesting: "1",
                    attributes: [
                        "alpha": "first"
                    ]
                )
            ]
        )
    )

    let edited = language.updatingKeywordForeground(nil)

    #expect(edited.wordStyles == [
        UserDefinedLanguageWordStyle(
            name: "KEYWORDS1",
            fgColor: nil,
            bgColor: "445566",
            fontName: "Menlo",
            fontStyle: "3",
            nesting: "1",
            attributes: [
                "alpha": "first"
            ]
        )
    ])
}

@Test func userDefinedLanguageWordStylesEditableTextCanClearOrRejectInvalidStyles() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "styled",
            extensions: ["styled"],
            keywords: ["TODO"],
            wordStyles: [
                UserDefinedLanguageWordStyle(name: "KEYWORDS1", fgColor: "AA5500")
            ]
        )
    )

    let cleared = try #require(
        language.updating(
            extensionsText: language.editableExtensionsText,
            keywordsText: language.editableKeywordsText,
            wordStylesText: " \n\t "
        )
    )

    #expect(cleared.wordStyles == [])
    #expect(
        language.updating(
            extensionsText: language.editableExtensionsText,
            keywordsText: language.editableKeywordsText,
            wordStylesText: "fgColor=AA5500"
        ) == nil
    )
}

@Test func userDefinedLanguageEditingNormalizesExtensionsAndKeywords() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "todo",
            displayName: "Todo Notes",
            extensions: [".todo"],
            keywords: ["TODO"]
        )
    )

    let edited = try #require(
        language.updating(
            extensionsText: ".TXT, TODO ; notes\n.txt",
            keywordsText: "alpha beta\nalpha  gamma"
        )
    )

    #expect(edited.name == "todo")
    #expect(edited.displayName == "Todo Notes")
    #expect(edited.extensions == ["txt", "todo", "notes"])
    #expect(edited.keywords == ["alpha", "beta", "gamma"])
    #expect(edited.wordStyles == language.wordStyles)

    let cleared = try #require(
        language.updating(
            extensionsText: "",
            keywordsText: ""
        )
    )

    #expect(cleared.displayName == "Todo Notes")
    #expect(cleared.extensions == [])
    #expect(cleared.keywords == [])
}

@Test func languageCatalogFindsMergedUserDefinedLanguageByNameAndExtension() throws {
    let userLanguage = try #require(
        UserDefinedLanguage(
            name: "todo",
            displayName: "Todo Notes",
            extensions: [".todo"],
            keywords: ["TODO", "DONE"]
        )
    )
    let catalog = LanguageCatalog.fallback.appendingUserDefinedLanguages([userLanguage])

    #expect(catalog.language(named: "todo")?.displayName == "Todo Notes")
    #expect(catalog.language(for: ".TODO")?.name == "todo")
    #expect(catalog.detect(url: URL(filePath: "/tmp/work.todo")).name == "todo")
}

@Test func languageDefinitionCarriesUserDefinedKeywordWordStyleColor() throws {
    let userLanguage = try #require(
        UserDefinedLanguage(
            name: "todo",
            displayName: "Todo Notes",
            extensions: [".todo"],
            keywords: ["TODO", "DONE"],
            wordStyles: [
                UserDefinedLanguageWordStyle(name: "DEFAULT", fgColor: "101010"),
                UserDefinedLanguageWordStyle(name: "KEYWORDS1", fgColor: "AA5500")
            ]
        )
    )
    let catalog = LanguageCatalog.fallback.appendingUserDefinedLanguages([userLanguage])
    let language = try #require(catalog.language(named: "todo"))

    #expect(language.keywordGroups == ["udlkw1": ["TODO", "DONE"]])
    #expect(language.wordStyle(named: "KEYWORDS1")?.foreground == StyleColor(hexRGB: "AA5500"))
    #expect(language.userDefinedKeywordForeground == StyleColor(hexRGB: "AA5500"))
}

@Test func languageDefinitionKeywordWordStyleColorFallsBackToKeywordsAndIgnoresInvalidColors() throws {
    let keywordsStyle = LanguageDefinition(
        name: "keywords",
        keywordGroups: ["instre1": ["TODO"]],
        wordStyles: [
            LanguageWordStyle(name: "KEYWORDS", foreground: StyleColor(hexRGB: "336699"))
        ]
    )
    let invalidKeywordsOneStyle = LanguageDefinition(
        name: "invalid",
        keywordGroups: ["instre1": ["TODO"]],
        wordStyles: [
            LanguageWordStyle(name: "KEYWORDS1", foreground: nil),
            LanguageWordStyle(name: "KEYWORDS", foreground: StyleColor(hexRGB: "336699"))
        ]
    )

    #expect(keywordsStyle.userDefinedKeywordForeground == StyleColor(hexRGB: "336699"))
    #expect(invalidKeywordsOneStyle.userDefinedKeywordForeground == StyleColor(hexRGB: "336699"))
    #expect(LanguageWordStyle(name: "KEYWORDS1", foregroundHexRGB: "XYZ123")?.foreground == nil)
    #expect(LanguageWordStyle(name: "KEYWORDS1", foregroundHexRGB: "12345")?.foreground == nil)
}

@Test func languageCatalogAllowsUserDefinedLanguageToOverrideBuiltInNameAndExtension() throws {
    let userLanguage = try #require(
        UserDefinedLanguage(
            name: "rust",
            displayName: "Custom Rust",
            extensions: [".rs", ".udlrs"],
            keywords: ["customKeyword"]
        )
    )
    let catalog = LanguageCatalog.fallback.appendingUserDefinedLanguages([userLanguage])

    #expect(catalog.language(named: "rust")?.displayName == "Custom Rust")
    #expect(catalog.language(for: "RS")?.displayName == "Custom Rust")
    #expect(catalog.language(for: ".udlrs")?.name == "rust")
}

@Test func languageCatalogDeduplicatesUserDefinedLanguageNamesCaseInsensitively() throws {
    let userLanguage = try #require(
        UserDefinedLanguage(
            name: "Rust",
            displayName: "Case Custom Rust",
            extensions: [".rs"],
            keywords: ["caseOnly"]
        )
    )
    let catalog = LanguageCatalog.fallback.appendingUserDefinedLanguages([userLanguage])

    #expect(catalog.languages.filter { $0.name.localizedCaseInsensitiveCompare("rust") == .orderedSame }.count == 1)
    #expect(catalog.language(named: "rust")?.displayName == "Case Custom Rust")
    #expect(catalog.language(named: "RUST")?.displayName == "Case Custom Rust")
    #expect(catalog.language(for: ".rs")?.displayName == "Case Custom Rust")
}
