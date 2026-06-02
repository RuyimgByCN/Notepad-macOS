import Foundation
import Darwin
import Testing
@testable import NotepadMacCore

@Test func pluginCommandRuntimeResolvesNativeCompatibleCommand() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    let result = try runtime.planExecutableCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase"
        ),
        in: PluginCatalog(plugins: [fixture.plugin])
    )

    #expect(result.plugin == fixture.plugin)
    #expect(result.command == PluginCommandDescriptor(identifier: "uppercase", title: "Uppercase Document"))
    #expect(result.processPlan.executableURL == fixture.entryURL.standardizedFileURL)
}

@Test func pluginCommandRuntimeRejectsMissingCommand() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    #expect(throws: PluginCommandRuntime.Error.commandNotFound(
        pluginIdentifier: fixture.plugin.identifier,
        commandIdentifier: "missing"
    )) {
        try runtime.planExecutableCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "missing"
            ),
            in: PluginCatalog(plugins: [fixture.plugin])
        )
    }
}

@Test func pluginCommandRuntimeRejectsIncompatiblePlugins() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let cases: [(PluginKind, PluginCompatibility, String)] = [
        (.windowsDLL, .windowsOnly(reason: PluginCompatibility.windowsDLLReason), PluginCompatibility.windowsDLLReason),
        (.nativeManifest, .unsupported(reason: "Requires a future host ABI."), "Requires a future host ABI."),
        (.nativeManifest, .invalidManifest(reason: "Missing required name."), "Missing required name.")
    ]

    for (index, testCase) in cases.enumerated() {
        let plugin = PluginDescriptor(
            identifier: "plugin-\(index)",
            displayName: "Plugin \(index)",
            kind: testCase.0,
            compatibility: testCase.1,
            directoryURL: fixture.pluginDirectoryURL,
            entryURL: fixture.entryURL,
            commands: [PluginCommandDescriptor(identifier: "uppercase", title: "Uppercase Document")]
        )

        #expect(throws: PluginCommandRuntime.Error.incompatiblePlugin(
            pluginIdentifier: plugin.identifier,
            reason: testCase.2
        )) {
            try runtime.planExecutableCommand(
                PluginCommandInvocation(
                    pluginIdentifier: plugin.identifier,
                    commandIdentifier: "uppercase"
                ),
                in: PluginCatalog(plugins: [plugin])
            )
        }
    }
}

@Test func pluginCommandRuntimeRejectsNonExecutableEntryPoint() throws {
    let fixture = try PluginCommandRuntimeFixture(makeExecutable: false)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    #expect(throws: PluginCommandRuntime.Error.entryPointNotExecutable(fixture.entryURL.standardizedFileURL)) {
        try runtime.planExecutableCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "uppercase"
            ),
            in: PluginCatalog(plugins: [fixture.plugin])
        )
    }
}

@Test func pluginCommandRuntimeRejectsEntryPointOutsidePluginDirectory() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let outsideEntryURL = fixture.rootURL.appending(path: "outside-tool")
    try "#!/bin/sh\nexit 0\n".write(to: outsideEntryURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outsideEntryURL.path)

    let plugin = PluginDescriptor(
        identifier: fixture.plugin.identifier,
        displayName: fixture.plugin.displayName,
        version: fixture.plugin.version,
        kind: fixture.plugin.kind,
        compatibility: fixture.plugin.compatibility,
        directoryURL: fixture.pluginDirectoryURL,
        entryURL: outsideEntryURL,
        commands: fixture.plugin.commands
    )
    let runtime = PluginCommandRuntime()

    #expect(throws: PluginCommandRuntime.Error.entryPointOutsidePluginDirectory(
        entryURL: outsideEntryURL.standardizedFileURL,
        pluginDirectoryURL: fixture.pluginDirectoryURL.standardizedFileURL
    )) {
        try runtime.planExecutableCommand(
            PluginCommandInvocation(
                pluginIdentifier: plugin.identifier,
                commandIdentifier: "uppercase"
            ),
            in: PluginCatalog(plugins: [plugin])
        )
    }
}

@Test func pluginCommandRuntimeShapesArgumentsAndEnvironment() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    let result = try runtime.planExecutableCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase",
            arguments: ["--selection", "abc"],
            environment: [
                "CUSTOM_SETTING": "enabled",
                "NOTEPAD_MAC_COMMAND_IDENTIFIER": "spoofed"
            ]
        ),
        in: PluginCatalog(plugins: [fixture.plugin]),
        baseEnvironment: [
            "PATH": "/usr/bin",
            "HOME": "/Users/tester",
            "NOTEPAD_MAC_PLUGIN_IDENTIFIER": "base-spoofed"
        ]
    )

    #expect(result.processPlan.arguments == ["--notepad-command", "uppercase", "--selection", "abc"])
    #expect(result.processPlan.environment["PATH"] == "/usr/bin")
    #expect(result.processPlan.environment["HOME"] == "/Users/tester")
    #expect(result.processPlan.environment["CUSTOM_SETTING"] == "enabled")
    #expect(result.processPlan.environment["NOTEPAD_MAC_PLUGIN_IDENTIFIER"] == fixture.plugin.identifier)
    #expect(result.processPlan.environment["NOTEPAD_MAC_COMMAND_IDENTIFIER"] == "uppercase")
    #expect(result.processPlan.environment["NOTEPAD_MAC_PLUGIN_DIRECTORY"] == fixture.pluginDirectoryURL.standardizedFileURL.path)
}

@Test func pluginCommandRuntimeAddsDocumentEnvironmentKeys() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let documentURL = fixture.rootURL
        .appending(path: "documents")
        .appending(path: "Example.swift")

    let result = try runtime.planExecutableCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase",
            environment: [
                "NOTEPAD_MAC_DOCUMENT_PATH": "spoofed",
                "NOTEPAD_MAC_DOCUMENT_DIRECTORY": "spoofed",
                "NOTEPAD_MAC_DOCUMENT_NAME": "spoofed"
            ],
            documentURL: documentURL
        ),
        in: PluginCatalog(plugins: [fixture.plugin])
    )

    #expect(result.processPlan.environment["NOTEPAD_MAC_DOCUMENT_PATH"] == documentURL.standardizedFileURL.path)
    #expect(result.processPlan.environment["NOTEPAD_MAC_DOCUMENT_DIRECTORY"] == documentURL.deletingLastPathComponent().standardizedFileURL.path)
    #expect(result.processPlan.environment["NOTEPAD_MAC_DOCUMENT_NAME"] == "Example.swift")
}

@Test func pluginCommandRuntimeRemovesDocumentEnvironmentKeysWithoutDocumentURL() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    let result = try runtime.planExecutableCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase",
            environment: [
                "NOTEPAD_MAC_DOCUMENT_PATH": "spoofed",
                "NOTEPAD_MAC_DOCUMENT_DIRECTORY": "spoofed",
                "NOTEPAD_MAC_DOCUMENT_NAME": "spoofed"
            ]
        ),
        in: PluginCatalog(plugins: [fixture.plugin]),
        baseEnvironment: [
            "NOTEPAD_MAC_DOCUMENT_PATH": "base-spoofed",
            "NOTEPAD_MAC_DOCUMENT_DIRECTORY": "base-spoofed",
            "NOTEPAD_MAC_DOCUMENT_NAME": "base-spoofed"
        ]
    )

    #expect(result.processPlan.environment["NOTEPAD_MAC_DOCUMENT_PATH"] == nil)
    #expect(result.processPlan.environment["NOTEPAD_MAC_DOCUMENT_DIRECTORY"] == nil)
    #expect(result.processPlan.environment["NOTEPAD_MAC_DOCUMENT_NAME"] == nil)
}

@Test func pluginCommandRuntimeRejectsNonFileDocumentURL() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let documentURL = try #require(URL(string: "https://example.com/Example.swift"))

    #expect(throws: PluginCommandDocumentURLValidationError(documentURL: documentURL)) {
        try runtime.planExecutableCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "uppercase",
                documentURL: documentURL
            ),
            in: PluginCatalog(plugins: [fixture.plugin])
        )
    }
}

@Test func pluginCommandRuntimeAddsSelectionEnvironmentKeys() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    let result = try runtime.planExecutableCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase",
            environment: [
                "NOTEPAD_MAC_SELECTION_UTF16_LOCATION": "spoofed",
                "NOTEPAD_MAC_SELECTION_UTF16_LENGTH": "spoofed",
                "NOTEPAD_MAC_SELECTION_TEXT": "spoofed"
            ],
            selection: PluginCommandSelectionContext(
                utf16Location: 7,
                utf16Length: 8,
                text: "Hello\nΔ"
            )
        ),
        in: PluginCatalog(plugins: [fixture.plugin]),
        baseEnvironment: [
            "NOTEPAD_MAC_SELECTION_UTF16_LOCATION": "base-spoofed",
            "NOTEPAD_MAC_SELECTION_UTF16_LENGTH": "base-spoofed",
            "NOTEPAD_MAC_SELECTION_TEXT": "base-spoofed"
        ]
    )

    #expect(result.processPlan.environment["NOTEPAD_MAC_SELECTION_UTF16_LOCATION"] == "7")
    #expect(result.processPlan.environment["NOTEPAD_MAC_SELECTION_UTF16_LENGTH"] == "8")
    #expect(result.processPlan.environment["NOTEPAD_MAC_SELECTION_TEXT"] == "Hello\nΔ")
}

@Test func pluginCommandRuntimeRejectsSelectionTextContainingNUL() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    #expect(throws: PluginCommandSelectionEnvironmentValidationError.textContainsNUL) {
        try runtime.planExecutableCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "uppercase",
                selection: PluginCommandSelectionContext(
                    utf16Location: 0,
                    utf16Length: 11,
                    text: "safe\u{0}spoof"
                )
            ),
            in: PluginCatalog(plugins: [fixture.plugin])
        )
    }
}

@Test func pluginCommandRuntimeRemovesSelectionEnvironmentKeysWithoutSelection() throws {
    let fixture = try PluginCommandRuntimeFixture()
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    let result = try runtime.planExecutableCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase",
            environment: [
                "NOTEPAD_MAC_SELECTION_UTF16_LOCATION": "spoofed",
                "NOTEPAD_MAC_SELECTION_UTF16_LENGTH": "spoofed",
                "NOTEPAD_MAC_SELECTION_TEXT": "spoofed"
            ]
        ),
        in: PluginCatalog(plugins: [fixture.plugin]),
        baseEnvironment: [
            "NOTEPAD_MAC_SELECTION_UTF16_LOCATION": "base-spoofed",
            "NOTEPAD_MAC_SELECTION_UTF16_LENGTH": "base-spoofed",
            "NOTEPAD_MAC_SELECTION_TEXT": "base-spoofed"
        ]
    )

    #expect(result.processPlan.environment["NOTEPAD_MAC_SELECTION_UTF16_LOCATION"] == nil)
    #expect(result.processPlan.environment["NOTEPAD_MAC_SELECTION_UTF16_LENGTH"] == nil)
    #expect(result.processPlan.environment["NOTEPAD_MAC_SELECTION_TEXT"] == nil)
}

@Test func pluginCommandRuntimeParsesArgumentInput() throws {
    let arguments = try PluginCommandArgumentParser.parse(#"--selection "Hello world" --mode fast"#)

    #expect(arguments == ["--selection", "Hello world", "--mode", "fast"])
}

@Test func pluginCommandRuntimeRejectsUnterminatedArgumentQuote() {
    #expect(throws: PluginCommandArgumentParser.Error.unterminatedQuote) {
        try PluginCommandArgumentParser.parse(#"--selection "Hello world"#)
    }
}

@Test func pluginCommandRuntimeExecutesCommandAndCapturesOutput() async throws {
    let script = """
    #!/bin/sh
    printf 'stdout:%s\\n' "$NOTEPAD_MAC_COMMAND_IDENTIFIER"
    printf 'stderr:%s\\n' "$NOTEPAD_MAC_PLUGIN_IDENTIFIER" >&2
    index=0
    for arg in "$@"; do
      printf 'arg%s=%s\\n' "$index" "$arg"
      index=$((index + 1))
    done
    exit 7
    """
    let fixture = try PluginCommandRuntimeFixture(script: script)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let recorder = PluginCommandOutputEventRecorder()

    let result = try await runtime.executeCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase",
            arguments: ["--selection", "Hello world"]
        ),
        in: PluginCatalog(plugins: [fixture.plugin]),
        onOutput: { event in
            recorder.append(event)
        }
    )

    #expect(result.terminationStatus == 7)
    #expect(result.terminationReason == .exit)
    #expect(result.standardOutput.contains("stdout:uppercase"))
    #expect(result.standardOutput.contains("arg0=--notepad-command"))
    #expect(result.standardOutput.contains("arg1=uppercase"))
    #expect(result.standardOutput.contains("arg2=--selection"))
    #expect(result.standardOutput.contains("arg3=Hello world"))
    #expect(result.standardError.contains("stderr:\(fixture.plugin.identifier)"))

    let events = recorder.snapshot()
    #expect(events.contains(where: { $0.stream == .standardOutput && $0.text.contains("stdout:uppercase") }))
    #expect(events.contains(where: { $0.stream == .standardError && $0.text.contains("stderr:\(fixture.plugin.identifier)") }))
}

@Test func pluginCommandRuntimeDeliversOutputCallbacksOnMainThread() async throws {
    let script = """
    #!/bin/sh
    printf 'callback-thread-check\\n'
    """
    let fixture = try PluginCommandRuntimeFixture(script: script)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let recorder = PluginCommandOutputThreadRecorder()

    _ = try await runtime.executeCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase"
        ),
        in: PluginCatalog(plugins: [fixture.plugin]),
        onOutput: { event in
            recorder.append(event, isMainThread: Thread.isMainThread)
        }
    )

    let callbacks = recorder.snapshot()
    #expect(callbacks.contains { $0.event.text.contains("callback-thread-check") })
    #expect(callbacks.allSatisfy { $0.isMainThread })
}

@Test func pluginCommandRuntimeCancellingTaskTerminatesRunningProcess() async throws {
    let script = """
    #!/bin/sh
    trap 'printf "cancelled\\n" >&2; exit 99' TERM
    printf 'ready\\n'
    while :; do
      sleep 0.1
    done
    """
    let fixture = try PluginCommandRuntimeFixture(script: script)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let recorder = PluginCommandOutputEventRecorder()

    let executionTask = Task {
        try await runtime.executeCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "uppercase"
            ),
            in: PluginCatalog(plugins: [fixture.plugin]),
            onOutput: { event in
                recorder.append(event)
            }
        )
    }

    try await waitUntil("plugin command produced startup output") {
        recorder.snapshot().contains(where: { $0.stream == .standardOutput && $0.text.contains("ready") })
    }

    executionTask.cancel()
    let result = try await withTimeout("cancelled plugin command finished") {
        try await executionTask.value
    }

    #expect(result.terminationReason == .exit)
    #expect(result.terminationStatus == 99)
    #expect(result.standardOutput.contains("ready"))
    #expect(result.standardError.contains("cancelled"))
}

@Test func pluginCommandRuntimeCancellingTaskReportsUntrappedSignal() async throws {
    let script = """
    #!/bin/sh
    printf 'ready\\n'
    while :; do
      sleep 0.1
    done
    """
    let fixture = try PluginCommandRuntimeFixture(script: script)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let recorder = PluginCommandOutputEventRecorder()

    let executionTask = Task {
        try await runtime.executeCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "uppercase"
            ),
            in: PluginCatalog(plugins: [fixture.plugin]),
            onOutput: { event in
                recorder.append(event)
            }
        )
    }

    try await waitUntil("plugin command produced startup output") {
        recorder.snapshot().contains(where: { $0.stream == .standardOutput && $0.text.contains("ready") })
    }

    executionTask.cancel()
    let result = try await withTimeout("untrapped cancelled plugin command finished") {
        try await executionTask.value
    }

    #expect(result.terminationReason == .uncaughtSignal)
    #expect(result.terminationStatus == 15)
    #expect(result.standardOutput.contains("ready"))
}

@Test func pluginCommandRuntimeCancellingTaskTerminatesDescendantProcesses() async throws {
    let descendantPIDURL = URL(filePath: NSTemporaryDirectory()).appending(path: "notepad-plugin-child-\(UUID().uuidString).pid")
    defer { try? FileManager.default.removeItem(at: descendantPIDURL) }

    let script = """
    #!/bin/sh
    child_pid_file="$CHILD_PID_FILE"
    /bin/sh -c 'printf "%s" "$$" > "$1"; while :; do sleep 1; done' child-runner "$child_pid_file" &
    printf 'ready\\n'
    wait
    """
    let fixture = try PluginCommandRuntimeFixture(script: script)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()
    let recorder = PluginCommandOutputEventRecorder()

    let executionTask = Task {
        try await runtime.executeCommand(
            PluginCommandInvocation(
                pluginIdentifier: fixture.plugin.identifier,
                commandIdentifier: "uppercase",
                environment: ["CHILD_PID_FILE": descendantPIDURL.path]
            ),
            in: PluginCatalog(plugins: [fixture.plugin]),
            onOutput: { event in
                recorder.append(event)
            }
        )
    }

    try await waitUntil("plugin command produced startup output") {
        recorder.snapshot().contains(where: { $0.stream == .standardOutput && $0.text.contains("ready") })
    }
    try await waitUntil("plugin child wrote pid") {
        FileManager.default.fileExists(atPath: descendantPIDURL.path)
    }

    let childPIDText = try String(contentsOf: descendantPIDURL, encoding: .utf8)
    let childPID = try #require(Int32(childPIDText.trimmingCharacters(in: .whitespacesAndNewlines)))
    #expect(isProcessRunning(childPID))

    executionTask.cancel()
    _ = try await withTimeout("cancelled plugin command finished") {
        try await executionTask.value
    }

    try await waitUntil("plugin child process exited") {
        !isProcessRunning(childPID)
    }
}

@Test func pluginCommandRuntimeReportsSignalTermination() async throws {
    let script = """
    #!/bin/sh
    printf 'before-signal\\n'
    kill -TERM $$
    """
    let fixture = try PluginCommandRuntimeFixture(script: script)
    defer { fixture.remove() }
    let runtime = PluginCommandRuntime()

    let result = try await runtime.executeCommand(
        PluginCommandInvocation(
            pluginIdentifier: fixture.plugin.identifier,
            commandIdentifier: "uppercase"
        ),
        in: PluginCatalog(plugins: [fixture.plugin])
    )

    #expect(result.terminationReason == .uncaughtSignal)
    #expect(result.terminationStatus == 15)
    #expect(result.standardOutput.contains("before-signal"))
}

private struct PluginCommandRuntimeFixture {
    let rootURL: URL
    let pluginDirectoryURL: URL
    let entryURL: URL
    let plugin: PluginDescriptor

    init(makeExecutable: Bool = true, script: String = "#!/bin/sh\nexit 0\n") throws {
        rootURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        pluginDirectoryURL = rootURL.appending(path: "NativeTools")
        entryURL = pluginDirectoryURL.appending(path: "native-tools")

        try FileManager.default.createDirectory(at: pluginDirectoryURL, withIntermediateDirectories: true)
        try script.write(to: entryURL, atomically: true, encoding: .utf8)
        if makeExecutable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: entryURL.path)
        }

        plugin = PluginDescriptor(
            identifier: "org.notepad-plus-plus.macnative.native-tools",
            displayName: "Native Tools",
            version: "1.0.0",
            kind: .nativeManifest,
            compatibility: .nativeCompatible,
            directoryURL: pluginDirectoryURL,
            entryURL: entryURL,
            commands: [
                PluginCommandDescriptor(identifier: "uppercase", title: "Uppercase Document"),
                PluginCommandDescriptor(identifier: "lowercase", title: "Lowercase Document")
            ]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private final class PluginCommandOutputEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [PluginCommandOutputEvent] = []

    func append(_ event: PluginCommandOutputEvent) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    func snapshot() -> [PluginCommandOutputEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

private struct PluginCommandOutputThreadRecord {
    let event: PluginCommandOutputEvent
    let isMainThread: Bool
}

private final class PluginCommandOutputThreadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [PluginCommandOutputThreadRecord] = []

    func append(_ event: PluginCommandOutputEvent, isMainThread: Bool) {
        lock.lock()
        defer { lock.unlock() }
        records.append(PluginCommandOutputThreadRecord(event: event, isMainThread: isMainThread))
    }

    func snapshot() -> [PluginCommandOutputThreadRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }
}

private struct TimeoutError: Error, CustomStringConvertible {
    let operation: String

    var description: String {
        "Timed out while waiting for \(operation)"
    }
}

private func withTimeout<T: Sendable>(
    _ operation: String,
    timeout: Duration = .seconds(5),
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await work()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError(operation: operation)
        }

        let value = try await group.next()
        group.cancelAll()
        return try #require(value)
    }
}

private func waitUntil(
    _ conditionDescription: String,
    timeout: Duration = .seconds(5),
    pollInterval: Duration = .milliseconds(25),
    condition: @escaping @Sendable () -> Bool
) async throws {
    try await withTimeout(conditionDescription, timeout: timeout) {
        while !condition() {
            try await Task.sleep(for: pollInterval)
        }
        return ()
    }
}

private func isProcessRunning(_ pid: Int32) -> Bool {
    kill(pid, 0) == 0
}
