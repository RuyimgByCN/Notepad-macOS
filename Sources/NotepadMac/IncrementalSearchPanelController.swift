import AppKit
import NotepadMacCore

/// Incremental Search panel with optional match counting ("nth of total"),
/// aligned with upstream Notepad++ 8.9.7 Incremental Search bar behavior.
@MainActor
final class IncrementalSearchPanelController: NSWindowController {
    private weak var editor: EditorWindowController?

    private let searchField = NSSearchField()
    private let countCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

    private static let countDefaultsKey = "notepadMac.incrementalSearchCount"

    /// When true, show "n of m" and precompute all matches (upstream default: on).
    private var countEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.countDefaultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.countDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.countDefaultsKey)
        }
    }

    init(editor: EditorWindowController) {
        self.editor = editor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 72),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.title = Localization.string(.incrementalSearchTitle, default: "Incremental Search")

        super.init(window: panel)
        configureContent()
        refreshLocalizedStrings()
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        refreshLocalizedStrings()
        countCheckbox.state = countEnabled ? .on : .off
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
        NSApp.activate(ignoringOtherApps: true)
        runSearch(from: searchField)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.incrementalSearchTitle, default: "Incremental Search")
        searchField.placeholderString = Localization.string(.incrementalSearchPlaceholder, default: "Search…")
        searchField.setAccessibilityLabel(Localization.string(.incrementalSearchPlaceholder, default: "Search…"))
        countCheckbox.title = Localization.string(.incrementalSearchCount, default: "Count")
        countCheckbox.setAccessibilityLabel(
            Localization.string(.incrementalSearchCount, default: "Count")
        )
        // Re-apply status with current localization if a query is active.
        if !searchField.stringValue.isEmpty {
            runSearch(from: searchField)
        }
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsSearchStringImmediately = true
        searchField.translatesAutoresizingMaskIntoConstraints = false

        countCheckbox.target = self
        countCheckbox.action = #selector(countToggled(_:))
        countCheckbox.state = countEnabled ? .on : .off
        countCheckbox.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(searchField)
        contentView.addSubview(countCheckbox)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            countCheckbox.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            countCheckbox.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            countCheckbox.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: countCheckbox.trailingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: countCheckbox.centerYAnchor),
        ])
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        runSearch(from: sender)
    }

    @objc private func countToggled(_ sender: NSButton) {
        countEnabled = sender.state == .on
        if !countEnabled {
            editor?.clearIncrementalMatchCache()
        }
        runSearch(from: searchField)
    }

    private func runSearch(from field: NSSearchField) {
        let query = field.stringValue

        guard !query.isEmpty else {
            editor?.clearIncrementalHighlight()
            editor?.clearIncrementalMatchCache()
            statusLabel.stringValue = ""
            return
        }

        let result = editor?.performIncrementalFind(query: query, countMatches: countEnabled)
            ?? IncrementalFindResult(found: false, nth: 0, total: 0, countingEnabled: countEnabled)

        applyStatus(result)

        if !result.found {
            NSSound.beep()
        }
    }

    private func applyStatus(_ result: IncrementalFindResult) {
        if result.found {
            if result.countingEnabled, result.total > 0, result.nth > 0 {
                let format = Localization.string(
                    .incrementalSearchNthOfTotal,
                    default: "%d of %d"
                )
                statusLabel.stringValue = String(format: format, result.nth, result.total)
                statusLabel.textColor = .secondaryLabelColor
            } else {
                statusLabel.stringValue = Localization.string(
                    .incrementalSearchFound,
                    default: "Found"
                )
                statusLabel.textColor = .secondaryLabelColor
            }
        } else {
            statusLabel.stringValue = Localization.string(
                .incrementalSearchNotFound,
                default: "Phrase not found"
            )
            statusLabel.textColor = .systemRed
        }
    }
}

/// Result of one Incremental Search step (mirrors upstream FindIncrementDlg status).
struct IncrementalFindResult: Equatable, Sendable {
    let found: Bool
    /// 1-based match index when counting; 0 when not found or counting off.
    let nth: Int
    /// Total matches when counting; 0 when counting off or not found.
    let total: Int
    let countingEnabled: Bool
}
