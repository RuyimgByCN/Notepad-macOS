import XCTest
@testable import NotepadMacCore

final class EditorContextMenuSpecTests: XCTestCase {
    // Default entries from PowerEditor/src/MISC/Common/NppConstants.h.
    private let upstreamDefaultXML = """
    <NotepadPlus><ScintillaContextMenu>
        <Item MenuEntryName="Edit" MenuItemName="Cut"/>
        <Item MenuEntryName="Edit" MenuItemName="Copy"/>
        <Item MenuEntryName="Edit" MenuItemName="Paste"/>
        <Item MenuEntryName="Edit" MenuItemName="Delete"/>
        <Item MenuEntryName="Edit" MenuItemName="Select all"/>
        <Item MenuEntryName="Edit" MenuItemName="Begin/End Select"/>
        <Item MenuEntryName="Edit" MenuItemName="Begin/End Select in Column Mode"/>
        <Item id="0"/>
        <Item FolderName="Style all occurrences of token" TranslateID="contextMenu-styleAlloccurrencesOfToken" id="43022"/>
        <Item FolderName="Style all occurrences of token" TranslateID="contextMenu-styleAlloccurrencesOfToken" id="43024"/>
        <Item FolderName="Style all occurrences of token" TranslateID="contextMenu-styleAlloccurrencesOfToken" id="43026"/>
        <Item FolderName="Style all occurrences of token" TranslateID="contextMenu-styleAlloccurrencesOfToken" id="43028"/>
        <Item FolderName="Style all occurrences of token" TranslateID="contextMenu-styleAlloccurrencesOfToken" id="43030"/>
        <Item FolderName="Style one token" TranslateID="contextMenu-styleOneToken" id="43062"/>
        <Item FolderName="Style one token" TranslateID="contextMenu-styleOneToken" id="43063"/>
        <Item FolderName="Style one token" TranslateID="contextMenu-styleOneToken" id="43064"/>
        <Item FolderName="Style one token" TranslateID="contextMenu-styleOneToken" id="43065"/>
        <Item FolderName="Style one token" TranslateID="contextMenu-styleOneToken" id="43066"/>
        <Item FolderName="Clear style" TranslateID="contextMenu-clearStyle" id="43023"/>
        <Item FolderName="Clear style" TranslateID="contextMenu-clearStyle" id="43025"/>
        <Item FolderName="Clear style" TranslateID="contextMenu-clearStyle" id="43027"/>
        <Item FolderName="Clear style" TranslateID="contextMenu-clearStyle" id="43029"/>
        <Item FolderName="Clear style" TranslateID="contextMenu-clearStyle" id="43031"/>
        <Item FolderName="Clear style" TranslateID="contextMenu-clearStyle" id="43032"/>
        <Item id="0"/>
        <Item FolderName="Plugin commands" PluginEntryName="MIME Tools" PluginCommandItemName="Base64 Encode"/>
        <Item FolderName="Plugin commands" PluginEntryName="MIME Tools" PluginCommandItemName="Base64 Decode"/>
        <Item FolderName="Plugin commands" PluginEntryName="NppExport" PluginCommandItemName="Copy all formats to clipboard" ItemNameAs="Copy Text with Syntax Highlighting"/>
        <Item id="0"/>
        <Item MenuEntryName="Edit" MenuItemName="UPPERCASE"/>
        <Item MenuEntryName="Edit" MenuItemName="lowercase"/>
        <Item id="0"/>
        <Item MenuEntryName="Edit" MenuItemName="Open File"/>
        <Item MenuEntryName="Edit" MenuItemName="Search on Internet"/>
        <Item id="0"/>
        <Item MenuEntryName="Edit" MenuItemName="Toggle Single Line Comment"/>
        <Item MenuEntryName="Edit" MenuItemName="Block Comment"/>
        <Item MenuEntryName="Edit" MenuItemName="Block Uncomment"/>
        <Item id="0"/>
        <Item MenuEntryName="View" MenuItemName="Hide lines"/>
    </ScintillaContextMenu></NotepadPlus>
    """

    func testParsesEveryUpstreamDefaultEntry() throws {
        let spec = try XCTUnwrap(EditorContextMenuSpec.parse(xml: upstreamDefaultXML))
        XCTAssertEqual(spec.items.count, 40)

        let actions = spec.items.compactMap { item -> EditorContextMenuAction? in
            guard case let .action(action, _, _) = item else { return nil }
            return action
        }
        XCTAssertEqual(actions, [
            .cut, .copy, .paste, .delete, .selectAll, .beginOrEndSelect,
            .beginOrEndSelectInColumnMode, .upperCase, .lowerCase, .openSelectedFile,
            .searchOnInternet, .toggleLineComment, .blockComment, .blockUncomment, .hideLines
        ])

        let styleCommands = spec.items.compactMap { item -> EditorContextMenuStyleCommand? in
            guard case let .styleCommand(command, _, _) = item else { return nil }
            return command
        }
        XCTAssertEqual(styleCommands, [
            .markAll(.style1), .markAll(.style2), .markAll(.style3),
            .markAll(.style4), .markAll(.style5),
            .markOne(.style1), .markOne(.style2), .markOne(.style3),
            .markOne(.style4), .markOne(.style5),
            .clear(.style1), .clear(.style2), .clear(.style3),
            .clear(.style4), .clear(.style5), .clearAll
        ])
    }

    func testNumericActionsMatchUpstreamIDs() throws {
        let spec = try XCTUnwrap(EditorContextMenuSpec.parse(xml: """
        <ScintillaContextMenu>
            <Item id="42001"/><Item id="42002"/><Item id="42005"/>
            <Item id="42006"/><Item id="42007"/>
            <Item id="42016"/><Item id="42017"/><Item id="42067"/><Item id="42071"/>
            <Item id="42022"/><Item id="42023"/><Item id="42047"/>
            <Item id="42020"/><Item id="42089"/><Item id="44042"/>
        </ScintillaContextMenu>
        """))
        let actions = spec.items.compactMap { item -> EditorContextMenuAction? in
            guard case let .action(action, _, _) = item else { return nil }
            return action
        }
        XCTAssertEqual(actions, [
            .cut, .copy, .paste, .delete, .selectAll,
            .upperCase, .lowerCase, .properCase, .toggleCase,
            .toggleLineComment, .blockComment, .blockUncomment,
            .beginOrEndSelect, .beginOrEndSelectInColumnMode, .hideLines
        ])
    }

    func testPreservesFoldersDisplayOverridesAndPluginCommands() throws {
        let spec = try XCTUnwrap(EditorContextMenuSpec.parse(xml: """
        <ScintillaContextMenu>
            <Item FolderName="我的样式" ItemNameAs="红色" id="43022"/>
            <Item FolderName="我的编辑" ItemNameAs="复制选中内容" MenuItemName="Copy"/>
            <Item FolderName="Plugin commands" ItemNameAs="编码" PluginEntryName="MIME Tools" PluginCommandItemName="Base64 Encode"/>
            <Item id="0"/>
        </ScintillaContextMenu>
        """))
        XCTAssertEqual(spec.items.count, 4)
        guard case let .styleCommand(command, displayName, folderName) = spec.items[0] else {
            return XCTFail("Expected a style command")
        }
        XCTAssertEqual(command, .markAll(.style1))
        XCTAssertEqual(displayName, "红色")
        XCTAssertEqual(folderName, "我的样式")
        guard case let .action(action, actionName, actionFolder) = spec.items[1] else {
            return XCTFail("Expected an edit action")
        }
        XCTAssertEqual(action, .copy)
        XCTAssertEqual(actionName, "复制选中内容")
        XCTAssertEqual(actionFolder, "我的编辑")
        guard case let .pluginCommand(plugin, pluginCommand, pluginName, pluginFolder) = spec.items[2] else {
            return XCTFail("Expected a plugin command")
        }
        XCTAssertEqual(plugin, "MIME Tools")
        XCTAssertEqual(pluginCommand, "Base64 Encode")
        XCTAssertEqual(pluginName, "编码")
        XCTAssertEqual(pluginFolder, "Plugin commands")
        guard case .separator = spec.items[3] else { return XCTFail("Expected a separator") }
    }

    func testUnknownIDsAndItemsOutsideContextMenuAreIgnored() throws {
        let spec = try XCTUnwrap(EditorContextMenuSpec.parse(xml: """
        <NotepadPlus>
            <Item MenuItemName="Copy"/>
            <ScintillaContextMenu>
                <Item id="999999"/><Item id="not-a-number"/>
                <Item MenuItemName="Unknown command"/>
            </ScintillaContextMenu>
            <Item id="43022"/>
        </NotepadPlus>
        """))
        XCTAssertTrue(spec.items.isEmpty)
    }

    func testInvalidXMLReturnsNilAndValidEmptyXMLReturnsEmptySpec() throws {
        XCTAssertNil(EditorContextMenuSpec.parse(xml: "<ScintillaContextMenu><Item id=\"43022\">"))
        let spec = try XCTUnwrap(EditorContextMenuSpec.parse(xml: "<ScintillaContextMenu/>"))
        XCTAssertTrue(spec.items.isEmpty)
    }
}
