import Foundation

/// One item in a tab context menu spec loaded from tabContextMenu.xml.
public enum TabContextMenuSpecItem: Sendable {
    case separator
    case action(TabContextMenuAction, displayName: String?, folderName: String?)
}

/// Tab context actions that map to Notepad++ menu item names.
public enum TabContextMenuAction: String, Sendable {
    // File group
    case close                  = "Close"
    case closeOthers            = "Close All but Active Document"
    case closeAllButThis        = "Close All BUT Active Document"
    case closeAllButPinned      = "Close All but Pinned"
    case closeToLeft            = "Close All to the Left"
    case closeToRight           = "Close All to the Right"
    case closeUnchanged         = "Close All Unchanged"
    case save                   = "Save"
    case saveAs                 = "Save As..."
    case rename                 = "Rename..."
    case moveToTrash            = "Move to Recycle Bin"
    case reload                 = "Reload from Disk"
    case print                  = "Print..."
    // Edit group
    case toggleReadOnly         = "Set Read-Only"
    case clearReadOnly          = "Clear Read-Only Flag"
    case copyFullPath           = "Copy Current Full File Path"
    case copyFilename           = "Copy Current Filename"
    case copyDirPath            = "Copy Current Dir. Path"
    // View/move group
    case moveToStart            = "Move to Start"
    case moveToEnd              = "Move to End"
    case openContainingFolder   = "Explorer"
    case openInTerminal         = "cmd"
    case openAsFolderWorkspace  = "Folder as Workspace"
    case openInDefaultViewer    = "Open in Default Viewer"
    // Tab color
    case applyColor1            = "Apply Color 1"
    case applyColor2            = "Apply Color 2"
    case applyColor3            = "Apply Color 3"
    case applyColor4            = "Apply Color 4"
    case applyColor5            = "Apply Color 5"
    case removeColor            = "Remove Color"
    // Pin
    case pinTab                 = "Pin Tab"
    case unpinTab               = "Unpin Tab"
}

/// Parsed representation of tabContextMenu.xml.
public struct TabContextMenuSpec: Sendable {
    public let items: [TabContextMenuSpecItem]

    public init(items: [TabContextMenuSpecItem]) {
        self.items = items
    }

    /// Parse tabContextMenu.xml content into a spec. Returns nil if the XML is invalid.
    public static func parse(xml: String) -> TabContextMenuSpec? {
        guard let data = xml.data(using: .utf8) else { return nil }
        let parser = TabContextMenuXMLParser(data: data)
        return parser.parse()
    }

    /// Load from the user's Application Support directory.
    public static func loadFromUserDirectory() -> TabContextMenuSpec? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let url = support.appendingPathComponent("NotepadMac/tabContextMenu.xml")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(xml: content)
    }
}

// MARK: - XML Parser

private final class TabContextMenuXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var items: [TabContextMenuSpecItem] = []
    private var insideRoot = false
    private var currentFolder: String? = nil

    init(data: Data) { self.data = data }

    func parse() -> TabContextMenuSpec? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return TabContextMenuSpec(items: items)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "TabContextMenu" {
            insideRoot = true
            return
        }
        guard insideRoot, elementName == "Item" else { return }

        let folder = attributes["FolderName"]

        // id="0" = separator
        if attributes["id"] == "0" {
            if folder == nil {
                items.append(.separator)
            }
            // folder-level separators are ignored (submenus handle them)
            return
        }

        guard let menuItemName = attributes["MenuItemName"] else { return }
        let displayName = attributes["ItemNameAs"]

        if let action = actionForItemName(menuItemName) {
            items.append(.action(action, displayName: displayName, folderName: folder))
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "TabContextMenu" { insideRoot = false }
    }

    private func actionForItemName(_ name: String) -> TabContextMenuAction? {
        // Direct raw value match first
        if let action = TabContextMenuAction(rawValue: name) { return action }
        // Legacy / alternate names
        switch name {
        case "Close All BUT This": return .closeOthers
        case "Reload": return .reload
        case "Print": return .print
        case "Open in Default Viewer": return .openInDefaultViewer
        case "Move to New Instance", "Open in New Instance",
             "Move to Other View", "Clone to Other View": return nil // not supported on macOS
        default: return nil
        }
    }
}
