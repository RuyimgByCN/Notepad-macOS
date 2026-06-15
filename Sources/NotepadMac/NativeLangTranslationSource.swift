import Foundation

struct NativeLangTranslations: Sendable {
    struct MessageBox: Equatable, Sendable {
        let title: String
        let message: String
    }

    private let mainMenuEntries: [String: String]
    private let subMenuEntries: [String: String]
    private let commands: [String: String]
    private let dialogTitles: [String: String]
    private let preferenceTitle: String?
    private let preferenceGlobalItems: [String: String]
    private let dialogEntries: [String: String]
    private let messageBoxes: [String: MessageBox]
    private let defaultValueTranslations: [String: String]

    init(
        mainMenuEntries: [String: String],
        subMenuEntries: [String: String],
        commands: [String: String],
        dialogTitles: [String: String],
        preferenceTitle: String?,
        preferenceGlobalItems: [String: String],
        dialogEntries: [String: String],
        messageBoxes: [String: MessageBox],
        defaultValueTranslations: [String: String]
    ) {
        self.mainMenuEntries = mainMenuEntries
        self.subMenuEntries = subMenuEntries
        self.commands = commands
        self.dialogTitles = dialogTitles
        self.preferenceTitle = preferenceTitle
        self.preferenceGlobalItems = preferenceGlobalItems
        self.dialogEntries = dialogEntries
        self.messageBoxes = messageBoxes
        self.defaultValueTranslations = defaultValueTranslations
    }

    func localizedValue(for localizationKey: String) -> String? {
        guard let lookup = NativeLangLookup.map[localizationKey] else { return nil }

        let rawValue: String?
        switch lookup {
        case let .mainMenu(menuID):
            rawValue = mainMenuEntries[menuID]
        case let .command(commandID):
            rawValue = commands[commandID]
        case let .dialogTitle(dialogName):
            rawValue = dialogTitles[dialogName]
        case .preferenceTitle:
            rawValue = preferenceTitle
        case let .preferenceGlobalItem(itemID):
            rawValue = preferenceGlobalItems[itemID]
        case let .subMenu(subMenuID):
            rawValue = subMenuEntries[subMenuID]
        case let .dialogEntry(entryKey):
            rawValue = dialogEntries[entryKey]
        }

        guard let rawValue else { return nil }
        return NativeLangLookup.sanitized(rawValue)
    }

    func localizedValue(forDefaultValue defaultValue: String) -> String? {
        defaultValueTranslations[NativeLangLookup.sanitized(defaultValue)]
    }

    func messageBox(tag: String) -> MessageBox? {
        messageBoxes[tag]
    }

    static func load(fileName: String, bundle: Bundle) -> NativeLangTranslations? {
        let fileBaseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        guard let xmlURL = bundle.url(forResource: fileBaseName, withExtension: "xml"),
              let englishURL = bundle.url(forResource: "english", withExtension: "xml"),
              let targetValues = NativeLangTranslationsParser.parse(xmlURL),
              let englishValues = NativeLangTranslationsParser.parse(englishURL)
        else { return nil }

        return NativeLangTranslations(
            mainMenuEntries: targetValues.mainMenuEntries,
            subMenuEntries: targetValues.subMenuEntries,
            commands: targetValues.commands,
            dialogTitles: targetValues.dialogTitles,
            preferenceTitle: targetValues.preferenceTitle,
            preferenceGlobalItems: targetValues.preferenceGlobalItems,
            dialogEntries: targetValues.translationEntries,
            messageBoxes: targetValues.messageBoxes,
            defaultValueTranslations: buildDefaultValueTranslations(english: englishValues, target: targetValues)
        )
    }

    private static func buildDefaultValueTranslations(
        english: NativeLangParsedValues,
        target: NativeLangParsedValues
    ) -> [String: String] {
        var translations: [String: String] = [:]

        func merge(_ englishValues: [String: String], _ targetValues: [String: String]) {
            for (identifier, englishValue) in englishValues {
                guard let localizedValue = targetValues[identifier] else { continue }
                translations[NativeLangLookup.sanitized(englishValue)] = NativeLangLookup.sanitized(localizedValue)
            }
        }

        merge(english.mainMenuEntries, target.mainMenuEntries)
        merge(english.subMenuEntries, target.subMenuEntries)
        merge(english.commands, target.commands)
        merge(english.dialogTitles, target.dialogTitles)
        merge(english.preferenceGlobalItems, target.preferenceGlobalItems)
        // Merge all Dialog/<name>/Item entries (Find, Column Editor, UDL StylerDialog,
        // Plugins, Preference sub-items, etc.) so that non-builtin languages translate
        // panel/control strings by matching their English default value. Without this,
        // ~1000 Mac-native UI strings fall back to English for every language besides
        // English/Chinese.
        merge(english.translationEntries, target.translationEntries)
        if let englishPreferenceTitle = english.preferenceTitle,
           let localizedPreferenceTitle = target.preferenceTitle {
            translations[NativeLangLookup.sanitized(englishPreferenceTitle)] = NativeLangLookup.sanitized(localizedPreferenceTitle)
        }

        return translations
    }
}

private enum NativeLangLookup {
    case mainMenu(String)
    case subMenu(String)
    case command(String)
    case dialogTitle(String)
    case preferenceTitle
    case preferenceGlobalItem(String)
    case dialogEntry(String)

    static let map: [String: NativeLangLookup] = [
        "app.preferences": .command("48011"),
        "menu.file": .mainMenu("file"),
        "menu.edit": .mainMenu("edit"),
        "menu.search": .mainMenu("search"),
        "menu.view": .mainMenu("view"),
        "menu.encoding": .mainMenu("encoding"),
        "menu.language": .mainMenu("language"),
        "menu.settings": .mainMenu("settings"),
        "menu.tools": .mainMenu("tools"),
        "menu.macro": .mainMenu("macro"),
        "menu.run": .mainMenu("run"),
        "menu.plugins": .mainMenu("Plugins"),
        "menu.window": .mainMenu("Window"),
        "bookmarkMenu": .subMenu("search-bookmark"),
        "udl.panelTitle": .subMenu("language-userDefinedLanguage"),
        "udl.column.extensions": .dialogEntry("Dialog/UserDefine/Item/20009"),
        "plugins.panelTitle": .dialogTitle("PluginsAdminDlg"),
        "plugins.install.panelTitle": .dialogTitle("PluginsAdminDlg"),
        "plugins.install.panelPrompt": .dialogEntry("Dialog/PluginsAdminDlg/Item/5503"),
        "plugins.column.plugin": .dialogEntry("Dialog/PluginsAdminDlg/ColumnPlugin"),
        "plugins.column.version": .dialogEntry("Dialog/PluginsAdminDlg/ColumnVersion"),
        "styleConfigurator.panelTitle": .dialogTitle("StyleConfig"),
        "styleConfigurator.language": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2225"),
        "styleConfigurator.bold": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2204"),
        "styleConfigurator.italic": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2205"),
        "styleConfigurator.foreground": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2206"),
        "styleConfigurator.background": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2207"),
        "styleConfigurator.font": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2208"),
        "styleConfigurator.size": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2209"),
        "styleConfigurator.style": .dialogEntry("Dialog/StyleConfig/SubDialog/Item/2211"),
        "udl.import": .dialogEntry("Dialog/UserDefine/Item/20015"),
        "udl.export": .dialogEntry("Dialog/UserDefine/Item/20016"),
        "udl.edit": .command("46250"),
        "udl.edit.panelTitle": .command("46250"),
        "udl.delete": .dialogEntry("Dialog/UserDefine/Item/20004"),
        "udl.edit.save": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/1"),
        "udl.edit.cancel": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/2"),
        "udl.edit.structuredStyleName": .dialogEntry("Dialog/UserDefine/Folder/Item/21102"),
        "udl.edit.structuredFgColor": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/25006"),
        "udl.edit.structuredBgColor": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/25007"),
        "udl.edit.structuredFontName": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/25031"),
        "udl.edit.structuredFontStyle": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/25030"),
        "udl.edit.structuredNesting": .dialogEntry("Dialog/UserDefine/StylerDialog/Item/25029"),
        "help.commandLineArguments": .command("47010"),
        "help.home": .command("47001"),
        "help.projectPage": .command("47002"),
        "help.onlineUserManual": .command("47003"),
        "help.forum": .command("47004"),
        "help.update": .command("47006"),
        "help.debugInfo": .command("47012"),
        "help.about": .command("47000"),
        "run.command": .command("49000"),
        "preferences.panelTitle": .preferenceTitle,
        "preferences.section.localization": .preferenceGlobalItem("6123"),
        "preferences.localization": .preferenceGlobalItem("6123")
    ]

    static func sanitized(_ text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "&" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "&" {
                    result.append("&")
                    index = text.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
                continue
            }

            result.append(character)
            index = text.index(after: index)
        }

        return result
    }
}

private struct NativeLangParsedValues: Sendable {
    let mainMenuEntries: [String: String]
    let subMenuEntries: [String: String]
    let commands: [String: String]
    let dialogTitles: [String: String]
    let preferenceTitle: String?
    let preferenceGlobalItems: [String: String]
    let translationEntries: [String: String]
    let messageBoxes: [String: NativeLangTranslations.MessageBox]
}

private final class NativeLangTranslationsParser: NSObject, XMLParserDelegate {
    private var mainMenuEntries: [String: String] = [:]
    private var subMenuEntries: [String: String] = [:]
    private var commands: [String: String] = [:]
    private var dialogTitles: [String: String] = [:]
    private var preferenceTitle: String?
    private var preferenceGlobalItems: [String: String] = [:]
    private var translationEntries: [String: String] = [:]
    private var messageBoxes: [String: NativeLangTranslations.MessageBox] = [:]

    private var elementStack: [String] = []

    static func parse(_ url: URL) -> NativeLangParsedValues? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = NativeLangTranslationsParser()
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return NativeLangParsedValues(
            mainMenuEntries: delegate.mainMenuEntries,
            subMenuEntries: delegate.subMenuEntries,
            commands: delegate.commands,
            dialogTitles: delegate.dialogTitles,
            preferenceTitle: delegate.preferenceTitle,
            preferenceGlobalItems: delegate.preferenceGlobalItems,
            translationEntries: delegate.translationEntries,
            messageBoxes: delegate.messageBoxes
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elementStack.append(elementName)
        let dialogName = currentDialogName()

        switch elementStack {
        case ["NotepadPlus", "Native-Langue", "Menu", "Main", "Entries", "Item"]:
            if let menuID = attributeDict["menuId"], let name = attributeDict["name"] {
                mainMenuEntries[menuID] = name
                translationEntries["Menu/Main/Entries/\(menuID)"] = name
            }
        case ["NotepadPlus", "Native-Langue", "Menu", "Main", "SubEntries", "Item"]:
            if let subMenuID = attributeDict["subMenuId"], let name = attributeDict["name"] {
                subMenuEntries[subMenuID] = name
                translationEntries["Menu/Main/SubEntries/\(subMenuID)"] = name
            }
        case ["NotepadPlus", "Native-Langue", "Menu", "Main", "Commands", "Item"]:
            if let commandID = attributeDict["id"], let name = attributeDict["name"] {
                commands[commandID] = name
                translationEntries["Menu/Main/Commands/\(commandID)"] = name
            }
        case ["NotepadPlus", "Native-Langue", "Dialog", "Preference"]:
            preferenceTitle = attributeDict["title"] ?? preferenceTitle
            if let title = attributeDict["title"] {
                dialogTitles["Preference"] = title
                translationEntries["Dialog/Preference/@title"] = title
            }
        case ["NotepadPlus", "Native-Langue", "Dialog", "Preference", "Global", "Item"]:
            if let itemID = attributeDict["id"], let name = attributeDict["name"] {
                preferenceGlobalItems[itemID] = name
                translationEntries["Dialog/Preference/Global/\(itemID)"] = name
            }
        default:
            if elementStack.count == 4,
               elementStack[0] == "NotepadPlus",
               elementStack[1] == "Native-Langue",
               elementStack[2] == "MessageBox",
               let title = attributeDict["title"],
               let message = attributeDict["message"] {
                messageBoxes[elementStack[3]] = NativeLangTranslations.MessageBox(title: title, message: message)
            }

            if let dialogName, let title = attributeDict["title"] {
                dialogTitles[dialogName] = title
                translationEntries["Dialog/\(dialogName)/@title"] = title
            }

            if let dialogName, let itemID = attributeDict["id"], let name = attributeDict["name"] {
                let subpath = dialogSubpath()
                let prefix = subpath.isEmpty ? "Dialog/\(dialogName)" : "Dialog/\(dialogName)/\(subpath)"
                translationEntries["\(prefix)/Item/\(itemID)"] = name
            } else if let dialogName, let name = attributeDict["name"] {
                let subpath = dialogSubpath()
                let prefix = subpath.isEmpty ? "Dialog/\(dialogName)" : "Dialog/\(dialogName)/\(subpath)"
                translationEntries["\(prefix)/\(elementName)"] = name
            }

            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if !elementStack.isEmpty {
            _ = elementStack.popLast()
        }
    }

    private func currentDialogName() -> String? {
        guard let dialogIndex = elementStack.firstIndex(of: "Dialog"),
              dialogIndex + 1 < elementStack.count
        else {
            return nil
        }

        return elementStack[dialogIndex + 1]
    }

    private func dialogSubpath() -> String {
        guard let dialogIndex = elementStack.firstIndex(of: "Dialog"),
              dialogIndex + 2 < elementStack.count
        else {
            return ""
        }

        let pathComponents = elementStack[(dialogIndex + 2)..<elementStack.count - 1]
        return pathComponents.joined(separator: "/")
    }
}
