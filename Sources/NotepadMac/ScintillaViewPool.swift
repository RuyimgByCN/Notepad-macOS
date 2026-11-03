import AppKit

@MainActor
final class ScintillaViewBackend {
    let view: NSView
    let bridge: ScintillaDynamicBridge

    init(view: NSView) {
        self.view = view
        self.bridge = ScintillaDynamicBridge(target: view)
        view.translatesAutoresizingMaskIntoConstraints = false
    }
}

/// Owns drawing views independently of documents. The scratch view never enters a window.
@MainActor
final class ScintillaViewPool {
    static var shared: ScintillaViewPool?
    private let makeView: () -> NSView
    private let scratch: ScintillaViewBackend
    private let retired = ScintillaViewBackend(view: NSView())
    private weak var scratchOwner: ScintillaEditorSurface?
    private var available: [ScintillaViewBackend] = []
    private struct WeakSurface { weak var value: ScintillaEditorSurface? }
    private var surfaces: [ObjectIdentifier: WeakSurface] = [:]

    init(makeView: @escaping () -> NSView) {
        self.makeView = makeView
        self.scratch = ScintillaViewBackend(view: makeView())
    }

    func createDocument() -> Int {
        Int(scratch.bridge.integerMessage(ScintillaMessage.createDocument, wParam: 0, lParam: 0) ?? 0)
    }

    func releaseDocument(_ pointer: Int) {
        scratch.bridge.setGeneralProperty(ScintillaMessage.releaseDocument, parameter: 0, value: pointer)
    }

    func backend(for surface: ScintillaEditorSurface) -> ScintillaViewBackend {
        // Late panel/timer callbacks must never attach a released document or
        // send commands to a drawing view that now belongs to another tab.
        guard !surface.didReleasePooledDocument else { return retired }
        surfaces[ObjectIdentifier(surface)] = WeakSurface(value: surface)
        if let live = surface.presentationBackend { return live }
        if scratchOwner !== surface {
            saveScratchOwner()
            scratchOwner = surface
            bind(surface, to: scratch)
        }
        return scratch
    }

    private func bind(_ surface: ScintillaEditorSurface, to backend: ScintillaViewBackend) {
        backend.bridge.onPropertySet = nil
        _ = backend.bridge.setDelegate(nil)
        backend.bridge.setGeneralProperty(ScintillaMessage.setDocPointer, parameter: 0, value: surface.pooledDocument)
        surface.restorePooledViewConfiguration()
        surface.parkedViewState.restore(using: backend.bridge)
        _ = backend.bridge.setDelegate(surface)
        backend.bridge.onPropertySet = { [weak surface] message, parameter, value in
            surface?.rememberIndicatorAppearance(message, parameter: parameter, value: value)
        }
    }

    private func saveScratchOwner() {
        guard let owner = scratchOwner else { return }
        owner.parkedViewState = ScintillaDocumentViewState(capturing: scratch.bridge)
        _ = scratch.bridge.setDelegate(nil)
        scratchOwner = nil
    }

    func present(_ surface: ScintillaEditorSurface) {
        guard !surface.didReleasePooledDocument, surface.presentationBackend == nil else { return }
        if scratchOwner === surface { saveScratchOwner() }
        let backend: ScintillaViewBackend
        if let reused = available.popLast() {
            backend = reused
        } else {
            backend = ScintillaViewBackend(view: makeView())
        }
        surface.presentationBackend = backend
        let container = surface.view
        container.addSubview(backend.view)
        NSLayoutConstraint.activate([
            backend.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backend.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backend.view.topAnchor.constraint(equalTo: container.topAnchor),
            backend.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        bind(surface, to: backend)
    }

    func park(_ surface: ScintillaEditorSurface) {
        guard let backend = surface.presentationBackend else { return }
        surface.parkedViewState = ScintillaDocumentViewState(capturing: backend.bridge)
        backend.bridge.setGeneralProperty(ScintillaMessage.autoCCancel, parameter: 0, value: 0)
        backend.bridge.setGeneralProperty(ScintillaMessage.callTipCancel, parameter: 0, value: 0)
        _ = backend.bridge.setDelegate(nil)
        backend.bridge.onPropertySet = nil
        backend.view.removeFromSuperview()
        backend.view.menu = nil
        backend.bridge.setGeneralProperty(ScintillaMessage.setDocPointer, parameter: 0, value: 0)
        surface.presentationBackend = nil
        available.append(backend)
    }

    func changeDocument(for surface: ScintillaEditorSurface, to pointer: Int) -> Bool {
        guard pointer != 0, !surface.didReleasePooledDocument else { return false }
        let backend = backend(for: surface)
        backend.bridge.setGeneralProperty(ScintillaMessage.addRefDocument, parameter: 0, value: pointer)
        let previous = surface.pooledDocument
        surface.pooledDocument = pointer
        surface.clearPooledDocumentCaches()
        surface.parkedViewState = ScintillaDocumentViewState()
        bind(surface, to: backend)
        releaseDocument(previous)
        return true
    }

    func release(_ surface: ScintillaEditorSurface) {
        guard !surface.didReleasePooledDocument else { return }
        park(surface)
        if scratchOwner === surface {
            _ = scratch.bridge.setDelegate(nil)
            scratch.bridge.setGeneralProperty(ScintillaMessage.setDocPointer, parameter: 0, value: 0)
            scratchOwner = nil
        }
        surface.didReleasePooledDocument = true
        releaseDocument(surface.pooledDocument)
        surfaces.removeValue(forKey: ObjectIdentifier(surface))
    }

    func invalidateDocumentCopies(of source: ScintillaEditorSurface, programmatic: Bool) {
        for entry in surfaces.values {
            guard let surface = entry.value, surface !== source,
                  surface.pooledDocument == source.pooledDocument else { continue }
            surface.invalidatePooledDocumentCopy(programmatic: programmatic)
        }
    }
}

/// Scintilla owns text and undo history in the document; these values belong to a view.
@MainActor
struct ScintillaDocumentViewState {
    struct Selection {
        var caret: Int = 0
        var anchor: Int = 0
        var caretVirtualSpace: Int = 0
        var anchorVirtualSpace: Int = 0
    }
    var selections = [Selection()]
    var mainSelection = 0
    var mode = 0
    var multipleSelection = 0
    var additionalSelectionTyping = 0
    var virtualSpaceOptions = 0
    var firstVisibleLine = 0
    var xOffset = 0
    var scrollWidth = 1
    var zoom = 0
    var overtype = 0
    var rectangular = Selection()
    var collapsed: [Int] = []
    var hidden: [ClosedRange<Int>] = []

    init() {}

    init(capturing bridge: ScintillaDynamicBridge) {
        func get(_ message: Int32, _ parameter: Int = 0) -> Int {
            Int(bridge.getGeneralProperty(message, parameter: parameter) ?? 0)
        }
        selections = (0..<max(1, get(ScintillaMessage.getSelections))).map { index in
            Selection(caret: get(ScintillaMessage.getSelectionNCaret, index), anchor: get(ScintillaMessage.getSelectionNAnchor, index),
                      caretVirtualSpace: get(ScintillaMessage.getSelectionNCaretVirtualSpace, index), anchorVirtualSpace: get(ScintillaMessage.getSelectionNAnchorVirtualSpace, index))
        }
        mainSelection = get(ScintillaMessage.getMainSelection)
        mode = get(ScintillaMessage.getSelectionMode)
        multipleSelection = get(ScintillaMessage.getMultipleSelection)
        additionalSelectionTyping = get(ScintillaMessage.getAdditionalSelectionTyping)
        virtualSpaceOptions = get(ScintillaMessage.getVirtualSpaceOptions)
        firstVisibleLine = get(ScintillaMessage.getFirstVisibleLine)
        xOffset = get(ScintillaMessage.getXOffset)
        scrollWidth = get(ScintillaMessage.getScrollWidth)
        zoom = get(ScintillaMessage.getZoom)
        overtype = get(ScintillaMessage.getOvertype)
        rectangular = Selection(caret: get(ScintillaMessage.getRectangularSelectionCaret), anchor: get(ScintillaMessage.getRectangularSelectionAnchor),
                                caretVirtualSpace: get(ScintillaMessage.getRectangularSelectionCaretVirtualSpace), anchorVirtualSpace: get(ScintillaMessage.getRectangularSelectionAnchorVirtualSpace))
        var line = get(ScintillaMessage.contractedFoldNext)
        while line >= 0 {
            collapsed.append(line)
            line = get(ScintillaMessage.contractedFoldNext, line + 1)
        }
        if get(ScintillaMessage.getAllLinesVisible) == 0 {
            var start: Int?
            let count = get(ScintillaMessage.getLineCount)
            for index in 0..<count {
                if get(ScintillaMessage.getLineVisible, index) == 0 {
                    if start == nil { start = index }
                } else if let first = start {
                    hidden.append(first...(index - 1))
                    start = nil
                }
            }
            if let start, start < count { hidden.append(start...(count - 1)) }
        }
    }

    func restore(using bridge: ScintillaDynamicBridge) {
        func set(_ message: Int32, _ parameter: Int = 0, _ value: Int = 0) {
            bridge.setGeneralProperty(message, parameter: parameter, value: value)
        }
        set(ScintillaMessage.setZoom, zoom)
        set(ScintillaMessage.setScrollWidth, scrollWidth)
        set(ScintillaMessage.setMultipleSelection, multipleSelection)
        set(ScintillaMessage.setAdditionalSelectionTyping, additionalSelectionTyping)
        set(ScintillaMessage.setVirtualSpaceOptions, virtualSpaceOptions)
        set(ScintillaMessage.setSelectionMode, mode)
        set(ScintillaMessage.clearSelections)
        for (index, selection) in selections.enumerated() {
            set(index == 0 ? ScintillaMessage.setSelection : ScintillaMessage.addSelection, selection.caret, selection.anchor)
            set(ScintillaMessage.setSelectionNCaretVirtualSpace, index, selection.caretVirtualSpace)
            set(ScintillaMessage.setSelectionNAnchorVirtualSpace, index, selection.anchorVirtualSpace)
        }
        set(ScintillaMessage.setMainSelection, mainSelection)
        if mode == 1 || mode == 3 {
            set(ScintillaMessage.setRectangularSelectionCaret, rectangular.caret)
            set(ScintillaMessage.setRectangularSelectionAnchor, rectangular.anchor)
            set(ScintillaMessage.setRectangularSelectionCaretVirtualSpace, rectangular.caretVirtualSpace)
            set(ScintillaMessage.setRectangularSelectionAnchorVirtualSpace, rectangular.anchorVirtualSpace)
        }
        for line in collapsed { set(ScintillaMessage.setFoldExpanded, line, 0) }
        for range in hidden { set(ScintillaMessage.hideLines, range.lowerBound, range.upperBound) }
        set(ScintillaMessage.setOvertype, overtype)
        set(ScintillaMessage.setFirstVisibleLine, firstVisibleLine)
        set(ScintillaMessage.setXOffset, xOffset)
    }
}
