import AppKit

/// Toolbar for the file-compare window (aligned with Notepad-- CompareWin toolbar).
@MainActor
final class DiffToolbar: NSView {

    var onWhitespace: (() -> Void)?
    var onRules: (() -> Void)?
    var onBreak: (() -> Void)?
    var onPullOpen: (() -> Void)?
    var onStrict: (() -> Void)?
    var onIgnore: (() -> Void)?
    var onUndo: (() -> Void)?
    var onDiffMap: (() -> Void)?
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
    private let whitespaceButton = DiffToolbarButton()
    private let strictButton = DiffToolbarButton()
    private let ignoreButton = DiffToolbarButton()

    static let barHeight: CGFloat = 88

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        NSColor.separatorColor.withAlphaComponent(0.5).setFill()
        NSRect(x: 0, y: bounds.height - 0.5, width: bounds.width, height: 0.5).fill()
    }

    private func configure() {
        countField.translatesAutoresizingMaskIntoConstraints = false
        countField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        countField.textColor = .secondaryLabelColor
        countField.alignment = .right
        countField.stringValue = ""

        whitespaceButton.translatesAutoresizingMaskIntoConstraints = false
        configureIconButton(
            whitespaceButton,
            image: DiffToolbarIcons.whitespace(),
            caption: DiffStrings.toolbarWhitespaceCaption,
            tooltip: DiffStrings.toolbarWhitespace,
            action: #selector(whitespaceClicked),
            isToggle: true
        )

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 3

        stack.addArrangedSubview(whitespaceButton)
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.rules(),
            caption: DiffStrings.toolbarRulesCaption,
            tooltip: DiffStrings.toolbarRules,
            action: #selector(rulesClicked)
        ))
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.breakAction(),
            caption: DiffStrings.toolbarBreakCaption,
            tooltip: DiffStrings.toolbarBreak,
            action: #selector(breakClicked)
        ))
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.pullOpen(),
            caption: DiffStrings.toolbarPullOpenCaption,
            tooltip: DiffStrings.toolbarPullOpen,
            action: #selector(pullOpenClicked)
        ))
        stack.addArrangedSubview(makeSeparator())

        strictButton.translatesAutoresizingMaskIntoConstraints = false
        configureIconButton(
            strictButton,
            image: DiffToolbarIcons.strictMode(),
            caption: DiffStrings.toolbarStrictCaption,
            tooltip: DiffStrings.toolbarStrict,
            action: #selector(strictClicked),
            isToggle: true
        )
        stack.addArrangedSubview(strictButton)

        ignoreButton.translatesAutoresizingMaskIntoConstraints = false
        configureIconButton(
            ignoreButton,
            image: DiffToolbarIcons.ignoreMode(),
            caption: DiffStrings.toolbarIgnoreCaption,
            tooltip: DiffStrings.toolbarIgnore,
            action: #selector(ignoreClicked),
            isToggle: true
        )
        stack.addArrangedSubview(ignoreButton)
        setCompareModeHighlighted(isStrict: true)
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.undo(),
            caption: DiffStrings.toolbarUndoCaption,
            tooltip: DiffStrings.toolbarUndo,
            action: #selector(undoClicked)
        ))
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.previous(),
            caption: DiffStrings.previousDifferenceCaption,
            tooltip: DiffStrings.previousDifference,
            action: #selector(previousClicked)
        ))
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.next(),
            caption: DiffStrings.nextDifferenceCaption,
            tooltip: DiffStrings.nextDifference,
            action: #selector(nextClicked)
        ))
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.zoomIn(),
            caption: DiffStrings.toolbarZoomInCaption,
            tooltip: DiffStrings.toolbarZoomIn,
            action: #selector(zoomInClicked)
        ))
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.zoomOut(),
            caption: DiffStrings.toolbarZoomOutCaption,
            tooltip: DiffStrings.toolbarZoomOut,
            action: #selector(zoomOutClicked)
        ))
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.clear(),
            caption: DiffStrings.toolbarClearCaption,
            tooltip: DiffStrings.toolbarClear,
            action: #selector(clearClicked)
        ))
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.swap(),
            caption: DiffStrings.swapSidesCaption,
            tooltip: DiffStrings.swapSides,
            action: #selector(swapClicked)
        ))
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.refresh(),
            caption: DiffStrings.recompareCaption,
            tooltip: DiffStrings.recompare,
            action: #selector(refreshClicked)
        ))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeButton(
            image: DiffToolbarIcons.diffMap(),
            caption: DiffStrings.toolbarDiffMapCaption,
            tooltip: DiffStrings.toolbarDiffMap,
            action: #selector(diffMapClicked)
        ))

        addSubview(stack)
        addSubview(countField)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: countField.leadingAnchor, constant: -12),

            countField.centerYAnchor.constraint(equalTo: centerYAnchor),
            countField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            countField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
    }

    private func makeSeparator() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        container.addSubview(separator)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 8),
            separator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            separator.heightAnchor.constraint(equalToConstant: 18),
        ])
        return container
    }

    private func makeButton(image: NSImage?, caption: String, tooltip: String, action: Selector) -> NSButton {
        let button = DiffToolbarButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        configureIconButton(button, image: image, caption: caption, tooltip: tooltip, action: action)
        return button
    }

    private func configureIconButton(
        _ button: NSButton,
        image: NSImage?,
        caption: String,
        tooltip: String,
        action: Selector,
        isToggle: Bool = false
    ) {
        button.title = caption
        button.image = scaledToolbarImage(image)
        button.imagePosition = .imageAbove
        button.imageScaling = .scaleProportionallyDown
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.setButtonType(isToggle ? .toggle : .momentaryChange)
        button.toolTip = tooltip
        button.target = self
        button.action = action
        button.setAccessibilityLabel(tooltip)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.lineBreakMode = .byTruncatingTail
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 58),
        ])
    }

    private func scaledToolbarImage(_ image: NSImage?) -> NSImage? {
        guard let image = image?.copy() as? NSImage else { return nil }
        image.size = NSSize(width: 24, height: 24)
        return image
    }

    func setWhitespaceHighlighted(_ highlighted: Bool) {
        applySelection(highlighted, to: whitespaceButton)
    }

    func setCompareModeHighlighted(isStrict: Bool) {
        applySelection(isStrict, to: strictButton)
        applySelection(!isStrict, to: ignoreButton)
    }

    private func applySelection(_ selected: Bool, to button: NSButton) {
        button.state = selected ? .on : .off
        button.isBordered = selected
        button.contentTintColor = selected ? .controlAccentColor : nil
        button.needsDisplay = true
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

    @objc private func whitespaceClicked() {
        applySelection(whitespaceButton.state == .on, to: whitespaceButton)
        onWhitespace?()
    }
    @objc private func rulesClicked() { onRules?() }
    @objc private func breakClicked() { onBreak?() }
    @objc private func pullOpenClicked() { onPullOpen?() }
    @objc private func strictClicked() {
        setCompareModeHighlighted(isStrict: true)
        onStrict?()
    }
    @objc private func ignoreClicked() {
        setCompareModeHighlighted(isStrict: false)
        onIgnore?()
    }
    @objc private func undoClicked() { onUndo?() }
    @objc private func diffMapClicked() { onDiffMap?() }
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

/// AppKit's `imageAbove` button cell clips inside titlebar accessories on macOS 26.
private final class DiffToolbarButton: NSButton {
    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 48, height: 58)
    }

    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on || isBordered
        let highlightRect = bounds.insetBy(dx: 2, dy: 2)
        if selected || isHighlighted {
            let fill = selected
                ? NSColor.controlAccentColor.withAlphaComponent(0.14)
                : NSColor.selectedControlColor.withAlphaComponent(0.12)
            let path = NSBezierPath(roundedRect: highlightRect, xRadius: 4, yRadius: 4)
            fill.setFill()
            path.fill()
            if selected {
                NSColor.controlAccentColor.withAlphaComponent(0.55).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }

        let iconSide: CGFloat = 25
        let iconRect = NSRect(
            x: (bounds.width - iconSide) / 2,
            y: 6,
            width: iconSide,
            height: iconSide
        )
        image?.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: isEnabled ? 1 : 0.35,
            respectFlipped: true,
            hints: nil
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let textColor: NSColor = isEnabled ? .labelColor : .disabledControlTextColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        (title as NSString).draw(
            with: NSRect(x: 1, y: 36, width: bounds.width - 2, height: 18),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes
        )
    }
}

/// Icons for the compare toolbar: Notepad-- PNG assets where available,
/// otherwise SF Symbols as fallback.
@MainActor
enum DiffToolbarIcons {
    private static let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)

    static func windowIcon() -> NSImage? {
        bundled("cmpfile")
            ?? UpstreamToolbarBitmap.image(named: "cmpfile")
    }

    static func whitespace() -> NSImage? {
        bundled("white")
            ?? UpstreamToolbarBitmap.image(named: "allChars")
            ?? symbol("character.textbox", accessibility: DiffStrings.toolbarWhitespace)
    }

    static func rules() -> NSImage? {
        bundled("rule")
            ?? symbol("slider.horizontal.3", accessibility: DiffStrings.toolbarRules)
    }

    static func breakAction() -> NSImage? {
        bundled("break")
            ?? symbol("pause.circle", accessibility: DiffStrings.toolbarBreak)
    }

    static func pullOpen() -> NSImage? {
        bundled("pullopen")
            ?? symbol("arrow.left.and.right.square", accessibility: DiffStrings.toolbarPullOpen)
    }

    static func strictMode() -> NSImage? {
        bundled("strict")
            ?? symbol("checkmark.seal", accessibility: DiffStrings.toolbarStrict)
    }

    static func ignoreMode() -> NSImage? {
        bundled("tolerant")
            ?? symbol("eye.slash", accessibility: DiffStrings.toolbarIgnore)
    }

    static func undo() -> NSImage? {
        bundled("undo")
            ?? UpstreamToolbarBitmap.image(named: "undo")
            ?? symbol("arrow.uturn.backward.circle", accessibility: DiffStrings.toolbarUndo)
    }

    static func diffMap() -> NSImage? {
        bundled("diffall")
            ?? symbol("chart.bar.doc.horizontal", accessibility: DiffStrings.toolbarDiffMap)
    }

    static func previous() -> NSImage? {
        bundled("pre")
            ?? symbol("chevron.up.circle", accessibility: DiffStrings.previousDifference)
    }

    static func next() -> NSImage? {
        bundled("next")
            ?? symbol("chevron.down.circle", accessibility: DiffStrings.nextDifference)
    }

    static func zoomIn() -> NSImage? {
        bundled("zoomIn")
            ?? UpstreamToolbarBitmap.image(named: "zoomIn")
            ?? symbol("plus.magnifyingglass", accessibility: DiffStrings.toolbarZoomIn)
    }

    static func zoomOut() -> NSImage? {
        bundled("zoomOut")
            ?? UpstreamToolbarBitmap.image(named: "zoomOut")
            ?? symbol("minus.magnifyingglass", accessibility: DiffStrings.toolbarZoomOut)
    }

    static func clear() -> NSImage? {
        bundled("clear")
            ?? symbol("xmark.circle", accessibility: DiffStrings.toolbarClear)
    }

    static func swap() -> NSImage? {
        bundled("swap")
            ?? bundled("syncH")
            ?? UpstreamToolbarBitmap.image(named: "syncH")
            ?? symbol("arrow.left.arrow.right.circle", accessibility: DiffStrings.swapSides)
    }

    static func refresh() -> NSImage? {
        bundled("reload")
            ?? symbol("arrow.trianglehead.2.clockwise.rotate.90", accessibility: DiffStrings.recompare)
    }

    static func copyLeftToRight() -> NSImage? {
        bundled("right3")
            ?? symbol("arrow.right.doc.on.clipboard", accessibility: DiffStrings.copyLeftToRight)
    }

    static func copyRightToLeft() -> NSImage? {
        bundled("left3")
            ?? symbol("arrow.left.doc.on.clipboard", accessibility: DiffStrings.copyRightToLeft)
    }

    private static func bundled(_ name: String) -> NSImage? {
        CompareToolbarIcon.image(named: name)
    }

    private static func symbol(_ name: String, accessibility: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibility) else {
            return nil
        }
        return image.withSymbolConfiguration(symbolConfig)
    }
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
    static var previousDifferenceCaption: String {
        Localization.string(.diffPreviousCaption, default: "Previous")
    }
    static var nextDifference: String {
        Localization.string(.diffNext, default: "Next Difference (F4)")
    }
    static var nextDifferenceCaption: String {
        Localization.string(.diffNextCaption, default: "Next")
    }
    static var copyLeftToRight: String {
        Localization.string(.diffCopyLeftToRight, default: "Copy Left → Right")
    }
    static var copyLeftToRightCaption: String {
        Localization.string(.diffCopyLeftToRightCaption, default: "L→R")
    }
    static var copyRightToLeft: String {
        Localization.string(.diffCopyRightToLeft, default: "Copy Right → Left")
    }
    static var copyRightToLeftCaption: String {
        Localization.string(.diffCopyRightToLeftCaption, default: "R→L")
    }
    static var swapSides: String {
        Localization.string(.diffSwap, default: "Swap Sides")
    }
    static var swapSidesCaption: String {
        Localization.string(.diffSwapCaption, default: "Swap")
    }
    static var recompare: String {
        Localization.string(.diffRecompare, default: "Recompare (F5)")
    }
    static var recompareCaption: String {
        Localization.string(.diffRecompareCaption, default: "Refresh")
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
    static var toolbarWhitespaceCaption: String {
        Localization.string(.diffToolbarWhitespaceCaption, default: "Whitespace")
    }
    static var toolbarRules: String {
        Localization.string(.diffToolbarRules, default: "Compare Rules")
    }
    static var toolbarRulesCaption: String {
        Localization.string(.diffToolbarRulesCaption, default: "Rules")
    }
    static var toolbarBreak: String {
        Localization.string(.diffToolbarBreak, default: "Cancel comparison")
    }
    static var toolbarBreakCaption: String {
        Localization.string(.diffToolbarBreakCaption, default: "Break")
    }
    static var toolbarPullOpen: String {
        Localization.string(.diffToolbarPullOpen, default: "Center and show current difference")
    }
    static var toolbarPullOpenCaption: String {
        Localization.string(.diffToolbarPullOpenCaption, default: "Pull Open")
    }
    static var toolbarStrict: String {
        Localization.string(.diffToolbarStrict, default: "Strict compare mode")
    }
    static var toolbarStrictCaption: String {
        Localization.string(.diffToolbarStrictCaption, default: "Strict")
    }
    static var toolbarIgnore: String {
        Localization.string(.diffToolbarIgnore, default: "Ignore compare mode")
    }
    static var toolbarIgnoreCaption: String {
        Localization.string(.diffToolbarIgnoreCaption, default: "Ignore")
    }
    static var toolbarUndo: String {
        Localization.string(.diffToolbarUndo, default: "Undo")
    }
    static var toolbarUndoCaption: String {
        Localization.string(.diffToolbarUndoCaption, default: "Undo")
    }
    static var toolbarDiffMap: String {
        Localization.string(.diffToolbarDiffMap, default: "Difference map")
    }
    static var toolbarDiffMapCaption: String {
        Localization.string(.diffToolbarDiffMapCaption, default: "Diff Map")
    }
    static var toolbarZoomIn: String {
        Localization.string(.diffToolbarZoomIn, default: "Zoom In")
    }
    static var toolbarZoomInCaption: String {
        Localization.string(.diffToolbarZoomInCaption, default: "Zoom In")
    }
    static var toolbarZoomOut: String {
        Localization.string(.diffToolbarZoomOut, default: "Zoom Out")
    }
    static var toolbarZoomOutCaption: String {
        Localization.string(.diffToolbarZoomOutCaption, default: "Zoom Out")
    }
    static var toolbarClear: String {
        Localization.string(.diffToolbarClear, default: "Clear Compare")
    }
    static var toolbarClearCaption: String {
        Localization.string(.diffToolbarClearCaption, default: "Clear")
    }
    static var paneOpen: String {
        Localization.string(.diffPaneOpen, default: "Open File")
    }
    static var paneSave: String {
        Localization.string(.diffPaneSave, default: "Save File")
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
    static var computing: String {
        Localization.string(.diffComputing, default: "Computing comparison…")
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
