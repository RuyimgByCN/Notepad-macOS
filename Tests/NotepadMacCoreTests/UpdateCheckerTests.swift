import Foundation
import Testing
@testable import NotepadMacCore

// MARK: - Version parsing and comparison

@Test func appVersionParsesPlainAndPrefixedForms() throws {
    #expect(AppVersion("1.2.3")?.components == [1, 2, 3])
    #expect(AppVersion("v2.0")?.components == [2, 0])
    #expect(AppVersion("3")?.components == [3])
    #expect(AppVersion("1.2.3-beta")?.isPrerelease == true)
    #expect(AppVersion("1.2.3+45")?.isPrerelease == false)
    #expect(AppVersion("") == nil)
    #expect(AppVersion("abc") == nil)
    #expect(AppVersion("1..2") == nil)
}

@Test func appVersionComparesNumericallyWithMissingComponentsAsZero() throws {
    let table: [(String, String, Bool)] = [
        ("1.0", "1.0.0", false),  // equal, not less
        ("1.0", "1.0.1", true),
        ("1.9", "1.10", true),
        ("2.0", "10.0", true),
        ("1.2.3", "1.2.3", false),
        ("0.9.9", "1.0", true),
    ]
    for (left, right, expectLess) in table {
        let lhs = try #require(AppVersion(left))
        let rhs = try #require(AppVersion(right))
        #expect((lhs < rhs) == expectLess, "\(left) < \(right)")
    }
    // Pre-release sorts before the matching final release.
    let pre = try #require(AppVersion("1.2.3-rc1"))
    let final = try #require(AppVersion("1.2.3"))
    #expect(pre < final)
}

// MARK: - Feed URL

@Test func releasesAPIURLRequiresOwnerSlashRepo() throws {
    #expect(
        UpdateChecker.releasesAPIURL(repositorySlug: "owner/repo")?.absoluteString
            == "https://api.github.com/repos/owner/repo/releases?per_page=20"
    )
    #expect(UpdateChecker.releasesAPIURL(repositorySlug: "owner") == nil)
    #expect(UpdateChecker.releasesAPIURL(repositorySlug: "owner/") == nil)
    #expect(UpdateChecker.releasesAPIURL(repositorySlug: "/repo") == nil)
    #expect(UpdateChecker.releasesAPIURL(repositorySlug: "") == nil)
}

// MARK: - Feed decoding

private let sampleFeed = """
[
  {
    "tag_name": "v1.4.0",
    "name": "Notepad++ Mac 1.4.0",
    "html_url": "https://github.com/owner/repo/releases/tag/v1.4.0",
    "draft": false,
    "prerelease": false,
    "assets": [
      {"name": "Notepad++ Mac.dmg", "browser_download_url": "https://github.com/owner/repo/releases/download/v1.4.0/Notepad%2B%2B%20Mac.dmg"},
      {"name": "symbols.zip", "browser_download_url": "https://example.com/symbols.zip"}
    ]
  },
  {
    "tag_name": "v1.5.0-rc1",
    "name": "RC",
    "html_url": "https://github.com/owner/repo/releases/tag/v1.5.0-rc1",
    "draft": false,
    "prerelease": true,
    "assets": []
  },
  {
    "tag_name": "v9.9.9",
    "name": "Draft",
    "html_url": null,
    "draft": true,
    "prerelease": false,
    "assets": []
  }
]
"""

@Test func decodeReleasesReadsTagsAssetsAndFlags() throws {
    let releases = try UpdateChecker.decodeReleases(from: Data(sampleFeed.utf8))
    #expect(releases.count == 3)
    #expect(releases[0].tagName == "v1.4.0")
    #expect(releases[0].dmgAssetURL?.absoluteString.hasSuffix(".dmg") == true)
    #expect(releases[1].isPrerelease)
    #expect(releases[2].isDraft)
}

@Test func decodeReleasesRejectsNonArrayPayload() throws {
    #expect(throws: UpdateCheckError.invalidFeedData) {
        _ = try UpdateChecker.decodeReleases(from: Data("{\"message\":\"Not Found\"}".utf8))
    }
}

// MARK: - Evaluation

@Test func evaluateReportsUpdateWhenNewerReleaseExists() throws {
    let releases = try UpdateChecker.decodeReleases(from: Data(sampleFeed.utf8))
    let outcome = try UpdateChecker.evaluate(currentVersion: "1.3.0", releases: releases)
    guard case .updateAvailable(let release) = outcome else {
        Issue.record("expected updateAvailable, got \(outcome)")
        return
    }
    #expect(release.tagName == "v1.4.0")  // draft + prerelease excluded
}

@Test func evaluateReportsUpToDateForEqualOrNewerCurrentVersion() throws {
    let releases = try UpdateChecker.decodeReleases(from: Data(sampleFeed.utf8))
    #expect(try UpdateChecker.evaluate(currentVersion: "1.4.0", releases: releases) == .upToDate)
    #expect(try UpdateChecker.evaluate(currentVersion: "2.0", releases: releases) == .upToDate)
}

@Test func evaluateIncludesPrereleasesOnlyWhenRequested() throws {
    let releases = try UpdateChecker.decodeReleases(from: Data(sampleFeed.utf8))
    let outcome = try UpdateChecker.evaluate(
        currentVersion: "1.4.0", releases: releases, includePrereleases: true
    )
    guard case .updateAvailable(let release) = outcome else {
        Issue.record("expected updateAvailable, got \(outcome)")
        return
    }
    #expect(release.tagName == "v1.5.0-rc1")
}

@Test func evaluateReportsNoPublishedReleasesForEmptyOrDraftOnlyFeeds() throws {
    #expect(try UpdateChecker.evaluate(currentVersion: "1.0", releases: []) == .noPublishedReleases)
    let draftOnly = [
        UpdateRelease(
            tagName: "v2.0", name: nil, htmlURL: nil,
            isDraft: true, isPrerelease: false, dmgAssetURL: nil
        )
    ]
    #expect(
        try UpdateChecker.evaluate(currentVersion: "1.0", releases: draftOnly)
            == .noPublishedReleases
    )
}

@Test func evaluateThrowsWhenCurrentVersionIsUnparsable() throws {
    let releases = try UpdateChecker.decodeReleases(from: Data(sampleFeed.utf8))
    #expect(throws: UpdateCheckError.noParsableVersion(tag: "Dev")) {
        _ = try UpdateChecker.evaluate(currentVersion: "Dev", releases: releases)
    }
}

// MARK: - Proxy settings

@Test func updaterProxySettingsBuildConnectionDictionaryOnlyWhenUsable() throws {
    var settings = UpdaterProxySettings(isEnabled: true, host: "proxy.local", port: 3128)
    let dict = try #require(settings.connectionProxyDictionary)
    #expect(dict["HTTPProxy"] as? String == "proxy.local")
    #expect(dict["HTTPSPort"] as? Int == 3128)

    settings.isEnabled = false
    #expect(settings.connectionProxyDictionary == nil)
    settings.isEnabled = true
    settings.host = "   "
    #expect(settings.connectionProxyDictionary == nil)
    settings.host = "proxy.local"
    settings.port = 0
    #expect(settings.connectionProxyDictionary == nil)
}

@Test func updaterProxyStoreRoundTripsSettings() throws {
    let suite = "UpdateCheckerTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = UpdaterProxyStore(defaults: defaults)
    #expect(store.load() == UpdaterProxySettings())

    let saved = UpdaterProxySettings(isEnabled: true, host: "127.0.0.1", port: 8888)
    store.save(saved)
    #expect(store.load() == saved)
}
