import Foundation

/// Persists Folder-as-Workspace / file-browser outline expand/collapse paths
/// per root folder, matching upstream Notepad++ 8.9.7 FaW session behavior.
public struct WorkspaceExpandStateStore: @unchecked Sendable {
    public static let defaultsKey = "notepadMac.workspaceExpandedPathsByRoot"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Expanded node paths for a workspace root (absolute paths preferred).
    public func expandedPaths(forRoot rootPath: String) -> Set<String> {
        let key = normalizeRoot(rootPath)
        guard !key.isEmpty else { return [] }
        let table = loadTable()
        return Set(table[key] ?? [])
    }

    public func setExpandedPaths(_ paths: Set<String>, forRoot rootPath: String) {
        let key = normalizeRoot(rootPath)
        guard !key.isEmpty else { return }
        var table = loadTable()
        if paths.isEmpty {
            table.removeValue(forKey: key)
        } else {
            table[key] = paths.sorted()
        }
        saveTable(table)
    }

    public func clearAll() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func loadTable() -> [String: [String]] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            // Legacy: plain dictionary written via set(_:forKey:)
            if let dict = defaults.dictionary(forKey: Self.defaultsKey) as? [String: [String]] {
                return dict
            }
            return [:]
        }
        return decoded
    }

    private func saveTable(_ table: [String: [String]]) {
        if let data = try? JSONEncoder().encode(table) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    private func normalizeRoot(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
