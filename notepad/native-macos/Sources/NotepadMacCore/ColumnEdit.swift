import Foundation

public struct ColumnEditResult: Equatable, Sendable {
    public let text: String
    public let insertedRanges: [NSRange]

    public init(text: String, insertedRanges: [NSRange]) {
        self.text = text
        self.insertedRanges = insertedRanges
    }
}

public enum ColumnEditError: Error, Equatable, Sendable {
    case invalidColumn
    case invalidLineRange
    case lineRangeOutsideDocument
    case invalidRepeatCount
    case numberSequenceOverflow
}

public enum ColumnNumberFormat: Equatable, Sendable {
    case decimal
    case hexadecimal(uppercase: Bool)
    case octal
    case binary
}

public enum ColumnNumberPadding: Equatable, Sendable {
    case none
    case zeros(width: Int)
    case spaces(width: Int)
}

public struct ColumnNumberOptions: Equatable, Sendable {
    public let initial: Int
    public let increment: Int
    public let repeatCount: Int
    public let format: ColumnNumberFormat
    public let padding: ColumnNumberPadding

    public init(
        initial: Int,
        increment: Int,
        repeatCount: Int = 1,
        format: ColumnNumberFormat = .decimal,
        padding: ColumnNumberPadding = .none
    ) {
        self.initial = initial
        self.increment = increment
        self.repeatCount = repeatCount
        self.format = format
        self.padding = padding
    }
}

public enum ColumnEdit {
    public static func insertText(
        _ insertion: String,
        into text: String,
        lineRange: ClosedRange<Int>,
        column: Int
    ) throws -> ColumnEditResult {
        guard column > 0 else {
            throw ColumnEditError.invalidColumn
        }
        guard lineRange.lowerBound > 0, lineRange.lowerBound <= lineRange.upperBound else {
            throw ColumnEditError.invalidLineRange
        }

        var lines = splitLinesPreservingEndings(text)
        guard lineRange.upperBound <= lines.count else {
            throw ColumnEditError.lineRangeOutsideDocument
        }

        var insertedRanges: [NSRange] = []
        for lineNumber in lineRange {
            let index = lineNumber - 1
            let line = lines[index]
            let targetOffset = column - 1
            let bodyCount = line.body.count
            let padding = String(repeating: " ", count: max(0, targetOffset - bodyCount))
            let paddedBody = line.body + padding
            let insertionIndex = paddedBody.index(paddedBody.startIndex, offsetBy: targetOffset)
            let prefix = String(paddedBody[..<insertionIndex])
            let suffix = String(paddedBody[insertionIndex...])

            lines[index] = PreservedLine(body: prefix + insertion + suffix, ending: line.ending)
        }

        var rebuilt = ""
        var utf16Location = 0
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            if lineRange.contains(lineNumber) {
                let insertedLocation = utf16Location + min(column - 1, line.body.utf16.count)
                insertedRanges.append(NSRange(location: insertedLocation, length: insertion.utf16.count))
            }
            rebuilt += line.body
            rebuilt += line.ending
            utf16Location = rebuilt.utf16.count
        }

        return ColumnEditResult(text: rebuilt, insertedRanges: insertedRanges)
    }

    public static func insertNumberSequence(
        into text: String,
        lineRange: ClosedRange<Int>,
        column: Int,
        options: ColumnNumberOptions
    ) throws -> ColumnEditResult {
        guard options.repeatCount > 0 else {
            throw ColumnEditError.invalidRepeatCount
        }
        guard column > 0 else {
            throw ColumnEditError.invalidColumn
        }
        guard lineRange.lowerBound > 0, lineRange.lowerBound <= lineRange.upperBound else {
            throw ColumnEditError.invalidLineRange
        }

        var lines = splitLinesPreservingEndings(text)
        guard lineRange.upperBound <= lines.count else {
            throw ColumnEditError.lineRangeOutsideDocument
        }

        var insertedRanges: [NSRange] = []
        for lineNumber in lineRange {
            let sequenceIndex = (lineNumber - lineRange.lowerBound) / options.repeatCount
            let value = try sequenceValue(at: sequenceIndex, options: options)
            let insertion = format(value, options: options)

            let index = lineNumber - 1
            let line = lines[index]
            let targetOffset = column - 1
            let bodyCount = line.body.count
            let padding = String(repeating: " ", count: max(0, targetOffset - bodyCount))
            let paddedBody = line.body + padding
            let insertionIndex = paddedBody.index(paddedBody.startIndex, offsetBy: targetOffset)
            let prefix = String(paddedBody[..<insertionIndex])
            let suffix = String(paddedBody[insertionIndex...])

            lines[index] = PreservedLine(body: prefix + insertion + suffix, ending: line.ending)
        }

        var rebuilt = ""
        var utf16Location = 0
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            if lineRange.contains(lineNumber) {
                let sequenceIndex = (lineNumber - lineRange.lowerBound) / options.repeatCount
                let value = try sequenceValue(at: sequenceIndex, options: options)
                let insertion = format(value, options: options)
                let insertedLocation = utf16Location + min(column - 1, line.body.utf16.count)
                insertedRanges.append(NSRange(location: insertedLocation, length: insertion.utf16.count))
            }
            rebuilt += line.body
            rebuilt += line.ending
            utf16Location = rebuilt.utf16.count
        }

        return ColumnEditResult(text: rebuilt, insertedRanges: insertedRanges)
    }

    private static func sequenceValue(at index: Int, options: ColumnNumberOptions) throws -> Int {
        let (offset, multipliedOverflow) = index.multipliedReportingOverflow(by: options.increment)
        guard !multipliedOverflow else {
            throw ColumnEditError.numberSequenceOverflow
        }

        let (value, addedOverflow) = options.initial.addingReportingOverflow(offset)
        guard !addedOverflow else {
            throw ColumnEditError.numberSequenceOverflow
        }
        return value
    }

    private static func format(_ value: Int, options: ColumnNumberOptions) -> String {
        let sign = value < 0 ? "-" : ""
        let magnitude = unsignedMagnitude(of: value)
        let raw: String

        switch options.format {
        case .decimal:
            raw = String(magnitude, radix: 10)
        case let .hexadecimal(uppercase):
            let text = String(magnitude, radix: 16)
            raw = uppercase ? text.uppercased() : text.lowercased()
        case .octal:
            raw = String(magnitude, radix: 8)
        case .binary:
            raw = String(magnitude, radix: 2)
        }

        let unsigned = applyPadding(to: raw, padding: options.padding)
        return sign + unsigned
    }

    private static func unsignedMagnitude(of value: Int) -> UInt {
        if value == Int.min {
            return UInt(Int.max) + 1
        }
        return UInt(abs(value))
    }

    private static func applyPadding(to text: String, padding: ColumnNumberPadding) -> String {
        switch padding {
        case .none:
            return text
        case let .zeros(width):
            return String(repeating: "0", count: max(0, width - text.count)) + text
        case let .spaces(width):
            return String(repeating: " ", count: max(0, width - text.count)) + text
        }
    }

    private static func splitLinesPreservingEndings(_ text: String) -> [PreservedLine] {
        guard !text.isEmpty else {
            return [PreservedLine(body: "", ending: "")]
        }

        var lines: [PreservedLine] = []
        var bodyStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if String(character) == "\r\n" {
                lines.append(PreservedLine(body: String(text[bodyStart..<index]), ending: "\r\n"))
                index = text.index(after: index)
                bodyStart = index
            } else if character == "\n" {
                lines.append(PreservedLine(body: String(text[bodyStart..<index]), ending: "\n"))
                index = text.index(after: index)
                bodyStart = index
            } else if character == "\r" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    lines.append(PreservedLine(body: String(text[bodyStart..<index]), ending: "\r\n"))
                    index = text.index(after: next)
                } else {
                    lines.append(PreservedLine(body: String(text[bodyStart..<index]), ending: "\r"))
                    index = next
                }
                bodyStart = index
            } else {
                index = text.index(after: index)
            }
        }

        if bodyStart < text.endIndex {
            lines.append(PreservedLine(body: String(text[bodyStart..<text.endIndex]), ending: ""))
        }

        return lines.isEmpty ? [PreservedLine(body: "", ending: "")] : lines
    }
}

private struct PreservedLine: Equatable {
    var body: String
    var ending: String
}
