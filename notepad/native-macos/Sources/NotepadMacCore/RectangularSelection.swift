import Foundation

public struct RectangularSelectionContext: Equatable, Sendable {
    public let lineRange: ClosedRange<Int>
    public let startColumn: Int
    public let endColumn: Int
    public let selectedBlock: [String]

    public init(
        lineRange: ClosedRange<Int>,
        startColumn: Int,
        endColumn: Int,
        selectedBlock: [String]
    ) {
        self.lineRange = lineRange
        self.startColumn = startColumn
        self.endColumn = endColumn
        self.selectedBlock = selectedBlock
    }

    public var blockText: String {
        selectedBlock.joined(separator: "\n")
    }
}

public struct RectangularSelectionLiveMetadata: Equatable, Sendable {
    public let anchorUTF16Location: Int
    public let caretUTF16Location: Int
    public let anchorVirtualSpace: Int
    public let caretVirtualSpace: Int

    public init(
        anchorUTF16Location: Int,
        caretUTF16Location: Int,
        anchorVirtualSpace: Int,
        caretVirtualSpace: Int
    ) {
        self.anchorUTF16Location = anchorUTF16Location
        self.caretUTF16Location = caretUTF16Location
        self.anchorVirtualSpace = anchorVirtualSpace
        self.caretVirtualSpace = caretVirtualSpace
    }
}

public struct RectangularSelectionEditResult: Equatable, Sendable {
    public let text: String
    public let editedRanges: [NSRange]

    public init(text: String, editedRanges: [NSRange]) {
        self.text = text
        self.editedRanges = editedRanges
    }

    /// A single contiguous range spanning all edited row ranges.
    ///
    /// This is a fallback for editor surfaces that cannot yet express true
    /// rectangular multi-selections; `editedRanges` remains the precise
    /// per-row metadata for future Scintilla multi-selection wiring.
    public var contiguousEditedRange: NSRange? {
        guard let firstRange = editedRanges.first else {
            return nil
        }

        var lowerBound = firstRange.location
        var upperBound = firstRange.location + firstRange.length
        for range in editedRanges.dropFirst() {
            lowerBound = min(lowerBound, range.location)
            upperBound = max(upperBound, range.location + range.length)
        }
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    public var finalCaretRange: NSRange {
        guard let range = editedRanges.last else {
            return NSRange(location: 0, length: 0)
        }
        return NSRange(location: range.location + range.length, length: 0)
    }
}

public enum RectangularSelectionError: Error, Equatable, Sendable {
    case invalidColumn
    case invalidColumnRange
    case invalidLineRange
    case lineRangeOutsideDocument
    case blockLineCountMismatch
}

public enum RectangularSelection {
    public static func context(in text: String, selectedRange: NSRange) throws -> RectangularSelectionContext {
        let range = clamped(selectedRange, in: text)
        let startPosition = TextPosition.lineAndCharacterColumn(in: text, utf16Location: range.location)
        guard range.length > 0 else {
            return RectangularSelectionContext(
                lineRange: startPosition.line...startPosition.line,
                startColumn: startPosition.column,
                endColumn: startPosition.column,
                selectedBlock: []
            )
        }

        let endLocation = effectiveSelectionEndLocation(in: text, selectedRange: range)
        guard endLocation > range.location else {
            return RectangularSelectionContext(
                lineRange: startPosition.line...startPosition.line,
                startColumn: startPosition.column,
                endColumn: startPosition.column,
                selectedBlock: []
            )
        }

        let endPosition = TextPosition.lineAndCharacterColumn(in: text, utf16Location: endLocation)
        let endColumn = max(1, endPosition.column - 1)
        let startColumn = min(startPosition.column, endColumn)
        let throughColumn = max(startPosition.column, endColumn)
        let lineRange = min(startPosition.line, endPosition.line)...max(startPosition.line, endPosition.line)
        let selectedBlock = try extract(
            from: text,
            lineRange: lineRange,
            columnRange: (startColumn - 1)..<throughColumn
        )

        return RectangularSelectionContext(
            lineRange: lineRange,
            startColumn: startColumn,
            endColumn: throughColumn,
            selectedBlock: selectedBlock
        )
    }

    public static func context(
        in text: String,
        liveSelection: RectangularSelectionLiveMetadata
    ) throws -> RectangularSelectionContext {
        let anchor = rectangularEndpoint(
            in: text,
            utf16Location: liveSelection.anchorUTF16Location,
            virtualSpace: liveSelection.anchorVirtualSpace
        )
        let caret = rectangularEndpoint(
            in: text,
            utf16Location: liveSelection.caretUTF16Location,
            virtualSpace: liveSelection.caretVirtualSpace
        )
        let lineRange = min(anchor.line, caret.line)...max(anchor.line, caret.line)
        let startZeroBasedColumn = min(anchor.zeroBasedColumn, caret.zeroBasedColumn)
        let endExclusiveColumn = max(anchor.zeroBasedColumn, caret.zeroBasedColumn)
        let startColumn = startZeroBasedColumn + 1
        let endColumn = max(startColumn, endExclusiveColumn)
        let selectedBlock = endExclusiveColumn > startZeroBasedColumn
            ? try extract(
                from: text,
                lineRange: lineRange,
                columnRange: startZeroBasedColumn..<endExclusiveColumn
            )
            : []

        return RectangularSelectionContext(
            lineRange: lineRange,
            startColumn: startColumn,
            endColumn: endColumn,
            selectedBlock: selectedBlock
        )
    }

    public static func zeroBasedCharacterColumn(fromOneBasedColumn column: Int) throws -> Int {
        guard column > 0 else {
            throw RectangularSelectionError.invalidColumn
        }
        return column - 1
    }

    public static func zeroBasedCharacterColumn(in text: String, utf16Location: Int) -> Int {
        max(0, TextPosition.lineAndCharacterColumn(in: text, utf16Location: utf16Location).column - 1)
    }

    /// Extracts a rectangular block using one-based line numbers and zero-based character column offsets.
    public static func extract(
        from text: String,
        lineRange: ClosedRange<Int>,
        columnRange: Range<Int>
    ) throws -> [String] {
        let lines = splitLinesPreservingEndings(text)
        _ = try validate(lineRange: lineRange, lineCount: lines.count)
        try validate(columnRange: columnRange)

        var block: [String] = []
        for lineNumber in lineRange.lowerBound...lineRange.upperBound {
            let line = lines[lineNumber - 1]
            block.append(extract(from: line.body, columnRange: columnRange))
        }
        return block
    }

    /// Inserts a rectangular block using one-based line numbers and a zero-based character column offset.
    public static func insert(
        _ block: [String],
        into text: String,
        lineRange: ClosedRange<Int>,
        column: Int
    ) throws -> String {
        try insertResult(block, into: text, lineRange: lineRange, column: column).text
    }

    /// Inserts a rectangular block and reports the inserted ranges in the edited text.
    public static func insertResult(
        _ block: [String],
        into text: String,
        lineRange: ClosedRange<Int>,
        column: Int
    ) throws -> RectangularSelectionEditResult {
        guard column >= 0 else {
            throw RectangularSelectionError.invalidColumn
        }

        return try replaceResult(
            in: text,
            lineRange: lineRange,
            columnRange: column..<column,
            with: block
        )
    }

    /// Replaces a rectangular block using one-based line numbers and zero-based character column offsets.
    public static func replace(
        in text: String,
        lineRange: ClosedRange<Int>,
        columnRange: Range<Int>,
        with block: [String]
    ) throws -> String {
        try replaceResult(in: text, lineRange: lineRange, columnRange: columnRange, with: block).text
    }

    /// Replaces a rectangular block and reports the replacement ranges in the edited text.
    public static func replaceResult(
        in text: String,
        lineRange: ClosedRange<Int>,
        columnRange: Range<Int>,
        with block: [String]
    ) throws -> RectangularSelectionEditResult {
        var lines = splitLinesPreservingEndings(text)
        let selectedLineCount = try validate(lineRange: lineRange, lineCount: lines.count)
        try validate(columnRange: columnRange)
        guard block.count == selectedLineCount else {
            throw RectangularSelectionError.blockLineCountMismatch
        }

        var editedRangesByLine = Array<NSRange?>(repeating: nil, count: lines.count)
        for lineNumber in lineRange.lowerBound...lineRange.upperBound {
            let lineIndex = lineNumber - 1
            let blockIndex = lineNumber - lineRange.lowerBound
            let edit = replacement(
                in: lines[lineIndex].body,
                columnRange: columnRange,
                with: block[blockIndex]
            )
            lines[lineIndex].body = edit.body
            editedRangesByLine[lineIndex] = edit.editedRange
        }

        return rebuildResult(lines, editedRangesByLine: editedRangesByLine)
    }

    private static func validate(lineRange: ClosedRange<Int>, lineCount: Int) throws -> Int {
        guard lineRange.lowerBound > 0, lineRange.lowerBound <= lineRange.upperBound else {
            throw RectangularSelectionError.invalidLineRange
        }
        guard lineRange.upperBound <= lineCount else {
            throw RectangularSelectionError.lineRangeOutsideDocument
        }
        return lineRange.upperBound - lineRange.lowerBound + 1
    }

    private static func validate(columnRange: Range<Int>) throws {
        guard columnRange.lowerBound >= 0, columnRange.upperBound >= columnRange.lowerBound else {
            throw RectangularSelectionError.invalidColumnRange
        }
    }

    private static func extract(from body: String, columnRange: Range<Int>) -> String {
        let bodyCount = body.count
        let startOffset = min(columnRange.lowerBound, bodyCount)
        let endOffset = min(columnRange.upperBound, bodyCount)
        guard startOffset < endOffset else {
            return ""
        }

        let startIndex = body.index(body.startIndex, offsetBy: startOffset)
        let endIndex = body.index(body.startIndex, offsetBy: endOffset)
        return String(body[startIndex..<endIndex])
    }

    private static func replacement(
        in body: String,
        columnRange: Range<Int>,
        with replacement: String
    ) -> RectangularLineEdit {
        let bodyCount = body.count
        let prefix: String
        if columnRange.lowerBound <= bodyCount {
            let prefixEnd = body.index(body.startIndex, offsetBy: columnRange.lowerBound)
            prefix = String(body[..<prefixEnd])
        } else {
            prefix = body + String(repeating: " ", count: columnRange.lowerBound - bodyCount)
        }

        let suffix: String
        if columnRange.upperBound < bodyCount {
            let suffixStart = body.index(body.startIndex, offsetBy: columnRange.upperBound)
            suffix = String(body[suffixStart...])
        } else {
            suffix = ""
        }

        return RectangularLineEdit(
            body: prefix + replacement + suffix,
            editedRange: NSRange(location: prefix.utf16.count, length: replacement.utf16.count)
        )
    }

    private static func rebuildResult(
        _ lines: [RectangularLine],
        editedRangesByLine: [NSRange?]
    ) -> RectangularSelectionEditResult {
        var text = ""
        var editedRanges: [NSRange] = []
        var utf16Location = 0
        for (index, line) in lines.enumerated() {
            if let localRange = editedRangesByLine[index] {
                editedRanges.append(NSRange(
                    location: utf16Location + localRange.location,
                    length: localRange.length
                ))
            }
            text += line.body
            text += line.ending
            utf16Location = text.utf16.count
        }
        return RectangularSelectionEditResult(text: text, editedRanges: editedRanges)
    }

    private static func rectangularEndpoint(
        in text: String,
        utf16Location: Int,
        virtualSpace: Int
    ) -> (line: Int, zeroBasedColumn: Int) {
        let position = TextPosition.lineAndCharacterColumn(in: text, utf16Location: utf16Location)
        return (
            line: position.line,
            zeroBasedColumn: max(0, position.column - 1) + max(0, virtualSpace)
        )
    }

    private static func clamped(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(max(0, range.location), length)
        let requestedLength = max(0, range.length)
        let requestedEnd = range.location > Int.max - requestedLength
            ? Int.max
            : range.location + requestedLength
        let end = min(max(location, requestedEnd), length)
        return NSRange(location: location, length: end - location)
    }

    private static func effectiveSelectionEndLocation(in text: String, selectedRange range: NSRange) -> Int {
        let nsText = text as NSString
        let endLocation = range.location + range.length
        guard endLocation > range.location, endLocation <= nsText.length else {
            return endLocation
        }

        let previousCharacter = nsText.substring(with: NSRange(location: endLocation - 1, length: 1))
        if previousCharacter == "\n" {
            if endLocation >= 2,
               nsText.substring(with: NSRange(location: endLocation - 2, length: 1)) == "\r" {
                return endLocation - 2
            }
            return endLocation - 1
        }
        if previousCharacter == "\r" {
            return endLocation - 1
        }
        return endLocation
    }

    private static func splitLinesPreservingEndings(_ text: String) -> [RectangularLine] {
        guard !text.isEmpty else {
            return [RectangularLine(body: "", ending: "")]
        }

        var lines: [RectangularLine] = []
        var bodyStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if String(character) == "\r\n" {
                lines.append(RectangularLine(body: String(text[bodyStart..<index]), ending: "\r\n"))
                index = text.index(after: index)
                bodyStart = index
            } else if character == "\n" {
                lines.append(RectangularLine(body: String(text[bodyStart..<index]), ending: "\n"))
                index = text.index(after: index)
                bodyStart = index
            } else if character == "\r" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    lines.append(RectangularLine(body: String(text[bodyStart..<index]), ending: "\r\n"))
                    index = text.index(after: next)
                } else {
                    lines.append(RectangularLine(body: String(text[bodyStart..<index]), ending: "\r"))
                    index = next
                }
                bodyStart = index
            } else {
                index = text.index(after: index)
            }
        }

        if bodyStart < text.endIndex {
            lines.append(RectangularLine(body: String(text[bodyStart..<text.endIndex]), ending: ""))
        }

        return lines.isEmpty ? [RectangularLine(body: "", ending: "")] : lines
    }
}

private struct RectangularLine: Equatable {
    var body: String
    var ending: String
}

private struct RectangularLineEdit: Equatable {
    var body: String
    var editedRange: NSRange
}
