import Foundation
import NotepadMacCore
import Testing

// MARK: - PluginRepositoryError localized descriptions

/// Regression: `PluginRepositoryError` used to fall back to Cocoa's default
/// NSError bridge, so a failed download surfaced as the opaque
/// "PluginRepositoryError error 1." instead of the underlying HTTP reason.
/// These tests pin the readable `LocalizedError` descriptions.

@Test func pluginRepositoryErrorDownloadFailedSurfacesReason() {
    let error = PluginRepositoryError.downloadFailed(identifier: "urlplugin", reason: "HTTP 404")
    let description = error.localizedDescription
    #expect(description.contains("HTTP 404"), "reason must be visible — got: \(description)")
    #expect(description.contains("urlplugin"), "identifier must be visible — got: \(description)")
    #expect(!description.contains("error 1"), "must not fall back to opaque NSError bridge — got: \(description)")
}

@Test func pluginRepositoryErrorMissingRepositoryURLSurfacesIdentifier() {
    let error = PluginRepositoryError.missingRepositoryURL(identifier: "dark_mode_c")
    let description = error.localizedDescription
    #expect(description.contains("dark_mode_c"), "identifier must be visible — got: \(description)")
    #expect(!description.contains("error 0"), "must not fall back to opaque NSError bridge — got: \(description)")
}

@Test func pluginRepositoryErrorUserPluginDirectoryUnavailableIsReadable() {
    let error = PluginRepositoryError.userPluginDirectoryUnavailable
    let description = error.localizedDescription
    #expect(!description.contains("error 2"), "must not fall back to opaque NSError bridge — got: \(description)")
    #expect(!description.isEmpty)
}

// MARK: - installFromRepository integration with a stubbed HTTP transport

/// Replies to every request with a fixed status code / body, so the download
/// path can be exercised without hitting the network.
private final class StubResponseURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var body: Data = Data("payload".utf8)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubResponseURLProtocol.self]
    return URLSession(configuration: config)
}

@MainActor
private func makeTemporaryUserPluginDirectory() throws -> URL {
    let url = URL(filePath: NSTemporaryDirectory())
        .appending(path: "NotepadMacPluginRepoTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
@Test func installFromRepositoryReportsReadableErrorOnHTTP404() async throws {
    StubResponseURLProtocol.statusCode = 404
    let entry = PluginRepositoryEntry(
        identifier: "urlplugin",
        name: "URL Encode/Decode Plugin",
        version: "1.0.0",
        repository: "https://example.invalid/urlplugin-1.0.0.zip"
    )
    let userDir = try makeTemporaryUserPluginDirectory()
    defer { try? FileManager.default.removeItem(at: userDir) }

    do {
        _ = try await PluginRepository.installFromRepository(
            entry: entry, into: userDir, session: makeStubbedSession())
        Issue.record("installFromRepository should have thrown for HTTP 404")
    } catch let error as PluginRepositoryError {
        guard case let .downloadFailed(identifier, reason) = error else {
            Issue.record("expected .downloadFailed — got: \(error)")
            return
        }
        #expect(identifier == "urlplugin")
        #expect(reason.contains("404"))
        #expect(error.localizedDescription.contains("404"))
    } catch {
        Issue.record("expected PluginRepositoryError — got: \(error)")
    }
}

@MainActor
@Test func installFromRepositoryReportsReadableErrorWhenUserDirMissing() async {
    let entry = PluginRepositoryEntry(
        identifier: "urlplugin",
        name: "URL Encode/Decode Plugin",
        repository: "https://example.invalid/urlplugin-1.0.0.zip"
    )
    do {
        _ = try await PluginRepository.installFromRepository(
            entry: entry, into: nil, session: makeStubbedSession())
        Issue.record("installFromRepository should have thrown without a user plugin directory")
    } catch let error as PluginRepositoryError {
        guard case .userPluginDirectoryUnavailable = error else {
            Issue.record("expected .userPluginDirectoryUnavailable — got: \(error)")
            return
        }
    } catch {
        Issue.record("expected PluginRepositoryError — got: \(error)")
    }
}

@MainActor
@Test func installFromRepositoryReportsReadableErrorWhenRepositoryMissing() async throws {
    let entry = PluginRepositoryEntry(
        identifier: "dark_mode_c",
        name: "Dark Mode C",
        repository: nil
    )
    let userDir = try makeTemporaryUserPluginDirectory()
    defer { try? FileManager.default.removeItem(at: userDir) }

    do {
        _ = try await PluginRepository.installFromRepository(
            entry: entry, into: userDir, session: makeStubbedSession())
        Issue.record("installFromRepository should have thrown without a repository URL")
    } catch let error as PluginRepositoryError {
        guard case .missingRepositoryURL = error else {
            Issue.record("expected .missingRepositoryURL — got: \(error)")
            return
        }
    } catch {
        Issue.record("expected PluginRepositoryError — got: \(error)")
    }
}

// MARK: - compare() availability filtering

@Test func compareExcludesEntriesWithoutRepositoryURL() {
    let remote = PluginRepositoryCatalog(plugins: [
        PluginRepositoryEntry(
            identifier: "has-url", name: "A", version: "1.0.0",
            repository: "https://example.invalid/a.zip", upstreamWindowsDLL: false
        ),
        PluginRepositoryEntry(
            identifier: "no-url", name: "B",
            repository: nil, upstreamWindowsDLL: false
        ),
        PluginRepositoryEntry(
            identifier: "empty-url", name: "C",
            repository: "", upstreamWindowsDLL: false
        ),
        PluginRepositoryEntry(
            identifier: "win-dll", name: "D", version: "1.0.0",
            repository: "https://example.invalid/d.zip", upstreamWindowsDLL: true
        ),
    ])
    let result = PluginRepository.compare(remote: remote, installed: PluginCatalog(plugins: []))
    #expect(result.available.map(\.identifier) == ["has-url"])
    #expect(result.updates.isEmpty)
}
