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

/// Standard Neutral button with a shortcut tooltip for a batch selection action.
struct SchemaWorkbenchSelectionActionButton: View {
    let action: SchemaWorkbenchSelectionAction

    var body: some View {
        WorkbenchButton(
            title: action.title,
            isRedesign: true,
            action: action.perform
        )
        .workbenchTooltip(
            scenarioID: "toolbar.selection.\(action.id)",
            label: action.title,
            shortcut: .fixed(action.keyLabel)
        )
        .accessibilityIdentifier("workbench-selection-action-\(action.id)")
    }
}
