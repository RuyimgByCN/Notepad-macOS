import Foundation

/// Scans text for URL patterns and returns their ranges.
public enum URLScanner {
    /// Default URI schemes recognized as clickable links.
    public static let defaultSchemes: [String] = [
        "https", "http", "ftps", "ftp", "file",
        "ssh", "sftp", "svn", "git", "irc", "ircs",
        "mailto", "tel", "callto",
    ]

    nonisolated(unsafe) private static var cachedPattern: (schemes: [String], regex: NSRegularExpression)?

    private static func makePattern(schemes: [String]) -> NSRegularExpression {
        let sorted = schemes.sorted { $0.count > $1.count } // longest first for greedy match
        let alts = sorted.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        // mailto/tel use ":" not "://"
        let schemePart = "(?:\(alts))"
        // Some schemes use ":", others "://"
        let urlBody = #"[^\s<>\"\'\]\[\{\}\|\\^`]+"#
        let p = "\(schemePart)(?:://|:)\(urlBody)"
        return try! NSRegularExpression(pattern: p, options: [])
    }

    private static func pattern(for schemes: [String]) -> NSRegularExpression {
        if let cached = cachedPattern, cached.schemes == schemes {
            return cached.regex
        }
        let regex = makePattern(schemes: schemes)
        cachedPattern = (schemes: schemes, regex: regex)
        return regex
    }

    public static func findURLRanges(in text: String, schemes: [String] = defaultSchemes) -> [NSRange] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return pattern(for: schemes).matches(in: text, options: [], range: fullRange).map(\.range)
    }
}
