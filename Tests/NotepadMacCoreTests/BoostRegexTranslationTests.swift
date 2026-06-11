import Foundation
import Testing
@testable import NotepadMacCore

// MARK: - Pattern translation

@Test func boostRegexTranslatesWordStartAndEndBoundaries() throws {
    let text = "cat category concat cat."
    let options = TextSearch.Options(matchCase: true, searchMode: .regex)

    let matches = TextSearch.findAll("\\<cat\\>", in: text, options: options)

    let nsText = text as NSString
    #expect(matches.map { nsText.substring(with: $0) } == ["cat", "cat"])
}

@Test func boostRegexKeepsEscapedAngleBracketsLiteralInsideCharacterClass() throws {
    let translated = try BoostRegexTranslation.icuPattern(fromBoostPattern: "[\\<\\>]+")
    #expect(translated == "[\\<\\>]+")

    let matches = TextSearch.findAll("[\\<\\>]+", in: "a <b> c", options: .init(searchMode: .regex))
    #expect(matches.count == 2)
}

@Test func boostRegexSupportsPosixCharacterClassesAndAnyNewline() throws {
    // POSIX class
    let digits = TextSearch.findAll("[[:digit:]]+", in: "a1 b22 c333", options: .init(searchMode: .regex))
    #expect(digits.count == 3)

    // \R matches any line ending in both engines
    let lf = TextSearch.findAll("a\\Rb", in: "a\nb", options: .init(searchMode: .regex))
    let crlf = TextSearch.findAll("a\\Rb", in: "a\r\nb", options: .init(searchMode: .regex))
    #expect(lf.count == 1)
    #expect(crlf.count == 1)
}

@Test func boostRegexTranslationLayerStillFlagsICUOnlyGaps() {
    // The ICU translation layer (kept for the NSTextView fallback
    // documentation) still reports these constructs as untranslatable.
    let untranslatable = ["a\\Kb", "(?R)", "(?0)", "(?(1)a|b)", "(?>ab)", "(?&name)", "\\g{1}"]
    for pattern in untranslatable {
        #expect(BoostRegexTranslation.patternProblem(pattern) != nil, "\(pattern) should be flagged by the ICU layer")
    }

    // Control: a vanilla pattern reports no problem anywhere.
    #expect(BoostRegexTranslation.patternProblem("(\\w+)-\\d{2,}") == nil)
    #expect(TextSearch.regexPatternProblem("(\\w+)") == nil)
    // The Boost engine now reports problems straight from boost::regex.
    #expect(TextSearch.regexPatternProblem("(\\w+") != nil)
}

// MARK: - Boost engine: upstream-only constructs now supported

@Test func boostEngineSupportsMatchResetK() {
    let matches = TextSearch.findAll("a\\Kb", in: "ab ab", options: .init(matchCase: true, searchMode: .regex))
    #expect(matches == [NSRange(location: 1, length: 1), NSRange(location: 4, length: 1)])
}

@Test func boostEngineSupportsAtomicGroups() {
    let matches = TextSearch.findAll("(?>ab)", in: "ab", options: .init(matchCase: true, searchMode: .regex))
    #expect(matches == [NSRange(location: 0, length: 2)])
}

@Test func boostEngineSupportsConditionalGroups() {
    let matches = TextSearch.findAll(
        "(a)?(?(1)b|c)", in: "ab c", options: .init(matchCase: true, searchMode: .regex))
    let text = "ab c" as NSString
    #expect(matches.map { text.substring(with: $0) } == ["ab", "c"])
}

@Test func boostEngineSupportsRecursion() {
    // Balanced parentheses via full-pattern recursion.
    let matches = TextSearch.findAll(
        "\\((?:[^()]|(?R))*\\)", in: "x (a(b)) y", options: .init(matchCase: true, searchMode: .regex))
    let text = "x (a(b)) y" as NSString
    #expect(matches.map { text.substring(with: $0) } == ["(a(b))"])
}

@Test func boostEngineSupportsNamedRecursion() {
    let matches = TextSearch.findAll(
        "(?<paren>\\((?:[^()]|(?&paren))*\\))", in: "(a(b)c)", options: .init(matchCase: true, searchMode: .regex))
    #expect(matches == [NSRange(location: 0, length: 7)])
}

@Test func boostEngineSupportsGBackreferences() {
    let matches = TextSearch.findAll("(a)\\g{1}", in: "aa ba", options: .init(matchCase: true, searchMode: .regex))
    #expect(matches == [NSRange(location: 0, length: 2)])
}

@Test func boostEngineFormatsCaseConversionOperators() {
    // \u, \l, \U...\E are boost format_all-only operators.
    let upper = TextSearch.replaceAll(
        "(\\w+)", with: "\\U$1\\E", in: "abc def",
        options: .init(matchCase: true, searchMode: .regex))
    #expect(upper.text == "ABC DEF")

    let firstUpper = TextSearch.replaceAll(
        "(\\w+)", with: "\\u$1", in: "abc def",
        options: .init(matchCase: true, searchMode: .regex))
    #expect(firstUpper.text == "Abc Def")
}

@Test func boostEngineFormatsConditionalReplacement() {
    // ?Ntrue:false conditional format syntax (format_all).
    let result = TextSearch.replaceAll(
        "(a)|(b)", with: "(?1A:B)", in: "ab",
        options: .init(matchCase: true, searchMode: .regex))
    #expect(result.text == "AB")
}

// MARK: - Replacement template translation

@Test func boostRegexReplacementSupportsBackslashBackreferences() {
    let result = TextSearch.replaceAll(
        "(\\w+)-(\\w+)",
        with: "\\2-\\1",
        in: "alpha-bravo charlie-delta",
        options: .init(searchMode: .regex)
    )
    #expect(result.text == "bravo-alpha delta-charlie")
    #expect(result.count == 2)
}

@Test func boostRegexReplacementSupportsDollarAmpersandAndBracedGroups() {
    let wholeMatch = TextSearch.replaceAll(
        "\\d+",
        with: "[$&]",
        in: "a1 b22",
        options: .init(searchMode: .regex)
    )
    #expect(wholeMatch.text == "a[1] b[22]")

    let braced = TextSearch.replaceAll(
        "(\\w)(\\w)",
        with: "${2}${1}",
        in: "ab",
        options: .init(searchMode: .regex)
    )
    #expect(braced.text == "ba")
}

@Test func boostRegexReplacementExpandsEscapesAndKeepsLiteralDollars() {
    let newline = TextSearch.replaceAll(
        ", ",
        with: ",\\n",
        in: "one, two",
        options: .init(searchMode: .regex)
    )
    #expect(newline.text == "one,\ntwo")

    let literalDollar = TextSearch.replaceAll(
        "price",
        with: "$ cost",
        in: "price: 5",
        options: .init(searchMode: .regex)
    )
    #expect(literalDollar.text == "$ cost: 5")
}

@Test func boostRegexReplaceNextSubstitutesCaptureGroups() {
    let result = TextSearch.replaceNext(
        "(\\w+)@(\\w+)",
        with: "\\2 at \\1",
        in: "mail me: user@example now",
        from: NSRange(location: 0, length: 0),
        options: .init(searchMode: .regex)
    )

    #expect(result?.text == "mail me: example at user now")
    #expect(result?.replacedRange == NSRange(location: 9, length: "example at user".utf16.count))
}

@Test func boostRegexReplacementTemplateTranslationTable() {
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "\\1\\2") == "$1$2")
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "$&") == "$0")
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "${12}") == "$12")
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "a\\tb") == "a\tb")
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "100$") == "100\\$")
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "\\\\n") == "\\\\n")
    #expect(BoostRegexTranslation.icuTemplate(fromBoostReplacement: "$1") == "$1")
}
