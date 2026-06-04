import Foundation
import Testing
@testable import NotepadMacCore

@Test func hashToolSupportGeneratesKnownDigestsForText() {
    #expect(HashToolSupport.digest(of: "hello", using: .md5) == "5d41402abc4b2a76b9719d911017c592")
    #expect(HashToolSupport.digest(of: "hello", using: .sha1) == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    #expect(HashToolSupport.digest(of: "hello", using: .sha256) == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    #expect(HashToolSupport.digest(of: "hello", using: .sha512) == "9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043")
    #expect(HashToolSupport.digest(of: "你好", using: .sha256) == "670d9743542cae3ea7ebe36af56bd53648b0a1126162e78d81a32934a711302e")
}

@Test func hashToolSupportGeneratesPerLineDigestsPreservingBlankLines() {
    let result = HashToolSupport.digestPerLine(of: "hello\n\nworld", using: .md5)

    #expect(result == "5d41402abc4b2a76b9719d911017c592\r\n\r\n7d793037a0760186574b0282f2f435e7\r\n")
}

@Test func hashToolSupportBuildsFileDigestReportUsingBasenames() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let first = directory.appendingPathComponent("alpha.txt")
    let second = directory.appendingPathComponent("beta.txt")
    try Data("hello".utf8).write(to: first)
    try Data("world".utf8).write(to: second)

    let report = try HashToolSupport.fileDigestReport(for: [first, second], using: .sha1)

    #expect(report == "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d  alpha.txt\r\n7c211433f02071597741e6ff5a8ea34789abbf43  beta.txt\r\n")
}
