import Foundation

/// Header or footer for one edge (left / center / right) of a printed page.
/// Supports Notepad++-style variable substitution.
public struct PrintBand: Codable, Equatable, Sendable {
    public var left: String
    public var center: String
    public var right: String

    public init(left: String = "", center: String = "", right: String = "") {
        self.left = left
        self.center = center
        self.right = right
    }

    public var isEmpty: Bool { left.isEmpty && center.isEmpty && right.isEmpty }

    /// Expand Notepad++ print variables in one template string.
    public static func expandVariables(
        _ template: String,
        page: Int,
        totalPages: Int,
        filePath: String?,
        date: Date = Date()
    ) -> String {
        guard !template.isEmpty else { return "" }
        let fileName = filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        let fileNameWithoutExt: String = {
            guard !fileName.isEmpty else { return "" }
            let url = URL(fileURLWithPath: fileName)
            return url.deletingPathExtension().lastPathComponent
        }()
        let filePathFull = filePath ?? "(untitled)"

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year   = String(format: "%04d", comps.year   ?? 0)
        let month  = String(format: "%02d", comps.month  ?? 0)
        let day    = String(format: "%02d", comps.day    ?? 0)
        let hour   = String(format: "%02d", comps.hour   ?? 0)
        let minute = String(format: "%02d", comps.minute ?? 0)
        let second = String(format: "%02d", comps.second ?? 0)

        let shortDateFmt = DateFormatter()
        shortDateFmt.dateStyle = .short
        shortDateFmt.timeStyle = .none

        let longDateFmt = DateFormatter()
        longDateFmt.dateStyle = .long
        longDateFmt.timeStyle = .none

        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .medium

        var s = template
        let replacements: [(String, String)] = [
            ("$(FULL_CURRENT_PATH)",      filePathFull),
            ("$(FILE_NAME)",              fileName),
            ("$(FILE_NAME_WITHOUT_EXT)", fileNameWithoutExt),
            ("$(PAGES)",                 "\(totalPages)"),
            ("$(PAGE)",                  "\(page)"),
            ("$(SHORT_DATE)",            shortDateFmt.string(from: date)),
            ("$(LONG_DATE)",             longDateFmt.string(from: date)),
            ("$(TIME)",                  timeFmt.string(from: date)),
            ("$(YEAR)",                  year),
            ("$(MONTH)",                 month),
            ("$(DAY)",                   day),
            ("$(HOUR)",                  hour),
            ("$(MINUTE)",                minute),
            ("$(SECOND)",                second),
        ]
        for (key, value) in replacements {
            s = s.replacingOccurrences(of: key, with: value)
        }
        return s
    }

    /// Expand all three cells for a given page.
    public func expand(
        page: Int,
        totalPages: Int,
        filePath: String?,
        date: Date = Date()
    ) -> (left: String, center: String, right: String) {
        let expand = { Self.expandVariables($0, page: page, totalPages: totalPages, filePath: filePath, date: date) }
        return (expand(left), expand(center), expand(right))
    }
}

/// Complete print settings: header, footer, margins and appearance.
public struct PrintSettings: Codable, Equatable, Sendable {
    /// Defaults matching Notepad++ out-of-box behaviour.
    public static let defaultValue = PrintSettings()

    public var header: PrintBand
    public var footer: PrintBand

    /// 0 = print with original colours, 1 = force black text
    public var colorMode: Int
    /// 0 = use editor font size, positive = explicit override in points
    public var fontSize: Double
    public var marginTop: Double     // points
    public var marginBottom: Double
    public var marginLeft: Double
    public var marginRight: Double

    public init(
        header: PrintBand = PrintBand(left: "", center: "$(FILE_NAME)", right: ""),
        footer: PrintBand = PrintBand(left: "", center: "", right: "$(PAGE) / $(PAGES)"),
        colorMode: Int = 0,
        fontSize: Double = 0,
        marginTop: Double = 36,
        marginBottom: Double = 36,
        marginLeft: Double = 36,
        marginRight: Double = 36
    ) {
        self.header = header
        self.footer = footer
        self.colorMode = max(0, min(1, colorMode))
        self.fontSize = max(0, fontSize)
        self.marginTop = max(0, marginTop)
        self.marginBottom = max(0, marginBottom)
        self.marginLeft = max(0, marginLeft)
        self.marginRight = max(0, marginRight)
    }
}
