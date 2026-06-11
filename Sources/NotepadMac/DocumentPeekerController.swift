import AppKit

/// Upstream "Document Peeker": a small floating preview shown when the
/// pointer dwells on a tab, displaying the first lines of that document
/// without activating it.
@MainActor
final class DocumentPeekerController {
    static let maxPreviewLines = 24
    static let maxPreviewLineLength = 120

    private var panel: NSPanel?
    private let titleLabel = NSTextField(labelWithString: "")
    private let previewLabel = NSTextField(labelWithString: "")

    /// Trims a document's text down to the peek excerpt.
    static func previewExcerpt(from text: String) -> String {
        var lines: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(maxPreviewLines) {
            lines.append(String(line.prefix(maxPreviewLineLength)))
        }
        return lines.joined(separator: "\n")
    }

    func show(title: String, previewText: String, near tabScreenRect: NSRect) {
        let panel = ensurePanel()
        titleLabel.stringValue = title
        previewLabel.stringValue = previewText.isEmpty ? " " : previewText

        let maxContentWidth: CGFloat = 380
        let maxPreviewHeight: CGFloat = 260
        let padding: CGFloat = 8

        titleLabel.preferredMaxLayoutWidth = maxContentWidth
        previewLabel.preferredMaxLayoutWidth = maxContentWidth
        let titleSize = titleLabel.intrinsicContentSize
        let previewSize = previewLabel.intrinsicContentSize
        let contentWidth = min(maxContentWidth, max(titleSize.width, previewSize.width))
        let previewHeight = min(maxPreviewHeight, previewSize.height)
        let contentHeight = titleSize.height + 4 + previewHeight

        let panelSize = NSSize(
            width: contentWidth + padding * 2,
            height: contentHeight + padding * 2
        )

        titleLabel.frame = NSRect(
            x: padding,
            y: panelSize.height - padding - titleSize.height,
            width: contentWidth,
            height: titleSize.height
        )
        previewLabel.frame = NSRect(
            x: padding,
            y: padding,
            width: contentWidth,
            height: previewHeight
        )

        var origin = NSPoint(
            x: tabScreenRect.minX,
            y: tabScreenRect.minY - panelSize.height - 4
        )
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(tabScreenRect) })
            ?? NSScreen.main {
            let visible = screen.visibleFrame
            if origin.x + panelSize.width > visible.maxX {
                origin.x = visible.maxX - panelSize.width
            }
            origin.x = max(origin.x, visible.minX)
            if origin.y < visible.minY {
                // Not enough room below the tab bar: show above it.
                origin.y = tabScreenRect.maxY + 4
            }
        }

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        newPanel.level = .floating
        newPanel.hasShadow = true
        newPanel.ignoresMouseEvents = true
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.backgroundColor = .clear

        let background = NSVisualEffectView()
        background.material = .toolTip
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1

        previewLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.lineBreakMode = .byClipping
        previewLabel.maximumNumberOfLines = 0
        previewLabel.cell?.truncatesLastVisibleLine = true

        background.addSubview(titleLabel)
        background.addSubview(previewLabel)
        newPanel.contentView = background

        panel = newPanel
        return newPanel
    }
}
