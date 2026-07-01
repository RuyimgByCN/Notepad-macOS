import AppKit
import NotepadMacCore

/// Window controller for side-by-side file comparison (Notepad-- CompareWin layout).
@MainActor
final class DiffWindowController: NSWindowController, NSWindowDelegate {
    private static let minimumWindowSize = NSSize(width: 900, height: 520)
    private static let minimumContentSize = NSSize(width: 900, height: 488)
    private static let defaultContentSize = NSSize(width: 1100, height: 720)

    var onClose: (() -> Void)?

    private let leftSurface: EditorSurface
    private let rightSurface: EditorSurface
    private let leftHeader = DiffPaneHeader()
    private let rightHeader = DiffPaneHeader()
    private let headerRow = NSView()
    private let chromeContainerView = NSView()
    private let toolbarContainerView = NSView()
    private let editorContainerView = DiffEditorSplitView()
    private let rootView = NSView()
    private let toolbar = DiffToolbar()
    private var toolbarAccessoryController: NSTitlebarAccessoryViewController?
    private var titlebarAccessoryController: NSTitlebarAccessoryViewController?
    private var overviewWidthConstraint: NSLayoutConstraint?
    private let statusField = NSTextField(labelWithString: "")
    private let keyHandlerView = DiffKeyHandlerView()
    private let footerBar: DiffFooterBar
    private let dropReceiverView = DiffDropReceiverView()
    private let overviewBar = DiffOverviewBar()
    private var showsOverviewBar = true

    private(set) var result: FileDiff.DiffResult
    private var leftText: String
    private var rightText: String
    private var leftURL: URL?
    private var rightURL: URL?
    private var leftEncoding: String.Encoding
    private var rightEncoding: String.Encoding
    private var leftSaveEncoding: String.Encoding
    private var rightSaveEncoding: String.Encoding
    private var leftLineEnding: LineEnding = .lf
    private var rightLineEnding: LineEnding = .lf
    private var leftIncludeByteOrderMark: Bool = false
    private var rightIncludeByteOrderMark: Bool = false
    private var compareOptions = FileDiff.CompareOptions.default
    private var undoStack: [(left: String, right: String)] = []

    private var currentHunkIndex: Int = -1
    private var isSyncingScroll = false
    private var showWhitespace = false
    private var fontSize: CGFloat = 13
    private var keyMonitor: Any?
    private var computeTask: Task<Void, Never>?
    private var readyContinuations: [CheckedContinuation<Void, Never>] = []
    private(set) var isReady = false

    /// Await the initial (or in-flight) background diff before asserting on `result`.
    func waitUntilReady() async {
        if isReady { return }
        await withCheckedContinuation { readyContinuations.append($0) }
    }

    /// Test hook: height of the editor pane area after layout.
    var editorSplitHeightForTesting: CGFloat {
        editorContainerView.bounds.height
    }

    /// Test hook: editor container view for rendering checks.
    var editorContainerViewForTesting: NSView {
        editorContainerView
    }

    /// Test hook: the actual left editor surface NSView (Scintilla view when
    /// available) for direct rendering checks that bypass the container layer.
    var leftEditorSurfaceViewForTesting: NSView {
        leftSurface.view
    }

    /// Test hook: width of the left editor pane after layout.
    var editorPaneWidthForTesting: CGFloat {
        leftSurface.view.bounds.width
    }

    /// Test hook: text currently loaded into the left diff pane.
    var leftEditorTextForTesting: String {
        leftSurface.text
    }

    /// Test hook: text currently loaded into the right diff pane.
    var rightEditorTextForTesting: String {
        rightSurface.text
    }

    /// Test hook: editor surface backing the left diff pane.
    var leftEditorSurfaceNameForTesting: String {
        leftSurface.displayName
    }

    /// Test hook: editor surface backing the right diff pane.
    var rightEditorSurfaceNameForTesting: String {
        rightSurface.displayName
    }

    /// Test hook: document view size inside the left diff pane scroll view.
    var leftEditorDocumentSizeForTesting: NSSize {
        editorDocumentSize(leftSurface)
    }

    /// Test hook: document view size inside the right diff pane scroll view.
    var rightEditorDocumentSizeForTesting: NSSize {
        editorDocumentSize(rightSurface)
    }

    /// Test hook: the full-window drag receiver must not paint over visible content.
    var diffDropReceiverIsBehindContentForTesting: Bool {
        guard let dropIndex = rootView.subviews.firstIndex(of: dropReceiverView),
              let editorIndex = rootView.subviews.firstIndex(of: editorContainerView),
              let footerIndex = rootView.subviews.firstIndex(of: footerBar)
        else {
            return false
        }
        return dropIndex < editorIndex
            && dropIndex < footerIndex
    }

    /// Test hook: compare controls are hosted in the titlebar accessory, not the editor content layer.
    var diffChromeUsesTitlebarAccessoryForTesting: Bool {
        titlebarAccessoryController?.view === chromeContainerView
    }

    /// Test hook: the compare toolbar is hosted outside the Scintilla content layer.
    var diffToolbarUsesTitlebarAccessoryForTesting: Bool {
        toolbarAccessoryController?.view === toolbarContainerView
            && toolbar.superview === toolbarContainerView
    }

    private func editorDocumentSize(_ surface: EditorSurface) -> NSSize {
        if let scrollView = surface.view as? NSScrollView,
           let documentView = scrollView.documentView {
            return documentView.bounds.size
        }
        return surface.view.bounds.size
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        if let window {
            enforceMinimumWindowSize(window)
        }
        finishWindowPresentation()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            self.enforceMinimumWindowSize(window)
            self.finishWindowPresentation()
        }
    }

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
        self.leftSaveEncoding = leftEncoding
        self.rightSaveEncoding = rightEncoding
        self.footerBar = DiffFooterBar(state: .init(
            leftEncoding: leftEncoding,
            leftSaveEncoding: leftEncoding,
            rightEncoding: rightEncoding,
            rightSaveEncoding: rightEncoding
        ))
        _ = NSText.didChangeNotification
        _ = NSTextView.didChangeSelectionNotification
        self.leftSurface = EditorSurfaceFactory.makeDiff()
        self.rightSurface = EditorSurfaceFactory.makeDiff()
        self.result = FileDiff.DiffResult(
            leftLines: [],
            rightLines: [],
            hunks: [],
            leftTitle: leftTitle,
            rightTitle: rightTitle
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
        window.minSize = Self.minimumWindowSize
        window.contentMinSize = Self.minimumContentSize
        window.setFrameAutosaveName("NotepadMacDiffWindow.v5")
        enforceMinimumWindowSize(window)
        if window.frame == NSRect(x: 0, y: 0, width: 1100, height: 720) {
            window.center()
        }
        configureContent()
        updateWindowTitle()
        updatePaneHeaders()
        showComputingStatus()
        installKeyMonitor()
        scheduleCompute()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    private func configureContent() {
        guard let window else { return }
        rootView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootView

        dropReceiverView.translatesAutoresizingMaskIntoConstraints = false
        dropReceiverView.onDropFile = { [weak self] url, side in
            self?.openDroppedFile(url, side: side)
        }

        overviewBar.translatesAutoresizingMaskIntoConstraints = false
        overviewBar.onSelectHunk = { [weak self] idx in
            guard let self else { return }
            self.currentHunkIndex = idx
            self.scrollToCurrentHunk()
            self.updateStatus()
        }

        leftSurface.configureForDiff()
        rightSurface.configureForDiff()
        leftSurface.applyFont(size: fontSize)
        rightSurface.applyFont(size: fontSize)
        leftSurface.applyLineNumberMargin(true)
        rightSurface.applyLineNumberMargin(true)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        wireToolbar()
        syncToolbarModeState()

        leftHeader.translatesAutoresizingMaskIntoConstraints = false
        rightHeader.translatesAutoresizingMaskIntoConstraints = false
        leftHeader.onOpen = { [weak self] in self?.openFile(side: .left) }
        rightHeader.onOpen = { [weak self] in self?.openFile(side: .right) }
        leftHeader.onSave = { [weak self] in self?.saveFile(side: .left) }
        rightHeader.onSave = { [weak self] in self?.saveFile(side: .right) }

        statusField.translatesAutoresizingMaskIntoConstraints = false
        statusField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusField.textColor = .secondaryLabelColor
        statusField.alignment = .left

        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.onChange = { [weak self] state in
            guard let self else { return }
            self.leftEncoding = state.leftEncoding
            self.rightEncoding = state.rightEncoding
            self.leftSaveEncoding = state.leftSaveEncoding
            self.rightSaveEncoding = state.rightSaveEncoding
            self.updatePaneHeaders()
        }

        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(leftHeader)
        headerRow.addSubview(rightHeader)
        NSLayoutConstraint.activate([
            leftHeader.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            leftHeader.topAnchor.constraint(equalTo: headerRow.topAnchor),
            leftHeader.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),
            leftHeader.trailingAnchor.constraint(equalTo: headerRow.centerXAnchor),

            rightHeader.leadingAnchor.constraint(equalTo: headerRow.centerXAnchor),
            rightHeader.topAnchor.constraint(equalTo: headerRow.topAnchor),
            rightHeader.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor),
            rightHeader.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
        ])

        chromeContainerView.translatesAutoresizingMaskIntoConstraints = false

        toolbarContainerView.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainerView.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbarContainerView.heightAnchor.constraint(equalToConstant: DiffToolbar.barHeight),

            toolbar.leadingAnchor.constraint(equalTo: toolbarContainerView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: toolbarContainerView.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: toolbarContainerView.topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: toolbarContainerView.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: DiffToolbar.barHeight),
        ])
        let toolbarAccessory = NSTitlebarAccessoryViewController()
        toolbarAccessory.view = toolbarContainerView
        toolbarAccessory.layoutAttribute = .bottom
        window.addTitlebarAccessoryViewController(toolbarAccessory)
        toolbarAccessoryController = toolbarAccessory

        chromeContainerView.addSubview(headerRow)
        NSLayoutConstraint.activate([
            chromeContainerView.heightAnchor.constraint(equalToConstant: DiffPaneHeader.headerHeight),

            headerRow.leadingAnchor.constraint(equalTo: chromeContainerView.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: chromeContainerView.trailingAnchor),
            headerRow.topAnchor.constraint(equalTo: chromeContainerView.topAnchor),
            headerRow.bottomAnchor.constraint(equalTo: chromeContainerView.bottomAnchor),
            headerRow.heightAnchor.constraint(equalToConstant: DiffPaneHeader.headerHeight),
        ])
        let chromeAccessory = NSTitlebarAccessoryViewController()
        chromeAccessory.view = chromeContainerView
        chromeAccessory.layoutAttribute = .bottom
        window.addTitlebarAccessoryViewController(chromeAccessory)
        titlebarAccessoryController = chromeAccessory

        editorContainerView.translatesAutoresizingMaskIntoConstraints = false
        // macOS 26: a bare layer-hosting Scintilla sibling inside the content view
        // suppresses compositing of every sibling layer ordered before it within its
        // vertical band (the diff toolbar/headers stay blank). Hosting the two panes
        // in an NSSplitView — like the main editor window does — gives Scintilla a
        // properly isolated compositing context so the chrome renders again.
        editorContainerView.isVertical = true
        editorContainerView.dividerStyle = .thin
        editorContainerView.addArrangedSubview(leftSurface.view)
        editorContainerView.addArrangedSubview(rightSurface.view)
        leftSurface.view.widthAnchor.constraint(equalTo: rightSurface.view.widthAnchor).isActive = true

        keyHandlerView.translatesAutoresizingMaskIntoConstraints = false
        keyHandlerView.onKeyAction = { [weak self] action in self?.handleKeyAction(action) }

        rootView.addSubview(dropReceiverView)
        rootView.addSubview(footerBar)
        rootView.addSubview(statusField)
        rootView.addSubview(keyHandlerView)
        rootView.addSubview(editorContainerView)
        rootView.addSubview(overviewBar)

        let overviewWidth = overviewBar.widthAnchor.constraint(equalToConstant: 10)
        overviewWidthConstraint = overviewWidth
        let footerHeight = footerBar.heightAnchor.constraint(equalToConstant: 32)

        NSLayoutConstraint.activate([
            editorContainerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            editorContainerView.trailingAnchor.constraint(equalTo: overviewBar.leadingAnchor),
            editorContainerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            editorContainerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            overviewBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            overviewBar.topAnchor.constraint(equalTo: rootView.topAnchor),
            overviewBar.bottomAnchor.constraint(equalTo: editorContainerView.bottomAnchor),
            overviewWidth,

            footerBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: statusField.topAnchor),
            footerHeight,

            statusField.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 10),
            statusField.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -10),
            statusField.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -5),
            statusField.heightAnchor.constraint(equalToConstant: 18),

            keyHandlerView.widthAnchor.constraint(equalToConstant: 1),
            keyHandlerView.heightAnchor.constraint(equalToConstant: 1),
            keyHandlerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            keyHandlerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            dropReceiverView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            dropReceiverView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            dropReceiverView.topAnchor.constraint(equalTo: rootView.topAnchor),
            dropReceiverView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])

        editorContainerView.setContentHuggingPriority(.defaultLow, for: .vertical)
        editorContainerView.setContentCompressionResistancePriority(.required, for: .vertical)
        toolbar.setContentCompressionResistancePriority(.required, for: .vertical)
        toolbarContainerView.setContentCompressionResistancePriority(.required, for: .vertical)
        headerRow.setContentCompressionResistancePriority(.required, for: .vertical)
        footerBar.setContentCompressionResistancePriority(.required, for: .vertical)

        let editorMinHeight = editorContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        editorMinHeight.priority = .defaultHigh
        editorMinHeight.isActive = true

        window.layoutIfNeeded()
        layoutEditorSplit()
        window.makeFirstResponder(keyHandlerView)
        if ProcessInfo.processInfo.arguments.contains("--smoke-hide-editor") {
            editorContainerView.isHidden = true
        }
    }

    /// Called after the window is shown so the first layout pass uses a real content size.
    func finishWindowPresentation() {
        if let window {
            enforceMinimumWindowSize(window)
        }
        window?.layoutIfNeeded()
        layoutEditorSplit()
        if isReady {
            // Scintilla may miss the first paint if text was set before the pane
            // received its final size — re-apply once geometry is stable.
            let leftJoined = result.leftLines.map(\.text).joined(separator: "\n")
            let rightJoined = result.rightLines.map(\.text).joined(separator: "\n")
            leftSurface.text = leftJoined
            rightSurface.text = rightJoined
            renderHighlights()
        }
        refreshEditorSurfaces()
        toolbar.needsDisplay = true
        toolbar.displayIfNeeded()
    }

    private func layoutEditorSplit() {
        editorContainerView.layoutSubtreeIfNeeded()
    }

    private func enforceMinimumWindowSize(_ window: NSWindow) {
        let contentSizeBefore = window.contentView?.bounds.size ?? .zero
        let frameBefore = window.frame
        guard contentSizeBefore.width < Self.minimumContentSize.width
            || contentSizeBefore.height < Self.minimumContentSize.height
            || frameBefore.width < Self.minimumWindowSize.width
            || frameBefore.height < Self.minimumWindowSize.height
        else { return }

        let autosaveName = window.frameAutosaveName
        if !autosaveName.isEmpty {
            UserDefaults.standard.removeObject(forKey: "NSWindow Frame \(autosaveName)")
        }

        let desiredContentSize = NSSize(
            width: max(contentSizeBefore.width, Self.defaultContentSize.width, Self.minimumContentSize.width),
            height: max(contentSizeBefore.height, Self.defaultContentSize.height, Self.minimumContentSize.height)
        )
        var desiredFrame = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: desiredContentSize)
        )
        desiredFrame.size.width = max(desiredFrame.width, Self.minimumWindowSize.width)
        desiredFrame.size.height = max(desiredFrame.height, Self.minimumWindowSize.height)
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if desiredFrame.width > visible.width {
                desiredFrame.size.width = visible.width
            }
            if desiredFrame.height > visible.height {
                desiredFrame.size.height = visible.height
            }
            desiredFrame.origin.x = visible.midX - desiredFrame.width / 2
            desiredFrame.origin.y = visible.midY - desiredFrame.height / 2
        } else {
            desiredFrame.origin = window.frame.origin
            desiredFrame.origin.y += frameBefore.height - desiredFrame.height
        }

        window.setFrame(desiredFrame, display: true, animate: false)
        window.contentMinSize = Self.minimumContentSize
        window.minSize = Self.minimumWindowSize
        if !autosaveName.isEmpty {
            window.setFrameAutosaveName(autosaveName)
        }
        if ProcessInfo.processInfo.arguments.contains("--smoke-diff") {
            try? "\(window.windowNumber)".write(toFile: "/tmp/diff_winid.txt", atomically: true, encoding: .utf8)
        }
    }

    private func refreshEditorSurfaces() {
        layoutEditorSplit()
        editorContainerView.layoutSubtreeIfNeeded()
        for surface in [leftSurface, rightSurface] {
            surface.refreshDisplayAfterLayout()
            let view = surface.view
            view.needsDisplay = true
            view.displayIfNeeded()
            if view.window != nil {
                view.postsFrameChangedNotifications = true
                NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: view)
            }
        }
        scheduleDiffRepaint()
        if ProcessInfo.processInfo.arguments.contains("--smoke-diff") {
            if let num = window?.windowNumber {
                try? "\(num)".write(toFile: "/tmp/diff_winid.txt", atomically: true, encoding: .utf8)
            }
            let all = NSApp.windows.map { "\($0.windowNumber)\t\($0.title)\tvisible=\($0.isVisible)" }.joined(separator: "\n")
            try? all.write(toFile: "/tmp/diff_allwins.txt", atomically: true, encoding: .utf8)

            func describeScintilla(_ root: NSView, _ tag: String) -> String {
                var out: [String] = []
                func walk(_ v: NSView, _ depth: Int) {
                    let cls = String(describing: type(of: v))
                    if cls.contains("SCIContent") || cls.contains("Scintilla") || cls.contains("InnerView") {
                        let cs = v.layer?.contentsScale ?? -1
                        let fmt = v.layer?.contentsFormat.rawValue ?? "nil"
                        out.append("\(tag) \(cls) wantsLayer=\(v.wantsLayer) layer=\(v.layer != nil) opaque=\(v.isOpaque) scale=\(cs) fmt=\(fmt)")
                    }
                    v.subviews.forEach { walk($0, depth + 1) }
                }
                walk(root, 0)
                return out.joined(separator: "\n")
            }
            var dump: [String] = []
            dump.append("screen=\(String(describing: NSScreen.main?.colorSpace))")
            for win in NSApp.windows where win.isVisible {
                if let cv = win.contentView {
                    dump.append("WIN \(win.windowNumber) '\(win.title)' isOpaque=\(win.isOpaque) winCS=\(String(describing: win.colorSpace)) cv.wantsLayer=\(cv.wantsLayer) cv.layer=\(cv.layer != nil) cv.fmt=\(cv.layer?.contentsFormat.rawValue ?? "nil")")
                    dump.append(describeScintilla(cv, "  "))
                }
            }
            try? dump.joined(separator: "\n").write(toFile: "/tmp/diff_scidump.txt", atomically: true, encoding: .utf8)
        }
    }

    /// Scintilla grows its content view from one line to the full viewport height
    /// *after* the synchronous layout pass, and on macOS 26 the newly exposed
    /// layer backing keeps stale grey pixels until something repaints it. Force a
    /// full repaint on the next run-loop turns once that growth has settled.
    private func scheduleDiffRepaint() {
        DispatchQueue.main.async { [weak self] in
            self?.forceDiffRepaint()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.forceDiffRepaint()
        }
    }

    private func forceDiffRepaint() {
        leftSurface.forceDiffRepaint()
        rightSurface.forceDiffRepaint()
    }

    func windowDidResize(_ notification: Notification) {
        layoutEditorSplit()
        window?.layoutIfNeeded()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        finishWindowPresentation()
    }

    private func toggleOverviewBar() {
        showsOverviewBar.toggle()
        overviewBar.isHidden = !showsOverviewBar
        overviewWidthConstraint?.constant = showsOverviewBar ? 10 : 0
        window?.layoutIfNeeded()
    }

    private func openDroppedFile(_ url: URL, side: DiffDropReceiverView.Side) {
        do {
            let loaded = try TextFileCodec.read(url)
            switch side {
            case .left:
                leftText = loaded.text
                leftURL = url
                leftEncoding = loaded.encoding
                leftSaveEncoding = loaded.encoding
                leftLineEnding = loaded.lineEnding
                leftIncludeByteOrderMark = TextFileSavePolicy.loaded(loaded).includeByteOrderMark(for: loaded.encoding)
            case .right:
                rightText = loaded.text
                rightURL = url
                rightEncoding = loaded.encoding
                rightSaveEncoding = loaded.encoding
                rightLineEnding = loaded.lineEnding
                rightIncludeByteOrderMark = TextFileSavePolicy.loaded(loaded).includeByteOrderMark(for: loaded.encoding)
            }
            recompute()
            updatePaneHeaders()
        } catch {
            NSApp.presentError(error)
        }
    }

    private enum CompareSide { case left, right }

    private func wireToolbar() {
        toolbar.onWhitespace = { [weak self] in self?.toggleWhitespace() }
        toolbar.onRules = { [weak self] in self?.showCompareOptions() }
        toolbar.onBreak = { [weak self] in self?.breakCompute() }
        toolbar.onPullOpen = { [weak self] in self?.pullOpen() }
        toolbar.onStrict = { [weak self] in self?.setCompareMode(.deep) }
        toolbar.onIgnore = { [weak self] in self?.setCompareMode(.quick) }
        toolbar.onUndo = { [weak self] in self?.undoLastEdit() }
        toolbar.onDiffMap = { [weak self] in self?.toggleOverviewBar() }
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
            path: leftURL?.path,
            encoding: leftEncoding,
            encodingLabel: DiffStrings.paneLeftEncoding
        )
        rightHeader.update(
            title: result.rightTitle,
            path: rightURL?.path,
            encoding: rightEncoding,
            encodingLabel: DiffStrings.paneRightEncoding
        )
        footerBar.update(state: .init(
            leftEncoding: leftEncoding,
            leftSaveEncoding: leftSaveEncoding,
            rightEncoding: rightEncoding,
            rightSaveEncoding: rightSaveEncoding
        ))
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
        leftSurface.applyLineNumberMargin(true)
        rightSurface.applyLineNumberMargin(true)
        leftSurface.applyShowWhitespace(showWhitespace)
        rightSurface.applyShowWhitespace(showWhitespace)

        renderHighlights()
        overviewBar.result = result
        updateStatus()
        toolbar.setWhitespaceHighlighted(showWhitespace)
        layoutEditorSplit()
        window?.layoutIfNeeded()
        refreshEditorSurfaces()
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
        pushUndo()
        rightText = newRight
        recompute()
    }

    func copyCurrentHunkRightToLeft() {
        guard currentHunkIndex >= 0, currentHunkIndex < result.hunks.count else { return }
        guard let newLeft = FileDiff.applyRightToLeft(result, hunkIndex: currentHunkIndex) else { return }
        pushUndo()
        leftText = newLeft
        recompute()
    }

    func swapSides() {
        pushUndo()
        swap(&leftText, &rightText)
        swap(&leftURL, &rightURL)
        swap(&leftEncoding, &rightEncoding)
        swap(&leftSaveEncoding, &rightSaveEncoding)
        swap(&leftLineEnding, &rightLineEnding)
        swap(&leftIncludeByteOrderMark, &rightIncludeByteOrderMark)
        let swapTitle = result.leftTitle
        result = FileDiff.DiffResult(
            leftLines: result.leftLines,
            rightLines: result.rightLines,
            hunks: result.hunks,
            leftTitle: result.rightTitle,
            rightTitle: swapTitle
        )
        currentHunkIndex = -1
        updateWindowTitle()
        updatePaneHeaders()
        scheduleCompute()
    }

    func recompare() {
        if let url = leftURL {
            if let loaded = try? TextFileCodec.read(url) {
                leftText = loaded.text
                leftEncoding = loaded.encoding
                leftLineEnding = loaded.lineEnding
                leftIncludeByteOrderMark = TextFileSavePolicy.loaded(loaded).includeByteOrderMark(for: loaded.encoding)
            }
        }
        if let url = rightURL {
            if let loaded = try? TextFileCodec.read(url) {
                rightText = loaded.text
                rightEncoding = loaded.encoding
                rightLineEnding = loaded.lineEnding
                rightIncludeByteOrderMark = TextFileSavePolicy.loaded(loaded).includeByteOrderMark(for: loaded.encoding)
            }
        }
        recompute()
    }

    private func clearCompare() {
        pushUndo()
        leftText = ""
        rightText = ""
        leftURL = nil
        rightURL = nil
        currentHunkIndex = -1
        updatePaneHeaders()
        scheduleCompute()
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
            self.syncToolbarModeState()
            self.recompute()
        }
        if let window {
            window.beginSheet(panel.window!) { _ in }
        } else {
            panel.showWindow(nil)
        }
    }

    private func breakCompute() {
        computeTask?.cancel()
        computeTask = nil
        statusField.stringValue = Localization.string("diff.status.canceled", default: "Canceled")
        statusField.textColor = .secondaryLabelColor
    }

    private func pullOpen() {
        layoutEditorSplit()
        finishWindowPresentation()
        scrollToCurrentHunk()
    }

    private func setCompareMode(_ mode: FileDiff.CompareOptions.CompareMode) {
        compareOptions.mode = mode
        syncToolbarModeState()
        if mode == .deep {
            flashStatus(Localization.string("diff.mode.deep", default: "current exec rule mode is deep slow mode, please wait ..."))
        } else {
            flashStatus(Localization.string("diff.mode.quick", default: "current exec rule mode is quick mode, please wait ..."))
        }
        recompute()
    }

    private func syncToolbarModeState() {
        toolbar.setCompareModeHighlighted(isStrict: compareOptions.mode == .deep)
    }

    private func pushUndo() {
        undoStack.append((left: leftText, right: rightText))
        if undoStack.count > 50 { undoStack.removeFirst(undoStack.count - 50) }
    }

    private func undoLastEdit() {
        guard let last = undoStack.popLast() else { return }
        leftText = last.left
        rightText = last.right
        recompute()
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
                leftLineEnding = loaded.lineEnding
                leftIncludeByteOrderMark = TextFileSavePolicy.loaded(loaded).includeByteOrderMark(for: loaded.encoding)
            case .right:
                rightText = loaded.text
                rightURL = url
                rightEncoding = loaded.encoding
                rightLineEnding = loaded.lineEnding
                rightIncludeByteOrderMark = TextFileSavePolicy.loaded(loaded).includeByteOrderMark(for: loaded.encoding)
            }
            recompute()
            updatePaneHeaders()
        } catch {
            NSApp.presentError(error)
        }
    }

    private func saveFile(side: CompareSide) {
        let url: URL?
        let text: String
        let saveEncoding: String.Encoding
        let lineEnding: LineEnding
        let includeByteOrderMark: Bool

        switch side {
        case .left:
            url = leftURL
            text = leftText
            saveEncoding = leftSaveEncoding
            lineEnding = leftLineEnding
            includeByteOrderMark = leftIncludeByteOrderMark
        case .right:
            url = rightURL
            text = rightText
            saveEncoding = rightSaveEncoding
            lineEnding = rightLineEnding
            includeByteOrderMark = rightIncludeByteOrderMark
        }

        if let url {
            do {
                let bom = includeByteOrderMark && saveEncoding.supportsByteOrderMarkIntent
                try TextFileCodec.write(text, to: url, encoding: saveEncoding, lineEnding: lineEnding, includeByteOrderMark: bom)
                flashStatus("Saved: \(url.lastPathComponent)")
            } catch {
                NSApp.presentError(error)
            }
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = side == .left ? result.leftTitle : result.rightTitle
        panel.prompt = DiffStrings.paneSave
        guard panel.runModal() == .OK, let chosenURL = panel.url else { return }
        do {
            let bom = includeByteOrderMark && saveEncoding.supportsByteOrderMarkIntent
            try TextFileCodec.write(text, to: chosenURL, encoding: saveEncoding, lineEnding: lineEnding, includeByteOrderMark: bom)
            if side == .left {
                leftURL = chosenURL
            } else {
                rightURL = chosenURL
            }
            updatePaneHeaders()
            flashStatus("Saved: \(chosenURL.lastPathComponent)")
        } catch {
            NSApp.presentError(error)
        }
    }

    private func recompute() {
        scheduleCompute()
    }

    private func showComputingStatus() {
        statusField.stringValue = DiffStrings.computing
        statusField.textColor = .secondaryLabelColor
        toolbar.updateHunkCount(current: 0, total: 0)
    }

    private func scheduleCompute() {
        isReady = false
        showComputingStatus()
        computeTask?.cancel()
        let left = leftText
        let right = rightText
        let leftTitle = result.leftTitle
        let rightTitle = result.rightTitle
        let options = compareOptions
        let preservedHunkIndex = currentHunkIndex
        computeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let computed = await Task.detached(priority: .userInitiated) {
                FileDiff.compute(
                    left: left,
                    right: right,
                    leftTitle: leftTitle,
                    rightTitle: rightTitle,
                    options: options
                )
            }.value
            guard !Task.isCancelled else { return }
            self.result = computed
            self.currentHunkIndex = computed.hunks.isEmpty
                ? -1
                : min(max(preservedHunkIndex, 0), computed.hunks.count - 1)
            self.render()
            self.finishCompute()
            DispatchQueue.main.async { [weak self] in
                self?.finishWindowPresentation()
            }
        }
    }

    private func finishCompute() {
        isReady = true
        let continuations = readyContinuations
        readyContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
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
        computeTask?.cancel()
        computeTask = nil
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

/// Hosts the two diff panes side by side. Using an NSSplitView (as the main editor
/// window does) gives the layer-hosting Scintilla panes an isolated compositing
/// context so the surrounding chrome composites correctly on macOS 26.
private final class DiffEditorSplitView: NSSplitView {
    override var dividerColor: NSColor { .separatorColor }
}
