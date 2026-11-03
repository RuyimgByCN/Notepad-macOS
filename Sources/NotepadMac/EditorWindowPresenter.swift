import AppKit

/// Documents own their editing state; the application owns one presentation window.
@MainActor
final class EditorWindowPresenter {
    private(set) var window: NSWindow?
    private(set) weak var activeController: EditorWindowController?

    func present(_ controller: EditorWindowController) {
        if activeController === controller {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        // A sheet must finish with its original document before changing owners.
        guard window?.attachedSheet == nil else { return }
        let sharedWindow = window ?? controller.window ?? EditorWindowController.makePresentationWindow()
        activeController?.detachPresentationWindow()
        controller.detachPresentationWindow(discardWindow: controller.window !== sharedWindow)
        window = sharedWindow
        activeController = controller
        controller.attachPresentationWindow(sharedWindow)
        sharedWindow.makeKeyAndOrderFront(nil)
        controller.finishEditorViewPresentation()
    }

    func remove(_ controller: EditorWindowController) {
        guard activeController === controller else { return }
        controller.detachPresentationWindow()
        activeController = nil
        window?.orderOut(nil)
    }
}
