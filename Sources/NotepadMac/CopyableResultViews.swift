import AppKit

/// NSOutlineView that participates in the responder-chain `copy:` action
/// (Edit > Copy / Cmd+C), delegating the actual pasteboard work to its
/// owner. Used by results lists so found data can be copied directly.
@MainActor
final class CopyableOutlineView: NSOutlineView {
    var onCopy: (() -> Bool)?

    @objc func copy(_ sender: Any?) {
        if onCopy?() != true {
            NSSound.beep()
        }
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(copy(_:)) {
            return onCopy != nil
        }
        return super.responds(to: aSelector)
    }
}

/// NSTableView counterpart of `CopyableOutlineView`.
@MainActor
final class CopyableTableView: NSTableView {
    var onCopy: (() -> Bool)?

    @objc func copy(_ sender: Any?) {
        if onCopy?() != true {
            NSSound.beep()
        }
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(copy(_:)) {
            return onCopy != nil
        }
        return super.responds(to: aSelector)
    }
}
