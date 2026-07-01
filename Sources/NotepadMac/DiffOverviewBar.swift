import AppKit
import NotepadMacCore

/// A slim overview bar showing diff hunks positions.
@MainActor
final class DiffOverviewBar: NSView {
    var result: FileDiff.DiffResult = .init(leftLines: [], rightLines: [], hunks: [], leftTitle: "", rightTitle: "") {
        didSet { needsDisplay = true }
    }

    /// Called with a hunk index to navigate to.
    var onSelectHunk: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.tertiaryLabelColor.withAlphaComponent(0.08).setFill()
        dirtyRect.fill()

        guard !result.hunks.isEmpty, result.leftLines.count > 0 else { return }

        let total = max(1, result.leftLines.count)
        for (idx, hunk) in result.hunks.enumerated() {
            let start = CGFloat(hunk.leftRange.lowerBound) / CGFloat(total)
            let end = CGFloat(hunk.leftRange.upperBound) / CGFloat(total)
            let y = start * bounds.height
            let h = max(2, (end - start) * bounds.height)
            let rect = NSRect(x: 0, y: y, width: bounds.width, height: h)
            (idx == 0 ? NSColor.systemBlue : NSColor.systemOrange).withAlphaComponent(0.7).setFill()
            rect.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !result.hunks.isEmpty else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let p = min(max(loc.y / max(1, bounds.height), 0), 1)
        let total = max(1, result.leftLines.count)
        let targetLine = Int(p * CGFloat(total))
        let nearest = result.hunks.enumerated().min { a, b in
            abs(a.element.leftRange.lowerBound - targetLine) < abs(b.element.leftRange.lowerBound - targetLine)
        }?.offset
        if let nearest { onSelectHunk?(nearest) }
    }
}

