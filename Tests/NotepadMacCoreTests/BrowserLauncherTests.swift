import XCTest
@testable import NotepadMacCore

final class BrowserLauncherTests: XCTestCase {
    func testCandidatesHaveNoDuplicateBundleIdentifiers() {
        let bundleIDs = BrowserLauncher.candidates.map(\.bundleIdentifier)
        XCTAssertEqual(bundleIDs.count, Set(bundleIDs).count,
                       "Browser candidates must not repeat a bundle identifier")
    }

    func testCandidatesHaveNoDuplicateDisplayNames() {
        let names = BrowserLauncher.candidates.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count,
                       "Browser candidates must not repeat a display name")
    }

    func testCandidatesCoverUpstreamBrowserTargets() {
        // Upstream Notepad++ offers Firefox, Chrome, Edge, IE. IE has no macOS
        // equivalent, so the remaining three must all be discoverable.
        let candidateBundleIDs = Set(BrowserLauncher.candidates.map(\.bundleIdentifier))
        for upstream in BrowserLauncher.upstreamBrowserBundleIdentifiers {
            XCTAssertTrue(candidateBundleIDs.contains(upstream),
                          "Missing upstream browser target \(upstream)")
        }
    }

    func testInstalledBrowsersFiltersByInjectedPredicate() {
        let installed = BrowserLauncher.installedBrowsers { bundleID in
            bundleID == "com.apple.Safari" || bundleID == "org.mozilla.firefox"
        }

        XCTAssertEqual(Set(installed.map(\.bundleIdentifier)),
                       ["com.apple.Safari", "org.mozilla.firefox"])
    }

    func testInstalledBrowsersReturnsEmptyWhenNoneInstalled() {
        let installed = BrowserLauncher.installedBrowsers { _ in false }
        XCTAssertTrue(installed.isEmpty)
    }

    func testInstalledBrowsersReturnsAllWhenAllInstalled() {
        let installed = BrowserLauncher.installedBrowsers { _ in true }
        XCTAssertEqual(installed.count, BrowserLauncher.candidates.count)
    }

    func testInstalledBrowsersPreservesCandidateOrder() {
        // Only every other candidate is "installed"; ordering must match the
        // candidate declaration order, not the predicate's evaluation order.
        let everyOther = Set(BrowserLauncher.candidates.enumerated()
            .filter { $0.offset.isMultiple(of: 2) }
            .map { $0.element.bundleIdentifier })
        let installed = BrowserLauncher.installedBrowsers { everyOther.contains($0) }

        XCTAssertEqual(installed.map(\.bundleIdentifier),
                       BrowserLauncher.candidates
                        .filter { everyOther.contains($0.bundleIdentifier) }
                        .map(\.bundleIdentifier))
    }
}
