import Foundation

public enum WorkspaceDetailColumn: String, CaseIterable, Codable, Sendable {
    case size
    case type
    case dateModified
}

public struct WorkspacePanelSettings: Equatable, Sendable {
    public var showHiddenFiles: Bool
    public var visibleDetailColumns: Set<WorkspaceDetailColumn>

    public init(
        showHiddenFiles: Bool = false,
        visibleDetailColumns: Set<WorkspaceDetailColumn> = []
    ) {
        self.showHiddenFiles = showHiddenFiles
        self.visibleDetailColumns = visibleDetailColumns
    }
}

public struct WorkspacePanelSettingsStore: @unchecked Sendable {
    public static let showHiddenFilesKey = "notepadMac.workspace.showHiddenFiles"
    public static let visibleDetailColumnsKey = "notepadMac.workspace.visibleDetailColumns"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> WorkspacePanelSettings {
        let columns = defaults.stringArray(forKey: Self.visibleDetailColumnsKey) ?? []
        return WorkspacePanelSettings(
            showHiddenFiles: defaults.bool(forKey: Self.showHiddenFilesKey),
            visibleDetailColumns: Set(columns.compactMap(WorkspaceDetailColumn.init(rawValue:)))
        )
    }

    public func setShowHiddenFiles(_ showHiddenFiles: Bool) {
        defaults.set(showHiddenFiles, forKey: Self.showHiddenFilesKey)
    }

    public func setVisibleDetailColumns(_ columns: Set<WorkspaceDetailColumn>) {
        defaults.set(columns.map(\.rawValue).sorted(), forKey: Self.visibleDetailColumnsKey)
    }
}
