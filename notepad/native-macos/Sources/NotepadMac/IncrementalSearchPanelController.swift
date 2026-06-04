import AppKit
import NotepadMacCore

@MainActor
final class IncrementalSearchPanelController: NSWindowController {
    private weak var editor: EditorWindowController?

    private let searchField = NSSearchField()

    init(editor: EditorWindowController) {
        self.editor = editor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 48),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
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
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func localizationDidChange(_ notification: Notification) {
        refreshLocalizedStrings()
    }

    private func refreshLocalizedStrings() {
        window?.title = Localization.string(.incrementalSearchTitle, default: "Incremental Search")
        searchField.placeholderString = Localization.string(.incrementalSearchPlaceholder, default: "Search…")
        searchField.setAccessibilityLabel(Localization.string(.incrementalSearchPlaceholder, default: "Search…"))
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsSearchStringImmediately = true
        searchField.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        let query = sender.stringValue

        guard !query.isEmpty else {
            editor?.clearIncrementalHighlight()
            return
        }

        if editor?.performIncrementalFind(query: query) != true {
            NSSound.beep()
        }
    }
}
