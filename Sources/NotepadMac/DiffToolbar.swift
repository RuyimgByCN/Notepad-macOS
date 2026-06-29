import AppKit

/// Toolbar for the file-compare window (aligned with Notepad-- CompareWin toolbar).
@MainActor
final class DiffToolbar: NSView {

    var onWhitespace: (() -> Void)?
    var onRules: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onClear: (() -> Void)?
    var onSwap: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onCopyLeftToRight: (() -> Void)?
    var onCopyRightToLeft: (() -> Void)?

    private let countField = NSTextField(labelWithString: "")
    private let whitespaceButton = NSButton()

    static let barHeight: CGFloat = 36

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        countField.translatesAutoresizingMaskIntoConstraints = false
        countField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        countField.textColor = .secondaryLabelColor
        countField.alignment = .right
        countField.stringValue = ""

        whitespaceButton.translatesAutoresizingMaskIntoConstraints = false
        whitespaceButton.bezelStyle = .smallSquare
        whitespaceButton.image = NSImage(systemSymbolName: "space", accessibilityDescription: DiffStrings.toolbarWhitespace)
        whitespaceButton.imagePosition = .imageOnly
        whitespaceButton.toolTip = DiffStrings.toolbarWhitespace
        whitespaceButton.target = self
        whitespaceButton.action = #selector(whitespaceClicked)
        whitespaceButton.setContentHuggingPriority(.required, for: .horizontal)

        let buttons: [(String, String, Selector)] = [
            ("list.bullet.rectangle", DiffStrings.toolbarRules, #selector(rulesClicked)),
            ("chevron.up", DiffStrings.previousDifference, #selector(previousClicked)),
            ("chevron.down", DiffStrings.nextDifference, #selector(nextClicked)),
            ("plus.magnifyingglass", DiffStrings.toolbarZoomIn, #selector(zoomInClicked)),
            ("minus.magnifyingglass", DiffStrings.toolbarZoomOut, #selector(zoomOutClicked)),
            ("trash", DiffStrings.toolbarClear, #selector(clearClicked)),
            ("arrow.left.arrow.right", DiffStrings.swapSides, #selector(swapClicked)),
            ("arrow.clockwise", DiffStrings.recompare, #selector(refreshClicked)),
        ]

        var items: [NSView] = [whitespaceButton]
        for (symbol, tooltip, action) in buttons {
            items.append(makeButton(symbol: symbol, tooltip: tooltip, action: action))
        }
        items.append(makeCopyMenuButton())

        let stack = NSStackView(views: items)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        addSubview(stack)
        addSubview(countField)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            countField.centerYAnchor.constraint(equalTo: centerYAnchor),
            countField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            countField.leadingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 12),
            countField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
    }

    private func makeButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .smallSquare
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.target = self
        button.action = action
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func makeCopyMenuButton() -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .smallSquare
        button.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: DiffStrings.toolbarCopyMenu)
        button.imagePosition = .imageOnly
        button.toolTip = DiffStrings.toolbarCopyMenu
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.target = self
        button.action = #selector(copyMenuClicked(_:))

        let menu = NSMenu()
        let copyLR = NSMenuItem(
            title: DiffStrings.copyLeftToRight,
            action: #selector(copyLeftToRightClicked),
            keyEquivalent: ""
        )
        copyLR.target = self
        menu.addItem(copyLR)
        let copyRL = NSMenuItem(
            title: DiffStrings.copyRightToLeft,
            action: #selector(copyRightToLeftClicked),
            keyEquivalent: ""
        )
        copyRL.target = self
        menu.addItem(copyRL)
        button.menu = menu
        return button
    }

    @objc private func copyMenuClicked(_ sender: NSButton) {
        guard let menu = sender.menu else { return }
        let location = NSPoint(x: 0, y: sender.bounds.height)
        menu.popUp(positioning: nil, at: location, in: sender)
    }

    func setWhitespaceHighlighted(_ highlighted: Bool) {
        whitespaceButton.contentTintColor = highlighted ? .controlAccentColor : nil
    }

    func updateHunkCount(current: Int, total: Int) {
        if total == 0 {
            countField.stringValue = DiffStrings.noDifferences
            countField.textColor = .secondaryLabelColor
        } else {
            let clamped = min(max(current, 1), total)
            countField.stringValue = DiffStrings.hunkCount(current: clamped, total: total)
            countField.textColor = .labelColor
        }
    }

    @objc private func whitespaceClicked() { onWhitespace?() }
    @objc private func rulesClicked() { onRules?() }
    @objc private func previousClicked() { onPrevious?() }
    @objc private func nextClicked() { onNext?() }
    @objc private func zoomInClicked() { onZoomIn?() }
    @objc private func zoomOutClicked() { onZoomOut?() }
    @objc private func clearClicked() { onClear?() }
    @objc private func swapClicked() { onSwap?() }
    @objc private func refreshClicked() { onRefresh?() }
    @objc private func copyLeftToRightClicked() { onCopyLeftToRight?() }
    @objc private func copyRightToLeftClicked() { onCopyRightToLeft?() }
}

/// Localized strings for the compare feature.
@MainActor
enum DiffStrings {
    static var windowTitle: String {
        Localization.string(.diffWindowTitle, default: "Compare Files")
    }
    static var previousDifference: String {
        Localization.string(.diffPrevious, default: "Previous Difference (F3)")
    }
    static var nextDifference: String {
        Localization.string(.diffNext, default: "Next Difference (F4)")
    }
    static var copyLeftToRight: String {
        Localization.string(.diffCopyLeftToRight, default: "Copy Left → Right")
    }
    static var copyRightToLeft: String {
        Localization.string(.diffCopyRightToLeft, default: "Copy Right → Left")
    }
    static var swapSides: String {
        Localization.string(.diffSwap, default: "Swap Sides")
    }
    static var recompare: String {
        Localization.string(.diffRecompare, default: "Recompare (F5)")
    }
    static var noDifferences: String {
        Localization.string(.diffNoDifferences, default: "No differences")
    }
    static var filesIdentical: String {
        Localization.string(.diffFilesIdentical, default: "Files are identical")
    }
    static var toolbarWhitespace: String {
        Localization.string(.diffToolbarWhitespace, default: "Show Whitespace")
    }
    static var toolbarRules: String {
        Localization.string(.diffToolbarRules, default: "Compare Rules")
    }
    static var toolbarZoomIn: String {
        Localization.string(.diffToolbarZoomIn, default: "Zoom In")
    }
    static var toolbarZoomOut: String {
        Localization.string(.diffToolbarZoomOut, default: "Zoom Out")
    }
    static var toolbarClear: String {
        Localization.string(.diffToolbarClear, default: "Clear Compare")
    }
    static var toolbarCopyMenu: String {
        Localization.string(.diffToolbarCopyMenu, default: "Copy Hunk")
    }
    static var paneOpen: String {
        Localization.string(.diffPaneOpen, default: "Open File")
    }
    static var paneLeftEncoding: String {
        Localization.string(.diffPaneLeftEncoding, default: "Left encoding")
    }
    static var paneRightEncoding: String {
        Localization.string(.diffPaneRightEncoding, default: "Right encoding")
    }
    static var optionsTitle: String {
        Localization.string(.diffOptionsTitle, default: "Compare Options")
    }
    static var optionsCompareGroup: String {
        Localization.string(.diffOptionsCompareGroup, default: "Compare Options")
    }
    static var optionsIgnoreLeadingWhitespace: String {
        Localization.string(.diffOptionsIgnoreLeadingWhitespace, default: "Ignore whitespace characters before line")
    }
    static var optionsIgnoreTrailingWhitespace: String {
        Localization.string(.diffOptionsIgnoreTrailingWhitespace, default: "Ignore whitespace characters at back of the line")
    }
    static var optionsIgnoreAllWhitespace: String {
        Localization.string(.diffOptionsIgnoreAllWhitespace, default: "Ignore all whitespace characters")
    }
    static var optionsComingSoon: String {
        Localization.string(.diffOptionsComingSoon, default: "Coming soon")
    }
    static var optionsApply: String {
        Localization.string(.diffOptionsApply, default: "Apply")
    }
    static var optionsCancel: String {
        Localization.string(.diffOptionsCancel, default: "Cancel")
    }
    static var statusAlreadyFirst: String {
        Localization.string(.diffStatusAlreadyFirst, default: "Already the first difference")
    }
    static var statusAlreadyLast: String {
        Localization.string(.diffStatusAlreadyLast, default: "Already the last difference")
    }
    static var statusNoMoreDiffs: String {
        Localization.string(.diffStatusNoMoreDiffs, default: "No more differences")
    }

    static func hunkCount(current: Int, total: Int) -> String {
        String(
            format: Localization.string(.diffStatusHunkCount, default: "Difference %d of %d"),
            locale: Locale.current,
            current,
            total
        )
    }

    static func statusDiffCount(total: Int) -> String {
        String(
            format: Localization.string(.diffStatusDiffCount, default: "%d difference(s)"),
            locale: Locale.current,
            total
        )
    }
}
