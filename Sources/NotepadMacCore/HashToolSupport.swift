import CryptoKit
import Foundation

public enum HashAlgorithm: String, CaseIterable, Sendable {
    case md5
    case sha1
    case sha256
    case sha512

    public var displayName: String {
        switch self {
        case .md5:
            "MD5"
        case .sha1:
            "SHA-1"
        case .sha256:
            "SHA-256"
        case .sha512:
            "SHA-512"
        }
    }
}

public enum HashToolSupport {
    public static func digest(of text: String, using algorithm: HashAlgorithm) -> String {
        hexDigest(for: Data(text.utf8), using: algorithm)
    }

    public static func digestPerLine(of text: String, using algorithm: HashAlgorithm) -> String {
        guard !text.isEmpty else { return "" }

        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalizedText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if normalizedText.last == "\n", !lines.isEmpty {
            lines.removeLast()
        }

        return lines.map { line in
            line.isEmpty ? "" : digest(of: line, using: algorithm)
        }.joined(separator: "\r\n") + "\r\n"
    }

    public static func fileDigestReport(for fileURLs: [URL], using algorithm: HashAlgorithm) throws -> String {
        try fileURLs.map { fileURL in
            let digest = try hexDigest(for: Data(contentsOf: fileURL), using: algorithm)
            return "\(digest)  \(fileURL.lastPathComponent)"
        }.joined(separator: "\r\n") + "\r\n"
    }

    private static func hexDigest(for data: Data, using algorithm: HashAlgorithm) -> String {
        switch algorithm {
        case .md5:
            return hexString(Insecure.MD5.hash(data: data))
        case .sha1:
            return hexString(Insecure.SHA1.hash(data: data))
        case .sha256:
            return hexString(SHA256.hash(data: data))
        case .sha512:
            return hexString(SHA512.hash(data: data))
        }
    }

    private static func hexString<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
