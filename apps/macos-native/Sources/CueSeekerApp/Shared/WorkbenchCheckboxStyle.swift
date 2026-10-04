import AppKit
import SwiftUI

enum WorkbenchCheckboxState: Equatable {
    case unchecked
    case checked
    case indeterminate
}

enum WorkbenchCheckboxStyle {
    static func icon(for state: WorkbenchCheckboxState) -> AppIcon {
        switch state {
        case .unchecked:
            return .circle
        case .checked:
            return .checkCircle
        case .indeterminate:
            return .minusCircle
        }
    }

    /// A ticked box reads as a solid mark, so both marked states draw the
    /// filled cut; the empty box draws the ordinary stroke master.
    static func iconWeight(for state: WorkbenchCheckboxState) -> AppIconWeight {
        switch state {
        case .unchecked:
            return .regular
        case .checked, .indeterminate:
            return .fill
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
        AppIconStore.tintedImage(
            icon(for: state),
            size: size,
            color: controlColor(for: state, isEnabled: isEnabled),
            weight: iconWeight(for: state)
        )
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
        let drawRect = appKitDrawingRect(
            imageSize: CGSize(width: size, height: size),
            centeredIn: controlRect
        )
        if state != .unchecked && isEnabled {
            let innerSize = size * 0.70
            let innerRect = CGRect(
                x: drawRect.midX - innerSize / 2,
                y: drawRect.midY - innerSize / 2,
                width: innerSize,
                height: innerSize
            )
            NSColor.white.setFill()
            NSBezierPath(ovalIn: innerRect).fill()
        }
        guard let image = appKitImage(
            for: state,
            isEnabled: isEnabled,
            size: size
        ) else { return }
        image.draw(in: drawRect)
    }
}

struct WorkbenchCheckboxGlyph: View {
    let state: WorkbenchCheckboxState
    let isEnabled: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            if state != .unchecked && isEnabled {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.70, height: size * 0.70)
            }
            AppIconImage(
                WorkbenchCheckboxStyle.icon(for: state),
                size: size,
                weight: WorkbenchCheckboxStyle.iconWeight(for: state)
            )
            .foregroundStyle(Color(nsColor: WorkbenchCheckboxStyle.controlColor(
                for: state,
                isEnabled: isEnabled
            )))
        }
        .frame(width: size, height: size)
    }
}
