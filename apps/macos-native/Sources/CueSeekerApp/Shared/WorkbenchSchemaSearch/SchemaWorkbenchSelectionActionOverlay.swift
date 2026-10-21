import AppKit
import SwiftUI

/// One action the Selection Action Overlay offers: what it says, the key that
/// does the same thing, and the work itself. Clicking a button runs exactly
/// what its key runs.
struct SchemaWorkbenchSelectionAction: Identifiable {
    let id: String
    let title: String
    /// What the keycap shows. Letters, never a symbol.
    let keyLabel: String
    let keyCode: UInt16
    let perform: () -> Void

    /// The three export actions both workbench tables offer, in overlay order.
    /// Exit is not here: the overlay owns it, the same way it owns the count.
    static func exportActions(
        exportToAnki: @escaping () -> Void,
        copyDeepLinks: @escaping () -> Void,
        copyTable: @escaping () -> Void
    ) -> [Self] {
        [
            // A, D, T.
            Self(
                id: "anki",
                title: L("table.toolbar.anki"),
                keyLabel: "A",
                keyCode: 0,
                perform: exportToAnki
            ),
            Self(
                id: "copy-deep-links",
                title: L("table.toolbar.copy_deep_links"),
                keyLabel: "D",
                keyCode: 2,
                perform: copyDeepLinks
            ),
            Self(
                id: "copy-table",
                title: L("table.toolbar.copy_table"),
                keyLabel: "T",
                keyCode: 17,
                perform: copyTable
            ),
        ]
    }
}

/// Text plus the key that does the same thing.
struct SchemaWorkbenchSelectionActionButton: View {
    let action: SchemaWorkbenchSelectionAction

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action.perform) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text(action.title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                SchemaWorkbenchSelectionKeycap(
                    label: action.keyLabel,
                    background: isPressed
                        ? WorkbenchRedesignColors.popoverSurfaceKeycapPressedBg
                        : (isHovered
                            ? WorkbenchRedesignColors.popoverSurfaceKeycapHoverBg
                            : WorkbenchRedesignColors.popoverSurfaceKeycapBg)
                )
            }
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3)
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignChipRadius,
                    style: .continuous
                )
                .fill(
                    isPressed
                        ? WorkbenchRedesignColors.popoverSurfaceShortcutButtonPressedBg
                        : (isHovered
                            ? WorkbenchRedesignColors.popoverSurfaceShortcutButtonHoverBg
                            : Color.clear)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .focusable(false)
        .onPointerHover { isHovered = $0 }
        .accessibilityIdentifier("workbench-selection-action-\(action.id)")
    }
}

private struct SchemaWorkbenchSelectionKeycap: View {
    let label: String
    let background: Color

    var body: some View {
        Text(label)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: WorkbenchControlMetrics.redesignFontWeightControl
            ))
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignKeycapHorizontalPadding
            )
            .frame(minWidth: WorkbenchControlMetrics.redesignKeycapHeight)
            .frame(height: WorkbenchControlMetrics.redesignKeycapHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignKeycapRadius,
                    style: .continuous
                )
                .fill(background)
            }
            .allowsHitTesting(false)
    }
}
