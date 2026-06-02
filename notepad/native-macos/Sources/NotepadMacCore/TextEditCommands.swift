import Foundation

public struct TextEditCommandResult: Equatable, Sendable {
    public let text: String
    public let selectedRange: NSRange

    public init(text: String, selectedRange: NSRange) {
        self.text = text
        self.selectedRange = selectedRange
    }
}

public enum TextEditCommands {
    public static func duplicate(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        if range.length > 0 {
            return duplicateSelectedText(in: text, selectedRange: range)
        }
        return duplicateCurrentLine(in: text, caretLocation: range.location)
    }

    public static func trimTrailingWhitespace(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        var trimmedText = ""
        var removedRanges: [NSRange] = []

        for line in lines {
            let trimEnd = trailingWhitespaceStart(in: nsText, bodyRange: line.bodyRange)
            let keptBodyRange = NSRange(
                location: line.bodyRange.location,
                length: trimEnd - line.bodyRange.location
            )
            let removedLength = line.bodyRange.endLocation - trimEnd
            if removedLength > 0 {
                removedRanges.append(NSRange(location: trimEnd, length: removedLength))
            }

            trimmedText += nsText.substring(with: keptBodyRange)
            trimmedText += nsText.substring(with: line.endingRange)
        }

        let start = mappedLocation(range.location, afterRemoving: removedRanges)
        let end = mappedLocation(range.endLocation, afterRemoving: removedRanges)
        return TextEditCommandResult(
            text: trimmedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func joinSelectedLines(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)

        guard block.lowerBound < block.upperBound else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        var joinedText = ""
        var removedRanges: [NSRange] = []

        for (index, line) in lines.enumerated() {
            joinedText += nsText.substring(with: line.bodyRange)
            if block.contains(index), index < block.upperBound {
                if line.endingRange.length > 0 {
                    removedRanges.append(line.endingRange)
                }
            } else {
                joinedText += nsText.substring(with: line.endingRange)
            }
        }

        let start = mappedLocation(range.location, afterRemoving: removedRanges)
        let end = mappedLocation(range.endLocation, afterRemoving: removedRanges)
        return TextEditCommandResult(
            text: joinedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func removeEmptyLines(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        removeLines(in: text, selectedRange: selectedRange) { _, line in
            line.bodyRange.length == 0
        }
    }

    public static func removeBlankLines(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        removeLines(in: text, selectedRange: selectedRange) { nsText, line in
            line.bodyRange.length == 0 || containsOnlySpacesAndTabs(in: nsText, range: line.bodyRange)
        }
    }

    public static func removeDuplicateLines(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        removeDuplicateLines(in: text, selectedRange: selectedRange, consecutiveOnly: false)
    }

    public static func removeConsecutiveDuplicateLines(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        removeDuplicateLines(in: text, selectedRange: selectedRange, consecutiveOnly: true)
    }

    public static func sortSelectedLinesAscending(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        sortSelectedLines(in: text, selectedRange: selectedRange, order: .ascending)
    }

    public static func sortSelectedLinesDescending(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        sortSelectedLines(in: text, selectedRange: selectedRange, order: .descending)
    }

    public static func uppercaseSelection(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        convertSelectionCase(in: text, selectedRange: selectedRange, conversion: .uppercase)
    }

    public static func lowercaseSelection(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        convertSelectionCase(in: text, selectedRange: selectedRange, conversion: .lowercase)
    }

    public static func invertSelectionCase(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        convertSelectionCase(in: text, selectedRange: selectedRange, conversion: .inverted)
    }

    public static func sentenceCaseSelection(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        convertSelectionCase(in: text, selectedRange: selectedRange, conversion: .sentence)
    }

    public static func deleteCurrentLineOrSelection(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let result = mutableCopy(of: text)

        if range.length > 0 {
            result.deleteCharacters(in: range)
            return TextEditCommandResult(
                text: String(result),
                selectedRange: NSRange(location: min(range.location, result.length), length: 0)
            )
        }

        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let lineIndex = lineIndex(containing: range.location, in: lines)
        let deleteRange = currentLineDeletionRange(at: lineIndex, in: lines)
        guard deleteRange.length > 0 else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        result.deleteCharacters(in: deleteRange)
        return TextEditCommandResult(
            text: String(result),
            selectedRange: NSRange(location: min(deleteRange.location, result.length), length: 0)
        )
    }

    public static func moveCurrentLineOrSelectionUp(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        moveCurrentLineOrSelection(in: text, selectedRange: selectedRange, direction: .up)
    }

    public static func moveCurrentLineOrSelectionDown(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        moveCurrentLineOrSelection(in: text, selectedRange: selectedRange, direction: .down)
    }

    private static func duplicateSelectedText(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let nsText = text as NSString
        let selectedText = nsText.substring(with: selectedRange)
        let insertLocation = selectedRange.endLocation
        let result = mutableCopy(of: text)
        result.insert(selectedText, at: insertLocation)

        return TextEditCommandResult(
            text: String(result),
            selectedRange: NSRange(location: insertLocation, length: selectedRange.length)
        )
    }

    private static func duplicateCurrentLine(in text: String, caretLocation: Int) -> TextEditCommandResult {
        let nsText = text as NSString
        let line = line(containing: caretLocation, in: splitLines(in: nsText))
        let result = mutableCopy(of: text)
        let insertedText: String
        let insertLocation: Int

        if line.endingRange.length > 0 {
            insertedText = nsText.substring(with: line.fullRange)
            insertLocation = line.fullRange.endLocation
        } else {
            let preferredEnding = LineEnding.detect(in: text).rawValue
            insertedText = preferredEnding + nsText.substring(with: line.bodyRange)
            insertLocation = line.fullRange.endLocation
        }

        result.insert(insertedText, at: insertLocation)
        return TextEditCommandResult(
            text: String(result),
            selectedRange: NSRange(location: caretLocation + insertedText.utf16.count, length: 0)
        )
    }

    private static func splitLines(in text: NSString) -> [TextEditLine] {
        guard text.length > 0 else {
            return [
                TextEditLine(
                    bodyRange: NSRange(location: 0, length: 0),
                    endingRange: NSRange(location: 0, length: 0)
                )
            ]
        }

        var lines: [TextEditLine] = []
        var bodyStart = 0
        var location = 0

        while location < text.length {
            let unit = text.character(at: location)
            if unit == 13 {
                let endingLength: Int
                if location + 1 < text.length, text.character(at: location + 1) == 10 {
                    endingLength = 2
                } else {
                    endingLength = 1
                }
                lines.append(
                    TextEditLine(
                        bodyRange: NSRange(location: bodyStart, length: location - bodyStart),
                        endingRange: NSRange(location: location, length: endingLength)
                    )
                )
                location += endingLength
                bodyStart = location
            } else if unit == 10 {
                lines.append(
                    TextEditLine(
                        bodyRange: NSRange(location: bodyStart, length: location - bodyStart),
                        endingRange: NSRange(location: location, length: 1)
                    )
                )
                location += 1
                bodyStart = location
            } else {
                location += 1
            }
        }

        if bodyStart < text.length {
            lines.append(
                TextEditLine(
                    bodyRange: NSRange(location: bodyStart, length: text.length - bodyStart),
                    endingRange: NSRange(location: text.length, length: 0)
                )
            )
        } else {
            lines.append(
                TextEditLine(
                    bodyRange: NSRange(location: text.length, length: 0),
                    endingRange: NSRange(location: text.length, length: 0)
                )
            )
        }

        return lines
    }

    private static func line(containing location: Int, in lines: [TextEditLine]) -> TextEditLine {
        for line in lines {
            if location < line.fullRange.endLocation {
                return line
            }
            if line.fullRange.length == 0, location == line.fullRange.location {
                return line
            }
        }
        return lines[lines.count - 1]
    }

    private static func lineIndex(containing location: Int, in lines: [TextEditLine]) -> Int {
        for (index, line) in lines.enumerated() {
            if location < line.fullRange.endLocation {
                return index
            }
            if line.fullRange.length == 0, location == line.fullRange.location {
                return index
            }
        }
        return lines.count - 1
    }

    private static func lineBlock(containing range: NSRange, in lines: [TextEditLine]) -> ClosedRange<Int> {
        let start = lineIndex(containing: range.location, in: lines)
        let endLocation = range.length > 0 ? max(range.location, range.endLocation - 1) : range.location
        let end = lineIndex(containing: endLocation, in: lines)
        return start...end
    }

    private static func currentLineDeletionRange(at index: Int, in lines: [TextEditLine]) -> NSRange {
        let current = lines[index]
        if current.endingRange.length > 0 || index == 0 {
            return current.fullRange
        }

        let previous = lines[index - 1]
        return NSRange(
            location: previous.endingRange.location,
            length: previous.endingRange.length + current.fullRange.length
        )
    }

    private static func moveCurrentLineOrSelection(
        in text: String,
        selectedRange: NSRange,
        direction: LineMoveDirection
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)

        switch direction {
        case .up where block.lowerBound == 0:
            return TextEditCommandResult(text: text, selectedRange: range)
        case .down where block.upperBound >= lines.count - 1:
            return TextEditCommandResult(text: text, selectedRange: range)
        default:
            break
        }

        let tokens = lineTokens(from: lines, in: nsText)
        var movedTokens: [TextEditLineToken] = []

        switch direction {
        case .up:
            let previousIndex = block.lowerBound - 1
            movedTokens.append(contentsOf: tokens[0..<previousIndex])
            movedTokens.append(contentsOf: tokens[block])
            movedTokens.append(tokens[previousIndex])
            movedTokens.append(contentsOf: tokens[(block.upperBound + 1)..<tokens.count])
        case .down:
            let nextIndex = block.upperBound + 1
            movedTokens.append(contentsOf: tokens[0..<block.lowerBound])
            movedTokens.append(tokens[nextIndex])
            movedTokens.append(contentsOf: tokens[block])
            movedTokens.append(contentsOf: tokens[(nextIndex + 1)..<tokens.count])
        }

        var sourceToMovedIndex = Array(repeating: 0, count: movedTokens.count)
        for (index, token) in movedTokens.enumerated() {
            sourceToMovedIndex[token.sourceIndex] = index
        }

        normalizeFinalLineEnding(in: &movedTokens)
        let movedLineStarts = lineStarts(in: movedTokens)
        let movedText = movedTokens.map(\.fullText).joined()

        let movedSelectionStart = movedLocation(
            from: linePosition(for: range.location, endBoundary: false, in: lines),
            sourceToMovedIndex: sourceToMovedIndex,
            movedTokens: movedTokens,
            movedLineStarts: movedLineStarts
        )

        if range.length == 0 {
            return TextEditCommandResult(
                text: movedText,
                selectedRange: NSRange(location: movedSelectionStart, length: 0)
            )
        }

        let movedSelectionEnd = movedLocation(
            from: linePosition(for: range.endLocation, endBoundary: true, in: lines),
            sourceToMovedIndex: sourceToMovedIndex,
            movedTokens: movedTokens,
            movedLineStarts: movedLineStarts
        )

        return TextEditCommandResult(
            text: movedText,
            selectedRange: NSRange(
                location: min(movedSelectionStart, movedSelectionEnd),
                length: max(movedSelectionStart, movedSelectionEnd) - min(movedSelectionStart, movedSelectionEnd)
            )
        )
    }

    private static func lineTokens(from lines: [TextEditLine], in text: NSString) -> [TextEditLineToken] {
        lines.enumerated().map { index, line in
            TextEditLineToken(
                sourceIndex: index,
                body: text.substring(with: line.bodyRange),
                ending: text.substring(with: line.endingRange)
            )
        }
    }

    private static func normalizeFinalLineEnding(in tokens: inout [TextEditLineToken]) {
        guard let emptyEndingIndex = tokens.firstIndex(where: { $0.ending.isEmpty }) else {
            return
        }

        var index = emptyEndingIndex
        while index < tokens.count - 1 {
            tokens[index].ending = tokens[index + 1].ending
            tokens[index + 1].ending = ""
            index += 1
        }
    }

    private static func lineStarts(in tokens: [TextEditLineToken]) -> [Int] {
        var starts: [Int] = []
        var location = 0
        for token in tokens {
            starts.append(location)
            location += token.fullUTF16Length
        }
        return starts
    }

    private static func linePosition(
        for location: Int,
        endBoundary: Bool,
        in lines: [TextEditLine]
    ) -> TextEditLinePosition {
        let sourceLocation = endBoundary && location > 0 ? location - 1 : location
        let index = lineIndex(containing: sourceLocation, in: lines)
        let boundaryOffset = endBoundary && location > 0 ? 1 : 0
        return TextEditLinePosition(
            lineIndex: index,
            offset: sourceLocation - lines[index].fullRange.location + boundaryOffset
        )
    }

    private static func movedLocation(
        from position: TextEditLinePosition,
        sourceToMovedIndex: [Int],
        movedTokens: [TextEditLineToken],
        movedLineStarts: [Int]
    ) -> Int {
        let movedIndex = sourceToMovedIndex[position.lineIndex]
        let token = movedTokens[movedIndex]
        return movedLineStarts[movedIndex] + min(max(0, position.offset), token.fullUTF16Length)
    }

    private static func removeLines(
        in text: String,
        selectedRange: NSRange,
        shouldRemove: (NSString, TextEditLine) -> Bool
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        var editedText = ""
        var removedRanges: [NSRange] = []

        for line in lines {
            if shouldRemove(nsText, line) {
                let fullRange = line.fullRange
                if fullRange.length > 0 {
                    removedRanges.append(fullRange)
                }
            } else {
                editedText += nsText.substring(with: line.fullRange)
            }
        }

        let start = mappedLocation(range.location, afterRemoving: removedRanges)
        let end = mappedLocation(range.endLocation, afterRemoving: removedRanges)
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    private static func sortSelectedLines(
        in text: String,
        selectedRange: NSRange,
        order: LineSortOrder
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        guard block.lowerBound < block.upperBound else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        var tokens = lineTokens(from: lines, in: nsText)
        let sortedBlock = tokens[block]
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.body == rhs.element.body {
                    return lhs.offset < rhs.offset
                }
                switch order {
                case .ascending:
                    return lhs.element.body < rhs.element.body
                case .descending:
                    return lhs.element.body > rhs.element.body
                }
            }
            .map(\.element)

        tokens.replaceSubrange(block, with: sortedBlock)
        normalizeFinalLineEnding(in: &tokens)
        let starts = lineStarts(in: tokens)
        let sortedText = tokens.map(\.fullText).joined()
        let selectionStart = starts[block.lowerBound]
        let selectionEnd = starts[block.upperBound] + tokens[block.upperBound].fullUTF16Length

        return TextEditCommandResult(
            text: sortedText,
            selectedRange: NSRange(location: selectionStart, length: selectionEnd - selectionStart)
        )
    }

    private static func removeDuplicateLines(
        in text: String,
        selectedRange: NSRange,
        consecutiveOnly: Bool
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        var editedText = ""
        var removedRanges: [NSRange] = []
        var seenBodies = Set<String>()
        var previousKeptBody: String?

        for line in lines {
            let body = nsText.substring(with: line.bodyRange)
            let shouldRemove: Bool
            if consecutiveOnly {
                shouldRemove = previousKeptBody == body
            } else {
                shouldRemove = seenBodies.contains(body)
            }

            if shouldRemove {
                let fullRange = line.fullRange
                if fullRange.length > 0 {
                    removedRanges.append(fullRange)
                }
            } else {
                editedText += nsText.substring(with: line.fullRange)
                previousKeptBody = body
                seenBodies.insert(body)
            }
        }

        let start = mappedLocation(range.location, afterRemoving: removedRanges)
        let end = mappedLocation(range.endLocation, afterRemoving: removedRanges)
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    private static func convertSelectionCase(
        in text: String,
        selectedRange: NSRange,
        conversion: CaseConversion
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        guard range.length > 0 else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        let nsText = text as NSString
        let selectedText = nsText.substring(with: range)
        let replacement: String
        switch conversion {
        case .uppercase:
            replacement = selectedText.uppercased()
        case .lowercase:
            replacement = selectedText.lowercased()
        case .inverted:
            replacement = selectedText.map { character in
                let text = String(character)
                let uppercased = text.uppercased()
                let lowercased = text.lowercased()

                if text == uppercased, text != lowercased {
                    return lowercased
                }
                if text == lowercased, text != uppercased {
                    return uppercased
                }
                return text
            }
            .joined()
        case .sentence:
            replacement = sentenceCased(selectedText.uppercased())
        }

        let result = mutableCopy(of: text)
        result.replaceCharacters(in: range, with: replacement)
        return TextEditCommandResult(
            text: String(result),
            selectedRange: NSRange(location: range.location, length: replacement.utf16.count)
        )
    }

    private static func containsOnlySpacesAndTabs(in text: NSString, range: NSRange) -> Bool {
        var location = range.location
        while location < range.endLocation {
            let unit = text.character(at: location)
            if unit != 32 && unit != 9 {
                return false
            }
            location += 1
        }
        return true
    }

    private static func trailingWhitespaceStart(in text: NSString, bodyRange: NSRange) -> Int {
        var location = bodyRange.endLocation
        while location > bodyRange.location {
            let unit = text.character(at: location - 1)
            if unit == 32 || unit == 9 {
                location -= 1
            } else {
                break
            }
        }
        return location
    }

    private static func sentenceCased(_ text: String) -> String {
        var shouldCapitalizeNextCasedCharacter = true
        var result = ""

        for character in text {
            let characterText = String(character)
            let uppercased = characterText.uppercased()
            let lowercased = characterText.lowercased()
            let hasCase = uppercased != lowercased

            if hasCase {
                if shouldCapitalizeNextCasedCharacter {
                    result += uppercased
                    shouldCapitalizeNextCasedCharacter = false
                } else {
                    result += lowercased
                }
            } else {
                result += characterText
            }

            if character == "." || character == "!" || character == "?" {
                shouldCapitalizeNextCasedCharacter = true
            }
        }

        return result
    }

    private static func mappedLocation(_ location: Int, afterRemoving removedRanges: [NSRange]) -> Int {
        var mapped = location
        for range in removedRanges {
            if location <= range.location {
                break
            }
            if location >= range.endLocation {
                mapped -= range.length
            } else {
                mapped -= location - range.location
            }
        }
        return max(0, mapped)
    }

    private static func clamped(_ range: NSRange, in text: String) -> NSRange {
        let textLength = text.utf16.count
        let location = min(max(0, range.location), textLength)
        let requestedEnd: Int
        if range.length < 0 {
            requestedEnd = location
        } else {
            let (end, overflow) = range.location.addingReportingOverflow(range.length)
            requestedEnd = overflow ? textLength : end
        }
        let end = min(max(location, requestedEnd), textLength)
        return NSRange(location: location, length: end - location)
    }

    private static func mutableCopy(of text: String) -> NSMutableString {
        NSMutableString(string: text)
    }
}

private struct TextEditLine: Equatable {
    let bodyRange: NSRange
    let endingRange: NSRange

    var fullRange: NSRange {
        NSRange(location: bodyRange.location, length: bodyRange.length + endingRange.length)
    }
}

private struct TextEditLineToken {
    let sourceIndex: Int
    let body: String
    var ending: String

    var fullText: String {
        body + ending
    }

    var fullUTF16Length: Int {
        body.utf16.count + ending.utf16.count
    }
}

private struct TextEditLinePosition {
    let lineIndex: Int
    let offset: Int
}

private enum LineMoveDirection {
    case up
    case down
}

private enum LineSortOrder {
    case ascending
    case descending
}

private enum CaseConversion {
    case uppercase
    case lowercase
    case inverted
    case sentence
}

private extension NSRange {
    var endLocation: Int {
        location + length
    }
}
