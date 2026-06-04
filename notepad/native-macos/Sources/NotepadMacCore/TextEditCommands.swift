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
    public static func splitLines(
        in text: String,
        selectedRange: NSRange,
        lineWidth: Int = 80
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        let width = max(1, lineWidth)
        var editedText = ""

        for (index, line) in lines.enumerated() {
            if block.contains(index) {
                let ending = lineEnding(for: line, in: nsText, defaultLineEnding: LineEnding.detect(in: text).rawValue)
                editedText += splitBody(
                    nsText.substring(with: line.bodyRange),
                    at: width,
                    with: ending
                )
                editedText += nsText.substring(with: line.endingRange)
            } else {
                editedText += nsText.substring(with: line.fullRange)
            }
        }

        let start = mappedLocationForSplit(
            range.location,
            in: lines,
            block: block,
            lineWidth: width,
            text: nsText,
            defaultLineEnding: LineEnding.detect(in: text).rawValue
        )
        let end = mappedLocationForSplit(
            range.endLocation,
            in: lines,
            block: block,
            lineWidth: width,
            text: nsText,
            defaultLineEnding: LineEnding.detect(in: text).rawValue
        )
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func transposeLine(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        guard lines.count >= 2 else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        let targetIndex = lineIndex(containing: range.location, in: lines)
        guard targetIndex > 0 else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        let currentLine = lines[targetIndex]
        let previousLine = lines[targetIndex - 1]

        var swappedLines: [TextEditLine] = lines
        swappedLines[targetIndex] = previousLine
        swappedLines[targetIndex - 1] = currentLine
        let editedText = swappedLines
            .map { nsText.substring(with: $0.fullRange) }
            .joined()

        let mappedLocation = { (location: Int) -> Int in
            switch location {
            case previousLine.fullRange.location..<previousLine.fullRange.endLocation:
                return currentLine.fullRange.location + (location - previousLine.fullRange.location)
            case currentLine.fullRange.location..<currentLine.fullRange.endLocation:
                return previousLine.fullRange.location + (location - currentLine.fullRange.location)
            default:
                return location
            }
        }

        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(
                location: mappedLocation(range.location),
                length: max(0, mappedLocation(range.endLocation) - mappedLocation(range.location))
            )
        )
    }

    public static func insertBlankLineAboveCurrentLine(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        guard !lines.isEmpty else { return TextEditCommandResult(text: text, selectedRange: range) }

        let insertionLine = line(containing: range.location, in: lines)
        let insertionIndex = insertionLine.bodyRange.location
        let insertion = LineEnding.detect(in: text).rawValue
        let editedText = nsText.replacingCharacters(in: NSRange(location: insertionIndex, length: 0), with: insertion)

        let mapped = mappedLocationForInsertions(
            in: range,
            insertedAt: insertionIndex,
            insertLength: insertion.utf16.count,
            textLength: nsText.length
        )
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: mapped.location, length: mapped.length)
        )
    }

    public static func insertBlankLineBelowCurrentLine(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        guard !lines.isEmpty else { return TextEditCommandResult(text: text, selectedRange: range) }

        let insertionLine = line(containing: range.location, in: lines)
        let insertionIndex = insertionLine.fullRange.endLocation
        let insertion = LineEnding.detect(in: text).rawValue
        let editedText = nsText.replacingCharacters(in: NSRange(location: insertionIndex, length: 0), with: insertion)

        let mapped = mappedLocationForInsertions(
            in: range,
            insertedAt: insertionIndex,
            insertLength: insertion.utf16.count,
            textLength: nsText.length
        )
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: mapped.location, length: mapped.length)
        )
    }

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

    public static func trimLeadingWhitespace(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        var trimmedText = ""
        var removedRanges: [NSRange] = []

        for (index, line) in lines.enumerated() {
            guard block.contains(index) else {
                trimmedText += nsText.substring(with: line.fullRange)
                continue
            }

            let keepStart = leadingWhitespaceEnd(in: nsText, bodyRange: line.bodyRange)
            if keepStart > line.bodyRange.location {
                removedRanges.append(
                    NSRange(location: line.bodyRange.location, length: keepStart - line.bodyRange.location)
                )
            }
            trimmedText += nsText.substring(with: NSRange(
                location: keepStart,
                length: line.bodyRange.endLocation - keepStart
            ))
            trimmedText += nsText.substring(with: line.endingRange)
        }

        let start = mappedLocation(range.location, afterRemoving: removedRanges)
        let end = mappedLocation(range.endLocation, afterRemoving: removedRanges)
        return TextEditCommandResult(
            text: trimmedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func trimLeadingAndTrailingWhitespace(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        var trimmedText = ""
        var removedRanges: [NSRange] = []

        for (index, line) in lines.enumerated() {
            guard block.contains(index) else {
                trimmedText += nsText.substring(with: line.fullRange)
                continue
            }

            let lineEnd = line.bodyRange.endLocation
            if line.bodyRange.location == lineEnd {
                trimmedText += nsText.substring(with: line.fullRange)
                continue
            }

            let leadingEnd = leadingWhitespaceEnd(in: nsText, bodyRange: line.bodyRange)
            let trailingStart = trailingWhitespaceStart(in: nsText, bodyRange: line.bodyRange)

            if leadingEnd >= trailingStart {
                removedRanges.append(line.bodyRange)
                trimmedText += nsText.substring(with: line.endingRange)
            } else {
                let keepStart = leadingEnd
                let keepLength = trailingStart - leadingEnd
                if keepStart > line.bodyRange.location {
                    removedRanges.append(
                        NSRange(
                            location: line.bodyRange.location,
                            length: keepStart - line.bodyRange.location
                        )
                    )
                }
                if keepStart < keepStart + keepLength {
                    if trailingStart < lineEnd {
                        removedRanges.append(
                            NSRange(location: trailingStart, length: lineEnd - trailingStart)
                        )
                    }
                }
                trimmedText += nsText.substring(with: NSRange(location: keepStart, length: keepLength))
                trimmedText += nsText.substring(with: line.endingRange)
            }
        }

        let start = mappedLocation(range.location, afterRemoving: removedRanges)
        let end = mappedLocation(range.endLocation, afterRemoving: removedRanges)
        return TextEditCommandResult(
            text: trimmedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func eolToWhitespace(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let effectiveRange = range.length == 0 ? NSRange(location: 0, length: text.utf16.count) : range
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = if range.length == 0 {
            0...(lines.count - 1)
        } else {
            lineBlock(containing: effectiveRange, in: lines)
        }
        var editedText = ""
        var replacements: [TextEditReplacement] = []

        for (index, line) in lines.enumerated() {
            if block.contains(index) && index < block.upperBound {
                let body = nsText.substring(with: line.bodyRange)
                editedText += body
                replacements.append(
                    TextEditReplacement(
                        sourceRange: line.endingRange,
                        replacementLength: " ".utf16.count
                    )
                )
                editedText += " "
            } else {
                editedText += nsText.substring(with: line.fullRange)
            }
        }

        let start = mapLocation(effectiveRange.location, with: replacements, inTextLength: nsText.length)
        let end = mapLocation(effectiveRange.endLocation, with: replacements, inTextLength: nsText.length)
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func trimAll(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let effectiveRange = range.length == 0 ? NSRange(location: 0, length: text.utf16.count) : range
        let bothTrimmed = trimLeadingAndTrailingWhitespace(in: text, selectedRange: effectiveRange)
        let eolWhitespace = eolToWhitespace(in: bothTrimmed.text, selectedRange: bothTrimmed.selectedRange)
        return eolWhitespace
    }

    public static func tabToSpaces(
        in text: String,
        selectedRange: NSRange,
        tabWidth: Int = 4
    ) -> TextEditCommandResult {
        convertWhitespace(
            in: text,
            selectedRange: selectedRange
        ) { body in
            tabToSpaces(in: body, tabWidth: tabWidth)
        }
    }

    public static func spaceToTabsLeading(
        in text: String,
        selectedRange: NSRange,
        tabWidth: Int = 4
    ) -> TextEditCommandResult {
        convertWhitespace(
            in: text,
            selectedRange: selectedRange
        ) { body in
            spaceToTabs(in: body, tabWidth: tabWidth, leadingOnly: true)
        }
    }

    public static func spaceToTabsAll(
        in text: String,
        selectedRange: NSRange,
        tabWidth: Int = 4
    ) -> TextEditCommandResult {
        convertWhitespace(
            in: text,
            selectedRange: selectedRange
        ) { body in
            spaceToTabs(in: body, tabWidth: tabWidth, leadingOnly: false)
        }
    }

    public static func setBlockComments(
        in text: String,
        selectedRange: NSRange,
        commentStart: String,
        commentEnd: String
    ) -> TextEditCommandResult {
        guard !commentStart.isEmpty, !commentEnd.isEmpty else {
            return TextEditCommandResult(text: text, selectedRange: clamped(selectedRange, in: text))
        }

        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        let startToken = commentStart + " "
        let endToken = " " + commentEnd
        var editedText = ""
        var replacements: [TextEditReplacement] = []

        for (index, line) in lines.enumerated() {
            guard block.contains(index) else {
                editedText += nsText.substring(with: line.fullRange)
                continue
            }

            let indentEnd = leadingWhitespaceEnd(in: nsText, bodyRange: line.bodyRange)
            if indentEnd == line.bodyRange.endLocation {
                editedText += nsText.substring(with: line.fullRange)
                continue
            }

            let indentLength = indentEnd - line.bodyRange.location
            let indent = nsText.substring(with: NSRange(location: line.bodyRange.location, length: indentLength))
            let content = nsText.substring(with: NSRange(location: indentEnd, length: line.bodyRange.endLocation - indentEnd))
            editedText += indent + startToken + content + endToken
            editedText += nsText.substring(with: line.endingRange)
            replacements.append(
                TextEditReplacement(
                    sourceRange: NSRange(location: indentEnd, length: 0),
                    replacementLength: startToken.utf16.count
                )
            )
            replacements.append(
                TextEditReplacement(
                    sourceRange: NSRange(location: line.bodyRange.endLocation, length: 0),
                    replacementLength: endToken.utf16.count
                )
            )
        }

        let start = mapLocation(range.location, with: replacements, inTextLength: nsText.length)
        let end = mapLocation(range.endLocation, with: replacements, inTextLength: nsText.length)
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func removeBlockComments(
        in text: String,
        selectedRange: NSRange,
        commentStart: String,
        commentEnd: String
    ) -> TextEditCommandResult {
        guard !commentStart.isEmpty, !commentEnd.isEmpty else {
            return TextEditCommandResult(text: text, selectedRange: clamped(selectedRange, in: text))
        }

        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        var editedText = ""
        var replacements: [TextEditReplacement] = []

        for (index, line) in lines.enumerated() {
            guard block.contains(index) else {
                editedText += nsText.substring(with: line.fullRange)
                continue
            }

            let indentEnd = leadingWhitespaceEnd(in: nsText, bodyRange: line.bodyRange)
            let body = nsText.substring(with: line.bodyRange)
            let bodyUTF16Length = (body as NSString).length
            let startLength = blockCommentStartRemovalLength(
                in: body,
                indentUTF16Offset: indentEnd - line.bodyRange.location,
                commentStart: commentStart
            )
            let endLength = blockCommentEndRemovalLength(in: body, commentEnd: commentEnd)

            if let startLength, let endLength,
               indentEnd - line.bodyRange.location + startLength <= bodyUTF16Length - endLength {
                let indentLength = indentEnd - line.bodyRange.location
                let keepStart = indentLength
                let middleStart = keepStart + startLength
                let middleEnd = bodyUTF16Length - endLength
                let indent = (body as NSString).substring(with: NSRange(location: 0, length: keepStart))
                let content = (body as NSString).substring(with: NSRange(location: middleStart, length: middleEnd - middleStart))
                editedText += indent + content
                editedText += nsText.substring(with: line.endingRange)

                replacements.append(
                    TextEditReplacement(
                        sourceRange: NSRange(location: indentEnd, length: startLength),
                        replacementLength: 0
                    )
                )
                replacements.append(
                    TextEditReplacement(
                        sourceRange: NSRange(
                            location: line.bodyRange.endLocation - endLength,
                            length: endLength
                        ),
                        replacementLength: 0
                    )
                )
            } else {
                editedText += nsText.substring(with: line.fullRange)
            }
        }

        let start = mapLocation(range.location, with: replacements, inTextLength: nsText.length)
        let end = mapLocation(range.endLocation, with: replacements, inTextLength: nsText.length)
        return TextEditCommandResult(
            text: editedText,
            selectedRange: NSRange(location: start, length: max(0, end - start))
        )
    }

    public static func streamComment(
        in text: String,
        selectedRange: NSRange,
        commentStart: String,
        commentEnd: String
    ) -> TextEditCommandResult {
        guard !commentStart.isEmpty, !commentEnd.isEmpty else {
            return TextEditCommandResult(text: text, selectedRange: clamped(selectedRange, in: text))
        }

        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let effectiveRange: NSRange
        if range.length == 0 {
            let currentLine = line(containing: range.location, in: splitLines(in: nsText))
            let lineStart = leadingWhitespaceEnd(in: nsText, bodyRange: currentLine.bodyRange)
            effectiveRange = NSRange(location: lineStart, length: currentLine.bodyRange.endLocation - lineStart)
        } else {
            effectiveRange = range
        }

        let startToken = commentStart + " "
        let endToken = " " + commentEnd
        let result = mutableCopy(of: text)
        result.insert(startToken, at: effectiveRange.location)
        result.insert(endToken, at: effectiveRange.endLocation + startToken.utf16.count)

        return TextEditCommandResult(
            text: String(result),
            selectedRange: NSRange(
                location: effectiveRange.location + startToken.utf16.count,
                length: effectiveRange.length
            )
        )
    }

    public static func streamUncomment(
        in text: String,
        selectedRange: NSRange,
        commentStart: String,
        commentEnd: String
    ) -> TextEditCommandResult {
        guard !commentStart.isEmpty, !commentEnd.isEmpty else {
            return TextEditCommandResult(text: text, selectedRange: clamped(selectedRange, in: text))
        }

        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        guard let pair = findStreamCommentPair(
            in: nsText,
            selection: range,
            commentStart: commentStart,
            commentEnd: commentEnd
        ) else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        let result = mutableCopy(of: text)
        result.deleteCharacters(in: pair.endRange)
        result.deleteCharacters(in: pair.startRange)
        let replacements = [
            TextEditReplacement(sourceRange: pair.startRange, replacementLength: 0),
            TextEditReplacement(sourceRange: pair.endRange, replacementLength: 0)
        ]
        let start = mapLocation(range.location, with: replacements, inTextLength: nsText.length)
        let end = mapLocation(range.endLocation, with: replacements, inTextLength: nsText.length)
        return TextEditCommandResult(
            text: String(result),
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

    public static func sortSelectedLinesAsIntegersAscending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByNumber(
            in: text,
            selectedRange: selectedRange,
            allowedCharacters: Set(" \t-0123456789")
        ) { Int64($0) }
    }

    public static func sortSelectedLinesAsIntegersDescending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByNumber(
            in: text,
            selectedRange: selectedRange,
            order: .descending,
            allowedCharacters: Set(" \t-0123456789")
        ) { Int64($0) }
    }

    public static func sortSelectedLinesAsDecimalCommaAscending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByNumber(
            in: text,
            selectedRange: selectedRange,
            allowedCharacters: Set(" \t-0123456789,")
        ) { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }

    public static func sortSelectedLinesAsDecimalCommaDescending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByNumber(
            in: text,
            selectedRange: selectedRange,
            order: .descending,
            allowedCharacters: Set(" \t-0123456789,")
        ) { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }

    public static func sortSelectedLinesAsDecimalDotAscending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByNumber(
            in: text,
            selectedRange: selectedRange,
            allowedCharacters: Set(" \t-0123456789.")
        ) { Double($0) }
    }

    public static func sortSelectedLinesAsDecimalDotDescending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByNumber(
            in: text,
            selectedRange: selectedRange,
            order: .descending,
            allowedCharacters: Set(" \t-0123456789.")
        ) { Double($0) }
    }

    public static func reverseSelectedLines(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        sortSelectedLineTokens(in: text, selectedRange: selectedRange) { tokens in
            Array(tokens.reversed())
        }
    }

    public static func randomizeSelectedLines(
        in text: String,
        selectedRange: NSRange,
        randomKey: () -> Int = { Int.random(in: Int.min...Int.max) }
    ) -> TextEditCommandResult {
        sortSelectedLineTokens(in: text, selectedRange: selectedRange) { tokens in
            tokens.enumerated().map { (offset: $0.offset, token: $0.element, key: randomKey()) }
                .sorted { lhs, rhs in
                    if lhs.key == rhs.key {
                        return lhs.offset < rhs.offset
                    }
                    return lhs.key < rhs.key
                }
                .map(\.token)
        }
    }

    public static func sortSelectedLinesCaseInsensitiveAscending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesCaseInsensitive(in: text, selectedRange: selectedRange, order: .ascending)
    }

    public static func sortSelectedLinesCaseInsensitiveDescending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesCaseInsensitive(in: text, selectedRange: selectedRange, order: .descending)
    }

    public static func sortSelectedLinesInLocaleAscending(
        in text: String,
        selectedRange: NSRange,
        locale: Locale = .current
    ) -> TextEditCommandResult {
        sortSelectedLinesInLocale(in: text, selectedRange: selectedRange, order: .ascending, locale: locale)
    }

    public static func sortSelectedLinesInLocaleDescending(
        in text: String,
        selectedRange: NSRange,
        locale: Locale = .current
    ) -> TextEditCommandResult {
        sortSelectedLinesInLocale(in: text, selectedRange: selectedRange, order: .descending, locale: locale)
    }

    public static func sortSelectedLinesByLengthAscending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByLength(in: text, selectedRange: selectedRange, order: .ascending)
    }

    public static func sortSelectedLinesByLengthDescending(
        in text: String,
        selectedRange: NSRange
    ) -> TextEditCommandResult {
        sortSelectedLinesByLength(in: text, selectedRange: selectedRange, order: .descending)
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

    public static func properCaseSelection(in text: String, selectedRange: NSRange) -> TextEditCommandResult {
        convertSelectionCase(in: text, selectedRange: selectedRange, conversion: .proper)
    }

    public static func randomCaseSelection(
        in text: String,
        selectedRange: NSRange,
        randomBit: () -> Bool = { Bool.random() }
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        guard range.length > 0 else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        let nsText = text as NSString
        let selectedText = nsText.substring(with: range)
        let replacement = selectedText.map { character -> String in
            let characterText = String(character)
            let uppercased = characterText.uppercased()
            let lowercased = characterText.lowercased()
            let hasCase = uppercased != lowercased

            guard hasCase else { return characterText }
            return randomBit() ? uppercased : lowercased
        }
        .joined()

        let result = mutableCopy(of: text)
        result.replaceCharacters(in: range, with: replacement)
        return TextEditCommandResult(
            text: String(result),
            selectedRange: NSRange(location: range.location, length: replacement.utf16.count)
        )
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

    private static func sortSelectedLinesByNumber<T: Comparable>(
        in text: String,
        selectedRange: NSRange,
        order: LineSortOrder = .ascending,
        allowedCharacters: Set<Character>,
        parse: (String) -> T?
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        guard block.lowerBound < block.upperBound else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        var tokens = lineTokens(from: lines, in: nsText)
        let selectedTokens = Array(tokens[block])
        var blankTokens: [TextEditLineToken] = []
        var numericTokens: [(offset: Int, token: TextEditLineToken, value: T)] = []

        for (offset, token) in selectedTokens.enumerated() {
            let prepared = String(token.body.prefix { allowedCharacters.contains($0) })
            let trimmed = prepared.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                blankTokens.append(token)
                continue
            }

            guard let value = parse(trimmed) else {
                return TextEditCommandResult(text: text, selectedRange: range)
            }
            numericTokens.append((offset: offset, token: token, value: value))
        }

        numericTokens.sort { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.offset < rhs.offset
            }
            switch order {
            case .ascending:
                return lhs.value < rhs.value
            case .descending:
                return lhs.value > rhs.value
            }
        }

        let sortedBlockTokens = switch order {
        case .ascending:
            blankTokens + numericTokens.map(\.token)
        case .descending:
            numericTokens.map(\.token) + blankTokens
        }

        tokens.replaceSubrange(block, with: sortedBlockTokens)
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

    private static func sortSelectedLinesByLength(
        in text: String,
        selectedRange: NSRange,
        order: LineSortOrder
    ) -> TextEditCommandResult {
        sortSelectedLineTokens(in: text, selectedRange: selectedRange) { tokens in
            tokens.enumerated().sorted { lhs, rhs in
                let lhsLength = lhs.element.body.utf16.count
                let rhsLength = rhs.element.body.utf16.count

                if lhsLength == rhsLength {
                    return lhs.offset < rhs.offset
                }

                switch order {
                case .ascending:
                    return lhsLength < rhsLength
                case .descending:
                    return lhsLength > rhsLength
                }
            }
            .map(\.element)
        }
    }

    private static func sortSelectedLinesCaseInsensitive(
        in text: String,
        selectedRange: NSRange,
        order: LineSortOrder
    ) -> TextEditCommandResult {
        sortSelectedLineTokens(in: text, selectedRange: selectedRange) { tokens in
            tokens.enumerated().sorted { lhs, rhs in
                let lhsValue = lhs.element.body.lowercased()
                let rhsValue = rhs.element.body.lowercased()

                if lhsValue == rhsValue {
                    return lhs.offset < rhs.offset
                }

                switch order {
                case .ascending:
                    return lhsValue < rhsValue
                case .descending:
                    return lhsValue > rhsValue
                }
            }
            .map(\.element)
        }
    }

    private static func sortSelectedLinesInLocale(
        in text: String,
        selectedRange: NSRange,
        order: LineSortOrder,
        locale: Locale
    ) -> TextEditCommandResult {
        sortSelectedLineTokens(in: text, selectedRange: selectedRange) { tokens in
            tokens.enumerated().sorted { lhs, rhs in
                let comparison = lhs.element.body.compare(
                    rhs.element.body,
                    options: [.caseInsensitive, .numeric],
                    range: nil,
                    locale: locale
                )

                if comparison == .orderedSame {
                    return lhs.offset < rhs.offset
                }

                switch order {
                case .ascending:
                    return comparison == .orderedAscending
                case .descending:
                    return comparison == .orderedDescending
                }
            }
            .map(\.element)
        }
    }

    private static func sortSelectedLineTokens(
        in text: String,
        selectedRange: NSRange,
        transform: ([TextEditLineToken]) -> [TextEditLineToken]
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = lineBlock(containing: range, in: lines)
        guard block.lowerBound < block.upperBound else {
            return TextEditCommandResult(text: text, selectedRange: range)
        }

        var tokens = lineTokens(from: lines, in: nsText)
        let selectedTokens = Array(tokens[block])
        let transformedTokens = transform(selectedTokens)
        tokens.replaceSubrange(block, with: transformedTokens)
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

    private static func convertWhitespace(
        in text: String,
        selectedRange: NSRange,
        transform: (String) -> TextEditBodyTransform
    ) -> TextEditCommandResult {
        let range = clamped(selectedRange, in: text)
        let nsText = text as NSString
        let lines = splitLines(in: nsText)
        let block = range.length == 0
            ? 0...(lines.count - 1)
            : lineBlock(containing: range, in: lines)
        var editedText = ""
        var replacements: [TextEditReplacement] = []

        for (index, line) in lines.enumerated() {
            guard block.contains(index) else {
                editedText += nsText.substring(with: line.fullRange)
                continue
            }

            let body = nsText.substring(with: line.bodyRange)
            let transformed = transform(body)
            editedText += transformed.text
            editedText += nsText.substring(with: line.endingRange)
            replacements.append(
                contentsOf: transformed.replacements.map { replacement in
                    TextEditReplacement(
                        sourceRange: NSRange(
                            location: line.bodyRange.location + replacement.sourceRange.location,
                            length: replacement.sourceRange.length
                        ),
                        replacementLength: replacement.replacementLength
                    )
                }
            )
        }

        let start = mapLocation(range.location, with: replacements, inTextLength: nsText.length)
        let end = mapLocation(range.endLocation, with: replacements, inTextLength: nsText.length)
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
        case .proper:
            replacement = properCased(selectedText.uppercased())
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

    private static func leadingWhitespaceEnd(in text: NSString, bodyRange: NSRange) -> Int {
        var location = bodyRange.location
        while location < bodyRange.endLocation {
            let unit = text.character(at: location)
            if unit == 32 || unit == 9 {
                location += 1
            } else {
                break
            }
        }
        return location
    }

    private static func splitBody(
        _ body: String,
        at lineWidth: Int,
        with lineEnding: String
    ) -> String {
        let nsBody = body as NSString
        guard nsBody.length > lineWidth else { return body }

        let splitLength = max(1, lineWidth)
        var splitBody = ""
        var location = 0

        while location < nsBody.length {
            let pieceLength = min(splitLength, nsBody.length - location)
            let piece = nsBody.substring(with: NSRange(location: location, length: pieceLength))
            splitBody += piece

            location += pieceLength
            if location < nsBody.length {
                splitBody += lineEnding
            }
        }

        return splitBody
    }

    private static func lineEnding(for line: TextEditLine, in text: NSString, defaultLineEnding: String) -> String {
        if line.endingRange.length > 0 {
            return text.substring(with: line.endingRange)
        }

        return defaultLineEnding
    }

    private static func tabToSpaces(in body: String, tabWidth: Int) -> TextEditBodyTransform {
        let width = max(1, tabWidth)
        let nsBody = body as NSString
        var transformed = ""
        var replacements: [TextEditReplacement] = []
        var column = 0
        var location = 0

        while location < nsBody.length {
            let unit = nsBody.character(at: location)
            if unit == 9 {
                let spaceCount = width - (column % width)
                transformed += String(repeating: " ", count: spaceCount)
                replacements.append(
                    TextEditReplacement(
                        sourceRange: NSRange(location: location, length: 1),
                        replacementLength: spaceCount
                    )
                )
                column += spaceCount
            } else {
                transformed += nsBody.substring(with: NSRange(location: location, length: 1))
                column += 1
            }
            location += 1
        }

        return TextEditBodyTransform(text: transformed, replacements: replacements)
    }

    private static func spaceToTabs(
        in body: String,
        tabWidth: Int,
        leadingOnly: Bool
    ) -> TextEditBodyTransform {
        let width = max(1, tabWidth)
        let nsBody = body as NSString
        var transformed = ""
        var replacements: [TextEditReplacement] = []
        var column = 0
        var location = 0
        var withinIndentation = true

        while location < nsBody.length {
            let unit = nsBody.character(at: location)

            if unit == 32, withinIndentation || !leadingOnly {
                let runStart = location
                let runColumn = column

                while location < nsBody.length, nsBody.character(at: location) == 32 {
                    location += 1
                    column += 1
                }

                let runLength = location - runStart
                let replacement = tabifiedSpaces(
                    count: runLength,
                    startingColumn: runColumn,
                    tabWidth: width
                )
                transformed += replacement

                if replacement != String(repeating: " ", count: runLength) {
                    replacements.append(
                        TextEditReplacement(
                            sourceRange: NSRange(location: runStart, length: runLength),
                            replacementLength: replacement.utf16.count
                        )
                    )
                }
                continue
            }

            transformed += nsBody.substring(with: NSRange(location: location, length: 1))

            if unit == 9 {
                column += width - (column % width)
            } else {
                column += 1
                if leadingOnly, unit != 32 {
                    withinIndentation = false
                }
            }

            location += 1
        }

        return TextEditBodyTransform(text: transformed, replacements: replacements)
    }

    private static func tabifiedSpaces(
        count: Int,
        startingColumn: Int,
        tabWidth: Int
    ) -> String {
        guard count > 0 else { return "" }

        var remaining = count
        var column = startingColumn
        var transformed = ""

        while remaining > 0 {
            let spacesToNextStop = tabWidth - (column % tabWidth)
            if spacesToNextStop > 1, remaining >= spacesToNextStop {
                transformed += "\t"
                remaining -= spacesToNextStop
                column += spacesToNextStop
            } else {
                transformed += " "
                remaining -= 1
                column += 1
            }
        }

        return transformed
    }

    private static func blockCommentStartRemovalLength(
        in body: String,
        indentUTF16Offset: Int,
        commentStart: String
    ) -> Int? {
        let afterIndent = (body as NSString).substring(from: indentUTF16Offset)
        let spaced = commentStart + " "
        if afterIndent.hasPrefix(spaced) {
            return spaced.utf16.count
        }
        if afterIndent.hasPrefix(commentStart) {
            return commentStart.utf16.count
        }
        return nil
    }

    private static func blockCommentEndRemovalLength(in body: String, commentEnd: String) -> Int? {
        let spaced = " " + commentEnd
        if body.hasSuffix(spaced) {
            return spaced.utf16.count
        }
        if body.hasSuffix(commentEnd) {
            return commentEnd.utf16.count
        }
        return nil
    }

    private static func findStreamCommentPair(
        in text: NSString,
        selection: NSRange,
        commentStart: String,
        commentEnd: String
    ) -> TextEditCommentPair? {
        let startCandidates = [commentStart + " ", commentStart]
        let endCandidates = [" " + commentEnd, commentEnd]
        let searchLocation = min(selection.location, text.length)

        for startToken in startCandidates {
            let startRange = text.range(
                of: startToken,
                options: .backwards,
                range: NSRange(location: 0, length: searchLocation + 1)
            )
            guard startRange.location != NSNotFound else { continue }

            for endToken in endCandidates {
                let startOfEndSearch = startRange.endLocation
                guard startOfEndSearch <= text.length else { continue }
                let endSearchRange = NSRange(location: startOfEndSearch, length: text.length - startOfEndSearch)
                let endRange = text.range(of: endToken, options: [], range: endSearchRange)
                guard endRange.location != NSNotFound else { continue }

                let fullRange = NSRange(
                    location: startRange.location,
                    length: endRange.endLocation - startRange.location
                )
                if selection.location >= fullRange.location && selection.endLocation <= fullRange.endLocation {
                    return TextEditCommentPair(startRange: startRange, endRange: endRange)
                }
            }
        }

        return nil
    }

    private static func splitInsertions(
        for lineWidth: Int,
        bodyLength: Int
    ) -> Int {
        if bodyLength <= lineWidth {
            return 0
        }

        return max(0, (bodyLength - 1) / lineWidth)
    }

    private static func splitInsertions(
        before location: Int,
        lineWidth: Int,
        bodyLength: Int
    ) -> Int {
        if bodyLength <= lineWidth {
            return 0
        }

        if location <= 0 {
            return 0
        }

        if location >= bodyLength {
            return splitInsertions(for: lineWidth, bodyLength: bodyLength)
        }

        return location / lineWidth
    }

    private static func mappedLocationForSplit(
        _ location: Int,
        in lines: [TextEditLine],
        block: ClosedRange<Int>,
        lineWidth: Int,
        text: NSString,
        defaultLineEnding: String
    ) -> Int {
        var mapped = 0

        for (index, line) in lines.enumerated() {
            let sourceRange = line.fullRange
            let isSplitLine = block.contains(index)

            if location <= sourceRange.location {
                return mapped
            }

            if isSplitLine {
                let lineEnding = lineEnding(for: line, in: text, defaultLineEnding: defaultLineEnding)
                let bodyLength = line.bodyRange.length
                let insertedLength = splitInsertions(for: lineWidth, bodyLength: bodyLength)
                let splitBodyLength = line.bodyRange.length + (insertedLength * lineEnding.utf16.count)

                if location < line.bodyRange.endLocation {
                    let localOffset = location - line.bodyRange.location
                    let addedSplitLength = splitInsertions(
                        before: localOffset,
                        lineWidth: lineWidth,
                        bodyLength: bodyLength
                    ) * lineEnding.utf16.count
                    return mapped + localOffset + addedSplitLength
                }

                if location <= sourceRange.endLocation {
                    let localOffset = location - line.bodyRange.endLocation
                    return mapped + splitBodyLength + localOffset
                }

                mapped += splitBodyLength + line.endingRange.length
                continue
            }

            if location <= sourceRange.endLocation {
                return mapped + max(0, location - sourceRange.location)
            }

            mapped += sourceRange.length
        }

        return text.length
    }

    private static func mappedLocationForInsertions(
        in sourceRange: NSRange,
        insertedAt sourceInsertionAt: Int,
        insertLength: Int,
        textLength: Int
    ) -> NSRange {
        let newTextLength = textLength + insertLength
        let mappedStart = sourceRange.location >= sourceInsertionAt
            ? min(sourceRange.location + insertLength, newTextLength)
            : sourceRange.location
        let mappedEnd = sourceRange.endLocation >= sourceInsertionAt
            ? min(sourceRange.endLocation + insertLength, newTextLength)
            : sourceRange.endLocation

        return NSRange(location: mappedStart, length: max(0, mappedEnd - mappedStart))
    }

    private static func mapLocation(
        _ location: Int,
        with replacements: [TextEditReplacement],
        inTextLength: Int
    ) -> Int {
        let clampedLocation = min(max(location, 0), inTextLength)
        var replacementDelta = 0

        for replacement in replacements {
            let sourceStart = replacement.sourceRange.location
            let sourceEnd = replacement.sourceRange.endLocation

            if clampedLocation <= sourceStart {
                return clampedLocation + replacementDelta
            }

            if clampedLocation <= sourceEnd {
                return sourceStart + replacement.replacementLength + replacementDelta
            }

            replacementDelta += replacement.replacementLength - replacement.sourceRange.length
        }

        return clampedLocation + replacementDelta
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

    private static func properCased(_ text: String) -> String {
        let characters = Array(text)
        var result = ""

        for (index, character) in characters.enumerated() {
            let characterText = String(character)
            let uppercased = characterText.uppercased()
            let lowercased = characterText.lowercased()
            let hasCase = uppercased != lowercased

            guard hasCase else {
                result += characterText
                continue
            }

            let followsWordApostrophe = index >= 2
                && isSingleQuote(characters[index - 1])
                && isAlphaNumeric(characters[index - 2])
            let startsWord = index == 0 || !isAlphaNumeric(characters[index - 1])

            if followsWordApostrophe {
                result += lowercased
            } else if startsWord {
                result += uppercased
            } else {
                result += lowercased
            }
        }

        return result
    }

    private static func isSingleQuote(_ character: Character) -> Bool {
        character == "'" || character == "’"
    }

    private static func isAlphaNumeric(_ character: Character) -> Bool {
        character.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
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

    // MARK: - Select between delimiters

    /// Returns the selection range of content between the nearest enclosing delimiter pair.
    ///
    /// If `left` and `right` are empty, treats whitespace characters as delimiters
    /// (selects the current "word/token" bounded by whitespace).
    /// Searches outward from the current caret or selection for the nearest matching pair.
    ///
    /// - Returns: The new selection range (excluding delimiters themselves), or `nil` if no pair found.
    public static func selectBetweenDelimiters(
        in text: String,
        from selection: NSRange,
        left: String,
        right: String
    ) -> NSRange? {
        let ns = text as NSString
        let len = ns.length
        guard len > 0 else { return nil }

        let caretPos = max(0, min(selection.location, len))

        if left.isEmpty || right.isEmpty {
            // Whitespace-delimited: select token around caret
            var start = caretPos
            var end = caretPos
            // Expand left past non-whitespace
            while start > 0 {
                let ch = ns.character(at: start - 1)
                guard let s = Unicode.Scalar(ch), !CharacterSet.whitespaces.contains(s) else { break }
                start -= 1
            }
            // Expand right past non-whitespace
            while end < len {
                let ch = ns.character(at: end)
                guard let s = Unicode.Scalar(ch), !CharacterSet.whitespaces.contains(s) else { break }
                end += 1
            }
            guard end > start else { return nil }
            return NSRange(location: start, length: end - start)
        }

        let leftLen = (left as NSString).length
        let rightLen = (right as NSString).length

        // Search backward from caret for left delimiter
        var leftPos = -1
        var searchFrom = caretPos
        while searchFrom >= leftLen {
            let candidateRange = NSRange(location: searchFrom - leftLen, length: leftLen)
            if ns.substring(with: candidateRange) == left {
                leftPos = searchFrom - leftLen
                break
            }
            searchFrom -= 1
        }
        guard leftPos >= 0 else { return nil }

        // Search forward from left delimiter end for right delimiter
        var rightPos = -1
        var searchRight = leftPos + leftLen
        while searchRight + rightLen <= len {
            let candidateRange = NSRange(location: searchRight, length: rightLen)
            if ns.substring(with: candidateRange) == right {
                rightPos = searchRight
                break
            }
            searchRight += 1
        }
        guard rightPos > leftPos else { return nil }

        let contentStart = leftPos + leftLen
        let contentLength = rightPos - contentStart
        guard contentLength >= 0 else { return nil }
        return NSRange(location: contentStart, length: contentLength)
    }
}

private struct TextEditLine: Equatable {
    let bodyRange: NSRange
    let endingRange: NSRange

    var fullRange: NSRange {
        NSRange(location: bodyRange.location, length: bodyRange.length + endingRange.length)
    }
}

private struct TextEditReplacement {
    let sourceRange: NSRange
    let replacementLength: Int
}

private struct TextEditBodyTransform {
    let text: String
    let replacements: [TextEditReplacement]
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

private struct TextEditCommentPair {
    let startRange: NSRange
    let endRange: NSRange
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
    case proper
}

private extension NSRange {
    var endLocation: Int {
        location + length
    }
}
