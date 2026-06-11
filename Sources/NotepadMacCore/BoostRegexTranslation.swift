import Foundation

/// Translates Notepad++/Boost::regex pattern and replacement syntax into the
/// ICU syntax used by NSRegularExpression.
///
/// Upstream Notepad++ searches with Boost::regex (Perl syntax). Most syntax is
/// shared with ICU, but a few constructs differ:
///
/// Translated:
/// - `\<` / `\>` word-start / word-end boundaries → `\b(?=\w)` / `\b(?<=\w)`
/// - replacement backreferences `\1`-`\9`, `\0` → `$1`-`$9`, `$0`
/// - replacement whole-match `$&` → `$0`, `${n}` → `$n`
/// - replacement escapes `\n`, `\t`, `\r` → literal control characters
/// - literal `$` in replacements is escaped for the ICU template parser
///
/// Rejected with a clear error (no ICU equivalent):
/// - `\K` match-reset, `(?R)`/`(?0)` recursion, `(?&name)`/`(?P>name)`
///   subroutine calls, `(?(...)...)` conditionals, `(?>...)` atomic groups,
///   `\g` backreference/subroutine syntax
public enum BoostRegexTranslation {
    public struct UnsupportedConstructError: Error, Equatable, Sendable {
        public let construct: String
        public let reason: String

        public init(construct: String, reason: String) {
            self.construct = construct
            self.reason = reason
        }
    }

    /// Translates a Boost-flavoured pattern into ICU syntax.
    /// Throws `UnsupportedConstructError` for constructs ICU cannot express.
    public static func icuPattern(fromBoostPattern pattern: String) throws -> String {
        var result = ""
        var inCharacterClass = false
        var i = pattern.startIndex

        while i < pattern.endIndex {
            let character = pattern[i]

            if character == "\\" {
                let next = pattern.index(after: i)
                guard next < pattern.endIndex else {
                    result.append(character)
                    break
                }
                let escaped = pattern[next]
                switch escaped {
                case "<" where !inCharacterClass:
                    result.append("\\b(?=\\w)")
                case ">" where !inCharacterClass:
                    result.append("\\b(?<=\\w)")
                case "K":
                    throw UnsupportedConstructError(
                        construct: "\\K",
                        reason: "match-reset is not supported by the macOS (ICU) regex engine"
                    )
                case "g" where !inCharacterClass:
                    throw UnsupportedConstructError(
                        construct: "\\g",
                        reason: "\\g backreferences/subroutines are not supported by the macOS (ICU) regex engine; use \\1-\\9"
                    )
                default:
                    result.append(character)
                    result.append(escaped)
                }
                i = pattern.index(after: next)
                continue
            }

            if inCharacterClass {
                if character == "]" {
                    inCharacterClass = false
                }
                result.append(character)
                i = pattern.index(after: i)
                continue
            }

            if character == "[" {
                inCharacterClass = true
                result.append(character)
                i = pattern.index(after: i)
                continue
            }

            if character == "(" {
                let rest = pattern[i...]
                if rest.hasPrefix("(?R") || rest.hasPrefix("(?0") {
                    throw UnsupportedConstructError(
                        construct: "(?R)",
                        reason: "recursive patterns are not supported by the macOS (ICU) regex engine"
                    )
                }
                if rest.hasPrefix("(?&") || rest.hasPrefix("(?P>") {
                    throw UnsupportedConstructError(
                        construct: "(?&name)",
                        reason: "subroutine calls are not supported by the macOS (ICU) regex engine"
                    )
                }
                if rest.hasPrefix("(?(") {
                    throw UnsupportedConstructError(
                        construct: "(?(condition)...)",
                        reason: "conditional groups are not supported by the macOS (ICU) regex engine"
                    )
                }
                if rest.hasPrefix("(?>") {
                    throw UnsupportedConstructError(
                        construct: "(?>...)",
                        reason: "atomic groups are not supported by the macOS (ICU) regex engine; possessive quantifiers (*+, ++, ?+) are"
                    )
                }
            }

            result.append(character)
            i = pattern.index(after: i)
        }

        return result
    }

    /// Returns a human-readable problem description for a Boost-flavoured
    /// pattern, or nil when the pattern is usable.
    public static func patternProblem(_ pattern: String) -> String? {
        do {
            let translated = try icuPattern(fromBoostPattern: pattern)
            _ = try NSRegularExpression(pattern: translated)
            return nil
        } catch let error as UnsupportedConstructError {
            return "\(error.construct): \(error.reason)"
        } catch {
            return error.localizedDescription
        }
    }

    /// Translates a Boost/Notepad++-flavoured replacement string into an
    /// ICU replacement template for NSRegularExpression.
    public static func icuTemplate(fromBoostReplacement replacement: String) -> String {
        var result = ""
        var i = replacement.startIndex

        while i < replacement.endIndex {
            let character = replacement[i]

            if character == "\\" {
                let next = replacement.index(after: i)
                guard next < replacement.endIndex else {
                    // Trailing backslash: ICU templates treat a lone backslash
                    // as an escape, so escape it.
                    result.append("\\\\")
                    break
                }
                let escaped = replacement[next]
                switch escaped {
                case "0"..."9":
                    result.append("$")
                    result.append(escaped)
                case "n":
                    result.append("\n")
                case "t":
                    result.append("\t")
                case "r":
                    result.append("\r")
                case "\\":
                    result.append("\\\\")
                case "$":
                    result.append("\\$")
                default:
                    // Backslash escapes the next character in ICU templates,
                    // producing that character literally — same net effect.
                    result.append(character)
                    result.append(escaped)
                }
                i = replacement.index(after: next)
                continue
            }

            if character == "$" {
                let next = replacement.index(after: i)
                if next < replacement.endIndex {
                    let following = replacement[next]
                    if following == "&" {
                        result.append("$0")
                        i = replacement.index(after: next)
                        continue
                    }
                    if following.isNumber {
                        result.append("$")
                        i = next
                        continue
                    }
                    if following == "{" {
                        // ${n} → $n
                        var j = replacement.index(after: next)
                        var digits = ""
                        while j < replacement.endIndex, replacement[j].isNumber {
                            digits.append(replacement[j])
                            j = replacement.index(after: j)
                        }
                        if !digits.isEmpty, j < replacement.endIndex, replacement[j] == "}" {
                            result.append("$")
                            result.append(digits)
                            i = replacement.index(after: j)
                            continue
                        }
                    }
                }
                // Literal dollar sign
                result.append("\\$")
                i = replacement.index(after: i)
                continue
            }

            result.append(character)
            i = replacement.index(after: i)
        }

        return result
    }
}
