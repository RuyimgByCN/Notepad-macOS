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
        var crlfCount = 0
        var lfCount = 0
        var crCount = 0
        var pendingCR = false

        // Newline bytes are identical in UTF-8, so one byte pass avoids the
        // temporary whole-document copies previously created for CRLF removal.
        for byte in text.utf8 {
            if pendingCR {
                if byte == 0x0A {
                    crlfCount += 1
                    pendingCR = false
                    continue
                }
                crCount += 1
                pendingCR = false
            }

            if byte == 0x0D {
                pendingCR = true
            } else if byte == 0x0A {
                lfCount += 1
            }
        }
        if pendingCR {
            crCount += 1
        }

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
