import Foundation

/// Core logic for Notepad++-style "Cut/Copy/Paste Binary Content".
///
/// Binary clipboard content is the selection's raw bytes in the document's
/// current encoding. Unlike plain pasteboard strings, this round-trips NUL
/// bytes and other control characters byte-for-byte.
public enum BinaryClipboard {
    /// The custom pasteboard type identifier used for binary content.
    public static let pasteboardType = "com.notepad-mac.binary-content"

    /// Encodes the selected text into raw bytes using the document encoding.
    /// Falls back to ISO Latin-1 and then UTF-8 when the text cannot be
    /// represented in the document encoding, so the command never fails to
    /// produce a payload for a non-empty selection.
    public static func encode(selectedText: String, encoding: String.Encoding) -> Data? {
        guard !selectedText.isEmpty else { return nil }
        if let data = TextFileCodec.encode(selectedText, encoding: encoding) {
            return data
        }
        if let data = selectedText.data(using: .isoLatin1) {
            return data
        }
        return selectedText.data(using: .utf8)
    }

    /// Decodes binary pasteboard bytes back into editor text using the
    /// document encoding. Falls back to ISO Latin-1, which maps every byte
    /// 0x00-0xFF to a code point, so arbitrary binary data is preserved as a
    /// reversible character sequence rather than rejected.
    public static func decode(data: Data, encoding: String.Encoding) -> String? {
        guard !data.isEmpty else { return "" }
        if let text = TextFileCodec.decode(data, encoding: encoding), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        return nil
    }
}
