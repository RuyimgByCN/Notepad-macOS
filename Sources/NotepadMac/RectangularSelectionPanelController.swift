import AppKit

enum RectangularSelectionPanelOperation {
    case insert(blockText: String)
    case replace(blockText: String, endColumn: Int)
}

@MainActor
final class RectangularSelectionPanelController: NSObject {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 540, height: 390),
        styleMask: [.titled, .closable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let rangeField = NSTextField(labelWithString: "")
    private let blockLabel = NSTextField(labelWithString: "")
    private let endColumnLabel = NSTextField(labelWithString: "")
    private let insertModeButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let replaceModeButton = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
    private let blockTextView = NSTextView()
    private let endColumnField = NSTextField(string: "")
    private let endColumnStepper = NSStepper()
    private let statusField = NSTextField(labelWithString: "")
    private let applyButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private var startColumn = 1
    private var onApply: ((RectangularSelectionPanelOperation) -> Void)?

    override init() {
        super.init()
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        configureContent()
        refreshLocalizedStrings()
        updateModeControls()
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

    func show(
        lineRange: ClosedRange<Int>,
        column: Int,
        endColumn: Int,
        blockText: String,
        prefersReplaceMode: Bool,
        onApply: @escaping (RectangularSelectionPanelOperation) -> Void
    ) {
        self.onApply = onApply
        startColumn = max(1, column)
        let normalizedEndColumn = max(startColumn, endColumn)
        rangeField.stringValue = lineRange.lowerBound == lineRange.upperBound
            ? localizedString(
                .rectangularSelectionRangeSingleLine,
                default: "Line %d    Column %d",
                lineRange.lowerBound,
                startColumn
            )
            : localizedString(
                .rectangularSelectionRangeMultipleLines,
                default: "Lines %d-%d    Column %d",
                lineRange.lowerBound,
                lineRange.upperBound,
                startColumn
            )
        resetInputState(
            blockText: blockText,
            endColumn: normalizedEndColumn,
            prefersReplaceMode: prefersReplaceMode
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(blockTextView)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
        updateModeControls()
    }

    private func refreshLocalizedStrings() {
        panel.title = Localization.string(.rectangularSelectionPanelTitle, default: "Rectangular Selection")
        rangeField.setAccessibilityLabel(
            Localization.string(.rectangularSelectionRangeAccessibilityLabel, default: "Selection range")
        )
        blockLabel.stringValue = Localization.string(.rectangularSelectionBlockTextLabel, default: "Block Text")
        endColumnLabel.stringValue = Localization.string(.rectangularSelectionEndColumnLabel, default: "Through Column")
        cancelButton.title = Localization.string(.rectangularSelectionCancel, default: "Cancel")
        insertModeButton.title = Localization.string(.rectangularSelectionInsertMode, default: "Insert at column")
        replaceModeButton.title = Localization.string(.rectangularSelectionReplaceMode, default: "Replace column range")
        insertModeButton.setAccessibilityLabel(
            Localization.string(.rectangularSelectionInsertModeAccessibilityLabel, default: "Insert at column mode")
        )
        replaceModeButton.setAccessibilityLabel(
            Localization.string(.rectangularSelectionReplaceModeAccessibilityLabel, default: "Replace column range mode")
        )
        blockTextView.setAccessibilityLabel(
            Localization.string(.rectangularSelectionBlockTextAccessibilityLabel, default: "Block text")
        )
        endColumnField.setAccessibilityLabel(
            Localization.string(.rectangularSelectionEndColumnFieldAccessibilityLabel, default: "Through column")
        )
        endColumnStepper.setAccessibilityLabel(
            Localization.string(.rectangularSelectionEndColumnStepperAccessibilityLabel, default: "Through column stepper")
        )
        statusField.setAccessibilityLabel(
            Localization.string(.rectangularSelectionStatusAccessibilityLabel, default: "Rectangular selection status")
        )
        applyButton.setAccessibilityLabel(
            Localization.string(.rectangularSelectionApplyAccessibilityLabel, default: "Apply rectangular selection")
        )
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root
        let scrollView = NSScrollView()

        insertModeButton.target = self
        insertModeButton.action = #selector(modeChanged(_:))
        insertModeButton.state = .on
        replaceModeButton.target = self
        replaceModeButton.action = #selector(modeChanged(_:))

        blockTextView.isRichText = false
        blockTextView.isAutomaticQuoteSubstitutionEnabled = false
        blockTextView.isAutomaticDashSubstitutionEnabled = false
        blockTextView.isAutomaticTextReplacementEnabled = false
        blockTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        blockTextView.minSize = NSSize(width: 0, height: 0)
        blockTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        blockTextView.isVerticallyResizable = true
        blockTextView.isHorizontallyResizable = true
        blockTextView.autoresizingMask = [.width]
        blockTextView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        blockTextView.textContainer?.widthTracksTextView = false

        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = blockTextView

        endColumnField.formatter = integerFormatter
        endColumnStepper.minValue = 1
        endColumnStepper.maxValue = 9999
        endColumnStepper.increment = 1
        endColumnStepper.target = self
        endColumnStepper.action = #selector(stepperChanged(_:))

        statusField.textColor = .secondaryLabelColor
        applyButton.target = self
        applyButton.action = #selector(apply(_:))
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))
        cancelButton.bezelStyle = .rounded

        let views: [NSView] = [
            rangeField,
            insertModeButton,
            replaceModeButton,
            blockLabel,
            scrollView,
            endColumnLabel,
            endColumnField,
            endColumnStepper,
            statusField,
            cancelButton,
            applyButton
        ]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0)
        }

        NSLayoutConstraint.activate([
            rangeField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            rangeField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            rangeField.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),

            insertModeButton.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            insertModeButton.topAnchor.constraint(equalTo: rangeField.bottomAnchor, constant: 16),

            replaceModeButton.leadingAnchor.constraint(equalTo: insertModeButton.trailingAnchor, constant: 24),
            replaceModeButton.centerYAnchor.constraint(equalTo: insertModeButton.centerYAnchor),

            blockLabel.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            blockLabel.topAnchor.constraint(equalTo: insertModeButton.bottomAnchor, constant: 16),

            scrollView.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rangeField.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: blockLabel.bottomAnchor, constant: 8),
            scrollView.heightAnchor.constraint(equalToConstant: 170),

            endColumnLabel.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            endColumnLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            endColumnLabel.widthAnchor.constraint(equalToConstant: 110),

            endColumnField.leadingAnchor.constraint(equalTo: endColumnLabel.trailingAnchor, constant: 12),
            endColumnField.centerYAnchor.constraint(equalTo: endColumnLabel.centerYAnchor),
            endColumnField.widthAnchor.constraint(equalToConstant: 74),

            endColumnStepper.leadingAnchor.constraint(equalTo: endColumnField.trailingAnchor, constant: 8),
            endColumnStepper.centerYAnchor.constraint(equalTo: endColumnLabel.centerYAnchor),

            statusField.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            statusField.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -12),
            statusField.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),

            applyButton.trailingAnchor.constraint(equalTo: rangeField.trailingAnchor),
            applyButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -10),
            cancelButton.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor)
        ])
    }

    @objc private func modeChanged(_ sender: Any?) {
        if sender as? NSButton === insertModeButton {
            insertModeButton.state = .on
            replaceModeButton.state = .off
        } else {
            insertModeButton.state = .off
            replaceModeButton.state = .on
        }
        statusField.stringValue = ""
        updateModeControls()
    }

    @objc private func stepperChanged(_ sender: Any?) {
        endColumnField.integerValue = max(1, endColumnStepper.integerValue)
    }

    @objc private func apply(_ sender: Any?) {
        if insertModeButton.state == .on {
            onApply?(.insert(blockText: blockTextView.string))
            return
        }

        let endColumn = max(1, endColumnField.integerValue)
        guard endColumn >= startColumn else {
            statusField.stringValue = localizedString(
                .rectangularSelectionEndColumnValidation,
                default: "Through column must be at least %d.",
                startColumn
            )
            return
        }
        endColumnField.integerValue = endColumn
        endColumnStepper.integerValue = endColumn
        onApply?(.replace(blockText: blockTextView.string, endColumn: endColumn))
    }

    @objc private func cancel(_ sender: Any?) {
        panel.close()
    }

    private func updateModeControls() {
        let isReplaceMode = replaceModeButton.state == .on
        endColumnField.isEnabled = isReplaceMode
        endColumnStepper.isEnabled = isReplaceMode
        applyButton.title = Localization.string(
            isReplaceMode ? .rectangularSelectionApplyReplace : .rectangularSelectionApplyInsert,
            default: isReplaceMode ? "Replace" : "Insert"
        )
    }

    private func resetInputState(blockText: String, endColumn: Int, prefersReplaceMode: Bool) {
        blockTextView.string = blockText
        blockTextView.setSelectedRange(NSRange(location: 0, length: 0))
        insertModeButton.state = prefersReplaceMode ? .off : .on
        replaceModeButton.state = prefersReplaceMode ? .on : .off
        endColumnField.integerValue = endColumn
        endColumnStepper.integerValue = endColumn
        statusField.stringValue = prefersReplaceMode && !blockText.isEmpty
            ? Localization.string(
                .rectangularSelectionPreviewLoaded,
                default: "Loaded current selection as a replacement preview."
            )
            : ""
        updateModeControls()
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }

    private func localizedString(_ key: Localization.Key, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: Localization.string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
