import Foundation

/// File-level line diff and inline (word/character) diff.
///
/// This module is a pure value-type algorithm layer with no UI dependencies,
/// so it can be unit-tested in isolation. It is used by the diff window
/// controller (`Sources/NotepadMac/DiffWindowController.swift`) to render
/// side-by-side file comparisons.
///
/// The algorithm is a two-stage LCS:
/// 1. Line-level LCS produces an aligned edit script (equal / insert / delete).
/// 2. For paired changed lines, a character-level LCS produces inline segments
///    so that the differing characters within a modified line can be highlighted.
///
/// Note: `upstream/notepad--` ships its compare feature as a closed-source
/// commercial plugin (the open-source tree has empty `slot_compareFile` bodies
/// and no `StrategyCompare.cpp`). This module is an independent implementation.
public enum FileDiff {

    // MARK: - Result types

    /// A single aligned line on either side of the comparison.
    public struct AlignedLine: Sendable, Equatable {
        /// Classification of the line relative to the other side.
        public enum Kind: Sendable, Equatable {
            /// Identical on both sides.
            case common
            /// Modified: present on this side with real content, paired against
            /// a different line (or a pad) on the other side.
            case changed
            /// Added on the right side only (`insert` in the edit script).
            case added
            /// Removed from the left side only (`delete` in the edit script).
            case removed
            /// Virtual blank line used only to keep both sides the same length
            /// so that line numbers line up visually.
            case pad
        }

        /// 1-based line number in the original source, or `nil` for pad lines.
        public let sourceLine: Int?
        /// Line text without its line terminator. Empty for pad lines.
        public let text: String
        public let kind: Kind

        public init(sourceLine: Int?, text: String, kind: Kind) {
            self.sourceLine = sourceLine
            self.text = text
            self.kind = kind
        }
    }

    /// A contiguous run of characters within a changed line sharing one edit type.
    public struct InlineSegment: Sendable, Equatable {
        public enum Edit: Sendable, Equatable {
            case equal
            case insert
            case delete
        }

        public let edit: Edit
        public let text: String

        public init(edit: Edit, text: String) {
            self.edit = edit
            self.text = text
        }
    }

    /// One contiguous group of differing lines, kept aligned across both sides.
    public struct DiffHunk: Sendable, Equatable {
        /// Range of indices into `DiffResult.leftLines` covered by this hunk.
        public let leftRange: Range<Int>
        /// Range of indices into `DiffResult.rightLines` covered by this hunk.
        public let rightRange: Range<Int>
        /// Inline character segments for each changed/removed left line.
        /// Index `i` corresponds to `leftLines[leftRange.lowerBound + i]`
        /// when that line is not a pad; pad lines contribute an empty array.
        public let leftSegments: [[InlineSegment]]
        /// Inline character segments for each changed/added right line.
        public let rightSegments: [[InlineSegment]]

        public init(
            leftRange: Range<Int>,
            rightRange: Range<Int>,
            leftSegments: [[InlineSegment]],
            rightSegments: [[InlineSegment]]
        ) {
            self.leftRange = leftRange
            self.rightRange = rightRange
            self.leftSegments = leftSegments
            self.rightSegments = rightSegments
        }
    }

    /// Full result of a comparison between two texts.
    public struct DiffResult: Sendable, Equatable {
        public let leftLines: [AlignedLine]
        public let rightLines: [AlignedLine]
        public let hunks: [DiffHunk]
        public let leftTitle: String
        public let rightTitle: String

        public var isIdentical: Bool { hunks.isEmpty }

        public init(
            leftLines: [AlignedLine],
            rightLines: [AlignedLine],
            hunks: [DiffHunk],
            leftTitle: String,
            rightTitle: String
        ) {
            self.leftLines = leftLines
            self.rightLines = rightLines
            self.hunks = hunks
            self.leftTitle = leftTitle
            self.rightTitle = rightTitle
        }
    }

    // MARK: - Compare options

    /// Options that control how lines are matched before diffing.
    public struct CompareOptions: Sendable, Equatable {
        public enum WhitespaceMode: Sendable, Equatable {
            /// Do not ignore whitespace.
            case none
            /// Ignore whitespace before the first non-whitespace character.
            case leading
            /// Ignore whitespace after the last non-whitespace character.
            case trailing
            /// Ignore all whitespace characters.
            case all
        }

        public enum CompareMode: Sendable, Equatable {
            /// Faster: compute line-level diff only (no inline character segments).
            case quick
            /// More detailed: also compute inline character segments for changed lines.
            case deep
        }

        public var whitespaceMode: WhitespaceMode
        public var mode: CompareMode

        public init(
            whitespaceMode: WhitespaceMode = .leading,
            mode: CompareMode = .deep
        ) {
            self.whitespaceMode = whitespaceMode
            self.mode = mode
        }

        public static let `default` = CompareOptions()
    }

    // MARK: - Public entry points

    /// Compute the difference between two texts.
    ///
    /// Line splitting preserves every line except a trailing empty line that
    /// results from a terminal newline, so `"a\n"` and `"a"` compare equal.
    public static func compute(
        left: String,
        right: String,
        leftTitle: String,
        rightTitle: String,
        options: CompareOptions = .default
    ) -> DiffResult {
        let leftRaw = splitLines(left)
        let rightRaw = splitLines(right)

        let leftNorm = leftRaw.map { normalizeLine($0, options: options) }
        let rightNorm = rightRaw.map { normalizeLine($0, options: options) }

        // Stage 1: line-level LCS edit script.
        let script = lineLevelEditScript(leftNorm, rightNorm)

        // Stage 2: build aligned line arrays (equal length) with pads inserted.
        var leftLines: [AlignedLine] = []
        var rightLines: [AlignedLine] = []
        var leftIndex = 0   // next unconsumed raw left line
        var rightIndex = 0  // next unconsumed raw right line

        // While emitting, also track hunk boundaries for grouping.
        struct PendingHunk {
            var leftStart: Int
            var rightStart: Int
            var leftAligned: [AlignedLine] = []
            var rightAligned: [AlignedLine] = []
        }
        var current: PendingHunk?
        var hunks: [DiffHunk] = []

        func openHunkIfNeeded() {
            if current == nil {
                current = PendingHunk(
                    leftStart: leftLines.count,
                    rightStart: rightLines.count
                )
            }
        }

        @discardableResult
        func flushHunk() -> Bool {
            guard let h = current else { return false }
            // Stage 2b: optional character-level inline diff for paired changed lines.
            // Walk both aligned arrays in lockstep; for two non-pad, non-common
            // lines treat them as a changed pair and segment them when enabled.
            var leftSegs: [[InlineSegment]] = []
            var rightSegs: [[InlineSegment]] = []
            var li = 0
            var ri = 0
            while li < h.leftAligned.count || ri < h.rightAligned.count {
                let l = li < h.leftAligned.count ? h.leftAligned[li] : nil
                let r = ri < h.rightAligned.count ? h.rightAligned[ri] : nil
                switch (l?.kind, r?.kind) {
                case (.pad, .pad):
                    leftSegs.append([]); rightSegs.append([])
                    li += 1; ri += 1
                case (.pad, _):
                    leftSegs.append([])
                    ri += 1
                case (_, .pad):
                    rightSegs.append([])
                    li += 1
                case (.removed?, _):
                    // Pure removal: full-line delete highlight, no inline segs needed.
                    leftSegs.append([])
                    li += 1
                case (_, .added?):
                    rightSegs.append([])
                    ri += 1
                case (.changed?, .changed?):
                    if options.mode == .deep {
                        // Paired modification: run character-level diff.
                        let segs = charLevelSegments(l!.text, r!.text)
                        leftSegs.append(segs.left)
                        rightSegs.append(segs.right)
                    } else {
                        leftSegs.append([])
                        rightSegs.append([])
                    }
                    li += 1; ri += 1
                default:
                    li += 1; ri += 1
                }
            }
            hunks.append(DiffHunk(
                leftRange: h.leftStart..<(h.leftStart + h.leftAligned.count),
                rightRange: h.rightStart..<(h.rightStart + h.rightAligned.count),
                leftSegments: leftSegs,
                rightSegments: rightSegs
            ))
            current = nil
            return true
        }

        for op in script {
            switch op {
            case .equal(let count):
                flushHunk()
                for _ in 0..<count {
                    leftLines.append(AlignedLine(
                        sourceLine: leftIndex + 1, text: leftRaw[leftIndex], kind: .common))
                    rightLines.append(AlignedLine(
                        sourceLine: rightIndex + 1, text: rightRaw[rightIndex], kind: .common))
                    leftIndex += 1
                    rightIndex += 1
                }
            case .insert(let count):
                openHunkIfNeeded()
                for _ in 0..<count {
                    let line = AlignedLine(
                        sourceLine: rightIndex + 1, text: rightRaw[rightIndex], kind: .added)
                    current!.rightAligned.append(line)
                    rightLines.append(line)
                    // Pad the left to keep alignment.
                    let pad = AlignedLine(sourceLine: nil, text: "", kind: .pad)
                    current!.leftAligned.append(pad)
                    leftLines.append(pad)
                    rightIndex += 1
                }
            case .delete(let count):
                openHunkIfNeeded()
                for _ in 0..<count {
                    let line = AlignedLine(
                        sourceLine: leftIndex + 1, text: leftRaw[leftIndex], kind: .removed)
                    current!.leftAligned.append(line)
                    leftLines.append(line)
                    let pad = AlignedLine(sourceLine: nil, text: "", kind: .pad)
                    current!.rightAligned.append(pad)
                    rightLines.append(pad)
                    leftIndex += 1
                }
            case .replace(let delCount, let insCount):
                openHunkIfNeeded()
                // Pair up min(del, ins) as changed lines; the remainder is pure
                // insert/delete (handled by padding the shorter side).
                let paired = min(delCount, insCount)
                for _ in 0..<paired {
                    let lLine = AlignedLine(
                        sourceLine: leftIndex + 1, text: leftRaw[leftIndex], kind: .changed)
                    let rLine = AlignedLine(
                        sourceLine: rightIndex + 1, text: rightRaw[rightIndex], kind: .changed)
                    current!.leftAligned.append(lLine)
                    current!.rightAligned.append(rLine)
                    leftLines.append(lLine)
                    rightLines.append(rLine)
                    leftIndex += 1
                    rightIndex += 1
                }
                if delCount > paired {
                    for _ in 0..<(delCount - paired) {
                        let line = AlignedLine(
                            sourceLine: leftIndex + 1, text: leftRaw[leftIndex], kind: .removed)
                        current!.leftAligned.append(line)
                        leftLines.append(line)
                        let pad = AlignedLine(sourceLine: nil, text: "", kind: .pad)
                        current!.rightAligned.append(pad)
                        rightLines.append(pad)
                        leftIndex += 1
                    }
                }
                if insCount > paired {
                    for _ in 0..<(insCount - paired) {
                        let line = AlignedLine(
                            sourceLine: rightIndex + 1, text: rightRaw[rightIndex], kind: .added)
                        current!.rightAligned.append(line)
                        rightLines.append(line)
                        let pad = AlignedLine(sourceLine: nil, text: "", kind: .pad)
                        current!.leftAligned.append(pad)
                        leftLines.append(pad)
                        rightIndex += 1
                    }
                }
            }
        }
        flushHunk()

        return DiffResult(
            leftLines: leftLines,
            rightLines: rightLines,
            hunks: hunks,
            leftTitle: leftTitle,
            rightTitle: rightTitle
        )
    }

    /// Rebuild plain text (without pads) from aligned lines.
    public static func reconstructText(_ lines: [AlignedLine]) -> String {
        let real = lines.filter { $0.kind != .pad }
        return real.map(\.text).joined(separator: "\n")
    }

    /// Apply a hunk from the left side onto the right, returning the new right text.
    ///
    /// After applying, the controller should recompute the diff so that alignment
    /// and hunk indices stay correct. Returns `nil` if the index is out of range.
    public static func applyLeftToRight(_ result: DiffResult, hunkIndex: Int) -> String? {
        guard hunkIndex >= 0, hunkIndex < result.hunks.count else { return nil }
        let hunk = result.hunks[hunkIndex]
        var rightLines = result.rightLines
        // Replace the hunk's right range with the hunk's left content (skipping pads).
        let replacement: [AlignedLine] = result.leftLines[hunk.leftRange]
            .filter { $0.kind != .pad }
            .map { AlignedLine(sourceLine: nil, text: $0.text, kind: .common) }
        rightLines.replaceSubrange(hunk.rightRange, with: replacement)
        return reconstructText(rightLines)
    }

    /// Apply a hunk from the right side onto the left, returning the new left text.
    public static func applyRightToLeft(_ result: DiffResult, hunkIndex: Int) -> String? {
        guard hunkIndex >= 0, hunkIndex < result.hunks.count else { return nil }
        let hunk = result.hunks[hunkIndex]
        var leftLines = result.leftLines
        let replacement: [AlignedLine] = result.rightLines[hunk.rightRange]
            .filter { $0.kind != .pad }
            .map { AlignedLine(sourceLine: nil, text: $0.text, kind: .common) }
        leftLines.replaceSubrange(hunk.leftRange, with: replacement)
        return reconstructText(leftLines)
    }

    // MARK: - Line splitting

    /// Split text into lines, dropping the phantom empty line produced by a
    /// trailing newline so `"a\n"` → `["a"]` (matching `"a"`).
    /// Recognizes `\n`, `\r\n`, and lone `\r` as line terminators so that files
    /// using classic-Mac (`\r`) line endings compare correctly.
    static func splitLines(_ text: String) -> [String] {
        if text.isEmpty { return [] }
        // Enumerate by unicode scalar, breaking on any of the three EOL forms.
        var lines: [String] = []
        var current = ""
        var prevWasCR = false
        for scalar in text.unicodeScalars {
            if scalar == "\r" {
                lines.append(current)
                current = ""
                prevWasCR = true
                continue
            }
            if scalar == "\n" {
                // A "\r\n" sequence should count as one break, not two. The
                // preceding "\r" already pushed a line, so skip this "\n".
                if prevWasCR {
                    prevWasCR = false
                    continue
                }
                lines.append(current)
                current = ""
                prevWasCR = false
                continue
            }
            current.unicodeScalars.append(scalar)
            prevWasCR = false
        }
        // Trailing content after the last terminator.
        if !current.isEmpty {
            lines.append(current)
        }
        // If the text ended with a terminator, the loop above already captured
        // the final line; no phantom "" is added, so no trailing-drop needed.
        return lines
    }

    /// Normalize a line for comparison according to the given options.
    /// Original line text is preserved in the aligned output.
    private static func normalizeLine(_ line: String, options: CompareOptions) -> String {
        switch options.whitespaceMode {
        case .none:
            return line
        case .leading:
            if let first = line.firstIndex(where: { !$0.isWhitespace }) {
                return String(line[first...])
            }
            return ""
        case .trailing:
            if let last = line.lastIndex(where: { !$0.isWhitespace }) {
                return String(line[...last])
            }
            return ""
        case .all:
            return String(line.filter { !$0.isWhitespace })
        }
    }

    // MARK: - Line-level LCS

    /// Run-length-compressed edit script from a line-level LCS.
    enum LineEdit {
        case equal(Int)
        case insert(Int)
        case delete(Int)
        case replace(Int, Int)  // (deleteCount, insertCount)
    }

    /// Produce a run-length-compressed edit script describing how `left` becomes `right`.
    static func lineLevelEditScript(_ left: [String], _ right: [String]) -> [LineEdit] {
        let m = left.count
        let n = right.count

        // Quick paths for fully equal / fully inserted / fully deleted.
        if m == 0 && n == 0 { return [] }
        if m == 0 { return [.insert(n)] }
        if n == 0 { return [.delete(m)] }
        if left == right { return [.equal(m)] }

        // DP table of LCS lengths. dp[i][j] = LCS length of left[i..<m], right[j..<n].
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in stride(from: m - 1, through: 0, by: -1) {
            for j in stride(from: n - 1, through: 0, by: -1) {
                if left[i] == right[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        // Backtrack to produce the raw script (per-line equal/insert/delete),
        // then run-length compress into equal/insert/delete/replace.
        var raw: [(kind: Int, count: Int)] = []  // 0=equal,1=delete(left-only),2=insert(right-only)
        var i = 0
        var j = 0
        while i < m && j < n {
            if left[i] == right[j] {
                raw.append((0, 1)); i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                raw.append((1, 1)); i += 1
            } else {
                raw.append((2, 1)); j += 1
            }
        }
        while i < m { raw.append((1, 1)); i += 1 }
        while j < n { raw.append((2, 1)); j += 1 }

        return runLengthCompress(raw)
    }

    /// Compress a per-line (kind, 1) list into run-length edit ops, fusing
    /// adjacent delete+insert runs into a single `replace`.
    private static func runLengthCompress(_ raw: [(kind: Int, count: Int)]) -> [LineEdit] {
        guard !raw.isEmpty else { return [] }
        var result: [LineEdit] = []
        var idx = 0
        while idx < raw.count {
            let kind = raw[idx].kind
            var count = 0
            while idx < raw.count && raw[idx].kind == kind {
                count += 1
                idx += 1
            }
            switch kind {
            case 0: result.append(.equal(count))
            case 1:  // delete run
                // Fuse a following insert run into a replace.
                var insCount = 0
                let saveIdx = idx
                while idx < raw.count && raw[idx].kind == 2 {
                    insCount += 1
                    idx += 1
                }
                if insCount > 0 {
                    result.append(.replace(count, insCount))
                } else {
                    result.append(.delete(count))
                    idx = saveIdx
                }
            case 2:  // insert run (only reached if not preceded by delete)
                result.append(.insert(count))
            default: break
            }
        }
        return result
    }

    // MARK: - Character-level LCS (inline segments)

    /// Character-level diff of two changed lines.
    /// Returns segments for the left (delete + equal) and right (insert + equal).
    static func charLevelSegments(_ left: String, _ right: String) -> (left: [InlineSegment], right: [InlineSegment]) {
        let l = Array(left.unicodeScalars.map { Character($0) })
        let r = Array(right.unicodeScalars.map { Character($0) })
        let m = l.count
        let n = r.count

        if m == 0 && n == 0 { return ([], []) }
        if m == 0 {
            return ([], [InlineSegment(edit: .insert, text: right)])
        }
        if n == 0 {
            return ([InlineSegment(edit: .delete, text: left)], [])
        }

        // dp[i][j] = LCS length of l[i..<m], r[j..<n]
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in stride(from: m - 1, through: 0, by: -1) {
            for j in stride(from: n - 1, through: 0, by: -1) {
                if l[i] == r[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        // Backtrack into raw (kind, char) ops: 0=equal, 1=delete(left-only), 2=insert(right-only)
        var leftSegs: [InlineSegment] = []
        var rightSegs: [InlineSegment] = []
        var i = 0
        var j = 0
        var leftRun = ""
        var rightRun = ""
        // We collect delete chars into leftRun and insert chars into rightRun,
        // flushing whenever we hit an equal so that segments stay contiguous.
        func flushRuns() {
            if !leftRun.isEmpty {
                leftSegs.append(InlineSegment(edit: .delete, text: leftRun))
                leftRun = ""
            }
            if !rightRun.isEmpty {
                rightSegs.append(InlineSegment(edit: .insert, text: rightRun))
                rightRun = ""
            }
        }
        while i < m && j < n {
            if l[i] == r[j] {
                flushRuns()
                leftSegs.append(InlineSegment(edit: .equal, text: String(l[i])))
                rightSegs.append(InlineSegment(edit: .equal, text: String(r[j])))
                i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                leftRun.append(l[i])
                i += 1
            } else {
                rightRun.append(r[j])
                j += 1
            }
        }
        while i < m { leftRun.append(l[i]); i += 1 }
        while j < n { rightRun.append(r[j]); j += 1 }
        flushRuns()

        return (mergeAdjacentEqual(leftSegs), mergeAdjacentEqual(rightSegs))
    }

    /// Merge consecutive `.equal` segments into one (backtracking can interleave).
    private static func mergeAdjacentEqual(_ segments: [InlineSegment]) -> [InlineSegment] {
        guard !segments.isEmpty else { return [] }
        var merged: [InlineSegment] = []
        for seg in segments {
            if let last = merged.last, last.edit == seg.edit, seg.edit == .equal {
                merged[merged.count - 1] = InlineSegment(edit: .equal, text: last.text + seg.text)
            } else {
                merged.append(seg)
            }
        }
        return merged
    }
}
