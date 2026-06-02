import Foundation

public enum WorkspaceNodeKind: String, Codable, Equatable, Sendable {
    case project
    case folder
    case file
}

public struct WorkspaceNode: Codable, Equatable, Sendable {
    public let name: String
    public let kind: WorkspaceNodeKind
    public let url: URL?
    public let children: [WorkspaceNode]

    public init(
        name: String,
        kind: WorkspaceNodeKind,
        url: URL? = nil,
        children: [WorkspaceNode] = []
    ) {
        self.name = name.isEmpty ? Self.defaultName(for: kind) : name
        self.kind = kind
        self.url = url?.standardizedFileURL
        self.children = children
    }

    public static func file(url: URL, name: String? = nil) -> WorkspaceNode {
        let standardizedURL = url.standardizedFileURL
        return WorkspaceNode(
            name: name ?? standardizedURL.lastPathComponent,
            kind: .file,
            url: standardizedURL
        )
    }

    private static func defaultName(for kind: WorkspaceNodeKind) -> String {
        switch kind {
        case .project:
            "Project"
        case .folder:
            "Folder"
        case .file:
            "File"
        }
    }
}

public struct WorkspaceDocument: Codable, Equatable, Sendable {
    public let name: String
    public let projects: [WorkspaceNode]

    public init(name: String, projects: [WorkspaceNode]) {
        self.name = name.isEmpty ? "Workspace" : name
        self.projects = projects.map { project in
            project.kind == .project ? project : WorkspaceNode(name: project.name, kind: .project, children: project.children)
        }
    }

    public static func load(from url: URL) throws -> WorkspaceDocument {
        guard let parser = XMLParser(contentsOf: url) else {
            throw WorkspaceDocumentError.unreadableWorkspace(url.path)
        }

        let delegate = WorkspaceXMLParser(workspaceURL: url)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw WorkspaceDocumentError.invalidWorkspace(parser.parserError?.localizedDescription ?? "Unknown XML parser error")
        }

        guard !delegate.projects.isEmpty else {
            throw WorkspaceDocumentError.invalidWorkspace("Workspace contains no projects")
        }

        return WorkspaceDocument(name: url.lastPathComponent, projects: delegate.projects)
    }

    public func write(to url: URL) throws {
        let root = XMLElement(name: "NotepadPlus")
        let document = XMLDocument(rootElement: root)
        document.characterEncoding = "UTF-8"
        document.version = "1.0"

        for project in projects {
            let projectElement = XMLElement(name: "Project")
            projectElement.addStringAttribute(name: "name", value: project.name)
            appendWorkspaceChildren(project.children, to: projectElement, workspaceURL: url)
            root.addChild(projectElement)
        }

        try document.xmlData(options: [.nodePrettyPrint]).write(to: url, options: .atomic)
    }

    public static func folderWorkspace(from rootURL: URL) throws -> WorkspaceDocument {
        let root = rootURL.standardizedFileURL
        let children = try workspaceChildren(in: root)
        let project = WorkspaceNode(name: root.lastPathComponent, kind: .project, children: children)
        return WorkspaceDocument(name: root.lastPathComponent, projects: [project])
    }

    private static func workspaceChildren(in directory: URL) throws -> [WorkspaceNode] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )

        let sortedURLs = try urls.sorted { lhs, rhs in
            let lhsValues = try lhs.resourceValues(forKeys: Set(resourceKeys))
            let rhsValues = try rhs.resourceValues(forKeys: Set(resourceKeys))
            let lhsIsDirectory = lhsValues.isDirectory == true
            let rhsIsDirectory = rhsValues.isDirectory == true

            if lhsIsDirectory != rhsIsDirectory {
                return lhsIsDirectory
            }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        var children: [WorkspaceNode] = []
        for url in sortedURLs {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            if values.isDirectory == true {
                children.append(
                    WorkspaceNode(
                        name: url.lastPathComponent,
                        kind: .folder,
                        children: try workspaceChildren(in: url)
                    )
                )
            } else if values.isRegularFile == true {
                children.append(.file(url: url))
            }
        }

        return children
    }
}

public final class WorkspaceStore {
    private enum Key {
        static let document = "notepadMac.workspace.document"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> WorkspaceDocument? {
        defaults.data(forKey: Key.document)
            .flatMap { try? JSONDecoder().decode(WorkspaceDocument.self, from: $0) }
    }

    public func save(_ workspace: WorkspaceDocument) {
        if let data = try? JSONEncoder().encode(workspace) {
            defaults.set(data, forKey: Key.document)
            defaults.synchronize()
        }
    }

    public func clear() {
        defaults.removeObject(forKey: Key.document)
        defaults.synchronize()
    }
}

public enum WorkspaceDocumentError: Error, Equatable, Sendable {
    case unreadableWorkspace(String)
    case invalidWorkspace(String)
}

private final class WorkspaceXMLParser: NSObject, XMLParserDelegate {
    private struct PendingNode {
        let name: String
        let kind: WorkspaceNodeKind
        var children: [WorkspaceNode] = []
    }

    private let workspaceURL: URL
    private var stack: [PendingNode] = []

    private(set) var projects: [WorkspaceNode] = []

    init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL.standardizedFileURL
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "Project":
            stack.append(PendingNode(name: attributeDict["name"] ?? "Project", kind: .project))
        case "Folder":
            stack.append(PendingNode(name: attributeDict["name"] ?? "Folder", kind: .folder))
        case "File":
            guard let rawPath = attributeDict["name"] else { return }
            append(WorkspaceNode.file(url: resolveFileURL(rawPath)))
        default:
            return
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "Project" || elementName == "Folder", let pending = stack.popLast() else {
            return
        }

        append(WorkspaceNode(name: pending.name, kind: pending.kind, children: pending.children))
    }

    private func append(_ node: WorkspaceNode) {
        guard !stack.isEmpty else {
            if node.kind == .project {
                projects.append(node)
            }
            return
        }

        var parent = stack.removeLast()
        parent.children.append(node)
        stack.append(parent)
    }

    private func resolveFileURL(_ path: String) -> URL {
        if (path as NSString).isAbsolutePath {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        return workspaceURL
            .deletingLastPathComponent()
            .appending(path: path)
            .standardizedFileURL
    }
}

private func appendWorkspaceChildren(_ children: [WorkspaceNode], to element: XMLElement, workspaceURL: URL) {
    for child in children {
        switch child.kind {
        case .project:
            continue
        case .folder:
            let folderElement = XMLElement(name: "Folder")
            folderElement.addStringAttribute(name: "name", value: child.name)
            appendWorkspaceChildren(child.children, to: folderElement, workspaceURL: workspaceURL)
            element.addChild(folderElement)
        case .file:
            guard let url = child.url else { continue }
            let fileElement = XMLElement(name: "File")
            fileElement.addStringAttribute(name: "name", value: relativeFilePath(url, workspaceURL: workspaceURL))
            element.addChild(fileElement)
        }
    }
}

private func relativeFilePath(_ fileURL: URL, workspaceURL: URL) -> String {
    let workspaceDirectory = workspaceURL
        .deletingLastPathComponent()
        .standardizedFileURL
        .path
    let filePath = fileURL.standardizedFileURL.path
    let prefix = workspaceDirectory.hasSuffix("/") ? workspaceDirectory : workspaceDirectory + "/"

    guard filePath.hasPrefix(prefix) else {
        return filePath
    }

    return String(filePath.dropFirst(prefix.count))
}

private extension XMLElement {
    func addStringAttribute(name: String, value: String) {
        addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
    }
}
