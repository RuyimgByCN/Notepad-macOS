import AppKit
import Testing
@testable import NotepadMac

@MainActor
@Test func editorToolbarIsContentRowAboveTabBar() {
    let controller = EditorWindowController()

    #expect(controller.window?.toolbar == nil)

    let contentSubviews = controller.window?.contentView?.subviews ?? []
    let toolbarIndex = contentSubviews.firstIndex {
        $0.accessibilityIdentifier() == EditorWindowToolbar.contentRowAccessibilityIdentifier
    }
    let tabBarIndex = contentSubviews.firstIndex { $0 is EditorTabBarView }

    #expect(toolbarIndex == 0)
    #expect(tabBarIndex == 1)
}
