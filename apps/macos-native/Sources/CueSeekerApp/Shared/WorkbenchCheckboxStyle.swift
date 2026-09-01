import AppKit
import SwiftUI

enum WorkbenchCheckboxState: Equatable {
    case unchecked
    case checked
    case indeterminate
}

enum WorkbenchCheckboxStyle {
    static func systemImageName(for state: WorkbenchCheckboxState) -> String {
        switch state {
        case .unchecked:
            return "circle"
        case .checked:
            return "checkmark.circle.fill"
        case .indeterminate:
            return "minus.circle.fill"
        }
    }

    static func controlColor(
        for state: WorkbenchCheckboxState,
        isEnabled: Bool
    ) -> NSColor {
        guard isEnabled else {
            return WorkbenchRedesignColors.NS.textDisabled
        }
        switch state {
        case .unchecked:
            return WorkbenchRedesignColors.NS.borderCheckbox
        case .checked, .indeterminate:
            return WorkbenchRedesignColors.NS.bgCheckboxChecked
        }
    }

    @MainActor
    static func appKitImage(
        for state: WorkbenchCheckboxState,
        isEnabled: Bool,
        size: CGFloat
    ) -> NSImage? {
        let color = controlColor(for: state, isEnabled: isEnabled)
        let configuration = NSImage.SymbolConfiguration(
            pointSize: size,
            weight: .regular
        )
        .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        .applying(.preferringMonochrome())
        return NSImage(
            systemSymbolName: systemImageName(for: state),
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration)
    }

    static func appKitDrawingRect(
        imageSize: CGSize,
        centeredIn controlRect: CGRect
    ) -> CGRect {
        CGRect(
            x: controlRect.midX - imageSize.width / 2,
            y: controlRect.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
    }

    @MainActor
    static func drawAppKitGlyph(
        for state: WorkbenchCheckboxState,
        isEnabled: Bool,
        size: CGFloat,
        in controlRect: CGRect
    ) {
        guard let image = appKitImage(
            for: state,
            isEnabled: isEnabled,
            size: size
        ) else { return }
        image.draw(in: appKitDrawingRect(
            imageSize: image.size,
            centeredIn: controlRect
        ))
    }
}

struct WorkbenchCheckboxGlyph: View {
    let state: WorkbenchCheckboxState
    let isEnabled: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: WorkbenchCheckboxStyle.systemImageName(for: state))
            .font(.system(size: size))
            .foregroundStyle(Color(nsColor: WorkbenchCheckboxStyle.controlColor(
                for: state,
                isEnabled: isEnabled
            )))
            .frame(width: size, height: size)
    }
}
