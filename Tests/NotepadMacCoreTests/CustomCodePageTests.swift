import Foundation
import Testing
@testable import NotepadMacCore

// MARK: - Byte-level reference checks

@Test func oem720MapsArabicLettersAndAsciiIdentity() throws {
    let page = CustomCodePage.oem720
    // 0x9F = ARABIC LETTER ALEF (U+0627), 0xA0 = BEH (U+0628)
    #expect(page.decode(Data([0x9F, 0xA0])) == "اب")
    #expect(page.encode("اب") == Data([0x9F, 0xA0]))
    // ASCII identity
    #expect(page.decode(Data("hello".utf8)) == "hello")
    #expect(page.encode("hello") == Data("hello".utf8))
}

@Test func oem858PlacesEuroSignAt0xD5() throws {
    let page = CustomCodePage.oem858
    #expect(page.decode(Data([0xD5])) == "€")
    #expect(page.encode("€") == Data([0xD5]))
    // Other positions match cp850: é at 0x82.
    #expect(page.encode("é") == Data([0x82]))
}

@Test func oem861MapsIcelandicLetters() throws {
    let page = CustomCodePage.oem861
    // 0x8B = Eth (U+00D0), 0x8D = Thorn (U+00DE), 0x97 = ý acute (U+00DD is Ý at 0x97? -> Ý)
    #expect(page.decode(Data([0x8B])) == "Ð")
    #expect(page.decode(Data([0x8D])) == "Þ")
    #expect(page.encode("Ðþæö") != nil)
    // Regression: must NOT decode like cp775 (CF's broken table).
    // In cp775, 0x8B is ē; in real cp861 it is Ð.
    #expect(page.decode(Data([0x8B])) != "ē")
}

// MARK: - Full byte-table round trips

@Test func customCodePagesRoundTripAll256Bytes() throws {
    for page in CustomCodePage.allCases {
        let allBytes = Data((0...255).map(UInt8.init))
        let decoded = try #require(page.decode(allBytes), "\(page) failed to decode full byte range")
        let reencoded = try #require(page.encode(decoded), "\(page) failed to re-encode full byte range")
        #expect(reencoded == allBytes, "\(page) byte-level round trip mismatch")
    }
}

@Test func customCodePagesRejectUnmappableCharacters() throws {
    for page in CustomCodePage.allCases {
        #expect(page.encode("中") == nil, "\(page) should reject unmappable text")
    }
}

// MARK: - TextEncodingOption / TextFileCodec integration

@Test func textEncodingOptionsExposeCustomCodePages() throws {
    #expect(TextEncodingOption.dosCP720.encoding == .dosCP720Encoding)
    #expect(TextEncodingOption.dosCP858.encoding == .dosCP858Encoding)
    #expect(TextEncodingOption.dosCP861.encoding == .dosCP861Encoding)
    #expect(TextEncodingOption(encoding: .dosCP720Encoding) == .dosCP720)
    #expect(TextEncodingOption(encoding: .dosCP858Encoding) == .dosCP858)
    #expect(TextEncodingOption(encoding: .dosCP861Encoding) == .dosCP861)
}

@Test func textFileCodecDecodeEncodeRouteCustomPages() throws {
    let sample = "Verð: 100€"
    let encoded = try #require(TextFileCodec.encode(sample, encoding: .dosCP858Encoding))
    #expect(TextFileCodec.decode(encoded, encoding: .dosCP858Encoding) == sample)
    // Standard encodings still go through Foundation.
    #expect(TextFileCodec.encode("abc", encoding: .utf8) == Data("abc".utf8))
}

@Test func textFileCodecReadsAndWritesCustomCodePageFiles() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let samples: [(TextEncodingOption, String)] = [
        (.dosCP720, "مرحبا"),
        (.dosCP858, "àéîõü€"),
        (.dosCP861, "Þórður á Íslandi"),
    ]
    for (option, sample) in samples {
        let fileURL = directory.appending(path: "\(option.rawValue).txt")
        try TextFileCodec.write(sample, to: fileURL, encoding: option.encoding, lineEnding: .lf)
        let loaded = try TextFileCodec.read(fileURL, forcingEncoding: option)
        #expect(loaded.text == sample, "\(option.displayName) file round-trip mismatch")
        #expect(loaded.encoding == option.encoding)
    }
}
