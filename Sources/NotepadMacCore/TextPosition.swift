import Foundation

public struct TextPosition: Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func lineAndColumn(in text: String, utf16Location: Int) -> TextPosition {
        let nsText = text as NSString
        let selectedLocation = min(max(0, utf16Location), nsText.length)
        guard selectedLocation > 0 else {
            return TextPosition(line: 1, column: 1)
        }

        var line = 1
        var lineStart = 0
        var location = 0

        while location < selectedLocation {
            let range = nsText.rangeOfComposedCharacterSequence(at: location)
            let fragment = nsText.substring(with: range)

            if fragment == "\r" {
                let nextLocation = range.upperBound
                if nextLocation < selectedLocation,
                   nextLocation < nsText.length,
                   nsText.substring(with: NSRange(location: nextLocation, length: 1)) == "\n" {
                    line += 1
                    lineStart = nextLocation + 1
                    location = nextLocation + 1
                } else {
                    line += 1
                    lineStart = range.upperBound
                    location = range.upperBound
                }
            } else if fragment == "\n" {
                line += 1
                lineStart = range.upperBound
                location = range.upperBound
            } else {
                location = range.upperBound
            }
        }

        return TextPosition(line: line, column: selectedLocation - lineStart + 1)
    }

    public static func lineAndCharacterColumn(in text: String, utf16Location: Int) -> TextPosition {
        let nsText = text as NSString
        let selectedLocation = min(max(0, utf16Location), nsText.length)
        guard selectedLocation > 0 else {
            return TextPosition(line: 1, column: 1)
        }

        var line = 1
        var column = 1
        var location = 0

        while location < selectedLocation {
            let range = nsText.rangeOfComposedCharacterSequence(at: location)
            let fragment = nsText.substring(with: range)

            if fragment == "\r" {
                let nextLocation = range.upperBound
                if nextLocation < selectedLocation,
                   nextLocation < nsText.length,
                   nsText.substring(with: NSRange(location: nextLocation, length: 1)) == "\n" {
                    line += 1
                    column = 1
                    location = nextLocation + 1
                } else {
                    line += 1
                    column = 1
                    location = range.upperBound
                }
            } else if fragment == "\n" {
                line += 1
                column = 1
                location = range.upperBound
            } else {
                if range.upperBound > selectedLocation {
                    break
                }
                column += 1
                location = range.upperBound
            }
        }

        return TextPosition(line: line, column: column)
    }
}
