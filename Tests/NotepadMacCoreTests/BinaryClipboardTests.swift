import Foundation
import XCTest
@testable import NotepadMacCore

final class BinaryClipboardTests: XCTestCase {
    func testBinaryClipboardRoundTripsNULBytesThroughUTF8() {
        let text = "abc\0def"

        let data = BinaryClipboard.encode(selectedText: text, encoding: .utf8)

        XCTAssertEqual(data, Data([0x61, 0x62, 0x63, 0x00, 0x64, 0x65, 0x66]))
        XCTAssertEqual(BinaryClipboard.decode(data: data!, encoding: .utf8), text)
    }

    func testBinaryClipboardEncodesInDocumentEncoding() {
        let data = BinaryClipboard.encode(selectedText: "AB", encoding: .utf16LittleEndian)

        XCTAssertEqual(data, Data([0x41, 0x00, 0x42, 0x00]))
        XCTAssertEqual(BinaryClipboard.decode(data: data!, encoding: .utf16LittleEndian), "AB")
    }

    func testBinaryClipboardRejectsEmptySelection() {
        XCTAssertNil(BinaryClipboard.encode(selectedText: "", encoding: .utf8))
    }

    func testBinaryClipboardDecodeFallsBackToISOLatin1ForInvalidUTF8() {
        let invalidUTF8 = Data([0xFF, 0xFE, 0x80])

        let decoded = BinaryClipboard.decode(data: invalidUTF8, encoding: .utf8)

        XCTAssertEqual(decoded, "\u{FF}\u{FE}\u{80}")
        // Byte-for-byte reversible through Latin-1.
        XCTAssertEqual(decoded?.data(using: .isoLatin1), invalidUTF8)
    }

    func testBinaryClipboardEncodeFallsBackWhenDocumentEncodingCannotRepresentText() {
        let data = BinaryClipboard.encode(selectedText: "héllo", encoding: .ascii)

        XCTAssertNotNil(data)
        XCTAssertEqual(String(data: data!, encoding: .isoLatin1), "héllo")
    }
}
