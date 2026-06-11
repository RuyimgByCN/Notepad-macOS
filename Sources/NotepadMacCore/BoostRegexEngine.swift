import CBoostRegexBridge
import Foundation

/// Swift face of the upstream Boost.Regex engine (CBoostRegexBridge).
/// Provides Notepad++-compatible regex search and replacement formatting,
/// including \K, recursion, conditionals, and atomic groups that the
/// previous ICU translation layer could not express.
///
/// All public offsets are UTF-16 (NSRange-compatible); the bridge itself
/// works in UTF-32 code points, so this type owns the offset mapping.
public final class BoostRegexEngine {
    public struct Match: Equatable {
        /// Whole-match range (UTF-16).
        public let range: NSRange
        /// Group ranges including group 0; unmatched groups are
        /// {NSNotFound, 0}, mirroring NSRegularExpression.
        public let groupRanges: [NSRange]
    }

    public enum EngineError: Error, Equatable {
        case invalidPattern(String)
    }

    private let handle: OpaquePointer

    /// UTF-32 view of the most recently searched text plus offset tables.
    private var scalars: [UInt32] = []
    /// utf16Offsets[i] = UTF-16 offset of scalar i; count = scalars.count + 1.
    private var utf16Offsets: [Int] = []
    private var lastSearchedText: String?

    public init(pattern: String, matchCase: Bool) throws {
        var errorBuffer = [CChar](repeating: 0, count: 512)
        let patternScalars = pattern.unicodeScalars.map(\.value)
        let created = patternScalars.withUnsafeBufferPointer { buffer in
            npboost_regex_create(
                buffer.baseAddress,
                buffer.count,
                matchCase ? 1 : 0,
                &errorBuffer,
                errorBuffer.count
            )
        }
        guard let created else {
            throw EngineError.invalidPattern(String(cString: errorBuffer))
        }
        handle = created
    }

    deinit {
        npboost_regex_destroy(handle)
    }

    /// Validates a pattern without keeping the engine, returning the Boost
    /// error message for invalid patterns and nil for valid ones.
    public static func patternProblem(_ pattern: String, matchCase: Bool = true) -> String? {
        do {
            _ = try BoostRegexEngine(pattern: pattern, matchCase: matchCase)
            return nil
        } catch EngineError.invalidPattern(let message) {
            return message
        } catch {
            return "\(error)"
        }
    }

    // MARK: - Offset mapping

    private func prepare(text: String) {
        if lastSearchedText == text { return }
        lastSearchedText = text
        scalars.removeAll(keepingCapacity: true)
        utf16Offsets.removeAll(keepingCapacity: true)
        scalars.reserveCapacity(text.unicodeScalars.count)
        utf16Offsets.reserveCapacity(text.unicodeScalars.count + 1)
        var utf16Position = 0
        for scalar in text.unicodeScalars {
            scalars.append(scalar.value)
            utf16Offsets.append(utf16Position)
            utf16Position += scalar.value > 0xFFFF ? 2 : 1
        }
        utf16Offsets.append(utf16Position)
    }

    private func scalarIndex(forUTF16 offset: Int) -> Int? {
        // utf16Offsets is strictly increasing; binary search.
        var low = 0
        var high = utf16Offsets.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if utf16Offsets[mid] == offset { return mid }
            if utf16Offsets[mid] < offset { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }

    private func utf16Range(fromScalarBegin begin: Int, end: Int) -> NSRange {
        NSRange(
            location: utf16Offsets[begin],
            length: utf16Offsets[end] - utf16Offsets[begin]
        )
    }

    // MARK: - Search

    /// Finds the first match inside `searchRange` (UTF-16 offsets).
    /// The match state stays on the handle for `format(replacement:)`.
    public func firstMatch(
        in text: String,
        range searchRange: NSRange,
        dotMatchesLineSeparators: Bool = false
    ) -> Match? {
        prepare(text: text)
        guard let startScalar = scalarIndex(forUTF16: searchRange.location),
              let endScalar = scalarIndex(forUTF16: NSMaxRange(searchRange))
        else { return nil }

        let groupSlots = Int(npboost_regex_group_count(handle)) + 1
        var begins = [Int](repeating: 0, count: groupSlots)
        var ends = [Int](repeating: 0, count: groupSlots)
        var groupCount = 0

        let status = scalars.withUnsafeBufferPointer { buffer in
            npboost_regex_search(
                handle,
                buffer.baseAddress,
                buffer.count,
                startScalar,
                endScalar,
                dotMatchesLineSeparators ? 0 : 1,
                &begins,
                &ends,
                groupSlots,
                &groupCount
            )
        }
        guard status == 1 else { return nil }

        let reported = min(groupCount, groupSlots)
        var ranges: [NSRange] = []
        ranges.reserveCapacity(reported)
        for index in 0..<reported {
            if begins[index] < 0 || ends[index] < 0 {
                ranges.append(NSRange(location: NSNotFound, length: 0))
            } else {
                ranges.append(utf16Range(fromScalarBegin: begins[index], end: ends[index]))
            }
        }
        guard let whole = ranges.first else { return nil }
        return Match(range: whole, groupRanges: ranges)
    }

    /// All matches inside `searchRange`, advancing one character past
    /// empty matches the way Scintilla/upstream does.
    public func allMatches(
        in text: String,
        range searchRange: NSRange? = nil,
        dotMatchesLineSeparators: Bool = false
    ) -> [Match] {
        prepare(text: text)
        let fullRange = NSRange(location: 0, length: utf16Offsets.last ?? 0)
        var window = searchRange ?? fullRange
        let windowEnd = NSMaxRange(window)
        var matches: [Match] = []
        while window.location <= windowEnd {
            guard let match = firstMatch(
                in: text, range: window, dotMatchesLineSeparators: dotMatchesLineSeparators
            ) else { break }
            matches.append(match)
            let advance = max(NSMaxRange(match.range), match.range.location + 1)
            guard advance <= windowEnd else { break }
            window = NSRange(location: advance, length: windowEnd - advance)
        }
        return matches
    }

    /// Formats `replacement` (Boost format_all syntax: $1, \1, $&, ${name},
    /// conditionals, case-conversion operators) against the last match.
    public func format(replacement: String) -> String? {
        let replacementScalars = replacement.unicodeScalars.map(\.value)
        let needed = replacementScalars.withUnsafeBufferPointer { buffer in
            npboost_regex_format(handle, buffer.baseAddress, buffer.count, nil, 0)
        }
        guard needed >= 0 else { return nil }
        var output = [UInt32](repeating: 0, count: needed)
        let copied = replacementScalars.withUnsafeBufferPointer { buffer in
            output.withUnsafeMutableBufferPointer { outBuffer in
                npboost_regex_format(
                    handle,
                    buffer.baseAddress,
                    buffer.count,
                    outBuffer.baseAddress,
                    outBuffer.count
                )
            }
        }
        guard copied >= 0 else { return nil }
        var result = String.UnicodeScalarView()
        result.reserveCapacity(output.count)
        for value in output {
            guard let scalar = UnicodeScalar(value) else { return nil }
            result.append(scalar)
        }
        return String(result)
    }
}
