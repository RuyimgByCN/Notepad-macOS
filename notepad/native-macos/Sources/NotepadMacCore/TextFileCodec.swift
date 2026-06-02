import Foundation

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

    private let preservesByteOrderMark: Bool

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
        case .macOSRoman:
            self = .macOSRoman
        default:
            return nil
        }
    }

    public var encoding: String.Encoding {
        switch self {
        case .utf8:
            .utf8
        case .utf16:
            .utf16
        case .utf16LittleEndian:
            .utf16LittleEndian
        case .utf16BigEndian:
            .utf16BigEndian
        case .ascii:
            .ascii
        case .isoLatin1:
            .isoLatin1
        case .windowsCP1252:
            .windowsCP1252
        case .macOSRoman:
            .macOSRoman
        }
    }

    public var displayName: String {
        switch self {
        case .utf8:
            "UTF-8"
        case .utf16:
            "UTF-16"
        case .utf16LittleEndian:
            "UTF-16 LE"
        case .utf16BigEndian:
            "UTF-16 BE"
        case .ascii:
            "ASCII"
        case .isoLatin1:
            "ISO Latin-1"
        case .windowsCP1252:
            "Windows CP1252"
        case .macOSRoman:
            "Mac OS Roman"
        }
    }
}

private extension String.Encoding {
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
