import AppKit
import CLexillaBridge
import Darwin
import NotepadMacCore

@MainActor
enum EditorSurfaceNotificationKey {
    /// userInfo key on NSText.didChangeNotification posts: true when the text
    /// change came from the host's programmatic `text` setter (file load,
    /// reload, command-driven edits) rather than direct user editing.
    static let programmaticTextChange = "NotepadMacProgrammaticTextChange"
}

enum EditorMargin {
    case bookmark
    case fold
}

/// A line highlight instruction emitted by the file-compare window.
@MainActor
struct DiffLineHighlight {
    enum Kind {
        case added
        case removed
        case changed
        case pad
    }
    let line: Int      // 1-based line number
    let kind: Kind
    init(line: Int, kind: Kind) {
        self.line = line
        self.kind = kind
    }
}

@MainActor
struct EditorMarginClick {
    let margin: EditorMargin
    let line: Int
}

/// Caret/selection plus scroll anchor captured before view-option toggles that
/// can trigger Scintilla relayout (e.g. whitespace/EOL/NPC representations).
@MainActor
struct EditorViewPosition {
    var selectedRange: NSRange
    var firstVisibleLine: Int
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
    func clearLexer()
    var documentByteCount: Int { get }
    /// Caret line/column (1-based) computed natively when the surface can do
    /// so in O(1); nil means the host must derive it from the text.
    func caretLineAndColumn() -> (line: Int, column: Int)?
    func shouldHandleTextChangeNotification(_ notification: Notification) -> Bool
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

    // MARK: - Document sharing (cloned views)
    /// Scintilla document pointer for view cloning; nil on surfaces without
    /// document sharing support (NSTextView fallback).
    var documentPointer: Int? { get }
    /// Attaches this view to an existing Scintilla document (releases the
    /// view's current document, references the new one). Returns false on
    /// surfaces without document sharing support.
    @discardableResult
    func setDocumentPointer(_ pointer: Int) -> Bool
    /// Detaches from the shared document by creating a fresh empty document
    /// for this view, releasing the reference on the shared one.
    func detachFromSharedDocument()

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
    /// Whether smart-highlight indicators are currently applied (testing/observability).
    var hasSmartHighlightApplied: Bool { get }

    // MARK: - Insert/Overtype mode
    var isOvertype: Bool { get }

    // MARK: - NPC (Non-Printing Characters) display
    var supportsNpcDisplay: Bool { get }
    func applyNpcDisplay(_ show: Bool)
    func applyControlCharactersAndUnicodeEOLDisplay(_ show: Bool)

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
    func captureViewPosition() -> EditorViewPosition
    func restoreViewPosition(_ position: EditorViewPosition)
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

    // MARK: - File compare / diff rendering
    /// Configure this surface for use as a read-only compare pane: define the
    /// markers and indicator used to highlight added/removed/changed lines and
    /// inline character differences.
    func configureForDiff()
    /// Force a full repaint of the diff surface (works around macOS 26 layer
    /// backing keeping stale pixels after Scintilla grows its content view).
    func forceDiffRepaint()
    /// Apply a set of diff line highlights. Each entry tints a line background
    /// and (for non-pad lines) places a marker in the symbol margin.
    func applyDiffLineHighlights(_ highlights: [DiffLineHighlight])
    /// Clear all diff line highlights and markers.
    func clearDiffHighlights()
    /// Apply inline (character-level) indicator highlights for a single line.
    /// `ranges` are 0-based UTF-16 ranges within the given (1-based) line's text.
    func applyDiffInlineHighlights(line: Int, ranges: [NSRange], isInsert: Bool)
    /// Clear all inline diff indicators.
    func clearDiffInlineHighlights()
    /// Scroll so that the given 1-based line is visible near the top of the pane.
    func scrollDiffToLine(_ line: Int)
    /// The 1-based line currently at the top of the visible area.
    var firstVisibleDiffLine: Int { get }
    /// Force a repaint after the host view has received its final geometry.
    func refreshDisplayAfterLayout()

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

    static func makeDiff() -> EditorSurface {
        ScintillaEditorSurface.load() ?? TextViewEditorSurface()
    }
}

@MainActor
final class TextViewEditorSurface: EditorSurface {
    let scrollView: NSScrollView
    let textView: NSTextView
    private var fillsVisibleHeight = false

    var view: NSView { scrollView }
    var notificationObject: AnyObject { textView }
    var firstResponder: NSResponder { textView }
    var displayName: String { "NSTextView" }
    var supportsFolding: Bool { false }
    var supportsAdvancedViewOptions: Bool { false }
    var foldState: FoldState { FoldState() }

    var text: String {
        get { textView.string }
        set {
            textView.string = newValue
            applyBaseTextAttributes()
            sizeTextViewToScrollView()
        }
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

    var documentPointer: Int? { nil }

    func setDocumentPointer(_ pointer: Int) -> Bool { false }

    func detachFromSharedDocument() {}

    init() {
        let standardScrollView = NSTextView.scrollableTextView()
        self.scrollView = standardScrollView
        self.textView = standardScrollView.documentView as? NSTextView ?? NSTextView()
        if standardScrollView.documentView == nil {
            standardScrollView.documentView = textView
        }
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
        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: max(1, scrollView.contentSize.width),
            height: CGFloat.greatestFiniteMagnitude
        )
        scrollView.documentView = textView
        applyBaseTextAttributes()
        sizeTextViewToScrollView()
    }

    func applyFont(size: CGFloat) {
        textView.font = .monospacedSystemFont(ofSize: size, weight: .regular)
        applyBaseTextAttributes()
        sizeTextViewToScrollView()
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
        applyBaseTextAttributes()
        sizeTextViewToScrollView()
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

    func clearLexer() {}

    var documentByteCount: Int { textView.string.utf8.count }

    func caretLineAndColumn() -> (line: Int, column: Int)? { nil }

    func shouldHandleTextChangeNotification(_ notification: Notification) -> Bool { true }

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
    func applyControlCharactersAndUnicodeEOLDisplay(_ show: Bool) {}

    var supportsSmartHighlight: Bool { false }
    func applySmartHighlight(_ word: String, matchCase: Bool, wholeWord: Bool) {}
    func clearSmartHighlight() {}
    var hasSmartHighlightApplied: Bool { false }

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
    func captureViewPosition() -> EditorViewPosition {
        EditorViewPosition(
            selectedRange: textView.selectedRange(),
            firstVisibleLine: 0
        )
    }

    func restoreViewPosition(_ position: EditorViewPosition) {
        textView.setSelectedRange(position.selectedRange)
        textView.scrollRangeToVisible(position.selectedRange)
    }

    func scrollToSelection() {
        textView.scrollRangeToVisible(textView.selectedRange())
    }
    func configureForDiff() {
        fillsVisibleHeight = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = .textBackgroundColor
        applyBaseTextAttributes()
        sizeTextViewToScrollView()
    }

    func forceDiffRepaint() {
        textView.needsDisplay = true
        scrollView.needsDisplay = true
    }

    func applyDiffLineHighlights(_ highlights: [DiffLineHighlight]) {
        clearDiffHighlights()
        let nsText = textView.string as NSString
        for highlight in highlights {
            guard let range = utf16RangeForLine(highlight.line, in: nsText) else { continue }
            let color: NSColor
            switch highlight.kind {
            case .added:
                color = NSColor.systemGreen.withAlphaComponent(0.18)
            case .removed:
                color = NSColor.systemRed.withAlphaComponent(0.16)
            case .changed:
                color = NSColor.systemYellow.withAlphaComponent(0.28)
            case .pad:
                color = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
            }
            textView.textStorage?.addAttribute(.backgroundColor, value: color, range: range)
        }
    }

    func clearDiffHighlights() {
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
        applyBaseTextAttributes()
    }

    func applyDiffInlineHighlights(line: Int, ranges: [NSRange], isInsert: Bool) {
        guard line >= 1, !ranges.isEmpty else { return }
        let nsText = textView.string as NSString
        guard let lineRange = utf16RangeForLine(line, in: nsText) else { return }
        let color = (isInsert ? NSColor.systemGreen : NSColor.systemRed).withAlphaComponent(0.34)
        for range in ranges {
            let absolute = NSRange(location: lineRange.location + range.location, length: range.length)
            guard NSMaxRange(absolute) <= NSMaxRange(lineRange),
                  NSMaxRange(absolute) <= nsText.length
            else { continue }
            textView.textStorage?.addAttribute(.backgroundColor, value: color, range: absolute)
        }
    }

    func clearDiffInlineHighlights() {
        clearDiffHighlights()
    }

    func scrollDiffToLine(_ line: Int) {
        let nsText = textView.string as NSString
        guard let range = utf16RangeForLine(line, in: nsText) else { return }
        textView.scrollRangeToVisible(range)
    }

    var firstVisibleDiffLine: Int {
        guard let clipView = scrollView.contentView as NSClipView? else { return 1 }
        let visibleOrigin = clipView.bounds.origin
        let glyphIndex = textView.layoutManager?.glyphIndex(
            for: visibleOrigin,
            in: textView.textContainer ?? NSTextContainer()
        ) ?? 0
        let charIndex = textView.layoutManager?.characterIndexForGlyph(at: glyphIndex) ?? 0
        let prefix = (textView.string as NSString).substring(with: NSRange(location: 0, length: min(charIndex, (textView.string as NSString).length)))
        return prefix.components(separatedBy: .newlines).count
    }

    func refreshDisplayAfterLayout() {
        sizeTextViewToScrollView()
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
        textView.needsDisplay = true
        textView.displayIfNeeded()
        scrollView.needsDisplay = true
        scrollView.displayIfNeeded()
    }
    func teardown() {}

    private func applyBaseTextAttributes() {
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard fullRange.length > 0 else { return }
        textView.textStorage?.addAttributes([
            .font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.textColor,
        ], range: fullRange)
    }

    private func sizeTextViewToScrollView() {
        let contentWidth = max(1, scrollView.contentSize.width)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        let usedHeight: CGFloat
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            usedHeight = layoutManager.usedRect(for: textContainer).height
        } else {
            usedHeight = 0
        }
        let insetHeight = textView.textContainerInset.height * 2
        var contentHeight = max(scrollView.contentSize.height, usedHeight + insetHeight)
        if fillsVisibleHeight {
            contentHeight = max(contentHeight, scrollView.contentView.bounds.height)
        }
        textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
    }

    private func utf16RangeForLine(_ oneBasedLine: Int, in text: NSString) -> NSRange? {
        guard oneBasedLine >= 1 else { return nil }
        var currentLine = 1
        var lineStart = 0
        var index = 0
        while index < text.length {
            if currentLine == oneBasedLine {
                var lineEnd = index
                while lineEnd < text.length {
                    let ch = text.character(at: lineEnd)
                    if ch == 10 || ch == 13 { break }
                    lineEnd += 1
                }
                return NSRange(location: lineStart, length: lineEnd - lineStart)
            }
            let ch = text.character(at: index)
            if ch == 10 || ch == 13 {
                if ch == 13, index + 1 < text.length, text.character(at: index + 1) == 10 {
                    index += 1
                }
                currentLine += 1
                lineStart = index + 1
            }
            index += 1
        }
        if currentLine == oneBasedLine {
            return NSRange(location: lineStart, length: text.length - lineStart)
        }
        return nil
    }
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

    /// True while the host is replacing the buffer through the `text` setter.
    /// Scintilla's SCN_MODIFIED callback runs synchronously inside the set, so
    /// the deferred NSText.didChange post can carry this as metadata.
    private var isProgrammaticTextSet = false

    /// Cached full-document copy. Reading the buffer out of Scintilla and
    /// decoding it is O(document); selection/scroll handlers ask for `text`
    /// several times per event, so reuse one copy until SCN_MODIFIED
    /// invalidates it. Only safe once the notification delegate is wired up.
    private var cachedDocumentText: String?

    var text: String {
        get {
            documentText()
        }
        set {
            isProgrammaticTextSet = true
            defer { isProgrammaticTextSet = false }
            replaceDocumentText(newValue)
        }
    }

    var selectedRange: NSRange {
        bridge.selectedRange()
    }

    private func documentText() -> String {
        if let cachedDocumentText, didConfigureNotificationDelegate {
            return cachedDocumentText
        }
        let length = Int(bridge.getGeneralProperty(ScintillaMessage.getLength, parameter: 0) ?? 0)
        guard length > 0 else { return "" }

        let bufferSize = length + 1
        var bytes = [UInt8](repeating: 0, count: bufferSize)
        bytes.withUnsafeMutableBytes { rawBuffer in
            bridge.setReferenceProperty(
                ScintillaMessage.getText,
                parameter: CLong(bufferSize),
                value: UnsafeRawPointer(rawBuffer.baseAddress)
            )
        }
        let result = String(decoding: bytes.prefix(length), as: UTF8.self)
        if didConfigureNotificationDelegate {
            cachedDocumentText = result
        }
        return result
    }

    private func replaceDocumentText(_ newValue: String) {
        let wasReadOnly = isReadOnly
        if wasReadOnly {
            isReadOnly = false
        }
        defer {
            if wasReadOnly {
                isReadOnly = true
            }
        }

        bridge.setGeneralProperty(ScintillaMessage.setUndoCollection, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.clearAll, parameter: 0, value: 0)

        let bytes = Array(newValue.utf8)
        if !bytes.isEmpty {
            bridge.setGeneralProperty(ScintillaMessage.allocate, parameter: CLong(bytes.count), value: 0)
            bytes.withUnsafeBytes { rawBuffer in
                bridge.setReferenceProperty(
                    ScintillaMessage.appendText,
                    parameter: CLong(bytes.count),
                    value: rawBuffer.baseAddress
                )
            }
        }

        bridge.setGeneralProperty(ScintillaMessage.setUndoCollection, parameter: 1, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.emptyUndoBuffer, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setSavePoint, parameter: 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.gotoPos, parameter: 0, value: 0)
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

    deinit {
        MainActor.assumeIsolated {
            _ = bridge.setDelegate(nil)
        }
    }

    func teardown() {
        _ = bridge.setDelegate(nil)
    }

    func shouldHandleTextChangeNotification(_ notification: Notification) -> Bool {
        notification.userInfo?[EditorSurfaceNotificationKey.programmaticTextChange] != nil
    }

    private static func dbgWrite(_ s: String) {
        let path = "/tmp/notepad_debug.txt"
        if let f = fopen(path, "a") {
            fputs(s + "\n", f)
            fclose(f)
        }
    }

    static func load() -> ScintillaEditorSurface? {
        dbgWrite("[load] starting ScintillaEditorSurface.load()")
        for frameworkURL in frameworkCandidates() {
            dbgWrite("[load] trying \(frameworkURL.path) exists=\(FileManager.default.fileExists(atPath: frameworkURL.path))")
            guard FileManager.default.fileExists(atPath: frameworkURL.path),
                  let bundle = Bundle(url: frameworkURL),
                  bundle.load()
            else {
                dbgWrite("[load] skipping \(frameworkURL.lastPathComponent)")
                continue
            }

            for className in ["ScintillaView", "Scintilla.ScintillaView"] {
                guard let viewClass = NSClassFromString(className) as? NSView.Type else { continue }
                return ScintillaEditorSurface(scintillaView: viewClass.init(frame: .zero))
            }
        }

        return nil
    }

    var documentPointer: Int? {
        guard let pointer = bridge.getGeneralProperty(ScintillaMessage.getDocPointer, parameter: 0),
              pointer != 0
        else { return nil }
        return pointer
    }

    @discardableResult
    func setDocumentPointer(_ pointer: Int) -> Bool {
        // SCI_SETDOCPOINTER releases the view's current document and takes a
        // reference on the supplied one (lParam carries the pointer).
        bridge.setGeneralProperty(ScintillaMessage.setDocPointer, parameter: 0, value: CLong(pointer))
        return bridge.getGeneralProperty(ScintillaMessage.getDocPointer, parameter: 0) == CLong(pointer)
    }

    func detachFromSharedDocument() {
        // SCI_SETDOCPOINTER with NULL creates a fresh empty document and
        // releases the reference on the previously attached document.
        bridge.setGeneralProperty(ScintillaMessage.setDocPointer, parameter: 0, value: 0)
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
        // Scintilla defaults scrollWidth to 2000px, so a brand-new/empty document
        // shows a horizontal scrollbar on any window narrower than ~2000px. Override
        // to 1px (matching upstream ScintillaEditView.cpp); tracking grows it to fit
        // the longest line so the bar only appears when content actually overflows.
        bridge.setGeneralProperty(ScintillaMessage.setScrollWidth, parameter: 1, value: 0)
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
        let define = ScintillaMessage.markerDefine
        for marker in ScintillaFoldMarginMarkerStyle.symbols(forRawValue: style) {
            bridge.setGeneralProperty(define, parameter: marker.markerNumber, value: marker.symbol)
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
            parameter: CLong(StyleColor(red: 232, green: 232, blue: 255).scintillaColor),
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

    /// Line-number margin width, mirroring upstream ScintillaEditView::
    /// updateLineNumberWidth (non-dynamic mode): pixel width is measured from
    /// the actual line-number font via SCI_TEXTWIDTH rather than a hardcoded
    /// per-digit constant, and reserves at least 4 digits so the margin
    /// doesn't visibly grow on the first edits of a fresh document.
    private func lineNumberMarginWidth() -> Int {
        let lineCount = bridge.getGeneralProperty(ScintillaMessage.getLineCount, parameter: 0) ?? 1
        var digits = String(lineCount).count
        if digits < 4 { digits = 4 }
        let digitBytes = Array("8".utf8)
        let digitWidth = digitBytes.withUnsafeBytes { rawBuffer -> CLong in
            bridge.message(
                ScintillaMessage.textWidth,
                wParam: CLong(33), // STYLE_LINENUMBER
                lParam: rawBuffer.baseAddress
            ) ?? 8
        }
        return 8 + digits * Int(digitWidth)
    }

    func applyLineNumberMargin(_ visible: Bool) {
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginWidth,
            parameter: ScintillaMargin.lineNumber,
            value: visible ? CLong(lineNumberMarginWidth()) : 0
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
        bridge.setGeneralProperty(ScintillaMessage.styleClearAll, parameter: 0, value: 0)

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
            configureLexillaProperties(for: language)
            // Force initial colorization so the fold margin reflects the new
            // lexer immediately. configureAutomaticFold only enables SHOW|CLICK
            // (never CHANGE), so colorize cannot auto-collapse the document.
            bridge.setGeneralProperty(ScintillaMessage.colourise, parameter: 0, value: -1)
            configureAutomaticFold()
        } else {
            bridge.setReferenceProperty(ScintillaMessage.setILexer, parameter: 0, value: nil)
        }

        for (scintillaIndex, keywords) in language.scintillaKeywordSets where scintillaIndex < ScintillaKeywordSet.maximumSets {
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
    }

    func clearLexer() {
        bridge.setReferenceProperty(ScintillaMessage.setILexer, parameter: 0, value: nil)
        bridge.setGeneralProperty(ScintillaMessage.styleClearAll, parameter: 0, value: 0)
    }

    var documentByteCount: Int {
        Int(bridge.getGeneralProperty(ScintillaMessage.getLength, parameter: 0) ?? 0)
    }

    func caretLineAndColumn() -> (line: Int, column: Int)? {
        guard let pos = bridge.getGeneralProperty(ScintillaMessage.getCurrentPos, parameter: 0),
              let line = bridge.getGeneralProperty(ScintillaMessage.lineFromPosition, parameter: pos),
              let column = bridge.getGeneralProperty(ScintillaMessage.getColumn, parameter: pos)
        else { return nil }
        return (Int(line) + 1, Int(column) + 1)
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
            parameter: ScintillaFoldAction.expandAllLevels,
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
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(documentByteCount))
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

    // MARK: - File compare / diff rendering

    /// Diff line markers reuse Scintilla marker numbers 2-5 (bookmark=1,
    /// fold margins=25-31). Indicators 6 (insert) and 7 (delete) are used for
    /// inline character-level highlights; both well clear of the search-mark
    /// indicators (1-5) and platform indicators.
    private enum DiffMarker {
        static let added: CLong = 2
        static let removed: CLong = 3
        static let changed: CLong = 4
        static let mask: CLong = (1 << added) | (1 << removed) | (1 << changed)
    }
    private enum DiffIndicator {
        static let insert: CLong = 6
        static let delete: CLong = 7
    }

    func configureForDiff() {
        isReadOnly = true
        isDiffMode = true

        // DIAGNOSTIC: disable buffered draw (intermediate bitmap may not be
        // colour-matched to the display, darkening white from 255 to ~234).
        bridge.setGeneralProperty(2035, parameter: 0, value: 0)

        bridge.setReferenceProperty(ScintillaMessage.setILexer, parameter: 0, value: nil)

        let catalog = StyleCatalog.loadDefault()
        let prefs = StylePreferences()
        bridge.setGeneralProperty(ScintillaMessage.styleClearAll, parameter: 0, value: 0)
        applyDefaultLexerStyles(styleCatalog: catalog, stylePreferences: prefs)
        applyGlobalStyles(styleCatalog: catalog, stylePreferences: prefs)

        bridge.setGeneralProperty(
            ScintillaMessage.setMarginType,
            parameter: ScintillaMargin.lineNumber,
            value: ScintillaMarginType.number
        )
        bridge.setGeneralProperty(ScintillaMessage.setMarginWidth, parameter: ScintillaMargin.bookmark, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setMarginWidth, parameter: ScintillaMargin.fold, value: 0)
        applyLineNumberMargin(true)
        applyDiffScrollAppearance()

        // Give the diff pane a dedicated symbol margin (margin #3, clear of the
        // line-number/bookmark/fold margins 0/1/2) so line markers show.
        let diffMargin: CLong = 3
        bridge.setGeneralProperty(ScintillaMessage.setMarginType,
                                  parameter: diffMargin, value: ScintillaMarginType.symbol)
        bridge.setGeneralProperty(ScintillaMessage.setMarginWidth,
                                  parameter: diffMargin, value: 14)
        bridge.setGeneralProperty(ScintillaMessage.setMarginMask,
                                  parameter: diffMargin, value: DiffMarker.mask)
        bridge.setGeneralProperty(ScintillaMessage.setMarginSensitive,
                                  parameter: diffMargin, value: 0)

        // Marker definitions: background-tinting markers (SC_MARK_BACKGROUND)
        // colour the whole line, plus a small symbol drawn in the margin.
        let defs: [(marker: CLong, symbol: CLong, r: Int, g: Int, b: Int)] = [
            // Added: green tint
            (DiffMarker.added, ScintillaMarkerSymbol.arrowDown, 200, 255, 200),
            // Removed: red/pink tint
            (DiffMarker.removed, ScintillaMarkerSymbol.circle, 255, 210, 210),
            // Changed: yellow tint
            (DiffMarker.changed, ScintillaMarkerSymbol.arrow, 255, 240, 190),
        ]
        for d in defs {
            bridge.setGeneralProperty(ScintillaMessage.markerDefine,
                                      parameter: d.marker, value: ScintillaMarkerSymbol.background)
            let rgb = CLong(d.b) | (CLong(d.g) << 8) | (CLong(d.r) << 16)
            bridge.setGeneralProperty(ScintillaMessage.markerSetBack,
                                      parameter: d.marker, value: rgb)
            // Alpha for the background tint (0-255).
            bridge.setGeneralProperty(ScintillaMessage.markerSetAlpha,
                                      parameter: d.marker, value: 70)
        }

        // Inline indicators: subtle underline-style highlights for the changed
        // characters within a modified line.
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle,
                                  parameter: DiffIndicator.insert,
                                  value: ScintillaIndicatorStyle.roundBox)
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore,
                                  parameter: DiffIndicator.insert,
                                  value: CLong(0x70) | (CLong(0xB0) << 8) | (CLong(0x70) << 16))  // green
        bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha,
                                  parameter: DiffIndicator.insert, value: 90)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder,
                                  parameter: DiffIndicator.insert, value: 1)
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle,
                                  parameter: DiffIndicator.delete,
                                  value: ScintillaIndicatorStyle.roundBox)
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore,
                                  parameter: DiffIndicator.delete,
                                  value: CLong(0xB0) | (CLong(0x70) << 8) | (CLong(0x70) << 16))  // red
        bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha,
                                  parameter: DiffIndicator.delete, value: 90)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder,
                                  parameter: DiffIndicator.delete, value: 1)

        recolourDocument()
        invalidateEntireSurface()

        // Scintilla caches a drawing copy (vsDraw) of the styles and skips
        // rebuilding it when STYLE_DEFAULT is re-set to its *current* value, so the
        // cached background can stay stale grey (which is what paints the area
        // below the last line) even though the model style already reports the
        // editor background. Force an actual change — sentinel then editor white —
        // so Scintilla refreshes the drawing copy and repaints white.
        let editorBackground: CLong = 0xFF_FFFF
        bridge.setGeneralProperty(ScintillaMessage.styleSetBack, parameter: 32, value: 0x00_0001)
        bridge.setGeneralProperty(ScintillaMessage.styleSetBack, parameter: 32, value: editorBackground)
        recolourDocument()
        invalidateEntireSurface()
    }

    private var isDiffMode = false

    /// Force the whole Scintilla surface to repaint. macOS 26 layer-backed views
    /// keep stale backing for regions exposed by a *programmatic* frame growth
    /// (Scintilla enlarges its content view from one line to the full viewport
    /// after the diff window settles), leaving grey below the text. Marking the
    /// content/margin/host views dirty over their full bounds forces drawRect to
    /// repaint the exposed area with STYLE_DEFAULT white.
    func forceDiffRepaint() {
        guard isDiffMode else { return }
        applyDiffScrollAppearance()
        let scroll = scintillaView.subviews.compactMap { $0 as? NSScrollView }.first
        let candidates: [NSView?] = [
            scintillaContentView(),
            scroll?.contentView,
            scroll?.verticalRulerView,
            scroll,
            scintillaView,
        ]
        for view in candidates.compactMap({ $0 }) {
            view.layer?.setNeedsDisplay()
            view.setNeedsDisplay(view.bounds)
            view.display()
        }

        if ProcessInfo.processInfo.arguments.contains("--smoke-diff") {
            let content = scintillaContentView()
            let styleBack = bridge.getGeneralProperty(2482, parameter: 32) ?? -1
            let msg = "forceDiffRepaint STYLE_DEFAULT.back=\(String(styleBack, radix: 16)) contentFound=\(content != nil) contentFrame=\(content?.frame ?? .zero) scintillaFrame=\(scintillaView.frame)\n"
            if let f = fopen("/tmp/diff_repaint.txt", "a") { fputs(msg, f); fclose(f) }
        }
    }

    private func applyDiffScrollAppearance() {
        for scroll in scintillaView.subviews.compactMap({ $0 as? NSScrollView }) {
            scroll.drawsBackground = true
            scroll.backgroundColor = .textBackgroundColor
            scroll.contentView.drawsBackground = true
            scroll.contentView.backgroundColor = .textBackgroundColor
            scroll.verticalRulerView?.needsDisplay = true
        }
    }

    private func scintillaContentView() -> NSView? {
        let selector = NSSelectorFromString("content")
        guard scintillaView.responds(to: selector),
              let method = scintillaView.method(for: selector)
        else {
            return scintillaView.subviews.compactMap { $0 as? NSScrollView }.first?.contentView
        }
        typealias Function = @convention(c) (AnyObject, Selector) -> Unmanaged<NSView>
        let function = unsafeBitCast(method, to: Function.self)
        return function(scintillaView, selector).takeUnretainedValue()
    }

    private func invalidateEntireSurface() {
        applyDiffScrollAppearance()
        let views = [
            scintillaContentView(),
            scintillaView.subviews.compactMap { $0 as? NSScrollView }.first?.verticalRulerView,
            scintillaView,
        ].compactMap { $0 }
        for view in views {
            view.setNeedsDisplay(view.bounds)
            view.displayIfNeeded()
        }
    }

    private func scintillaColor(from color: NSColor) -> CLong {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return CLong(Int(red * 255)) | (CLong(Int(green * 255)) << 8) | (CLong(Int(blue * 255)) << 16)
    }

    private func recolourDocument() {
        let length = bridge.getGeneralProperty(ScintillaMessage.getLength, parameter: 0) ?? 0
        if length > 0 {
            bridge.setGeneralProperty(ScintillaMessage.colourise, parameter: 0, value: length)
        }
    }

    func applyDiffLineHighlights(_ highlights: [DiffLineHighlight]) {
        clearDiffHighlights()
        for h in highlights {
            guard h.line >= 1 else { continue }
            let zeroBased = CLong(h.line - 1)
            let marker: CLong
            switch h.kind {
            case .added: marker = DiffMarker.added
            case .removed: marker = DiffMarker.removed
            case .changed: marker = DiffMarker.changed
            case .pad: continue  // pad lines get no marker
            }
            bridge.setGeneralProperty(ScintillaMessage.markerAdd,
                                      parameter: zeroBased, value: marker)
        }
        invalidateEntireSurface()
    }

    func clearDiffHighlights() {
        bridge.setGeneralProperty(ScintillaMessage.markerDeleteAll,
                                  parameter: DiffMarker.added, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.markerDeleteAll,
                                  parameter: DiffMarker.removed, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.markerDeleteAll,
                                  parameter: DiffMarker.changed, value: 0)
    }

    func applyDiffInlineHighlights(line: Int, ranges: [NSRange], isInsert: Bool) {
        guard line >= 1, !ranges.isEmpty else { return }
        let indicator = isInsert ? DiffIndicator.insert : DiffIndicator.delete
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent,
                                  parameter: indicator, value: 0)
        let currentText = text
        for range in ranges {
            // Convert the line-local UTF-16 offset to an absolute document offset.
            let lineStartUTF16 = absoluteUTF16Start(ofLine: line, in: currentText)
            let absLocation = lineStartUTF16 + range.location
            let absEnd = lineStartUTF16 + NSMaxRange(range)
            guard let sciStart = scintillaPosition(in: currentText, utf16Location: absLocation),
                  let sciEnd = scintillaPosition(in: currentText, utf16Location: absEnd),
                  sciEnd > sciStart
            else { continue }
            bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange,
                                      parameter: sciStart, value: sciEnd - sciStart)
        }
        invalidateEntireSurface()
    }

    func clearDiffInlineHighlights() {
        let total = CLong(documentByteCount)
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent,
                                  parameter: DiffIndicator.insert, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange,
                                  parameter: 0, value: total)
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent,
                                  parameter: DiffIndicator.delete, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange,
                                  parameter: 0, value: total)
    }

    func scrollDiffToLine(_ line: Int) {
        guard line >= 1 else { return }
        // SCI_SCROLLRANGE keeps the given range visible; scrolling so that the
        // target line sits near the top gives stable navigation between hunks.
        let zeroBased = CLong(line - 1)
        let lineStart = bridge.getGeneralProperty(ScintillaMessage.positionFromLine,
                                                  parameter: zeroBased) ?? 0
        // Use SCI_GOTOPOS via setGeneralProperty then ensure visible.
        bridge.setGeneralProperty(ScintillaMessage.gotoPos, parameter: lineStart, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.scrollRange,
                                  parameter: lineStart, value: lineStart)
    }

    var firstVisibleDiffLine: Int {
        let sciPos = bridge.getGeneralProperty(ScintillaMessage.getFirstVisibleLine, parameter: 0) ?? 0
        return Int(sciPos) + 1  // Scintilla reports a 0-based line
    }

    func refreshDisplayAfterLayout() {
        if isDiffMode {
            applyLineNumberMargin(true)
            applyDiffScrollAppearance()
        }
        recolourDocument()
        invalidateEntireSurface()
    }

    /// UTF-16 location of the start of a 1-based line in the whole document.
    private func absoluteUTF16Start(ofLine line: Int, in fullText: String) -> Int {
        guard line > 1 else { return 0 }
        var current = 1
        var utf16Index = 0
        for char in fullText {
            if current == line { return utf16Index }
            utf16Index += char.utf16.count
            if char == "\n" {
                current += 1
            }
        }
        return utf16Index
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
        let npcEntries: [(encodedCharacter: String, representation: String)] = [
            ("\u{00A0}", "NBSP"), ("\u{00AD}", "SHY"), ("\u{061C}", "ALM"),
            ("\u{070F}", "SAM"), ("\u{1680}", "OSPM"), ("\u{180E}", "MVS"),
            ("\u{2000}", "NQSP"), ("\u{2001}", "MQSP"), ("\u{2002}", "ENSP"),
            ("\u{2003}", "EMSP"), ("\u{2004}", "3/MSP"), ("\u{2005}", "4/MSP"),
            ("\u{2006}", "6/MSP"), ("\u{2007}", "FSP"), ("\u{2008}", "PSP"),
            ("\u{2009}", "THSP"), ("\u{200A}", "HSP"), ("\u{200B}", "ZWSP"),
            ("\u{200C}", "ZWNJ"), ("\u{200D}", "ZWJ"), ("\u{200E}", "LRM"),
            ("\u{200F}", "RLM"), ("\u{202A}", "LRE"), ("\u{202B}", "RLE"),
            ("\u{202C}", "PDF"), ("\u{202D}", "LRO"), ("\u{202E}", "RLO"),
            ("\u{202F}", "NNBSP"), ("\u{205F}", "MMSP"), ("\u{2060}", "WJ"),
            ("\u{2061}", "(FA)"), ("\u{2062}", "(IT)"), ("\u{2063}", "(IS)"),
            ("\u{2064}", "(IP)"), ("\u{2066}", "LRI"), ("\u{2067}", "RLI"),
            ("\u{2068}", "FSI"), ("\u{2069}", "PDI"), ("\u{206A}", "ISS"),
            ("\u{206B}", "ASS"), ("\u{206C}", "IAFS"), ("\u{206D}", "AAFS"),
            ("\u{206E}", "NADS"), ("\u{206F}", "NODS"), ("\u{3000}", "IDSP"),
            ("\u{FEFF}", "ZWNBSP"), ("\u{FFF9}", "IAA"), ("\u{FFFA}", "IAS"),
            ("\u{FFFB}", "IAT")
        ]
        applyRepresentations(npcEntries, show: show)
    }

    func applyControlCharactersAndUnicodeEOLDisplay(_ show: Bool) {
        let controlEntries: [(encodedCharacter: String, representation: String)] = [
            ("\u{0000}", "NUL"), ("\u{0001}", "SOH"), ("\u{0002}", "STX"),
            ("\u{0003}", "ETX"), ("\u{0004}", "EOT"), ("\u{0005}", "ENQ"),
            ("\u{0006}", "ACK"), ("\u{0007}", "BEL"), ("\u{0008}", "BS"),
            ("\u{000B}", "VT"), ("\u{000C}", "FF"), ("\u{000E}", "SO"),
            ("\u{000F}", "SI"), ("\u{0010}", "DLE"), ("\u{0011}", "DC1"),
            ("\u{0012}", "DC2"), ("\u{0013}", "DC3"), ("\u{0014}", "DC4"),
            ("\u{0015}", "NAK"), ("\u{0016}", "SYN"), ("\u{0017}", "ETB"),
            ("\u{0018}", "CAN"), ("\u{0019}", "EM"), ("\u{001A}", "SUB"),
            ("\u{001B}", "ESC"), ("\u{001C}", "FS"), ("\u{001D}", "GS"),
            ("\u{001E}", "RS"), ("\u{001F}", "US"), ("\u{007F}", "DEL"),
            ("\u{0080}", "PAD"), ("\u{0081}", "HOP"), ("\u{0082}", "BPH"),
            ("\u{0083}", "NBH"), ("\u{0084}", "IND"), ("\u{0086}", "SSA"),
            ("\u{0087}", "ESA"), ("\u{0088}", "HTS"), ("\u{0089}", "HTJ"),
            ("\u{008A}", "VTS"), ("\u{008B}", "PLD"), ("\u{008C}", "PLU"),
            ("\u{008D}", "RI"), ("\u{008E}", "SS2"), ("\u{008F}", "SS3"),
            ("\u{0090}", "DCS"), ("\u{0091}", "PU1"), ("\u{0092}", "PU2"),
            ("\u{0093}", "STS"), ("\u{0094}", "CCH"), ("\u{0095}", "MW"),
            ("\u{0096}", "SPA"), ("\u{0097}", "EPA"), ("\u{0098}", "SOS"),
            ("\u{0099}", "SGCI"), ("\u{009A}", "SCI"), ("\u{009B}", "CSI"),
            ("\u{009C}", "ST"), ("\u{009D}", "OSC"), ("\u{009E}", "PM"),
            ("\u{009F}", "APC"), ("\u{0085}", "NEL"), ("\u{2028}", "LS"),
            ("\u{2029}", "PS")
        ]
        applyRepresentations(controlEntries, show: show, hiddenRepresentation: "\u{200B}")
    }

    private func applyRepresentations(
        _ entries: [(encodedCharacter: String, representation: String)],
        show: Bool,
        hiddenRepresentation: String? = nil
    ) {
        for entry in entries {
            entry.encodedCharacter.withCString { charPtr in
                let parameter = CLong(bitPattern: UInt(bitPattern: charPtr))
                if show {
                    setRepresentation(entry.representation, for: parameter)
                } else if let hiddenRepresentation {
                    setRepresentation(hiddenRepresentation, for: parameter)
                } else {
                    bridge.setReferenceProperty(
                        ScintillaMessage.clearRepresentation,
                        parameter: parameter,
                        value: nil
                    )
                }
            }
        }
    }

    private func setRepresentation(_ representation: String, for parameter: CLong) {
        representation.withCString { reprPtr in
            bridge.setReferenceProperty(
                ScintillaMessage.setRepresentation,
                parameter: parameter,
                value: UnsafeRawPointer(reprPtr)
            )
        }
    }

    // MARK: - Smart highlighting

    private static let smartHighlightIndicator: CLong = 10 // INDICATOR_CONTAINER + custom

    /// Last applied smart-highlight request; repeated identical requests
    /// (selection drags fire several SCIUpdateUI events per gesture) must be
    /// no-ops, otherwise the clear-and-repaint cycle makes the visible lines
    /// flicker.
    private var appliedSmartHighlight: (word: String, matchCase: Bool, wholeWord: Bool, start: CLong, end: CLong)?

    var supportsSmartHighlight: Bool { true }

    var hasSmartHighlightApplied: Bool { appliedSmartHighlight != nil }

    func applySmartHighlight(_ word: String, matchCase: Bool, wholeWord: Bool) {
        guard !word.isEmpty else {
            clearSmartHighlight()
            return
        }

        // Configure the indicator style
        let indicator = Self.smartHighlightIndicator
        bridge.setGeneralProperty(ScintillaMessage.indicSetStyle, parameter: indicator, value: ScintillaIndicatorStyle.roundBox)
        // Upstream "Smart HighLighting" style: a saturated, near-solid
        // green block (RGB 0,255,0). Scintilla colors are 0xBBGGRR.
        let green: CLong = 255 << 8
        bridge.setGeneralProperty(ScintillaMessage.indicSetFore, parameter: indicator, value: green)
        bridge.setGeneralProperty(ScintillaMessage.indicSetAlpha, parameter: indicator, value: 230)
        bridge.setGeneralProperty(ScintillaMessage.indicSetOutlineAlpha, parameter: indicator, value: 255)
        bridge.setGeneralProperty(ScintillaMessage.indicSetUnder, parameter: indicator, value: 1)

        // Mark occurrences in the visible lines only (upstream SmartHighlighter
        // behavior) using Scintilla's native target search, so the cost stays
        // O(visible area) regardless of document size.
        let firstVisible = bridge.getGeneralProperty(ScintillaMessage.getFirstVisibleLine, parameter: 0) ?? 0
        let linesOnScreen = bridge.getGeneralProperty(ScintillaMessage.linesOnScreen, parameter: 0) ?? 0
        let firstLine = bridge.getGeneralProperty(ScintillaMessage.docLineFromVisible, parameter: firstVisible) ?? 0
        let lastLine = bridge.getGeneralProperty(ScintillaMessage.docLineFromVisible, parameter: firstVisible + linesOnScreen) ?? 0
        let rangeStart = bridge.getGeneralProperty(ScintillaMessage.positionFromLine, parameter: firstLine) ?? 0
        let rangeEnd = bridge.getGeneralProperty(ScintillaMessage.getLineEndPosition, parameter: lastLine)
            ?? CLong(documentByteCount)

        if let applied = appliedSmartHighlight,
           applied.word == word, applied.matchCase == matchCase, applied.wholeWord == wholeWord,
           applied.start == rangeStart, applied.end == rangeEnd {
            return
        }
        // Clear only what the previous application painted; clearing the
        // whole document would force a repaint of every visible line.
        if let applied = appliedSmartHighlight {
            bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
            bridge.setGeneralProperty(
                ScintillaMessage.indicatorClearRange,
                parameter: applied.start,
                value: applied.end - applied.start
            )
        } else {
            clearSmartHighlight()
        }
        appliedSmartHighlight = (word, matchCase, wholeWord, rangeStart, rangeEnd)

        bridge.setGeneralProperty(
            ScintillaMessage.setSearchFlags,
            parameter: buildSearchFlags(matchCase: matchCase, wholeWord: wholeWord),
            value: 0
        )
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)

        let wordBytes = Array(word.utf8)
        var searchStart = rangeStart
        while searchStart < rangeEnd {
            bridge.setGeneralProperty(ScintillaMessage.setTargetStart, parameter: searchStart, value: 0)
            bridge.setGeneralProperty(ScintillaMessage.setTargetEnd, parameter: rangeEnd, value: 0)
            let found = wordBytes.withUnsafeBytes { rawBuffer in
                bridge.message(
                    ScintillaMessage.searchInTarget,
                    wParam: CLong(wordBytes.count),
                    lParam: rawBuffer.baseAddress
                )
            }
            guard let found, found >= 0,
                  let matchStart = bridge.getGeneralProperty(ScintillaMessage.getTargetStart, parameter: 0),
                  let matchEnd = bridge.getGeneralProperty(ScintillaMessage.getTargetEnd, parameter: 0),
                  matchEnd > matchStart
            else { break }
            bridge.setGeneralProperty(ScintillaMessage.indicatorFillRange, parameter: matchStart, value: matchEnd - matchStart)
            searchStart = matchEnd
        }
    }

    func clearSmartHighlight() {
        appliedSmartHighlight = nil
        let indicator = Self.smartHighlightIndicator
        bridge.setGeneralProperty(ScintillaMessage.setIndicatorCurrent, parameter: indicator, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(documentByteCount))
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
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(documentByteCount))
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
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(documentByteCount))
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
        bridge.setGeneralProperty(ScintillaMessage.indicatorClearRange, parameter: 0, value: CLong(documentByteCount))
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
        // Fast path: callers almost always pass the selection start, whose
        // byte position Scintilla can report directly — avoids an O(document)
        // UTF-16 → UTF-8 conversion on every caret move.
        let sciPos: CLong
        if location == bridge.selectedRange().location,
           let selectionStart = bridge.getGeneralProperty(ScintillaMessage.getSelectionStart, parameter: 0) {
            sciPos = selectionStart
        } else if let converted = scintillaPosition(in: text, utf16Location: location) {
            sciPos = converted
        } else {
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
        // Live multi-caret editing: typing applies to every active selection,
        // and an Alt(Option)+drag selection switches to rectangular mode,
        // matching upstream Notepad++'s column-mode editing behavior.
        bridge.setGeneralProperty(ScintillaMessage.setAdditionalSelectionTyping, parameter: on ? 1 : 0, value: 0)
        bridge.setGeneralProperty(ScintillaMessage.setMouseSelectionRectangularSwitch, parameter: on ? 1 : 0, value: 0)
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

    func captureViewPosition() -> EditorViewPosition {
        EditorViewPosition(
            selectedRange: selectedRange,
            firstVisibleLine: Int(bridge.getGeneralProperty(ScintillaMessage.getFirstVisibleLine, parameter: 0) ?? 0)
        )
    }

    func restoreViewPosition(_ position: EditorViewPosition) {
        guard let scintillaRange = scintillaPositionRange(in: text, forUTF16Range: position.selectedRange) else {
            return
        }
        bridge.setGeneralProperty(
            ScintillaMessage.setSelection,
            parameter: scintillaRange.caret,
            value: scintillaRange.anchor
        )
        bridge.setGeneralProperty(
            ScintillaMessage.setFirstVisibleLine,
            parameter: CLong(position.firstVisibleLine),
            value: 0
        )
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
        cachedDocumentText = nil
        // Positions shift with the edit; force the next smart-highlight
        // application to repaint instead of being deduplicated away.
        appliedSmartHighlight = nil
        // Defer to next run-loop iteration to avoid re-entering Swift Observation tracking
        // while Scintilla is in the middle of a drawRect/paint cycle (macOS 26+ SIGSEGV fix).
        // Capture whether this modification came from the host's `text` setter
        // synchronously, BEFORE deferring: the deferred post otherwise arrives
        // after callers reset their dirty state (e.g. file load), and the
        // observer would wrongly mark freshly loaded documents as modified.
        let programmatic = isProgrammaticTextSet
        let view = scintillaView
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSText.didChangeNotification,
                object: view,
                userInfo: [EditorSurfaceNotificationKey.programmaticTextChange: programmatic]
            )
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
        // Use the same width calculation as applyLineNumberMargin so the
        // initial value matches what later edits compute, avoiding a visible
        // jump on the first keystroke.
        bridge.setGeneralProperty(
            ScintillaMessage.setMarginWidth,
            parameter: ScintillaMargin.lineNumber,
            value: CLong(lineNumberMarginWidth())
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

    /// Set SC_AUTOMATICFOLD after fold levels have already been built by
    /// SCI_COLOURISE, so that SC_AUTOMATICFOLD_CHANGE only applies to
    /// *future* incremental fold-level changes — not to the initial pass
    /// that creates every fold point from scratch (which would auto-collapse
    /// the entire document on load).
    private func configureAutomaticFold() {
        // SCI_SETAUTOMATICFOLD(SC_AUTOMATICFOLD_SHOW | SC_AUTOMATICFOLD_CLICK)
        // SHOW (0x0001): keep lines folded when they become visible again.
        // CLICK (0x0002): handle fold-margin clicks.
        // SC_AUTOMATICFOLD_CHANGE (0x0004) is intentionally NOT set: it folds
        // whenever a fold level changes, which fires during every colorize
        // (language switch, keyword/style application after colorize) and
        // collapses the whole document. Manual folding via margin/menu is
        // unaffected.
        bridge.setGeneralProperty(ScintillaMessage.setAutomaticFold, parameter: 0x0001 | 0x0002, value: 0)
    }

    private func configureLexillaProperties(for language: LanguageDefinition) {
        for property in language.lexillaProperties {
            bridge.setLexerProperty(name: property.name, value: property.value)
        }
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
            applyDefaultLexerStyles(styleCatalog: styleCatalog, stylePreferences: stylePreferences)
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
    private func applyDefaultLexerStyles(styleCatalog: StyleCatalog, stylePreferences: StylePreferences) {
        let defaultStyle = resolvedDefaultStyle(styleCatalog: styleCatalog, stylePreferences: stylePreferences)
        let textColor = defaultStyle.foreground ?? StyleColor(red: 0, green: 0, blue: 0)
        let backgroundColor = defaultStyle.background ?? StyleColor(red: 255, green: 255, blue: 255)

        // Standard Scintilla lexer style ID semantics:
        // 0=default, 1=identifier, 2=comment, 3=number, 4=string/double-quoted,
        // 5=character/single-quoted, 6=keyword/instruction, 7=triple-quoted/verbatim,
        // 8=preprocessor, 9=operator, 10=label, 11-15=extended lexer styles
        let defaults: [(Int, StyleColor)] = [
            (0, textColor),
            (1, textColor),
            (2, StyleColor(red: 0, green: 128, blue: 0)),
            (3, StyleColor(red: 255, green: 128, blue: 0)),
            (4, StyleColor(red: 128, green: 128, blue: 128)),
            (5, StyleColor(red: 128, green: 128, blue: 128)),
            (6, StyleColor(red: 0, green: 0, blue: 255)),
            (7, StyleColor(red: 128, green: 128, blue: 128)),
            (8, StyleColor(red: 128, green: 0, blue: 0)),
            (9, textColor),
            (10, textColor),
            (11, textColor),
            (12, textColor),
            (13, textColor),
            (14, textColor),
            (15, textColor),
        ]
        for (styleID, color) in defaults {
            bridge.setGeneralProperty(ScintillaMessage.styleSetFore, parameter: CLong(styleID), value: CLong(color.scintillaColor))
            bridge.setGeneralProperty(ScintillaMessage.styleSetBack, parameter: CLong(styleID), value: CLong(backgroundColor.scintillaColor))
        }
    }

    // Apply global/widget styles (STYLE_DEFAULT=32, STYLE_LINENUMBER=33, etc.)
    // and propagate the Default Style colors to the autocomplete list.
    private func applyGlobalStyles(styleCatalog: StyleCatalog, stylePreferences: StylePreferences) {
        // Notepad++ global style IDs 21...31 are indicators, not Scintilla text styles.
        for baseStyle in styleCatalog.globalStyles where ScintillaStyleRouting.isGlobalTextStyle(baseStyle.styleID) {
            let key = StyleOverrideKey(languageName: "global", styleID: baseStyle.styleID)
            let style = stylePreferences.resolvedStyle(for: key, base: baseStyle)
            applyStyle(style)
        }
        // Apply Default Style (STYLE_DEFAULT = 32) colors to the autocomplete list.
        // This Scintilla build exposes no SCI_AUTOCSETFORE/BACK — those legacy
        // IDs (2237/2238) are actually SCI_FOLDLINE/SCI_FOLDCHILDREN, so using
        // them folded line 0 on every highlight pass. Use the element-colour API
        // instead: SCI_SETELEMENTCOLOUR with SC_ELEMENT_LIST (0) / LIST_BACK (1).
        if let defaultStyle = styleCatalog.globalStyles.first(where: { $0.styleID == 32 }) {
            let key = StyleOverrideKey(languageName: "global", styleID: 32)
            let resolved = stylePreferences.resolvedStyle(for: key, base: defaultStyle)
            if let fg = resolved.foreground {
                bridge.setGeneralProperty(ScintillaMessage.setElementColour, parameter: 0, value: CLong(fg.scintillaColor))
            }
            if let bg = resolved.background {
                bridge.setGeneralProperty(ScintillaMessage.setElementColour, parameter: 1, value: CLong(bg.scintillaColor))
            }
        }
    }

    private func resolvedDefaultStyle(
        styleCatalog: StyleCatalog,
        stylePreferences: StylePreferences
    ) -> LexerStyle {
        let base = styleCatalog.globalStyle(named: "Default Style")
            ?? styleCatalog.globalStyles.first { $0.styleID == 32 }
            ?? LexerStyle(
                name: "Default Style",
                styleID: 32,
                foreground: StyleColor(red: 0, green: 0, blue: 0),
                background: StyleColor(red: 255, green: 255, blue: 255),
                fontName: nil,
                fontSize: nil,
                fontStyle: 0,
                keywordClass: nil
            )
        let key = StyleOverrideKey(languageName: "global", styleID: base.styleID)
        return stylePreferences.resolvedStyle(for: key, base: base)
    }

    private func applyStyle(_ style: LexerStyle) {
        let styleID = CLong(style.styleID)

        if let foreground = style.foreground {
            let scintVal = CLong(foreground.scintillaColor)
            bridge.setGeneralProperty(ScintillaMessage.styleSetFore, parameter: styleID, value: scintVal)
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

    /// Send a raw Scintilla message with a pointer lParam and return the
    /// result — needed for messages like SCI_SEARCHINTARGET whose return
    /// value the property-style accessors discard.
    func message(_ message: Int32, wParam: CLong, lParam: UnsafeRawPointer?) -> CLong? {
        let selector = NSSelectorFromString("message:wParam:lParam:")
        guard target.responds(to: selector), let method = target.method(for: selector) else { return nil }
        typealias Function = @convention(c) (AnyObject, Selector, UInt32, UInt, Int) -> Int
        let function = unsafeBitCast(method, to: Function.self)
        return function(target, selector, UInt32(bitPattern: message), UInt(bitPattern: wParam), Int(bitPattern: lParam))
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
    static let clearAll: Int32 = 2004
    static let getCurrentPos: Int32 = 2008
    static let gotoLine: Int32 = 2024
    static let getLineCount: Int32 = 2154
    static let getDocPointer: Int32 = 2357
    static let setDocPointer: Int32 = 2358
    static let addRefDocument: Int32 = 2376
    static let releaseDocument: Int32 = 2377
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
    static let scrollRange: Int32 = 2569  // SCI_SCROLLRANGE (wParam=secondary, lParam=primary)
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
    static let setMouseSelectionRectangularSwitch: Int32 = 2668
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
    static let setAutomaticFold: Int32 = 2663  // SCI_SETAUTOMATICFOLD
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
    static let markerSetAlpha: Int32 = 2484  // SCI_MARKERSETALPHA
    static let setMarginType: Int32 = 2240
    static let setMarginWidth: Int32 = 2242
    static let setMarginMask: Int32 = 2244
    static let setMarginSensitive: Int32 = 2246
    // Indicator messages
    static let indicSetStyle: Int32 = 2080
    static let indicSetFore: Int32 = 2082
    static let indicSetAlpha: Int32 = 2523
    static let indicSetOutlineAlpha: Int32 = 2558
    static let indicSetUnder: Int32 = 2510
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
    static let getColumn: Int32 = 2129
    static let getFirstVisibleLine: Int32 = 2152
    static let setFirstVisibleLine: Int32 = 2163
    static let docLineFromVisible: Int32 = 2221
    static let linesOnScreen: Int32 = 2370
    static let textWidth: Int32 = 2276
    static let getSelText: Int32 = 2161
    static let getTextRange: Int32 = 2162
    static let annotationClearAll: Int32 = 2547
    static let setUndoCollection: Int32 = 2012
    static let setSavePoint: Int32 = 2014
    static let emptyUndoBuffer: Int32 = 2175
    static let getText: Int32 = 2182
    static let appendText: Int32 = 2282
    static let allocate: Int32 = 2446
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
    static let setScrollWidth: Int32 = 2274
    static let setScrollWidthTracking: Int32 = 2516
    static let setElementColour: Int32 = 2753  // SCI_SETELEMENTCOLOUR
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
    static let getStyleAt: Int32 = 2010
    static let styleGetFore: Int32 = 2481
    static let styleGetBack: Int32 = 2482
    static let styleGetBold: Int32 = 2483
    static let styleGetItalic: Int32 = 2484
    static let styleGetSize: Int32 = 2485
    static let styleGetFont: Int32 = 2486
    static let styleGetUnderline: Int32 = 2488
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
    static let contract: CLong = 0      // SC_FOLDACTION_CONTRACT
    static let expand: CLong = 1         // SC_FOLDACTION_EXPAND
    static let toggle: CLong = 2         // SC_FOLDACTION_TOGGLE
    static let contractEveryLevel: CLong = 4  // SC_FOLDACTION_CONTRACT_EVERY_LEVEL
    // Expand all levels: SC_FOLDACTION_EXPAND | SC_FOLDACTION_CONTRACT_EVERY_LEVEL
    // Contract all levels: SC_FOLDACTION_CONTRACT | SC_FOLDACTION_CONTRACT_EVERY_LEVEL
    // Matches upstream Notepad++ Editor::foldAll() implementation
    static let expandAllLevels: CLong = expand | contractEveryLevel
    static let contractAllLevels: CLong = contract | contractEveryLevel
}

private enum ScintillaFoldLevel {
    static let headerFlag: CLong = 0x2000
}

enum ScintillaFoldMarginMarkerStyle {
    static func symbols(forRawValue rawValue: Int) -> [(markerNumber: CLong, symbol: CLong)] {
        let style = FoldMarginStyle(rawValue: FoldMarginStyle.normalizedRawValue(rawValue)) ?? .box
        switch style {
        case .simple:
            return symbols(
                open: ScintillaMarkerSymbol.minus,
                closed: ScintillaMarkerSymbol.plus,
                sub: ScintillaMarkerSymbol.empty,
                tail: ScintillaMarkerSymbol.empty,
                end: ScintillaMarkerSymbol.empty,
                openMid: ScintillaMarkerSymbol.empty,
                midTail: ScintillaMarkerSymbol.empty
            )
        case .arrow:
            return symbols(
                open: ScintillaMarkerSymbol.arrowDown,
                closed: ScintillaMarkerSymbol.arrow,
                sub: ScintillaMarkerSymbol.empty,
                tail: ScintillaMarkerSymbol.empty,
                end: ScintillaMarkerSymbol.empty,
                openMid: ScintillaMarkerSymbol.empty,
                midTail: ScintillaMarkerSymbol.empty
            )
        case .circle:
            return symbols(
                open: ScintillaMarkerSymbol.circleMinus,
                closed: ScintillaMarkerSymbol.circlePlus,
                sub: ScintillaMarkerSymbol.vLine,
                tail: ScintillaMarkerSymbol.lCornerCurve,
                end: ScintillaMarkerSymbol.circlePlusConnected,
                openMid: ScintillaMarkerSymbol.circleMinusConnected,
                midTail: ScintillaMarkerSymbol.tCornerCurve
            )
        case .box, .none:
            return symbols(
                open: ScintillaMarkerSymbol.boxMinus,
                closed: ScintillaMarkerSymbol.boxPlus,
                sub: ScintillaMarkerSymbol.vLine,
                tail: ScintillaMarkerSymbol.lCorner,
                end: ScintillaMarkerSymbol.boxPlusConnected,
                openMid: ScintillaMarkerSymbol.boxMinusConnected,
                midTail: ScintillaMarkerSymbol.tCorner
            )
        }
    }

    private static func symbols(
        open: CLong,
        closed: CLong,
        sub: CLong,
        tail: CLong,
        end: CLong,
        openMid: CLong,
        midTail: CLong
    ) -> [(markerNumber: CLong, symbol: CLong)] {
        [
            (ScintillaMarker.folderOpen, open),
            (ScintillaMarker.folder, closed),
            (ScintillaMarker.folderSub, sub),
            (ScintillaMarker.folderTail, tail),
            (ScintillaMarker.folderEnd, end),
            (ScintillaMarker.folderOpenMid, openMid),
            (ScintillaMarker.folderMidTail, midTail)
        ]
    }
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
    static let arrow: CLong = 2
    static let empty: CLong = 5
    static let arrowDown: CLong = 6
    static let minus: CLong = 7
    static let plus: CLong = 8
    static let vLine: CLong = 9
    static let lCorner: CLong = 10
    static let tCorner: CLong = 11
    static let boxPlus: CLong = 12
    static let boxPlusConnected: CLong = 13
    static let boxMinus: CLong = 14
    static let boxMinusConnected: CLong = 15
    static let lCornerCurve: CLong = 16
    static let tCornerCurve: CLong = 17
    static let circlePlus: CLong = 18
    static let circlePlusConnected: CLong = 19
    static let circleMinus: CLong = 20
    static let circleMinusConnected: CLong = 21
    static let background: CLong = 22  // SC_MARK_BACKGROUND: tints the whole line
}
