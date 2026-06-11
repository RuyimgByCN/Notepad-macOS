import Foundation
import Testing
@testable import NotepadMacCore

@Test func textFileCodecDetectsUtf8ByteOrderMarkWithoutAddingMarkerCharacter() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-bom.txt")
    let bytes = Data([0xEF, 0xBB, 0xBF]) + Data("one\r\ntwo".utf8)
    try bytes.write(to: fileURL)

    let loaded = try TextFileCodec.read(fileURL)

    #expect(loaded.text == "one\r\ntwo")
    #expect(loaded.encoding == .utf8)
    #expect(loaded.hasByteOrderMark)
    #expect(loaded.lineEnding == .crlf)
}

@Test func textFileCodecCanWriteUtf8ByteOrderMarkWhenRequested() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-bom-write.txt")
    try TextFileCodec.write(
        "hello\n",
        to: fileURL,
        encoding: .utf8,
        lineEnding: .lf,
        includeByteOrderMark: true
    )

    let raw = try Data(contentsOf: fileURL)
    #expect(Array(raw.prefix(3)) == [0xEF, 0xBB, 0xBF])

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "hello\n")
    #expect(loaded.encoding == .utf8)
    #expect(loaded.hasByteOrderMark)
}

@Test func textFileCodecOmitsUtf8ByteOrderMarkByDefault() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-no-bom.txt")
    try TextFileCodec.write("hello\n", to: fileURL, encoding: .utf8, lineEnding: .lf)

    let raw = try Data(contentsOf: fileURL)
    #expect(!raw.starts(with: [0xEF, 0xBB, 0xBF]))

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "hello\n")
    #expect(loaded.encoding == .utf8)
    #expect(!loaded.hasByteOrderMark)
}

@Test func textFileCodecReportsUtf16ByteOrderMarkOnRead() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf16-bom.txt")
    try TextFileCodec.write("hello\n", to: fileURL, encoding: .utf16, lineEnding: .lf)

    let raw = try Data(contentsOf: fileURL)
    #expect(raw.starts(with: [0xFF, 0xFE]) || raw.starts(with: [0xFE, 0xFF]))

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "hello\n")
    #expect(loaded.encoding == .utf16)
    #expect(loaded.hasByteOrderMark)
}

@Test func textFileSavePolicyPreservesLoadedByteOrderMarkForCompatibleEncodings() {
    let policy = TextFileSavePolicy.loaded(
        LoadedTextFile(
            text: "hello",
            encoding: .utf8,
            lineEnding: .lf,
            hasByteOrderMark: true
        )
    )

    #expect(policy.includeByteOrderMark(for: .utf8))
    #expect(policy.converted(to: .utf16LittleEndian).includeByteOrderMark(for: .utf16LittleEndian))
    #expect(policy.converted(to: .utf16BigEndian).includeByteOrderMark(for: .utf16BigEndian))
    #expect(!policy.converted(to: .ascii).includeByteOrderMark(for: .ascii))
    #expect(!policy.converted(to: .ascii).converted(to: .utf8).includeByteOrderMark(for: .utf8))
}

@Test func textFileSavePolicyDoesNotAddByteOrderMarkForNewUtf8Files() {
    let policy = TextFileSavePolicy.newFile

    #expect(!policy.includeByteOrderMark(for: .utf8))
    #expect(!policy.converted(to: .utf8).includeByteOrderMark(for: .utf8))
}

// MARK: - Character-set encoding coverage (PARITY_PLAN P1)

@Test func textEncodingOptionRoundTripsAllCharacterSetEncodings() {
    // Representative text per encoding that must survive encode→decode.
    let samples: [TextEncodingOption: String] = [
        .isoLatin3: "ĝĥĵŝŭ",                 // Esperanto letters
        .isoLatin4: "āēģķļņū",               // Latvian letters
        .isoLatinCyrillic: "Привет мир",
        .isoLatinArabic: "مرحبا",
        .isoLatinGreek: "Καλημέρα",
        .isoLatinHebrew: "שלום",
        .isoLatin5: "ğışĞİŞ",                // Turkish letters
        .isoLatin6: "þðæöá",                 // Nordic letters
        .isoLatin7: "ąčęėįšųž",              // Lithuanian letters
        .isoLatin8: "ŵŷḃċḋ",                 // Welsh/Celtic letters
        .isoLatin9: "€àéîõü",                // Euro sign requires 8859-15
        .koi8u: "Привіт світ ҐґЄєІіЇї",      // Ukrainian letters incl. ghe with upturn
        .tis620: "สวัสดี",
        .windowsCP949: "안녕하세요",
        .dosCP737: "Καλημέρα",
        .dosCP775: "āčēģīķļ",
        .dosCP850: "àéîõü±÷",
        .dosCP852: "áčďéěížž",
        .dosCP855: "Привет мир",
        .dosCP857: "ğışĞİŞ",
        .dosCP860: "ãõçáé",
        .dosCP862: "שלום",
        .dosCP863: "àâçêè",
        .dosCP865: "æøåÆØÅ",
        .dosCP866: "Привет мир",
        .dosCP869: "Καλημέρα"
    ]

    for (option, sample) in samples {
        let encoded = sample.data(using: option.encoding)
        #expect(encoded != nil, "\(option.displayName) failed to encode sample")
        guard let data = encoded else { continue }
        let decoded = String(data: data, encoding: option.encoding)
        #expect(decoded == sample, "\(option.displayName) round-trip mismatch")
    }
}

@Test func textEncodingOptionMapsFixedLegacyEncodingsToCorrectByteValues() {
    // Regression guards for previously wrong CFStringEncoding constants.
    // ISO 8859-15: euro sign at 0xA4 (Latin-1 has ¤ there instead).
    #expect("€".data(using: .isoLatin9Encoding) == Data([0xA4]))
    // OEM 850: é at 0x82 (DOS Latin-1), not cp775.
    #expect("é".data(using: .dosCP850Encoding) == Data([0x82]))
    // OEM 866: Cyrillic А at 0x80.
    #expect("А".data(using: .dosCP866Encoding) == Data([0x80]))
    // Windows-1255: Hebrew aleph at 0xE0.
    #expect("א".data(using: .windowsCP1255Encoding) == Data([0xE0]))
    // Windows-1256: Arabic alef at 0xC7.
    #expect("ا".data(using: .windowsCP1256Encoding) == Data([0xC7]))
    // Windows-1257: Latvian ā at 0xE2.
    #expect("ā".data(using: .windowsCP1257Encoding) == Data([0xE2]))
    // Windows-1258: Vietnamese đ at 0xF0.
    #expect("đ".data(using: .windowsCP1258Encoding) == Data([0xF0]))
}

@Test func textEncodingOptionInitFromEncodingCoversEveryCase() {
    for option in TextEncodingOption.allCases {
        let reconstructed = TextEncodingOption(encoding: option.encoding)
        #expect(reconstructed == option, "\(option.displayName) does not round-trip through init(encoding:)")
    }
}

@Test func textEncodingOptionMenuSectionsCoverEveryNonUnicodeCase() {
    var seen = Set(TextEncodingOption.unicodeMenuOptions)
    for section in TextEncodingOption.characterSetMenuSections {
        for option in section.options {
            #expect(!seen.contains(option), "\(option.displayName) appears in more than one menu section")
            seen.insert(option)
        }
    }
    #expect(seen == Set(TextEncodingOption.allCases), "encoding menu sections must cover all cases exactly once")
}
