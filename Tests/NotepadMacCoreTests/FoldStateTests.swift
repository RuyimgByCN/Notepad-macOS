import Foundation
import Testing
@testable import NotepadMacCore

@Test func foldStateNormalizesCollapsedLines() {
    let state = FoldState(collapsedLines: [5, 0, 3, -1, 5, 1])

    #expect(state.collapsedLines == [1, 3, 5])
}

@Test func foldStateClampsToDocumentLineCount() {
    let state = FoldState(collapsedLines: [1, 3, 7])

    #expect(state.clamped(toLineCount: 3).collapsedLines == [1, 3])
    #expect(state.clamped(toLineCount: 0).isEmpty)
}

@Test func foldStateLooksUpCollapsedLines() {
    let state = FoldState(collapsedLines: [2, 4])

    #expect(state.isCollapsed(line: 2))
    #expect(!state.isCollapsed(line: 3))
    #expect(!state.isCollapsed(line: 0))
}

@Test func foldStateDecodesDirtyPayloadsThroughNormalizer() throws {
    let data = Data("""
    {
      "collapsedLines": [8, 2, 0, -1, 8]
    }
    """.utf8)

    let state = try JSONDecoder().decode(FoldState.self, from: data)

    #expect(state.collapsedLines == [2, 8])
}

@Test func sessionFoldRecordNormalizesIdentityAndLines() {
    let file = URL(filePath: "/tmp/one.txt")
    let duplicateFile = URL(filePath: "/tmp/../tmp/one.txt")

    let record = SessionFoldRecord(
        identity: .file(duplicateFile),
        folds: FoldState(collapsedLines: [4, 1, 4, -2])
    )

    #expect(record.identity == .file(file.standardizedFileURL))
    #expect(record.folds.collapsedLines == [1, 4])
}

@Test func appSessionFoldStateKeepsValidTabIdentities() {
    let first = URL(filePath: "/tmp/one.txt")
    let duplicateFirst = URL(filePath: "/tmp/../tmp/one.txt")
    let outside = URL(filePath: "/tmp/outside.txt")
    let snapshot = DocumentSnapshot(
        id: "draft-1",
        displayName: "new 1",
        originalFile: nil,
        backupFile: URL(filePath: "/tmp/backup/new 1@2026-06-01_120000-draft-1.bak"),
        encoding: .utf8,
        lineEnding: .lf
    )

    let session = AppSession(
        openFiles: [first],
        activeFile: first,
        snapshots: [snapshot],
        folds: [
            SessionFoldRecord(identity: .file(duplicateFirst), folds: FoldState(collapsedLines: [6, 2, 6])),
            SessionFoldRecord(identity: .snapshot("draft-1"), folds: FoldState(collapsedLines: [3])),
            SessionFoldRecord(identity: .file(outside), folds: FoldState(collapsedLines: [9])),
            SessionFoldRecord(identity: .snapshot("missing"), folds: FoldState(collapsedLines: [4])),
            SessionFoldRecord(identity: .file(first), folds: FoldState())
        ]
    )

    #expect(session.folds == [
        SessionFoldRecord(identity: .file(first), folds: FoldState(collapsedLines: [2, 6])),
        SessionFoldRecord(identity: .snapshot("draft-1"), folds: FoldState(collapsedLines: [3]))
    ])
    #expect(session.foldState(for: .file(first)).collapsedLines == [2, 6])
    #expect(session.foldState(for: .snapshot("draft-1")).collapsedLines == [3])
    #expect(session.foldState(for: .file(outside)).isEmpty)
}

@Test func appSessionFoldStateDecodesOlderSessionsWithoutFoldRecords() throws {
    let data = Data("""
    {
      "openFiles": [
        "file:///tmp/one.txt"
      ],
      "snapshots": [],
      "activeFile": "file:///tmp/one.txt",
      "activeSnapshotID": null,
      "bookmarks": []
    }
    """.utf8)

    let session = try JSONDecoder().decode(AppSession.self, from: data)

    #expect(session.openFiles == [URL(filePath: "/tmp/one.txt").standardizedFileURL])
    #expect(session.folds.isEmpty)
    #expect(session.foldState(for: .file(URL(filePath: "/tmp/one.txt"))).isEmpty)
}

@Test func sessionStorePersistsFoldState() throws {
    let suiteName = "NotepadMacCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = URL(filePath: "/tmp/one.txt")
    let store = SessionStore(defaults: defaults)
    let saved = AppSession(
        openFiles: [first],
        activeFile: first,
        folds: [
            SessionFoldRecord(identity: .file(first), folds: FoldState(collapsedLines: [8, 2, 8]))
        ]
    )

    store.save(saved)

    #expect(store.load() == saved)
}
