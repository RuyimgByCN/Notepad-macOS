import AppKit

/// Toolbar for the file-compare window.
///
/// A horizontal strip of buttons for navigating between hunks, copying a hunk
/// from one side to the other, swapping the two sides, and closing the window.
/// All actions are delivered via closures so the toolbar stays free of business
/// logic; the controller wires them up.
@MainActor
final class DiffToolbar: NSView {

    /// Called when the user asks to jump to the previous difference hunk.
    var onPrevious: (() -> Void)?
    /// Called when the user asks to jump to the next difference hunk.
    var onNext: (() -> Void)?
    /// Called when the user asks to copy the current hunk from left to right.
    var onCopyLeftToRight: (() -> Void)?
    /// Called when the user asks to copy the current hunk from right to left.
    var onCopyRightToLeft: (() -> Void)?
    /// Called when the user asks to swap the two sides and recompare.
    var onSwap: (() -> Void)?
    /// Called when the user asks to re-run the comparison (refresh).
    var onRefresh: (() -> Void)?
    /// Called when the user asks to close the compare window.
    var onClose: (() -> Void)?

    private let countField = NSTextField(labelWithString: "")

    /// Static height of the toolbar row.
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

        let prevButton = makeButton(symbol: "chevron.up",
                                    tooltip: DiffStrings.previousDifference,
                                    action: #selector(previousClicked))
        let nextButton = makeButton(symbol: "chevron.down",
                                    tooltip: DiffStrings.nextDifference,
                                    action: #selector(nextClicked))
        let copyLR = makeButton(symbol: "arrow.right",
                                tooltip: DiffStrings.copyLeftToRight,
                                action: #selector(copyLeftToRightClicked))
        let copyRL = makeButton(symbol: "arrow.left",
                                tooltip: DiffStrings.copyRightToLeft,
                                action: #selector(copyRightToLeftClicked))
        let swap = makeButton(symbol: "arrow.left.arrow.right",
                              tooltip: DiffStrings.swapSides,
                              action: #selector(swapClicked))
        let refresh = makeButton(symbol: "arrow.clockwise",
                                 tooltip: DiffStrings.recompare,
                                 action: #selector(refreshClicked))
        let closeButton = makeButton(symbol: "xmark",
                                     tooltip: DiffStrings.close,
                                     action: #selector(closeClicked))

        let stack = NSStackView(views: [prevButton, nextButton, NSView(), copyLR, copyRL, swap, refresh])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        addSubview(stack)
        addSubview(countField)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            countField.centerYAnchor.constraint(equalTo: centerYAnchor),
            countField.leadingAnchor.constraint(equalTo: stack.trailingAnchor, constant: 12),
            countField.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: countField.trailingAnchor, constant: 12),
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

    /// Update the "current / total" hunk counter shown on the right.
    func updateHunkCount(current: Int, total: Int) {
        if total == 0 {
            countField.stringValue = DiffStrings.noDifferences
            countField.textColor = .secondaryLabelColor
        } else {
            let clamped = min(max(current, 1), total)
            countField.stringValue = "\(clamped) / \(total)"
            countField.textColor = .labelColor
        }
    }

    // MARK: - Actions

    @objc private func previousClicked() { onPrevious?() }
    @objc private func nextClicked() { onNext?() }
    @objc private func copyLeftToRightClicked() { onCopyLeftToRight?() }
    @objc private func copyRightToLeftClicked() { onCopyRightToLeft?() }
    @objc private func swapClicked() { onSwap?() }
    @objc private func refreshClicked() { onRefresh?() }
    @objc private func closeClicked() { onClose?() }
}

/// Localized strings for the compare feature. Centralized here so the toolbar,
/// window controller, and menu all reference the same copy.
@MainActor
enum DiffStrings {
    static var windowTitle: String {
        Localization.string(.diffWindowTitle, default: "Compare Files")
    }
    static var previousDifference: String {
        Localization.string(.diffPrevious, default: "Previous Difference")
    }
    static var nextDifference: String {
        Localization.string(.diffNext, default: "Next Difference")
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
        Localization.string(.diffRecompare, default: "Recompare")
    }
    static var close: String {
        Localization.string(.diffClose, default: "Close")
    }
    static var noDifferences: String {
        Localization.string(.diffNoDifferences, default: "No differences")
    }
    static var filesIdentical: String {
        Localization.string(.diffFilesIdentical, default: "Files are identical")
    }
}
