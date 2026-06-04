import Foundation
import Testing
@testable import NotepadMacCore

@Test func runCommandSupportPlansExecutableFromPathAndParsesArguments() throws {
    let fixture = try RunCommandFixture()
    defer { fixture.remove() }

    let documentURL = fixture.rootURL.appending(path: "docs").appending(path: "note.txt")
    try FileManager.default.createDirectory(at: documentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: documentURL)

    let plan = try RunCommandSupport.plan(
        commandLine: "tool",
        documentURL: documentURL,
        environment: ["PATH": fixture.binDirectoryURL.path]
    )

    #expect(plan.executableURL == fixture.commandURL.standardizedFileURL)
    #expect(plan.arguments == [])
    #expect(plan.currentDirectoryURL == documentURL.deletingLastPathComponent().standardizedFileURL)
}

@Test func runCommandSupportPlansQuotedArguments() throws {
    let fixture = try RunCommandFixture()
    defer { fixture.remove() }

    let plan = try RunCommandSupport.plan(
        commandLine: #""\#(fixture.commandURL.path)" --selection "Hello world" --mode fast"#,
        environment: [:]
    )

    #expect(plan.executableURL == fixture.commandURL.standardizedFileURL)
    #expect(plan.arguments == ["--selection", "Hello world", "--mode", "fast"])
}

@Test func runCommandSupportRejectsEmptyCommandLine() {
    #expect(throws: RunCommandSupport.Error.emptyCommandLine) {
        try RunCommandSupport.plan(commandLine: "   ")
    }
}

@Test func runCommandSupportExecutesAndCapturesOutput() async throws {
    let script = """
    #!/bin/sh
    printf 'stdout:%s\\n' "$1"
    printf 'stderr:%s\\n' "$2" >&2
    exit 7
    """
    let fixture = try RunCommandFixture(script: script)
    defer { fixture.remove() }

    let plan = try RunCommandSupport.plan(
        commandLine: #""\#(fixture.commandURL.path)" first second"#,
        environment: [:]
    )
    let result = try await RunCommandSupport.execute(plan)

    #expect(result.terminationReason == .exit)
    #expect(result.terminationStatus == 7)
    #expect(result.standardOutput.contains("stdout:first"))
    #expect(result.standardError.contains("stderr:second"))
}

@Test func runCommandSupportCancelsRunningProcess() async throws {
    let pidFileURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    let script = """
    #!/bin/sh
    trap 'exit 0' TERM INT
    echo $$ > "$1"
    while true; do
      sleep 1
    done
    """
    let fixture = try RunCommandFixture(script: script)
    defer {
        fixture.remove()
        try? FileManager.default.removeItem(at: pidFileURL)
    }

    let plan = try RunCommandSupport.plan(
        commandLine: #""\#(fixture.commandURL.path)" "\#(pidFileURL.path)""#,
        environment: [:]
    )

    let task = Task {
        try await RunCommandSupport.execute(plan)
    }

    try await waitUntil("run command wrote pid") {
        FileManager.default.fileExists(atPath: pidFileURL.path)
    }

    let pidText = try String(contentsOf: pidFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let pid = try #require(Int32(pidText))
    #expect(isProcessRunning(pid))

    task.cancel()

    await #expect(throws: CancellationError.self) {
        _ = try await task.value
    }

    try await waitUntil("run command process exited") {
        !isProcessRunning(pid)
    }
}

private struct RunCommandFixture {
    let rootURL: URL
    let binDirectoryURL: URL
    let commandURL: URL

    init(script: String = "#!/bin/sh\nexit 0\n") throws {
        rootURL = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        binDirectoryURL = rootURL.appending(path: "bin")
        commandURL = binDirectoryURL.appending(path: "tool")

        try FileManager.default.createDirectory(at: binDirectoryURL, withIntermediateDirectories: true)
        try script.write(to: commandURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandURL.path)
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
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

// MARK: - Variable expansion tests

@Test func runCommandExpandsFilePathVariables() {
    let fileURL = URL(fileURLWithPath: "/Users/user/docs/script.py")
    let ctx = RunCommandVariableContext(
        fileURL: fileURL,
        currentLine: 5,
        currentColumn: 12,
        currentWord: "hello"
    )

    #expect(RunCommandSupport.expandVariables(in: "$(FULL_CURRENT_PATH)", context: ctx) == "/Users/user/docs/script.py")
    #expect(RunCommandSupport.expandVariables(in: "$(CURRENT_DIRECTORY)", context: ctx) == "/Users/user/docs")
    #expect(RunCommandSupport.expandVariables(in: "$(FILE_NAME)", context: ctx) == "script.py")
    #expect(RunCommandSupport.expandVariables(in: "$(NAME_PART)", context: ctx) == "script")
    #expect(RunCommandSupport.expandVariables(in: "$(EXT_PART)", context: ctx) == ".py")
}

@Test func runCommandExpandsEditorPositionVariables() {
    let ctx = RunCommandVariableContext(
        fileURL: URL(fileURLWithPath: "/tmp/a.txt"),
        currentLine: 42,
        currentColumn: 7,
        currentWord: "selected word"
    )

    #expect(RunCommandSupport.expandVariables(in: "$(CURRENT_LINE)", context: ctx) == "42")
    #expect(RunCommandSupport.expandVariables(in: "$(CURRENT_COLUMN)", context: ctx) == "7")
    #expect(RunCommandSupport.expandVariables(in: "$(CURRENT_WORD)", context: ctx) == "selected word")
}

@Test func runCommandExpandsSysVariables() {
    let ctx = RunCommandVariableContext(
        fileURL: nil,
        systemEnvironment: ["HOME": "/home/test", "SHELL": "/bin/zsh"]
    )

    #expect(RunCommandSupport.expandVariables(in: "$(SYS.HOME)", context: ctx) == "/home/test")
    #expect(RunCommandSupport.expandVariables(in: "$(SYS.SHELL)", context: ctx) == "/bin/zsh")
    #expect(RunCommandSupport.expandVariables(in: "$(SYS.UNDEFINED)", context: ctx) == "")
}

@Test func runCommandExpandsMultipleVariablesInOneString() {
    let fileURL = URL(fileURLWithPath: "/tmp/notes/todo.txt")
    let ctx = RunCommandVariableContext(
        fileURL: fileURL,
        currentLine: 3,
        currentColumn: 1,
        currentWord: "fix"
    )

    let input = "python3 $(FULL_CURRENT_PATH) --line $(CURRENT_LINE) --word $(CURRENT_WORD)"
    let expected = "python3 /tmp/notes/todo.txt --line 3 --word fix"
    #expect(RunCommandSupport.expandVariables(in: input, context: ctx) == expected)
}

@Test func runCommandExpandsNoVariablesWhenContextEmpty() {
    let ctx = RunCommandVariableContext()
    let input = "echo $(FULL_CURRENT_PATH)"
    #expect(RunCommandSupport.expandVariables(in: input, context: ctx) == "echo ")
}

@Test func runCommandVariableExpansionIntegratesWithPlan() throws {
    let fixture = try RunCommandFixture()
    defer { fixture.remove() }

    let fileURL = URL(fileURLWithPath: "/tmp/test.py")
    let ctx = RunCommandVariableContext(
        fileURL: fileURL,
        currentLine: 10,
        currentColumn: 1,
        currentWord: "token",
        appBundleURL: URL(fileURLWithPath: "/Applications/NotepadMac.app")
    )

    let commandLine = #""\#(fixture.commandURL.path)" $(FILE_NAME) $(CURRENT_LINE)"#
    let plan = try RunCommandSupport.plan(
        commandLine: commandLine,
        variableContext: ctx,
        environment: [:]
    )

    #expect(plan.arguments == ["test.py", "10"])
}
