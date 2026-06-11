import Testing
@testable import NotepadMac

@MainActor
private final class FullScreenToggleSpy: FullScreenToggling {
    var invocationCount = 0

    func toggleFullScreen(_ sender: Any?) {
        invocationCount += 1
    }
}

@Test func windowPresentationStateTogglesAlwaysOnTop() {
    let initial = WindowPresentationState()
    let toggled = initial.toggledAlwaysOnTop()

    #expect(initial.isAlwaysOnTop == false)
    #expect(toggled.isAlwaysOnTop == true)
    #expect(toggled.isDistractionFree == false)
}

@Test func windowPresentationStateTogglesDistractionFree() {
    let initial = WindowPresentationState()
    let toggled = initial.toggledDistractionFree()

    #expect(initial.isDistractionFree == false)
    #expect(toggled.isDistractionFree == true)
    #expect(toggled.shouldHideChrome == true)
}

@MainActor
@Test func windowPresentationSupportDelegatesFullscreenToggle() {
    let spy = FullScreenToggleSpy()

    WindowPresentationSupport.toggleFullScreen(using: spy, sender: nil)

    #expect(spy.invocationCount == 1)
}
