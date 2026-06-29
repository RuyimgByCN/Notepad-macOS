import AppKit
import NotepadMacCore

@MainActor
final class RunCommandPanelController: NSObject, NSWindowDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
        styleMask: [.titled, .closable, .resizable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let commandLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let outputLabel = NSTextField(labelWithString: "")
    private let commandField = NSTextField()
    private let outputTextView = NSTextView()
    private lazy var runButton = NSButton(
        title: Localization.string(.runRunButton, default: "Run"),
        target: self,
        action: #selector(runCommand(_:))
    )
    private lazy var stopButton = NSButton(
        title: Localization.string(.runStopButton, default: "Stop"),
        target: self,
        action: #selector(stopCommand(_:))
    )
    private lazy var historyButton = NSButton(
        title: Localization.string(.runHistoryButton, default: "History ▾"),
        target: self,
        action: #selector(showHistory(_:))
    )
    private lazy var saveCommandButton = NSButton(
        title: Localization.string(.runSaveButton, default: "Save..."),
        target: self,
        action: #selector(saveCurrentCommand(_:))
    )
    private lazy var browseButton = NSButton(
        title: Localization.string(.runBrowseButton, default: "Browse..."),
        target: self,
        action: #selector(browseForProgram(_:))
    )
    private var currentDocumentURL: URL?
    private var variableContext: RunCommandVariableContext?
    private var executionTask: Task<Void, Never>?
    var onSaveCommand: ((SavedRunCommand) -> Void)?
    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.delegate = self
        configureContent()
        refreshLocalizedStrings()
        updateControls(isRunning: false)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localizationDidChange(_:)),
            name: Localization.localizationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private static let historyKey = "notepadMac.runCommandHistory"

    func show(documentURL: URL?, variableContext: RunCommandVariableContext? = nil) {
        currentDocumentURL = documentURL
        self.variableContext = variableContext
        // Restore last command from history
        if commandField.stringValue.isEmpty,
           let lastCommand = loadCommandHistory().first {
            commandField.stringValue = lastCommand
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadCommandHistory() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
    }

    private func addToCommandHistory(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var history = loadCommandHistory()
        history.removeAll { $0 == command }
        history.insert(command, at: 0)
        UserDefaults.standard.set(Array(history.prefix(20)), forKey: Self.historyKey)
    }

    func windowWillClose(_ notification: Notification) {
        executionTask?.cancel()
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.runPanelTitle, default: "Run...")
        commandLabel.stringValue = Localization.string(.runProgramLabel, default: "The Program to Run")
        commandField.placeholderString = Localization.string(.runProgramPlaceholder, default: "/usr/bin/env python3 script.py")
        commandField.setAccessibilityLabel(
            Localization.string(.runProgramAccessibilityLabel, default: "Program to run")
        )
        outputLabel.stringValue = Localization.string(.runOutputLabel, default: "Output")
        outputTextView.setAccessibilityLabel(
            Localization.string(.runOutputAccessibilityLabel, default: "Run command output")
        )
        runButton.title = Localization.string(.runRunButton, default: "Run")
        stopButton.title = Localization.string(.runStopButton, default: "Stop")
        historyButton.title = Localization.string(.runHistoryButton, default: "History ▾")
        saveCommandButton.title = Localization.string(.runSaveButton, default: "Save...")
        browseButton.title = Localization.string(.runBrowseButton, default: "Browse...")
    }

    @objc private func showHistory(_ sender: Any?) {
        let history = loadCommandHistory()
        guard !history.isEmpty else { return }
        let menu = NSMenu()
        for command in history {
            let item = NSMenuItem(title: command, action: #selector(selectHistoryItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = command
            menu.addItem(item)
        }
        if let button = sender as? NSButton {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func selectHistoryItem(_ sender: NSMenuItem) {
        if let command = sender.representedObject as? String {
            commandField.stringValue = command
        }
    }

    @objc private func browseForProgram(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            let quoted = url.path.contains(" ") ? "\"\(url.path)\"" : url.path
            let existing = self.commandField.stringValue.trimmingCharacters(in: .whitespaces)
            self.commandField.stringValue = existing.isEmpty ? quoted : "\(existing) \(quoted)"
        }
    }

    @objc private func saveCurrentCommand(_ sender: Any?) {
        let commandLine = commandField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !commandLine.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = Localization.string(.runSaveDialogTitle, default: "Save Command")
        alert.informativeText = Localization.string(.runSaveDialogMessage, default: "Enter a name for this command:")
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        nameField.placeholderString = Localization.string(.runSaveDialogPlaceholder, default: "My Script")
        alert.accessoryView = nameField
        alert.addButton(withTitle: Localization.string(.runSaveDialogSave, default: "Save"))
        alert.addButton(withTitle: Localization.string(.runSaveDialogCancel, default: "Cancel"))
        alert.window.initialFirstResponder = nameField
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let saved = SavedRunCommand(name: name, commandLine: commandLine)
        onSaveCommand?(saved)
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        commandLabel.translatesAutoresizingMaskIntoConstraints = false
        commandLabel.stringValue = Localization.string(.runProgramLabel, default: "The Program to Run")

        commandField.translatesAutoresizingMaskIntoConstraints = false
        commandField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        commandField.placeholderString = Localization.string(.runProgramPlaceholder, default: "/usr/bin/env python3 script.py")
        commandField.setAccessibilityLabel(
            Localization.string(.runProgramAccessibilityLabel, default: "Program to run")
        )

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        outputLabel.translatesAutoresizingMaskIntoConstraints = false
        outputLabel.stringValue = Localization.string(.runOutputLabel, default: "Output")

        let outputScrollView = NSScrollView()
        outputScrollView.translatesAutoresizingMaskIntoConstraints = false
        outputScrollView.borderType = .bezelBorder
        outputScrollView.hasVerticalScroller = true

        outputTextView.isEditable = false
        outputTextView.isSelectable = true
        outputTextView.isRichText = false
        outputTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        outputTextView.setAccessibilityLabel(
            Localization.string(.runOutputAccessibilityLabel, default: "Run command output")
        )
        outputScrollView.documentView = outputTextView

        runButton.translatesAutoresizingMaskIntoConstraints = false
        runButton.bezelStyle = .rounded
        runButton.keyEquivalent = "\r"

        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.bezelStyle = .rounded

        historyButton.translatesAutoresizingMaskIntoConstraints = false
        historyButton.bezelStyle = .rounded

        saveCommandButton.translatesAutoresizingMaskIntoConstraints = false
        saveCommandButton.bezelStyle = .rounded

        browseButton.translatesAutoresizingMaskIntoConstraints = false
        browseButton.bezelStyle = .rounded

        root.addSubview(commandLabel)
        root.addSubview(commandField)
        root.addSubview(browseButton)
        root.addSubview(statusLabel)
        root.addSubview(outputLabel)
        root.addSubview(outputScrollView)
        root.addSubview(runButton)
        root.addSubview(stopButton)
        root.addSubview(historyButton)
        root.addSubview(saveCommandButton)

        NSLayoutConstraint.activate([
            commandLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            commandLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            browseButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            browseButton.centerYAnchor.constraint(equalTo: commandField.centerYAnchor),

            commandField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            commandField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -8),
            commandField.topAnchor.constraint(equalTo: commandLabel.bottomAnchor, constant: 8),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            statusLabel.topAnchor.constraint(equalTo: commandField.bottomAnchor, constant: 8),

            outputLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            outputLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),

            outputScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            outputScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            outputScrollView.topAnchor.constraint(equalTo: outputLabel.bottomAnchor, constant: 8),
            outputScrollView.bottomAnchor.constraint(equalTo: runButton.topAnchor, constant: -12),

            stopButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stopButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            runButton.trailingAnchor.constraint(equalTo: stopButton.leadingAnchor, constant: -8),
            runButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            historyButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            historyButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            saveCommandButton.leadingAnchor.constraint(equalTo: historyButton.trailingAnchor, constant: 8),
            saveCommandButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])
    }

    @objc private func runCommand(_ sender: Any?) {
        executionTask?.cancel()
        addToCommandHistory(commandField.stringValue)

        let environment = runEnvironment(for: currentDocumentURL)
        let plan: RunCommandPlan
        do {
            plan = try RunCommandSupport.plan(
                commandLine: commandField.stringValue,
                documentURL: currentDocumentURL,
                variableContext: variableContext,
                environment: environment
            )
        } catch {
            statusLabel.stringValue = error.localizedDescription
            outputTextView.string = ""
            updateControls(isRunning: false)
            return
        }

        outputTextView.string = ""
        statusLabel.stringValue = String(
            format: Localization.string(.runStatusRunning, default: "Running %@"),
            locale: Locale.current,
            plan.executableURL.lastPathComponent
        )
        updateControls(isRunning: true)

        executionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await RunCommandSupport.execute(plan, environment: environment)
                await MainActor.run {
                    self.outputTextView.string = self.formattedOutput(for: result)
                    self.statusLabel.stringValue = self.statusText(for: result)
                    self.updateControls(isRunning: false)
                    self.executionTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.statusLabel.stringValue = Localization.string(.runStatusStopped, default: "Stopped")
                    self.updateControls(isRunning: false)
                    self.executionTask = nil
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = error.localizedDescription
                    self.updateControls(isRunning: false)
                    self.executionTask = nil
                }
            }
        }
    }

    @objc private func stopCommand(_ sender: Any?) {
        statusLabel.stringValue = Localization.string(.runStatusStopping, default: "Stopping...")
        executionTask?.cancel()
    }

    private func updateControls(isRunning: Bool) {
        runButton.isEnabled = !isRunning
        stopButton.isEnabled = isRunning
        commandField.isEnabled = !isRunning
    }

    private func statusText(for result: RunCommandExecutionResult) -> String {
        switch result.terminationReason {
        case .exit:
            return String(
                format: Localization.string(.runStatusExited, default: "Exited with status %d"),
                locale: Locale.current,
                Int(result.terminationStatus)
            )
        case .uncaughtSignal:
            return String(
                format: Localization.string(.runStatusSignaled, default: "Terminated by signal %d"),
                locale: Locale.current,
                Int(result.terminationStatus)
            )
        @unknown default:
            return String(
                format: Localization.string(.runStatusExited, default: "Exited with status %d"),
                locale: Locale.current,
                Int(result.terminationStatus)
            )
        }
    }

    private func formattedOutput(for result: RunCommandExecutionResult) -> String {
        var sections: [String] = []
        if !result.standardOutput.isEmpty {
            sections.append(result.standardOutput)
        }
        if !result.standardError.isEmpty {
            sections.append(result.standardError)
        }

        if sections.isEmpty {
            return Localization.string(.runNoOutput, default: "(no output)")
        }

        return sections.joined(separator: sections.count > 1 ? "\n" : "")
    }

    private func runEnvironment(for documentURL: URL?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment

        if let documentURL, documentURL.isFileURL {
            environment["NOTEPAD_MAC_DOCUMENT_PATH"] = documentURL.path
            environment["NOTEPAD_MAC_DOCUMENT_DIRECTORY"] = documentURL.deletingLastPathComponent().path
            environment["NOTEPAD_MAC_DOCUMENT_NAME"] = documentURL.lastPathComponent
        } else {
            environment.removeValue(forKey: "NOTEPAD_MAC_DOCUMENT_PATH")
            environment.removeValue(forKey: "NOTEPAD_MAC_DOCUMENT_DIRECTORY")
            environment.removeValue(forKey: "NOTEPAD_MAC_DOCUMENT_NAME")
        }

        return environment
    }
}
