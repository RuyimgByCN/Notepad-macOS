import AppKit
import NotepadMacCore

@MainActor
final class PrintTextView: NSTextView {
    private static let printableWidth: CGFloat = 540
    private static let minimumPrintableHeight: CGFloat = 720

    init(document: PrintDocument, fontSize: CGFloat, includeLineNumbers: Bool = true) {
        let storage = NSTextStorage(attributedString: Self.attributedString(for: document, fontSize: fontSize, includeLineNumbers: includeLineNumbers))
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
        textContainerInset = NSSize(width: 0, height: 0)
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        frame = NSRect(
            x: 0,
            y: 0,
            width: Self.printableWidth,
            height: max(Self.minimumPrintableHeight, ceil(usedRect.height) + 24)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func attributedString(for document: PrintDocument, fontSize: CGFloat, includeLineNumbers: Bool = true) -> NSAttributedString {
        let text = document.renderedPlainText(includeLineNumbers: includeLineNumbers)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2

        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: max(fontSize, 9), weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )
    }
}
