import Foundation
import Testing
@testable import NotepadMac
@testable import NotepadMacCore

@MainActor
@Test func ordinaryWorkspaceStopsReloadingPreviouslyWatchedFolder() throws {
    let folderURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folderURL) }

    let folderWorkspace = try WorkspaceDocument.folderWorkspace(from: folderURL)
    let ordinaryWorkspace = WorkspaceDocument(name: "Project", projects: [])
    let controller = WorkspacePanelController(onOpenFile: { _ in })
    var reloadCount = 0

    controller.show(workspace: folderWorkspace, expandStateRoot: folderURL)
    controller.startWatching(url: folderURL) { reloadCount += 1 }
    controller.reloadFolderWorkspaceIfActive()
    #expect(reloadCount == 1)

    controller.show(workspace: ordinaryWorkspace)
    controller.reloadFolderWorkspaceIfActive()
    #expect(reloadCount == 1)
}
