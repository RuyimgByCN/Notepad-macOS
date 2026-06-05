import Foundation

/// One item in an editor (Scintilla) context menu spec loaded from contextMenu.xml.
public enum EditorContextMenuSpecItem: Sendable {
    case separator
    case action(EditorContextMenuAction, displayName: String?, folderName: String?)
    case pluginCommand(pluginName: String, commandName: String, displayName: String?, folderName: String?)
}

/// Editor right-click context menu actions that map to Notepad++ contextMenu.xml entries.
/// The rawValue is a canonical key used for XML lookup; actual display strings come from
/// the (MenuEntryName, MenuItemName) pair or ItemNameAs override.
public enum EditorContextMenuAction: String, Sendable, CaseIterable {
    // Edit group
    case undo               = "Undo"
    case redo               = "Redo"
    case cut                = "Cut"
    case copy               = "Copy"
    case paste              = "Paste"
    case delete             = "Delete"
    case selectAll          = "Select All"
    case copyAsHTML         = "Copy as HTML (HEX)"
    case copyAsRTF          = "Copy as RTF"
    case duplicateLine      = "Duplicate Current Line"
    case deleteLine         = "Delete Current Line"
    case joinLines          = "Join Lines"
    case upperCase          = "UPPERCASE"
    case lowerCase          = "lowercase"
    case properCase         = "Proper Case"
    case toggleCase         = "Toggle Case"

    // Search group
    case find               = "Find..."
    case findNext           = "Find Next"
    case findPrevious       = "Find Previous"
    case findAll            = "Find All"
    case replace            = "Replace..."
    case findInFiles        = "Find in Files..."
    case goToLine           = "Go to..."
    case markAllFind        = "Mark All"
    case searchOnInternet   = "Search on Internet"

    // View group
    case toggleFold         = "Toggle Fold"
    case foldAll            = "Fold All"
    case unfoldAll          = "Unfold All"
    case collapseCurrentLevel  = "Collapse Current Level"
    case uncollapseCurrentLevel = "Uncollapse Current Level"
    case collapseAllLevels  = "Collapse All"
    case uncollapseAllLevels = "Uncollapse All"

    // File group
    case openSelectedFile   = "Open File"

    // Misc
    case toggleReadOnly     = "Set Read-Only"
    case clearReadOnly      = "Clear Read-Only Flag"
    case copyFullPath        = "Full File Path to Clipboard"
    case copyFilename        = "Filename to Clipboard"
    case copyDirPath         = "Current Dir. Path to Clipboard"
}

/// Parsed representation of contextMenu.xml.
public struct EditorContextMenuSpec: Sendable {
    public let items: [EditorContextMenuSpecItem]

    public init(items: [EditorContextMenuSpecItem]) {
        self.items = items
    }

    /// Parse contextMenu.xml content into a spec. Returns nil if the XML is invalid.
    public static func parse(xml: String) -> EditorContextMenuSpec? {
        guard let data = xml.data(using: .utf8) else { return nil }
        let parser = EditorContextMenuXMLParser(data: data)
        return parser.parse()
    }

    /// Load from the user's Application Support directory.
    public static func loadFromUserDirectory() -> EditorContextMenuSpec? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let url = support.appendingPathComponent("NotepadMac/contextMenu.xml")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(xml: content)
    }
}

// MARK: - XML Parser

private final class EditorContextMenuXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var items: [EditorContextMenuSpecItem] = []
    private var insideContextMenu = false

    init(data: Data) { self.data = data }

    func parse() -> EditorContextMenuSpec? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return EditorContextMenuSpec(items: items)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attrs: [String: String] = [:]) {
        if elementName == "ScintillaContextMenu" {
            insideContextMenu = true
            return
        }
        guard insideContextMenu, elementName == "Item" else { return }

        let folder = attrs["FolderName"]
        let displayName = attrs["ItemNameAs"]

        // id="0" = separator (only at top level)
        if attrs["id"] == "0" {
            if folder == nil { items.append(.separator) }
            return
        }

        // Plugin item
        if let pluginEntry = attrs["PluginEntryName"],
           let pluginCmd = attrs["PluginCommandItemName"] {
            items.append(.pluginCommand(
                pluginName: pluginEntry,
                commandName: pluginCmd,
                displayName: displayName,
                folderName: folder
            ))
            return
        }

        // Regular menu item — match by MenuItemName (primary key)
        guard let menuItemName = attrs["MenuItemName"] else { return }
        if let action = actionForItemName(menuItemName) {
            items.append(.action(action, displayName: displayName, folderName: folder))
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "ScintillaContextMenu" { insideContextMenu = false }
    }

    private func actionForItemName(_ name: String) -> EditorContextMenuAction? {
        if let action = EditorContextMenuAction(rawValue: name) { return action }
        switch name {
        // Alternate spellings used in older contextMenu.xml files
        case "Copy as HTML":       return .copyAsHTML
        case "Copy RTF":           return .copyAsRTF
        case "Duplicate Line":     return .duplicateLine
        case "Delete Line":        return .deleteLine
        case "Upper Case":         return .upperCase
        case "Lower Case":         return .lowerCase
        case "Find Next...":       return .findNext
        case "Find Previous...":   return .findPrevious
        case "Open Selected File": return .openSelectedFile
        case "Set Read Only":      return .toggleReadOnly
        case "Clear Read Only":    return .clearReadOnly
        default:                   return nil
        }
    }
}
