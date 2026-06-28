import AppKit
import NotepadMacCore

/// Window controller for side-by-side file comparison.
///
/// Owns two read-only `EditorSurface` panes (left / right) laid out in a split
/// view, renders the result of `FileDiff.compute` as line background tints and
/// inline character highlights, and supports navigating between hunks and
/// copying a hunk from one side to the other.
///
/// The two panes stay aligned because `FileDiff` inserts virtual "pad" lines so
/// that both aligned line arrays have equal length; sync-scrolling then maps a
/// line on one side to the same aligned index on the other.
@MainActor
final class DiffWindowController: NSWindowController, NSWindowDelegate {

    /// Called when the window closes, so the owner (AppDelegate) can drop its
    /// reference to this controller.
    var onClose: (() -> Void)?

    private let leftSurface: EditorSurface
    private let rightSurface: EditorSurface
    private let splitView = NSSplitView()
    private let toolbar = DiffToolbar()
    private let statusField = NSTextField(labelWithString: "")
    private let leftTitleField = NSTextField(labelWithString: "")
    private let rightTitleField = NSTextField(labelWithString: "")

    /// Current comparison result (reflects the latest apply/swap).
    private(set) var result: FileDiff.DiffResult

    /// Current working text on each side (mutated by copy operations).
    private var leftText: String
    private var rightText: String

    /// Index of the hunk the navigation cursor currently points at.
    /// `-1` means "before the first hunk".
    private var currentHunkIndex: Int = -1

    /// Guards recursive sync-scroll handlers.
    private var isSyncingScroll = false

    init(left: String, right: String, leftTitle: String, rightTitle: String) {
        self.leftText = left
        self.rightText = right
        self.leftSurface = EditorSurfaceFactory.make()
        self.rightSurface = EditorSurfaceFactory.make()
        self.result = FileDiff.compute(
            left: left, right: right, leftTitle: leftTitle, rightTitle: rightTitle
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.delegate = self
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("NotepadMacDiffWindow")
        if window.frame == NSRect(x: 0, y: 0, width: 1100, height: 720) {
            window.center()
        }
        configureContent()
        updateWindowTitle()
        render()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    private func configureContent() {
        guard let window else { return }
        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootView

        leftSurface.configureForDiff()
        rightSurface.configureForDiff()

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        wireToolbar()

        for (field, title) in [(leftTitleField, result.leftTitle), (rightTitleField, result.rightTitle)] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.font = .systemFont(ofSize: 11, weight: .medium)
            field.textColor = .secondaryLabelColor
            field.lineBreakMode = .byTruncatingMiddle
            field.maximumNumberOfLines = 1
            field.stringValue = title
        }

        statusField.translatesAutoresizingMaskIntoConstraints = false
        statusField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusField.textColor = .secondaryLabelColor
        statusField.alignment = .center

        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(leftSurface.view)
        splitView.addArrangedSubview(rightSurface.view)

        let leftColumn = NSStackView(views: [leftTitleField])
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        leftColumn.orientation = .horizontal
        leftColumn.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)

        let rightColumn = NSStackView(views: [rightTitleField])
        rightColumn.translatesAutoresizingMaskIntoConstraints = false
        rightColumn.orientation = .horizontal
        rightColumn.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)

        let titleRow = NSSplitView()
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.isVertical = true
        titleRow.dividerStyle = .thin
        titleRow.addArrangedSubview(leftColumn)
        titleRow.addArrangedSubview(rightColumn)

        rootView.addSubview(toolbar)
        rootView.addSubview(titleRow)
        rootView.addSubview(splitView)
        rootView.addSubview(statusField)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: rootView.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: DiffToolbar.barHeight),

            titleRow.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            titleRow.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            titleRow.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            titleRow.heightAnchor.constraint(equalToConstant: 20),

            splitView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: titleRow.bottomAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusField.topAnchor),

            statusField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            statusField.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -5),
        ])
    }

    private func wireToolbar() {
        toolbar.onPrevious = { [weak self] in self?.navigatePrevious() }
        toolbar.onNext = { [weak self] in self?.navigateNext() }
        toolbar.onCopyLeftToRight = { [weak self] in self?.copyCurrentHunkLeftToRight() }
        toolbar.onCopyRightToLeft = { [weak self] in self?.copyCurrentHunkRightToLeft() }
        toolbar.onSwap = { [weak self] in self?.swapSides() }
        toolbar.onRefresh = { [weak self] in self?.recompare() }
        toolbar.onClose = { [weak self] in self?.close() }
    }

    private func updateWindowTitle() {
        window?.title = "\(DiffStrings.windowTitle): \(result.leftTitle) ↔ \(result.rightTitle)"
    }

    // MARK: - Rendering

    /// Re-emit the current `result` into both panes and refresh highlights.
    private func render() {
        let leftJoined = result.leftLines.map(\.text).joined(separator: "\n")
        let rightJoined = result.rightLines.map(\.text).joined(separator: "\n")

        leftSurface.text = leftJoined
        rightSurface.text = rightJoined

        leftSurface.configureForDiff()
        rightSurface.configureForDiff()

        renderHighlights()
        updateStatus()
    }

    private func renderHighlights() {
        let leftHL = result.leftLines.enumerated().compactMap { idx, line -> DiffLineHighlight? in
            // Aligned index is 1-based line number in the pane.
            let kind: DiffLineHighlight.Kind?
            switch line.kind {
            case .added: kind = nil  // added only appears on the right
            case .removed: kind = .removed
            case .changed: kind = .changed
            case .pad: kind = .pad
            case .common: kind = nil
            }
            guard let k = kind else { return nil }
            return DiffLineHighlight(line: idx + 1, kind: k)
        }
        let rightHL = result.rightLines.enumerated().compactMap { idx, line -> DiffLineHighlight? in
            let kind: DiffLineHighlight.Kind?
            switch line.kind {
            case .added: kind = .added
            case .removed: kind = nil  // removed only appears on the left
            case .changed: kind = .changed
            case .pad: kind = .pad
            case .common: kind = nil
            }
            guard let k = kind else { return nil }
            return DiffLineHighlight(line: idx + 1, kind: k)
        }

        leftSurface.clearDiffInlineHighlights()
        rightSurface.clearDiffInlineHighlights()
        leftSurface.applyDiffLineHighlights(leftHL)
        rightSurface.applyDiffLineHighlights(rightHL)
        renderInlineHighlights()
    }

    /// Apply character-level inline indicators for every changed line in each hunk.
    private func renderInlineHighlights() {
        for hunk in result.hunks {
            // Left side: delete segments for each non-pad left line in the hunk.
            for (offset, segs) in hunk.leftSegments.enumerated() {
                let alignedIndex = hunk.leftRange.lowerBound + offset
                guard alignedIndex < result.leftLines.count,
                      result.leftLines[alignedIndex].kind != .pad,
                      !segs.isEmpty else { continue }
                let ranges = inlineUTF16Ranges(segments: segs, filter: .delete)
                if !ranges.isEmpty {
                    leftSurface.applyDiffInlineHighlights(
                        line: alignedIndex + 1, ranges: ranges, isInsert: false)
                }
            }
            // Right side: insert segments for each non-pad right line in the hunk.
            for (offset, segs) in hunk.rightSegments.enumerated() {
                let alignedIndex = hunk.rightRange.lowerBound + offset
                guard alignedIndex < result.rightLines.count,
                      result.rightLines[alignedIndex].kind != .pad,
                      !segs.isEmpty else { continue }
                let ranges = inlineUTF16Ranges(segments: segs, filter: .insert)
                if !ranges.isEmpty {
                    rightSurface.applyDiffInlineHighlights(
                        line: alignedIndex + 1, ranges: ranges, isInsert: true)
                }
            }
        }
    }

    /// Convert inline segments of a given edit type into 0-based UTF-16 ranges
    /// relative to the start of the line.
    private func inlineUTF16Ranges(
        segments: [FileDiff.InlineSegment],
        filter: FileDiff.InlineSegment.Edit
    ) -> [NSRange] {
        var ranges: [NSRange] = []
        var offset = 0
        for seg in segments {
            let length = seg.text.utf16.count
            if seg.edit == filter {
                ranges.append(NSRange(location: offset, length: length))
            }
            offset += length
        }
        return ranges
    }

    private func updateStatus() {
        if result.isIdentical {
            statusField.stringValue = DiffStrings.filesIdentical
            statusField.textColor = .systemGreen
            toolbar.updateHunkCount(current: 0, total: 0)
        } else {
            let total = result.hunks.count
            let display = currentHunkIndex < 0 ? 0 : currentHunkIndex + 1
            statusField.stringValue = "\(result.hunks.count) \(result.hunks.count == 1 ? "difference" : "differences")"
            statusField.textColor = .secondaryLabelColor
            toolbar.updateHunkCount(current: display, total: total)
        }
    }

    // MARK: - Navigation

    func navigateNext() {
        guard !result.hunks.isEmpty else { return }
        currentHunkIndex = min(currentHunkIndex + 1, result.hunks.count - 1)
        scrollToCurrentHunk()
        updateStatus()
    }

    func navigatePrevious() {
        guard !result.hunks.isEmpty else { return }
        currentHunkIndex = max(currentHunkIndex - 1, 0)
        scrollToCurrentHunk()
        updateStatus()
    }

    private func scrollToCurrentHunk() {
        guard currentHunkIndex >= 0, currentHunkIndex < result.hunks.count else { return }
        let hunk = result.hunks[currentHunkIndex]
        // Scroll both panes to the top of the hunk.
        if hunk.leftRange.lowerBound < result.leftLines.count {
            leftSurface.scrollDiffToLine(hunk.leftRange.lowerBound + 1)
        }
        if hunk.rightRange.lowerBound < result.rightLines.count {
            rightSurface.scrollDiffToLine(hunk.rightRange.lowerBound + 1)
        }
    }

    // MARK: - Copy / merge

    func copyCurrentHunkLeftToRight() {
        guard currentHunkIndex >= 0, currentHunkIndex < result.hunks.count else { return }
        guard let newRight = FileDiff.applyLeftToRight(result, hunkIndex: currentHunkIndex) else { return }
        rightText = newRight
        recompute()
    }

    func copyCurrentHunkRightToLeft() {
        guard currentHunkIndex >= 0, currentHunkIndex < result.hunks.count else { return }
        guard let newLeft = FileDiff.applyRightToLeft(result, hunkIndex: currentHunkIndex) else { return }
        leftText = newLeft
        recompute()
    }

    func swapSides() {
        let swapText = leftText
        leftText = rightText
        rightText = swapText
        let swapTitle = result.leftTitle
        result = FileDiff.compute(
            left: leftText, right: rightText,
            leftTitle: result.rightTitle, rightTitle: swapTitle
        )
        leftTitleField.stringValue = result.leftTitle
        rightTitleField.stringValue = result.rightTitle
        currentHunkIndex = -1
        updateWindowTitle()
        render()
    }

    /// Re-read the disk files backing each side (no-op if neither has a URL).
    func recompare() {
        recompute()
    }

    private func recompute() {
        result = FileDiff.compute(
            left: leftText, right: rightText,
            leftTitle: result.leftTitle, rightTitle: result.rightTitle
        )
        currentHunkIndex = result.hunks.isEmpty ? -1 : min(max(currentHunkIndex, 0), result.hunks.count - 1)
        render()
    }

    // MARK: - Sync scroll

    /// Sync the right pane's first visible line to the left pane (and vice versa).
    /// Called by observers wired up after the surfaces are ready.
    func syncScrollFromLeft() {
        guard !isSyncingScroll else { return }
        isSyncingScroll = true
        defer { isSyncingScroll = false }
        let line = leftSurface.firstVisibleDiffLine
        rightSurface.scrollDiffToLine(line)
    }

    func syncScrollFromRight() {
        guard !isSyncingScroll else { return }
        isSyncingScroll = true
        defer { isSyncingScroll = false }
        let line = rightSurface.firstVisibleDiffLine
        leftSurface.scrollDiffToLine(line)
    }

    // MARK: - Window delegate

    func windowWillClose(_ notification: Notification) {
        leftSurface.teardown()
        rightSurface.teardown()
        onClose?()
    }
}
