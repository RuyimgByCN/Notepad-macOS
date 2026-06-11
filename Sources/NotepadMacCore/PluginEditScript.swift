import Foundation

/// Buffer-mutation protocol for native manifest plugins.
///
/// When the host invokes a plugin command, it sets
/// `NOTEPAD_MAC_EDIT_SCRIPT_FILE` to a writable temp path. A plugin that wants
/// to modify the active buffer writes a JSON edit script to that path before
/// exiting successfully. The host validates and applies the edits; the plugin
/// process never mutates editor state directly.
///
/// JSON shape (version 1):
/// ```json
/// {
///   "version": 1,
///   "edits": [
///     {"action": "replaceSelection", "text": "new text"},
///     {"action": "insertAtCaret", "text": "inserted"},
///     {"action": "replaceRange", "location": 10, "length": 5, "text": "x"},
///     {"action": "setText", "text": "entire new buffer"}
///   ]
/// }
/// ```
/// `location`/`length` are UTF-16 offsets in the buffer as it stands when the
/// edit is applied (edits apply sequentially).
public struct PluginEditScript: Equatable, Sendable {
    public static let currentVersion = 1

    public enum Edit: Equatable, Sendable {
        case replaceSelection(text: String)
        case insertAtCaret(text: String)
        case replaceRange(utf16Location: Int, utf16Length: Int, text: String)
        case setText(text: String)
    }

    public enum DecodeError: Swift.Error, Equatable, Sendable {
        case invalidJSON(String)
        case unsupportedVersion(Int)
        case missingEdits
        case unknownAction(String)
        case missingField(action: String, field: String)
        case negativeRangeField(action: String, field: String)
    }

    public enum ApplyError: Swift.Error, Equatable, Sendable {
        case rangeOutOfBounds(utf16Location: Int, utf16Length: Int, bufferLength: Int)
    }

    public struct ApplyResult: Equatable, Sendable {
        public let text: String
        public let selectedRange: NSRange
        public let appliedEditCount: Int

        public init(text: String, selectedRange: NSRange, appliedEditCount: Int) {
            self.text = text
            self.selectedRange = selectedRange
            self.appliedEditCount = appliedEditCount
        }
    }

    public let edits: [Edit]

    public init(edits: [Edit]) {
        self.edits = edits
    }

    // MARK: - Decode

    public static func decode(_ data: Data) throws -> PluginEditScript {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DecodeError.invalidJSON(error.localizedDescription)
        }
        guard let root = object as? [String: Any] else {
            throw DecodeError.invalidJSON("root must be a JSON object")
        }
        let version = root["version"] as? Int ?? currentVersion
        guard version == currentVersion else {
            throw DecodeError.unsupportedVersion(version)
        }
        guard let rawEdits = root["edits"] as? [[String: Any]], !rawEdits.isEmpty else {
            throw DecodeError.missingEdits
        }

        let edits = try rawEdits.map { raw -> Edit in
            guard let action = raw["action"] as? String else {
                throw DecodeError.missingField(action: "(none)", field: "action")
            }
            func requiredText() throws -> String {
                guard let text = raw["text"] as? String else {
                    throw DecodeError.missingField(action: action, field: "text")
                }
                return text
            }
            switch action {
            case "replaceSelection":
                return .replaceSelection(text: try requiredText())
            case "insertAtCaret":
                return .insertAtCaret(text: try requiredText())
            case "setText":
                return .setText(text: try requiredText())
            case "replaceRange":
                guard let location = raw["location"] as? Int else {
                    throw DecodeError.missingField(action: action, field: "location")
                }
                guard let length = raw["length"] as? Int else {
                    throw DecodeError.missingField(action: action, field: "length")
                }
                guard location >= 0 else {
                    throw DecodeError.negativeRangeField(action: action, field: "location")
                }
                guard length >= 0 else {
                    throw DecodeError.negativeRangeField(action: action, field: "length")
                }
                return .replaceRange(utf16Location: location, utf16Length: length, text: try requiredText())
            default:
                throw DecodeError.unknownAction(action)
            }
        }
        return PluginEditScript(edits: edits)
    }

    // MARK: - Apply (pure transform)

    /// Applies the edits sequentially to `text` with `selection` as the
    /// initial caret/selection state, returning the new buffer and selection.
    public func apply(to text: String, selection: NSRange) throws -> ApplyResult {
        var currentText = text as NSString
        var currentSelection = clamp(selection, length: currentText.length)

        for edit in edits {
            switch edit {
            case .replaceSelection(let replacement):
                currentText = replace(currentText, range: currentSelection, with: replacement)
                currentSelection = NSRange(
                    location: currentSelection.location + (replacement as NSString).length,
                    length: 0
                )
            case .insertAtCaret(let inserted):
                let caret = NSRange(location: currentSelection.location, length: 0)
                currentText = replace(currentText, range: caret, with: inserted)
                currentSelection = NSRange(
                    location: caret.location + (inserted as NSString).length,
                    length: 0
                )
            case .replaceRange(let location, let length, let replacement):
                guard location >= 0, length >= 0, location + length <= currentText.length else {
                    throw ApplyError.rangeOutOfBounds(
                        utf16Location: location,
                        utf16Length: length,
                        bufferLength: currentText.length
                    )
                }
                currentText = replace(currentText, range: NSRange(location: location, length: length), with: replacement)
                currentSelection = NSRange(
                    location: location + (replacement as NSString).length,
                    length: 0
                )
            case .setText(let newText):
                currentText = newText as NSString
                currentSelection = NSRange(location: 0, length: 0)
            }
        }

        return ApplyResult(
            text: currentText as String,
            selectedRange: clamp(currentSelection, length: currentText.length),
            appliedEditCount: edits.count
        )
    }

    private func replace(_ text: NSString, range: NSRange, with replacement: String) -> NSString {
        text.replacingCharacters(in: range, with: replacement) as NSString
    }

    private func clamp(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        let maxLength = length - location
        return NSRange(location: location, length: min(max(range.length, 0), maxLength))
    }
}
