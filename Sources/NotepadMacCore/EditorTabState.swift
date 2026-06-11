import Foundation

public enum EditorTabIdentity: Codable, Equatable, Hashable, Sendable {
    case file(URL)
    case snapshot(String)
    case untitled(String)

    public var normalized: EditorTabIdentity {
        switch self {
        case let .file(url):
            .file(url.standardizedFileURL)
        case let .snapshot(id):
            .snapshot(id)
        case let .untitled(id):
            .untitled(id)
        }
    }
}

public struct EditorTabItem: Codable, Equatable, Sendable {
    public let identity: EditorTabIdentity
    public let title: String
    public let isDirty: Bool
    public let isPinned: Bool
    public let tabColorIndex: Int?

    public let isMonitoring: Bool

    public init(
        identity: EditorTabIdentity,
        title: String,
        isDirty: Bool = false,
        isPinned: Bool = false,
        tabColorIndex: Int? = nil,
        isMonitoring: Bool = false
    ) {
        self.identity = identity.normalized
        self.title = title
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.tabColorIndex = tabColorIndex
        self.isMonitoring = isMonitoring
    }
}

public struct EditorTabState: Codable, Equatable, Sendable {
    public let items: [EditorTabItem]
    public let activeIdentity: EditorTabIdentity?

    public init(items: [EditorTabItem] = [], activeIdentity: EditorTabIdentity? = nil) {
        var seen: Set<EditorTabIdentity> = []
        var normalizedItems: [EditorTabItem] = []

        for item in items {
            let normalizedItem = Self.normalizedItem(item)
            guard seen.insert(normalizedItem.identity).inserted else { continue }
            normalizedItems.append(normalizedItem)
        }

        self.items = normalizedItems

        let normalizedActive = activeIdentity?.normalized
        if let normalizedActive, seen.contains(normalizedActive) {
            self.activeIdentity = normalizedActive
        } else {
            self.activeIdentity = normalizedItems.first?.identity
        }
    }

    public func adding(_ item: EditorTabItem, activate: Bool = true) -> EditorTabState {
        let normalizedItem = Self.normalizedItem(item)
        let nextItems = items.contains(where: { $0.identity == normalizedItem.identity })
            ? items
            : items + [normalizedItem]
        let nextActive = activate ? normalizedItem.identity : activeIdentity
        return EditorTabState(items: nextItems, activeIdentity: nextActive)
    }

    public func removing(_ identity: EditorTabIdentity) -> EditorTabState {
        let normalizedIdentity = identity.normalized
        guard let removedIndex = items.firstIndex(where: { $0.identity == normalizedIdentity }) else {
            return self
        }

        var nextItems = items
        nextItems.remove(at: removedIndex)

        guard activeIdentity == normalizedIdentity else {
            return EditorTabState(items: nextItems, activeIdentity: activeIdentity)
        }

        if nextItems.isEmpty {
            return EditorTabState()
        }

        let replacementIndex = min(removedIndex, nextItems.count - 1)
        return EditorTabState(items: nextItems, activeIdentity: nextItems[replacementIndex].identity)
    }

    private static func normalizedItem(_ item: EditorTabItem) -> EditorTabItem {
        EditorTabItem(
            identity: item.identity,
            title: item.title,
            isDirty: item.isDirty,
            isPinned: item.isPinned,
            tabColorIndex: item.tabColorIndex,
            isMonitoring: item.isMonitoring
        )
    }
}
