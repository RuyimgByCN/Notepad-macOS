import AppKit
import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Test func diffWindowControllerConstructsWithTwoTexts() {
    let controller = DiffWindowController(
        left: "a\nb\nc",
        right: "a\nX\nc",
        leftTitle: "Left.txt",
        rightTitle: "Right.txt"
    )
    // The result should detect the single changed line.
    #expect(controller.result.hunks.count == 1)
    #expect(controller.result.leftLines.count == controller.result.rightLines.count)
    #expect(controller.window != nil)
}

@MainActor
@Test func diffWindowControllerReportsIdenticalFiles() {
    let controller = DiffWindowController(
        left: "same\ncontent",
        right: "same\ncontent",
        leftTitle: "L",
        rightTitle: "R"
    )
    #expect(controller.result.isIdentical)
    #expect(controller.result.hunks.isEmpty)
}

@MainActor
@Test func diffWindowControllerSelectorsExist() {
    // The AppDelegate selectors must exist for the Search > Compare menu to dispatch.
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
