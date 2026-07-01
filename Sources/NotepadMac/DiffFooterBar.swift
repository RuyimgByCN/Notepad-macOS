import AppKit
import NotepadMacCore

/// Bottom bar for the compare window (matches Notepad-- style):
/// left/right encoding + save-encoding selectors and a drag hint.
@MainActor
final class DiffFooterBar: NSView {
    struct State: Equatable {
        var leftEncoding: String.Encoding
        var leftSaveEncoding: String.Encoding
        var rightEncoding: String.Encoding
        var rightSaveEncoding: String.Encoding
    }

    var onChange: ((State) -> Void)?

    private let leftLabel = NSTextField(labelWithString: "")
    private let leftPopup = NSPopUpButton()
    private let leftSaveLabel = NSTextField(labelWithString: "")
    private let leftSavePopup = NSPopUpButton()

    private let rightLabel = NSTextField(labelWithString: "")
    private let rightPopup = NSPopUpButton()
    private let rightSaveLabel = NSTextField(labelWithString: "")
    private let rightSavePopup = NSPopUpButton()

    private let hintLabel = NSTextField(labelWithString: "")

    private var encodings: [TextEncodingOption] { TextEncodingOption.allCases }
    private var state: State

    init(state: State) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
        syncToState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        NSColor.separatorColor.withAlphaComponent(0.5).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 0.5).fill()
    }

    func update(state: State) {
        self.state = state
        syncToState()
    }

    private func configure() {
        leftLabel.stringValue = Localization.string("diff.footer.leftEncoding", default: "左边编码")
        leftSaveLabel.stringValue = Localization.string("diff.footer.leftSaveEncoding", default: "保存编码为")
        rightLabel.stringValue = Localization.string("diff.footer.rightEncoding", default: "右边编码")
        rightSaveLabel.stringValue = Localization.string("diff.footer.rightSaveEncoding", default: "保存编码为")
        hintLabel.stringValue = Localization.string("diff.footer.dragHint", default: "支持文件拖动…")

        for label in [leftLabel, leftSaveLabel, rightLabel, rightSaveLabel, hintLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
        }
        hintLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for popup in [leftPopup, leftSavePopup, rightPopup, rightSavePopup] {
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.controlSize = .small
            popup.font = .systemFont(ofSize: 11)
            popup.target = self
            popup.action = #selector(popupChanged(_:))
            popup.addItems(withTitles: encodings.map(\.displayName))
        }

        let row = NSStackView(views: [
            leftLabel, leftPopup,
            leftSaveLabel, leftSavePopup,
            NSView(),
            rightLabel, rightPopup,
            rightSaveLabel, rightSavePopup,
            NSView(),
            hintLabel,
        ])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            leftPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            leftSavePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            rightPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            rightSavePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
        ])
    }

    @objc private func popupChanged(_ sender: NSPopUpButton) {
        func encoding(at index: Int) -> String.Encoding {
            encodings.indices.contains(index) ? encodings[index].encoding : .utf8
        }

        state.leftEncoding = encoding(at: leftPopup.indexOfSelectedItem)
        state.leftSaveEncoding = encoding(at: leftSavePopup.indexOfSelectedItem)
        state.rightEncoding = encoding(at: rightPopup.indexOfSelectedItem)
        state.rightSaveEncoding = encoding(at: rightSavePopup.indexOfSelectedItem)
        onChange?(state)
    }

    private func syncToState() {
        func index(for encoding: String.Encoding) -> Int {
            encodings.firstIndex(where: { $0.encoding == encoding }) ?? 0
        }
        leftPopup.selectItem(at: index(for: state.leftEncoding))
        leftSavePopup.selectItem(at: index(for: state.leftSaveEncoding))
        rightPopup.selectItem(at: index(for: state.rightEncoding))
        rightSavePopup.selectItem(at: index(for: state.rightSaveEncoding))
    }
}

