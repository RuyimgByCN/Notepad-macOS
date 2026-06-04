import Foundation
import Testing
@testable import NotepadMacCore

@Test func urlScannerFindsHttpLinks() {
    let text = "Visit https://example.com and http://foo.bar/path?q=1"
    let ranges = URLScanner.findURLRanges(in: text)
    #expect(ranges.count == 2)
    let nsText = text as NSString
    #expect(nsText.substring(with: ranges[0]) == "https://example.com")
    #expect(nsText.substring(with: ranges[1]) == "http://foo.bar/path?q=1")
}

@Test func urlScannerFindsFtpLinks() {
    let text = "Download from ftp://files.example.com/pub/file.tar.gz"
    let ranges = URLScanner.findURLRanges(in: text)
    #expect(ranges.count == 1)
    let nsText = text as NSString
    #expect(nsText.substring(with: ranges[0]).hasPrefix("ftp://"))
}

@Test func urlScannerFindsSshLinks() {
    let text = "Connect via ssh://user@host.example.com:22"
    let ranges = URLScanner.findURLRanges(in: text)
    #expect(ranges.count == 1)
}

@Test func urlScannerFindsMailtoLinks() {
    let text = "Email us at mailto:support@example.com for help"
    let ranges = URLScanner.findURLRanges(in: text)
    #expect(ranges.count == 1)
    let nsText = text as NSString
    #expect(nsText.substring(with: ranges[0]) == "mailto:support@example.com")
}

@Test func urlScannerFindsCustomSchemes() {
    let text = "myapp://open?path=/foo slack://workspace/channel"
    let custom = URLScanner.defaultSchemes + ["myapp", "slack"]
    let ranges = URLScanner.findURLRanges(in: text, schemes: custom)
    #expect(ranges.count == 2)
}

@Test func urlScannerIgnoresUnknownSchemes() {
    let text = "unknown://thing should not match"
    let ranges = URLScanner.findURLRanges(in: text)
    #expect(ranges.isEmpty)
}

@Test func urlScannerHandlesEmptyText() {
    #expect(URLScanner.findURLRanges(in: "").isEmpty)
}

@Test func urlScannerStopsAtWhitespace() {
    let text = "See https://example.com/path here"
    let ranges = URLScanner.findURLRanges(in: text)
    #expect(ranges.count == 1)
    let nsText = text as NSString
    let found = nsText.substring(with: ranges[0])
    #expect(!found.hasSuffix(" here"))
    #expect(found == "https://example.com/path")
}

@Test func appPreferencesEffectiveURLSchemes() {
    let prefs = AppPreferences(extraURLSchemes: "myapp slack")
    let schemes = prefs.effectiveURLSchemes
    #expect(schemes.contains("https"))
    #expect(schemes.contains("myapp"))
    #expect(schemes.contains("slack"))
}

@Test func appPreferencesDefaultSchemesWhenEmpty() {
    let prefs = AppPreferences(extraURLSchemes: "")
    #expect(prefs.effectiveURLSchemes == URLScanner.defaultSchemes)
}
