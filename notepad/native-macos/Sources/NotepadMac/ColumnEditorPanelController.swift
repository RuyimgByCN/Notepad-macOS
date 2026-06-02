import AppKit
import NotepadMacCore

enum ColumnEditorOperation {
    case text(String)
    case number(ColumnNumberOptions)
}

@MainActor
final class ColumnEditorPanelController: NSObject {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 308),
        styleMask: [.titled, .closable, .utilityWindow],
        backing: .buffered,
        defer: false
    )
    private let rangeField = NSTextField(labelWithString: "")
    private let textModeButton = NSButton(
        radioButtonWithTitle: Localization.string(.columnEditorModeText, default: "Text to Insert"),
        target: nil,
        action: nil
    )
    private let numberModeButton = NSButton(
        radioButtonWithTitle: Localization.string(.columnEditorModeNumber, default: "Number to Insert"),
        target: nil,
        action: nil
    )
    private let textField = NSTextField(string: "")
    private let columnField = NSTextField(string: "")
    private let columnStepper = NSStepper()
    private let initialField = NSTextField(string: "1")
    private let incrementField = NSTextField(string: "1")
    private let repeatField = NSTextField(string: "1")
    private let formatPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let paddingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let widthField = NSTextField(string: "1")
    private var onApply: ((ColumnEditorOperation, Int) -> Void)?

    override init() {
        super.init()
        panel.title = Localization.string(.columnEditorPanelTitle, default: "Column Editor")
        panel.isReleasedWhenClosed = false
        configureContent()
        updateModeControls()
    }

    func show(lineRange: ClosedRange<Int>, column: Int, onApply: @escaping (ColumnEditorOperation, Int) -> Void) {
        self.onApply = onApply
        rangeField.stringValue = lineRange.lowerBound == lineRange.upperBound
            ? localizedString(.columnEditorRangeSingleLine, default: "Line %d", lineRange.lowerBound)
            : localizedString(
                .columnEditorRangeMultipleLines,
                default: "Lines %d-%d",
                lineRange.lowerBound,
                lineRange.upperBound
            )
        columnField.integerValue = max(1, column)
        columnStepper.integerValue = columnField.integerValue
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textModeButton.state == .on ? textField : initialField)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root
        rangeField.setAccessibilityLabel(
            Localization.string(.columnEditorRangeAccessibilityLabel, default: "Selected line range")
        )

        let textLabel = NSTextField(labelWithString: Localization.string(.columnEditorTextLabel, default: "Text"))
        let columnLabel = NSTextField(labelWithString: Localization.string(.columnEditorColumnLabel, default: "Column"))
        let initialLabel = NSTextField(labelWithString: Localization.string(.columnEditorInitialLabel, default: "Initial"))
        let incrementLabel = NSTextField(labelWithString: Localization.string(.columnEditorIncrementLabel, default: "Increase by"))
        let repeatLabel = NSTextField(labelWithString: Localization.string(.columnEditorRepeatLabel, default: "Repeat"))
        let formatLabel = NSTextField(labelWithString: Localization.string(.columnEditorFormatLabel, default: "Format"))
        let paddingLabel = NSTextField(labelWithString: Localization.string(.columnEditorPaddingLabel, default: "Leading"))
        let widthLabel = NSTextField(labelWithString: Localization.string(.columnEditorWidthLabel, default: "Width"))
        let applyButton = NSButton(
            title: Localization.string(.columnEditorApplyInsert, default: "Insert"),
            target: self,
            action: #selector(apply(_:))
        )

        textModeButton.target = self
        textModeButton.action = #selector(modeChanged(_:))
        textModeButton.state = .on
        textModeButton.setAccessibilityLabel(
            Localization.string(.columnEditorTextModeAccessibilityLabel, default: "Text insertion mode")
        )
        numberModeButton.target = self
        numberModeButton.action = #selector(modeChanged(_:))
        numberModeButton.setAccessibilityLabel(
            Localization.string(.columnEditorNumberModeAccessibilityLabel, default: "Number insertion mode")
        )

        textField.placeholderString = Localization.string(.columnEditorPlaceholderText, default: "Text")
        textField.setAccessibilityLabel(
            Localization.string(.columnEditorTextFieldAccessibilityLabel, default: "Text to insert")
        )
        [columnField, initialField, incrementField, repeatField, widthField].forEach {
            $0.formatter = integerFormatter
        }
        columnField.setAccessibilityLabel(
            Localization.string(.columnEditorColumnFieldAccessibilityLabel, default: "Insertion column")
        )
        initialField.setAccessibilityLabel(
            Localization.string(.columnEditorInitialFieldAccessibilityLabel, default: "Initial number")
        )
        incrementField.setAccessibilityLabel(
            Localization.string(.columnEditorIncrementFieldAccessibilityLabel, default: "Number increment")
        )
        repeatField.setAccessibilityLabel(
            Localization.string(.columnEditorRepeatFieldAccessibilityLabel, default: "Repeat count")
        )
        widthField.setAccessibilityLabel(
            Localization.string(.columnEditorWidthFieldAccessibilityLabel, default: "Padding width")
        )
        columnStepper.minValue = 1
        columnStepper.maxValue = 9999
        columnStepper.increment = 1
        columnStepper.target = self
        columnStepper.action = #selector(stepperChanged(_:))
        columnStepper.setAccessibilityLabel(
            Localization.string(.columnEditorColumnStepperAccessibilityLabel, default: "Insertion column stepper")
        )

        formatPopup.addItems(withTitles: [
            Localization.string(.columnEditorFormatDecimal, default: "Dec"),
            Localization.string(.columnEditorFormatHex, default: "Hex"),
            Localization.string(.columnEditorFormatHexUpper, default: "HEX"),
            Localization.string(.columnEditorFormatOctal, default: "Oct"),
            Localization.string(.columnEditorFormatBinary, default: "Bin")
        ])
        paddingPopup.addItems(withTitles: [
            Localization.string(.columnEditorPaddingNone, default: "None"),
            Localization.string(.columnEditorPaddingZeros, default: "Zeros"),
            Localization.string(.columnEditorPaddingSpaces, default: "Spaces")
        ])
        formatPopup.setAccessibilityLabel(
            Localization.string(.columnEditorFormatAccessibilityLabel, default: "Number format")
        )
        paddingPopup.setAccessibilityLabel(
            Localization.string(.columnEditorPaddingAccessibilityLabel, default: "Leading padding")
        )
        applyButton.bezelStyle = .rounded
        applyButton.setAccessibilityLabel(
            Localization.string(.columnEditorApplyAccessibilityLabel, default: "Apply column edit")
        )

        let views: [NSView] = [
            rangeField,
            textModeButton,
            numberModeButton,
            textLabel,
            textField,
            columnLabel,
            columnField,
            columnStepper,
            initialLabel,
            initialField,
            incrementLabel,
            incrementField,
            repeatLabel,
            repeatField,
            formatLabel,
            formatPopup,
            paddingLabel,
            paddingPopup,
            widthLabel,
            widthField,
            applyButton
        ]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0)
        }

        NSLayoutConstraint.activate([
            rangeField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            rangeField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            rangeField.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),

            textModeButton.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            textModeButton.topAnchor.constraint(equalTo: rangeField.bottomAnchor, constant: 18),

            textLabel.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor, constant: 18),
            textLabel.topAnchor.constraint(equalTo: textModeButton.bottomAnchor, constant: 10),
            textLabel.widthAnchor.constraint(equalToConstant: 82),

            textField.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            textField.centerYAnchor.constraint(equalTo: textLabel.centerYAnchor),

            numberModeButton.leadingAnchor.constraint(equalTo: rangeField.leadingAnchor),
            numberModeButton.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 18),

            initialLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
            initialLabel.topAnchor.constraint(equalTo: numberModeButton.bottomAnchor, constant: 10),
            initialLabel.widthAnchor.constraint(equalTo: textLabel.widthAnchor),

            initialField.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            initialField.centerYAnchor.constraint(equalTo: initialLabel.centerYAnchor),
            initialField.widthAnchor.constraint(equalToConstant: 74),

            incrementLabel.leadingAnchor.constraint(equalTo: initialField.trailingAnchor, constant: 18),
            incrementLabel.centerYAnchor.constraint(equalTo: initialLabel.centerYAnchor),

            incrementField.leadingAnchor.constraint(equalTo: incrementLabel.trailingAnchor, constant: 10),
            incrementField.centerYAnchor.constraint(equalTo: initialLabel.centerYAnchor),
            incrementField.widthAnchor.constraint(equalToConstant: 74),

            repeatLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
            repeatLabel.topAnchor.constraint(equalTo: initialLabel.bottomAnchor, constant: 14),
            repeatLabel.widthAnchor.constraint(equalTo: textLabel.widthAnchor),

            repeatField.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            repeatField.centerYAnchor.constraint(equalTo: repeatLabel.centerYAnchor),
            repeatField.widthAnchor.constraint(equalToConstant: 74),

            formatLabel.leadingAnchor.constraint(equalTo: repeatField.trailingAnchor, constant: 18),
            formatLabel.centerYAnchor.constraint(equalTo: repeatLabel.centerYAnchor),

            formatPopup.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 10),
            formatPopup.centerYAnchor.constraint(equalTo: repeatLabel.centerYAnchor),
            formatPopup.widthAnchor.constraint(equalToConstant: 92),

            paddingLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
            paddingLabel.topAnchor.constraint(equalTo: repeatLabel.bottomAnchor, constant: 14),
            paddingLabel.widthAnchor.constraint(equalTo: textLabel.widthAnchor),

            paddingPopup.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            paddingPopup.centerYAnchor.constraint(equalTo: paddingLabel.centerYAnchor),
            paddingPopup.widthAnchor.constraint(equalToConstant: 100),

            widthLabel.leadingAnchor.constraint(equalTo: paddingPopup.trailingAnchor, constant: 18),
            widthLabel.centerYAnchor.constraint(equalTo: paddingLabel.centerYAnchor),

            widthField.leadingAnchor.constraint(equalTo: widthLabel.trailingAnchor, constant: 10),
            widthField.centerYAnchor.constraint(equalTo: paddingLabel.centerYAnchor),
            widthField.widthAnchor.constraint(equalToConstant: 74),

            columnLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor),
            columnLabel.topAnchor.constraint(equalTo: paddingLabel.bottomAnchor, constant: 18),
            columnLabel.widthAnchor.constraint(equalTo: textLabel.widthAnchor),

            columnField.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            columnField.centerYAnchor.constraint(equalTo: columnLabel.centerYAnchor),
            columnField.widthAnchor.constraint(equalToConstant: 74),

            columnStepper.leadingAnchor.constraint(equalTo: columnField.trailingAnchor, constant: 8),
            columnStepper.centerYAnchor.constraint(equalTo: columnLabel.centerYAnchor),

            applyButton.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
            applyButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16)
        ])
    }

    @objc private func modeChanged(_ sender: Any?) {
        if sender as? NSButton === textModeButton {
            textModeButton.state = .on
            numberModeButton.state = .off
        } else {
            textModeButton.state = .off
            numberModeButton.state = .on
        }
        updateModeControls()
    }

    @objc private func stepperChanged(_ sender: Any?) {
        columnField.integerValue = max(1, columnStepper.integerValue)
    }

    @objc private func apply(_ sender: Any?) {
        if columnField.integerValue != columnStepper.integerValue {
            columnStepper.integerValue = max(1, columnField.integerValue)
        }

        if textModeButton.state == .on {
            onApply?(.text(textField.stringValue), max(1, columnField.integerValue))
        } else {
            onApply?(.number(numberOptions()), max(1, columnField.integerValue))
        }
    }

    private func updateModeControls() {
        let isTextMode = textModeButton.state == .on
        textField.isEnabled = isTextMode
        [initialField, incrementField, repeatField, formatPopup, paddingPopup, widthField].forEach {
            $0.isEnabled = !isTextMode
        }
    }

    private func numberOptions() -> ColumnNumberOptions {
        ColumnNumberOptions(
            initial: initialField.integerValue,
            increment: incrementField.integerValue,
            repeatCount: max(1, repeatField.integerValue),
            format: selectedFormat,
            padding: selectedPadding
        )
    }

    private var selectedFormat: ColumnNumberFormat {
        switch formatPopup.indexOfSelectedItem {
        case 1:
            .hexadecimal(uppercase: false)
        case 2:
            .hexadecimal(uppercase: true)
        case 3:
            .octal
        case 4:
            .binary
        default:
            .decimal
        }
    }

    private var selectedPadding: ColumnNumberPadding {
        switch paddingPopup.indexOfSelectedItem {
        case 1:
            .zeros(width: max(1, widthField.integerValue))
        case 2:
            .spaces(width: max(1, widthField.integerValue))
        default:
            .none
        }
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }

    private func localizedString(_ key: Localization.Key, default defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: Localization.string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
