import Foundation

public struct SavedRunCommand: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var commandLine: String

    public init(id: UUID = UUID(), name: String, commandLine: String) {
        self.id = id
        self.name = name
        self.commandLine = commandLine
    }
}

public final class SavedRunCommandStore {
    private enum Key {
        static let commands = "notepadMac.savedRunCommands"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [SavedRunCommand] {
        guard let data = defaults.data(forKey: Key.commands),
              let commands = try? decoder.decode([SavedRunCommand].self, from: data)
        else { return [] }
        return commands
    }

    public func save(_ commands: [SavedRunCommand]) {
        guard let data = try? encoder.encode(commands) else { return }
        defaults.set(data, forKey: Key.commands)
        defaults.synchronize()
    }

    public func add(_ command: SavedRunCommand) {
        var commands = load()
        commands.removeAll { $0.name == command.name }
        commands.append(command)
        save(commands)
    }

    public func remove(id: UUID) {
        var commands = load()
        commands.removeAll { $0.id == id }
        save(commands)
    }

    public func update(_ command: SavedRunCommand) {
        var commands = load()
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
        } else {
            commands.append(command)
        }
        save(commands)
    }
}
