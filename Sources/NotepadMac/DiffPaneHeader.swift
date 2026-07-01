import AppKit
import NotepadMacCore

/// Per-pane header row in the compare window: Open button, file title, encoding label.
@MainActor
final class DiffPaneHeader: NSView {

    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?

    private let openButton = NSButton()
    private let saveButton = NSButton()
    private let pathField = NSTextField(labelWithString: "")
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
        openButton.bezelStyle = .inline
        openButton.isBordered = false
        openButton.image = UpstreamToolbarBitmap.image(named: "openFile")
            ?? NSImage(systemSymbolName: "folder", accessibilityDescription: DiffStrings.paneOpen)
        openButton.imagePosition = .imageOnly
        openButton.title = ""
        openButton.target = self
        openButton.action = #selector(openClicked)
        openButton.setContentHuggingPriority(.required, for: .horizontal)

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.bezelStyle = .inline
        saveButton.isBordered = false
        saveButton.image = UpstreamToolbarBitmap.image(named: "saveFile")
            ?? NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: DiffStrings.paneSave)
        saveButton.imagePosition = .imageOnly
        saveButton.title = ""
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.setContentHuggingPriority(.required, for: .horizontal)

        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.font = .systemFont(ofSize: 11, weight: .medium)
        pathField.textColor = .labelColor
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.maximumNumberOfLines = 1
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        encodingPopup.translatesAutoresizingMaskIntoConstraints = false
        encodingPopup.isEnabled = false
        encodingPopup.addItem(withTitle: "UTF-8")
        encodingPopup.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(openButton)
        addSubview(saveButton)
        addSubview(pathField)
        addSubview(encodingPopup)

        NSLayoutConstraint.activate([
            openButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            openButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            pathField.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8),
            pathField.centerYAnchor.constraint(equalTo: centerYAnchor),
            pathField.trailingAnchor.constraint(lessThanOrEqualTo: saveButton.leadingAnchor, constant: -8),

            saveButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: encodingPopup.leadingAnchor, constant: -6),

            encodingPopup.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            encodingPopup.centerYAnchor.constraint(equalTo: centerYAnchor),
            encodingPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
        ])
    }

    func update(title: String, path: String?, encoding: String.Encoding, encodingLabel: String) {
        pathField.stringValue = path ?? title
        pathField.toolTip = path ?? title
        encodingPopup.removeAllItems()
        let display = TextEncodingOption(encoding: encoding)?.displayName ?? encoding.description
        encodingPopup.addItem(withTitle: display)
        encodingPopup.toolTip = encodingLabel
    }

    @objc private func openClicked() {
        onOpen?()
    }

    @objc private func saveClicked() {
        onSave?()
    }
}
