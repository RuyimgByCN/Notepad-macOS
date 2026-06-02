import Foundation

public struct LineCommentEditResult: Equatable, Sendable {
    public let text: String
    public let selectedRange: NSRange

    public init(text: String, selectedRange: NSRange) {
        self.text = text
        self.selectedRange = selectedRange
    }
}

public enum LineCommentEdit {
    public static func toggle(
        in text: String,
        selection: NSRange,
        marker: String
    ) -> LineCommentEditResult {
        guard !marker.isEmpty else {
            return LineCommentEditResult(text: text, selectedRange: selection)
        }

        let selectedRange = normalized(selection, in: text)
        var lines = splitLinesPreservingEndings(text)
        let touchedLineIndices = touchedLines(for: selectedRange, in: lines)
        guard !touchedLineIndices.isEmpty else {
            return LineCommentEditResult(text: text, selectedRange: selectedRange)
        }

        let shouldUncomment = touchedLineIndices.allSatisfy { lineIndex in
            let body = lines[lineIndex].body
            let indentEnd = indentationEnd(in: body)
            return body[indentEnd...].hasPrefix(marker)
        }

        let markerLength = marker.utf16.count
        var edits: [LineCommentEditOperation] = []

        for lineIndex in touchedLineIndices {
            let body = lines[lineIndex].body
            let indentEnd = indentationEnd(in: body)
            let indentLength = body[..<indentEnd].utf16.count
            let editLocation = lines[lineIndex].startUTF16 + indentLength

            if shouldUncomment {
                let markerEnd = body.index(indentEnd, offsetBy: marker.count)
                lines[lineIndex].body.removeSubrange(indentEnd..<markerEnd)
                edits.append(
                    LineCommentEditOperation(
                        location: editLocation,
                        removedLength: markerLength,
                        insertedLength: 0
                    )
                )
            } else {
                lines[lineIndex].body.insert(contentsOf: marker, at: indentEnd)
                edits.append(
                    LineCommentEditOperation(
                        location: editLocation,
                        removedLength: 0,
                        insertedLength: markerLength
                    )
                )
            }
        }

        return LineCommentEditResult(
            text: lines.map { $0.body + $0.ending }.joined(),
            selectedRange: transformed(selectedRange, by: edits)
        )
    }

    private static func normalized(_ selection: NSRange, in text: String) -> NSRange {
        let textLength = (text as NSString).length
        let location = min(max(0, selection.location), textLength)
        let length = min(max(0, selection.length), textLength - location)
        return NSRange(location: location, length: length)
    }

    private static func touchedLines(for selection: NSRange, in lines: [LineCommentEditLine]) -> [Int] {
        guard selection.length > 0 else {
            return [lineIndex(containing: selection.location, in: lines)]
        }

        let selectionStart = selection.location
        let selectionEnd = selection.location + selection.length
        let indices = lines.indices.filter { lineIndex in
            let line = lines[lineIndex]
            return max(selectionStart, line.startUTF16) < min(selectionEnd, line.endUTF16)
        }

        if indices.isEmpty {
            return [lineIndex(containing: selection.location, in: lines)]
        }
        return Array(indices)
    }

    private static func lineIndex(containing location: Int, in lines: [LineCommentEditLine]) -> Int {
        for (index, line) in lines.enumerated() where location < line.endUTF16 {
            return index
        }
        return max(0, lines.count - 1)
    }

    private static func indentationEnd(in body: String) -> String.Index {
        var index = body.startIndex
        while index < body.endIndex {
            let character = body[index]
            if character == " " || character == "\t" {
                index = body.index(after: index)
            } else {
                break
            }
        }
        return index
    }

    private static func transformed(_ selection: NSRange, by edits: [LineCommentEditOperation]) -> NSRange {
        guard selection.length > 0 else {
            return NSRange(
                location: transformedPosition(selection.location, by: edits, bias: .right),
                length: 0
            )
        }

        let start = transformedPosition(selection.location, by: edits, bias: .left)
        let end = transformedPosition(selection.location + selection.length, by: edits, bias: .right)
        return NSRange(location: start, length: max(0, end - start))
    }

    private static func transformedPosition(
        _ position: Int,
        by edits: [LineCommentEditOperation],
        bias: LineCommentEditBoundaryBias
    ) -> Int {
        var transformed = position
        var cumulativeDelta = 0

        for edit in edits {
            if edit.removedLength == 0 {
                if edit.location < position || (bias == .right && edit.location == position) {
                    transformed += edit.insertedLength
                }
            } else {
                let removedEnd = edit.location + edit.removedLength
                if position > edit.location && position < removedEnd {
                    transformed = edit.location + cumulativeDelta
                } else if position >= removedEnd {
                    transformed += edit.delta
                }
            }

            cumulativeDelta += edit.delta
        }

        return max(0, transformed)
    }

    private static func splitLinesPreservingEndings(_ text: String) -> [LineCommentEditLine] {
        let nsText = text as NSString
        let textLength = nsText.length
        var lines: [LineCommentEditLine] = []
        var lineStart = 0
        var index = 0

        while index < textLength {
            let codeUnit = nsText.character(at: index)
            if codeUnit == 13 {
                let endingLength: Int
                if index + 1 < textLength, nsText.character(at: index + 1) == 10 {
                    endingLength = 2
                } else {
                    endingLength = 1
                }

                lines.append(
                    LineCommentEditLine(
                        body: nsText.substring(with: NSRange(location: lineStart, length: index - lineStart)),
                        ending: nsText.substring(with: NSRange(location: index, length: endingLength)),
                        startUTF16: lineStart
                    )
                )
                index += endingLength
                lineStart = index
            } else if codeUnit == 10 {
                lines.append(
                    LineCommentEditLine(
                        body: nsText.substring(with: NSRange(location: lineStart, length: index - lineStart)),
                        ending: "\n",
                        startUTF16: lineStart
                    )
                )
                index += 1
                lineStart = index
            } else {
                index += 1
            }
        }

        if lineStart < textLength {
            lines.append(
                LineCommentEditLine(
                    body: nsText.substring(with: NSRange(location: lineStart, length: textLength - lineStart)),
                    ending: "",
                    startUTF16: lineStart
                )
            )
        }

        return lines.isEmpty ? [LineCommentEditLine(body: "", ending: "", startUTF16: 0)] : lines
    }
}

private enum LineCommentEditBoundaryBias {
    case left
    case right
}

private struct LineCommentEditLine: Equatable {
    var body: String
    let ending: String
    let startUTF16: Int

    var endUTF16: Int {
        startUTF16 + body.utf16.count + ending.utf16.count
    }
}

private struct LineCommentEditOperation {
    let location: Int
    let removedLength: Int
    let insertedLength: Int

    var delta: Int {
        insertedLength - removedLength
    }
}
