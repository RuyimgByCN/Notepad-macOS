import AppKit
import NotepadMacCore

/// Window controller for side-by-side file comparison (Notepad-- CompareWin layout).
@MainActor
final class DiffWindowController: NSWindowController, NSWindowDelegate {

    var onClose: (() -> Void)?

    private let leftSurface: EditorSurface
    private let rightSurface: EditorSurface
    private let leftHeader = DiffPaneHeader()
    private let rightHeader = DiffPaneHeader()
    private let splitView = NSSplitView()
    private let toolbar = DiffToolbar()
    private let statusField = NSTextField(labelWithString: "")
    private let keyHandlerView = DiffKeyHandlerView()

    private(set) var result: FileDiff.DiffResult
    private var leftText: String
    private var rightText: String
    private var leftURL: URL?
    private var rightURL: URL?
    private var leftEncoding: String.Encoding
    private var rightEncoding: String.Encoding
    private var compareOptions = FileDiff.CompareOptions.default

    private var currentHunkIndex: Int = -1
    private var isSyncingScroll = false
    private var showWhitespace = false
    private var fontSize: CGFloat = 13
    private var keyMonitor: Any?

    init(
        left: String,
        right: String,
        leftTitle: String,
        rightTitle: String,
        leftURL: URL? = nil,
        rightURL: URL? = nil,
        leftEncoding: String.Encoding = .utf8,
        rightEncoding: String.Encoding = .utf8
    ) {
        self.leftText = left
        self.rightText = right
        self.leftURL = leftURL
        self.rightURL = rightURL
        self.leftEncoding = leftEncoding
        self.rightEncoding = rightEncoding
        self.leftSurface = EditorSurfaceFactory.make()
        self.rightSurface = EditorSurfaceFactory.make()
        self.result = FileDiff.compute(
            left: left, right: right,
            leftTitle: leftTitle, rightTitle: rightTitle,
            options: .default
        )

        let window = DiffWindow(
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
        updatePaneHeaders()
        render()
        installKeyMonitor()
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
        leftSurface.applyFont(size: fontSize)
        rightSurface.applyFont(size: fontSize)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        wireToolbar()

        leftHeader.translatesAutoresizingMaskIntoConstraints = false
        rightHeader.translatesAutoresizingMaskIntoConstraints = false
        leftHeader.onOpen = { [weak self] in self?.openFile(side: .left) }
        rightHeader.onOpen = { [weak self] in self?.openFile(side: .right) }

        statusField.translatesAutoresizingMaskIntoConstraints = false
        statusField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusField.textColor = .secondaryLabelColor
        statusField.alignment = .left

        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let leftColumn = columnView(header: leftHeader, editor: leftSurface.view)
        let rightColumn = columnView(header: rightHeader, editor: rightSurface.view)
        splitView.addArrangedSubview(leftColumn)
        splitView.addArrangedSubview(rightColumn)

        keyHandlerView.translatesAutoresizingMaskIntoConstraints = false
        keyHandlerView.onKeyAction = { [weak self] action in self?.handleKeyAction(action) }

        rootView.addSubview(toolbar)
        rootView.addSubview(splitView)
        rootView.addSubview(statusField)
        rootView.addSubview(keyHandlerView)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: rootView.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: DiffToolbar.barHeight),

            splitView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusField.topAnchor, constant: -4),

            statusField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            statusField.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -5),

            keyHandlerView.widthAnchor.constraint(equalToConstant: 0),
            keyHandlerView.heightAnchor.constraint(equalToConstant: 0),
        ])

        window.makeFirstResponder(keyHandlerView)
    }

    private func columnView(header: DiffPaneHeader, editor: NSView) -> NSView {
        let column = NSView()
        column.translatesAutoresizingMaskIntoConstraints = false
        editor.translatesAutoresizingMaskIntoConstraints = false
        column.addSubview(header)
        column.addSubview(editor)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            header.topAnchor.constraint(equalTo: column.topAnchor),
            header.heightAnchor.constraint(equalToConstant: DiffPaneHeader.headerHeight),

            editor.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            editor.topAnchor.constraint(equalTo: header.bottomAnchor),
            editor.bottomAnchor.constraint(equalTo: column.bottomAnchor),
        ])
        return column
    }

    private enum CompareSide { case left, right }

    private func wireToolbar() {
        toolbar.onWhitespace = { [weak self] in self?.toggleWhitespace() }
        toolbar.onRules = { [weak self] in self?.showCompareOptions() }
        toolbar.onPrevious = { [weak self] in self?.navigatePrevious() }
        toolbar.onNext = { [weak self] in self?.navigateNext() }
        toolbar.onZoomIn = { [weak self] in self?.zoomIn() }
        toolbar.onZoomOut = { [weak self] in self?.zoomOut() }
        toolbar.onClear = { [weak self] in self?.clearCompare() }
        toolbar.onSwap = { [weak self] in self?.swapSides() }
        toolbar.onRefresh = { [weak self] in self?.recompare() }
        toolbar.onCopyLeftToRight = { [weak self] in self?.copyCurrentHunkLeftToRight() }
        toolbar.onCopyRightToLeft = { [weak self] in self?.copyCurrentHunkRightToLeft() }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            switch event.keyCode {
            case 99:  // F3
                self.navigatePrevious()
                return nil
            case 118: // F4
                self.navigateNext()
                return nil
            case 96:  // F5
                self.recompare()
                return nil
            default:
                return event
            }
        }
    }

    private func handleKeyAction(_ action: DiffKeyAction) {
        switch action {
        case .previous: navigatePrevious()
        case .next: navigateNext()
        case .refresh: recompare()
        }
    }

    private func updateWindowTitle() {
        window?.title = "\(DiffStrings.windowTitle): \(result.leftTitle) ↔ \(result.rightTitle)"
    }

    private func updatePaneHeaders() {
        leftHeader.update(
            title: result.leftTitle,
            encoding: leftEncoding,
            encodingLabel: DiffStrings.paneLeftEncoding
        )
        rightHeader.update(
            title: result.rightTitle,
            encoding: rightEncoding,
            encodingLabel: DiffStrings.paneRightEncoding
        )
    }

    // MARK: - Rendering

    private func render() {
        let leftJoined = result.leftLines.map(\.text).joined(separator: "\n")
        let rightJoined = result.rightLines.map(\.text).joined(separator: "\n")

        leftSurface.text = leftJoined
        rightSurface.text = rightJoined

        leftSurface.configureForDiff()
        rightSurface.configureForDiff()
        leftSurface.applyFont(size: fontSize)
        rightSurface.applyFont(size: fontSize)
        leftSurface.applyShowWhitespace(showWhitespace)
        rightSurface.applyShowWhitespace(showWhitespace)

        renderHighlights()
        updateStatus()
        toolbar.setWhitespaceHighlighted(showWhitespace)
    }

    private func renderHighlights() {
        let leftHL = result.leftLines.enumerated().compactMap { idx, line -> DiffLineHighlight? in
            let kind: DiffLineHighlight.Kind?
            switch line.kind {
            case .added: kind = nil
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
            case .removed: kind = nil
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

    private func renderInlineHighlights() {
        for hunk in result.hunks {
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
            statusField.stringValue = DiffStrings.statusDiffCount(total: result.hunks.count)
            statusField.textColor = .secondaryLabelColor
            let display = currentHunkIndex < 0 ? 0 : currentHunkIndex + 1
            toolbar.updateHunkCount(current: display, total: result.hunks.count)
        }
    }

    private func flashStatus(_ message: String) {
        statusField.stringValue = message
        statusField.textColor = .secondaryLabelColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.updateStatus()
        }
    }

    // MARK: - Navigation

    func navigateNext() {
        guard !result.hunks.isEmpty else {
            flashStatus(DiffStrings.statusNoMoreDiffs)
            return
        }
        if currentHunkIndex >= result.hunks.count - 1 {
            flashStatus(DiffStrings.statusAlreadyLast)
            return
        }
        currentHunkIndex = min(currentHunkIndex + 1, result.hunks.count - 1)
        scrollToCurrentHunk()
        updateStatus()
    }

    func navigatePrevious() {
        guard !result.hunks.isEmpty else {
            flashStatus(DiffStrings.statusNoMoreDiffs)
            return
        }
        if currentHunkIndex <= 0 {
            currentHunkIndex = 0
            flashStatus(DiffStrings.statusAlreadyFirst)
            scrollToCurrentHunk()
            updateStatus()
            return
        }
        currentHunkIndex = max(currentHunkIndex - 1, 0)
        scrollToCurrentHunk()
        updateStatus()
    }

    private func scrollToCurrentHunk() {
        guard currentHunkIndex >= 0, currentHunkIndex < result.hunks.count else { return }
        let hunk = result.hunks[currentHunkIndex]
        if hunk.leftRange.lowerBound < result.leftLines.count {
            leftSurface.scrollDiffToLine(hunk.leftRange.lowerBound + 1)
        }
        if hunk.rightRange.lowerBound < result.rightLines.count {
            rightSurface.scrollDiffToLine(hunk.rightRange.lowerBound + 1)
        }
    }

    // MARK: - Toolbar actions

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
        swap(&leftText, &rightText)
        swap(&leftURL, &rightURL)
        swap(&leftEncoding, &rightEncoding)
        let swapTitle = result.leftTitle
        result = FileDiff.compute(
            left: leftText, right: rightText,
            leftTitle: result.rightTitle, rightTitle: swapTitle,
            options: compareOptions
        )
        currentHunkIndex = -1
        updateWindowTitle()
        updatePaneHeaders()
        render()
    }

    func recompare() {
        if let url = leftURL {
            if let loaded = try? TextFileCodec.read(url) {
                leftText = loaded.text
                leftEncoding = loaded.encoding
            }
        }
        if let url = rightURL {
            if let loaded = try? TextFileCodec.read(url) {
                rightText = loaded.text
                rightEncoding = loaded.encoding
            }
        }
        recompute()
    }

    private func clearCompare() {
        leftText = ""
        rightText = ""
        leftURL = nil
        rightURL = nil
        result = FileDiff.compute(
            left: "", right: "",
            leftTitle: result.leftTitle, rightTitle: result.rightTitle,
            options: compareOptions
        )
        currentHunkIndex = -1
        updatePaneHeaders()
        render()
    }

    private func toggleWhitespace() {
        showWhitespace.toggle()
        leftSurface.applyShowWhitespace(showWhitespace)
        rightSurface.applyShowWhitespace(showWhitespace)
        toolbar.setWhitespaceHighlighted(showWhitespace)
    }

    private func zoomIn() {
        fontSize = min(fontSize + 1, 48)
        leftSurface.applyFont(size: fontSize)
        rightSurface.applyFont(size: fontSize)
    }

    private func zoomOut() {
        fontSize = max(fontSize - 1, 8)
        leftSurface.applyFont(size: fontSize)
        rightSurface.applyFont(size: fontSize)
    }

    private func showCompareOptions() {
        let panel = CompareOptionsPanel(options: compareOptions)
        panel.onApply = { [weak self] options in
            guard let self else { return }
            self.compareOptions = options
            self.recompute()
        }
        if let window {
            window.beginSheet(panel.window!) { _ in }
        } else {
            panel.showWindow(nil)
        }
    }

    private func openFile(side: CompareSide) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = DiffStrings.paneOpen
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let loaded = try TextFileCodec.read(url)
            switch side {
            case .left:
                leftText = loaded.text
                leftURL = url
                leftEncoding = loaded.encoding
            case .right:
                rightText = loaded.text
                rightURL = url
                rightEncoding = loaded.encoding
            }
            recompute()
            updatePaneHeaders()
        } catch {
            NSApp.presentError(error)
        }
    }

    private func recompute() {
        result = FileDiff.compute(
            left: leftText, right: rightText,
            leftTitle: result.leftTitle, rightTitle: result.rightTitle,
            options: compareOptions
        )
        currentHunkIndex = result.hunks.isEmpty ? -1 : min(max(currentHunkIndex, 0), result.hunks.count - 1)
        render()
    }

    // MARK: - Sync scroll

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
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        leftSurface.teardown()
        rightSurface.teardown()
        onClose?()
    }
}

// MARK: - Keyboard helpers

enum DiffKeyAction {
    case previous
    case next
    case refresh
}

private final class DiffKeyHandlerView: NSView {
    var onKeyAction: ((DiffKeyAction) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 99: onKeyAction?(.previous); return
        case 118: onKeyAction?(.next); return
        case 96: onKeyAction?(.refresh); return
        default: super.keyDown(with: event)
        }
    }
}

private final class DiffWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
