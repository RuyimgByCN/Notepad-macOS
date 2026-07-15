import AppKit
import NotepadMacCore

/// A paginated NSTextView used as the print view for NSPrintOperation.
/// Supports optional header/footer bands drawn in the page border area,
/// and optional form-feed page breaks (upstream Notepad++ 8.9.7).
@MainActor
final class PrintTextView: NSTextView {
    private let settings: PrintSettings
    private let filePath: String?
    private let printDate: Date
    private var cachedTotalPages: Int = 1
    private let pageContentHeight: CGFloat

    private static let bandHeight: CGFloat = 18
    private static let printableWidth: CGFloat = 540
    private static let minimumPrintableHeight: CGFloat = 720

    // MARK: - Init

    init(
        document: PrintDocument,
        fontSize: CGFloat,
        includeLineNumbers: Bool = true,
        printSettings: PrintSettings = .defaultValue,
        filePath: String? = nil
    ) {
        self.settings = printSettings
        self.filePath = filePath
        self.printDate = Date()

        let effectiveFontSize: CGFloat = printSettings.fontSize > 0
            ? CGFloat(printSettings.fontSize)
            : max(fontSize, 9)
        let hasBands = !printSettings.header.isEmpty || !printSettings.footer.isEmpty
        let bandH: CGFloat = hasBands ? Self.bandHeight : 0
        let pageContentH = max(Self.minimumPrintableHeight - bandH * 2, 120)
        self.pageContentHeight = pageContentH

        let textColor: NSColor = printSettings.colorMode == 1 ? .black : .labelColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: effectiveFontSize, weight: .regular),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]

        let attributed: NSAttributedString
        if printSettings.printFormFeedPageBreak {
            attributed = Self.formFeedAwareContent(
                document: document,
                includeLineNumbers: includeLineNumbers,
                attributes: baseAttributes,
                pageContentHeight: pageContentH,
                printableWidth: Self.printableWidth
            )
        } else {
            let text = document.renderedPlainText(includeLineNumbers: includeLineNumbers)
            attributed = NSAttributedString(string: text, attributes: baseAttributes)
        }

        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: Self.printableWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)

        super.init(
            frame: NSRect(x: 0, y: 0, width: Self.printableWidth, height: Self.minimumPrintableHeight),
            textContainer: textContainer
        )

        isEditable = false
        isSelectable = false
        drawsBackground = false
        textContainerInset = NSSize(width: 0, height: bandH)
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        var totalHeight = max(Self.minimumPrintableHeight, ceil(usedRect.height) + bandH * 2 + 24)

        // When form-feed page breaks pad sections to page boundaries, height is already
        // a multiple of pageContentH (plus insets). Snap total height for clean pagination.
        if printSettings.printFormFeedPageBreak, pageContentH > 0 {
            let contentH = ceil(usedRect.height)
            let pages = max(1, Int(ceil(contentH / pageContentH)))
            totalHeight = CGFloat(pages) * pageContentH + bandH * 2 + 24
            cachedTotalPages = pages
        } else if pageContentH > 0 {
            cachedTotalPages = max(1, Int(ceil(usedRect.height / pageContentH)))
        }

        frame = NSRect(x: 0, y: 0, width: Self.printableWidth, height: totalHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Form-feed section layout

    /// Builds content where each form-feed section is padded to a full page height so
    /// automatic vertical pagination starts the next section on a new page.
    private static func formFeedAwareContent(
        document: PrintDocument,
        includeLineNumbers: Bool,
        attributes: [NSAttributedString.Key: Any],
        pageContentHeight: CGFloat,
        printableWidth: CGFloat
    ) -> NSAttributedString {
        let header = [document.title, document.languageDisplayName, document.encodingDisplayName]
            .filter { !$0.isEmpty }
            .joined(separator: "    ")
        let headerBlock = header.isEmpty
            ? ""
            : "\(header)\n\(String(repeating: "=", count: max(header.count, 1)))\n"

        let sections = document.formFeedSections
        let allLineCount = max(sections.reduce(0) { $0 + $1.count }, 1)
        let lineNumberWidth = max(String(allLineCount).count, 4)

        let result = NSMutableAttributedString()
        var globalLine = 0

        // Header once at the top of the print job.
        if !headerBlock.isEmpty {
            result.append(NSAttributedString(string: headerBlock, attributes: attributes))
        }

        for (sectionIndex, section) in sections.enumerated() {
            let sectionStart = result.length
            var body = ""
            if section.isEmpty {
                body = includeLineNumbers ? "\(String(globalLine + 1).leftPadded(to: lineNumberWidth))  \n" : "\n"
                globalLine += 1
            } else {
                for line in section {
                    globalLine += 1
                    if includeLineNumbers {
                        body += "\(String(globalLine).leftPadded(to: lineNumberWidth))  \(line)\n"
                    } else {
                        body += "\(line)\n"
                    }
                }
            }
            result.append(NSAttributedString(string: body, attributes: attributes))

            // Measure this section and pad remaining space to a page boundary
            // (skip padding after the last section).
            if sectionIndex < sections.count - 1 {
                let sectionLength = result.length - sectionStart
                let measured = measureHeight(
                    of: result.attributedSubstring(from: NSRange(location: sectionStart, length: sectionLength)),
                    width: printableWidth
                )
                let usedInPage = measured.truncatingRemainder(dividingBy: pageContentHeight)
                let pad = usedInPage == 0 ? 0 : (pageContentHeight - usedInPage)
                if pad > 1 {
                    // Use paragraph spacing via a single line with large minimum line height.
                    let padStyle = NSMutableParagraphStyle()
                    padStyle.minimumLineHeight = pad
                    padStyle.maximumLineHeight = pad
                    var padAttrs = attributes
                    padAttrs[.paragraphStyle] = padStyle
                    padAttrs[.font] = NSFont.systemFont(ofSize: 1)
                    result.append(NSAttributedString(string: "\n", attributes: padAttrs))
                }
            }
        }

        if result.length == 0 {
            result.append(NSAttributedString(string: "\n", attributes: attributes))
        }
        return result
    }

    private static func measureHeight(of attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        return ceil(layoutManager.usedRect(for: textContainer).height)
    }

    // MARK: - Header / Footer

    override func drawPageBorder(with borderSize: NSSize) {
        guard let op = NSPrintOperation.current else { return }
        let currentPage = op.currentPage
        let total = cachedTotalPages

        drawBand(settings.header, atTop: true, borderSize: borderSize, page: currentPage, totalPages: total)
        drawBand(settings.footer, atTop: false, borderSize: borderSize, page: currentPage, totalPages: total)
    }

    private func drawBand(
        _ band: PrintBand,
        atTop: Bool,
        borderSize: NSSize,
        page: Int,
        totalPages: Int
    ) {
        guard !band.isEmpty else { return }
        let bandH = Self.bandHeight
        let expanded = band.expand(page: page, totalPages: totalPages, filePath: filePath, date: printDate)
        let y: CGFloat = atTop ? borderSize.height - bandH : 0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.black
        ]
        let pageWidth = borderSize.width
        if !expanded.left.isEmpty {
            NSAttributedString(string: expanded.left, attributes: attrs)
                .draw(at: NSPoint(x: 4, y: y + 4))
        }
        if !expanded.center.isEmpty {
            let s = NSAttributedString(string: expanded.center, attributes: attrs)
            s.draw(at: NSPoint(x: (pageWidth - s.size().width) / 2, y: y + 4))
        }
        if !expanded.right.isEmpty {
            let s = NSAttributedString(string: expanded.right, attributes: attrs)
            s.draw(at: NSPoint(x: pageWidth - s.size().width - 4, y: y + 4))
        }
        // Thin separator line
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        let path = NSBezierPath()
        let lineY: CGFloat = atTop ? y : y + bandH
        path.move(to: NSPoint(x: 0, y: lineY))
        path.line(to: NSPoint(x: pageWidth, y: lineY))
        path.lineWidth = 0.5
        path.stroke()
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        guard count < width else { return self }
        return String(repeating: " ", count: width - count) + self
    }
}
