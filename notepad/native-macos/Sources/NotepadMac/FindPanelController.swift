import AppKit
import NotepadMacCore

@MainActor
final class FindPanelController: NSWindowController {
    private weak var editor: EditorWindowController?
    private let preferencesStore: PreferencesStore

    private let findField = NSTextField(string: "")
    private let replaceField = NSTextField(string: "")
    private let matchCaseButton = NSButton(
        checkboxWithTitle: Localization.string(.findMatchCase, default: "Match Case"),
        target: nil,
        action: nil
    )
    private let wholeWordButton = NSButton(
        checkboxWithTitle: Localization.string(.findWholeWord, default: "Whole Word"),
        target: nil,
        action: nil
    )
    private let wrapAroundButton = NSButton(
        checkboxWithTitle: Localization.string(.findWrapAround, default: "Wrap Around"),
        target: nil,
        action: nil
    )
    private let directionControl = NSSegmentedControl()
    private let statusField = NSTextField(labelWithString: "")

    init(editor: EditorWindowController, preferencesStore: PreferencesStore) {
        self.editor = editor
        self.preferencesStore = preferencesStore

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 265),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = Localization.string(.findPanelTitle, default: "Find and Replace")
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        configureContent()
        loadPreferences()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(focusedOnReplace: Bool = false) {
        loadPreferences()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(focusedOnReplace ? replaceField : findField)
    }

    func findNextFromMenu() {
        guard !findField.stringValue.isEmpty else {
            show()
            return
        }
        performFind(options: options)
    }

    func findPreviousFromMenu() {
        guard !findField.stringValue.isEmpty else {
            show()
            return
        }
        performFind(options: makeOptions(direction: .up))
    }

    @objc private func findNext(_ sender: Any?) {
        performFind(options: options)
    }

    private func performFind(options searchOptions: TextSearch.Options) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        if editor?.performFind(query: findField.stringValue, options: searchOptions) == true {
            statusField.stringValue = Localization.string(.findStatusFound, default: "Found.")
        } else {
            statusField.stringValue = Localization.string(.findStatusNoMatches, default: "No matches.")
        }
    }

    @objc private func replaceNext(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        if editor?.performReplace(query: findField.stringValue, replacement: replaceField.stringValue, options: options) == true {
            statusField.stringValue = Localization.string(.findStatusReplaced, default: "Replaced.")
        } else {
            statusField.stringValue = Localization.string(.findStatusNoMatches, default: "No matches.")
        }
    }

    @objc private func replaceAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        let count = editor?.performReplaceAll(query: findField.stringValue, replacement: replaceField.stringValue, options: options) ?? 0
        statusField.stringValue = localizedString(
            .findStatusReplacementCount,
            default: "%d replacement(s).",
            count
        )
    }

    @objc private func bookmarkAll(_ sender: Any?) {
        guard !findField.stringValue.isEmpty else {
            statusField.stringValue = Localization.string(.findStatusEnterText, default: "Enter text to find.")
            return
        }

        saveSearchPreferences()
        let result = editor?.performBookmarkAllMatches(query: findField.stringValue, options: options) ?? (matchCount: 0, lineCount: 0)
        guard result.matchCount > 0 else {
            statusField.stringValue = Localization.string(.findStatusNoMatches, default: "No matches.")
            return
        }

        statusField.stringValue = localizedString(
            .findStatusBookmarkCount,
            default: "Bookmarked %d match(es) on %d line(s).",
            result.matchCount,
            result.lineCount
        )
    }

    private var options: TextSearch.Options {
        makeOptions(direction: nil)
    }

    private func makeOptions(direction: TextSearch.Direction?) -> TextSearch.Options {
        TextSearch.Options(
            matchCase: matchCaseButton.state == .on,
            wholeWord: wholeWordButton.state == .on,
            wraps: wrapAroundButton.state == .on,
            direction: direction ?? (directionControl.selectedSegment == 1 ? .up : .down)
        )
    }

    private func loadPreferences() {
        let preferences = preferencesStore.load()
        matchCaseButton.state = preferences.searchMatchCase ? .on : .off
        wholeWordButton.state = preferences.searchWholeWord ? .on : .off
    }

    private func saveSearchPreferences() {
        preferencesStore.save(preferencesStore.load().withSearchOptions(options))
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let findLabel = NSTextField(labelWithString: Localization.string(.findLabel, default: "Find"))
        let replaceLabel = NSTextField(labelWithString: Localization.string(.findReplaceLabel, default: "Replace"))
        let directionLabel = NSTextField(labelWithString: Localization.string(.findDirectionLabel, default: "Direction"))
        let findButton = NSButton(
            title: Localization.string(.findNextButton, default: "Find Next"),
            target: self,
            action: #selector(findNext(_:))
        )
        let replaceButton = NSButton(
            title: Localization.string(.findReplaceButton, default: "Replace"),
            target: self,
            action: #selector(replaceNext(_:))
        )
        let replaceAllButton = NSButton(
            title: Localization.string(.findReplaceAllButton, default: "Replace All"),
            target: self,
            action: #selector(replaceAll(_:))
        )
        let bookmarkAllButton = NSButton(
            title: Localization.string(.findBookmarkAllButton, default: "Bookmark All"),
            target: self,
            action: #selector(bookmarkAll(_:))
        )

        directionControl.segmentCount = 2
        directionControl.setLabel(Localization.string(.findDirectionDown, default: "Down"), forSegment: 0)
        directionControl.setLabel(Localization.string(.findDirectionUp, default: "Up"), forSegment: 1)
        directionControl.trackingMode = .selectOne
        directionControl.selectedSegment = 0
        wrapAroundButton.state = .on

        [findLabel, replaceLabel, directionLabel, findField, replaceField, matchCaseButton, wholeWordButton, wrapAroundButton, directionControl, findButton, replaceButton, replaceAllButton, bookmarkAllButton, statusField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        statusField.textColor = .secondaryLabelColor
        findButton.keyEquivalent = "\r"

        NSLayoutConstraint.activate([
            findLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            findLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            findLabel.widthAnchor.constraint(equalToConstant: 70),

            findField.leadingAnchor.constraint(equalTo: findLabel.trailingAnchor, constant: 10),
            findField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            findField.centerYAnchor.constraint(equalTo: findLabel.centerYAnchor),

            replaceLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            replaceLabel.topAnchor.constraint(equalTo: findLabel.bottomAnchor, constant: 16),
            replaceLabel.widthAnchor.constraint(equalTo: findLabel.widthAnchor),

            replaceField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            replaceField.trailingAnchor.constraint(equalTo: findField.trailingAnchor),
            replaceField.centerYAnchor.constraint(equalTo: replaceLabel.centerYAnchor),

            matchCaseButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            matchCaseButton.topAnchor.constraint(equalTo: replaceField.bottomAnchor, constant: 14),

            wholeWordButton.leadingAnchor.constraint(equalTo: matchCaseButton.trailingAnchor, constant: 20),
            wholeWordButton.centerYAnchor.constraint(equalTo: matchCaseButton.centerYAnchor),

            directionLabel.leadingAnchor.constraint(equalTo: findLabel.leadingAnchor),
            directionLabel.topAnchor.constraint(equalTo: matchCaseButton.bottomAnchor, constant: 14),
            directionLabel.widthAnchor.constraint(equalTo: findLabel.widthAnchor),

            directionControl.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            directionControl.centerYAnchor.constraint(equalTo: directionLabel.centerYAnchor),

            wrapAroundButton.leadingAnchor.constraint(equalTo: directionControl.trailingAnchor, constant: 20),
            wrapAroundButton.centerYAnchor.constraint(equalTo: directionControl.centerYAnchor),

            findButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            findButton.topAnchor.constraint(equalTo: directionControl.bottomAnchor, constant: 16),

            replaceButton.leadingAnchor.constraint(equalTo: findButton.trailingAnchor, constant: 10),
            replaceButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            replaceAllButton.leadingAnchor.constraint(equalTo: replaceButton.trailingAnchor, constant: 10),
            replaceAllButton.centerYAnchor.constraint(equalTo: findButton.centerYAnchor),

            bookmarkAllButton.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            bookmarkAllButton.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 10),

            statusField.leadingAnchor.constraint(equalTo: findField.leadingAnchor),
            statusField.trailingAnchor.constraint(equalTo: findField.trailingAnchor),
            statusField.topAnchor.constraint(equalTo: bookmarkAllButton.bottomAnchor, constant: 12)
        ])
    }

    private func localizedString(_ key: Localization.Key, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: Localization.string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
