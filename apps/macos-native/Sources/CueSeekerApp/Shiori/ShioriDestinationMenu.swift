import SwiftUI

/// The destination list menu: every Shiori list, then a divider and `New List`.
///
/// One surface draws it for all three callers — the table row menu's
/// `Save to Shiori ...`, `Move to ...` and `Duplicate to ...` submenus, and the
/// playback footer's `Save to Shiori` button. Which lists appear, and in which
/// order, stays with the caller: `Move to ...` leaves out the list the row is
/// already in, `Save to Shiori` leaves out nothing.
struct ShioriDestinationMenu: View {
    let destinations: [SubtitleTableRowActionDestination]
    @ObservedObject var highlight: MenuHighlightModel
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    let onSelect: (SubtitleTableRowActionDestination) -> Void
    let onCreateList: () -> Void

    /// `New List` sits after the lists, so it takes the position one past them.
    static func selectablePositions(
        destinationCount: Int
    ) -> [Int] {
        Array(0...destinationCount)
    }

    /// The list saved to most recently takes the highlight when the menu opens.
    /// Absent — never saved, or that list is gone — the menu falls back to its
    /// first item the way every other menu does.
    static func defaultPosition(
        destinations: [SubtitleTableRowActionDestination]
    ) -> Int? {
        destinations.firstIndex(where: \.isRecentSaveTarget)
    }

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true, maximumHeight: maximumHeight) {
            VStack(spacing: 0) {
                ForEach(
                    Array(destinations.enumerated()),
                    id: \.element.id
                ) { position, destination in
                    WorkbenchPopoverRow(
                        title: destination.title,
                        isHighlighted: highlight.highlightedPosition == position,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        action: {
                            onSelect(destination)
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                }
                if !destinations.isEmpty {
                    WorkbenchMenuDivider()
                }
                WorkbenchPopoverRow(
                    title: L("shiori.new_list"),
                    isHighlighted: highlight.highlightedPosition
                        == destinations.count,
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    action: onCreateList,
                    onHoverChange: { isHovered in
                        highlight.noteHover(isHovered, at: destinations.count)
                    }
                )
            }
        }
    }
}

extension ShioriStore {
    /// Every list, in creation order, as a `Save to Shiori` destination. Saving
    /// has no current list to leave out, and the list saved to most recently
    /// carries the flag the menu opens its highlight on.
    var saveDestinations: [SubtitleTableRowActionDestination] {
        listOverview.lists.map { summary in
            SubtitleTableRowActionDestination(
                id: summary.id,
                title: summary.list.name,
                isRecentSaveTarget: summary.id == recentSaveListID
            )
        }
    }
}
