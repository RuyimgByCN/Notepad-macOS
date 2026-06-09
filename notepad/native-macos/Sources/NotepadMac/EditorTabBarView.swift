import AppKit
import NotepadMacCore
import Foundation
import UniformTypeIdentifiers

// MARK: - Tab bar container

enum TabContextAction {
    case closeOthers
    case closeAllButPinned
    case closeUnchanged
    case closeToLeft
    case closeToRight
    case copyFilename
    case copyFullPath
    case copyDirectoryPath
    case openContainingFolder
    case openContainingFolderInTerminal
    case togglePin
    case setColor(Int?)
    case moveToStart
    case moveToEnd
    case moveForward
    case moveBackward
    case save
    case saveAs
    case rename
    case moveToTrash
    case reload
    case print
    case toggleReadOnly
}

@MainActor
final class EditorTabBarView: NSView {
    static let barHeight: CGFloat = 28
    static let compactBarHeight: CGFloat = 22
    static let normalTabFontSize: CGFloat = 12
    static let compactTabFontSize: CGFloat = 10

    /// Current effective bar height based on compactMode
    var currentBarHeight: CGFloat { compactMode ? Self.compactBarHeight : Self.barHeight }

    var onSelectTab: ((EditorTabIdentity) -> Void)?
    var onCloseTab: ((EditorTabIdentity) -> Void)?
    var onRenameTab: ((EditorTabIdentity) -> Void)?
    var onTabContextAction: ((EditorTabIdentity, TabContextAction) -> Void)?
    var onNewTab: (() -> Void)?
    /// Called when user drags a tab to a new position. Args: identity, target index.
    var onReorderTab: ((EditorTabIdentity, Int) -> Void)?
    /// When true, double-clicking a tab closes it
    var doubleClickClosesTab = false
    /// Max characters to show in a tab label (0 = no limit)
    var tabMaxLabelLength = 0
    /// When true, drag-drop tab reordering is disabled
    var lockDragDrop = false
    /// When false, the close (×) button is hidden on all tabs
    var showCloseButton = true
    /// When true, use compact/reduced style (smaller height and font)
    var compactMode = false {
        didSet { applyCompactStyle() }
    }
    /// When true, show tab index numbers (1-9) in tab labels
    var showIndexNumbers = false {
        didSet { rebuildTabs() }
    }
    /// Optional custom tab context menu spec loaded from tabContextMenu.xml
    var tabContextMenuSpec: TabContextMenuSpec?

    private var state = EditorTabState()
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private var tabButtons: [EditorTabButton] = []
    private let newTabButton = NSButton()
    /// Overflow/droplist button — shows all tabs in a popup menu
    private let overflowButton = NSButton()
    /// Width constraint for the overflow button (0 when hidden, 22 when visible)
    private var overflowWidthConstraint: NSLayoutConstraint!
    // Last valid bar width seen in layout(); used by rebuildTabs() so that
    // calls from update(state:) always get the correct width even when
    // scrollView.bounds hasn't been set yet (e.g. before first layout pass).
    private var validBarWidth: CGFloat = 0

    // MARK: - Drag state
    private var draggedButton: EditorTabButton?
    private var dragStartX: CGFloat = 0
    private var dragButtonOriginalFrame: CGRect = .zero
    private var mouseDownInEmptyArea = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScrollView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.documentView = documentView
        addSubview(scrollView)

        newTabButton.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.title = "+"
        newTabButton.font = .systemFont(ofSize: 14, weight: .light)
        newTabButton.bezelStyle = .inline
        newTabButton.isBordered = false
        newTabButton.contentTintColor = .secondaryLabelColor
        newTabButton.target = self
        newTabButton.action = #selector(newTabButtonClicked(_:))
        newTabButton.setAccessibilityLabel("New Tab")
        newTabButton.toolTip = "New Tab"
        addSubview(newTabButton)

        overflowButton.translatesAutoresizingMaskIntoConstraints = false
        overflowButton.title = "▾"
        overflowButton.font = .systemFont(ofSize: 10, weight: .regular)
        overflowButton.bezelStyle = .inline
        overflowButton.isBordered = false
        overflowButton.contentTintColor = .secondaryLabelColor
        overflowButton.target = self
        overflowButton.action = #selector(overflowButtonClicked(_:))
        overflowButton.setAccessibilityLabel("All Tabs")
        overflowButton.toolTip = "Show all open tabs"
        overflowButton.isHidden = true   // shown only when tabs overflow
        addSubview(overflowButton)

        let newTabWidth: CGFloat = 28
        overflowWidthConstraint = overflowButton.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            newTabButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            newTabButton.topAnchor.constraint(equalTo: topAnchor),
            newTabButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: newTabWidth),

            overflowButton.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor),
            overflowButton.topAnchor.constraint(equalTo: topAnchor),
            overflowButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            overflowWidthConstraint,

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: overflowButton.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @objc private func newTabButtonClicked(_ sender: Any?) {
        onNewTab?()
    }

    @objc private func overflowButtonClicked(_ sender: Any?) {
        guard !state.items.isEmpty else { return }
        let menu = NSMenu(title: "")
        for (index, item) in state.items.enumerated() {
            let statusPrefix = item.isMonitoring ? "⟳ " : (item.isDirty ? "• " : "")
            let indexPrefix = (showIndexNumbers && index < 9) ? "\(index + 1): " : ""
            let prefix = indexPrefix + statusPrefix
            let it = ClosureMenuItem(title: prefix + item.title) { [weak self] in
                self?.onSelectTab?(item.identity)
            }
            if item.identity == state.activeIdentity { it.state = .on }
            menu.addItem(it)
        }
        if let button = sender as? NSButton {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    // Double-click on the empty area after tabs creates a new tab; single click is absorbed
    // to prevent AppKit from generating a spurious redraw that causes visible flickering.
    override func mouseDown(with event: NSEvent) {
        let loc = documentView.convert(event.locationInWindow, from: nil)
        let tabsEnd = tabButtons.last?.frame.maxX ?? 0
        if loc.x > tabsEnd {
            mouseDownInEmptyArea = true
            if event.clickCount == 2 {
                onNewTab?()
            }
            return
        }
        mouseDownInEmptyArea = false
        // Detect drag start on a tab button
        let docLoc = documentView.convert(event.locationInWindow, from: nil)
        if let btn = tabButtons.first(where: { $0.frame.contains(docLoc) }) {
            draggedButton = btn
            dragStartX = docLoc.x
            dragButtonOriginalFrame = btn.frame
            btn.alphaValue = 0.6
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let btn = draggedButton, !lockDragDrop else { return }
        let docLoc = documentView.convert(event.locationInWindow, from: nil)
        let delta = docLoc.x - dragStartX
        var newFrame = dragButtonOriginalFrame
        newFrame.origin.x = max(0, dragButtonOriginalFrame.origin.x + delta)
        // Clamp to the right of other tabs
        let maxX = (tabButtons.last?.frame.maxX ?? 0) - newFrame.width
        newFrame.origin.x = min(newFrame.origin.x, maxX)
        btn.frame = newFrame
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownInEmptyArea { mouseDownInEmptyArea = false; return }
        guard let btn = draggedButton, !lockDragDrop else {
            draggedButton?.alphaValue = 1.0
            draggedButton = nil
            super.mouseUp(with: event)
            return
        }
        btn.alphaValue = 1.0
        let centerX = btn.frame.midX

        // Find target index based on center position
        let sortedOriginal = tabButtons.filter { $0 !== btn }
            .sorted { $0.frame.origin.x < $1.frame.origin.x }
        var targetIndex = sortedOriginal.count
        for (i, other) in sortedOriginal.enumerated() {
            if centerX < other.frame.midX {
                targetIndex = i
                break
            }
        }

        let sourceIndex = tabButtons.firstIndex(of: btn) ?? 0
        draggedButton = nil

        // Snap back and trigger reorder if position changed
        rebuildTabs()
        if targetIndex != sourceIndex {
            onReorderTab?(btn.item.identity, targetIndex)
        }
        super.mouseUp(with: event)
    }

    func update(state: EditorTabState) {
        guard state != self.state else { return }
        self.state = state
        rebuildTabs()
    }

    private func applyCompactStyle() {
        let fontSize = compactMode ? Self.compactTabFontSize : Self.normalTabFontSize
        invalidateIntrinsicContentSize()
        // Update existing tab buttons
        for btn in tabButtons {
            btn.compactMode = compactMode
        }
        // Update new-tab button font
        newTabButton.font = .systemFont(ofSize: fontSize, weight: .light)
        // Trigger relayout
        needsLayout = true
    }

    private func rebuildTabs() {
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        // Use the last valid bar width stored by layout(); fall back to scrollView
        // bounds only if layout() has never run (e.g. headless tests).
        let knownWidth = validBarWidth > 0 ? validBarWidth : max(0, scrollView.bounds.width)
        let halfBarWidth = max(EditorTabButton.minWidth, knownWidth / 2)
        let tabMaxWidth = min(EditorTabButton.absoluteMaxWidth, halfBarWidth)

        var x: CGFloat = 0
        for (index, item) in state.items.enumerated() {
            let isActive = item.identity == state.activeIdentity
            let btn = EditorTabButton(
                item: item,
                isActive: isActive,
                tabIndex: showIndexNumbers ? index + 1 : nil,
                onSelect: { [weak self] in self?.onSelectTab?(item.identity) },
                onClose: { [weak self] in self?.onCloseTab?(item.identity) },
                onContextAction: { [weak self] action in self?.onTabContextAction?(item.identity, action) }
            )
            btn.doubleClickClosesTab = doubleClickClosesTab
            btn.maxLabelLength = tabMaxLabelLength
            btn.dynamicMaxWidth = tabMaxWidth
            btn.tabContextMenuSpec = tabContextMenuSpec
            btn.showCloseButton = showCloseButton
            btn.onRename = { [weak self] in self?.onRenameTab?(item.identity) }
            let w = btn.preferredWidth
            btn.frame = CGRect(x: x, y: 0, width: w, height: currentBarHeight)
            documentView.addSubview(btn)
            tabButtons.append(btn)
            x += w
        }

        let totalWidth = max(x, scrollView.bounds.width)
        documentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: currentBarHeight)

        // Show overflow button when tabs exceed the visible scroll area.
        let needsOverflow = x > validBarWidth
        if needsOverflow != !overflowButton.isHidden {
            overflowButton.isHidden = !needsOverflow
            overflowWidthConstraint.constant = needsOverflow ? 22 : 0
            needsLayout = true
        }

        scrollToActiveTab(animated: false)
    }

    private func scrollToActiveTab(animated: Bool) {
        guard let idx = state.items.firstIndex(where: { $0.identity == state.activeIdentity }),
              idx < tabButtons.count else { return }
        let targetFrame = tabButtons[idx].frame
        if animated {
            scrollView.contentView.animator().setBoundsOrigin(
                NSPoint(x: max(0, targetFrame.midX - scrollView.bounds.width / 2), y: 0)
            )
        } else {
            scrollView.contentView.scrollToVisible(targetFrame)
        }
    }

    override func layout() {
        super.layout()
        // Subtract newTabButton (28) and overflow button (0 or 22) from available scroll area.
        let overflowW: CGFloat = overflowButton.isHidden ? 0 : 22
        let w = bounds.width - 28 - overflowW
        guard w > 0 else { return }

        let widthChanged = abs(w - validBarWidth) > 0.5
        validBarWidth = w

        if !tabButtons.isEmpty {
            // Recompute tab widths when the bar is resized or when the initial
            // layout pass finally provides a non-zero width.
            let newMax = min(EditorTabButton.absoluteMaxWidth, max(EditorTabButton.minWidth, w / 2))
            if widthChanged || tabButtons.first?.dynamicMaxWidth != newMax {
                rebuildTabs()
            }
            return
        }
        documentView.frame = CGRect(x: 0, y: 0, width: max(documentView.frame.width, w), height: currentBarHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Bottom separator
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 0.5).fill()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: compactMode ? Self.compactBarHeight : Self.barHeight)
    }
}

// MARK: - Individual tab button

@MainActor
final class EditorTabButton: NSView {
    private static let hPad: CGFloat = 8
    private static let closeSize: CGFloat = 13
    private static let closeRightPad: CGFloat = 5
    private static let documentIconSize: CGFloat = 14
    private static let documentIconTitleGap: CGFloat = 5
    // minWidth must fit: hPad + some text + pin + gap + close + closeRightPad
    static let minWidth: CGFloat = 110
    static let absoluteMaxWidth: CGFloat = 400
    // Set by the tab bar to half its visible width; tabs only truncate when the title exceeds that.
    var dynamicMaxWidth: CGFloat = 300

    let item: EditorTabItem
    private let isActive: Bool
    /// Optional 1-based tab index for display (nil = don't show)
    private let tabIndex: Int?
    private let onSelect: () -> Void
    private let onClose: () -> Void
    private let onContextAction: (TabContextAction) -> Void
    var onRename: (() -> Void)?

    private let documentIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let pinBtn = NSButton()
    private let closeBtn = NSButton()
    private static let pinSize: CGFloat = 12
    private static let pinGap: CGFloat = 3
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    /// When true, double-clicking the tab closes it
    var doubleClickClosesTab = false
    /// Max characters to display in the tab label (0 = no limit)
    var maxLabelLength = 0
    /// Optional XML-driven tab context menu spec
    var tabContextMenuSpec: TabContextMenuSpec?
    /// When false, the close (×) button is never shown on this tab
    var showCloseButton = true
    /// When true, use compact style (smaller font)
    var compactMode = false {
        didSet { titleLabel.font = .systemFont(ofSize: compactMode ? EditorTabBarView.compactTabFontSize : EditorTabBarView.normalTabFontSize) }
    }

    init(item: EditorTabItem, isActive: Bool, tabIndex: Int? = nil, onSelect: @escaping () -> Void, onClose: @escaping () -> Void, onContextAction: @escaping (TabContextAction) -> Void) {
        self.item = item
        self.isActive = isActive
        self.tabIndex = tabIndex
        self.onSelect = onSelect
        self.onClose = onClose
        self.onContextAction = onContextAction
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        documentIconView.image = Self.documentIcon(for: item)
        documentIconView.imageScaling = .scaleProportionallyDown
        documentIconView.contentTintColor = isActive ? .labelColor : .secondaryLabelColor
        documentIconView.alphaValue = isActive ? 0.9 : 0.65
        documentIconView.setAccessibilityLabel("Document")
        addSubview(documentIconView)

        let statusPrefix = item.isMonitoring ? "⟳ " : (item.isDirty ? "• " : "")
        let indexPrefix: String
        if let idx = tabIndex, idx <= 9 {
            indexPrefix = "\(idx): "
        } else {
            indexPrefix = ""
        }
        let prefix = indexPrefix + statusPrefix
        let rawTitle = item.title
        let truncatedTitle = maxLabelLength > 0 && rawTitle.count > maxLabelLength
            ? String(rawTitle.prefix(maxLabelLength)) + "…"
            : rawTitle
        let displayTitle = prefix + truncatedTitle
        titleLabel.stringValue = displayTitle
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = isActive ? .labelColor : .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        // Pin button — shows a filled pin when pinned, outline pin when unpinned (on hover).
        let pinSymbol = item.isPinned ? "pin.fill" : "pin"
        if let img = NSImage(systemSymbolName: pinSymbol, accessibilityDescription: nil) {
            pinBtn.image = img
            pinBtn.imageScaling = .scaleProportionallyDown
            pinBtn.imagePosition = .imageOnly
        }
        pinBtn.bezelStyle = .inline
        pinBtn.isBordered = false
        pinBtn.contentTintColor = item.isPinned ? .controlAccentColor : .secondaryLabelColor
        pinBtn.alphaValue = item.isPinned ? 0.8 : 0.55
        // Always visible when pinned; shown on hover for unpinned (handled in mouseEntered/Exited)
        pinBtn.isHidden = !item.isPinned
        pinBtn.target = self
        pinBtn.action = #selector(pinTapped)
        pinBtn.toolTip = item.isPinned
            ? Localization.string(.windowUnpinTab, default: "取消固定")
            : Localization.string(.windowPinTab, default: "固定标签页")
        addSubview(pinBtn)

        if let img = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) {
            closeBtn.image = img
            closeBtn.imageScaling = .scaleProportionallyDown
            closeBtn.imagePosition = .imageOnly
        } else {
            closeBtn.title = "×"
        }
        closeBtn.bezelStyle = .inline
        closeBtn.isBordered = false
        closeBtn.alphaValue = 0.55
        closeBtn.isHidden = !showCloseButton || !isActive
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        addSubview(closeBtn)
    }

    var preferredWidth: CGFloat {
        let statusPrefix = item.isMonitoring ? "⟳ " : (item.isDirty ? "• " : "")
        let indexPrefix: String
        if let idx = tabIndex, idx <= 9 { indexPrefix = "\(idx): " } else { indexPrefix = "" }
        let text = indexPrefix + statusPrefix + item.title
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12)]
        let textW = (text as NSString).size(withAttributes: attrs).width
        // Always reserve space for pin button because it appears on hover even when unpinned.
        // +12: NSTextField insets (4px) + gap before buttons (4px) + CJK rendering safety (4px)
        let raw = Self.hPad
            + Self.documentIconSize
            + Self.documentIconTitleGap
            + textW
            + 12
            + Self.pinSize
            + Self.pinGap
            + Self.closeSize
            + Self.closeRightPad
        return max(Self.minWidth, min(dynamicMaxWidth, ceil(raw)))
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let iconSz = Self.documentIconSize
        let iconX = Self.hPad
        let iconY = (h - iconSz) / 2
        documentIconView.frame = CGRect(x: iconX, y: iconY, width: iconSz, height: iconSz)

        let closeSz = Self.closeSize
        let closeX = bounds.maxX - closeSz - Self.closeRightPad
        let closeY = (h - closeSz) / 2
        closeBtn.frame = CGRect(x: closeX, y: closeY, width: closeSz, height: closeSz)

        // Pin button sits to the left of the close button.
        let pinSz = Self.pinSize
        let pinX = closeX - pinSz - Self.pinGap
        let pinY = (h - pinSz) / 2
        pinBtn.frame = CGRect(x: pinX, y: pinY, width: pinSz, height: pinSz)

        let titleX = documentIconView.frame.maxX + Self.documentIconTitleGap
        let rightEdge: CGFloat
        if !closeBtn.isHidden {
            // Always leave room for pin button even when hidden, so title doesn't jump on hover.
            rightEdge = pinX - 2
        } else {
            rightEdge = bounds.maxX - Self.hPad
        }
        let titleH: CGFloat = 17
        let titleY = (h - titleH) / 2
        titleLabel.frame = CGRect(x: titleX, y: titleY, width: max(0, rightEdge - titleX), height: titleH)
    }

    @objc private func closeTapped() {
        onClose()
    }

    @objc private func pinTapped() {
        onContextAction(.togglePin)
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if closeBtn.frame.insetBy(dx: -4, dy: -4).contains(loc) { return }
        // Middle-click closes the tab
        if event.buttonNumber == 2 {
            onClose()
            return
        }
        if event.clickCount == 2 && doubleClickClosesTab {
            onClose()
            return
        }
        if event.clickCount == 2 && !doubleClickClosesTab {
            onRename?()
            return
        }
        onSelect()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        closeBtn.isHidden = !showCloseButton
        // Show pin button on hover even for unpinned tabs so users can discover the feature.
        pinBtn.isHidden = false
        needsDisplay = true
        needsLayout = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        closeBtn.isHidden = !showCloseButton || !isActive
        pinBtn.isHidden = !item.isPinned
        needsDisplay = true
        needsLayout = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func draw(_ dirtyRect: NSRect) {
        // Active tab background
        if isActive {
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
            // Top accent line
            NSColor.controlAccentColor.setFill()
            NSRect(x: 0, y: bounds.maxY - 2, width: bounds.width, height: 2).fill()
        } else if isHovered {
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
            bounds.fill()
        }

        // Tab color strip overrides top line
        if let ci = item.tabColorIndex {
            tabColorForIndex(ci).setFill()
            NSRect(x: 0, y: bounds.maxY - 2, width: bounds.width, height: 2).fill()
        }

        // Right separator
        NSColor.separatorColor.withAlphaComponent(0.5).setFill()
        NSRect(x: bounds.maxX - 0.5, y: 3, width: 0.5, height: bounds.height - 6).fill()
    }

    private func tabColorForIndex(_ idx: Int) -> NSColor {
        let palette: [NSColor] = [.systemYellow, .systemGreen, .systemBlue, .systemRed, .systemOrange, .systemPurple]
        guard idx >= 1, idx <= palette.count else { return .clear }
        return palette[idx - 1]
    }

    static func upstreamDocumentIconResourceName(for item: EditorTabItem) -> String {
        if item.isMonitoring {
            return "monitoring"
        }
        return item.isDirty ? "unsaved" : "saved"
    }

    private static func documentIcon(for item: EditorTabItem) -> NSImage {
        let resourceName = upstreamDocumentIconResourceName(for: item)
        let upstreamImage = Bundle.module.url(
            forResource: resourceName,
            withExtension: "ico",
            subdirectory: "UpstreamTabBar"
        ).flatMap { NSImage(contentsOf: $0) }
        let sourceImage = upstreamImage ?? NSWorkspace.shared.icon(for: .plainText)
        let image = (sourceImage.copy() as? NSImage) ?? sourceImage
        image.size = NSSize(width: documentIconSize, height: documentIconSize)
        image.isTemplate = false
        return image
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func buildContextMenu() -> NSMenu {
        if let spec = tabContextMenuSpec {
            return buildContextMenuFromSpec(spec)
        }
        return buildDefaultContextMenu()
    }

    private func buildContextMenuFromSpec(_ spec: TabContextMenuSpec) -> NSMenu {
        let menu = NSMenu(title: "")
        let isFile = { if case .file = self.item.identity { return true }; return false }()

        // Group items by folderName → submenus
        var submenus: [String: NSMenu] = [:]
        var submenuOrder: [String] = []

        func makeItem(specAction: TabContextMenuAction, displayName: String?) -> NSMenuItem {
            let label = displayName ?? localizedLabel(for: specAction)
            let it = specMenuItem(label, specAction: specAction)
            it.isEnabled = isActionEnabled(specAction, isFile: isFile)
            return it
        }

        for specItem in spec.items {
            switch specItem {
            case .separator:
                menu.addItem(.separator())
            case .action(let action, let displayName, let folderName):
                if let folder = folderName {
                    if submenus[folder] == nil {
                        submenus[folder] = NSMenu(title: "")
                        submenuOrder.append(folder)
                        let parent = NSMenuItem(title: folder, action: nil, keyEquivalent: "")
                        parent.submenu = submenus[folder]
                        menu.addItem(parent)
                    }
                    submenus[folder]?.addItem(makeItem(specAction: action, displayName: displayName))
                } else {
                    menu.addItem(makeItem(specAction: action, displayName: displayName))
                }
            }
        }
        return menu
    }

    private func localizedLabel(for action: TabContextMenuAction) -> String {
        switch action {
        case .close:                return Localization.string(.fileClose, default: "Close")
        case .closeOthers, .closeAllButThis: return Localization.string(.fileCloseOthers, default: "Close Others")
        case .closeAllButPinned:    return Localization.string(.fileCloseAllButPinned, default: "Close All but Pinned")
        case .closeToLeft:          return Localization.string(.fileCloseAllToLeft, default: "Close All to the Left")
        case .closeToRight:         return Localization.string(.fileCloseAllToRight, default: "Close All to the Right")
        case .closeUnchanged:       return Localization.string(.fileCloseUnchanged, default: "Close All Unchanged")
        case .save:                 return Localization.string(.fileSave, default: "Save")
        case .saveAs:               return Localization.string(.fileSaveAs, default: "Save As...")
        case .rename:               return Localization.string(.fileRename, default: "Rename...")
        case .moveToTrash:          return Localization.string(.fileMoveToTrash, default: "Move to Trash")
        case .reload:               return Localization.string(.fileReloadFromDisk, default: "Reload from Disk")
        case .print:                return Localization.string(.filePrint, default: "Print...")
        case .toggleReadOnly:       return Localization.string(.editReadOnlyMenu, default: "Set Read-Only")
        case .clearReadOnly:        return "Clear Read-Only"
        case .copyFullPath:         return Localization.string(.editCopyCurrentFullPath, default: "Copy Full Path")
        case .copyFilename:         return Localization.string(.editCopyCurrentFilename, default: "Copy Filename")
        case .copyDirPath:          return Localization.string(.editCopyCurrentDirectoryPath, default: "Copy Dir Path")
        case .moveToStart:          return Localization.string(.windowMoveTabToStart, default: "Move to Start")
        case .moveToEnd:            return Localization.string(.windowMoveTabToEnd, default: "Move to End")
        case .openContainingFolder: return Localization.string(.fileOpenContainingFolder, default: "Open in Finder")
        case .openInTerminal:       return Localization.string(.fileOpenContainingFolderInTerminal, default: "Open in Terminal")
        case .openAsFolderWorkspace: return "Open as Folder Workspace"
        case .openInDefaultViewer:  return "Open in Default Viewer"
        case .applyColor1:          return Localization.string(.windowTabColor1, default: "Yellow")
        case .applyColor2:          return Localization.string(.windowTabColor2, default: "Green")
        case .applyColor3:          return Localization.string(.windowTabColor3, default: "Blue")
        case .applyColor4:          return Localization.string(.windowTabColor4, default: "Red")
        case .applyColor5:          return Localization.string(.windowTabColor5, default: "Orange")
        case .removeColor:          return Localization.string(.windowTabColorNone, default: "Remove Color")
        case .pinTab:               return Localization.string(.windowPinTab, default: "Pin Tab")
        case .unpinTab:             return Localization.string(.windowUnpinTab, default: "Unpin Tab")
        }
    }

    private func tabContextActionFor(_ specAction: TabContextMenuAction) -> TabContextAction {
        switch specAction {
        case .close:                return .closeOthers // handled specially below
        case .closeOthers, .closeAllButThis: return .closeOthers
        case .closeAllButPinned:    return .closeAllButPinned
        case .closeToLeft:          return .closeToLeft
        case .closeToRight:         return .closeToRight
        case .closeUnchanged:       return .closeUnchanged
        case .save:                 return .save
        case .saveAs:               return .saveAs
        case .rename:               return .rename
        case .moveToTrash:          return .moveToTrash
        case .reload:               return .reload
        case .print:                return .print
        case .toggleReadOnly, .clearReadOnly: return .toggleReadOnly
        case .copyFullPath:         return .copyFullPath
        case .copyFilename:         return .copyFilename
        case .copyDirPath:          return .copyDirectoryPath
        case .moveToStart:          return .moveToStart
        case .moveToEnd:            return .moveToEnd
        case .openContainingFolder, .openAsFolderWorkspace: return .openContainingFolder
        case .openInTerminal:       return .openContainingFolderInTerminal
        case .openInDefaultViewer:  return .openContainingFolder
        case .applyColor1:          return .setColor(1)
        case .applyColor2:          return .setColor(2)
        case .applyColor3:          return .setColor(3)
        case .applyColor4:          return .setColor(4)
        case .applyColor5:          return .setColor(5)
        case .removeColor:          return .setColor(nil)
        case .pinTab, .unpinTab:    return .togglePin
        }
    }

    private func specMenuItem(_ title: String, specAction: TabContextMenuAction) -> NSMenuItem {
        if specAction == .close {
            return ClosureMenuItem(title: Localization.string(.fileClose, default: "Close")) { [weak self] in self?.onClose() }
        }
        let tabAction = tabContextActionFor(specAction)
        return ClosureMenuItem(title: title) { [weak self] in self?.onContextAction(tabAction) }
    }

    private func isActionEnabled(_ action: TabContextMenuAction, isFile: Bool) -> Bool {
        switch action {
        case .rename, .moveToTrash, .reload, .openContainingFolder,
             .openInTerminal, .openAsFolderWorkspace, .openInDefaultViewer,
             .copyFullPath, .copyDirPath:
            return isFile
        default:
            return true
        }
    }

    private func buildDefaultContextMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        let isFile = { if case .file = self.item.identity { return true }; return false }()

        // — 关闭 / 关闭多个标签页 >
        let closeItem = ClosureMenuItem(title: Localization.string(.fileClose, default: "关闭")) { [weak self] in self?.onClose() }
        menu.addItem(closeItem)
        menu.addItem(closeMultipleSubmenuItem())

        // — 固定
        let pinTitle = item.isPinned
            ? Localization.string(.windowUnpinTab, default: "取消固定标签页")
            : Localization.string(.windowPinTab, default: "固定标签页")
        menu.addItem(menuItem(pinTitle, action: .togglePin))

        menu.addItem(.separator())

        // — 保存 / 另存为
        let saveItem = menuItem(Localization.string(.fileSave, default: "保存"), action: .save)
        saveItem.isEnabled = item.isDirty || !isFile
        menu.addItem(saveItem)
        menu.addItem(menuItem(Localization.string(.fileSaveAs, default: "另存为..."), action: .saveAs))

        // — 打开至 > (only for file-backed docs)
        if isFile {
            menu.addItem(openInSubmenuItem())
        }

        // — 重命名 / 移至废纸篓 / 重新加载
        let renameItem = menuItem(Localization.string(.fileRename, default: "重命名..."), action: .rename)
        renameItem.isEnabled = isFile
        menu.addItem(renameItem)

        let trashItem = menuItem(Localization.string(.fileMoveToTrash, default: "移至废纸篓"), action: .moveToTrash)
        trashItem.isEnabled = isFile
        menu.addItem(trashItem)

        let reloadItem = menuItem(Localization.string(.fileReloadFromDisk, default: "重新加载"), action: .reload)
        reloadItem.isEnabled = isFile
        menu.addItem(reloadItem)

        // — 打印
        menu.addItem(menuItem(Localization.string(.filePrint, default: "打印..."), action: .print))

        menu.addItem(.separator())

        // — 只读
        menu.addItem(menuItem(Localization.string(.editReadOnlyMenu, default: "设置为只读（仅本程序中）"), action: .toggleReadOnly))

        menu.addItem(.separator())

        // — 复制到剪贴板 > / 移动文档 > / 设置标签颜色 >
        menu.addItem(copyToClipboardSubmenuItem())
        menu.addItem(moveDocumentSubmenuItem())
        menu.addItem(colorSubmenuItem())

        return menu
    }

    private func closeMultipleSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: Localization.string(.fileCloseOthers, default: "关闭多个标签页"), action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "")
        sub.addItem(menuItem(Localization.string(.fileCloseOthers, default: "关闭其他标签页"), action: .closeOthers))
        sub.addItem(menuItem(Localization.string(.fileCloseAllButPinned, default: "关闭除固定外所有标签页"), action: .closeAllButPinned))
        sub.addItem(menuItem(Localization.string(.fileCloseAllToLeft, default: "关闭左侧所有标签页"), action: .closeToLeft))
        sub.addItem(menuItem(Localization.string(.fileCloseAllToRight, default: "关闭右侧所有标签页"), action: .closeToRight))
        sub.addItem(menuItem(Localization.string(.fileCloseUnchanged, default: "关闭未修改标签页"), action: .closeUnchanged))
        parent.submenu = sub
        return parent
    }

    private func openInSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: Localization.string(.fileOpenContainingFolder, default: "打开至"), action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "")
        sub.addItem(menuItem(Localization.string(.fileOpenContainingFolder, default: "在 Finder 中显示"), action: .openContainingFolder))
        sub.addItem(menuItem(Localization.string(.fileOpenContainingFolderInTerminal, default: "在终端中打开"), action: .openContainingFolderInTerminal))
        sub.addItem(menuItem(Localization.string(.fileOpenContainingFolderAsWorkspace, default: "Open as Folder Workspace"), action: .openContainingFolder))
        parent.submenu = sub
        return parent
    }

    private func copyToClipboardSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: Localization.string(.editCopyCurrentFilename, default: "复制到剪贴板"), action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "")
        if case .file(let url) = item.identity {
            let filename = url.lastPathComponent
            sub.addItem(menuItem(String(format: Localization.string(.editCopyCurrentFilename, default: "复制文件名 \"%@\""), filename), action: .copyFilename))
        } else {
            sub.addItem(menuItem(Localization.string(.editCopyCurrentFilename, default: "复制文件名"), action: .copyFilename))
        }
        sub.addItem(menuItem(Localization.string(.editCopyCurrentFullPath, default: "复制完整路径"), action: .copyFullPath))
        sub.addItem(menuItem(Localization.string(.editCopyCurrentDirectoryPath, default: "复制目录路径"), action: .copyDirectoryPath))
        parent.submenu = sub
        return parent
    }

    private func moveDocumentSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: Localization.string(.windowMoveTabToStart, default: "移动文档"), action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "")
        sub.addItem(menuItem(Localization.string(.windowMoveTabToStart, default: "移到开头"), action: .moveToStart))
        sub.addItem(menuItem(Localization.string(.windowMoveTabToEnd, default: "移到末尾"), action: .moveToEnd))
        sub.addItem(menuItem(Localization.string(.windowMoveTabForward, default: "向前移动"), action: .moveForward))
        sub.addItem(menuItem(Localization.string(.windowMoveTabBackward, default: "向后移动"), action: .moveBackward))
        parent.submenu = sub
        return parent
    }

    private func menuItem(_ title: String, action: TabContextAction) -> NSMenuItem {
        ClosureMenuItem(title: title) { [weak self] in self?.onContextAction(action) }
    }

    private func colorSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: Localization.string(.windowTabColor, default: "Tab Color"), action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "")
        let colors: [(Localization.Key, String, Int?)] = [
            (.windowTabColorNone, "None", nil),
            (.windowTabColor1, "Yellow", 1),
            (.windowTabColor2, "Green", 2),
            (.windowTabColor3, "Blue", 3),
            (.windowTabColor4, "Red", 4),
            (.windowTabColor5, "Orange", 5),
            (.windowTabColor6, "Purple", 6),
        ]
        for (key, fallback, idx) in colors {
            let it = ClosureMenuItem(title: Localization.string(key, default: fallback)) { [weak self] in
                self?.onContextAction(.setColor(idx))
            }
            if item.tabColorIndex == idx { it.state = .on }
            sub.addItem(it)
        }
        parent.submenu = sub
        return parent
    }
}

// NSMenuItem with inline action closure
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    @objc private func invoke() { handler() }
}
