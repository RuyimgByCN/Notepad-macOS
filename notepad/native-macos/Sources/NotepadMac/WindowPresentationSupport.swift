import AppKit

struct WindowPresentationState: Equatable {
    var isAlwaysOnTop = false
    var isDistractionFree = false
    var isPostIt = false

    var shouldHideChrome: Bool {
        isDistractionFree || isPostIt
    }

    /// 0.0 = fully transparent, 1.0 = opaque; defaults to 0.75 in Post-It mode
    var postItAlpha: CGFloat = 0.75

    var windowAlpha: CGFloat {
        isPostIt ? postItAlpha : 1.0
    }

    var windowLevel: NSWindow.Level {
        (isAlwaysOnTop || isPostIt) ? .floating : .normal
    }

    func toggledAlwaysOnTop() -> WindowPresentationState {
        var next = self
        next.isAlwaysOnTop.toggle()
        return next
    }

    func toggledDistractionFree() -> WindowPresentationState {
        var next = self
        next.isDistractionFree.toggle()
        return next
    }

    func toggledPostIt() -> WindowPresentationState {
        var next = self
        next.isPostIt.toggle()
        return next
    }
}

@MainActor
protocol FullScreenToggling: AnyObject {
    func toggleFullScreen(_ sender: Any?)
}

extension NSWindow: FullScreenToggling {}

enum WindowPresentationSupport {
    @MainActor
    static func toggleFullScreen(using window: FullScreenToggling, sender: Any?) {
        window.toggleFullScreen(sender)
    }
}
