import Foundation
import Testing
@testable import NotepadMacCore

@Test func userDefinedLanguageIOImportsAndNormalizesExtensions() throws {
    let xml = """
    <UserLang name="  DemoLang  " ext=".FOO Bar foo">
        <KeywordLists />
    </UserLang>
    """

    let language = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(language.name == "DemoLang")
    #expect(language.extensions == ["foo", "bar"])
    #expect(language.keywords == [])
}

@Test func userDefinedLanguageIOImportsExtensionsAttributeAndKeywords() throws {
    let xml = """
    <UserDefinedLanguage name="Task Notes" extensions=".todo, task; NOTE">
        <KeywordLists>
            <Keywords name="Comments">not imported</Keywords>
            <Keywords name="Keywords1">TODO DONE WAITING</Keywords>
            <Keywords name="Keywords2">
                owner priority TODO
            </Keywords>
            <Keywords name="Operators1">+ -</Keywords>
        </KeywordLists>
    </UserDefinedLanguage>
    """

    let language = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(language.name == "Task Notes")
    #expect(language.extensions == ["todo", "task", "note"])
    #expect(language.keywords == ["TODO", "DONE", "WAITING", "owner", "priority"])
}

@Test func userDefinedLanguageIOImportsWordsStylesWithKnownAndUnknownAttributes() throws {
    let xml = """
    <UserLang name="Styled Notes" ext=".styled">
        <KeywordLists>
            <Keywords name="Keywords1">TODO DONE</Keywords>
        </KeywordLists>
        <Styles>
            <WordsStyle name="DEFAULT" fgColor="111111" bgColor="FFFFFF" fontName="" fontStyle="0" nesting="0" colorStyle="1" />
            <WordsStyle name="KEYWORDS1" fgColor="AA5500" bgColor="002244" fontName="Menlo" fontStyle="3" nesting="1" zeta="last" alpha="first" />
        </Styles>
    </UserLang>
    """

    let language = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(language.name == "Styled Notes")
    #expect(language.extensions == ["styled"])
    #expect(language.keywords == ["TODO", "DONE"])
    #expect(language.wordStyles == [
        UserDefinedLanguageWordStyle(
            name: "DEFAULT",
            fgColor: "111111",
            bgColor: "FFFFFF",
            fontName: "",
            fontStyle: "0",
            nesting: "0",
            attributes: ["colorStyle": "1"]
        ),
        UserDefinedLanguageWordStyle(
            name: "KEYWORDS1",
            fgColor: "AA5500",
            bgColor: "002244",
            fontName: "Menlo",
            fontStyle: "3",
            nesting: "1",
            attributes: [
                "alpha": "first",
                "zeta": "last"
            ]
        )
    ])
}

@Test func userDefinedLanguageIOImportsExtensionlessUserDefinedLanguages() throws {
    let xml = """
    <UserLang name="Manual Only" ext="">
        <KeywordLists>
            <Keywords name="Keywords1">BEGIN END</Keywords>
        </KeywordLists>
    </UserLang>
    """

    let language = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(language.name == "Manual Only")
    #expect(language.extensions == [])
    #expect(language.keywords == ["BEGIN", "END"])
}

@Test func userDefinedLanguageIOExportsEscapedStableXML() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "A&B \"Lang\"",
            extensions: [".one", "two&"],
            keywords: ["if", "x<y", "\"quoted\""]
        )
    )

    let xml = UserDefinedLanguageIO.exportLanguage(language)

    #expect(xml == """
    <UserLang name="A&amp;B &quot;Lang&quot;" ext="one two&amp;">
        <KeywordLists>
            <Keywords name="Keywords1">if x&lt;y &quot;quoted&quot;</Keywords>
        </KeywordLists>
    </UserLang>
    """)
}

@Test func userDefinedLanguageIOExportsEscapedStableWordsStyleXML() throws {
    let language = try #require(
        UserDefinedLanguage(
            name: "Styled & Lang",
            extensions: [".styled"],
            keywords: ["TODO"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "AABBCC",
                    bgColor: "001122",
                    fontName: "Menlo \"Mono\"",
                    fontStyle: "3",
                    nesting: "1",
                    attributes: [
                        "alpha": "A&B",
                        "zeta": "Z<Z"
                    ]
                )
            ]
        )
    )

    let xml = UserDefinedLanguageIO.exportLanguage(language)

    #expect(xml == """
    <UserLang name="Styled &amp; Lang" ext="styled">
        <KeywordLists>
            <Keywords name="Keywords1">TODO</Keywords>
        </KeywordLists>
        <Styles>
            <WordsStyle name="KEYWORDS1" fgColor="AABBCC" bgColor="001122" fontName="Menlo &quot;Mono&quot;" fontStyle="3" nesting="1" alpha="A&amp;B" zeta="Z&lt;Z" />
        </Styles>
    </UserLang>
    """)
}

@Test func userDefinedLanguageIORejectsInvalidXML() throws {
    #expect(throws: UserDefinedLanguageIO.Error.invalidXML) {
        try UserDefinedLanguageIO.importLanguage(from: "<UserLang name=\"Broken\" ext=\"txt\">")
    }
}

@Test func userDefinedLanguageIORejectsInvalidUserDefinedLanguage() throws {
    #expect(throws: UserDefinedLanguageIO.Error.invalidUserDefinedLanguage) {
        try UserDefinedLanguageIO.importLanguage(from: "<UserLang name=\"   \" ext=\"txt\"/>")
    }
}

@Test func userDefinedLanguageIOExportImportRoundTrips() throws {
    let original = try #require(
        UserDefinedLanguage(
            name: "TodoScript",
            extensions: [".todo", "TASK"],
            keywords: ["TODO", "DONE", "WAITING"]
        )
    )

    let xml = UserDefinedLanguageIO.exportLanguage(original)
    let imported = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(imported == original)
}

@Test func userDefinedLanguageIOExportImportRoundTripsEditedLanguageContent() throws {
    let original = try #require(
        UserDefinedLanguage(
            name: "TodoScript",
            extensions: [".todo"],
            keywords: ["TODO"]
        )
    )
    let edited = try #require(
        original.updating(
            extensionsText: ".task, note\ntodo",
            keywordsText: "TODO WAITING\nDONE"
        )
    )

    let xml = UserDefinedLanguageIO.exportLanguage(edited)
    let imported = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(imported == edited)
}

@Test func userDefinedLanguageIOExportImportRoundTripsWordsStyles() throws {
    let original = try #require(
        UserDefinedLanguage(
            name: "TodoScript",
            extensions: [".todo", "TASK"],
            keywords: ["TODO", "DONE", "WAITING"],
            wordStyles: [
                UserDefinedLanguageWordStyle(
                    name: "DEFAULT",
                    fgColor: "000000",
                    bgColor: "FFFFFF",
                    fontName: "",
                    fontStyle: "0",
                    nesting: "0",
                    attributes: [
                        "alpha": "first",
                        "colorStyle": "1"
                    ]
                ),
                UserDefinedLanguageWordStyle(
                    name: "KEYWORDS1",
                    fgColor: "FF8800",
                    bgColor: "101010",
                    fontName: "Menlo",
                    fontStyle: "1",
                    nesting: "2",
                    attributes: ["zeta": "last"]
                )
            ]
        )
    )

    let xml = UserDefinedLanguageIO.exportLanguage(original)
    let imported = try UserDefinedLanguageIO.importLanguage(from: xml)

    #expect(imported == original)
}

@Test func userDefinedLanguageIORoundTripsAfterStructuredStyleUpdatesPreservingRawAttributes() throws {
    let xml = """
    <UserLang name="Styled Notes" ext=".styled">
        <KeywordLists>
            <Keywords name="Keywords1">TODO DONE</Keywords>
        </KeywordLists>
        <Styles>
            <WordsStyle name="DEFAULT" styleID="0" fgColor="111111" bgColor="FFFFFF" fontName="" fontStyle="0" fontSize="" />
            <WordsStyle name="COMMENTS" fgColor="008000" bgColor="FFFFFF" fontStyle="0" colorStyle="1" />
            <WordsStyle name="NUMBER" styleID="3" fgColor="FF8000" bgColor="FFFFFF" />
            <WordsStyle name="OPERATOR" fgColor="000080" fontStyle="1" custom="kept" />
            <WordsStyle name="FOLDEROPEN" fgColor="AA0000" fold="open" />
            <WordsStyle name="FOLDERCLOSE" fgColor="00AA00" fold="close" />
        </Styles>
    </UserLang>
    """
    let imported = try UserDefinedLanguageIO.importLanguage(from: xml)

    let edited = imported.applyingStructuredWordStyleUpdates([
        UserDefinedLanguageWordStyleStructuredUpdate(name: "DEFAULT", fgColor: "222222", bgColor: "EEEEEE"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "COMMENTS", fgColor: "229944", fontStyle: "2"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "NUMBER", fgColor: "CC6600"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "OPERATOR", fgColor: "003366", fontStyle: nil),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "FOLDEROPEN", fgColor: "660000", nesting: "1"),
        UserDefinedLanguageWordStyleStructuredUpdate(name: "FOLDERCLOSE", fgColor: "006600", nesting: "0")
    ])
    let exported = UserDefinedLanguageIO.exportLanguage(edited)
    let roundTripped = try UserDefinedLanguageIO.importLanguage(from: exported)

    #expect(roundTripped == edited)
    #expect(roundTripped.wordStyle(named: "DEFAULT")?.attributes == [
        "fontSize": "",
        "styleID": "0"
    ])
    #expect(roundTripped.wordStyle(named: "COMMENTS")?.attributes == ["colorStyle": "1"])
    #expect(roundTripped.wordStyle(named: "OPERATOR")?.attributes == ["custom": "kept"])
    #expect(roundTripped.wordStyle(named: "FOLDEROPEN")?.attributes == ["fold": "open"])
    #expect(roundTripped.wordStyle(named: "FOLDERCLOSE")?.attributes == ["fold": "close"])
}
