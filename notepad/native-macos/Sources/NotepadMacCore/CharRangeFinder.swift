import Foundation

public enum CharRangePreset: Equatable, Sendable {
    case ascii
    case nonASCII
    case custom(UInt8, UInt8)

    public var byteRange: (UInt8, UInt8)? {
        switch self {
        case .ascii:
            return (0, 127)
        case .nonASCII:
            return (128, 255)
        case let .custom(start, end):
            guard start <= end, end <= 255 else { return nil }
            return (start, end)
        }
    }
}

public struct CharRangeSearchOptions: Equatable, Sendable {
    public let preset: CharRangePreset
    public let direction: TextSearch.Direction
    public let wraps: Bool

    public init(
        preset: CharRangePreset,
        direction: TextSearch.Direction = .down,
        wraps: Bool = true
    ) {
        self.preset = preset
        self.direction = direction
        self.wraps = wraps
    }
}

public enum CharRangeFinder {
    /// Search UTF-8 byte values in text, aligned with Notepad++ Find Characters in Range semantics.
    public static func findNext(
        in text: String,
        from selection: NSRange,
        options: CharRangeSearchOptions
    ) -> NSRange? {
        guard let (startByte, endByte) = options.preset.byteRange else { return nil }

        let utf8Bytes = Array(text.utf8)
        guard !utf8Bytes.isEmpty else { return nil }

        let nsText = text as NSString
        let startPos: Int
        if options.direction == .down {
            let utf16Start = selection.length > 0 ? NSMaxRange(selection) : selection.location
            startPos = utf8ByteIndex(fromUTF16Location: min(utf16Start, nsText.length), in: text)
        } else {
            let utf16Start = max(0, selection.location - (selection.length > 0 ? 0 : 1))
            startPos = max(0, utf8ByteIndex(fromUTF16Location: min(utf16Start, nsText.length), in: text) - 1)
        }

        if let found = searchBytes(
            utf8Bytes,
            from: startPos,
            direction: options.direction,
            startByte: startByte,
            endByte: endByte
        ) {
            return utf16SelectionRange(forByteIndex: found, in: text, direction: options.direction)
        }

        guard options.wraps else { return nil }

        let wrapStart = options.direction == .down ? 0 : utf8Bytes.count - 1
        guard let found = searchBytes(
            utf8Bytes,
            from: wrapStart,
            direction: options.direction,
            startByte: startByte,
            endByte: endByte
        ) else {
            return nil
        }
        return utf16SelectionRange(forByteIndex: found, in: text, direction: options.direction)
    }

    private static func searchBytes(
        _ bytes: [UInt8],
        from startPos: Int,
        direction: TextSearch.Direction,
        startByte: UInt8,
        endByte: UInt8
    ) -> Int? {
        if direction == .down {
            let clampedStart = max(0, min(startPos, bytes.count))
            for index in clampedStart ..< bytes.count where bytes[index] >= startByte && bytes[index] <= endByte {
                return index
            }
        } else {
            let clampedStart = min(max(startPos, 0), max(bytes.count - 1, 0))
            for index in stride(from: clampedStart, through: 0, by: -1) where bytes[index] >= startByte && bytes[index] <= endByte {
                return index
            }
        }
        return nil
    }

    private static func utf8ByteIndex(fromUTF16Location location: Int, in text: String) -> Int {
        guard location > 0 else { return 0 }
        let prefix = (text as NSString).substring(to: location)
        return prefix.utf8.count
    }

    private static func utf16SelectionRange(
        forByteIndex byteIndex: Int,
        in text: String,
        direction: TextSearch.Direction
    ) -> NSRange {
        var currentByte = 0
        var utf16Offset = 0

        for scalar in text.unicodeScalars {
            let scalarUTF8 = Array(String(scalar).utf8)
            let scalarByteCount = scalarUTF8.count
            if byteIndex >= currentByte && byteIndex < currentByte + scalarByteCount {
                let utf16Length = scalar.utf16.count
                if direction == .up {
                    return NSRange(location: utf16Offset + utf16Length, length: 0)
                }
                return NSRange(location: utf16Offset, length: utf16Length)
            }
            currentByte += scalarByteCount
            utf16Offset += scalar.utf16.count
        }

        let end = (text as NSString).length
        if direction == .up {
            return NSRange(location: end, length: 0)
        }
        return NSRange(location: max(0, end - 1), length: end > 0 ? 1 : 0)
    }
}
