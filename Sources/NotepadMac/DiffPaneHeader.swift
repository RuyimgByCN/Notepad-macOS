import AppKit
import NotepadMacCore

/// Per-pane header row in the compare window: Open button, file title, encoding label.
@MainActor
final class DiffPaneHeader: NSView {

    var onOpen: (() -> Void)?

    private let openButton = NSButton()
    private let titleField = NSTextField(labelWithString: "")
    private let encodingPopup = NSPopUpButton()

    static let headerHeight: CGFloat = 28

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.bezelStyle = .rounded
        openButton.title = DiffStrings.paneOpen
        openButton.target = self
        openButton.action = #selector(openClicked)
        openButton.setContentHuggingPriority(.required, for: .horizontal)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 11, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.maximumNumberOfLines = 1

        encodingPopup.translatesAutoresizingMaskIntoConstraints = false
        encodingPopup.isEnabled = false
        encodingPopup.addItem(withTitle: "UTF-8")
        encodingPopup.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(openButton)
        addSubview(titleField)
        addSubview(encodingPopup)

        NSLayoutConstraint.activate([
            openButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            openButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleField.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: encodingPopup.leadingAnchor, constant: -8),

            encodingPopup.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            encodingPopup.centerYAnchor.constraint(equalTo: centerYAnchor),
            encodingPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
        ])
    }

    func update(title: String, encoding: String.Encoding, encodingLabel: String) {
        titleField.stringValue = title
        encodingPopup.removeAllItems()
        let display = TextEncodingOption(encoding: encoding)?.displayName ?? encoding.description
        encodingPopup.addItem(withTitle: display)
        encodingPopup.toolTip = encodingLabel
    }

    @objc private func openClicked() {
        onOpen?()
    }
}
