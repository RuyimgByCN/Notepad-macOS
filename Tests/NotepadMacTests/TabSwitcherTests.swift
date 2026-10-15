import AppKit
import Testing
@testable import NotepadMac

@MainActor
@Test func tabSwitcherCancelsOnApplicationDeactivationWithoutConfirmingStaleSelection() {
    _ = NSApplication.shared
    let switcher = TabSwitcherController()
    var confirmations = 0
    switcher.onConfirm = { _ in confirmations += 1 }
    let items = [TabSwitcherController.Item(title: "Document", isDirty: false, representedObject: nil)]
    switcher.show(items: items, selectedIndex: 0, ownerWindow: nil)
    #expect(switcher.isVisible)
    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
    #expect(!switcher.isVisible)
    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApp)
    #expect(!switcher.isVisible)
    switcher.confirmAndHide()
    #expect(confirmations == 0)

    switcher.show(items: items, selectedIndex: 0, ownerWindow: nil)
    switcher.confirmAndHide()
    #expect(confirmations == 1)
    #expect(!switcher.isVisible)
}

@MainActor
@Test func tabSwitcherCancelsWhenItsOwnerLosesKeyWindow() {
    _ = NSApplication.shared
    let owner = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                         styleMask: [.titled], backing: .buffered, defer: false)
    owner.isReleasedWhenClosed = false
    defer { owner.close() }
    let switcher = TabSwitcherController()
    switcher.show(items: [.init(title: "Document", isDirty: false, representedObject: nil)], selectedIndex: 0, ownerWindow: owner)
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: switcher.window)
    #expect(switcher.isVisible)
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: owner)
    #expect(!switcher.isVisible)
}
