import Foundation

public enum TextStatistics {
    public struct Summary: Equatable, Sendable {
        public let utf16CharacterCount: Int
        public let unicodeScalarCount: Int
        public let lineCount: Int
        public let wordCount: Int

        public init(
            utf16CharacterCount: Int,
            unicodeScalarCount: Int,
            lineCount: Int,
            wordCount: Int
        ) {
            self.utf16CharacterCount = utf16CharacterCount
            self.unicodeScalarCount = unicodeScalarCount
            self.lineCount = lineCount
            self.wordCount = wordCount
        }
    }

    public static func summary(for text: String) -> Summary {
        Summary(
            utf16CharacterCount: text.utf16.count,
            unicodeScalarCount: text.unicodeScalars.count,
            lineCount: lineCount(in: text),
            wordCount: wordCount(in: text)
        )
    }

    private static func lineCount(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        let cr = UnicodeScalar(13)!
        let lf = UnicodeScalar(10)!
        let scalars = text.unicodeScalars
        var count = 1
        var index = scalars.startIndex

        while index < scalars.endIndex {
            switch scalars[index] {
            case cr:
                count += 1
                let nextIndex = scalars.index(after: index)
                if nextIndex < scalars.endIndex, scalars[nextIndex] == lf {
                    index = scalars.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
            case lf:
                count += 1
                index = scalars.index(after: index)
            default:
                index = scalars.index(after: index)
            }
        }

        return count
    }

    private static func wordCount(in text: String) -> Int {
        var count = 0
        var isInsideWord = false

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if !isInsideWord {
                    count += 1
                }
                isInsideWord = true
            } else {
                isInsideWord = false
            }
        }

        return count
    }
}
