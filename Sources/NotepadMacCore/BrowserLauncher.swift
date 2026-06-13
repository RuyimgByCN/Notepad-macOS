import Foundation

/// Detection of installed web browsers for the "Launch in Browser" submenu.
///
/// Mirrors upstream Notepad++ `IDM_VIEW_IN_FIREFOX / _CHROME / _EDGE / _IE`,
/// adapted to macOS: browsers are identified by bundle identifier, and the
/// installed subset is offered as menu items. Internet Explorer is omitted
/// because it does not exist on macOS.
public enum BrowserLauncher {
    /// A discoverable browser: a localized display name and the macOS bundle
    /// identifier used to resolve the application.
    public struct Browser: Equatable, Sendable {
        public let displayName: String
        public let bundleIdentifier: String

        public init(displayName: String, bundleIdentifier: String) {
            self.displayName = displayName
            self.bundleIdentifier = bundleIdentifier
        }
    }

    /// Browser candidates ordered to echo the upstream View menu
    /// (Firefox, Chrome, Edge) first, followed by other common macOS browsers.
    public static let candidates: [Browser] = [
        Browser(displayName: "Mozilla Firefox", bundleIdentifier: "org.mozilla.firefox"),
        Browser(displayName: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        Browser(displayName: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
        Browser(displayName: "Safari", bundleIdentifier: "com.apple.Safari"),
        Browser(displayName: "Brave", bundleIdentifier: "com.brave.Browser"),
        Browser(displayName: "Arc", bundleIdentifier: "company.thebrowser.Browser"),
        Browser(displayName: "Opera", bundleIdentifier: "com.operasoftware.Opera"),
        Browser(displayName: "Chromium", bundleIdentifier: "org.chromium.Chromium"),
        Browser(displayName: "Vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi"),
    ]

    /// Bundle identifiers for the upstream Notepad++ browser targets that have
    /// a macOS equivalent (Firefox, Chrome, Edge). Used to assert upstream
    /// parity in tests.
    public static let upstreamBrowserBundleIdentifiers: Set<String> = [
        "org.mozilla.firefox",
        "com.google.Chrome",
        "com.microsoft.edgemac",
    ]

    /// Returns the subset of `candidates` whose bundle identifier resolves to
    /// an installed application, evaluated through `bundleExists`. The
    /// predicate is injected so the filtering logic can be unit-tested without
    /// a real `NSWorkspace`.
    public static func installedBrowsers(
        bundleExists: (String) -> Bool
    ) -> [Browser] {
        candidates.filter { bundleExists($0.bundleIdentifier) }
    }
}
