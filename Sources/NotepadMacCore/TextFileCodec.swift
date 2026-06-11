import Foundation
import CoreFoundation

public struct LoadedTextFile: Equatable, Sendable {
    public let text: String
    public let encoding: String.Encoding
    public let lineEnding: LineEnding
    public let hasByteOrderMark: Bool

    public init(
        text: String,
        encoding: String.Encoding,
        lineEnding: LineEnding,
        hasByteOrderMark: Bool = false
    ) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.hasByteOrderMark = hasByteOrderMark
    }
}

public struct TextFileSavePolicy: Equatable, Sendable {
    public static let newFile = TextFileSavePolicy(preservesByteOrderMark: false)

    public private(set) var preservesByteOrderMark: Bool

    public init(preservesByteOrderMark: Bool = false) {
        self.preservesByteOrderMark = preservesByteOrderMark
    }

    public static func loaded(_ file: LoadedTextFile) -> TextFileSavePolicy {
        TextFileSavePolicy(
            preservesByteOrderMark: file.hasByteOrderMark && file.encoding.supportsByteOrderMarkIntent
        )
    }

    public func converted(to encoding: String.Encoding) -> TextFileSavePolicy {
        TextFileSavePolicy(
            preservesByteOrderMark: preservesByteOrderMark && encoding.supportsByteOrderMarkIntent
        )
    }

    public func withByteOrderMark(_ hasBOM: Bool) -> TextFileSavePolicy {
        TextFileSavePolicy(preservesByteOrderMark: hasBOM)
    }

    public func includeByteOrderMark(for encoding: String.Encoding) -> Bool {
        preservesByteOrderMark && encoding.supportsByteOrderMarkIntent
    }
}

public enum TextEncodingOption: String, CaseIterable, Equatable, Sendable {
    case utf8
    case utf16
    case utf16LittleEndian
    case utf16BigEndian
    case ascii
    case isoLatin1
    case windowsCP1252
    case macOSRoman
    // CJK encodings
    case gbk            // Simplified Chinese (GBK / GB2312)
    case big5           // Traditional Chinese
    case shiftJIS       // Japanese
    case eucKR          // Korean
    case eucJP          // Japanese EUC
    // Windows codepages
    case windowsCP1250  // Central European
    case windowsCP1251  // Cyrillic
    case windowsCP1253  // Greek
    case windowsCP1254  // Turkish
    case windowsCP1255  // Hebrew
    case windowsCP1256  // Arabic
    case windowsCP1257  // Baltic
    case windowsCP1258  // Vietnamese
    // ISO encodings
    case isoLatin2      // ISO 8859-2 Central European
    case isoLatin3      // ISO 8859-3 South European
    case isoLatin4      // ISO 8859-4 Baltic
    case isoLatinCyrillic // ISO 8859-5 Cyrillic
    case isoLatinArabic // ISO 8859-6 Arabic
    case isoLatinGreek  // ISO 8859-7 Greek
    case isoLatinHebrew // ISO 8859-8 Hebrew
    case isoLatin5      // ISO 8859-9 Turkish
    case isoLatin6      // ISO 8859-10 Nordic
    case isoLatin7      // ISO 8859-13 Baltic Rim
    case isoLatin8      // ISO 8859-14 Celtic
    case isoLatin9      // ISO 8859-15 Western European
    // Other
    case koi8r          // Russian KOI8-R
    case koi8u          // Ukrainian KOI8-U
    case tis620         // TIS-620 / ISO 8859-11 (Thai)
    case windowsCP949   // Windows 949 (Unified Hangul, Korean)
    // OEM/DOS codepages
    case dosCP437       // OEM United States (MS-DOS)
    case dosCP737       // OEM Greek (MS-DOS)
    case dosCP775       // OEM Baltic Rim (MS-DOS)
    case dosCP850       // OEM Multilingual Latin 1 (MS-DOS Western)
    case dosCP852       // OEM Latin 2 (MS-DOS Central European)
    case dosCP855       // OEM Cyrillic (MS-DOS)
    case dosCP857       // OEM Turkish (MS-DOS)
    case dosCP860       // OEM Portuguese (MS-DOS)
    case dosCP862       // OEM Hebrew (MS-DOS)
    case dosCP863       // OEM Canadian French (MS-DOS)
    case dosCP865       // OEM Nordic (MS-DOS)
    case dosCP866       // OEM Russian / Cyrillic (MS-DOS)
    case dosCP869       // OEM Modern Greek (MS-DOS)
    // OEM codepages with no usable CF table (custom byte tables)
    case dosCP720       // OEM Arabic (MS-DOS)
    case dosCP858       // OEM Multilingual Latin 1 + euro (MS-DOS)
    case dosCP861       // OEM Icelandic (MS-DOS)

    public init?(encoding: String.Encoding) {
        switch encoding {
        case .utf8:
            self = .utf8
        case .utf16:
            self = .utf16
        case .utf16LittleEndian:
            self = .utf16LittleEndian
        case .utf16BigEndian:
            self = .utf16BigEndian
        case .ascii:
            self = .ascii
        case .isoLatin1:
            self = .isoLatin1
        case .windowsCP1252:
            self = .windowsCP1252
        case String.Encoding.gbkEncoding:
            self = .gbk
        case String.Encoding.big5:
            self = .big5
        case .shiftJIS:
            self = .shiftJIS
        case .EUC_KR:
            self = .eucKR
        case .japaneseEUC:
            self = .eucJP
        case .macOSRoman:
            self = .macOSRoman
        case .windowsCP1250:
            self = .windowsCP1250
        case .windowsCP1251:
            self = .windowsCP1251
        case .windowsCP1253:
            self = .windowsCP1253
        case .windowsCP1254:
            self = .windowsCP1254
        case String.Encoding.windowsCP1255Encoding:
            self = .windowsCP1255
        case String.Encoding.windowsCP1256Encoding:
            self = .windowsCP1256
        case String.Encoding.windowsCP1257Encoding:
            self = .windowsCP1257
        case String.Encoding.windowsCP1258Encoding:
            self = .windowsCP1258
        case .isoLatin2:
            self = .isoLatin2
        case String.Encoding.isoLatin3Encoding:
            self = .isoLatin3
        case String.Encoding.isoLatin4Encoding:
            self = .isoLatin4
        case String.Encoding.isoLatinCyrillicEncoding:
            self = .isoLatinCyrillic
        case String.Encoding.isoLatinArabicEncoding:
            self = .isoLatinArabic
        case String.Encoding.isoLatinGreekEncoding:
            self = .isoLatinGreek
        case String.Encoding.isoLatinHebrewEncoding:
            self = .isoLatinHebrew
        case String.Encoding.isoLatin5Encoding:
            self = .isoLatin5
        case String.Encoding.isoLatin6Encoding:
            self = .isoLatin6
        case String.Encoding.isoLatin7Encoding:
            self = .isoLatin7
        case String.Encoding.isoLatin8Encoding:
            self = .isoLatin8
        case String.Encoding.isoLatin9Encoding:
            self = .isoLatin9
        case String.Encoding.koi8rEncoding:
            self = .koi8r
        case String.Encoding.koi8uEncoding:
            self = .koi8u
        case String.Encoding.tis620Encoding:
            self = .tis620
        case String.Encoding.windowsCP949Encoding:
            self = .windowsCP949
        case String.Encoding.dosCP437Encoding:
            self = .dosCP437
        case String.Encoding.dosCP737Encoding:
            self = .dosCP737
        case String.Encoding.dosCP775Encoding:
            self = .dosCP775
        case String.Encoding.dosCP850Encoding:
            self = .dosCP850
        case String.Encoding.dosCP852Encoding:
            self = .dosCP852
        case String.Encoding.dosCP855Encoding:
            self = .dosCP855
        case String.Encoding.dosCP857Encoding:
            self = .dosCP857
        case String.Encoding.dosCP860Encoding:
            self = .dosCP860
        case String.Encoding.dosCP862Encoding:
            self = .dosCP862
        case String.Encoding.dosCP863Encoding:
            self = .dosCP863
        case String.Encoding.dosCP865Encoding:
            self = .dosCP865
        case String.Encoding.dosCP866Encoding:
            self = .dosCP866
        case String.Encoding.dosCP869Encoding:
            self = .dosCP869
        case String.Encoding.dosCP720Encoding:
            self = .dosCP720
        case String.Encoding.dosCP858Encoding:
            self = .dosCP858
        case String.Encoding.dosCP861Encoding:
            self = .dosCP861
        default:
            return nil
        }
    }

    public var encoding: String.Encoding {
        switch self {
        case .utf8: .utf8
        case .utf16: .utf16
        case .utf16LittleEndian: .utf16LittleEndian
        case .utf16BigEndian: .utf16BigEndian
        case .ascii: .ascii
        case .isoLatin1: .isoLatin1
        case .windowsCP1252: .windowsCP1252
        case .macOSRoman: .macOSRoman
        case .gbk: .gbkEncoding
        case .big5: .big5
        case .shiftJIS: .shiftJIS
        case .eucKR: .EUC_KR
        case .eucJP: .japaneseEUC
        case .windowsCP1250: .windowsCP1250
        case .windowsCP1251: .windowsCP1251
        case .windowsCP1253: .windowsCP1253
        case .windowsCP1254: .windowsCP1254
        case .windowsCP1255: .windowsCP1255Encoding
        case .windowsCP1256: .windowsCP1256Encoding
        case .windowsCP1257: .windowsCP1257Encoding
        case .windowsCP1258: .windowsCP1258Encoding
        case .isoLatin2: .isoLatin2
        case .isoLatin3: .isoLatin3Encoding
        case .isoLatin4: .isoLatin4Encoding
        case .isoLatinCyrillic: .isoLatinCyrillicEncoding
        case .isoLatinArabic: .isoLatinArabicEncoding
        case .isoLatinGreek: .isoLatinGreekEncoding
        case .isoLatinHebrew: .isoLatinHebrewEncoding
        case .isoLatin5: .isoLatin5Encoding
        case .isoLatin6: .isoLatin6Encoding
        case .isoLatin7: .isoLatin7Encoding
        case .isoLatin8: .isoLatin8Encoding
        case .isoLatin9: .isoLatin9Encoding
        case .koi8r: .koi8rEncoding
        case .koi8u: .koi8uEncoding
        case .tis620: .tis620Encoding
        case .windowsCP949: .windowsCP949Encoding
        case .dosCP437: .dosCP437Encoding
        case .dosCP737: .dosCP737Encoding
        case .dosCP775: .dosCP775Encoding
        case .dosCP850: .dosCP850Encoding
        case .dosCP852: .dosCP852Encoding
        case .dosCP855: .dosCP855Encoding
        case .dosCP857: .dosCP857Encoding
        case .dosCP860: .dosCP860Encoding
        case .dosCP862: .dosCP862Encoding
        case .dosCP863: .dosCP863Encoding
        case .dosCP865: .dosCP865Encoding
        case .dosCP866: .dosCP866Encoding
        case .dosCP869: .dosCP869Encoding
        case .dosCP720: .dosCP720Encoding
        case .dosCP858: .dosCP858Encoding
        case .dosCP861: .dosCP861Encoding
        }
    }

    public var displayName: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf16: "UTF-16"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        case .ascii: "ASCII"
        case .isoLatin1: "ISO Latin-1"
        case .windowsCP1252: "Windows CP1252"
        case .macOSRoman: "Mac OS Roman"
        case .gbk: "GBK (Simplified Chinese)"
        case .big5: "Big5 (Traditional Chinese)"
        case .shiftJIS: "Shift-JIS (Japanese)"
        case .eucKR: "EUC-KR (Korean)"
        case .eucJP: "EUC-JP (Japanese)"
        case .windowsCP1250: "Windows-1250 (Central European)"
        case .windowsCP1251: "Windows-1251 (Cyrillic)"
        case .windowsCP1253: "Windows-1253 (Greek)"
        case .windowsCP1254: "Windows-1254 (Turkish)"
        case .windowsCP1255: "Windows-1255 (Hebrew)"
        case .windowsCP1256: "Windows-1256 (Arabic)"
        case .windowsCP1257: "Windows-1257 (Baltic)"
        case .windowsCP1258: "Windows-1258 (Vietnamese)"
        case .isoLatin2: "ISO 8859-2 (Central European)"
        case .isoLatin3: "ISO 8859-3 (South European)"
        case .isoLatin4: "ISO 8859-4 (Baltic)"
        case .isoLatinCyrillic: "ISO 8859-5 (Cyrillic)"
        case .isoLatinArabic: "ISO 8859-6 (Arabic)"
        case .isoLatinGreek: "ISO 8859-7 (Greek)"
        case .isoLatinHebrew: "ISO 8859-8 (Hebrew)"
        case .isoLatin5: "ISO 8859-9 (Turkish)"
        case .isoLatin6: "ISO 8859-10 (Nordic)"
        case .isoLatin7: "ISO 8859-13 (Baltic Rim)"
        case .isoLatin8: "ISO 8859-14 (Celtic)"
        case .isoLatin9: "ISO 8859-15 (Western European)"
        case .koi8r: "KOI8-R (Russian)"
        case .koi8u: "KOI8-U (Ukrainian)"
        case .tis620: "TIS-620 (Thai)"
        case .windowsCP949: "Windows 949 (Korean)"
        case .dosCP437: "OEM-US CP437 (MS-DOS)"
        case .dosCP737: "OEM 737 (Greek)"
        case .dosCP775: "OEM 775 (Baltic Rim)"
        case .dosCP850: "OEM 850 (Western European)"
        case .dosCP852: "OEM 852 (Central European)"
        case .dosCP855: "OEM 855 (Cyrillic)"
        case .dosCP857: "OEM 857 (Turkish)"
        case .dosCP860: "OEM 860 (Portuguese)"
        case .dosCP862: "OEM 862 (Hebrew)"
        case .dosCP863: "OEM 863 (Canadian French)"
        case .dosCP865: "OEM 865 (Nordic)"
        case .dosCP866: "OEM 866 (Cyrillic)"
        case .dosCP869: "OEM 869 (Modern Greek)"
        case .dosCP720: "OEM 720 (Arabic)"
        case .dosCP858: "OEM 858 (Western European, Euro)"
        case .dosCP861: "OEM 861 (Icelandic)"
        }
    }

    /// Unicode options shown at the top level of the Encoding menus,
    /// mirroring upstream Notepad++'s top-level encoding entries.
    public static var unicodeMenuOptions: [TextEncodingOption] {
        [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .ascii]
    }

    /// Region-grouped legacy encodings for a "Character sets" style submenu,
    /// mirroring upstream Notepad++'s Encoding > Character sets grouping.
    public static var characterSetMenuSections: [(name: String, options: [TextEncodingOption])] {
        [
            ("Arabic", [.windowsCP1256, .isoLatinArabic, .dosCP720]),
            ("Baltic", [.windowsCP1257, .isoLatin4, .isoLatin7, .dosCP775]),
            ("Celtic", [.isoLatin8]),
            ("Central European", [.windowsCP1250, .isoLatin2, .dosCP852]),
            ("Chinese", [.gbk, .big5]),
            ("Cyrillic", [.windowsCP1251, .isoLatinCyrillic, .koi8r, .koi8u, .dosCP855, .dosCP866]),
            ("Greek", [.windowsCP1253, .isoLatinGreek, .dosCP737, .dosCP869]),
            ("Hebrew", [.windowsCP1255, .isoLatinHebrew, .dosCP862]),
            ("Japanese", [.shiftJIS, .eucJP]),
            ("Korean", [.windowsCP949, .eucKR]),
            // OEM 861 uses a custom byte table: CF's decoder for
            // kCFStringEncodingDOSIcelandic produces cp775 mappings.
            ("North European", [.isoLatin6, .dosCP861, .dosCP865]),
            ("South European", [.isoLatin3]),
            ("Thai", [.tis620]),
            ("Turkish", [.windowsCP1254, .isoLatin5, .dosCP857]),
            (
                "Western European",
                [.windowsCP1252, .isoLatin1, .isoLatin9, .macOSRoman, .dosCP437, .dosCP850, .dosCP858, .dosCP860, .dosCP863]
            ),
            ("Vietnamese", [.windowsCP1258])
        ]
    }
}

public extension String.Encoding {
    /// Bridges a CoreFoundation `CFStringEncoding` constant (see
    /// CFStringEncodingExt.h) into a Foundation `String.Encoding`.
    private static func cfEncoding(_ value: UInt32) -> String.Encoding {
        String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(value))))
    }

    /// GBK / GB2312 encoding (Simplified Chinese)
    static let gbkEncoding = String.Encoding(rawValue: 2147485234)
    /// Big5 encoding (Traditional Chinese)
    static let big5 = String.Encoding(rawValue: 2147486214)
    /// EUC-KR encoding (Korean)
    static let EUC_KR = String.Encoding(rawValue: 2147486016)
    // Windows codepages not in Foundation (kCFStringEncodingWindows*)
    static let windowsCP1255Encoding = cfEncoding(0x0505) // WindowsHebrew
    static let windowsCP1256Encoding = cfEncoding(0x0506) // WindowsArabic
    static let windowsCP1257Encoding = cfEncoding(0x0507) // WindowsBalticRim
    static let windowsCP1258Encoding = cfEncoding(0x0508) // WindowsVietnamese
    static let windowsCP949Encoding = cfEncoding(0x0422)  // DOSKorean / Windows 949
    // ISO 8859-x not in Foundation (kCFStringEncodingISOLatin*)
    static let isoLatin3Encoding = cfEncoding(0x0203)        // ISO 8859-3
    static let isoLatin4Encoding = cfEncoding(0x0204)        // ISO 8859-4
    static let isoLatinCyrillicEncoding = cfEncoding(0x0205) // ISO 8859-5
    static let isoLatinArabicEncoding = cfEncoding(0x0206)   // ISO 8859-6
    static let isoLatinGreekEncoding = cfEncoding(0x0207)    // ISO 8859-7
    static let isoLatinHebrewEncoding = cfEncoding(0x0208)   // ISO 8859-8
    static let isoLatin5Encoding = cfEncoding(0x0209)        // ISO 8859-9
    static let isoLatin6Encoding = cfEncoding(0x020A)        // ISO 8859-10
    static let tis620Encoding = cfEncoding(0x020B)           // ISO 8859-11 / TIS-620
    static let isoLatin7Encoding = cfEncoding(0x020D)        // ISO 8859-13
    static let isoLatin8Encoding = cfEncoding(0x020E)        // ISO 8859-14
    static let isoLatin9Encoding = cfEncoding(0x020F)        // ISO 8859-15
    // Other
    static let koi8rEncoding = cfEncoding(0x0A02) // KOI8-R
    static let koi8uEncoding = cfEncoding(0x0A08) // KOI8-U
    // OEM/DOS codepages via CFStringEncoding (kCFStringEncodingDOS*)
    static let dosCP437Encoding = cfEncoding(0x0400) // DOSLatinUS
    static let dosCP737Encoding = cfEncoding(0x0405) // DOSGreek
    static let dosCP775Encoding = cfEncoding(0x0406) // DOSBalticRim
    static let dosCP850Encoding = cfEncoding(0x0410) // DOSLatin1
    static let dosCP852Encoding = cfEncoding(0x0412) // DOSLatin2
    static let dosCP855Encoding = cfEncoding(0x0413) // DOSCyrillic
    static let dosCP857Encoding = cfEncoding(0x0414) // DOSTurkish
    static let dosCP860Encoding = cfEncoding(0x0415) // DOSPortuguese
    static let dosCP862Encoding = cfEncoding(0x0417) // DOSHebrew
    static let dosCP863Encoding = cfEncoding(0x0418) // DOSCanadianFrench
    static let dosCP865Encoding = cfEncoding(0x041A) // DOSNordic
    static let dosCP866Encoding = cfEncoding(0x041B) // DOSRussian
    static let dosCP869Encoding = cfEncoding(0x041C) // DOSGreek2

    var supportsByteOrderMarkIntent: Bool {
        switch self {
        case .utf8, .utf16, .utf16LittleEndian, .utf16BigEndian:
            true
        default:
            false
        }
    }
}

public enum TextFileCodec {
    public enum ReadError: Error, Equatable, Sendable {
        case unsupportedEncoding
    }

    /// Read a file with optional ANSI-as-UTF8 reinterpretation.
    /// When `openAnsiAsUtf8` is true and the detected encoding is a legacy single-byte
    /// encoding (not UTF-8/UTF-16), try to re-decode as UTF-8 first.
    public static func read(_ url: URL, openAnsiAsUtf8: Bool = false) throws -> LoadedTextFile {
        let result = try read(url)

        if openAnsiAsUtf8 {
            // If the detected encoding is not UTF-8 or UTF-16, try UTF-8 reinterpretation.
            // This matches upstream's "openAnsiAsUTF8" semantics:
            // ANSI/Windows-CP files that are actually UTF-8 should be re-read as UTF-8.
            let isUnicode = result.encoding == .utf8
                || result.encoding == .utf16
                || result.encoding == .utf16LittleEndian
                || result.encoding == .utf16BigEndian

            if !isUnicode {
                let data = try Data(contentsOf: url)
                if let utf8Text = String(data: data, encoding: .utf8) {
                    return LoadedTextFile(
                        text: utf8Text,
                        encoding: .utf8,
                        lineEnding: LineEnding.detect(in: utf8Text),
                        hasByteOrderMark: data.hasUTF8ByteOrderMark
                    )
                }
            }
        }

        return result
    }

    public static func read(_ url: URL) throws -> LoadedTextFile {
        let data = try Data(contentsOf: url)
        let legacySingleByteCandidates: [String.Encoding] = [
            .ascii,
            .windowsCP1252,
            .isoLatin1,
            .macOSRoman
        ]
        let candidates: [String.Encoding]
        if data.hasUTF8ByteOrderMark {
            candidates = [.utf8]
        } else if data.hasUTF16ByteOrderMark {
            candidates = [.utf16, .utf16LittleEndian, .utf16BigEndian]
        } else if data.looksLikeUTF16LittleEndian {
            candidates = [.utf16LittleEndian, .utf8, .utf16BigEndian, .utf16] + legacySingleByteCandidates
        } else if data.looksLikeUTF16BigEndian {
            candidates = [.utf16BigEndian, .utf8, .utf16LittleEndian, .utf16] + legacySingleByteCandidates
        } else {
            candidates = [.utf8] + legacySingleByteCandidates + [.utf16LittleEndian, .utf16BigEndian, .utf16]
        }

        for encoding in candidates {
            if let text = String(data: data, encoding: encoding) {
                return LoadedTextFile(
                    text: text,
                    encoding: encoding,
                    lineEnding: LineEnding.detect(in: text),
                    hasByteOrderMark: data.hasByteOrderMark
                )
            }
        }

        // Fallback: use ICU-based charset detection for CJK and other encodings
        var usedLossyConversion: ObjCBool = false
        let detectedEncoding = NSString.stringEncoding(
            for: data,
            encodingOptions: [
                .allowLossyKey: false,
                .suggestedEncodingsKey: [
                    String.Encoding.utf8.rawValue,
                    String.Encoding.shiftJIS.rawValue,
                    String.Encoding.japaneseEUC.rawValue,
                    0x80000632, // GBK / GB18030
                    String.Encoding.big5.rawValue,
                    0x80000940, // EUC-KR
                    String.Encoding.isoLatin1.rawValue,
                    String.Encoding.windowsCP1252.rawValue,
                ] as [UInt]
            ],
            convertedString: nil,
            usedLossyConversion: &usedLossyConversion
        )
        if detectedEncoding != 0, !usedLossyConversion.boolValue,
           let text = String(data: data, encoding: String.Encoding(rawValue: detectedEncoding)) {
            return LoadedTextFile(
                text: text,
                encoding: String.Encoding(rawValue: detectedEncoding),
                lineEnding: LineEnding.detect(in: text),
                hasByteOrderMark: false
            )
        }

        throw ReadError.unsupportedEncoding
    }

    /// Decodes bytes with `encoding`, routing the custom OEM code pages
    /// through their byte tables and everything else through Foundation.
    public static func decode(_ data: Data, encoding: String.Encoding) -> String? {
        if let page = CustomCodePage(encoding: encoding) {
            return page.decode(data)
        }
        return String(data: data, encoding: encoding)
    }

    /// Encodes text with `encoding`, routing the custom OEM code pages
    /// through their byte tables and everything else through Foundation.
    public static func encode(_ text: String, encoding: String.Encoding) -> Data? {
        if let page = CustomCodePage(encoding: encoding) {
            return page.encode(text)
        }
        return text.data(using: encoding)
    }

    /// Read a file forcing a specific encoding (for "Reload as Encoding").
    public static func read(_ url: URL, forcingEncoding option: TextEncodingOption) throws -> LoadedTextFile {
        let data = try Data(contentsOf: url)
        guard let text = decode(data, encoding: option.encoding) else {
            throw ReadError.unsupportedEncoding
        }
        return LoadedTextFile(
            text: text,
            encoding: option.encoding,
            lineEnding: LineEnding.detect(in: text),
            hasByteOrderMark: data.hasByteOrderMark
        )
    }

    public static func write(
        _ text: String,
        to url: URL,
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding = .lf,
        includeByteOrderMark: Bool = false
    ) throws {
        let normalized = lineEnding.normalize(text)
        guard let data = encode(normalized, encoding: encoding) else {
            throw ReadError.unsupportedEncoding
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data
            .includingByteOrderMark(for: encoding, when: includeByteOrderMark)
            .write(to: url, options: .atomic)
    }
}

private extension Data {
    var hasByteOrderMark: Bool {
        hasUTF8ByteOrderMark || hasUTF16ByteOrderMark
    }

    var hasUTF8ByteOrderMark: Bool {
        starts(with: [0xEF, 0xBB, 0xBF])
    }

    var hasUTF16ByteOrderMark: Bool {
        starts(with: [0xFF, 0xFE]) || starts(with: [0xFE, 0xFF])
    }

    func includingByteOrderMark(for encoding: String.Encoding, when shouldInclude: Bool) -> Data {
        guard shouldInclude,
              let byteOrderMark = Data.byteOrderMark(for: encoding),
              !starts(with: byteOrderMark)
        else {
            return self
        }

        return Data(byteOrderMark) + self
    }

    static func byteOrderMark(for encoding: String.Encoding) -> [UInt8]? {
        switch encoding {
        case .utf8:
            [0xEF, 0xBB, 0xBF]
        case .utf16LittleEndian:
            [0xFF, 0xFE]
        case .utf16BigEndian:
            [0xFE, 0xFF]
        default:
            nil
        }
    }

    var looksLikeUTF16LittleEndian: Bool {
        utf16ZeroByteScore(evenOffsets: false) >= 0.35
    }

    var looksLikeUTF16BigEndian: Bool {
        utf16ZeroByteScore(evenOffsets: true) >= 0.35
    }

    func utf16ZeroByteScore(evenOffsets: Bool) -> Double {
        guard count >= 4 else { return 0 }

        var matchingZeroes = 0
        var sampledPairs = 0
        var index = 0
        while index + 1 < count, sampledPairs < 256 {
            let zeroOffset = evenOffsets ? index : index + 1
            if self[zeroOffset] == 0 {
                matchingZeroes += 1
            }
            sampledPairs += 1
            index += 2
        }

        guard sampledPairs > 0 else { return 0 }
        return Double(matchingZeroes) / Double(sampledPairs)
    }
}
