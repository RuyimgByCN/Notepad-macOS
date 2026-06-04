import Testing
import Foundation
@testable import NotepadMacCore

@Suite struct WorkspaceDocumentTests {

    // MARK: - Test Fixtures

    private static let fileA = URL(fileURLWithPath: "/tmp/a.txt")
    private static let fileB = URL(fileURLWithPath: "/tmp/b.txt")
    private static let fileC = URL(fileURLWithPath: "/tmp/c.txt")

    private static func makeDoc() -> WorkspaceDocument {
        let project = WorkspaceNode(name: "Project A", kind: .project, children: [
            WorkspaceNode.file(url: fileA),
            WorkspaceNode.file(url: fileB),
        ])
        return WorkspaceDocument(name: "Test", projects: [project])
    }

    // MARK: - addingFiles

    @Test func addingFilesAppendsToProject() {
        let doc = Self.makeDoc()
        let result = doc.addingFiles([Self.fileC], toProjectAt: 0)
        #expect(result.projects[0].children.count == 3)
        #expect(result.projects[0].children.last?.url == Self.fileC.standardizedFileURL)
    }

    @Test func addingFilesOutOfBoundsReturnsUnchanged() {
        let doc = Self.makeDoc()
        let result = doc.addingFiles([Self.fileC], toProjectAt: 99)
        #expect(result == doc)
    }

    // MARK: - removingNode

    @Test func removingNodeRemovesMatchingFile() {
        let doc = Self.makeDoc()
        let target = doc.projects[0].children[0]  // fileA node
        let result = doc.removingNode(target)
        #expect(result.projects[0].children.count == 1)
        #expect(result.projects[0].children[0].url == Self.fileB.standardizedFileURL)
    }

    @Test func removingUnknownNodeReturnsUnchanged() {
        let doc = Self.makeDoc()
        let stranger = WorkspaceNode.file(url: Self.fileC)
        let result = doc.removingNode(stranger)
        #expect(result.projects[0].children.count == 2)
    }

    // MARK: - renamingNode

    @Test func renamingNodeChangesName() {
        let doc = Self.makeDoc()
        let target = doc.projects[0].children[0]
        let result = doc.renamingNode(target, to: "Renamed")
        #expect(result.projects[0].children[0].name == "Renamed")
    }

    @Test func renamingNodeWithEmptyNameReturnsUnchanged() {
        let doc = Self.makeDoc()
        let target = doc.projects[0].children[0]
        let original = target.name
        let result = doc.renamingNode(target, to: "   ")
        #expect(result.projects[0].children[0].name == original)
    }

    // MARK: - movingNodeUp

    @Test func movingNodeUpSwapsWithPredecessor() {
        let doc = Self.makeDoc()
        let second = doc.projects[0].children[1]  // fileB
        let result = doc.movingNodeUp(second)
        #expect(result.projects[0].children[0].url == Self.fileB.standardizedFileURL)
        #expect(result.projects[0].children[1].url == Self.fileA.standardizedFileURL)
    }

    @Test func movingNodeUpFromFirstPositionReturnsUnchanged() {
        let doc = Self.makeDoc()
        let first = doc.projects[0].children[0]  // fileA
        let result = doc.movingNodeUp(first)
        #expect(result.projects[0].children[0].url == Self.fileA.standardizedFileURL)
    }

    // MARK: - movingNodeDown

    @Test func movingNodeDownSwapsWithSuccessor() {
        let doc = Self.makeDoc()
        let first = doc.projects[0].children[0]  // fileA
        let result = doc.movingNodeDown(first)
        #expect(result.projects[0].children[0].url == Self.fileB.standardizedFileURL)
        #expect(result.projects[0].children[1].url == Self.fileA.standardizedFileURL)
    }

    @Test func movingNodeDownFromLastPositionReturnsUnchanged() {
        let doc = Self.makeDoc()
        let last = doc.projects[0].children[1]  // fileB
        let result = doc.movingNodeDown(last)
        #expect(result.projects[0].children[1].url == Self.fileB.standardizedFileURL)
    }

    // MARK: - addingFolder

    @Test func addingFolderAppendsFolderNode() {
        let folderURL = URL(fileURLWithPath: "/tmp")
        let doc = Self.makeDoc()
        let result = doc.addingFolder(folderURL, recursive: false, toProjectAt: 0)
        let lastChild = result.projects[0].children.last
        #expect(lastChild?.kind == .folder)
        #expect(lastChild?.name == "tmp")
    }

    // MARK: - writeAndLoad roundtrip

    @Test func writeAndLoadRoundtrip() throws {
        let doc = Self.makeDoc()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xml")
        try doc.write(to: tmp)
        let loaded = try WorkspaceDocument.load(from: tmp)
        try FileManager.default.removeItem(at: tmp)
        #expect(loaded.name == tmp.lastPathComponent)
        #expect(loaded.projects.count == 1)
        #expect(loaded.projects[0].name == "Project A")
        #expect(loaded.projects[0].children.count == 2)
    }
}
