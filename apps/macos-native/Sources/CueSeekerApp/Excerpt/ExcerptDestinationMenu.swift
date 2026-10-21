import SwiftUI

/// The destination list menu: every Excerpt list, then a divider and `New List`.
///
/// One surface draws it for all three callers — the table row menu's
/// `Save to Excerpt ...`, `Move to ...` and `Duplicate to ...` submenus, and the
/// playback footer's `Save to Excerpt` button. Which lists appear, and in which
/// order, stays with the caller: `Move to ...` leaves out the list the row is
/// already in, `Save to Excerpt` leaves out nothing.
struct ExcerptDestinationMenu: View {
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
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: maximumHeight,
            highlight: highlight
        ) {
            VStack(spacing: 0) {
                ForEach(
                    Array(destinations.enumerated()),
                    id: \.element.id
                ) { position, destination in
                    WorkbenchPopoverRow(
                        title: destination.title,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        action: {
                            onSelect(destination)
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
                if !destinations.isEmpty {
                    WorkbenchMenuDivider()
                }
                WorkbenchPopoverRow(
                    title: L("excerpt.new_list"),
                    isHighlighted: highlight.isSelected(destinations.count),
                    isRowHovered: highlight.isHovered(destinations.count),
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    action: onCreateList,
                    onHoverChange: { isHovered in
                        highlight.noteHover(isHovered, at: destinations.count)
                    }
                )
                .id(destinations.count)
            }
        }
    }
}

extension ExcerptStore {
    /// Every list, in creation order, as a `Save to Excerpt` destination. Saving
    /// has no current list to leave out, and the list saved to most recently
    /// carries the flag the menu opens its highlight on.
    /// What the destination menu calls this list. Empty when the overview does
    /// not have it, which is the same state that leaves the menu without it.
    func listName(id: Int64) -> String {
        listOverview.lists.first { $0.id == id }?.list.name ?? ""
    }

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
