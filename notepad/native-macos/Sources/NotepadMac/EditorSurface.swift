import AppKit
import CLexillaBridge
import Darwin
import NotepadMacCore

@MainActor
enum EditorMargin {
    case bookmark
    case fold
}

@MainActor
struct EditorMarginClick {
    let margin: EditorMargin
    let line: Int
}

@MainActor
protocol EditorSurface: AnyObject {
    var view: NSView { get }
    var notificationObject: AnyObject { get }
    var firstResponder: NSResponder { get }
    var text: String { get set }
    var selectedRange: NSRange { get }
    var liveRectangularSelection: RectangularSelectionLiveMetadata? { get }
    var displayName: String { get }
    var supportsFolding: Bool { get }
    var supportsAdvancedViewOptions: Bool { get }
    var foldState: FoldState { get }

    func setSelectedRange(_ range: NSRange)
    func applyDiscontiguousSelections(_ ranges: [NSRange], mainSelectionIndex: Int) -> Bool
    func applyRectangularSelection(_ selection: RectangularSelectionLiveMetadata) -> Bool
    func applyFont(size: CGFloat)
    func applyFont(name: String, size: CGFloat, bold: Bool)
    func applyLineWrapping(_ wraps: Bool, width: CGFloat)
    func applyWordWrapMode(_ mode: Int)  // 0=none, 1=word, 2=whitespace, 3=character
    func applyCaretWidth(_ width: Int)
    func applyCaretNoBlink(_ noBlink: Bool)
    func applyCaretPeriod(_ periodMs: Int)
    func applyAdditionalEdgeColumns(_ columns: [Int])
    func applyCurrentLineFrameWidth(_ width: Int)
    func applyLineWrapIndent(_ mode: Int)
    func applyFoldMarginStyle(_ style: Int)
    func applyCodeFolding(_ enabled: Bool)
    func applyVirtualSpace(_ enabled: Bool)
    func applyBackspaceUnindents(_ enabled: Bool)
    func applyAutoIndent(_ enabled: Bool)
    func applyAutoIndentMode(_ mode: Int) // 0=off, 1=basic, 2=advanced
    func applyScrollBeyondLastLine(_ enabled: Bool)
    func applySelectedTextDragDrop(_ enabled: Bool)
    func applyPasteConvertEndings(_ enabled: Bool)
    func applyCaretStickyMode(_ mode: Int)
    func applyLineNumberDynamicWidth(_ enabled: Bool)
    func applyBookmarkMarginVisible(_ visible: Bool)
    func applyColumnSelectionToMultiEditing(_ enabled: Bool)
    func showInlineAutoComplete(prefix: String, words: [String])
    func cancelInlineAutoComplete()
    func applyAutoCompleteChooseSingle(_ on: Bool)
    func applyAutoCompleteTABFillup(_ on: Bool)
    func applyAutoCompleteEnterCommit(_ on: Bool)
    func applyAutoCompleteBrief(_ on: Bool)
    func applyAutoCompleteIgnoreCase(_ ignore: Bool)
    func applyShowWhitespace(_ visible: Bool)
    func applyShowWhitespace(mode: Int)
    func applyShowEOL(_ visible: Bool)
    func applyIndentGuides(_ visible: Bool)
    func applyIndentGuides(mode: Int)  // 0=none, 1=real, 2=lookForward, 3=lookBoth
    func applyCurrentLineHighlight(_ visible: Bool)
    func applyWrapSymbol(_ visible: Bool)
    func applyChangeHistory(_ enabled: Bool)
    func applyTabSize(_ size: Int, insertSpaces: Bool)
    func applyLineNumberMargin(_ visible: Bool)
    func applyEdgeLine(_ visible: Bool, column: Int)
    func applyFoldCompact(_ compact: Bool)
    var isReadOnly: Bool { get set }
    func applyHighlight(
        language: LanguageDefinition,
        styleCatalog: StyleCatalog,
        stylePreferences: StylePreferences,
        highlighter: SyntaxHighlighter
    )
    func syncBookmarkMarkers(_ bookmarks: BookmarkSet)
    func setMarginClickHandler(_ handler: ((EditorMarginClick) -> Void)?)
    func toggleFoldAtCurrentLine()
    func toggleFold(atLine line: Int) -> Bool
    func foldAll()
    func unfoldAll()
    func applyFoldState(_ folds: FoldState)
    func foldAtLevel(_ level: Int)
    func unfoldAtLevel(_ level: Int)
    func foldLevelAtCaret() -> Int
    func braceMatchPosition(from utf16Location: Int) -> Int?
    func hideLines(_ lineRange: ClosedRange<Int>)
    func showAllHiddenLines()
    func isLineHidden(_ line: Int) -> Bool

    // MARK: - Search indicator operations
    func initSearchIndicators()
    func clearSearchIndicator(_ style: SearchMarkStyle)
    func clearAllSearchIndicators()
    func markAllWithIndicator(_ style: SearchMarkStyle, ranges: [NSRange])
    func indicatorRanges(_ style: SearchMarkStyle) -> [NSRange]
    func goToNextIndicator(_ style: SearchMarkStyle, fromPosition: Int) -> Int?
    func goToPreviousIndicator(_ style: SearchMarkStyle, fromPosition: Int) -> Int?
    func showIncrementalHighlight(range: NSRange)
    func hideIncrementalHighlight()

    // MARK: - Multi-select operations
    var selectionCount: Int { get }
    func expandWordSelection()
    func multiSelectAddEach(matchCase: Bool, wholeWord: Bool)
    func multiSelectAddNext(matchCase: Bool, wholeWord: Bool)
    func dropLastSelection()
    func multiSelectSkip()

    // MARK: - Change history navigation
    var lineCount: Int { get }
    var currentLineNumber: Int { get }
    func goToLine(_ line: Int)
    func nextChangedLine(from line: Int) -> Int?
    func previousChangedLine(from line: Int) -> Int?
    func clearChangeHistory()

    // MARK: - Smart highlighting
    var supportsSmartHighlight: Bool { get }
    func applySmartHighlight(_ word: String, matchCase: Bool, wholeWord: Bool)
    func clearSmartHighlight()

    // MARK: - Insert/Overtype mode
    var isOvertype: Bool { get }

    // MARK: - NPC (Non-Printing Characters) display
    var supportsNpcDisplay: Bool { get }
    func applyNpcDisplay(_ show: Bool)

    // MARK: - XML tag matching
    var supportsXmlTagMatch: Bool { get }
    func applyXmlTagHighlight(openRange: NSRange, closeRange: NSRange)
    func clearXmlTagHighlight()
    func applyXmlAttributeHighlight(range: NSRange)
    func clearXmlAttributeHighlight()

    // MARK: - Auto-pair insertion
    var supportsAutoPair: Bool { get }
    func setAutoPairHandler(_ handler: ((Character) -> Void)?)
    func setCharAddedHandler(_ handler: ((Character) -> Void)?)
    func insertAutoPairClose(_ close: Character)

    // MARK: - Clickable URL highlighting
    var supportsUrlHighlight: Bool { get }
    func applyUrlHighlights(ranges: [NSRange], style: Int)
    func clearUrlHighlights()
    func setUrlClickHandler(_ handler: ((NSRange) -> Void)?)
    func urlIndicatorRange(at utf16Location: Int) -> NSRange?

    // MARK: - Brace match highlight
    func applyBraceHighlight(sciPos1: Int, sciPos2: Int)
    func applyBraceBadLight(sciPos: Int)
    func clearBraceHighlight()
    func updateBraceHighlightAtUtf16Location(_ location: Int)

    // MARK: - Scroll
    func scrollToSelection()

    // MARK: - Line padding
    func applyLinePadding(_ pixels: Int)

    // MARK: - Text direction (bidirectional)
    func applyBidirectional(_ mode: Int)  // 0=disabled, 1=L2R, 2=R2L
    func applySmoothFont(_ on: Bool)
    func applyMultiEditEnabled(_ on: Bool)
    func applyMultiPasteMode(_ mode: Int) // 0=paste once, 1=paste into each selection
    func applyAdditionalSelAlpha(_ alpha: Int) // 0-255 alpha, 256=opaque
    func applyAdditionalCaretsBlink(_ on: Bool)
    func applyAdditionalCaretsVisible(_ on: Bool)
    func applyCaretLineVisibleAlways(_ on: Bool)
    func applyWhitespaceSize(_ size: Int)  // 1-5 px dot size
    func applySelectionAlpha(_ alpha: Int) // 0-256, 256=opaque
    func applyControlCharDisplay(_ mode: Int) // 0=glyph, 1-6=symbol
    func applyScintillaRenderingTechnology(_ tech: Int)
    func applyRightClickKeepSelection(_ keep: Bool)
    func applyDisableAdvancedScrolling(_ disabled: Bool)
    func applyEdgeMode(_ mode: Int)     // 0=none, 1=line, 2=background
    func applyFoldFlags(_ flags: Int)   // bitmask: 2=before_expanded, 4=before_contracted, 8=after_expanded, 16=after_contracted

    // MARK: - Copy/Cut behavior
    func applyCopyLineWithoutSelection(_ enabled: Bool)

    /// Returns styled segments of the selected text for rich copy (HTML/RTF).
    /// Falls back to a single plain segment when style info is unavailable.
    func styledSegments(ofSelection range: NSRange) -> [StyledSegment]

    // MARK: - Scintilla key remapping
    func applyScintillaKeyRemaps(_ remaps: [ScintillaKeyRemap])

    // MARK: - Context menu
    func setContextMenu(_ menu: NSMenu?)

    // MARK: - Lifecycle
    /// Called before the surface is released (e.g. window closing) to allow the
    /// implementation to sever any unretained back-references (e.g. Scintilla delegate).
    func teardown()
}

@MainActor
enum EditorSurfaceFactory {
    static func make() -> EditorSurface {
        return ScintillaEditorSurface.load() ?? TextViewEditorSurface()
    }
}

@MainActor
final class TextViewEditorSurface: EditorSurface {
    let scrollView = NSScrollView()
    let textView = NSTextView()

    var view: NSView { scrollView }
    var notificationObject: AnyObject { textView }
    var firstResponder: NSResponder { textView }
    var displayName: String { "NSTextView" }
    var supportsFolding: Bool { false }
    var supportsAdvancedViewOptions: Bool { false }
    var foldState: FoldState { FoldState() }

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    var selectedRange: NSRange {
        textView.selectedRange()
    }

    var liveRectangularSelection: RectangularSelectionLiveMetadata? {
        nil
    }

    func setSelectedRange(_ range: NSRange) {
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }

    func applyDiscontiguousSelections(_ ranges: [NSRange], mainSelectionIndex: Int) -> Bool {
        false
    }

    func applyRectangularSelection(_ selection: RectangularSelectionLiveMetadata) -> Bool {
        false
    }

    init() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        scrollView.documentView = textView
    }

    func applyFont(size: CGFloat) {
        textView.font = .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func applyFont(name: String, size: CGFloat, bold: Bool) {
        let fontName = name.trimmingCharacters(in: .whitespaces)
        let weight: NSFont.Weight = bold ? .bold : .regular
        if fontName.isEmpty {
            textView.font = .monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            textView.font = NSFont(name: fontName, size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    func applyCaretWidth(_ width: Int) {}
    func applyCaretNoBlink(_ noBlink: Bool) {}
    func applyCaretPeriod(_ periodMs: Int) {}
    func applyAdditionalEdgeColumns(_ columns: [Int]) {}
    func applyCurrentLineFrameWidth(_ width: Int) {}
    func applyLineWrapIndent(_ mode: Int) {}
    func applyFoldMarginStyle(_ style: Int) {}
    func applyCodeFolding(_ enabled: Bool) {}
    func applyVirtualSpace(_ enabled: Bool) {}
    func applyBackspaceUnindents(_ enabled: Bool) {}
    func applyAutoIndent(_ enabled: Bool) {}
    func applyAutoIndentMode(_ mode: Int) {}
    func applyScrollBeyondLastLine(_ enabled: Bool) {}
    func applySelectedTextDragDrop(_ enabled: Bool) {}
    func applyPasteConvertEndings(_ enabled: Bool) {}
    func applyCaretStickyMode(_ mode: Int) {}
    func applyLineNumberDynamicWidth(_ enabled: Bool) {}
    func applyBookmarkMarginVisible(_ visible: Bool) {}
    func applyColumnSelectionToMultiEditing(_ enabled: Bool) {}
    func showInlineAutoComplete(prefix: String, words: [String]) {}
    func cancelInlineAutoComplete() {}
    func applyAutoCompleteChooseSingle(_ on: Bool) {}
    func applyAutoCompleteTABFillup(_ on: Bool) {}
    func applyAutoCompleteEnterCommit(_ on: Bool) {}
    func applyAutoCompleteBrief(_ on: Bool) {}
    func applyAutoCompleteIgnoreCase(_ ignore: Bool) {}

    func applyLineWrapping(_ wraps: Bool, width: CGFloat) {
        guard let textContainer = textView.textContainer else { return }

        if wraps {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
        } else {
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
        }
    }

    func applyWordWrapMode(_ mode: Int) {}

    func applyShowWhitespace(_ visible: Bool) {}

    func applyShowWhitespace(mode: Int) {}

    func applyShowEOL(_ visible: Bool) {}

    func applyIndentGuides(_ visible: Bool) {}
    func applyIndentGuides(mode: Int) {}
    func applyCurrentLineHighlight(_ visible: Bool) {}
    func applyWrapSymbol(_ visible: Bool) {}

    func applyChangeHistory(_ enabled: Bool) {}

    func applyTabSize(_ size: Int, insertSpaces: Bool) {}

    func applyLineNumberMargin(_ visible: Bool) {}

    func applyEdgeLine(_ visible: Bool, column: Int) {}
    func applyFoldCompact(_ compact: Bool) {}

    var isReadOnly: Bool {
        get { textView.isEditable == false }
        set { textView.isEditable = !newValue }
    }

    func applyHighlight(
        language: LanguageDefinition,
        styleCatalog: StyleCatalog,
        stylePreferences: StylePreferences,
        highlighter: SyntaxHighlighter
    ) {
        highlighter.apply(language: language, to: textView)
    }

    func syncBookmarkMarkers(_ bookmarks: BookmarkSet) {}

    func setMarginClickHandler(_ handler: ((EditorMarginClick) -> Void)?) {}

    func toggleFoldAtCurrentLine() {}

    func toggleFold(atLine line: Int) -> Bool { false }

    func foldAll() {}

    func unfoldAll() {}

    func applyFoldState(_ folds: FoldState) {}

    func foldAtLevel(_ level: Int) {}

    func unfoldAtLevel(_ level: Int) {}

    func foldLevelAtCaret() -> Int { 0 }

    func braceMatchPosition(from utf16Location: Int) -> Int? { nil }

    func hideLines(_ lineRange: ClosedRange<Int>) {}

    func showAllHiddenLines() {}

    func isLineHidden(_ line: Int) -> Bool { false }

    func initSearchIndicators() {}
    func clearSearchIndicator(_ style: SearchMarkStyle) {}
    func clearAllSearchIndicators() {}
    func markAllWithIndicator(_ style: SearchMarkStyle, ranges: [NSRange]) {}
    func indicatorRanges(_ style: SearchMarkStyle) -> [NSRange] { [] }
    func goToNextIndicator(_ style: SearchMarkStyle, fromPosition: Int) -> Int? { nil }
    func goToPreviousIndicator(_ style: SearchMarkStyle, fromPosition: Int) -> Int? { nil }
    func showIncrementalHighlight(range: NSRange) {}
    func hideIncrementalHighlight() {}

    var selectionCount: Int { 1 }
    func expandWordSelection() {}
    func multiSelectAddEach(matchCase: Bool, wholeWord: Bool) {}
    func multiSelectAddNext(matchCase: Bool, wholeWord: Bool) {}
    func dropLastSelection() {}
    func multiSelectSkip() {}

    var lineCount: Int {
        let text = textView.string as NSString
        return max(1, text.components(separatedBy: .newlines).count)
    }
    var currentLineNumber: Int {
        let text = textView.string as NSString
        let location = min(textView.selectedRange.location, text.length)
        return text.substring(with: NSRange(location: 0, length: location)).components(separatedBy: .newlines).count
    }
    func goToLine(_ line: Int) {}
    func nextChangedLine(from line: Int) -> Int? { nil }
    func previousChangedLine(from line: Int) -> Int? { nil }
    func clearChangeHistory() {}

    var isOvertype: Bool { false }

    var supportsNpcDisplay: Bool { false }
    func applyNpcDisplay(_ show: Bool) {}

    var supportsSmartHighlight: Bool { false }
    func applySmartHighlight(_ word: String, matchCase: Bool, wholeWord: Bool) {}
    func clearSmartHighlight() {}

    var supportsXmlTagMatch: Bool { false }
    func applyXmlTagHighlight(openRange: NSRange, closeRange: NSRange) {}
    func clearXmlTagHighlight() {}
    func applyXmlAttributeHighlight(range: NSRange) {}
    func clearXmlAttributeHighlight() {}

    var supportsAutoPair: Bool { false }
    func setAutoPairHandler(_ handler: ((Character) -> Void)?) {}
    func setCharAddedHandler(_ handler: ((Character) -> Void)?) {}
    func insertAutoPairClose(_ close: Character) {}

    var supportsUrlHighlight: Bool { false }
    func applyUrlHighlights(ranges: [NSRange], style: Int) {}
    func clearUrlHighlights() {}
    func setUrlClickHandler(_ handler: ((NSRange) -> Void)?) {}
    func urlIndicatorRange(at utf16Location: Int) -> NSRange? { nil }

    func applyBraceHighlight(sciPos1: Int, sciPos2: Int) {}
    func applyBraceBadLight(sciPos: Int) {}
    func clearBraceHighlight() {}
    func updateBraceHighlightAtUtf16Location(_ location: Int) {}

    func applyLinePadding(_ pixels: Int) {}
    func applyBidirectional(_ mode: Int) {}
    func applySmoothFont(_ on: Bool) {}
    func applyMultiEditEnabled(_ on: Bool) {}
    func applyMultiPasteMode(_ mode: Int) {}
    func applyAdditionalSelAlpha(_ alpha: Int) {}
    func applyAdditionalCaretsBlink(_ on: Bool) {}
    func applyAdditionalCaretsVisible(_ on: Bool) {}
    func applyCaretLineVisibleAlways(_ on: Bool) {}
    func applyWhitespaceSize(_ size: Int) {}
    func applySelectionAlpha(_ alpha: Int) {}
    func applyControlCharDisplay(_ mode: Int) {}
    func applyScintillaRenderingTechnology(_ tech: Int) {}
    func applyRightClickKeepSelection(_ keep: Bool) {}
    func applyDisableAdvancedScrolling(_ disabled: Bool) {}
    func applyEdgeMode(_ mode: Int) {}
    func applyFoldFlags(_ flags: Int) {}
    func applyCopyLineWithoutSelection(_ enabled: Bool) {}
    func styledSegments(ofSelection range: NSRange) -> [StyledSegment] {
        let nsText = textView.string as NSString
        let text = (range.location + range.length <= nsText.length)
            ? nsText.substring(with: range) : ""
        return [StyledSegment(text: text, foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false)]
    }
    func applyScintillaKeyRemaps(_ remaps: [ScintillaKeyRemap]) {}
    func setContextMenu(_ menu: NSMenu?) { textView.menu = menu }
    func scrollToSelection() {
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    func teardown() {}
}

@MainActor
final class ScintillaEditorSurface: EditorSurface {
    private static let frameworkRelativePath = ".build/scintilla-derived/Build/Products/Release/Scintilla.framework"

    let scintillaView: NSView

    var view: NSView { scintillaView }
    var notificationObject: AnyObject { scintillaView }
    var firstResponder: NSResponder { scintillaView }
    var displayName: String { "Scintilla" }
    var supportsFolding: Bool { true }
    var supportsAdvancedViewOptions: Bool { true }
    var foldState: FoldState {
        guard let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0),
              lineCount > 0
        else {
            return FoldState()
        }

        let collapsedLines = (0..<Int(lineCount)).compactMap { zeroBasedLine -> Int? in
            let foldLevel = bridge.getGeneralProperty(
                ScintillaMessage.getFoldLevel,
                parameter: CLong(zeroBasedLine)
            ) ?? 0
            guard (foldLevel & ScintillaFoldLevel.headerFlag) != 0 else {
                return nil
            }
            let isExpanded = bridge.getGeneralProperty(
                ScintillaMessage.getFoldExpanded,
                parameter: CLong(zeroBasedLine)
            ) ?? 1
            return isExpanded == 0 ? zeroBasedLine + 1 : nil
        }
        return FoldState(collapsedLines: collapsedLines)
    }

    var text: String {
        get {
            let selector = NSSelectorFromString("string")
            guard scintillaView.responds(to: selector),
                  let imp = scintillaView.method(for: selector) else { return "" }
            typealias Fn = @convention(c) (AnyObject, Selector) -> Unmanaged<NSString>
            return unsafeBitCast(imp, to: Fn.self)(scintillaView, selector).takeUnretainedValue() as String
        }
        set {
            let selector = NSSelectorFromString("setString:")
            guard scintillaView.responds(to: selector),
                  let imp = scintillaView.method(for: selector) else { return }
            typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Void
            unsafeBitCast(imp, to: Fn.self)(scintillaView, selector, newValue as NSString)
        }
    }

    var selectedRange: NSRange {
        bridge.selectedRange()
    }

    var liveRectangularSelection: RectangularSelectionLiveMetadata? {
        guard bridge.getGeneralProperty(ScintillaMessage.selectionIsRectangle, parameter: 0) == 1,
              let anchorPosition = bridge.getGeneralProperty(
                ScintillaMessage.getRectangularSelectionAnchor,
                parameter: 0
              ),
              let caretPosition = bridge.getGeneralProperty(
                ScintillaMessage.getRectangularSelectionCaret,
                parameter: 0
              ),
              let anchorLocation = utf16Location(in: text, scintillaPosition: anchorPosition),
              let caretLocation = utf16Location(in: text, scintillaPosition: caretPosition)
        else {
            return nil
        }

        return RectangularSelectionLiveMetadata(
            anchorUTF16Location: anchorLocation,
            caretUTF16Location: caretLocation,
            anchorVirtualSpace: Int(max(
                0,
                bridge.getGeneralProperty(
                    ScintillaMessage.getRectangularSelectionAnchorVirtualSpace,
                    parameter: 0
                ) ?? 0
            )),
            caretVirtualSpace: Int(max(
                0,
                bridge.getGeneralProperty(
                    ScintillaMessage.getRectangularSelectionCaretVirtualSpace,
                    parameter: 0
                ) ?? 0
            ))
        )
    }

    func setSelectedRange(_ range: NSRange) {
        guard let scintillaRange = scintillaPositionRange(in: text, forUTF16Range: range) else {
            return
        }

        bridge.setGeneralProperty(
            ScintillaMessage.setSelection,
            parameter: scintillaRange.caret,
            value: scintillaRange.anchor
        )
        bridge.setGeneralProperty(ScintillaMessage.scrollCaret, parameter: 0, value: 0)
    }

    func applyDiscontiguousSelections(_ ranges: [NSRange], mainSelectionIndex: Int = 0) -> Bool {
        guard !ranges.isEmpty,
              let resolvedMainSelectionIndex = clampedSelectionIndex(mainSelectionIndex, selectionCount: ranges.count)
        else {
            return false
        }

        let currentText = text
        var scintillaRanges: [(anchor: CLong, caret: CLong)] = []
        scintillaRanges.reserveCapacity(ranges.count)
        for range in ranges {
            guard let scintillaRange = scintillaPositionRange(in: currentText, forUTF16Range: range) else {
                return false
            }
            scintillaRanges.append(scintillaRange)
        }

        enableScintillaMultiSelection()
        bridge.setGeneralProperty(ScintillaMessage.clearSelections, parameter: 0, value: 0)

        let firstRange = scintillaRanges[0]
        bridge.setGeneralProperty(
            ScintillaMessage.setSelection,
            parameter: firstRange.caret,
            value: firstRange.anchor
        )

        for range in scintillaRanges.dropFirst() {
            bridge.setGeneralProperty(
                ScintillaMessage.addSelection,
                parameter: range.caret,
                value: range.anchor
            )
        }

        bridge.setGeneralProperty(
            ScintillaMessage.setMainSelection,
            parameter: CLong(resolvedMainSelectionIndex),
            value: 0
        )
        bridge.setGeneralProperty(ScintillaMessage.scrollCaret, parameter: 0, value: 0)
        return true
    }

    func applyRectangularSelection(_ selection: RectangularSelectionLiveMetadata) -> Bool {
        let currentText = text
        guard let anchorPosition = scintillaPosition(
                in: currentText,
                utf16Location: selection.anchorUTF16Location
              ),
              let caretPosition = scintillaPosition(
                in: currentText,
                utf16Location: selection.caretUTF16Location
              ),
              let anchorVirtualSpace = nonNegativeScintillaPosition(selection.anchorVirtualSpace),
              let caretVirtualSpace = nonNegativeScintillaPosition(selection.caretVirtualSpace)
        else {
            return false
        }

        enableScintillaMultiSelection()
        enableScintillaRectangularVirtualSpace()
        bridge.setGeneralProperty(
            ScintillaMessage.setRectangularSelectionAnchor,
            parameter: anchorPosition,
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setRectangularSelectionAnchorVirtualSpace,
            parameter: anchorVirtualSpace,
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setRectangularSelectionCaret,
            parameter: caretPosition,
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setRectangularSelectionCaretVirtualSpace,
            parameter: caretVirtualSpace,
            value: 0
        )
        bridge.setGeneralProperty(ScintillaMessage.scrollCaret, parameter: 0, value: 0)
        return true
    }

    private let bridge: ScintillaDynamicBridge
    private var marginClickHandler: ((EditorMarginClick) -> Void)?
    private var didConfigureNotificationDelegate = false

    private init(scintillaView: NSView) {
        self.scintillaView = scintillaView
        self.bridge = ScintillaDynamicBridge(target: scintillaView)
        self.scintillaView.translatesAutoresizingMaskIntoConstraints = false
        self.scintillaView.autoresizingMask = [.width, .height]
        configureMargins()
        configureNotificationDelegateIfAvailable()
    }

    func teardown() {
        _ = bridge.setDelegate(nil)
    }

    static func load() -> ScintillaEditorSurface? {
        for frameworkURL in frameworkCandidates() {
            guard FileManager.default.fileExists(atPath: frameworkURL.path),
                  let bundle = Bundle(url: frameworkURL),
                  bundle.load()
            else {
                continue
            }

            for className in ["ScintillaView", "Scintilla.ScintillaView"] {
                guard let viewClass = NSClassFromString(className) as? NSView.Type else { continue }
                return ScintillaEditorSurface(scintillaView: viewClass.init(frame: .zero))
            }
        }

        return nil
    }

    func applyFont(size: CGFloat) {
        bridge.setFont(name: "Menlo", size: Int32(size.rounded()), bold: false, italic: false)
    }

    func applyFont(name: String, size: CGFloat, bold: Bool) {
        let fontName = name.trimmingCharacters(in: .whitespaces)
        let resolvedName = fontName.isEmpty ? "Menlo" : fontName
        bridge.setFont(name: resolvedName as NSString, size: Int32(size.rounded()), bold: bold, italic: false)
    }

    func applyLineWrapping(_ wraps: Bool, width: CGFloat) {
        bridge.setGeneralProperty(
            ScintillaMessage.setWrapMode,
            parameter: wraps ? ScintillaWrapMode.word : ScintillaWrapMode.none,
            value: 0
        )
    }

    func applyWordWrapMode(_ mode: Int) {
        let clamped = CLong(max(0, min(3, mode)))
        bridge.setGeneralProperty(ScintillaMessage.setWrapMode, parameter: clamped, value: 0)
    }

    func applyCaretWidth(_ width: Int) {
        bridge.setGeneralProperty(ScintillaMessage.setCaretWidth, parameter: CLong(max(1, min(3, width))), value: 0)
    }

    func applyVirtualSpace(_ enabled: Bool) {
        // SCVS_NONE=0, SCVS_RECTANGULARSELECTION=1, SCVS_USERACCESSIBLE=2, SCVS_NOWRAPLINESTART=4
        bridge.setGeneralProperty(ScintillaMessage.setVirtualSpaceOptions, parameter: enabled ? 3 : 0, value: 0)
    }

    func applyBackspaceUnindents(_ enabled: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setBackSpaceUnIndents, parameter: enabled ? 1 : 0, value: 0)
    }

    func applyScrollBeyondLastLine(_ enabled: Bool) {
        // SCI_SETENDATLASTLINE: 1 = end at last line (default), 0 = can scroll past
        bridge.setGeneralProperty(ScintillaMessage.setEndAtLastLine, parameter: enabled ? 0 : 1, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setScrollWidthTracking, parameter: 1, value: 0)
    }

    func applySelectedTextDragDrop(_ enabled: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setDragDropEnabled, parameter: enabled ? 1 : 0, value: 0)
    }

    func applyPasteConvertEndings(_ enabled: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setPasteConvertEndings, parameter: enabled ? 1 : 0, value: 0)
    }

    func applyCaretStickyMode(_ mode: Int) {
        bridge.setGeneralProperty(ScintillaMessage.setCaretStickyMode, parameter: CLong(max(0, min(2, mode))), value: 0)
    }

    func applyLineNumberDynamicWidth(_ enabled: Bool) {
        // When dynamic width is off, restore a fixed 40px line number margin width.
        // When enabled, set to 0 so the existing applyEditorSurface logic sizes it.
        let marginWidth = enabled ? 0 : 40
        bridge.setGeneralProperty(ScintillaMessage.setMarginWidth, parameter: 0, value: CLong(marginWidth))
    }

    func applyBookmarkMarginVisible(_ visible: Bool) {
        let width: CLong = visible ? 16 : 0
        bridge.setGeneralProperty(ScintillaMessage.setMarginWidth, parameter: ScintillaMargin.bookmark, value: width)
    }

    func applyColumnSelectionToMultiEditing(_ enabled: Bool) {
        // SCVS_RECTANGULARSELECTION (bit 0) enables rectangular/column selection
        let current = bridge.getGeneralProperty(ScintillaMessage.getVirtualSpaceOptions, parameter: 0) ?? 0
        let newValue: CLong = enabled ? (current | 1) : (current & ~1)
        bridge.setGeneralProperty(ScintillaMessage.setVirtualSpaceOptions, parameter: newValue, value: 0)
    }

    func applyCaretNoBlink(_ noBlink: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setCaretPeriod, parameter: noBlink ? 0 : 500, value: 0)
    }

    func applyCaretPeriod(_ periodMs: Int) {
        bridge.setGeneralProperty(ScintillaMessage.setCaretPeriod, parameter: CLong(periodMs), value: 0)
    }

    func applyAdditionalEdgeColumns(_ columns: [Int]) {
        bridge.setGeneralProperty(ScintillaMessage.multiEdgeClearAll, parameter: 0, value: 0)
        for col in columns where col > 0 {
            bridge.setGeneralProperty(ScintillaMessage.multiEdgeAddLine, parameter: CLong(col), value: 0)
        }
    }

    func applyCurrentLineFrameWidth(_ width: Int) {
        bridge.setGeneralProperty(ScintillaMessage.setCaretLineFrame, parameter: CLong(max(0, min(4, width))), value: 0)
    }

    func applyLineWrapIndent(_ mode: Int) {
        bridge.setGeneralProperty(ScintillaMessage.setWrapIndentMode, parameter: CLong(max(0, min(3, mode))), value: 0)
    }

    func applyCodeFolding(_ enabled: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setMarginWidth, parameter: ScintillaMargin.fold, value: enabled ? 16 : 0)
    }

    func applyFoldMarginStyle(_ style: Int) {
        // Marker numbers (SC_MARKNUM_*)
        let folderEnd: CLong = 25, folderOpenMid: CLong = 26, folderMidTail: CLong = 27
        let folderTail: CLong = 28, folderSub: CLong = 29, folder: CLong = 30, folderOpen: CLong = 31
        // Marker symbols
        let arrow: CLong = 2, arrowDown: CLong = 6, vline: CLong = 9
        let lCorner: CLong = 10, tCorner: CLong = 11, empty: CLong = 22
        let boxPlus: CLong = 12, boxPlusConn: CLong = 13, boxMinus: CLong = 14, boxMinusConn: CLong = 15
        let circPlus: CLong = 18, circPlusConn: CLong = 19, circMinus: CLong = 20, circMinusConn: CLong = 21
        let define = ScintillaMessage.markerDefine

        switch style {
        case 1: // box tree
            bridge.setGeneralProperty(define, parameter: folder, value: boxPlus)
            bridge.setGeneralProperty(define, parameter: folderOpen, value: boxMinus)
            bridge.setGeneralProperty(define, parameter: folderSub, value: vline)
            bridge.setGeneralProperty(define, parameter: folderTail, value: lCorner)
            bridge.setGeneralProperty(define, parameter: folderMidTail, value: tCorner)
            bridge.setGeneralProperty(define, parameter: folderEnd, value: boxPlusConn)
            bridge.setGeneralProperty(define, parameter: folderOpenMid, value: boxMinusConn)
        case 2: // circle tree
            bridge.setGeneralProperty(define, parameter: folder, value: circPlus)
            bridge.setGeneralProperty(define, parameter: folderOpen, value: circMinus)
            bridge.setGeneralProperty(define, parameter: folderSub, value: vline)
            bridge.setGeneralProperty(define, parameter: folderTail, value: lCorner)
            bridge.setGeneralProperty(define, parameter: folderMidTail, value: tCorner)
            bridge.setGeneralProperty(define, parameter: folderEnd, value: circPlusConn)
            bridge.setGeneralProperty(define, parameter: folderOpenMid, value: circMinusConn)
        default: // 0 = simple arrows
            bridge.setGeneralProperty(define, parameter: folder, value: arrow)
            bridge.setGeneralProperty(define, parameter: folderOpen, value: arrowDown)
            bridge.setGeneralProperty(define, parameter: folderSub, value: empty)
            bridge.setGeneralProperty(define, parameter: folderTail, value: empty)
            bridge.setGeneralProperty(define, parameter: folderMidTail, value: empty)
            bridge.setGeneralProperty(define, parameter: folderEnd, value: empty)
            bridge.setGeneralProperty(define, parameter: folderOpenMid, value: empty)
        }
    }

    func showInlineAutoComplete(prefix: String, words: [String]) {
        guard !words.isEmpty else { return }
        let filtered = words.filter { $0.lowercased().hasPrefix(prefix.lowercased()) && $0 != prefix }
        guard !filtered.isEmpty else { return }
        let list = filtered.sorted().joined(separator: " ")
        bridge.setGeneralProperty(ScintillaMessage.autoCSeparator, parameter: CLong(UInt8(ascii: " ")), value: 0)
        list.withCString { ptr in
            bridge.setReferenceProperty(ScintillaMessage.autoCShow, parameter: CLong(prefix.utf8.count), value: UnsafeRawPointer(ptr))
        }
    }

    func cancelInlineAutoComplete() {
        bridge.setGeneralProperty(ScintillaMessage.autoCCancel, parameter: 0, value: 0)
    }

    func applyAutoCompleteChooseSingle(_ on: Bool) {
        // SCI_AUTOCSETCHOOSESINGLE = 2113: auto-accept if only one item in list
        bridge.setGeneralProperty(2113, parameter: on ? 1 : 0, value: 0)
    }

    func applyAutoCompleteTABFillup(_ on: Bool) {
        // SCI_AUTOCSETFILLUPS = 2112: characters that immediately commit the selection
        let fillups = on ? "\t" : ""
        fillups.withCString { ptr in
            bridge.setReferenceProperty(2112, parameter: 0, value: UnsafeRawPointer(ptr))
        }
    }

    func applyAutoCompleteEnterCommit(_ on: Bool) {
        // Enter-commit is handled at key-intercept layer; stored in EditorWindowController
    }

    func applyAutoCompleteBrief(_ on: Bool) {
        // Brief mode (hide function prototypes) is filtered at list-generation time
    }

    func applyAutoCompleteIgnoreCase(_ ignore: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setAutoCIgnoreCase, parameter: ignore ? 1 : 0, value: 0)
    }

    func applyShowWhitespace(_ visible: Bool) {
        bridge.setGeneralProperty(
            ScintillaMessage.setViewWhitespace,
            parameter: visible ? ScintillaWhitespaceMode.visibleAlways : ScintillaWhitespaceMode.invisible,
            value: 0
        )
    }

    func applyShowWhitespace(mode: Int) {
        // SCWS_INVISIBLE=0, SCWS_VISIBLEALWAYS=1, SCWS_VISIBLEAFTERINDENT=2, SCWS_VISIBLEONLYININDENT=3
        bridge.setGeneralProperty(
            ScintillaMessage.setViewWhitespace,
            parameter: CLong(clampedWhitespaceMode(mode)),
            value: 0
        )
    }

    private func clampedWhitespaceMode(_ raw: Int) -> Int {
        max(0, min(3, raw))
    }

    func applyShowEOL(_ visible: Bool) {
        bridge.setGeneralProperty(
            ScintillaMessage.setViewEOL,
            parameter: visible ? 1 : 0,
            value: 0
        )
    }

    func applyIndentGuides(_ visible: Bool) {
        bridge.setGeneralProperty(
            ScintillaMessage.setIndentationGuides,
            parameter: visible ? ScintillaIndentGuideMode.lookForward : ScintillaIndentGuideMode.none,
            value: 0
        )
    }

    func applyIndentGuides(mode: Int) {
        let clamped = CLong(max(0, min(3, mode)))
        bridge.setGeneralProperty(
            ScintillaMessage.setIndentationGuides,
            parameter: clamped,
            value: 0
        )
    }

    func applyCurrentLineHighlight(_ visible: Bool) {
        bridge.setGeneralProperty(
            ScintillaMessage.setCaretLineVisible,
            parameter: visible ? 1 : 0,
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setCaretLineVisibleAlways,
            parameter: visible ? 1 : 0,
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setCaretLineBack,
            parameter: CLong(StyleColor(red: 236, green: 240, blue: 241).scintillaColor),
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setCaretLineBackAlpha,
            parameter: 96,
            value: 0
        )
    }

    func applyWrapSymbol(_ visible: Bool) {
        bridge.setGeneralProperty(
            ScintillaMessage.setWrapVisualFlags,
            parameter: visible ? ScintillaWrapVisualFlag.end : ScintillaWrapVisualFlag.none,
            value: 0
        )
    }

    func applyChangeHistory(_ enabled: Bool) {
        // SC_CHANGE_HISTORY_DISABLED = 0, SC_CHANGE_HISTORY_ENABLED = 1,
        // SC_CHANGE_HISTORY_MARKERS = 2, SC_CHANGE_HISTORY_INDICATORS = 4
        let flags: CLong
        if enabled {
            flags = 1 | 2  // enabled + markers
        } else {
            flags = 0
        }
        bridge.setGeneralProperty(
            ScintillaMessage.setChangeHistory,
            parameter: flags,
            value: 0
        )
    }

    func applyTabSize(_ size: Int, insertSpaces: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setTabWidth, parameter: CLong(size), value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setUseTabs, parameter: insertSpaces ? 0 : 1, value: 0)
    }

    func applyLineNumberMargin(_ visible: Bool) {
        let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0) ?? 1
        let digits = max(3, String(lineCount).count)
        let width = digits * 8 + 8   // ~8px per digit + padding
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginWidth,
            parameter: ScintillaMargin.lineNumber,
            value: visible ? CLong(width) : 0
        )
    }

    func applyFoldCompact(_ compact: Bool) {
        foldCompactMode = compact
    }

    func applyEdgeLine(_ visible: Bool, column: Int) {
        bridge.setGeneralProperty(
            ScintillaMessage.setEdgeMode,
            parameter: visible ? ScintillaEdgeMode.line : ScintillaEdgeMode.none,
            value: 0
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setEdgeColumn,
            parameter: CLong(max(1, column)),
            value: 0
        )
    }

    var isReadOnly: Bool {
        get {
            bridge.getGeneralProperty(ScintillaMessage.getReadOnly, parameter: 0) == 1
        }
        set {
            bridge.setGeneralProperty(ScintillaMessage.setReadOnly, parameter: newValue ? 1 : 0, value: 0)
        }
    }

    func applyHighlight(
        language: LanguageDefinition,
        styleCatalog: StyleCatalog,
        stylePreferences: StylePreferences,
        highlighter: SyntaxHighlighter
    ) {
        bridge.setFont(name: "Menlo", size: 13, bold: false, italic: false)

        let lexerName = language.lexillaLexerName
        if let name = lexerName,
           let lexer = LexillaDynamicLibrary.shared.createLexer(named: name) {
            bridge.setReferenceProperty(
                ScintillaMessage.setILexer,
                parameter: 0,
                value: UnsafeRawPointer(lexer)
            )
            bridge.setGeneralProperty(ScintillaMessage.clearDocumentStyle, parameter: 0, value: 0)
            configureFoldingProperties()
        } else {
            bridge.setReferenceProperty(ScintillaMessage.setILexer, parameter: 0, value: nil)
        }

        for (scintillaIndex, keywords) in language.scintillaKeywordSets where scintillaIndex < ScintillaKeyword.maximumSets {
            let keywordText = keywords.joined(separator: " ")
            keywordText.withCString { pointer in
                bridge.setReferenceProperty(
                    ScintillaMessage.setKeywords,
                    parameter: CLong(scintillaIndex),
                    value: UnsafeRawPointer(pointer)
                )
            }
        }

        for (styleID, nesting) in language.nestingProperties {
            bridge.setLexerProperty(
                name: String(format: "userDefine.nesting.%02d", styleID),
                value: String(nesting)
            )
        }

        applyStyles(language: language, styleCatalog: styleCatalog, stylePreferences: stylePreferences)
        applyGlobalStyles(styleCatalog: styleCatalog, stylePreferences: stylePreferences)
        bridge.setGeneralProperty(ScintillaMessage.colourise, parameter: 0, value: -1)
    }

    func syncBookmarkMarkers(_ bookmarks: BookmarkSet) {
        bridge.setGeneralProperty(
            ScintillaMessage.markerDeleteAll,
            parameter: ScintillaMarker.bookmark,
            value: 0
        )
        for line in bookmarks.zeroBasedLines {
            bridge.setGeneralProperty(
                ScintillaMessage.markerAdd,
                parameter: CLong(line),
                value: ScintillaMarker.bookmark
            )
        }
    }

    func setMarginClickHandler(_ handler: ((EditorMarginClick) -> Void)?) {
        marginClickHandler = handler
        configureNotificationDelegateIfAvailable()
    }

    @objc private func notification(_ rawNotification: UnsafeMutableRawPointer?) {
        guard let rawNotification else { return }

        let code = rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.codeOffset,
            as: UInt32.self
        )
        switch code {
        case ScintillaNotificationCode.modified:
            postTextDidChangeIfNeeded(from: rawNotification)
        case ScintillaNotificationCode.charAdded:
            handleCharAdded(from: rawNotification)
        case ScintillaNotificationCode.marginClick:
            handleMarginClick(from: rawNotification)
        case ScintillaNotificationCode.indicatorClick:
            handleIndicatorClick(from: rawNotification)
        default:
            break
        }
    }

    func toggleFoldAtCurrentLine() {
        let caretPosition = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0)
            ?? CLong(selectedRange.location)
        guard let currentLine = bridge.getGeneralProperty(
            ScintillaMessage.lineFromPosition,
            parameter: caretPosition
        ) else {
            return
        }

        _ = toggleFold(zeroBasedLine: Int(currentLine))
    }

    func toggleFold(atLine line: Int) -> Bool {
        guard line > 0 else { return false }
        return toggleFold(zeroBasedLine: line - 1)
    }

    func foldAll() {
        bridge.setGeneralProperty(
            ScintillaMessage.foldAll,
            parameter: ScintillaFoldAction.contractAllLevels,
            value: 0
        )
    }

    func unfoldAll() {
        bridge.setGeneralProperty(
            ScintillaMessage.foldAll,
            parameter: ScintillaFoldAction.expand,
            value: 0
        )
    }

    func applyFoldState(_ folds: FoldState) {
        guard let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0),
              lineCount > 0
        else {
            return
        }

        unfoldAll()
        for oneBasedLine in folds.clamped(toLineCount: Int(lineCount)).collapsedLines {
            let zeroBasedLine = CLong(oneBasedLine - 1)
            let foldLevel = bridge.getGeneralProperty(
                ScintillaMessage.getFoldLevel,
                parameter: zeroBasedLine
            ) ?? 0
            guard (foldLevel & ScintillaFoldLevel.headerFlag) != 0 else { continue }
            let isExpanded = bridge.getGeneralProperty(
                ScintillaMessage.getFoldExpanded,
                parameter: zeroBasedLine
            ) ?? 1
            guard isExpanded != 0 else { continue }
            bridge.setGeneralProperty(ScintillaMessage.toggleFold, parameter: zeroBasedLine, value: 0)
        }
    }

    func foldAtLevel(_ level: Int) {
        guard level >= 1, level <= 8,
              let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0),
              lineCount > 0
        else { return }

        // SC_FOLDLEVELBASE = 0x400; level 1 = 0x401, level 2 = 0x402, etc.
        let targetFoldLevel = CLong(0x400 + level)
        let numberMask: CLong = 0x0FFF
        for zeroBasedLine in 0..<Int(lineCount) {
            let line = CLong(zeroBasedLine)
            let foldLevel = bridge.getGeneralProperty(ScintillaMessage.getFoldLevel, parameter: line) ?? 0
            guard (foldLevel & ScintillaFoldLevel.headerFlag) != 0,
                  (foldLevel & numberMask) == targetFoldLevel
            else { continue }
            let isExpanded = bridge.getGeneralProperty(
                ScintillaMessage.getFoldExpanded,
                parameter: line
            ) ?? 1
            guard isExpanded != 0 else { continue }
            bridge.setGeneralProperty(ScintillaMessage.toggleFold, parameter: line, value: 0)
        }
    }

    func unfoldAtLevel(_ level: Int) {
        guard level >= 1, level <= 8,
              let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0),
              lineCount > 0
        else { return }

        let targetFoldLevel = CLong(0x400 + level)
        let numberMask: CLong = 0x0FFF
        var line: CLong = 0
        while line < lineCount {
            let foldLevel = bridge.getGeneralProperty(ScintillaMessage.getFoldLevel, parameter: line) ?? 0
            if (foldLevel & ScintillaFoldLevel.headerFlag) != 0,
               (foldLevel & numberMask) == targetFoldLevel {
                let isExpanded = bridge.getGeneralProperty(
                    ScintillaMessage.getFoldExpanded,
                    parameter: line
                ) ?? 1
                if isExpanded == 0 {
                    bridge.setGeneralProperty(ScintillaMessage.toggleFold, parameter: line, value: 0)
                }
            }
            line += 1
        }
    }

    func foldLevelAtCaret() -> Int {
        let caretPos = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0) ?? 0
        guard let zeroBasedLine = bridge.getGeneralProperty(
            ScintillaMessage.lineFromPosition,
            parameter: caretPos
        ), zeroBasedLine >= 0 else { return 0 }

        let foldLevel = bridge.getGeneralProperty(
            ScintillaMessage.getFoldLevel,
            parameter: zeroBasedLine
        ) ?? 0
        // SC_FOLDLEVELNUMBERMASK = 0x0FFF, SC_FOLDLEVELBASE = 0x400
        let level = foldLevel & 0x0FFF
        let result = level - 0x400
        return max(0, result)
    }

    func braceMatchPosition(from location: Int) -> Int? {
        let currentText = text
        guard let scintillaPos = scintillaPosition(in: currentText, utf16Location: location) else {
            return nil
        }

        // Try matching at the given position first, then one before
        for offset in [0, -1] {
            let tryPos = scintillaPos + CLong(offset)
            guard tryPos >= 0 else { continue }
            let matchPos = bridge.getGeneralProperty(
                ScintillaMessage.braceMatch,
                parameter: tryPos
            )
            if let matchPos, matchPos >= 0 {
                return self.utf16Location(in: currentText, scintillaPosition: matchPos)
            }
        }
        return nil
    }

    func hideLines(_ lineRange: ClosedRange<Int>) {
        guard lineRange.lowerBound >= 1 else { return }
        let zeroBasedStart = CLong(lineRange.lowerBound - 1)
        let zeroBasedEnd = CLong(lineRange.upperBound - 1)
        bridge.setGeneralProperty(ScintillaMessage.hideLines, parameter: zeroBasedStart, value: zeroBasedEnd)
    }

    func showAllHiddenLines() {
        guard let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0),
              lineCount > 0
        else { return }

        bridge.setGeneralProperty(
            ScintillaMessage.showLines,
            parameter: 0,
            value: lineCount - 1
        )
    }

    func isLineHidden(_ line: Int) -> Bool {
        guard line >= 1 else { return false }
        let zeroBasedLine = CLong(line - 1)
        let visible = bridge.getGeneralProperty(
            ScintillaMessage.getLineVisible,
            parameter: zeroBasedLine
        )
        return visible == 0
    }

    // MARK: - Search indicator operations

    func initSearchIndicators() {
        for style in SearchMarkStyle.allCases {
            let indicator = CLong(style.rawValue)
            bridge.setGeneralProperty(ScintillaMessage.indicSetStyle, parameter: indicator, value: ScintillaIndicatorStyle.roundBox)
            let color = style.defaultColor
            let rgb = CLong(color.blue) | (CLong(color.green) << 8) | (CLong(color.red) << 16)
            bridge.setGeneralProperty(ScintillaMessage.indicSetFore, parameter: indicator, value: rgb)
            bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha, parameter: indicator, value: 100)
            bridge.setGeneralProperty(ScintillaMessage.indicSetUnder, parameter: indicator, value: 1)
        }
    }

    func clearSearchIndicator(_ style: SearchMarkStyle) {
        let indicator = CLong(style.rawValue)
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(text.utf16.count))
    }

    func clearAllSearchIndicators() {
        for style in SearchMarkStyle.allCases {
            clearSearchIndicator(style)
        }
    }

    func markAllWithIndicator(_ style: SearchMarkStyle, ranges: [NSRange]) {
        let indicator = CLong(style.rawValue)
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        let currentText = text
        for range in ranges {
            guard let sciStart = scintillaPosition(in: currentText, utf16Location: range.location),
                  let sciEnd = scintillaPosition(in: currentText, utf16Location: NSMaxRange(range))
            else { continue }
            bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange, parameter: sciStart, value: sciEnd - sciStart)
        }
    }

    func indicatorRanges(_ style: SearchMarkStyle) -> [NSRange] {
        let indicator = CLong(style.rawValue)
        let currentText = text
        let textLength = CLong(currentText.utf16.count)
        var ranges: [NSRange] = []
        var pos: CLong = 0
        while pos < textLength {
            let start = bridge.getGeneralProperty(ScintillaMessage.indicatorStart, parameter: pos) ?? pos
            guard let end = bridge.getGeneralProperty(ScintillaMessage.indicatorEnd, parameter: pos), end > start else {
                pos = start + 1
                continue
            }
            if let utfStart = utf16Location(in: currentText, scintillaPosition: start),
               let utfEnd = utf16Location(in: currentText, scintillaPosition: end)
            {
                let indicatorValue = bridge.getGeneralProperty(ScintillaMessage.indicatorValueAt, parameter: indicator)
                if indicatorValue != 0 {
                    ranges.append(NSRange(location: utfStart, length: utfEnd - utfStart))
                }
            }
            pos = end + 1
        }
        return ranges
    }

    func goToNextIndicator(_ style: SearchMarkStyle, fromPosition: Int) -> Int? {
        let indicator = CLong(style.rawValue)
        let currentText = text
        guard let sciPos = scintillaPosition(in: currentText, utf16Location: fromPosition) else { return nil }
        let textLength = CLong(currentText.utf16.count)
        // Search from the position after the current one
        var searchPos = sciPos + 1
        while searchPos < textLength {
            let start = bridge.getGeneralProperty(ScintillaMessage.indicatorStart, parameter: searchPos) ?? searchPos
            guard let end = bridge.getGeneralProperty(ScintillaMessage.indicatorEnd, parameter: searchPos), end > start else {
                searchPos += 1
                continue
            }
            let indicatorValue = bridge.getGeneralProperty(ScintillaMessage.indicatorValueAt, parameter: indicator)
            if indicatorValue != 0 {
                return utf16Location(in: currentText, scintillaPosition: start)
            }
            searchPos = end + 1
        }
        return nil
    }

    func goToPreviousIndicator(_ style: SearchMarkStyle, fromPosition: Int) -> Int? {
        let indicator = CLong(style.rawValue)
        let currentText = text
        guard fromPosition > 0 else { return nil }
        guard let sciPos = scintillaPosition(in: currentText, utf16Location: fromPosition - 1) else { return nil }
        // Walk backward through the document, tracking the last indicator range before sciPos
        var lastFound: Int? = nil
        var pos: CLong = 0
        let textLength = CLong(currentText.utf16.count)
        while pos < textLength && pos < sciPos {
            let start = bridge.getGeneralProperty(ScintillaMessage.indicatorStart, parameter: pos) ?? pos
            guard let end = bridge.getGeneralProperty(ScintillaMessage.indicatorEnd, parameter: pos), end > start else {
                pos += 1
                continue
            }
            let indicatorValue = bridge.getGeneralProperty(ScintillaMessage.indicatorValueAt, parameter: indicator)
            if indicatorValue != 0 {
                if let utfStart = utf16Location(in: currentText, scintillaPosition: start) {
                    lastFound = utfStart
                }
            }
            pos = end + 1
        }
        return lastFound
    }

    func showIncrementalHighlight(range: NSRange) {
        let currentText = text
        guard let sciStart = scintillaPosition(in: currentText, utf16Location: range.location),
              let sciEnd = scintillaPosition(in: currentText, utf16Location: NSMaxRange(range))
        else { return }
        // Use Scintilla's built-in find indicator for incremental highlight
        bridge.setGeneralProperty(ScintillaMessage.findIndicatorShow, parameter: sciStart, value: sciEnd)
    }

    func hideIncrementalHighlight() {
        bridge.setGeneralProperty(ScintillaMessage.findIndicatorHide, parameter: 0, value: 0)
    }

    // MARK: - Multi-select operations

    var selectionCount: Int {
        Int(bridge.getGeneralProperty(ScintillaMessage.getSelections, parameter: 0) ?? 1)
    }

    func expandWordSelection() {
        let currentPos = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0) ?? 0
        let wordStart = bridge.getGeneralProperty(ScintillaMessage.wordStart, parameter: currentPos) ?? currentPos
        let wordEnd = bridge.getGeneralProperty(ScintillaMessage.wordEnd, parameter: currentPos) ?? currentPos
        bridge.setGeneralProperty(ScintillaMessage.setSel, parameter: wordEnd, value: wordStart)
    }

    func multiSelectAddEach(matchCase: Bool, wholeWord: Bool) {
        enableScintillaMultiSelection()
        let flags = buildSearchFlags(matchCase: matchCase, wholeWord: wholeWord)
        bridge.setGeneralProperty(ScintillaMessage.targetWholeDocument, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setSearchFlags, parameter: flags, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.multipleSelectAddEach, parameter: 0, value: 0)
    }

    func multiSelectAddNext(matchCase: Bool, wholeWord: Bool) {
        enableScintillaMultiSelection()
        let flags = buildSearchFlags(matchCase: matchCase, wholeWord: wholeWord)
        bridge.setGeneralProperty(ScintillaMessage.targetWholeDocument, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setSearchFlags, parameter: flags, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.multipleSelectAddNext, parameter: 0, value: 0)
    }

    func dropLastSelection() {
        let n = bridge.getGeneralProperty(ScintillaMessage.getSelections, parameter: 0) ?? 1
        if n > 1 {
            bridge.setGeneralProperty(ScintillaMessage.dropSelectionN, parameter: n - 1, value: 0)
        }
    }

    func multiSelectSkip() {
        enableScintillaMultiSelection()
        bridge.setGeneralProperty(ScintillaMessage.targetWholeDocument, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.multipleSelectAddNext, parameter: 0, value: 0)
        let n = bridge.getGeneralProperty(ScintillaMessage.getSelections, parameter: 0) ?? 0
        if n > 1 {
            bridge.setGeneralProperty(ScintillaMessage.dropSelectionN, parameter: n - 2, value: 0)
        }
    }

    private func buildSearchFlags(matchCase: Bool, wholeWord: Bool) -> CLong {
        var flags: CLong = 0
        if matchCase { flags |= 4 }   // SCFIND_MATCHCASE
        if wholeWord { flags |= 2 }   // SCFIND_WHOLEWORD
        return flags
    }

    // MARK: - Change history navigation

    var lineCount: Int {
        Int(bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0) ?? 1)
    }

    var currentLineNumber: Int {
        let pos = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0) ?? 0
        let line = bridge.getGeneralProperty(ScintillaMessage.lineFromPosition, parameter: pos) ?? 0
        return Int(line) + 1 // Convert 0-based to 1-based
    }

    func goToLine(_ line: Int) {
        let zeroBased = CLong(max(0, line - 1))
        bridge.setGeneralProperty(ScintillaMessage.gotoLine, parameter: zeroBased, value: 0)
    }

    func nextChangedLine(from line: Int) -> Int? {
        let zeroBased = CLong(max(0, line - 1))
        let mask = ScintillaHistoryMarker.allMask
        let totalLines = CLong(lineCount)

        // Search from current line forward, skipping current position's block
        var searchLine = zeroBased
        var blockEnd = zeroBased
        while searchLine < totalLines {
            let markers = bridge.getGeneralProperty(ScintillaMessage.markerGet, parameter: searchLine) ?? 0
            if (markers & mask) != 0 {
                if searchLine != zeroBased {
                    return Int(searchLine) + 1
                }
                blockEnd = searchLine + 1
            }
            searchLine += 1
        }

        // Wrap around
        let endRange = min(blockEnd + 1, totalLines)
        for i in 0..<endRange {
            let markers = bridge.getGeneralProperty(ScintillaMessage.markerGet, parameter: i) ?? 0
            if (markers & mask) != 0 {
                return Int(i) + 1
            }
        }
        return nil
    }

    func previousChangedLine(from line: Int) -> Int? {
        let zeroBased = CLong(max(0, line - 1))
        let mask = ScintillaHistoryMarker.allMask
        let totalLines = CLong(lineCount)

        // Search backward from current line
        var blockStart = zeroBased
        var searchLine = zeroBased
        while searchLine >= 0 {
            let markers = bridge.getGeneralProperty(ScintillaMessage.markerGet, parameter: searchLine) ?? 0
            if (markers & mask) != 0 {
                if searchLine != zeroBased {
                    return Int(searchLine) + 1
                }
                blockStart = searchLine
            }
            searchLine -= 1
        }

        // Wrap around from last line
        for i in stride(from: totalLines - 1, through: blockStart + 1, by: -1) {
            let markers = bridge.getGeneralProperty(ScintillaMessage.markerGet, parameter: i) ?? 0
            if (markers & mask) != 0 {
                return Int(i) + 1
            }
        }
        return nil
    }

    func clearChangeHistory() {
        // Disable then re-enable change history to clear markers
        bridge.setGeneralProperty(ScintillaMessage.setChangeHistory, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setChangeHistory, parameter: 1, value: 0)
    }

    // MARK: - Insert/Overtype mode

    var isOvertype: Bool {
        (bridge.getGeneralProperty(ScintillaMessage.getOvertype, parameter: 0) ?? 0) != 0
    }

    // MARK: - NPC (Non-Printing Characters) display

    var supportsNpcDisplay: Bool { true }

    func applyNpcDisplay(_ show: Bool) {
        let npcEntries: [(code: UInt8, abbrev: String)] = [
            (0x00, "NUL"), (0x01, "SOH"), (0x02, "STX"), (0x03, "ETX"),
            (0x04, "EOT"), (0x05, "ENQ"), (0x06, "ACK"), (0x07, "BEL"),
            (0x08, "BS"),  (0x09, "HT"),  (0x0A, "LF"),  (0x0B, "VT"),
            (0x0C, "FF"),  (0x0D, "CR"),  (0x0E, "SO"),   (0x0F, "SI"),
            (0x10, "DLE"), (0x11, "DC1"), (0x12, "DC2"), (0x13, "DC3"),
            (0x14, "DC4"), (0x15, "NAK"), (0x16, "SYN"), (0x17, "ETB"),
            (0x18, "CAN"), (0x19, "EM"),  (0x1A, "SUB"), (0x1B, "ESC"),
            (0x1C, "FS"),  (0x1D, "GS"),  (0x1E, "RS"),  (0x1F, "US"),
            (0x7F, "DEL")
        ]
        for (code, abbrev) in npcEntries {
            var charBytes: [UInt8] = [code, 0]
            charBytes.withUnsafeMutableBytes { charBuf in
                let paramAsInt = CLong(bitPattern: UInt(bitPattern: charBuf.baseAddress!))
                if show {
                    abbrev.withCString { reprPtr in
                        bridge.setReferenceProperty(
                            ScintillaMessage.setRepresentation,
                            parameter: paramAsInt,
                            value: UnsafeRawPointer(reprPtr)
                        )
                    }
                } else {
                    bridge.setReferenceProperty(
                        ScintillaMessage.clearRepresentation,
                        parameter: paramAsInt,
                        value: nil
                    )
                }
            }
        }
    }

    // MARK: - Smart highlighting

    private static let smartHighlightIndicator: CLong = 10 // INDICATOR_CONTAINER + custom

    var supportsSmartHighlight: Bool { true }

    func applySmartHighlight(_ word: String, matchCase: Bool, wholeWord: Bool) {
        clearSmartHighlight()
        guard !word.isEmpty else { return }

        // Configure the indicator style
        let indicator = Self.smartHighlightIndicator
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle, parameter: indicator, value: ScintillaIndicatorStyle.roundBox)
        // Light yellow background: RGB (255, 255, 0)
        let rgb: CLong = 0 | (255 << 8) | (255 << 16)
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore, parameter: indicator, value: rgb)
        bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha, parameter: indicator, value: 80)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder, parameter: indicator, value: 1)

        // Find all occurrences and mark them
        let currentText = text
        let options = TextSearch.Options(matchCase: matchCase, wholeWord: wholeWord, wraps: false, direction: .down)
        let matches = TextSearch.findAll(word, in: currentText, options: options)
        guard !matches.isEmpty else { return }

        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        for range in matches {
            guard let sciStart = scintillaPosition(in: currentText, utf16Location: range.location),
                  let sciEnd = scintillaPosition(in: currentText, utf16Location: NSMaxRange(range))
            else { continue }
            bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange, parameter: sciStart, value: sciEnd - sciStart)
        }
    }

    func clearSmartHighlight() {
        let indicator = Self.smartHighlightIndicator
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(text.utf16.count))
    }

    // MARK: - XML tag matching

    private static let xmlTagMatchIndicator: CLong = 11

    var supportsXmlTagMatch: Bool { true }

    func applyXmlTagHighlight(openRange: NSRange, closeRange: NSRange) {
        clearXmlTagHighlight()
        let indicator = Self.xmlTagMatchIndicator
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle, parameter: indicator, value: ScintillaIndicatorStyle.box)
        // Light green: RGB(0, 200, 0)
        let rgb: CLong = 0 | (200 << 8)
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore, parameter: indicator, value: rgb)
        bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha, parameter: indicator, value: 100)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder, parameter: indicator, value: 1)

        let currentText = text
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        for nsRange in [openRange, closeRange] {
            guard let sciStart = scintillaPosition(in: currentText, utf16Location: nsRange.location),
                  let sciEnd = scintillaPosition(in: currentText, utf16Location: NSMaxRange(nsRange))
            else { continue }
            bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange, parameter: sciStart, value: sciEnd - sciStart)
        }
    }

    func clearXmlTagHighlight() {
        let indicator = Self.xmlTagMatchIndicator
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(text.utf16.count))
    }

    // XML tag attribute highlight uses indicator 12 (distinct from tag-name indicator 11)
    private static let xmlTagAttributeIndicator = 12

    func applyXmlAttributeHighlight(range: NSRange) {
        clearXmlAttributeHighlight()
        let indicator = Self.xmlTagAttributeIndicator
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle, parameter: indicator, value: ScintillaIndicatorStyle.roundBox)
        // Light blue: RGB(100, 180, 255)
        let rgb: CLong = 100 | (180 << 8) | (255 << 16)
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore, parameter: indicator, value: rgb)
        bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha, parameter: indicator, value: 80)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder, parameter: indicator, value: 1)

        let currentText = text
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        guard let sciStart = scintillaPosition(in: currentText, utf16Location: range.location),
              let sciEnd = scintillaPosition(in: currentText, utf16Location: NSMaxRange(range))
        else { return }
        bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange, parameter: sciStart, value: sciEnd - sciStart)
    }

    func clearXmlAttributeHighlight() {
        let indicator = Self.xmlTagAttributeIndicator
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(text.utf16.count))
    }

    // MARK: - Auto-indent

    private var autoIndentEnabled = false
    /// Auto-indent mode: 0=off, 1=basic (copy prev line indent), 2=advanced (basic + bracket-aware)
    private var autoIndentModeValue = 1

    func applyAutoIndent(_ enabled: Bool) {
        autoIndentEnabled = enabled
    }

    func applyAutoIndentMode(_ mode: Int) {
        autoIndentModeValue = max(0, min(2, mode))
    }

    private func performAutoIndent() {
        guard autoIndentModeValue > 0,
              let caretPos = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0),
              let currentLine = bridge.getGeneralProperty(ScintillaMessage.lineFromPosition, parameter: caretPos),
              currentLine > 0 else { return }

        let prevLine = currentLine - 1
        let prevIndentCols = Int(bridge.getGeneralProperty(ScintillaMessage.getLineIndentation, parameter: prevLine) ?? 0)

        let useTabs = bridge.getGeneralProperty(ScintillaMessage.getUseTabs, parameter: 0) == 1
        let tabWidth = max(1, Int(bridge.getGeneralProperty(ScintillaMessage.getTabWidth, parameter: 0) ?? 4))

        // Advanced mode: detect bracket-aware indent adjustment
        var targetCols = prevIndentCols
        if autoIndentModeValue >= 2 {
            // Read previous line text via full text split (simple, reliable)
            let lines = text.components(separatedBy: "\n")
            if prevLine < lines.count {
                let lineText = lines[prevLine]
                let trimmed = lineText.trimmingCharacters(in: .whitespaces)
                // Increase indent after opening brackets
                if trimmed.hasSuffix("{") || trimmed.hasSuffix(":") || trimmed.hasSuffix("(") || trimmed.hasSuffix("[") {
                    targetCols += (useTabs ? 1 : tabWidth)
                }
                // Decrease indent if line starts with closing bracket
                if trimmed.hasPrefix("}") || trimmed.hasPrefix(")") || trimmed.hasPrefix("]") {
                    targetCols = max(0, targetCols - (useTabs ? 1 : tabWidth))
                }
            }
        }

        guard targetCols > 0 else { return }

        let indentString: String
        if useTabs {
            let tabs = targetCols / tabWidth
            let spaces = targetCols % tabWidth
            indentString = String(repeating: "\t", count: tabs) + String(repeating: " ", count: spaces)
        } else {
            indentString = String(repeating: " ", count: targetCols)
        }

        indentString.withCString { ptr in
            bridge.setReferenceProperty(ScintillaMessage.insertText, parameter: caretPos, value: UnsafeRawPointer(ptr))
        }
        let newPos = caretPos + CLong(indentString.utf8.count)
        bridge.setGeneralProperty(ScintillaMessage.gotoPos, parameter: newPos, value: 0)
    }

    // MARK: - Auto-pair insertion

    var supportsAutoPair: Bool { true }

    private var autoPairHandler: ((Character) -> Void)?

    func setAutoPairHandler(_ handler: ((Character) -> Void)?) {
        autoPairHandler = handler
    }

    private var charAddedHandler: ((Character) -> Void)?

    func setCharAddedHandler(_ handler: ((Character) -> Void)?) {
        charAddedHandler = handler
    }

    func insertAutoPairClose(_ close: Character) {
        guard let caretPos = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0) else { return }
        let docLen = bridge.getGeneralProperty(ScintillaMessage.getLength, parameter: 0) ?? 0

        // Check next char: if it's the same close char, skip over it
        if caretPos < docLen,
           let nextCode = bridge.getGeneralProperty(ScintillaMessage.getCharAt, parameter: caretPos),
           nextCode > 0,
           let scalar = Unicode.Scalar(UInt32(nextCode)),
           Character(scalar) == close
        {
            bridge.setGeneralProperty(ScintillaMessage.gotoPos, parameter: caretPos + 1, value: 0)
            return
        }

        // Insert the close character at current position
        String(close).withCString { ptr in
            bridge.setReferenceProperty(ScintillaMessage.insertText, parameter: caretPos, value: UnsafeRawPointer(ptr))
        }
    }

    private func handleCharAdded(from rawNotification: UnsafeMutableRawPointer) {
        let ch = rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.chOffset,
            as: Int32.self
        )
        // Newline: trigger basic auto-indent
        if autoIndentEnabled && (ch == 10 || ch == 13) {
            performAutoIndent()
            return
        }
        guard ch > 0, ch <= 127,
              let scalar = Unicode.Scalar(UInt32(ch))
        else { return }
        let char = Character(scalar)
        autoPairHandler?(char)
        charAddedHandler?(char)
    }

    // MARK: - Clickable URL highlighting

    private static let urlIndicator: CLong = 12

    var supportsUrlHighlight: Bool { true }
    private var urlClickHandler: ((NSRange) -> Void)?

    func setUrlClickHandler(_ handler: ((NSRange) -> Void)?) {
        urlClickHandler = handler
    }

    func applyUrlHighlights(ranges: [NSRange], style: Int = 0) {
        clearUrlHighlights()
        let indicator = Self.urlIndicator
        // style: 0=underline(compositionThin), 1=box, 2=fullBox
        let indicatorStyle: CLong
        switch style {
        case 1:  indicatorStyle = ScintillaIndicatorStyle.box
        case 2:  indicatorStyle = ScintillaIndicatorStyle.fullBox
        default: indicatorStyle = ScintillaIndicatorStyle.compositionThin
        }
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle, parameter: indicator, value: indicatorStyle)
        // Blue color
        let rgb: CLong = (0x00 << 16) | (0x66 << 8) | 0xCC
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore, parameter: indicator, value: rgb)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder, parameter: indicator, value: style == 2 ? 0 : 1)

        let currentText = text
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        for range in ranges {
            guard let sciStart = scintillaPosition(in: currentText, utf16Location: range.location),
                  let sciEnd = scintillaPosition(in: currentText, utf16Location: NSMaxRange(range))
            else { continue }
            bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange, parameter: sciStart, value: sciEnd - sciStart)
        }
    }

    func clearUrlHighlights() {
        let indicator = Self.urlIndicator
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(text.utf16.count))
    }

    func urlIndicatorRange(at position: Int) -> NSRange? {
        let indicator = Self.urlIndicator
        let currentText = text
        guard let sciPos = scintillaPosition(in: currentText, utf16Location: position) else { return nil }

        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        let indicValue = bridge.getGeneralProperty(ScintillaMessage.indicatorValueAt, parameter: sciPos) ?? 0
        guard indicValue != 0 else { return nil }

        let sciStart = bridge.getGeneralProperty(ScintillaMessage.indicatorStart, parameter: sciPos) ?? sciPos
        let sciEnd = bridge.getGeneralProperty(ScintillaMessage.indicatorEnd, parameter: sciPos) ?? sciPos
        guard sciEnd > sciStart,
              let utfStart = utf16Location(in: currentText, scintillaPosition: sciStart),
              let utfEnd = utf16Location(in: currentText, scintillaPosition: sciEnd)
        else { return nil }
        return NSRange(location: utfStart, length: utfEnd - utfStart)
    }

    private func handleIndicatorClick(from rawNotification: UnsafeMutableRawPointer) {
        let modifiers = rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.modifiersOffset,
            as: Int32.self
        )
        // SCMOD_CTRL = 2 on Scintilla, but on macOS the Cmd key is reported as SCMOD_SUPER = 8
        // Accept either Ctrl or Cmd
        let isCommandClick = (modifiers & 0x8) != 0 || (modifiers & 0x2) != 0
        guard isCommandClick else { return }

        let sciPos = rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.positionOffset,
            as: Int.self
        )
        let currentText = text
        guard let utf16Pos = utf16Location(in: currentText, scintillaPosition: CLong(sciPos)),
              let range = urlIndicatorRange(at: utf16Pos)
        else { return }

        urlClickHandler?(range)
    }

    // MARK: - Brace match highlight

    func applyBraceHighlight(sciPos1: Int, sciPos2: Int) {
        bridge.setGeneralProperty(ScintillaMessage.braceHighlight, parameter: CLong(sciPos1), value: CLong(sciPos2))
    }

    func applyBraceBadLight(sciPos: Int) {
        bridge.setGeneralProperty(ScintillaMessage.braceBadLight, parameter: CLong(sciPos), value: 0)
    }

    func clearBraceHighlight() {
        // Use -1 to clear highlight (invalid position)
        bridge.setGeneralProperty(ScintillaMessage.braceHighlight, parameter: CLong(bitPattern: UInt(bitPattern: -1)), value: CLong(bitPattern: UInt(bitPattern: -1)))
    }

    func updateBraceHighlightAtUtf16Location(_ location: Int) {
        let currentText = text
        guard let sciPos = scintillaPosition(in: currentText, utf16Location: location) else {
            clearBraceHighlight()
            return
        }

        // Try at current position and one before
        for tryPos in [sciPos, sciPos - 1] {
            guard tryPos >= 0 else { continue }
            if let matchPos = bridge.getGeneralProperty(ScintillaMessage.braceMatch, parameter: tryPos),
               matchPos >= 0 {
                applyBraceHighlight(sciPos1: Int(tryPos), sciPos2: Int(matchPos))
                return
            }
        }
        clearBraceHighlight()
    }

    // MARK: - Line padding

    func applyLinePadding(_ pixels: Int) {
        let clamped = CLong(max(0, min(5, pixels)))
        bridge.setGeneralProperty(ScintillaMessage.setExtraAscent, parameter: clamped, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setExtraDescent, parameter: clamped, value: 0)
    }

    func applyBidirectional(_ mode: Int) {
        bridge.setGeneralProperty(ScintillaMessage.setBidirectional, parameter: CLong(mode), value: 0)
    }

    func applySmoothFont(_ on: Bool) {
        // SCI_SETFONTQUALITY: 0=default, 1=non-antialiased, 2=antialiased, 3=LCD optimized
        bridge.setGeneralProperty(ScintillaMessage.setFontQuality, parameter: on ? 2 : 0, value: 0)
    }

    func applyMultiEditEnabled(_ on: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setMultipleSelection, parameter: on ? 1 : 0, value: 0)
    }

    func applyMultiPasteMode(_ mode: Int) {
        // SC_MULTIPASTE_ONCE=0 (paste into main selection only)
        // SC_MULTIPASTE_EACH=1 (paste into each selection)
        bridge.setGeneralProperty(ScintillaMessage.setMultiPaste, parameter: CLong(max(0, min(1, mode))), value: 0)
    }

    func applyAdditionalSelAlpha(_ alpha: Int) {
        // SCI_SETADDITIONALSELALPHA: 0-255 alpha, 256=opaque (no alpha)
        bridge.setGeneralProperty(ScintillaMessage.setAdditionalSelAlpha, parameter: CLong(max(0, min(256, alpha))), value: 0)
    }

    func applyAdditionalCaretsBlink(_ on: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setAdditionalCaretsBlink, parameter: on ? 1 : 0, value: 0)
    }

    func applyAdditionalCaretsVisible(_ on: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setAdditionalCaretsVisible, parameter: on ? 1 : 0, value: 0)
    }

    func applyCaretLineVisibleAlways(_ on: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setCaretLineVisibleAlways, parameter: on ? 1 : 0, value: 0)
    }

    func applyWhitespaceSize(_ size: Int) {
        // SCI_SETWHITESPACESIZE: dot size in pixels (1-5)
        bridge.setGeneralProperty(ScintillaMessage.setWhitespaceSize, parameter: CLong(max(1, min(5, size))), value: 0)
    }

    func applySelectionAlpha(_ alpha: Int) {
        // SCI_SETSELALPHA: 0-255 transparent, 256=opaque
        bridge.setGeneralProperty(ScintillaMessage.setSelAlpha, parameter: CLong(max(0, min(256, alpha))), value: 0)
    }

    func applyControlCharDisplay(_ mode: Int) {
        // SCI_SETCONTROLCHARSYMBOL: 0=show as glyph, 1-6=use defined symbol
        bridge.setGeneralProperty(ScintillaMessage.setControlCharSymbol, parameter: CLong(max(0, min(6, mode))), value: 0)
    }

    func applyScintillaRenderingTechnology(_ tech: Int) {
        // SCI_SETTECHNOLOGY: 0=SC_TECHNOLOGY_DEFAULT, 1=SC_TECHNOLOGY_DIRECTWRITE
        bridge.setGeneralProperty(ScintillaMessage.setTechnology, parameter: CLong(max(0, min(1, tech))), value: 0)
    }

    func applyRightClickKeepSelection(_ keep: Bool) {
        // SCI_SETMOUSESELECTIONRECTANGULARSWITCH: when true, right-click doesn't move caret
        // Not directly supported by Scintilla; handled at EditorWindowController level
    }

    func applyDisableAdvancedScrolling(_ disabled: Bool) {
        // SCI_SETLAYOUTCACHE: 0=SC_CACHE_NONE (no layout cache, simpler scrolling),
        // 1=SC_CACHE_DOCUMENT (cache whole document layout, smoother scrolling).
        // "Disable advanced scrolling" = use SC_CACHE_NONE when true.
        bridge.setGeneralProperty(ScintillaMessage.setLayoutCache, parameter: disabled ? 0 : 1, value: 0)
    }

    func applyEdgeMode(_ mode: Int) {
        // SCI_SETEDGEMODE: 0=EDGE_NONE, 1=EDGE_LINE, 2=EDGE_BACKGROUND
        bridge.setGeneralProperty(ScintillaMessage.setEdgeMode, parameter: CLong(max(0, min(3, mode))), value: 0)
    }

    func applyFoldFlags(_ flags: Int) {
        // SCI_SETFOLDFLAGS: bitmask for fold visualization
        bridge.setGeneralProperty(ScintillaMessage.setFoldFlags, parameter: CLong(max(0, min(30, flags))), value: 0)
    }

    func applyCopyLineWithoutSelection(_ enabled: Bool) {
        bridge.setGeneralProperty(ScintillaMessage.setCopyAllowsLineSelection, parameter: enabled ? 1 : 0, value: 0)
    }

    func styledSegments(ofSelection range: NSRange) -> [StyledSegment] {
        let fullText = text
        let nsText = fullText as NSString
        guard range.location + range.length <= nsText.length,
              let startByte = scintillaPosition(in: fullText, utf16Location: range.location),
              let endByte = scintillaPosition(in: fullText, utf16Location: NSMaxRange(range)),
              startByte < endByte
        else {
            let text = nsText.substring(with: range)
            return [StyledSegment(text: text, foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false)]
        }

        // Limit: style extraction per byte is expensive via dynamic dispatch;
        // fall back to plain segment for very large selections (>32 KB).
        let byteCount = Int(endByte - startByte)
        guard byteCount <= 32_768 else {
            let text = nsText.substring(with: range)
            return [StyledSegment(text: text, foreColor: 0x000000, backColor: 0xFFFFFF, bold: false, italic: false)]
        }

        // Build per-byte style array and collect unique style IDs.
        var byteStyles = [UInt8](repeating: 0, count: byteCount)
        var uniqueStyles = Set<UInt8>()
        for offset in 0..<byteCount {
            let pos = startByte + CLong(offset)
            let style = UInt8(truncatingIfNeeded: bridge.getGeneralProperty(ScintillaMessage.getStyleAt, parameter: pos) ?? 0)
            byteStyles[offset] = style
            uniqueStyles.insert(style)
        }

        // Query style properties for each unique style.
        var styleInfo: [UInt8: (fore: Int, back: Int, bold: Bool, italic: Bool)] = [:]
        for s in uniqueStyles {
            let rawFore = Int(bridge.getGeneralProperty(ScintillaMessage.styleGetFore, parameter: CLong(s)) ?? 0)
            let rawBack = Int(bridge.getGeneralProperty(ScintillaMessage.styleGetBack, parameter: CLong(s)) ?? 0)
            // Scintilla colours are 0x00BBGGRR; convert to 0x00RRGGBB.
            let fore = Self.bgrToRGB(rawFore)
            let back = Self.bgrToRGB(rawBack)
            let bold = (bridge.getGeneralProperty(ScintillaMessage.styleGetBold, parameter: CLong(s)) ?? 0) != 0
            let italic = (bridge.getGeneralProperty(ScintillaMessage.styleGetItalic, parameter: CLong(s)) ?? 0) != 0
            styleInfo[s] = (fore: fore, back: back, bold: bold, italic: italic)
        }

        // Group consecutive bytes with the same style and convert to text segments.
        var segments: [StyledSegment] = []
        var runStart = 0
        for i in 1...byteCount {
            if i == byteCount || byteStyles[i] != byteStyles[runStart] {
                let byteBegin = Int(startByte) + runStart
                let byteEnd = Int(startByte) + i
                let utf8 = fullText.utf8
                let startIdx = utf8.index(utf8.startIndex, offsetBy: byteBegin)
                let endIdx = utf8.index(utf8.startIndex, offsetBy: byteEnd)
                if let sStart = String.Index(startIdx, within: fullText),
                   let sEnd = String.Index(endIdx, within: fullText) {
                    let segText = String(fullText[sStart..<sEnd])
                    if let info = styleInfo[byteStyles[runStart]] {
                        segments.append(StyledSegment(text: segText, foreColor: info.fore, backColor: info.back, bold: info.bold, italic: info.italic))
                    }
                }
                runStart = i
            }
        }
        return segments
    }

    /// Convert Scintilla 0x00BBGGRR colour to 0x00RRGGBB.
    private static func bgrToRGB(_ bgr: Int) -> Int {
        let r = bgr & 0xFF
        let g = (bgr >> 8) & 0xFF
        let b = (bgr >> 16) & 0xFF
        return (r << 16) | (g << 8) | b
    }

    func applyScintillaKeyRemaps(_ remaps: [ScintillaKeyRemap]) {
        for remap in remaps {
            if remap.key == 0 {
                bridge.setGeneralProperty(ScintillaMessage.clearCmdKey, parameter: remap.keyDefinition, value: 0)
            } else {
                bridge.setGeneralProperty(ScintillaMessage.assignCmdKey, parameter: remap.keyDefinition, value: Int(remap.commandID))
            }
        }
    }

    func setContextMenu(_ menu: NSMenu?) {
        scintillaView.menu = menu
    }

    func scrollToSelection() {
        bridge.setGeneralProperty(ScintillaMessage.scrollCaret, parameter: 0, value: 0)
    }

    private func configureNotificationDelegateIfAvailable() {
        guard !didConfigureNotificationDelegate else { return }
        didConfigureNotificationDelegate = bridge.setDelegate(self)
    }

    private func postTextDidChangeIfNeeded(from rawNotification: UnsafeMutableRawPointer) {
        let modificationType = rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.modificationTypeOffset,
            as: Int32.self
        )
        guard modificationType & ScintillaModificationType.textChanged != 0 else { return }
        // Defer to next run-loop iteration to avoid re-entering Swift Observation tracking
        // while Scintilla is in the middle of a drawRect/paint cycle (macOS 26+ SIGSEGV fix).
        let view = scintillaView
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSText.didChangeNotification, object: view)
        }
    }

    private func handleMarginClick(from rawNotification: UnsafeMutableRawPointer) {
        let margin = CLong(rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.marginOffset,
            as: Int32.self
        ))
        let position = CLong(rawNotification.load(
            fromByteOffset: ScintillaNotificationLayout.positionOffset,
            as: Int.self
        ))

        guard let editorMargin = editorMargin(forScintillaMargin: margin),
              let line = oneBasedLine(atScintillaPosition: position)
        else {
            return
        }

        marginClickHandler?(EditorMarginClick(margin: editorMargin, line: line))
    }

    private func editorMargin(forScintillaMargin margin: CLong) -> EditorMargin? {
        switch margin {
        case ScintillaMargin.bookmark:
            return .bookmark
        case ScintillaMargin.fold:
            return .fold
        default:
            return nil
        }
    }

    private func oneBasedLine(atScintillaPosition position: CLong) -> Int? {
        guard position >= 0,
              let zeroBasedLine = bridge.getGeneralProperty(
                ScintillaMessage.lineFromPosition,
                parameter: position
              ),
              zeroBasedLine >= 0
        else {
            return nil
        }

        return Int(zeroBasedLine) + 1
    }

    private func toggleFold(zeroBasedLine: Int) -> Bool {
        guard zeroBasedLine >= 0 else { return false }
        let line = CLong(zeroBasedLine)
        let foldLevel = bridge.getGeneralProperty(ScintillaMessage.getFoldLevel, parameter: line) ?? 0
        guard (foldLevel & ScintillaFoldLevel.headerFlag) != 0 else { return false }

        bridge.setGeneralProperty(ScintillaMessage.toggleFold, parameter: line, value: 0)
        return true
    }

    private func utf16Location(in text: String, scintillaPosition: CLong) -> Int? {
        guard scintillaPosition >= 0 else { return nil }
        let byteOffset = Int(scintillaPosition)
        guard byteOffset <= text.utf8.count else { return nil }

        let byteIndex = text.utf8.index(text.utf8.startIndex, offsetBy: byteOffset)
        guard let stringIndex = String.Index(byteIndex, within: text),
              let utf16Index = stringIndex.samePosition(in: text.utf16)
        else {
            return nil
        }
        return text.utf16.distance(from: text.utf16.startIndex, to: utf16Index)
    }

    private func scintillaPositionRange(
        in text: String,
        forUTF16Range range: NSRange
    ) -> (anchor: CLong, caret: CLong)? {
        guard range.location >= 0,
              range.length >= 0,
              range.location <= Int.max - range.length,
              let anchor = scintillaPosition(in: text, utf16Location: range.location),
              let caret = scintillaPosition(in: text, utf16Location: range.location + range.length)
        else {
            return nil
        }

        return (anchor: anchor, caret: caret)
    }

    private func scintillaPosition(in text: String, utf16Location: Int) -> CLong? {
        guard utf16Location >= 0,
              utf16Location <= text.utf16.count,
              let utf16Index = text.utf16.index(
                text.utf16.startIndex,
                offsetBy: utf16Location,
                limitedBy: text.utf16.endIndex
              ),
              let stringIndex = String.Index(utf16Index, within: text),
              let utf8Index = stringIndex.samePosition(in: text.utf8)
        else {
            return nil
        }

        return CLong(exactly: text.utf8.distance(from: text.utf8.startIndex, to: utf8Index))
    }

    private func nonNegativeScintillaPosition(_ value: Int) -> CLong? {
        CLong(exactly: max(0, value))
    }

    private func clampedSelectionIndex(_ index: Int, selectionCount: Int) -> Int? {
        guard selectionCount > 0 else { return nil }
        return min(max(0, index), selectionCount - 1)
    }

    private func enableScintillaMultiSelection() {
        bridge.setGeneralProperty(ScintillaMessage.setMultipleSelection, parameter: 1, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setAdditionalSelectionTyping, parameter: 1, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setMultiPaste, parameter: ScintillaMultiPaste.each, value: 0)
    }

    private func enableScintillaRectangularVirtualSpace() {
        let options = bridge.getGeneralProperty(ScintillaMessage.getVirtualSpaceOptions, parameter: 0) ?? 0
        bridge.setGeneralProperty(
            ScintillaMessage.setVirtualSpaceOptions,
            parameter: options | ScintillaVirtualSpace.rectangularSelection,
            value: 0
        )
    }

    private func configureMargins() {
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginType,
            parameter: ScintillaMargin.lineNumber,
            value: ScintillaMarginType.number
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginWidth,
            parameter: ScintillaMargin.lineNumber,
            value: 44
        )

        bridge.setGeneralProperty(
            ScintillaMessage.setMarginType,
            parameter: ScintillaMargin.bookmark,
            value: ScintillaMarginType.symbol
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginMask,
            parameter: ScintillaMargin.bookmark,
            value: ScintillaMarker.bookmarkMask
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginSensitive,
            parameter: ScintillaMargin.bookmark,
            value: 1
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginWidth,
            parameter: ScintillaMargin.bookmark,
            value: 16
        )
        bridge.setGeneralProperty(
            ScintillaMessage.markerDefine,
            parameter: ScintillaMarker.bookmark,
            value: ScintillaMarkerSymbol.circle
        )
        bridge.setGeneralProperty(
            ScintillaMessage.markerSetFore,
            parameter: ScintillaMarker.bookmark,
            value: CLong(StyleColor(red: 255, green: 255, blue: 255).scintillaColor)
        )
        bridge.setGeneralProperty(
            ScintillaMessage.markerSetBack,
            parameter: ScintillaMarker.bookmark,
            value: CLong(StyleColor(red: 54, green: 126, blue: 224).scintillaColor)
        )

        bridge.setGeneralProperty(
            ScintillaMessage.setMarginType,
            parameter: ScintillaMargin.fold,
            value: ScintillaMarginType.symbol
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginMask,
            parameter: ScintillaMargin.fold,
            value: ScintillaMarker.folderMask
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginSensitive,
            parameter: ScintillaMargin.fold,
            value: 1
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginWidth,
            parameter: ScintillaMargin.fold,
            value: 16
        )
        configureFolderMarkers()
    }

    private var foldCompactMode: Bool = false

    private func configureFoldingProperties() {
        bridge.setLexerProperty(name: "fold", value: "1")
        bridge.setLexerProperty(name: "fold.compact", value: foldCompactMode ? "1" : "0")
        bridge.setLexerProperty(name: "fold.comment", value: "1")
        bridge.setLexerProperty(name: "fold.preprocessor", value: "1")
        // HTML/XML-specific folding (matching NotepadNext xml.lua)
        bridge.setLexerProperty(name: "fold.html", value: "1")
    }

    private func configureFolderMarkers() {
        let folderMarkers: [(CLong, CLong)] = [
            (ScintillaMarker.folderEnd, ScintillaMarkerSymbol.boxPlusConnected),
            (ScintillaMarker.folderOpenMid, ScintillaMarkerSymbol.boxMinusConnected),
            (ScintillaMarker.folderMidTail, ScintillaMarkerSymbol.tCorner),
            (ScintillaMarker.folderTail, ScintillaMarkerSymbol.lCorner),
            (ScintillaMarker.folderSub, ScintillaMarkerSymbol.vLine),
            (ScintillaMarker.folder, ScintillaMarkerSymbol.boxPlus),
            (ScintillaMarker.folderOpen, ScintillaMarkerSymbol.boxMinus)
        ]

        for (markerNumber, symbol) in folderMarkers {
            bridge.setGeneralProperty(
                ScintillaMessage.markerDefine,
                parameter: markerNumber,
                value: symbol
            )
            bridge.setGeneralProperty(
                ScintillaMessage.markerSetFore,
                parameter: markerNumber,
                value: CLong(StyleColor(red: 255, green: 255, blue: 255).scintillaColor)
            )
            bridge.setGeneralProperty(
                ScintillaMessage.markerSetBack,
                parameter: markerNumber,
                value: CLong(StyleColor(red: 99, green: 110, blue: 123).scintillaColor)
            )
        }
    }

    private func applyStyles(
        language: LanguageDefinition,
        styleCatalog: StyleCatalog,
        stylePreferences: StylePreferences
    ) {
        guard let lexer = styleCatalog.lexer(named: language.name) else {
            // No style catalog entry for this language — apply sensible default colors
            // so syntax highlighting is visible even without a matching theme
            applyDefaultLexerStyles()
            return
        }

        for baseStyle in lexer.styles {
            let key = StyleOverrideKey(languageName: lexer.name, styleID: baseStyle.styleID)
            let style = stylePreferences.resolvedStyle(for: key, base: baseStyle)
            applyStyle(style)
        }
    }

    /// Apply minimal default colors for common Scintilla lexer style IDs (0-15).
    /// Ensures syntax highlighting is visible when the style catalog has no entry
    /// for the current language (e.g. fallback catalog language with no theme match).
    private func applyDefaultLexerStyles() {
        // Standard Scintilla lexer style ID semantics:
        // 0=default, 1=identifier, 2=comment, 3=number, 4=string/double-quoted,
        // 5=character/single-quoted, 6=keyword/instruction, 7=triple-quoted/verbatim,
        // 8=preprocessor, 9=operator, 10=label, 11-15=extended lexer styles
        let defaults: [(Int, UInt8, UInt8, UInt8)] = [
            (0,  217, 217, 217),  // default: light grey
            (1,  230, 230, 230),  // identifier: white-ish
            (2,  102, 179, 102),  // comment: green
            (3,  255, 153, 77),   // number: orange
            (4,  255, 204, 102),  // string: yellow
            (5,  255, 128, 128),  // character: red-ish
            (6,  77,  153, 255),  // keyword: blue
            (7,  153, 102, 204),  // verbatim: purple
            (8,  102, 153, 204),  // preprocessor: steel blue
            (9,  230, 230, 128),  // operator: light yellow
            (10, 204, 128, 204),  // label: magenta
            (11, 128, 204, 204),  // extended: teal
            (12, 204, 153, 102),  // extended: tan
            (13, 153, 204, 128),  // extended: sage
            (14, 179, 179, 102),  // extended: olive
            (15, 204, 102, 102),  // extended: dark red
        ]
        for (styleID, r, g, b) in defaults {
            let color = StyleColor(red: r, green: g, blue: b)
            bridge.setGeneralProperty(ScintillaMessage.styleSetFore, parameter: CLong(styleID), value: CLong(color.scintillaColor))
        }
    }

    // Apply global/widget styles (STYLE_DEFAULT=32, STYLE_LINENUMBER=33, etc.)
    // and propagate the Default Style colors to the autocomplete list.
    private func applyGlobalStyles(styleCatalog: StyleCatalog, stylePreferences: StylePreferences) {
        // Valid Scintilla built-in style IDs for global widget styles
        let scintillaBuiltinRange = 21...40
        for baseStyle in styleCatalog.globalStyles where scintillaBuiltinRange.contains(baseStyle.styleID) {
            let key = StyleOverrideKey(languageName: "global", styleID: baseStyle.styleID)
            let style = stylePreferences.resolvedStyle(for: key, base: baseStyle)
            applyStyle(style)
        }
        // Apply Default Style (STYLE_DEFAULT = 32) colors to autocomplete list
        if let defaultStyle = styleCatalog.globalStyles.first(where: { $0.styleID == 32 }) {
            let key = StyleOverrideKey(languageName: "global", styleID: 32)
            let resolved = stylePreferences.resolvedStyle(for: key, base: defaultStyle)
            if let fg = resolved.foreground {
                bridge.setGeneralProperty(ScintillaMessage.autoCSetFore, parameter: CLong(fg.scintillaColor), value: 0)
            }
            if let bg = resolved.background {
                bridge.setGeneralProperty(ScintillaMessage.autoCSetBack, parameter: CLong(bg.scintillaColor), value: 0)
            }
        }
    }

    private func applyStyle(_ style: LexerStyle) {
        let styleID = CLong(style.styleID)

        if let foreground = style.foreground {
            bridge.setGeneralProperty(ScintillaMessage.styleSetFore, parameter: styleID, value: CLong(foreground.scintillaColor))
        }

        if let background = style.background {
            bridge.setGeneralProperty(ScintillaMessage.styleSetBack, parameter: styleID, value: CLong(background.scintillaColor))
        }

        if let fontName = style.fontName {
            bridge.setStringProperty(ScintillaMessage.styleSetFont, parameter: styleID, value: fontName)
        }

        if let fontSize = style.fontSize {
            bridge.setGeneralProperty(ScintillaMessage.styleSetSize, parameter: styleID, value: CLong(fontSize))
        }

        bridge.setGeneralProperty(ScintillaMessage.styleSetBold, parameter: styleID, value: style.isBold ? 1 : 0)
        bridge.setGeneralProperty(ScintillaMessage.styleSetItalic, parameter: styleID, value: style.isItalic ? 1 : 0)
    }

    private static func frameworkCandidates() -> [URL] {
        let sourceRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        if let privateFrameworksURL = Bundle.main.privateFrameworksURL {
            urls.append(privateFrameworksURL.appending(path: "Scintilla.framework"))
        }

        urls.append(sourceRoot.appending(path: frameworkRelativePath))
        urls.append(URL(filePath: FileManager.default.currentDirectoryPath).appending(path: frameworkRelativePath))
        return urls
    }
}

@MainActor
private final class LexillaDynamicLibrary {
    static let shared = LexillaDynamicLibrary()

    private init() {
        // Lexilla is now statically linked via CLexillaBridge.
        // No dlopen/dlsym needed — CreateLexer is available as LexillaBridge_CreateLexer.
    }

    func createLexer(named lexerName: String) -> UnsafeMutableRawPointer? {
        return lexerName.withCString { namePtr in
            LexillaBridge_CreateLexer(namePtr)
        }
    }
}

@MainActor
private final class ScintillaDynamicBridge {
    private unowned let target: NSView

    init(target: NSView) {
        self.target = target
    }

    func selectedRange() -> NSRange {
        let selector = NSSelectorFromString("selectedRange")
        guard target.responds(to: selector), let method = target.method(for: selector) else {
            return NSRange(location: 0, length: 0)
        }
        typealias Function = @convention(c) (AnyObject, Selector) -> NSRange
        let function = unsafeBitCast(method, to: Function.self)
        return function(target, selector)
    }

    func setFont(name: NSString, size: Int32, bold: Bool, italic: Bool) {
        let selector = NSSelectorFromString("setFontName:size:bold:italic:")
        guard target.responds(to: selector), let method = target.method(for: selector) else { return }
        typealias Function = @convention(c) (AnyObject, Selector, NSString, Int32, ObjCBool, ObjCBool) -> Void
        let function = unsafeBitCast(method, to: Function.self)
        function(target, selector, name, size, ObjCBool(bold), ObjCBool(italic))
    }

    func setGeneralProperty(_ property: Int32, parameter: CLong, value: CLong) {
        let selector = NSSelectorFromString("setGeneralProperty:parameter:value:")
        guard target.responds(to: selector), let method = target.method(for: selector) else { return }
        typealias Function = @convention(c) (AnyObject, Selector, Int32, CLong, CLong) -> Void
        let function = unsafeBitCast(method, to: Function.self)
        function(target, selector, property, parameter, value)
    }

    func getGeneralProperty(_ property: Int32, parameter: CLong) -> CLong? {
        let selector = NSSelectorFromString("getGeneralProperty:parameter:")
        guard target.responds(to: selector), let method = target.method(for: selector) else { return nil }
        typealias Function = @convention(c) (AnyObject, Selector, Int32, CLong) -> CLong
        let function = unsafeBitCast(method, to: Function.self)
        return function(target, selector, property, parameter)
    }

    func setReferenceProperty(_ property: Int32, parameter: CLong, value: UnsafeRawPointer?) {
        let selector = NSSelectorFromString("setReferenceProperty:parameter:value:")
        guard target.responds(to: selector), let method = target.method(for: selector) else { return }
        typealias Function = @convention(c) (AnyObject, Selector, Int32, CLong, UnsafeRawPointer?) -> Void
        let function = unsafeBitCast(method, to: Function.self)
        function(target, selector, property, parameter, value)
    }

    func setStringProperty(_ property: Int32, parameter: CLong, value: String) {
        value.withCString { pointer in
            setReferenceProperty(property, parameter: parameter, value: UnsafeRawPointer(pointer))
        }
    }

    func setLexerProperty(name: String, value: String) {
        let selector = NSSelectorFromString("setLexerProperty:value:")
        guard target.responds(to: selector), let method = target.method(for: selector) else { return }
        typealias Function = @convention(c) (AnyObject, Selector, NSString, NSString) -> Void
        let function = unsafeBitCast(method, to: Function.self)
        function(target, selector, name as NSString, value as NSString)
    }

    func setDelegate(_ delegate: AnyObject?) -> Bool {
        let selector = NSSelectorFromString("setDelegate:")
        guard target.responds(to: selector), let method = target.method(for: selector) else {
            return false
        }
        typealias Function = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let function = unsafeBitCast(method, to: Function.self)
        function(target, selector, delegate)
        return true
    }
}

private enum ScintillaNotificationCode {
    static let modified: UInt32 = 2008
    static let charAdded: UInt32 = 2001
    static let marginClick: UInt32 = 2010
    static let updateUI: UInt32 = 2007
    static let indicatorClick: UInt32 = 2023
}

private enum ScintillaModificationType {
    static let insertText: Int32 = 0x1
    static let deleteText: Int32 = 0x2
    static let textChanged = insertText | deleteText
}

private enum ScintillaNotificationLayout {
    // Mirrors upstream Scintilla's 64-bit macOS NotificationData/SCNotification
    // layout used by ScintillaView's notification: delegate callback.
    static let codeOffset = 2 * MemoryLayout<Int>.size
    static let positionOffset = aligned(
        codeOffset + MemoryLayout<UInt32>.size,
        to: MemoryLayout<Int>.alignment
    )
    // ch field immediately follows position in SCNotification
    static let chOffset = positionOffset + MemoryLayout<Int>.size
    // modifiers field follows ch
    static let modifiersOffset = chOffset + MemoryLayout<Int32>.size
    static let modificationTypeOffset = positionOffset
        + MemoryLayout<Int>.size
        + MemoryLayout<Int32>.size
        + MemoryLayout<Int32>.size
    static let marginOffset = {
        var offset = modificationTypeOffset + MemoryLayout<Int32>.size
        offset = aligned(offset, to: MemoryLayout<UnsafeRawPointer?>.alignment)
        offset += MemoryLayout<UnsafeRawPointer?>.size
        offset += MemoryLayout<Int>.size
        offset += MemoryLayout<Int>.size
        offset += MemoryLayout<Int32>.size
        offset = aligned(offset, to: MemoryLayout<Int>.alignment)
        offset += MemoryLayout<UInt>.size
        offset += MemoryLayout<Int>.size
        offset += MemoryLayout<Int>.size
        offset += MemoryLayout<Int32>.size
        offset += MemoryLayout<Int32>.size
        return offset
    }()

    private static func aligned(_ offset: Int, to alignment: Int) -> Int {
        let remainder = offset % alignment
        return remainder == 0 ? offset : offset + alignment - remainder
    }
}

private enum ScintillaMessage {
    static let getCurrentPos: Int32 = 2008
    static let gotoLine: Int32 = 2024
    static let getLineCount: Int32 = 2154
    static let colourise: Int32 = 4003
    static let styleClearAll: Int32 = 2050
    static let styleSetFore: Int32 = 2051
    static let styleSetBack: Int32 = 2052
    static let styleSetBold: Int32 = 2053
    static let styleSetItalic: Int32 = 2054
    static let styleSetSize: Int32 = 2055
    static let styleSetFont: Int32 = 2056
    static let setWrapMode: Int32 = 2268
    static let setWrapVisualFlags: Int32 = 2460
    static let setChangeHistory: Int32 = 2780
    static let setTabWidth: Int32 = 2036
    static let setUseTabs: Int32 = 2124
    static let setEdgeMode: Int32 = 2363
    static let setEdgeColumn: Int32 = 2361
    static let setReadOnly: Int32 = 2171
    static let getReadOnly: Int32 = 2140
    static let setViewWhitespace: Int32 = 2021
    static let setViewEOL: Int32 = 2356
    static let setCaretLineVisible: Int32 = 2096
    static let setCaretLineBack: Int32 = 2098
    static let setIndentationGuides: Int32 = 2132
    static let setCaretLineBackAlpha: Int32 = 2470
    static let setCaretLineVisibleAlways: Int32 = 2655
    static let getOvertype: Int32 = 2115
    static let lineFromPosition: Int32 = 2166
    static let scrollCaret: Int32 = 2169
    static let getFoldLevel: Int32 = 2223
    static let getFoldExpanded: Int32 = 2230
    static let setFoldExpanded: Int32 = 2229
    static let toggleFold: Int32 = 2231
    static let ensureVisible: Int32 = 2232
    static let showLines: Int32 = 2226
    static let hideLines: Int32 = 2227
    static let getLineVisible: Int32 = 2228
    static let selectionIsRectangle: Int32 = 2372
    static let setMultipleSelection: Int32 = 2563
    static let setAdditionalSelectionTyping: Int32 = 2565
    static let clearSelections: Int32 = 2571
    static let setSelection: Int32 = 2572
    static let addSelection: Int32 = 2573
    static let setMainSelection: Int32 = 2574
    static let setRectangularSelectionCaret: Int32 = 2588
    static let getRectangularSelectionCaret: Int32 = 2589
    static let setRectangularSelectionAnchor: Int32 = 2590
    static let getRectangularSelectionAnchor: Int32 = 2591
    static let setRectangularSelectionCaretVirtualSpace: Int32 = 2592
    static let getRectangularSelectionCaretVirtualSpace: Int32 = 2593
    static let setRectangularSelectionAnchorVirtualSpace: Int32 = 2594
    static let getRectangularSelectionAnchorVirtualSpace: Int32 = 2595
    static let setVirtualSpaceOptions: Int32 = 2596
    static let getVirtualSpaceOptions: Int32 = 2597
    // Multi-select operations
    static let getSelections: Int32 = 2570
    static let dropSelectionN: Int32 = 2679
    static let multipleSelectAddNext: Int32 = 2688
    static let multipleSelectAddEach: Int32 = 2689
    static let setSearchFlags: Int32 = 2198
    static let targetWholeDocument: Int32 = 2690
    static let getSelectionStart: Int32 = 2143
    static let getSelectionEnd: Int32 = 2145
    static let wordStart: Int32 = 2266
    static let wordEnd: Int32 = 2267
    static let isRangeWord: Int32 = 2691
    static let setSel: Int32 = 2160
    static let changeSelectionRange: Int32 = 2567
    static let autoCShow: Int32 = 2100
    static let autoCCancel: Int32 = 2101
    static let autoCGetCurrent: Int32 = 2443
    static let autoCStops: Int32 = 2105
    static let autoCSeparator: Int32 = 2106
    static let autoCChoose: Int32 = 2108
    static let setAutoCIgnoreCase: Int32 = 2286
    static let callTipShow: Int32 = 2200
    static let callTipCancel: Int32 = 2201
    static let callTipPosStart: Int32 = 2214
    static let setMultiPaste: Int32 = 2614
    static let foldAll: Int32 = 2662
    static let assignCmdKey: Int32 = 2070
    static let clearCmdKey: Int32 = 2071
    static let clearAllCmdKeys: Int32 = 2072
    static let contractedFoldNext: Int32 = 2618
    static let braceMatch: Int32 = 2353
    static let setKeywords: Int32 = 4005
    static let setILexer: Int32 = 4033
    static let setLexerLanguage: Int32 = 4005
    static let setLexer: Int32 = 4001
    static let clearDocumentStyle: Int32 = 2005
    static let markerDefine: Int32 = 2040
    static let markerSetFore: Int32 = 2041
    static let markerSetBack: Int32 = 2042
    static let markerAdd: Int32 = 2043
    static let markerDeleteAll: Int32 = 2045
    static let markerGet: Int32 = 2046
    static let markerNext: Int32 = 2047
    static let markerPrevious: Int32 = 2048
    static let markerAddSet: Int32 = 2466
    static let setMarginType: Int32 = 2240
    static let setMarginWidth: Int32 = 2242
    static let setMarginMask: Int32 = 2244
    static let setMarginSensitive: Int32 = 2246
    // Indicator messages
    static let indicSetStyle: Int32 = 2080
    static let indicSetFore: Int32 = 2082
    static let indicSetAlpha: Int32 = 2543
    static let indicSetUnder: Int32 = 2549
    static let setIndicatorCurrent: Int32 = 2500
    static let setIndicatorValue: Int32 = 2502
    static let indicatorFillRange: Int32 = 2504
    static let indicatorClearRange: Int32 = 2505
    static let indicatorAllOnFor: Int32 = 2506
    static let indicatorValueAt: Int32 = 2507
    static let indicatorStart: Int32 = 2508
    static let indicatorEnd: Int32 = 2509
    static let findIndicatorShow: Int32 = 2640
    static let findIndicatorHide: Int32 = 2641
    static let searchNext: Int32 = 2367
    static let searchPrev: Int32 = 2368
    static let setTargetStart: Int32 = 2190
    static let setTargetEnd: Int32 = 2192
    static let searchInTarget: Int32 = 2197
    static let getTargetStart: Int32 = 2191
    static let getTargetEnd: Int32 = 2193
    static let replaceTarget: Int32 = 2194
    static let getLineEndPosition: Int32 = 2136
    static let positionFromLine: Int32 = 2167
    static let getSelText: Int32 = 2161
    static let getTextRange: Int32 = 2162
    static let annotationClearAll: Int32 = 2547
    static let insertText: Int32 = 2003
    static let getCharAt: Int32 = 2007
    static let getLength: Int32 = 2006
    static let deleteRange: Int32 = 2645
    static let gotoPos: Int32 = 2025
    static let braceHighlight: Int32 = 2351
    static let braceBadLight: Int32 = 2352
    static let setRepresentation: Int32 = 2629
    static let clearRepresentation: Int32 = 2630
    static let setCaretWidth: Int32 = 2188
    static let getCaretWidth: Int32 = 2189
    static let setCaretPeriod: Int32 = 2076
    static let multiEdgeAddLine: Int32 = 2694
    static let multiEdgeClearAll: Int32 = 2695
    static let setCaretLineFrame: Int32 = 2705
    static let setWrapIndentMode: Int32 = 2472
    static let setBackSpaceUnIndents: Int32 = 2262
    static let setIndent: Int32 = 2122
    static let getLineIndentation: Int32 = 2127
    static let getUseTabs: Int32 = 2125
    static let getTabWidth: Int32 = 2121
    static let setEndAtLastLine: Int32 = 2277
    static let setScrollWidthTracking: Int32 = 2516
    static let autoCSetFore: Int32 = 2237
    static let autoCSetBack: Int32 = 2238
    static let setExtraAscent: Int32 = 2525
    static let setExtraDescent: Int32 = 2526
    static let setBidirectional: Int32 = 2709
    static let setCopyAllowsLineSelection: Int32 = 2660
    static let setDragDropEnabled: Int32 = 2819
    static let setPasteConvertEndings: Int32 = 2467
    static let setCaretStickyMode: Int32 = 2657
    static let setFontQuality: Int32 = 2611
    static let setAdditionalSelAlpha: Int32 = 2602
    static let setAdditionalCaretsVisible: Int32 = 2608
    static let setAdditionalCaretsBlink: Int32 = 2761
    static let setTechnology: Int32 = 2630  // SCI_SETTECHNOLOGY: SC_TECHNOLOGY_DEFAULT=0, SC_TECHNOLOGY_DIRECTWRITE=1
    static let setLayoutCache: Int32 = 2213 // SCI_SETLAYOUTCACHE: SC_CACHE_NONE=0, SC_CACHE_DOCUMENT=1
    static let setFoldFlags: Int32 = 2233   // SCI_SETFOLDFLAGS: bitmask for fold line indicators
    static let setWhitespaceSize: Int32 = 2087
    static let setSelAlpha: Int32 = 2473
    static let setControlCharSymbol: Int32 = 2388
    // Style query
    static let getStyleAt: Int32 = 2498
    static let styleGetFore: Int32 = 2481
    static let styleGetBack: Int32 = 2482
    static let styleGetBold: Int32 = 2483
    static let styleGetItalic: Int32 = 2484
}


private enum ScintillaWrapMode {
    static let none: CLong = 0
    static let word: CLong = 1
    static let whitespace: CLong = 2
    static let character: CLong = 3
}

private enum ScintillaWhitespaceMode {
    static let invisible: CLong = 0
    static let visibleAlways: CLong = 1
}

private enum ScintillaWrapVisualFlag {
    static let none: CLong = 0
    static let end: CLong = 1
}

private enum ScintillaIndentGuideMode {
    static let none: CLong = 0
    static let lookForward: CLong = 2
}

private enum ScintillaEdgeMode {
    static let none: CLong = 0
    static let line: CLong = 1
}

private enum ScintillaMultiPaste {
    static let each: CLong = 1
}

private enum ScintillaVirtualSpace {
    static let rectangularSelection: CLong = 1
}

/// Change history marker numbers used by Scintilla.
private enum ScintillaHistoryMarker {
    static let revertedToOrigin: CLong = 21
    static let saved: CLong = 22
    static let modified: CLong = 23
    static let revertedToModified: CLong = 24

    /// Combined mask for all change history markers.
    static var allMask: CLong {
        (1 << revertedToOrigin) | (1 << saved) | (1 << modified) | (1 << revertedToModified)
    }
}

private enum ScintillaFoldAction {
    static let contractAllLevels: CLong = 4
    static let expand: CLong = 1
}

private enum ScintillaFoldLevel {
    static let headerFlag: CLong = 0x2000
}

private enum ScintillaIndicatorStyle {
    static let straightBox: CLong = 0
    static let plain: CLong = 1      // plain underline
    static let box: CLong = 6
    static let roundBox: CLong = 7
    static let straightBoxWithColour: CLong = 8
    static let compositionThin: CLong = 14  // thin dotted underline
    static let fullBox: CLong = 16           // filled translucent box
}

private enum ScintillaKeyword {
    static let maximumSets = 30
}

private enum ScintillaMargin {
    static let lineNumber: CLong = 0
    static let bookmark: CLong = 1
    static let fold: CLong = 2
}

private enum ScintillaMarginType {
    static let symbol: CLong = 0
    static let number: CLong = 1
}

private enum ScintillaMarker {
    static let bookmark: CLong = 1
    static let bookmarkMask: CLong = 1 << bookmark
    static let folderEnd: CLong = 25
    static let folderOpenMid: CLong = 26
    static let folderMidTail: CLong = 27
    static let folderTail: CLong = 28
    static let folderSub: CLong = 29
    static let folder: CLong = 30
    static let folderOpen: CLong = 31
    static let folderMask: CLong = 0xFE000000
}

private enum ScintillaMarkerSymbol {
    static let circle: CLong = 0
    static let vLine: CLong = 9
    static let lCorner: CLong = 10
    static let tCorner: CLong = 11
    static let boxPlus: CLong = 12
    static let boxPlusConnected: CLong = 13
    static let boxMinus: CLong = 14
    static let boxMinusConnected: CLong = 15
}

private extension LanguageDefinition {
    /// Returns (scintillaKeywordSetIndex, keywords) pairs in ascending index order.
    /// For UDL languages (groups prefixed "udl_" or "udlkw"), the indices map to
    /// SCE_USER_KWLIST_* constants so SCLEX_USER receives keywords at the right slots.
    /// For standard languages, indices match the sequential position after priority sort,
    /// which is what Lexilla's lexers expect.
    var scintillaKeywordSets: [(index: Int, keywords: [String])] {
        if isUserDefinedLanguage {
            return keywordGroups
                .compactMap { name, words -> (Int, [String])? in
                    guard let idx = udlKeywordSetIndex(name), !words.isEmpty else { return nil }
                    return (idx, words)
                }
                .sorted { $0.0 < $1.0 }
        }
        return keywordGroups
            .sorted { keywordGroupPriority($0.key) < keywordGroupPriority($1.key) }
            .filter { !$1.isEmpty }
            .enumerated()
            .map { (index: $0.offset, keywords: $0.element.value) }
    }

    var isUserDefinedLanguage: Bool {
        keywordGroups.keys.contains { $0.hasPrefix("udlkw") || $0.hasPrefix("udl_") }
    }

    private func udlKeywordSetIndex(_ name: String) -> Int? {
        switch name {
        case "udl_comments":            return 0
        case "udl_num_prefix1":         return 1
        case "udl_num_prefix2":         return 2
        case "udl_num_extras1":         return 3
        case "udl_num_extras2":         return 4
        case "udl_num_suffix1":         return 5
        case "udl_num_suffix2":         return 6
        case "udl_num_range":           return 7
        case "udl_operators1":          return 8
        case "udl_operators2":          return 9
        case "udl_fold_code1_open":     return 10
        case "udl_fold_code1_middle":   return 11
        case "udl_fold_code1_close":    return 12
        case "udl_fold_code2_open":     return 13
        case "udl_fold_code2_middle":   return 14
        case "udl_fold_code2_close":    return 15
        case "udl_fold_comment_open":   return 16
        case "udl_fold_comment_middle": return 17
        case "udl_fold_comment_close":  return 18
        case "udl_delimiters":          return 27
        default: break
        }
        if name.hasPrefix("udlkw"), let n = Int(name.dropFirst(5)), (1...8).contains(n) {
            return 18 + n  // udlkw1→19 (SCE_USER_KWLIST_KEYWORDS1), …, udlkw8→26
        }
        return nil
    }

    func keywordGroupPriority(_ name: String) -> Int {
        if name == "instre1" { return 0 }
        if name == "instre2" { return 1 }
        if name.hasPrefix("type"), let number = Int(name.dropFirst("type".count)) {
            return 1 + number
        }
        if name.hasPrefix("substyle"), let number = Int(name.dropFirst("substyle".count)) {
            return 20 + number
        }
        return 100
    }
}
