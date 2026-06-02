public enum LineEnding: String, CaseIterable, Codable, Sendable {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"

    public var displayName: String {
        switch self {
        case .lf:
            "LF"
        case .crlf:
            "CRLF"
        case .cr:
            "CR"
        }
    }

    public static func detect(in text: String) -> LineEnding {
        let crlfCount = text.countOccurrences(of: "\r\n")
        let withoutCRLF = text.replacingOccurrences(of: "\r\n", with: "")
        let lfCount = withoutCRLF.countOccurrences(of: "\n")
        let crCount = withoutCRLF.countOccurrences(of: "\r")

        if crlfCount == 0, lfCount == 0, crCount == 0 {
            return .lf
        }

        if crlfCount >= lfCount, crlfCount >= crCount {
            return .crlf
        }
        if lfCount >= crCount {
            return .lf
        }
        return .cr
    }

    public func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: rawValue)
    }
}

private extension String {
    func countOccurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }

        var count = 0
        var searchStart = startIndex
        while let range = self[searchStart...].range(of: needle) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }
}
