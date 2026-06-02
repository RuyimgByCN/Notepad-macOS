import AppKit
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
    var foldState: FoldState { get }

    func setSelectedRange(_ range: NSRange)
    func applyDiscontiguousSelections(_ ranges: [NSRange], mainSelectionIndex: Int) -> Bool
    func applyRectangularSelection(_ selection: RectangularSelectionLiveMetadata) -> Bool
    func applyFont(size: CGFloat)
    func applyLineWrapping(_ wraps: Bool, width: CGFloat)
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
}

@MainActor
enum EditorSurfaceFactory {
    static func make() -> EditorSurface {
        ScintillaEditorSurface.load() ?? TextViewEditorSurface()
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
                  let result = scintillaView.perform(selector)?.takeUnretainedValue() as? NSString
            else {
                return ""
            }
            return result as String
        }
        set {
            let selector = NSSelectorFromString("setString:")
            guard scintillaView.responds(to: selector) else { return }
            scintillaView.perform(selector, with: newValue as NSString)
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

    func applyLineWrapping(_ wraps: Bool, width: CGFloat) {
        bridge.setGeneralProperty(
            ScintillaMessage.setWrapMode,
            parameter: wraps ? ScintillaWrapMode.word : ScintillaWrapMode.none,
            value: 0
        )
    }

    func applyHighlight(
        language: LanguageDefinition,
        styleCatalog: StyleCatalog,
        stylePreferences: StylePreferences,
        highlighter: SyntaxHighlighter
    ) {
        bridge.setFont(name: "Menlo", size: 13, bold: false, italic: false)
        bridge.setGeneralProperty(ScintillaMessage.styleClearAll, parameter: 0, value: 0)

        if let lexerName = language.lexillaLexerName,
           let lexer = LexillaDynamicLibrary.shared.createLexer(named: lexerName) {
            bridge.setReferenceProperty(
                ScintillaMessage.setILexer,
                parameter: 0,
                value: UnsafeRawPointer(lexer)
            )
            configureFoldingProperties()
        } else {
            bridge.setReferenceProperty(ScintillaMessage.setILexer, parameter: 0, value: nil)
        }

        for (index, keywords) in language.scintillaKeywordSets.prefix(ScintillaKeyword.maximumSets).enumerated() {
            let keywordText = keywords.joined(separator: " ")
            keywordText.withCString { pointer in
                bridge.setReferenceProperty(
                    ScintillaMessage.setKeywords,
                    parameter: CLong(index),
                    value: UnsafeRawPointer(pointer)
                )
            }
        }

        applyStyles(language: language, styleCatalog: styleCatalog, stylePreferences: stylePreferences)
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
        case ScintillaNotificationCode.marginClick:
            handleMarginClick(from: rawNotification)
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
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: scintillaView)
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

    private func configureFoldingProperties() {
        bridge.setLexerProperty(name: "fold", value: "1")
        bridge.setLexerProperty(name: "fold.compact", value: "0")
        bridge.setLexerProperty(name: "fold.comment", value: "1")
        bridge.setLexerProperty(name: "fold.preprocessor", value: "1")
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
        guard let lexer = styleCatalog.lexer(named: language.name) else { return }

        for baseStyle in lexer.styles {
            let key = StyleOverrideKey(languageName: lexer.name, styleID: baseStyle.styleID)
            let style = stylePreferences.resolvedStyle(for: key, base: baseStyle)
            applyStyle(style)
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

    private typealias CreateLexerFunction = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?

    private let handle: UnsafeMutableRawPointer?
    private let createLexerFunction: CreateLexerFunction?

    private init() {
        for libraryURL in Self.libraryCandidates() {
            guard FileManager.default.fileExists(atPath: libraryURL.path),
                  let openedHandle = dlopen(libraryURL.path, RTLD_NOW | RTLD_LOCAL)
            else {
                continue
            }

            if let symbol = dlsym(openedHandle, "CreateLexer") {
                handle = openedHandle
                createLexerFunction = unsafeBitCast(symbol, to: CreateLexerFunction.self)
                return
            }

            dlclose(openedHandle)
        }

        handle = nil
        createLexerFunction = nil
    }

    func createLexer(named lexerName: String) -> UnsafeMutableRawPointer? {
        guard let createLexerFunction else { return nil }
        return lexerName.withCString { pointer in
            createLexerFunction(pointer)
        }
    }

    private static func libraryCandidates() -> [URL] {
        let sourceRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var urls: [URL] = []
        if let privateFrameworksURL = Bundle.main.privateFrameworksURL {
            urls.append(privateFrameworksURL.appending(path: "liblexilla.dylib"))
        }

        urls.append(sourceRoot.appending(path: "../notepad-plus-plus/lexilla/bin/liblexilla.dylib").standardizedFileURL)
        urls.append(
            URL(filePath: FileManager.default.currentDirectoryPath)
                .appending(path: "../notepad-plus-plus/lexilla/bin/liblexilla.dylib")
                .standardizedFileURL
        )
        return urls
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
    static let marginClick: UInt32 = 2010
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
    static let lineFromPosition: Int32 = 2166
    static let scrollCaret: Int32 = 2169
    static let getFoldLevel: Int32 = 2223
    static let getFoldExpanded: Int32 = 2230
    static let toggleFold: Int32 = 2231
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
    static let setMultiPaste: Int32 = 2614
    static let foldAll: Int32 = 2662
    static let setKeywords: Int32 = 4005
    static let setILexer: Int32 = 4033
    static let markerDefine: Int32 = 2040
    static let markerSetFore: Int32 = 2041
    static let markerSetBack: Int32 = 2042
    static let markerAdd: Int32 = 2043
    static let markerDeleteAll: Int32 = 2045
    static let setMarginType: Int32 = 2240
    static let setMarginWidth: Int32 = 2242
    static let setMarginMask: Int32 = 2244
    static let setMarginSensitive: Int32 = 2246
}

private enum ScintillaWrapMode {
    static let none: CLong = 0
    static let word: CLong = 1
}

private enum ScintillaMultiPaste {
    static let each: CLong = 1
}

private enum ScintillaVirtualSpace {
    static let rectangularSelection: CLong = 1
}

private enum ScintillaFoldAction {
    static let contractAllLevels: CLong = 4
    static let expand: CLong = 1
}

private enum ScintillaFoldLevel {
    static let headerFlag: CLong = 0x2000
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
    var scintillaKeywordSets: [[String]] {
        keywordGroups
            .sorted { lhs, rhs in
                keywordGroupPriority(lhs.key) < keywordGroupPriority(rhs.key)
            }
            .map(\.value)
            .filter { !$0.isEmpty }
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
