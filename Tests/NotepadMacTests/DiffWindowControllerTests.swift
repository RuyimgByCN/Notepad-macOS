import AppKit
import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func diffWindowControllerConstructsWithTwoTexts() async {
    let controller = DiffWindowController(
        left: "a\nb\nc",
        right: "a\nX\nc",
        leftTitle: "Left.txt",
        rightTitle: "Right.txt"
    )
    await controller.waitUntilReady()
    #expect(controller.result.hunks.count == 1)
    #expect(controller.result.leftLines.count == controller.result.rightLines.count)
    #expect(controller.window != nil)
}

@MainActor
@Test func diffWindowControllerReportsIdenticalFiles() async {
    let controller = DiffWindowController(
        left: "same\ncontent",
        right: "same\ncontent",
        leftTitle: "L",
        rightTitle: "R"
    )
    await controller.waitUntilReady()
    #expect(controller.result.isIdentical)
    #expect(controller.result.hunks.isEmpty)
}

@MainActor
@Test func diffWindowControllerSelectorsExist() {
    #expect(AppDelegate.instancesRespond(to: #selector(AppDelegate.compareFiles(_:))))
    #expect(AppDelegate.instancesRespond(to: #selector(AppDelegate.compareActiveWith(_:))))
    #expect(AppDelegate.instancesRespond(to: #selector(AppDelegate.compareTwoOpenDocuments(_:))))
}

@MainActor
@Test func diffToolbarExposesNavigationClosures() {
    let toolbar = DiffToolbar()
    var navigated = false
    toolbar.onNext = { navigated = true }
    toolbar.onNext?()
    #expect(navigated)
}

@MainActor
@Test func diffWindowNavigationMovesBetweenHunks() async {
    let controller = DiffWindowController(
        left: "a\nb\nc\nd",
        right: "a\nX\nc\nY",
        leftTitle: "L",
        rightTitle: "R"
    )
    await controller.waitUntilReady()
    #expect(controller.result.hunks.count >= 2)
    controller.navigateNext()
    controller.navigateNext()
    controller.navigatePrevious()
}

@MainActor
@Test func diffWindowEditorPanesHaveNonZeroHeightAfterLayout() async {
    let controller = DiffWindowController(
        left: "line1\nline2\nline3",
        right: "line1\nLINE2\nline3",
        leftTitle: "Left.txt",
        rightTitle: "Right.txt"
    )
    await controller.waitUntilReady()
    controller.showWindow(nil)
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()
    let height = controller.editorSplitHeightForTesting
    #expect(height > 100)
    #expect(controller.editorPaneWidthForTesting > 100)
}

@MainActor
@Test func diffToolbarIncludesWhitespaceAndRulesActions() {
    let toolbar = DiffToolbar()
    var rulesOpened = false
    toolbar.onRules = { rulesOpened = true }
    toolbar.onRules?()
    #expect(rulesOpened)
}

@MainActor
@Test func diffToolbarShowsUpstreamCaptionsInOrder() {
    let toolbar = DiffToolbar()
    let buttonTitles = diffToolbarButtons(in: toolbar).map(\.title).filter { !$0.isEmpty }

    #expect(buttonTitles == [
        DiffStrings.toolbarWhitespaceCaption,
        DiffStrings.toolbarRulesCaption,
        DiffStrings.toolbarBreakCaption,
        DiffStrings.toolbarPullOpenCaption,
        DiffStrings.toolbarStrictCaption,
        DiffStrings.toolbarIgnoreCaption,
        DiffStrings.toolbarUndoCaption,
        DiffStrings.previousDifferenceCaption,
        DiffStrings.nextDifferenceCaption,
        DiffStrings.toolbarZoomInCaption,
        DiffStrings.toolbarZoomOutCaption,
        DiffStrings.toolbarClearCaption,
        DiffStrings.swapSidesCaption,
        DiffStrings.recompareCaption,
        DiffStrings.toolbarDiffMapCaption,
    ])
}

@MainActor
@Test func diffToolbarButtonsKeepSelectedStateAfterClick() {
    let toolbar = DiffToolbar()
    let buttons = Dictionary(uniqueKeysWithValues: diffToolbarButtons(in: toolbar).map { ($0.accessibilityLabel() ?? "", $0) })
    guard let whitespace = buttons[DiffStrings.toolbarWhitespace],
          let strict = buttons[DiffStrings.toolbarStrict],
          let ignore = buttons[DiffStrings.toolbarIgnore]
    else {
        Issue.record("Missing compare toolbar mode buttons")
        return
    }

    whitespace.performClick(nil)
    #expect(whitespace.state == .on)
    #expect(whitespace.isBordered)

    ignore.performClick(nil)
    #expect(ignore.state == .on)
    #expect(ignore.isBordered)
    #expect(strict.state == .off)

    strict.performClick(nil)
    #expect(strict.state == .on)
    #expect(strict.isBordered)
    #expect(ignore.state == .off)
}

@MainActor
@Test func diffToolbarHeightLeavesRoomForIconAndCaption() {
    let toolbar = DiffToolbar()
    let buttonHeights = diffToolbarButtons(in: toolbar).map(\.fittingSize.height)
    let tallestButton = buttonHeights.max() ?? 0

    #expect(DiffToolbar.barHeight >= tallestButton + 28)
    #expect(DiffToolbar.barHeight >= 84)
}

@MainActor
@Test func diffWindowLayoutsWhenShownBeforeComputeFinishes() async {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    try? await Task.sleep(for: .milliseconds(200))
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    #expect(controller.editorSplitHeightForTesting > 100)
    #expect(controller.editorPaneWidthForTesting > 100)
}

@MainActor
@Test func diffWindowShowsComparedTextInBothEditorPanes() async {
    let controller = DiffWindowController(
        left: "111\nleft-only",
        right: "112\nright-only",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    #expect(controller.leftEditorTextForTesting == "111\nleft-only")
    #expect(controller.rightEditorTextForTesting == "112\nright-only")
    #expect(controller.editorPaneWidthForTesting > 100)
    #expect(controller.editorSplitHeightForTesting > 100)
}

@MainActor
@Test func diffWindowKeepsDropReceiverBehindVisibleContent() async {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    #expect(controller.diffDropReceiverIsBehindContentForTesting)
}

@MainActor
@Test func diffWindowHostsChromeInTitlebarAccessory() async {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    #expect(controller.diffChromeUsesTitlebarAccessoryForTesting)
}

@MainActor
@Test func diffWindowHostsToolbarInTitlebarAccessory() async {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    #expect(controller.diffToolbarUsesTitlebarAccessoryForTesting)
}

@MainActor
@Test func diffWindowUsesScintillaPanesWhenAvailable() async {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    await controller.waitUntilReady()

    let expected = ScintillaEditorSurface.load() == nil ? "NSTextView" : "Scintilla"
    #expect(controller.leftEditorSurfaceNameForTesting == expected)
    #expect(controller.rightEditorSurfaceNameForTesting == expected)
}

@MainActor
@Test func diffWindowTextViewDocumentsReceiveVisibleFrames() async {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    #expect(controller.leftEditorDocumentSizeForTesting.width > 100)
    #expect(controller.leftEditorDocumentSizeForTesting.height > 10)
    #expect(controller.rightEditorDocumentSizeForTesting.width > 100)
    #expect(controller.rightEditorDocumentSizeForTesting.height > 10)
}

@MainActor
@Test func diffWindowSingleLineViewportUsesTextBackgroundBelowContent() async throws {
    let controller = DiffWindowController(
        left: "111",
        right: "112",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    let surfaceView = controller.leftEditorSurfaceViewForTesting
    surfaceView.layoutSubtreeIfNeeded()
    surfaceView.displayIfNeeded()
    guard let bitmap = surfaceView.bitmapImageRepForCachingDisplay(in: surfaceView.bounds) else {
        Issue.record("Could not create diff editor bitmap")
        return
    }
    surfaceView.cacheDisplay(in: surfaceView.bounds, to: bitmap)

    let sampleRect = NSRect(
        x: surfaceView.bounds.midX - 40,
        y: surfaceView.bounds.minY + 80,
        width: 80,
        height: surfaceView.bounds.height * 0.35
    )
    let greyCount = countGreyBackgroundPixels(in: bitmap, bounds: surfaceView.bounds, rect: sampleRect)
    #expect(greyCount < 5)
}

@MainActor
@Test func diffWindowRenderedEditorAreaContainsVisibleInk() async throws {
    let controller = DiffWindowController(
        left: "111\nleft-only",
        right: "112\nright-only",
        leftTitle: "新文件1",
        rightTitle: "新文件2"
    )
    controller.showWindow(nil)
    await controller.waitUntilReady()
    controller.finishWindowPresentation()
    controller.window?.layoutIfNeeded()

    guard let contentView = controller.window?.contentView else {
        Issue.record("Diff window has no content view")
        return
    }
    _ = contentView

    let editorContainerView = controller.editorContainerViewForTesting
    editorContainerView.displayIfNeeded()
    guard let bitmap = editorContainerView.bitmapImageRepForCachingDisplay(in: editorContainerView.bounds) else {
        Issue.record("Could not create diff editor bitmap")
        return
    }
    editorContainerView.cacheDisplay(in: editorContainerView.bounds, to: bitmap)

    let editorRect = editorContainerView.bounds.insetBy(dx: 20, dy: 20)
    #expect(countVisibleInkPixels(in: bitmap, bounds: editorContainerView.bounds, rect: editorRect) > 80)
}

@MainActor
@Test func textViewEditorSurfaceRendersTextInk() {
    let surface = TextViewEditorSurface()
    surface.view.frame = NSRect(x: 0, y: 0, width: 600, height: 320)
    surface.configureForDiff()
    surface.applyFont(size: 13)
    surface.text = "111\nline2"
    surface.refreshDisplayAfterLayout()

    surface.view.layoutSubtreeIfNeeded()
    surface.view.displayIfNeeded()
    guard let bitmap = surface.textView.bitmapImageRepForCachingDisplay(in: surface.textView.bounds) else {
        Issue.record("Could not create editor surface bitmap")
        return
    }
    surface.textView.cacheDisplay(in: surface.textView.bounds, to: bitmap)

    #expect(countVisibleInkPixels(in: bitmap, bounds: surface.textView.bounds, rect: surface.textView.bounds) > 10)
}

@MainActor
private func diffToolbarButtons(in view: NSView) -> [NSButton] {
    view.subviews.flatMap { subview -> [NSButton] in
        var buttons = diffToolbarButtons(in: subview)
        if let button = subview as? NSButton {
            buttons.insert(button, at: 0)
        }
        return buttons
    }
}

private func countVisibleInkPixels(
    in bitmap: NSBitmapImageRep,
    bounds: NSRect,
    rect: NSRect
) -> Int {
    let xStart = max(0, Int(rect.minX.rounded(.down)))
    let xEnd = min(bitmap.pixelsWide, Int(rect.maxX.rounded(.up)))
    let yStart = max(0, Int((bounds.height - rect.maxY).rounded(.down)))
    let yEnd = min(bitmap.pixelsHigh, Int((bounds.height - rect.minY).rounded(.up)))
    guard xStart < xEnd, yStart < yEnd else { return 0 }

    var count = 0
    for y in stride(from: yStart, to: yEnd, by: 4) {
        for x in stride(from: xStart, to: xEnd, by: 4) {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if color.alphaComponent > 0.1,
               color.redComponent < 0.96 || color.greenComponent < 0.96 || color.blueComponent < 0.96 {
                count += 1
            }
        }
    }
    return count
}

private func countGreyBackgroundPixels(
    in bitmap: NSBitmapImageRep,
    bounds: NSRect,
    rect: NSRect
) -> Int {
    let xStart = max(0, Int(rect.minX.rounded(.down)))
    let xEnd = min(bitmap.pixelsWide, Int(rect.maxX.rounded(.up)))
    let yStart = max(0, Int((bounds.height - rect.maxY).rounded(.down)))
    let yEnd = min(bitmap.pixelsHigh, Int((bounds.height - rect.minY).rounded(.up)))
    guard xStart < xEnd, yStart < yEnd else { return 0 }

    var count = 0
    for y in stride(from: yStart, to: yEnd, by: 3) {
        for x in stride(from: xStart, to: xEnd, by: 3) {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            let components = [color.redComponent, color.greenComponent, color.blueComponent]
            let spread = components.max()! - components.min()!
            let average = components.reduce(0, +) / 3
            if color.alphaComponent > 0.9,
               spread < 0.04,
               average > 0.82,
               average < 0.97 {
                count += 1
            }
        }
    }
    return count
}

@Test func defaultRightDocumentIndexSkipsLeftSelection() {
    #expect(AppDelegate.defaultRightDocumentIndex(leftIndex: 0, documentCount: 3) == 1)
    #expect(AppDelegate.defaultRightDocumentIndex(leftIndex: 2, documentCount: 3) == 0)
    #expect(AppDelegate.defaultRightDocumentIndex(leftIndex: 1, documentCount: 2) == 0)
}
