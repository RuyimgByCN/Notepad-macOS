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
    case isoLatin9      // ISO 8859-15 Western European
    // Other
    case koi8r          // Russian KOI8-R

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
        case String.Encoding.isoLatin9Encoding:
            self = .isoLatin9
        case String.Encoding.koi8rEncoding:
            self = .koi8r
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
        case .isoLatin9: .isoLatin9Encoding
        case .koi8r: .koi8rEncoding
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
        case .isoLatin9: "ISO 8859-15 (Western European)"
        case .koi8r: "KOI8-R (Russian)"
        }
    }
}

public extension String.Encoding {
    /// GBK / GB2312 encoding (Simplified Chinese)
    static let gbkEncoding = String.Encoding(rawValue: 2147485234)
    /// Big5 encoding (Traditional Chinese)
    static let big5 = String.Encoding(rawValue: 2147486214)
    /// EUC-KR encoding (Korean)
    static let EUC_KR = String.Encoding(rawValue: 2147486016)
    // Windows codepages not in Foundation
    static let windowsCP1255Encoding = String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(1255)))
    static let windowsCP1256Encoding = String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(1256)))
    static let windowsCP1257Encoding = String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(1257)))
    static let windowsCP1258Encoding = String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(1258)))
    static let isoLatin9Encoding = String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(0x0201)))
    static let koi8rEncoding = String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(2562)))

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

    public static func write(
        _ text: String,
        to url: URL,
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding = .lf,
        includeByteOrderMark: Bool = false
    ) throws {
        let normalized = lineEnding.normalize(text)
        guard let data = normalized.data(using: encoding) else {
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
