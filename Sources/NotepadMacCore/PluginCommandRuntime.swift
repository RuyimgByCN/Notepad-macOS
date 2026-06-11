import Foundation

public struct PluginCommandSelectionContext: Equatable, Sendable {
    public let utf16Location: Int
    public let utf16Length: Int
    public let text: String

    public init(utf16Location: Int, utf16Length: Int, text: String) {
        self.utf16Location = max(0, utf16Location)
        self.utf16Length = max(0, utf16Length)
        self.text = text
    }

    public init(utf16Range: NSRange, text: String) {
        self.init(
            utf16Location: utf16Range.location,
            utf16Length: utf16Range.length,
            text: text
        )
    }
}

public struct PluginCommandInvocation: Equatable, Sendable {
    public let pluginIdentifier: String
    public let commandIdentifier: String
    public let arguments: [String]
    public let environment: [String: String]
    public let documentURL: URL?
    public let selection: PluginCommandSelectionContext?
    /// Host-provided writable path where the plugin may leave a
    /// `PluginEditScript` JSON payload for the host to apply after exit.
    public let editScriptFileURL: URL?

    public init(
        pluginIdentifier: String,
        commandIdentifier: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        documentURL: URL? = nil,
        selection: PluginCommandSelectionContext? = nil,
        editScriptFileURL: URL? = nil
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.commandIdentifier = commandIdentifier
        self.arguments = arguments
        self.environment = environment
        self.documentURL = documentURL
        self.selection = selection
        self.editScriptFileURL = editScriptFileURL
    }
}

public struct PluginCommandProcessPlan: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]

    public init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]
    ) {
        self.executableURL = executableURL.standardizedFileURL
        self.arguments = arguments
        self.environment = environment
    }

    public func makeProcess() -> Process {
        let process = Process()
        process.executableURL = Self.shellURL
        process.arguments = Self.wrapperArguments(executableURL: executableURL, arguments: arguments)
        process.environment = environment
        return process
    }

    private static let shellURL = URL(fileURLWithPath: "/bin/sh")

    private static func wrapperArguments(executableURL: URL, arguments: [String]) -> [String] {
        ["-c", processTreeWrapperScript, executableURL.path] + arguments
    }

    private static let processTreeWrapperScript = """
    child=

    terminate_descendants() {
        parent="$1"
        signal="$2"
        for pid in $(/usr/bin/pgrep -P "$parent" 2>/dev/null); do
            terminate_descendants "$pid" "$signal"
            /bin/kill -"$signal" "$pid" 2>/dev/null || true
        done
    }

    forward_signal() {
        signal="$1"
        if [ -n "$child" ]; then
            terminate_descendants "$child" "$signal"
            /bin/kill -"$signal" "$child" 2>/dev/null || true
            wait "$child"
            status=$?
            exit "$status"
        fi
        exit 128
    }

    trap 'forward_signal TERM' TERM
    trap 'forward_signal INT' INT

    "$0" "$@" &
    child=$!
    wait "$child"
    status=$?
    exit "$status"
    """
}

public struct PluginCommandResult: Equatable, Sendable {
    public let plugin: PluginDescriptor
    public let command: PluginCommandDescriptor
    public let processPlan: PluginCommandProcessPlan

    public init(
        plugin: PluginDescriptor,
        command: PluginCommandDescriptor,
        processPlan: PluginCommandProcessPlan
    ) {
        self.plugin = plugin
        self.command = command
        self.processPlan = processPlan
    }
}

public struct PluginCommandOutputEvent: Equatable, Sendable {
    public enum Stream: String, Equatable, Sendable {
        case standardOutput
        case standardError
    }

    public let stream: Stream
    public let text: String

    public init(stream: Stream, text: String) {
        self.stream = stream
        self.text = text
    }
}

public enum PluginCommandTerminationReason: String, Equatable, Sendable {
    case exit
    case uncaughtSignal
    case unknown
}

public struct PluginCommandExecutionResult: Equatable, Sendable {
    public let plugin: PluginDescriptor
    public let command: PluginCommandDescriptor
    public let processPlan: PluginCommandProcessPlan
    public let terminationStatus: Int32
    public let terminationReason: PluginCommandTerminationReason
    public let standardOutput: String
    public let standardError: String

    public init(
        plugin: PluginDescriptor,
        command: PluginCommandDescriptor,
        processPlan: PluginCommandProcessPlan,
        terminationStatus: Int32,
        terminationReason: PluginCommandTerminationReason,
        standardOutput: String,
        standardError: String
    ) {
        self.plugin = plugin
        self.command = command
        self.processPlan = processPlan
        self.terminationStatus = terminationStatus
        self.terminationReason = terminationReason
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public struct PluginCommandDocumentURLValidationError: Swift.Error, Equatable, Sendable {
    public let documentURL: URL

    public init(documentURL: URL) {
        self.documentURL = documentURL
    }
}

public enum PluginCommandSelectionEnvironmentValidationError: Swift.Error, Equatable, Sendable {
    case textContainsNUL
}

public enum PluginCommandArgumentParser {
    public enum Error: Swift.Error, Equatable, Sendable {
        case danglingEscape
        case unterminatedQuote
    }

    public static func parse(_ text: String) throws -> [String] {
        var arguments: [String] = []
        var current = ""
        var activeQuote: Character?
        var isEscaping = false
        var hasToken = false

        for character in text {
            if isEscaping {
                current.append(character)
                isEscaping = false
                hasToken = true
                continue
            }

            switch character {
            case "\\":
                isEscaping = true
            case "\"", "'":
                if let quote = activeQuote {
                    if quote == character {
                        activeQuote = nil
                    } else {
                        current.append(character)
                    }
                } else {
                    activeQuote = character
                }
                hasToken = true
            case " ", "\t", "\n", "\r":
                if activeQuote == nil {
                    if hasToken {
                        arguments.append(current)
                        current.removeAll(keepingCapacity: true)
                        hasToken = false
                    }
                } else {
                    current.append(character)
                    hasToken = true
                }
            default:
                current.append(character)
                hasToken = true
            }
        }

        if isEscaping {
            throw Error.danglingEscape
        }

        if activeQuote != nil {
            throw Error.unterminatedQuote
        }

        if hasToken {
            arguments.append(current)
        }

        return arguments
    }
}

public struct PluginCommandRuntime: Sendable {
    public static let commandArgumentName = "--notepad-command"
    public static let pluginIdentifierEnvironmentKey = "NOTEPAD_MAC_PLUGIN_IDENTIFIER"
    public static let commandIdentifierEnvironmentKey = "NOTEPAD_MAC_COMMAND_IDENTIFIER"
    public static let pluginDirectoryEnvironmentKey = "NOTEPAD_MAC_PLUGIN_DIRECTORY"
    public static let documentPathEnvironmentKey = "NOTEPAD_MAC_DOCUMENT_PATH"
    public static let documentDirectoryEnvironmentKey = "NOTEPAD_MAC_DOCUMENT_DIRECTORY"
    public static let documentNameEnvironmentKey = "NOTEPAD_MAC_DOCUMENT_NAME"
    public static let selectionUTF16LocationEnvironmentKey = "NOTEPAD_MAC_SELECTION_UTF16_LOCATION"
    public static let selectionUTF16LengthEnvironmentKey = "NOTEPAD_MAC_SELECTION_UTF16_LENGTH"
    public static let selectionTextEnvironmentKey = "NOTEPAD_MAC_SELECTION_TEXT"
    public static let editScriptFileEnvironmentKey = "NOTEPAD_MAC_EDIT_SCRIPT_FILE"

    public enum Error: Swift.Error, Equatable, Sendable {
        case pluginNotFound(identifier: String)
        case incompatiblePlugin(pluginIdentifier: String, reason: String)
        case commandNotFound(pluginIdentifier: String, commandIdentifier: String)
        case missingEntryPoint(pluginIdentifier: String)
        case entryPointMissing(URL)
        case entryPointOutsidePluginDirectory(entryURL: URL, pluginDirectoryURL: URL)
        case entryPointNotExecutable(URL)
    }

    public init() {}

    public func planExecutableCommand(
        _ invocation: PluginCommandInvocation,
        in catalog: PluginCatalog,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> PluginCommandResult {
        guard let plugin = catalog.plugin(identifier: invocation.pluginIdentifier) else {
            throw Error.pluginNotFound(identifier: invocation.pluginIdentifier)
        }

        try validatePluginCanRunCommands(plugin)

        guard let command = plugin.commands.first(where: { $0.identifier == invocation.commandIdentifier }) else {
            throw Error.commandNotFound(
                pluginIdentifier: invocation.pluginIdentifier,
                commandIdentifier: invocation.commandIdentifier
            )
        }

        guard let entryURL = plugin.entryURL?.standardizedFileURL else {
            throw Error.missingEntryPoint(pluginIdentifier: plugin.identifier)
        }

        try validateEntryPointBelongsToPlugin(entryURL, plugin: plugin)
        try validateExecutableEntryURL(entryURL, fileManager: fileManager)

        var environment = baseEnvironment
        for (key, value) in invocation.environment {
            environment[key] = value
        }
        environment[Self.pluginIdentifierEnvironmentKey] = plugin.identifier
        environment[Self.commandIdentifierEnvironmentKey] = command.identifier
        environment[Self.pluginDirectoryEnvironmentKey] = plugin.directoryURL.standardizedFileURL.path
        try addDocumentEnvironment(for: invocation.documentURL, to: &environment)
        try addSelectionEnvironment(for: invocation.selection, to: &environment)
        // The host owns the edit-script key: remove caller-spoofed values and
        // expose it only when this invocation provides a writable target file.
        environment.removeValue(forKey: Self.editScriptFileEnvironmentKey)
        if let editScriptFileURL = invocation.editScriptFileURL, editScriptFileURL.isFileURL {
            environment[Self.editScriptFileEnvironmentKey] = editScriptFileURL.standardizedFileURL.path
        }

        let processPlan = PluginCommandProcessPlan(
            executableURL: entryURL,
            arguments: [Self.commandArgumentName, command.identifier] + invocation.arguments,
            environment: environment
        )

        return PluginCommandResult(plugin: plugin, command: command, processPlan: processPlan)
    }

    public func executeCommand(
        _ invocation: PluginCommandInvocation,
        in catalog: PluginCatalog,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        onOutput: (@MainActor @Sendable (PluginCommandOutputEvent) -> Void)? = nil
    ) async throws -> PluginCommandExecutionResult {
        let result = try planExecutableCommand(
            invocation,
            in: catalog,
            baseEnvironment: baseEnvironment,
            fileManager: fileManager
        )
        return try await executePlannedCommand(result, onOutput: onOutput)
    }

    public func executePlannedCommand(
        _ result: PluginCommandResult,
        onOutput: (@MainActor @Sendable (PluginCommandOutputEvent) -> Void)? = nil
    ) async throws -> PluginCommandExecutionResult {
        let process = result.processPlan.makeProcess()
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let recorder = PluginCommandOutputRecorder(onOutput: onOutput)
        let coordinator = PluginCommandExecutionCoordinator(
            process: process,
            result: result,
            standardOutputPipe: standardOutputPipe,
            standardErrorPipe: standardErrorPipe,
            recorder: recorder
        )

        process.standardInput = FileHandle.nullDevice
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                coordinator.installContinuation(continuation)

                do {
                    try coordinator.run()
                } catch {
                    coordinator.failToStart(with: error)
                }
            }
        } onCancel: {
            coordinator.requestCancellation()
        }
    }

    private func validatePluginCanRunCommands(_ plugin: PluginDescriptor) throws {
        switch plugin.compatibility {
        case .nativeCompatible:
            break
        case let .windowsOnly(reason), let .unsupported(reason), let .invalidManifest(reason):
            throw Error.incompatiblePlugin(pluginIdentifier: plugin.identifier, reason: reason)
        }

        guard plugin.kind == .nativeManifest else {
            throw Error.incompatiblePlugin(
                pluginIdentifier: plugin.identifier,
                reason: "Only native manifest plugins can expose executable commands."
            )
        }
    }

    private func validateExecutableEntryURL(_ entryURL: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: entryURL.path, isDirectory: &isDirectory) else {
            throw Error.entryPointMissing(entryURL)
        }

        guard !isDirectory.boolValue, fileManager.isExecutableFile(atPath: entryURL.path) else {
            throw Error.entryPointNotExecutable(entryURL)
        }
    }

    private func validateEntryPointBelongsToPlugin(_ entryURL: URL, plugin: PluginDescriptor) throws {
        let resolvedEntryURL = entryURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedDirectoryURL = plugin.directoryURL.resolvingSymlinksInPath().standardizedFileURL
        let directoryPath = resolvedDirectoryURL.path
        let entryPath = resolvedEntryURL.path

        guard entryPath == directoryPath || entryPath.hasPrefix(directoryPath + "/") else {
            throw Error.entryPointOutsidePluginDirectory(
                entryURL: entryURL,
                pluginDirectoryURL: plugin.directoryURL
            )
        }
    }

    private func addDocumentEnvironment(for documentURL: URL?, to environment: inout [String: String]) throws {
        environment.removeValue(forKey: Self.documentPathEnvironmentKey)
        environment.removeValue(forKey: Self.documentDirectoryEnvironmentKey)
        environment.removeValue(forKey: Self.documentNameEnvironmentKey)

        guard let documentURL else {
            return
        }

        guard documentURL.isFileURL else {
            throw PluginCommandDocumentURLValidationError(documentURL: documentURL)
        }

        let standardizedDocumentURL = documentURL.standardizedFileURL
        environment[Self.documentPathEnvironmentKey] = standardizedDocumentURL.path
        environment[Self.documentDirectoryEnvironmentKey] = standardizedDocumentURL.deletingLastPathComponent().path
        environment[Self.documentNameEnvironmentKey] = standardizedDocumentURL.lastPathComponent
    }

    private func addSelectionEnvironment(
        for selection: PluginCommandSelectionContext?,
        to environment: inout [String: String]
    ) throws {
        environment.removeValue(forKey: Self.selectionUTF16LocationEnvironmentKey)
        environment.removeValue(forKey: Self.selectionUTF16LengthEnvironmentKey)
        environment.removeValue(forKey: Self.selectionTextEnvironmentKey)

        guard let selection else {
            return
        }

        guard !selection.text.utf8.contains(0) else {
            throw PluginCommandSelectionEnvironmentValidationError.textContainsNUL
        }

        environment[Self.selectionUTF16LocationEnvironmentKey] = String(selection.utf16Location)
        environment[Self.selectionUTF16LengthEnvironmentKey] = String(selection.utf16Length)
        environment[Self.selectionTextEnvironmentKey] = selection.text
    }
}

private final class PluginCommandExecutionCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private let result: PluginCommandResult
    private let standardOutputPipe: Pipe
    private let standardErrorPipe: Pipe
    private let recorder: PluginCommandOutputRecorder

    private var continuation: CheckedContinuation<PluginCommandExecutionResult, Error>?
    private var hasStarted = false
    private var hasResumed = false
    private var cancellationRequested = false

    init(
        process: Process,
        result: PluginCommandResult,
        standardOutputPipe: Pipe,
        standardErrorPipe: Pipe,
        recorder: PluginCommandOutputRecorder
    ) {
        self.process = process
        self.result = result
        self.standardOutputPipe = standardOutputPipe
        self.standardErrorPipe = standardErrorPipe
        self.recorder = recorder
    }

    func installContinuation(_ continuation: CheckedContinuation<PluginCommandExecutionResult, Error>) {
        lock.withLock {
            self.continuation = continuation
        }

        standardOutputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeAvailableData(from: handle, stream: .standardOutput)
        }

        standardErrorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consumeAvailableData(from: handle, stream: .standardError)
        }

        process.terminationHandler = { [weak self] process in
            self?.finish(with: process)
        }
    }

    func run() throws {
        try process.run()

        let shouldTerminate = lock.withLock {
            hasStarted = true
            return cancellationRequested
        }
        if shouldTerminate {
            requestTermination()
        }
    }

    func requestCancellation() {
        let shouldTerminate = lock.withLock {
            cancellationRequested = true
            return hasStarted && !hasResumed
        }
        if shouldTerminate {
            requestTermination()
        }
    }

    func failToStart(with error: Error) {
        clearHandlers()
        resume(with: .failure(error))
    }

    private func consumeAvailableData(from handle: FileHandle, stream: PluginCommandOutputEvent.Stream) {
        let data = handle.availableData
        guard !data.isEmpty else {
            handle.readabilityHandler = nil
            return
        }
        recorder.append(data, to: stream)
    }

    private func finish(with process: Process) {
        clearHandlers()
        recorder.append(standardOutputPipe.fileHandleForReading.readDataToEndOfFile(), to: .standardOutput)
        recorder.append(standardErrorPipe.fileHandleForReading.readDataToEndOfFile(), to: .standardError)

        let executionResult = PluginCommandExecutionResult(
            plugin: result.plugin,
            command: result.command,
            processPlan: result.processPlan,
            terminationStatus: normalizedTerminationStatus(for: process),
            terminationReason: normalizedTerminationReason(for: process),
            standardOutput: recorder.output(for: .standardOutput),
            standardError: recorder.output(for: .standardError)
        )

        Task { [self, recorder] in
            await recorder.waitForOutputCallbacks()
            resume(with: .success(executionResult))
        }
    }

    private func normalizedTerminationReason(for process: Process) -> PluginCommandTerminationReason {
        if shellSignalExitStatus(process.terminationStatus) != nil,
           process.terminationReason == .exit {
            return .uncaughtSignal
        }
        return PluginCommandTerminationReason(process.terminationReason)
    }

    private func normalizedTerminationStatus(for process: Process) -> Int32 {
        if process.terminationReason == .exit,
           let signal = shellSignalExitStatus(process.terminationStatus) {
            return signal
        }
        return process.terminationStatus
    }

    private func shellSignalExitStatus(_ status: Int32) -> Int32? {
        let signal = status - 128
        guard signal > 0, signal <= 64 else {
            return nil
        }
        return signal
    }

    private func clearHandlers() {
        standardOutputPipe.fileHandleForReading.readabilityHandler = nil
        standardErrorPipe.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
    }

    private func resume(with result: Result<PluginCommandExecutionResult, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<PluginCommandExecutionResult, Error>? in
            guard !hasResumed else {
                return nil
            }
            hasResumed = true
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }

        guard let continuation else {
            return
        }

        switch result {
        case let .success(executionResult):
            continuation.resume(returning: executionResult)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    private func requestTermination() {
        guard process.isRunning else {
            return
        }
        process.terminate()
    }
}

private final class PluginCommandOutputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let onOutput: (@MainActor @Sendable (PluginCommandOutputEvent) -> Void)?
    private var outputCallbackTasks: [Task<Void, Never>] = []
    private var standardOutput = Data()
    private var standardError = Data()

    init(onOutput: (@MainActor @Sendable (PluginCommandOutputEvent) -> Void)?) {
        self.onOutput = onOutput
    }

    func append(_ data: Data, to stream: PluginCommandOutputEvent.Stream) {
        guard !data.isEmpty else {
            return
        }

        lock.withLock {
            switch stream {
            case .standardOutput:
                standardOutput.append(data)
            case .standardError:
                standardError.append(data)
            }
        }

        emit(PluginCommandOutputEvent(stream: stream, text: String(decoding: data, as: UTF8.self)))
    }

    func output(for stream: PluginCommandOutputEvent.Stream) -> String {
        lock.withLock {
            switch stream {
            case .standardOutput:
                String(decoding: standardOutput, as: UTF8.self)
            case .standardError:
                String(decoding: standardError, as: UTF8.self)
            }
        }
    }

    func waitForOutputCallbacks() async {
        let tasks = lock.withLock { outputCallbackTasks }
        for task in tasks {
            await task.value
        }
    }

    private func emit(_ event: PluginCommandOutputEvent) {
        guard let onOutput else {
            return
        }

        let task = Task { @MainActor in
            onOutput(event)
        }
        lock.withLock {
            outputCallbackTasks.append(task)
        }
    }
}

private extension PluginCommandTerminationReason {
    init(_ reason: Process.TerminationReason) {
        switch reason {
        case .exit:
            self = .exit
        case .uncaughtSignal:
            self = .uncaughtSignal
        @unknown default:
            self = .unknown
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
