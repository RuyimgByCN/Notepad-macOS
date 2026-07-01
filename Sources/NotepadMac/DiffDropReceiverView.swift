import AppKit

/// Receives file drags for the diff window. Drops are routed by x-position:
/// left half → left pane, right half → right pane.
@MainActor
final class DiffDropReceiverView: NSView {
    enum Side { case left, right }
    var onDropFile: ((URL, Side) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard containsFileURL(sender) else { return [] }
        return .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        containsFileURL(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = firstFileURL(sender) else { return false }
        let loc = convert(sender.draggingLocation, from: nil)
        let side: Side = loc.x < bounds.midX ? .left : .right
        onDropFile?(url, side)
        return true
    }

    private func containsFileURL(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue])
    }

    private func firstFileURL(_ sender: NSDraggingInfo) -> URL? {
        let pb = sender.draggingPasteboard
        guard let items = pb.pasteboardItems else { return nil }
        for item in items {
            if let str = item.string(forType: .fileURL), let url = URL(string: str) {
                return url
            }
        }
        return nil
    }
}

