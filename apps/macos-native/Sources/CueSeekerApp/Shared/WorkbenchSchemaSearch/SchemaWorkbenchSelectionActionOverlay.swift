import AppKit
import SwiftUI

struct SchemaWorkbenchSelectionDestinationMenu {
    let destinations: [SubtitleTableRowActionDestination]
    let onSelect: (SubtitleTableRowActionDestination) -> Void
    let onCreateList: () -> Void
}

/// One action the Selection Action Overlay offers: what it says, the key that
/// does the same thing, and the work itself. Clicking a button runs exactly
/// what its key runs.
struct SchemaWorkbenchSelectionAction: Identifiable {
    enum Style: Equatable {
        case neutral
        case destructive
    }

    let id: String
    let title: String
    let icon: AppIcon
    /// What the keycap shows. Letters, never a symbol.
    let keyLabel: String
    let keyCode: UInt16
    let style: Style
    let destinationMenu: SchemaWorkbenchSelectionDestinationMenu?
    let perform: () -> Void

    init(
        id: String,
        title: String,
        icon: AppIcon,
        keyLabel: String,
        keyCode: UInt16,
        style: Style = .neutral,
        destinationMenu: SchemaWorkbenchSelectionDestinationMenu? = nil,
        perform: @escaping () -> Void = {}
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.keyLabel = keyLabel
        self.keyCode = keyCode
        self.style = style
        self.destinationMenu = destinationMenu
        self.perform = perform
    }

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
                id: SchemaWorkbenchSelectionActionID.exportToAnki.rawValue,
                title: L("table.toolbar.anki"),
                icon: .export,
                keyLabel: "A",
                keyCode: 0,
                perform: exportToAnki
            ),
            Self(
                id: SchemaWorkbenchSelectionActionID.copyDeepLinks.rawValue,
                title: L("table.toolbar.copy_deep_links"),
                icon: .linkSimple,
                keyLabel: "D",
                keyCode: 2,
                perform: copyDeepLinks
            ),
            Self(
                id: SchemaWorkbenchSelectionActionID.copyTable.rawValue,
                title: L("table.toolbar.copy_table"),
                icon: .copy,
                keyLabel: "T",
                keyCode: 17,
                perform: copyTable
            ),
        ]
    }

    /// Search table batch actions: Export to Anki (A), Copy Deep Links (D),
    /// Copy Table (T), and Save to Excerpt List (S).
    static func searchActions(
        exportToAnki: @escaping () -> Void,
        copyDeepLinks: @escaping () -> Void,
        copyTable: @escaping () -> Void,
        saveDestinations: [SubtitleTableRowActionDestination],
        saveToExcerptList: @escaping (SubtitleTableRowActionDestination) -> Void,
        createListForSave: @escaping () -> Void
    ) -> [Self] {
        exportActions(
            exportToAnki: exportToAnki,
            copyDeepLinks: copyDeepLinks,
            copyTable: copyTable
        ) + [
            Self(
                id: SchemaWorkbenchSelectionActionID.saveToExcerpt.rawValue,
                title: L("row_menu.save_to_excerpt"),
                icon: .arrowRight,
                keyLabel: "S",
                keyCode: 1,
                destinationMenu: SchemaWorkbenchSelectionDestinationMenu(
                    destinations: saveDestinations,
                    onSelect: saveToExcerptList,
                    onCreateList: createListForSave
                )
            ),
        ]
    }

    /// Excerpt table batch actions: Export to Anki (A), Copy Deep Links (D),
    /// Copy Table (T), Move to ... (M), Duplicate to ... (C), and Remove Excerpt (R).
    static func excerptActions(
        exportToAnki: @escaping () -> Void,
        copyDeepLinks: @escaping () -> Void,
        copyTable: @escaping () -> Void,
        destinations: [SubtitleTableRowActionDestination],
        moveToExcerptList: @escaping (SubtitleTableRowActionDestination) -> Void,
        createListForMove: @escaping () -> Void,
        duplicateToExcerptList: @escaping (SubtitleTableRowActionDestination) -> Void,
        createListForDuplicate: @escaping () -> Void,
        removeExcerpts: @escaping () -> Void
    ) -> [Self] {
        exportActions(
            exportToAnki: exportToAnki,
            copyDeepLinks: copyDeepLinks,
            copyTable: copyTable
        ) + [
            Self(
                id: SchemaWorkbenchSelectionActionID.moveTo.rawValue,
                title: L("row_menu.move_to"),
                icon: .arrowRight,
                keyLabel: "M",
                keyCode: 46,
                destinationMenu: SchemaWorkbenchSelectionDestinationMenu(
                    destinations: destinations,
                    onSelect: moveToExcerptList,
                    onCreateList: createListForMove
                )
            ),
            Self(
                id: SchemaWorkbenchSelectionActionID.duplicateTo.rawValue,
                title: L("row_menu.duplicate_to"),
                icon: .arrowRight,
                keyLabel: "C",
                keyCode: 8,
                destinationMenu: SchemaWorkbenchSelectionDestinationMenu(
                    destinations: destinations,
                    onSelect: duplicateToExcerptList,
                    onCreateList: createListForDuplicate
                )
            ),
            Self(
                id: SchemaWorkbenchSelectionActionID.removeExcerpt.rawValue,
                title: L("row_menu.remove_excerpt"),
                icon: .bookmarkSimple,
                keyLabel: "R",
                keyCode: 15,
                style: .destructive,
                perform: removeExcerpts
            ),
        ]
    }
}

/// Standard Neutral or Destructive button with a shortcut tooltip for a batch selection action.
struct SchemaWorkbenchSelectionActionButton: View {
    static var lastRenderedFocusedByID: [String: Bool] = [:]

    let action: SchemaWorkbenchSelectionAction
    var isOpen: Bool = false
    var isFocused: Bool = false
    var anchor: MenuAnchorHandle? = nil
    var onTrigger: (() -> Void)? = nil

    var body: some View {
        let _ = {
            Self.lastRenderedFocusedByID[action.id] = isFocused
        }()
        buttonContent
            .background {
                if let anchor {
                    MenuAnchorProbe(handle: anchor)
                }
            }
            .workbenchTooltip(
                scenarioID: "toolbar.selection.\(action.id)",
                isActive: !isOpen,
                label: action.title,
                shortcut: .fixed(action.keyLabel)
            )
            .accessibilityIdentifier("workbench-selection-action-\(action.id)")
    }

    @ViewBuilder
    private var buttonContent: some View {
        let trigger = onTrigger ?? action.perform
        switch action.style {
        case .neutral:
            WorkbenchButton(
                title: action.title,
                icon: action.icon,
                isOpen: isOpen,
                isFocused: isFocused,
                action: trigger
            )
        case .destructive:
            WorkbenchDestructiveButton(
                title: action.title,
                icon: action.icon,
                isFocused: isFocused,
                action: trigger
            )
        }
    }
}
