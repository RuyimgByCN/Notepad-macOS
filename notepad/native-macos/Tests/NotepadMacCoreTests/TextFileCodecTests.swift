import Foundation
import Testing
@testable import NotepadMacCore

@Test func textFileCodecDetectsUtf8ByteOrderMarkWithoutAddingMarkerCharacter() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-bom.txt")
    let bytes = Data([0xEF, 0xBB, 0xBF]) + Data("one\r\ntwo".utf8)
    try bytes.write(to: fileURL)

    let loaded = try TextFileCodec.read(fileURL)

    #expect(loaded.text == "one\r\ntwo")
    #expect(loaded.encoding == .utf8)
    #expect(loaded.hasByteOrderMark)
    #expect(loaded.lineEnding == .crlf)
}

@Test func textFileCodecCanWriteUtf8ByteOrderMarkWhenRequested() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-bom-write.txt")
    try TextFileCodec.write(
        "hello\n",
        to: fileURL,
        encoding: .utf8,
        lineEnding: .lf,
        includeByteOrderMark: true
    )

    let raw = try Data(contentsOf: fileURL)
    #expect(Array(raw.prefix(3)) == [0xEF, 0xBB, 0xBF])

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "hello\n")
    #expect(loaded.encoding == .utf8)
    #expect(loaded.hasByteOrderMark)
}

@Test func textFileCodecOmitsUtf8ByteOrderMarkByDefault() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf8-no-bom.txt")
    try TextFileCodec.write("hello\n", to: fileURL, encoding: .utf8, lineEnding: .lf)

    let raw = try Data(contentsOf: fileURL)
    #expect(!raw.starts(with: [0xEF, 0xBB, 0xBF]))

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "hello\n")
    #expect(loaded.encoding == .utf8)
    #expect(!loaded.hasByteOrderMark)
}

@Test func textFileCodecReportsUtf16ByteOrderMarkOnRead() throws {
    let directory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appending(path: "utf16-bom.txt")
    try TextFileCodec.write("hello\n", to: fileURL, encoding: .utf16, lineEnding: .lf)

    let raw = try Data(contentsOf: fileURL)
    #expect(raw.starts(with: [0xFF, 0xFE]) || raw.starts(with: [0xFE, 0xFF]))

    let loaded = try TextFileCodec.read(fileURL)
    #expect(loaded.text == "hello\n")
    #expect(loaded.encoding == .utf16)
    #expect(loaded.hasByteOrderMark)
}

@Test func textFileSavePolicyPreservesLoadedByteOrderMarkForCompatibleEncodings() {
    let policy = TextFileSavePolicy.loaded(
        LoadedTextFile(
            text: "hello",
            encoding: .utf8,
            lineEnding: .lf,
            hasByteOrderMark: true
        )
    )

    #expect(policy.includeByteOrderMark(for: .utf8))
    #expect(policy.converted(to: .utf16LittleEndian).includeByteOrderMark(for: .utf16LittleEndian))
    #expect(policy.converted(to: .utf16BigEndian).includeByteOrderMark(for: .utf16BigEndian))
    #expect(!policy.converted(to: .ascii).includeByteOrderMark(for: .ascii))
    #expect(!policy.converted(to: .ascii).converted(to: .utf8).includeByteOrderMark(for: .utf8))
}

@Test func textFileSavePolicyDoesNotAddByteOrderMarkForNewUtf8Files() {
    let policy = TextFileSavePolicy.newFile

    #expect(!policy.includeByteOrderMark(for: .utf8))
    #expect(!policy.converted(to: .utf8).includeByteOrderMark(for: .utf8))
}
