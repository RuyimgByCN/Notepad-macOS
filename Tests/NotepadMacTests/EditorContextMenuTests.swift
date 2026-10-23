import AppKit
import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@MainActor
@Suite(.serialized)
struct EditorContextMenuTests {
    @Test func selectedUnicodeTextOffersDefaultMenuWithoutChangingSelection() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let selection = selectUnicodeText(in: controller)

        let menu = try contextMenu(in: controller)

        #expect(menu === controller.editorSurface.view.menu)
        #expect(menu.items.contains { $0.action == #selector(NSText.copy(_:)) })
        #expect(menu.items.contains { $0.action == #selector(EditorWindowController.findAllInDocument(_:)) })
        #expect(controller.editorSurface.selectedRange == selection)
    }

    @Test func customMenuSpecReplacesContentViewMenu() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let selection = selectUnicodeText(in: controller)
        controller.applyEditorContextMenuSpec(EditorContextMenuSpec(items: [
            .action(.copy, displayName: "Custom Copy", folderName: nil),
            .action(.findAll, displayName: "Custom Find All", folderName: nil)
        ]))

        let menu = try contextMenu(in: controller)

        #expect(menu === controller.editorSurface.view.menu)
        #expect(menu.items.map(\.title) == ["Custom Copy", "Custom Find All"])
        #expect(menu.items.map(\.action) == [#selector(NSText.copy(_:)), #selector(EditorWindowController.findAllInDocument(_:))])
        #expect(controller.editorSurface.selectedRange == selection)
    }

    @Test func emptyAndSeparatorOnlySpecsRetainDefaultMenu() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let selection = selectUnicodeText(in: controller)

        for items: [EditorContextMenuSpecItem] in [[], [.separator], [.separator, .separator]] {
            controller.applyEditorContextMenuSpec(EditorContextMenuSpec(items: items))

            let menu = try contextMenu(in: controller)

            #expect(menu === controller.editorSurface.view.menu)
            #expect(menu.items.contains { $0.action == #selector(NSText.copy(_:)) })
            #expect(menu.items.contains { $0.action == #selector(EditorWindowController.findAllInDocument(_:)) })
            #expect(controller.editorSurface.selectedRange == selection)
        }
    }

    @Test func defaultMenuOffersUpstreamSelectionAndEditingCommands() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let menu = try contextMenu(in: controller)
        let actions = [
            #selector(NSText.delete(_:)),
            #selector(EditorWindowController.beginOrEndSelect(_:)),
            #selector(EditorWindowController.beginOrEndSelectInColumnMode(_:)),
            #selector(EditorWindowController.uppercaseSelection(_:)),
            #selector(EditorWindowController.lowercaseSelection(_:)),
            #selector(EditorWindowController.hideSelectedLines(_:))
        ]

        for action in actions {
            #expect(menu.items.contains { $0.action == action }, "Missing \(NSStringFromSelector(action))")
        }
    }

    @Test func defaultMenuContainsFiveStylesForEachStyleCommand() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let menu = try contextMenu(in: controller)

        try expectStyleCommandGroups(in: menu, targeting: controller)
    }

    @Test func upstreamNumericStyleIDsBuildAllSixteenExecutableMenuItems() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let spec = try #require(EditorContextMenuSpec.parse(xml: upstreamStyleMenuXML))
        #expect(spec.items.count == 16)
        controller.applyEditorContextMenuSpec(spec)

        let menu = try contextMenu(in: controller)

        #expect(menu.items.map(\.title) == [
            Localization.string(.searchStyleMenu, default: "Style all occurrences of token"),
            Localization.string(.searchStyleOneToken, default: "Style one token"),
            Localization.string(.searchClearStyle, default: "Clear style")
        ])
        try expectStyleCommandGroups(in: menu, targeting: controller)
    }

    @Test func unavailablePluginCommandsAreOmittedAndDoNotSuppressDefaultMenu() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let unavailable = EditorContextMenuSpecItem.pluginCommand(
            pluginName: "MissingContextMenuPlugin-\(UUID().uuidString)",
            commandName: "Missing Command",
            displayName: "Unavailable Plugin Command",
            folderName: "Unavailable Plugin"
        )
        controller.applyEditorContextMenuSpec(EditorContextMenuSpec(items: [unavailable]))

        let fallback = try contextMenu(in: controller)

        #expect(fallback.items.contains { $0.action == #selector(NSText.copy(_:)) })
        #expect(fallback.items.contains { $0.action == #selector(EditorWindowController.findAllInDocument(_:)) })
        #expect(!fallback.items.contains { $0.title == "Unavailable Plugin" })

        controller.applyEditorContextMenuSpec(EditorContextMenuSpec(items: [
            .action(.copy, displayName: "Copy Only", folderName: nil), unavailable
        ]))

        let mixed = try contextMenu(in: controller)

        #expect(mixed.items.map(\.title) == ["Copy Only"])
        #expect(mixed.items.map(\.action) == [#selector(NSText.copy(_:))])
    }

    private func expectStyleCommandGroups(in menu: NSMenu, targeting controller: EditorWindowController) throws {
        let commands = [
            #selector(EditorWindowController.markAllUsingStyle(_:)),
            #selector(EditorWindowController.markOneUsingStyle(_:)),
            #selector(EditorWindowController.unmarkAllUsingStyle(_:))
        ]

        for command in commands {
            let submenu = try styleMenu(for: command, in: menu)
            let styleItems = submenu.items.filter { $0.action == command }
            #expect(styleItems.count == 5)
            #expect(styleItems.compactMap { $0.representedObject as? SearchMarkStyle } == SearchMarkStyle.allCases)
            #expect(styleItems.allSatisfy { $0.target === controller })
        }

        let clearMenu = try styleMenu(for: #selector(EditorWindowController.unmarkAllUsingStyle(_:)), in: menu)
        let clearAll = try #require(clearMenu.items.first { $0.action == #selector(EditorWindowController.clearAllStyles(_:)) })
        #expect(clearAll.target === controller)
        #expect(clearAll.representedObject == nil)
        #expect(clearMenu.items.filter { !$0.isSeparatorItem }.count == 6)
    }

    @Test(arguments: [false, true])
    func styleMenuActionsMarkAndClearUnicodeSelectionInScintilla(usesUpstreamXML: Bool) throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        if usesUpstreamXML {
            let spec = try #require(EditorContextMenuSpec.parse(xml: upstreamStyleMenuXML))
            controller.applyEditorContextMenuSpec(spec)
        }
        let prefix = "开头 "
        let token = "token🚀"
        let middle = " 中段 "
        controller.editorSurface.text = prefix + token + middle + token + " 结尾"
        let selection = NSRange(location: prefix.utf16.count, length: token.utf16.count)
        let matches = [selection, NSRange(location: (prefix + token + middle).utf16.count, length: token.utf16.count)]
        controller.editorSurface.setSelectedRange(selection)
        let menu = try contextMenu(in: controller)
        let allMenu = try styleMenu(for: #selector(EditorWindowController.markAllUsingStyle(_:)), in: menu)
        let oneMenu = try styleMenu(for: #selector(EditorWindowController.markOneUsingStyle(_:)), in: menu)
        let clearMenu = try styleMenu(for: #selector(EditorWindowController.unmarkAllUsingStyle(_:)), in: menu)

        for style in SearchMarkStyle.allCases {
            try performStyleAction(#selector(EditorWindowController.markAllUsingStyle(_:)), style: style, in: allMenu)
            #expect(controller.editorSurface.indicatorRanges(style) == matches)
            #expect(controller.editorSurface.selectedRange == selection)

            try performStyleAction(#selector(EditorWindowController.unmarkAllUsingStyle(_:)), style: style, in: clearMenu)
            #expect(controller.editorSurface.indicatorRanges(style).isEmpty)
            #expect(controller.editorSurface.selectedRange == selection)

            try performStyleAction(#selector(EditorWindowController.markOneUsingStyle(_:)), style: style, in: oneMenu)
            #expect(controller.editorSurface.indicatorRanges(style) == [selection])
            #expect(controller.editorSurface.selectedRange == selection)
        }

        for style in SearchMarkStyle.allCases {
            #expect(controller.editorSurface.indicatorRanges(style) == [selection])
        }
        let clearAllIndex = try #require(clearMenu.items.firstIndex { $0.action == #selector(EditorWindowController.clearAllStyles(_:)) })
        clearMenu.performActionForItem(at: clearAllIndex)
        for style in SearchMarkStyle.allCases {
            #expect(controller.editorSurface.indicatorRanges(style).isEmpty)
        }
        #expect(controller.editorSurface.selectedRange == selection)
    }

    @Test func scintillaReportsIndependentStyleRangesAfterUnicodePrefixes() throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        let text = "前缀🧪 first 中间🚀 second"
        controller.editorSurface.text = text
        let first = (text as NSString).range(of: "first")
        let second = (text as NSString).range(of: "second")

        controller.editorSurface.markAllWithIndicator(.style1, ranges: [first])
        controller.editorSurface.markAllWithIndicator(.style5, ranges: [second])

        #expect(controller.editorSurface.indicatorRanges(.style1) == [first])
        #expect(controller.editorSurface.indicatorRanges(.style5) == [second])
        #expect(controller.editorSurface.indicatorRanges(.style2).isEmpty)
    }

    @Test(arguments: [false, true])
    func deleteMenuPreservesUndoAndRespectsReadOnly(usesCustomSpec: Bool) throws {
        let controller = try makeController()
        defer { controller.editorSurface.teardown() }
        if usesCustomSpec {
            controller.applyEditorContextMenuSpec(EditorContextMenuSpec(items: [
                .action(.delete, displayName: nil, folderName: nil)
            ]))
        }
        let original = "前缀 删除🚀 末尾"
        let selection = (original as NSString).range(of: "删除🚀")
        controller.editorSurface.text = original
        controller.editorSurface.setSelectedRange(selection)
        let menu = try contextMenu(in: controller)
        let index = try #require(menu.items.firstIndex { $0.action == #selector(NSText.delete(_:)) })
        let item = menu.items[index]
        #expect(item.target === controller)
        #expect(controller.validateMenuItem(item))

        menu.performActionForItem(at: index)

        #expect(controller.editorSurface.text == "前缀  末尾")
        #expect(controller.editorSurface.selectedRange == NSRange(location: selection.location, length: 0))
        let contentView = try #require(descendants(of: controller.editorSurface.view).first {
            NSStringFromClass(type(of: $0)).contains("SCIContentView")
        })
        #expect(contentView.tryToPerform(Selector(("undo:")), with: nil))
        #expect(controller.editorSurface.text == original)

        controller.editorSurface.setSelectedRange(selection)
        controller.editorSurface.isReadOnly = true
        #expect(!controller.validateMenuItem(item))
        menu.performActionForItem(at: index)
        #expect(controller.editorSurface.text == original)

        controller.editorSurface.isReadOnly = false
        controller.editorSurface.setSelectedRange(NSRange(location: selection.location, length: 0))
        #expect(!controller.validateMenuItem(item))
        menu.performActionForItem(at: index)
        #expect(controller.editorSurface.text == original)
    }

    @Test func fallbackSurfaceDeletesOnlyEditableSelections() {
        let surface = TextViewEditorSurface()
        surface.text = "前缀 删除🚀 末尾"
        surface.setSelectedRange((surface.text as NSString).range(of: "删除🚀"))
        surface.isReadOnly = true
        surface.deleteSelection()
        #expect(surface.text == "前缀 删除🚀 末尾")
        surface.isReadOnly = false
        surface.deleteSelection()
        #expect(surface.text == "前缀  末尾")
        surface.deleteSelection()
        #expect(surface.text == "前缀  末尾")
    }

    private func styleMenu(for action: Selector, in menu: NSMenu) throws -> NSMenu {
        try #require(menu.items.compactMap(\.submenu).first { submenu in
            submenu.items.contains { $0.action == action }
        })
    }

    private func performStyleAction(_ action: Selector, style: SearchMarkStyle, in menu: NSMenu) throws {
        let index = try #require(menu.items.firstIndex {
            $0.action == action && ($0.representedObject as? SearchMarkStyle) == style
        })
        menu.performActionForItem(at: index)
    }

    private func makeController() throws -> EditorWindowController {
        let probe = try #require(ScintillaEditorSurface.load(), "Context menu regression tests require the real Scintilla framework")
        probe.teardown()
        let upstream = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "upstream/notepad-plus-plus/PowerEditor/src")
        let controller = EditorWindowController(
            languageCatalog: try LanguageCatalog.load(from: upstream.appending(path: "langs.model.xml")),
            styleCatalog: try StyleCatalog.load(from: upstream.appending(path: "stylers.model.xml"))
        )
        _ = try #require(controller.editorSurface as? ScintillaEditorSurface)
        return controller
    }

    private func selectUnicodeText(in controller: EditorWindowController) -> NSRange {
        let prefix = "开头 "
        let selectedText = "选中文本🚀 café"
        controller.editorSurface.text = prefix + selectedText + " 末尾"
        let selection = NSRange(location: prefix.utf16.count, length: selectedText.utf16.count)
        controller.editorSurface.setSelectedRange(selection)
        return selection
    }

    private func contextMenu(in controller: EditorWindowController) throws -> NSMenu {
        let view = controller.editorSurface.view
        view.layoutSubtreeIfNeeded()
        let contentView = try #require(descendants(of: view).first {
            NSStringFromClass(type(of: $0)).contains("SCIContentView")
        })
        let window = try #require(controller.window)
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: contentView.convert(NSPoint(x: 20, y: 8), to: nil),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ))
        return try #require(contentView.menu(for: event))
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants)
    }

    private var upstreamStyleMenuXML: String {
        """
        <NotepadPlus><ScintillaContextMenu>
        <Item FolderName="Style all occurrences of token" id="43022"/>
        <Item FolderName="Style all occurrences of token" id="43024"/>
        <Item FolderName="Style all occurrences of token" id="43026"/>
        <Item FolderName="Style all occurrences of token" id="43028"/>
        <Item FolderName="Style all occurrences of token" id="43030"/>
        <Item FolderName="Style one token" id="43062"/>
        <Item FolderName="Style one token" id="43063"/>
        <Item FolderName="Style one token" id="43064"/>
        <Item FolderName="Style one token" id="43065"/>
        <Item FolderName="Style one token" id="43066"/>
        <Item FolderName="Clear style" id="43023"/>
        <Item FolderName="Clear style" id="43025"/>
        <Item FolderName="Clear style" id="43027"/>
        <Item FolderName="Clear style" id="43029"/>
        <Item FolderName="Clear style" id="43031"/>
        <Item FolderName="Clear style" id="43032"/>
        </ScintillaContextMenu></NotepadPlus>
        """
    }
}
