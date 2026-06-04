import Foundation

public struct RunCommandPlan: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let currentDirectoryURL: URL?

    public init(executableURL: URL, arguments: [String], currentDirectoryURL: URL? = nil) {
        self.executableURL = executableURL.standardizedFileURL
        self.arguments = arguments
        self.currentDirectoryURL = currentDirectoryURL?.standardizedFileURL
    }
}

public struct RunCommandExecutionResult: Sendable {
    public let standardOutput: String
    public let standardError: String
    public let terminationStatus: Int32
    public let terminationReason: Process.TerminationReason
}

/// Context for expanding Notepad++-style $(VARIABLE) tokens in run command strings.
public struct RunCommandVariableContext: Sendable {
    public let fileURL: URL?
    public let currentLine: Int    // 1-based
    public let currentColumn: Int  // 1-based
    public let currentWord: String
    public let appBundleURL: URL?
    public let systemEnvironment: [String: String]

    public init(
        fileURL: URL? = nil,
        currentLine: Int = 1,
        currentColumn: Int = 1,
        currentWord: String = "",
        appBundleURL: URL? = Bundle.main.bundleURL,
        systemEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileURL = fileURL
        self.currentLine = currentLine
        self.currentColumn = currentColumn
        self.currentWord = currentWord
        self.appBundleURL = appBundleURL
        self.systemEnvironment = systemEnvironment
    }
}

public enum RunCommandSupport {
    public enum Error: Swift.Error, Equatable, Sendable {
        case emptyCommandLine
        case executableNotFound(String)
        case executableIsDirectory(URL)
        case executableNotExecutable(URL)
        case argumentParse(PluginCommandArgumentParser.Error)
    }

    /// Expand Notepad++-style $(VARIABLE) tokens in a command string.
    /// Supports:
    /// - `$(FULL_CURRENT_PATH)` – full path of the active document
    /// - `$(CURRENT_DIRECTORY)` – directory of the active document
    /// - `$(FILE_NAME)` – filename with extension
    /// - `$(NAME_PART)` – filename without extension
    /// - `$(EXT_PART)` – file extension (including leading dot)
    /// - `$(NPP_DIRECTORY)` – app bundle directory
    /// - `$(CURRENT_LINE)` – 1-based line number
    /// - `$(CURRENT_COLUMN)` – 1-based column number
    /// - `$(CURRENT_WORD)` – selected text or word under caret
    /// - `$(SYS.NAME)` – system environment variable NAME
    public static func expandVariables(
        in commandLine: String,
        context: RunCommandVariableContext
    ) -> String {
        var result = commandLine
        let file = context.fileURL
        let dirPath = file?.deletingLastPathComponent().path ?? ""
        let fileName = file?.lastPathComponent ?? ""
        let nameOnly = file.map { URL(fileURLWithPath: $0.deletingPathExtension().lastPathComponent).lastPathComponent } ?? ""
        let rawExt = file.map { "." + $0.pathExtension } ?? ""
        let ext = rawExt == "." ? "" : rawExt
        let appDir = context.appBundleURL?.deletingLastPathComponent().path ?? ""

        let builtins: [(String, String)] = [
            ("FULL_CURRENT_PATH", file?.path ?? ""),
            ("CURRENT_DIRECTORY", dirPath),
            ("FILE_NAME", fileName),
            ("NAME_PART", nameOnly),
            ("EXT_PART", ext),
            ("NPP_DIRECTORY", appDir),
            ("NPP_FULL_FILE_PATH", file?.path ?? ""),
            ("CURRENT_LINE", "\(context.currentLine)"),
            ("CURRENT_COLUMN", "\(context.currentColumn)"),
            ("CURRENT_WORD", context.currentWord),
        ]

        for (key, value) in builtins {
            result = result.replacingOccurrences(of: "$(\(key))", with: value)
        }

        // $(SYS.NAME) → system environment variable
        var searchFrom = result.startIndex
        while let dollarRange = result.range(of: "$(SYS.", range: searchFrom..<result.endIndex) {
            guard let closeRange = result.range(of: ")", range: dollarRange.upperBound..<result.endIndex) else { break }
            let varName = String(result[dollarRange.upperBound..<closeRange.lowerBound])
            let tokenRange = dollarRange.lowerBound..<result.index(after: closeRange.lowerBound)
            let replacement = context.systemEnvironment[varName] ?? ""
            result.replaceSubrange(tokenRange, with: replacement)
            searchFrom = result.index(result.startIndex, offsetBy: max(0, result.distance(from: result.startIndex, to: tokenRange.lowerBound) + replacement.count))
        }

        return result
    }

    public static func plan(
        commandLine: String,
        documentURL: URL? = nil,
        variableContext: RunCommandVariableContext? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> RunCommandPlan {
        let expanded: String
        if let ctx = variableContext {
            expanded = expandVariables(in: commandLine, context: ctx)
        } else {
            expanded = commandLine
        }
        let arguments: [String]
        do {
            arguments = try PluginCommandArgumentParser.parse(expanded)
        } catch let error as PluginCommandArgumentParser.Error {
            throw Error.argumentParse(error)
        }

        guard let executableToken = arguments.first else {
            throw Error.emptyCommandLine
        }

        let currentDirectoryURL = documentURL?.deletingLastPathComponent().standardizedFileURL
        let executableURL = try resolveExecutable(
            executableToken,
            currentDirectoryURL: currentDirectoryURL,
            environment: environment,
            fileManager: fileManager
        )

        return RunCommandPlan(
            executableURL: executableURL,
            arguments: Array(arguments.dropFirst()),
            currentDirectoryURL: currentDirectoryURL
        )
    }

    public static func execute(
        _ plan: RunCommandPlan,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> RunCommandExecutionResult {
        let process = Process()
        process.executableURL = plan.executableURL
        process.arguments = plan.arguments
        process.environment = environment
        process.currentDirectoryURL = plan.currentDirectoryURL
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutTask = Task {
            try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
        }
        let stderrTask = Task {
            try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        }

        try process.run()

        let termination = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    continuation.resume(returning: (process.terminationStatus, process.terminationReason))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        let standardOutput = String(decoding: try await stdoutTask.value, as: UTF8.self)
        let standardError = String(decoding: try await stderrTask.value, as: UTF8.self)

        if Task.isCancelled {
            throw CancellationError()
        }

        return RunCommandExecutionResult(
            standardOutput: standardOutput,
            standardError: standardError,
            terminationStatus: termination.0,
            terminationReason: termination.1
        )
    }

    private static func resolveExecutable(
        _ token: String,
        currentDirectoryURL: URL?,
        environment: [String: String],
        fileManager: FileManager
    ) throws -> URL {
        if token.contains("/") {
            let candidateURL: URL
            if token.hasPrefix("/") {
                candidateURL = URL(fileURLWithPath: token)
            } else if let currentDirectoryURL {
                candidateURL = currentDirectoryURL.appendingPathComponent(token)
            } else {
                candidateURL = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent(token)
            }

            return try validateExecutable(candidateURL.standardizedFileURL, fileManager: fileManager)
        }

        let pathComponents = (environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for pathComponent in pathComponents where !pathComponent.isEmpty {
            let candidateURL = URL(fileURLWithPath: pathComponent).appendingPathComponent(token)
            if let validatedURL = try validateExecutableIfPresent(candidateURL, fileManager: fileManager) {
                return validatedURL
            }
        }

        throw Error.executableNotFound(token)
    }

    private static func validateExecutableIfPresent(
        _ candidateURL: URL,
        fileManager: FileManager
    ) throws -> URL? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        return try validateExecutable(candidateURL, fileManager: fileManager)
    }

    private static func validateExecutable(_ candidateURL: URL, fileManager: FileManager) throws -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory) else {
            throw Error.executableNotFound(candidateURL.path)
        }
        if isDirectory.boolValue {
            throw Error.executableIsDirectory(candidateURL)
        }
        guard fileManager.isExecutableFile(atPath: candidateURL.path) else {
            throw Error.executableNotExecutable(candidateURL)
        }
        return candidateURL.standardizedFileURL
    }
}

extension RunCommandSupport.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyCommandLine:
            return "Enter a command to run."
        case let .executableNotFound(token):
            return "Executable not found: \(token)"
        case let .executableIsDirectory(url):
            return "Executable path is a directory: \(url.path)"
        case let .executableNotExecutable(url):
            return "File is not executable: \(url.path)"
        case let .argumentParse(error):
            switch error {
            case .danglingEscape:
                return "The command line ends with an unfinished escape."
            case .unterminatedQuote:
                return "The command line contains an unterminated quote."
            }
        }
    }
}
