import AppKit
import NotepadMacCore

extension AppMenu {
    @MainActor
    static func addSearchStyleMenus(to menu: NSMenu, target: AnyObject?) {
        let groups: [(Localization.Key, String, [EditorContextMenuStyleCommand])] = [
            (.searchStyleMenu, "Style All Occurrences of Token", SearchMarkStyle.allCases.map(EditorContextMenuStyleCommand.markAll)),
            (.searchStyleOneToken, "Style One Token", SearchMarkStyle.allCases.map(EditorContextMenuStyleCommand.markOne)),
            (.searchClearStyle, "Clear Style", SearchMarkStyle.allCases.map(EditorContextMenuStyleCommand.clear) + [.clearAll])
        ]
        for (key, defaultTitle, commands) in groups {
            let title = Localization.string(key, default: defaultTitle)
            let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            for command in commands {
                submenu.addItem(searchStyleMenuItem(for: command, title: nil, target: target))
            }
            parent.submenu = submenu
            menu.addItem(parent)
        }
    }

    @MainActor
    static func searchStyleMenuItem(for command: EditorContextMenuStyleCommand, title: String?, target: AnyObject?) -> NSMenuItem {
        let key: Localization.Key
        let defaultTitle: String
        let action: Selector
        let style: SearchMarkStyle?
        switch command {
        case .markAll(let value):
            key = [.searchMarkAllStyle1, .searchMarkAllStyle2, .searchMarkAllStyle3, .searchMarkAllStyle4, .searchMarkAllStyle5][value.rawValue - 1]
            defaultTitle = "Mark All Using Style \(value.rawValue)"
            action = #selector(EditorWindowController.markAllUsingStyle(_:))
            style = value
        case .markOne(let value):
            key = [.searchMarkOneStyle1, .searchMarkOneStyle2, .searchMarkOneStyle3, .searchMarkOneStyle4, .searchMarkOneStyle5][value.rawValue - 1]
            defaultTitle = "Mark One Using Style \(value.rawValue)"
            action = #selector(EditorWindowController.markOneUsingStyle(_:))
            style = value
        case .clear(let value):
            key = [.searchUnmarkAllStyle1, .searchUnmarkAllStyle2, .searchUnmarkAllStyle3, .searchUnmarkAllStyle4, .searchUnmarkAllStyle5][value.rawValue - 1]
            defaultTitle = "Clear Style \(value.rawValue)"
            action = #selector(EditorWindowController.unmarkAllUsingStyle(_:))
            style = value
        case .clearAll:
            key = .searchClearAllStyles
            defaultTitle = "Clear All Styles"
            action = #selector(EditorWindowController.clearAllStyles(_:))
            style = nil
        }
        let item = NSMenuItem(title: title ?? Localization.string(key, default: defaultTitle), action: action, keyEquivalent: "")
        item.target = target
        item.representedObject = style
        return item
    }
}
