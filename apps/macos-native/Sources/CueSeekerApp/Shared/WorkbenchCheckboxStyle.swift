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
            return WorkbenchRedesignColors.NS.iconDisabled
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
        isEnabled: Bool
    ) -> NSImage? {
        let color = controlColor(for: state, isEnabled: isEnabled)
        let configuration = NSImage.SymbolConfiguration(
            hierarchicalColor: color
        ).applying(.preferringMonochrome())
        return NSImage(
            systemSymbolName: systemImageName(for: state),
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration)
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
