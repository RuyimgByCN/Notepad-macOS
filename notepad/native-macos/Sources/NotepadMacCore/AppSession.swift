import Foundation

public struct SessionCaretRecord: Codable, Equatable, Sendable {
    public let identity: EditorTabIdentity
    /// UTF-16 offset of the caret/insertion point.
    public let caretLocation: Int

    public init(identity: EditorTabIdentity, caretLocation: Int) {
        self.identity = identity.normalized
        self.caretLocation = caretLocation
    }
}

public struct SessionBookmarkRecord: Codable, Equatable, Sendable {
    public let identity: EditorTabIdentity
    public let bookmarks: BookmarkSet

    public init(identity: EditorTabIdentity, bookmarks: BookmarkSet) {
        self.identity = identity.normalized
        self.bookmarks = bookmarks
    }
}

public struct SessionSnapshotFileFallback: Equatable, Sendable {
    public let snapshotID: String
    public let fileURL: URL
    public let bookmarks: BookmarkSet
    public let folds: FoldState

    public init(
        snapshotID: String,
        fileURL: URL,
        bookmarks: BookmarkSet,
        folds: FoldState = FoldState()
    ) {
        self.snapshotID = snapshotID
        self.fileURL = fileURL.standardizedFileURL
        self.bookmarks = bookmarks
        self.folds = folds
    }
}

public struct SessionTabStateRecord: Codable, Equatable, Sendable {
    public let identity: EditorTabIdentity
    public let isPinned: Bool
    public let tabColorIndex: Int?

    public init(identity: EditorTabIdentity, isPinned: Bool, tabColorIndex: Int?) {
        self.identity = identity.normalized
        self.isPinned = isPinned
        self.tabColorIndex = tabColorIndex
    }
}

public struct AppSession: Codable, Equatable, Sendable {
    public static let empty = AppSession(openFiles: [], activeFile: nil)

    public let openFiles: [URL]
    public let snapshots: [DocumentSnapshot]
    public let activeFile: URL?
    public let activeSnapshotID: String?
    public let bookmarks: [SessionBookmarkRecord]
    public let folds: [SessionFoldRecord]
    public let tabStates: [SessionTabStateRecord]
    public let caretPositions: [SessionCaretRecord]

    public init(
        openFiles: [URL],
        activeFile: URL?,
        snapshots: [DocumentSnapshot] = [],
        activeSnapshotID: String? = nil,
        bookmarks: [SessionBookmarkRecord] = [],
        folds: [SessionFoldRecord] = [],
        tabStates: [SessionTabStateRecord] = [],
        caretPositions: [SessionCaretRecord] = []
    ) {
        var seen: Set<URL> = []
        let standardizedOpenFiles = openFiles.compactMap { url -> URL? in
            let standardized = url.standardizedFileURL
            return seen.insert(standardized).inserted ? standardized : nil
        }

        var seenSnapshots: Set<String> = []
        let normalizedSnapshots = snapshots.compactMap { snapshot -> DocumentSnapshot? in
            guard !snapshot.id.isEmpty, seenSnapshots.insert(snapshot.id).inserted else { return nil }
            return snapshot
        }
        let snapshotIDs = Set(normalizedSnapshots.map(\.id))
        let normalizedActiveSnapshotID = activeSnapshotID.flatMap { snapshotIDs.contains($0) ? $0 : nil }
        let validTabIdentities = Set(
            standardizedOpenFiles.map { EditorTabIdentity.file($0) }
                + normalizedSnapshots.map { EditorTabIdentity.snapshot($0.id) }
        )
        var seenBookmarkIdentities: Set<EditorTabIdentity> = []
        let normalizedBookmarks = bookmarks.compactMap { record -> SessionBookmarkRecord? in
            let normalized = SessionBookmarkRecord(identity: record.identity, bookmarks: record.bookmarks)
            guard validTabIdentities.contains(normalized.identity),
                  !normalized.bookmarks.isEmpty,
                  seenBookmarkIdentities.insert(normalized.identity).inserted
            else {
                return nil
            }
            return normalized
        }
        var seenFoldIdentities: Set<EditorTabIdentity> = []
        let normalizedFolds = folds.compactMap { record -> SessionFoldRecord? in
            let normalized = SessionFoldRecord(identity: record.identity, folds: record.folds)
            guard validTabIdentities.contains(normalized.identity),
                  !normalized.folds.isEmpty,
                  seenFoldIdentities.insert(normalized.identity).inserted
            else {
                return nil
            }
            return normalized
        }

        self.openFiles = standardizedOpenFiles
        self.snapshots = normalizedSnapshots
        self.activeSnapshotID = normalizedActiveSnapshotID ?? (standardizedOpenFiles.isEmpty ? normalizedSnapshots.first?.id : nil)
        self.bookmarks = normalizedBookmarks
        self.folds = normalizedFolds
        self.tabStates = tabStates.filter { validTabIdentities.contains($0.identity) }
        self.caretPositions = caretPositions.filter { validTabIdentities.contains($0.identity) }

        guard let first = standardizedOpenFiles.first else {
            self.activeFile = nil
            return
        }

        if self.activeSnapshotID != nil {
            self.activeFile = nil
            return
        }

        let standardizedActiveFile = activeFile?.standardizedFileURL
        self.activeFile = standardizedActiveFile.flatMap { standardizedOpenFiles.contains($0) ? $0 : nil } ?? first
    }

    public func bookmarkSet(for identity: EditorTabIdentity) -> BookmarkSet {
        bookmarks.first { $0.identity == identity.normalized }?.bookmarks ?? BookmarkSet()
    }

    public func foldState(for identity: EditorTabIdentity) -> FoldState {
        folds.first { $0.identity == identity.normalized }?.folds ?? FoldState()
    }

    public func tabState(for identity: EditorTabIdentity) -> SessionTabStateRecord? {
        tabStates.first { $0.identity == identity.normalized }
    }

    public func caretLocation(for identity: EditorTabIdentity) -> Int? {
        caretPositions.first { $0.identity == identity.normalized }?.caretLocation
    }

    public func snapshotFileFallbacks(missingSnapshotIDs: Set<String>) -> [SessionSnapshotFileFallback] {
        snapshots.compactMap { snapshot in
            guard missingSnapshotIDs.contains(snapshot.id),
                  let originalFile = snapshot.originalFile
            else {
                return nil
            }

            return SessionSnapshotFileFallback(
                snapshotID: snapshot.id,
                fileURL: originalFile,
                bookmarks: bookmarkSet(for: .snapshot(snapshot.id)),
                folds: foldState(for: .snapshot(snapshot.id))
            )
        }
    }
}

extension AppSession {
    private enum CodingKeys: String, CodingKey {
        case openFiles
        case snapshots
        case activeFile
        case activeSnapshotID
        case bookmarks
        case folds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            openFiles: try container.decodeIfPresent([URL].self, forKey: .openFiles) ?? [],
            activeFile: try container.decodeIfPresent(URL.self, forKey: .activeFile),
            snapshots: try container.decodeIfPresent([DocumentSnapshot].self, forKey: .snapshots) ?? [],
            activeSnapshotID: try container.decodeIfPresent(String.self, forKey: .activeSnapshotID),
            bookmarks: try container.decodeIfPresent([SessionBookmarkRecord].self, forKey: .bookmarks) ?? [],
            folds: try container.decodeIfPresent([SessionFoldRecord].self, forKey: .folds) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(openFiles, forKey: .openFiles)
        try container.encode(snapshots, forKey: .snapshots)
        try container.encodeIfPresent(activeFile, forKey: .activeFile)
        try container.encodeIfPresent(activeSnapshotID, forKey: .activeSnapshotID)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encode(folds, forKey: .folds)
    }
}

public final class SessionStore {
    private enum Key {
        static let openFiles = "notepadMac.session.openFiles"
        static let activeFile = "notepadMac.session.activeFile"
        static let snapshots = "notepadMac.session.snapshots"
        static let activeSnapshotID = "notepadMac.session.activeSnapshotID"
        static let bookmarks = "notepadMac.session.bookmarks"
        static let folds = "notepadMac.session.folds"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSession {
        let openFiles = defaults.stringArray(forKey: Key.openFiles)?
            .map { URL(fileURLWithPath: $0) } ?? []
        let activeFile = defaults.string(forKey: Key.activeFile)
            .map { URL(fileURLWithPath: $0) }
        let snapshots = (defaults.data(forKey: Key.snapshots))
            .flatMap { try? JSONDecoder().decode([DocumentSnapshot].self, from: $0) } ?? []
        let activeSnapshotID = defaults.string(forKey: Key.activeSnapshotID)
        let bookmarks = (defaults.data(forKey: Key.bookmarks))
            .flatMap { try? JSONDecoder().decode([SessionBookmarkRecord].self, from: $0) } ?? []
        let folds = (defaults.data(forKey: Key.folds))
            .flatMap { try? JSONDecoder().decode([SessionFoldRecord].self, from: $0) } ?? []

        return AppSession(
            openFiles: openFiles,
            activeFile: activeFile,
            snapshots: snapshots,
            activeSnapshotID: activeSnapshotID,
            bookmarks: bookmarks,
            folds: folds
        )
    }

    public func save(_ session: AppSession) {
        defaults.set(session.openFiles.map(\.path), forKey: Key.openFiles)
        defaults.set(session.activeFile?.path, forKey: Key.activeFile)
        defaults.set(session.activeSnapshotID, forKey: Key.activeSnapshotID)

        if session.snapshots.isEmpty {
            defaults.removeObject(forKey: Key.snapshots)
        } else if let data = try? JSONEncoder().encode(session.snapshots) {
            defaults.set(data, forKey: Key.snapshots)
        }

        if session.bookmarks.isEmpty {
            defaults.removeObject(forKey: Key.bookmarks)
        } else if let data = try? JSONEncoder().encode(session.bookmarks) {
            defaults.set(data, forKey: Key.bookmarks)
        }

        if session.folds.isEmpty {
            defaults.removeObject(forKey: Key.folds)
        } else if let data = try? JSONEncoder().encode(session.folds) {
            defaults.set(data, forKey: Key.folds)
        }

        defaults.synchronize()
    }

    public func clear() {
        defaults.removeObject(forKey: Key.openFiles)
        defaults.removeObject(forKey: Key.activeFile)
        defaults.removeObject(forKey: Key.snapshots)
        defaults.removeObject(forKey: Key.activeSnapshotID)
        defaults.removeObject(forKey: Key.bookmarks)
        defaults.removeObject(forKey: Key.folds)
        defaults.synchronize()
    }
}
