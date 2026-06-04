import AppKit
import NotepadMacCore
import Foundation

// MARK: - Tab bar container

enum TabContextAction {
    case closeOthers
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

    var onSelectTab: ((EditorTabIdentity) -> Void)?
    var onCloseTab: ((EditorTabIdentity) -> Void)?
    var onTabContextAction: ((EditorTabIdentity, TabContextAction) -> Void)?
    var onNewTab: (() -> Void)?
    /// Called when user drags a tab to a new position. Args: identity, target index.
    var onReorderTab: ((EditorTabIdentity, Int) -> Void)?

    private var state = EditorTabState()
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private var tabButtons: [EditorTabButton] = []
    private let newTabButton = NSButton()

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

        let newTabWidth: CGFloat = 28
        NSLayoutConstraint.activate([
            newTabButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            newTabButton.topAnchor.constraint(equalTo: topAnchor),
            newTabButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: newTabWidth),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @objc private func newTabButtonClicked(_ sender: Any?) {
        onNewTab?()
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
        guard let btn = draggedButton else { return }
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
        guard let btn = draggedButton else { super.mouseUp(with: event); return }
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

    // Pass an explicit maxWidth when calling from layout() so we don't re-read
    // scrollView.bounds.width (which may still be 0 during the layout pass).
    private func rebuildTabs(overrideMaxWidth: CGFloat? = nil) {
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        let tabMaxWidth: CGFloat
        if let override = overrideMaxWidth {
            tabMaxWidth = override
        } else {
            // Only truncate filenames that exceed half the visible bar width.
            let halfBarWidth = max(EditorTabButton.minWidth, scrollView.bounds.width / 2)
            tabMaxWidth = min(EditorTabButton.absoluteMaxWidth, halfBarWidth)
        }

        var x: CGFloat = 0
        for item in state.items {
            let isActive = item.identity == state.activeIdentity
            let btn = EditorTabButton(
                item: item,
                isActive: isActive,
                onSelect: { [weak self] in self?.onSelectTab?(item.identity) },
                onClose: { [weak self] in self?.onCloseTab?(item.identity) },
                onContextAction: { [weak self] action in self?.onTabContextAction?(item.identity, action) }
            )
            btn.dynamicMaxWidth = tabMaxWidth
            let w = btn.preferredWidth
            btn.frame = CGRect(x: x, y: 0, width: w, height: Self.barHeight)
            documentView.addSubview(btn)
            tabButtons.append(btn)
            x += w
        }

        let totalWidth = max(x, scrollView.bounds.width)
        documentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: Self.barHeight)
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
        // Use our own bounds minus the newTabButton so we don't depend on scrollView layout order.
        let availableWidth = max(0, bounds.width - 28)
        let newMax = min(EditorTabButton.absoluteMaxWidth,
                        max(EditorTabButton.minWidth, availableWidth / 2))
        if !tabButtons.isEmpty {
            // Recompute tab widths if bar was resized after initial rebuild (e.g. window resize).
            if tabButtons.first?.dynamicMaxWidth != newMax {
                rebuildTabs(overrideMaxWidth: newMax)
            }
            return
        }
        documentView.frame = CGRect(x: 0, y: 0, width: max(documentView.frame.width, bounds.width - 28), height: Self.barHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Bottom separator
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 0.5).fill()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.barHeight)
    }
}

// MARK: - Individual tab button

@MainActor
final class EditorTabButton: NSView {
    private static let hPad: CGFloat = 8
    private static let closeSize: CGFloat = 13
    private static let closeRightPad: CGFloat = 5
    static let minWidth: CGFloat = 60
    static let absoluteMaxWidth: CGFloat = 400
    // Set by the tab bar to half its visible width; tabs only truncate when the title exceeds that.
    var dynamicMaxWidth: CGFloat = 300

    let item: EditorTabItem
    private let isActive: Bool
    private let onSelect: () -> Void
    private let onClose: () -> Void
    private let onContextAction: (TabContextAction) -> Void

    private let titleLabel = NSTextField(labelWithString: "")
    private let closeBtn = NSButton()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    init(item: EditorTabItem, isActive: Bool, onSelect: @escaping () -> Void, onClose: @escaping () -> Void, onContextAction: @escaping (TabContextAction) -> Void) {
        self.item = item
        self.isActive = isActive
        self.onSelect = onSelect
        self.onClose = onClose
        self.onContextAction = onContextAction
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let prefix = item.isMonitoring ? "⟳ " : (item.isDirty ? "• " : "")
        let displayTitle = prefix + item.title
        titleLabel.stringValue = displayTitle
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = isActive ? .labelColor : .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

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
        closeBtn.isHidden = !isActive
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        addSubview(closeBtn)
    }

    var preferredWidth: CGFloat {
        let prefix = item.isMonitoring ? "⟳ " : (item.isDirty ? "• " : "")
        let text = prefix + item.title
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12)]
        let textW = (text as NSString).size(withAttributes: attrs).width
        // +6: extra margin so subpixel/Retina rendering doesn't clip CJK characters
        let raw = Self.hPad + textW + 6 + Self.closeSize + Self.closeRightPad
        return max(Self.minWidth, min(dynamicMaxWidth, ceil(raw)))
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let closeSz = Self.closeSize
        let closeX = bounds.maxX - closeSz - Self.closeRightPad
        let closeY = (h - closeSz) / 2
        closeBtn.frame = CGRect(x: closeX, y: closeY, width: closeSz, height: closeSz)

        let titleX = Self.hPad
        // When the close button is hidden (inactive tab), extend title to the right edge.
        let titleMaxX = closeBtn.isHidden ? bounds.maxX - Self.hPad : closeX - 4
        let titleH: CGFloat = 17
        let titleY = (h - titleH) / 2
        titleLabel.frame = CGRect(x: titleX, y: titleY, width: max(0, titleMaxX - titleX), height: titleH)
    }

    @objc private func closeTapped() {
        onClose()
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if !closeBtn.frame.insetBy(dx: -4, dy: -4).contains(loc) {
            onSelect()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        closeBtn.isHidden = false
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        closeBtn.isHidden = !isActive
        needsDisplay = true
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

    override func rightMouseDown(with event: NSEvent) {
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func buildContextMenu() -> NSMenu {
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
        sub.addItem(menuItem(Localization.string(.fileCloseAllToLeft, default: "关闭左侧所有标签页"), action: .closeToLeft))
        sub.addItem(menuItem(Localization.string(.fileCloseAllToRight, default: "关闭右侧所有标签页"), action: .closeToRight))
        parent.submenu = sub
        return parent
    }

    private func openInSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: Localization.string(.fileOpenContainingFolder, default: "打开至"), action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "")
        sub.addItem(menuItem(Localization.string(.fileOpenContainingFolder, default: "在 Finder 中显示"), action: .openContainingFolder))
        sub.addItem(menuItem(Localization.string(.fileOpenContainingFolderInTerminal, default: "在终端中打开"), action: .openContainingFolderInTerminal))
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
