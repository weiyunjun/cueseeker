import SwiftUI
import CueSeekerCore

struct ShioriListOverviewView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @State private var pendingDeletion: ShioriListSummary?

    var body: some View {
        LibraryCardContextMenuHost { openContextMenu in
            LibraryOverviewLayout(
                title: "Shiori",
                summaryText: "\(shioriStore.listOverview.lists.count) Lists · "
                    + "\(shioriStore.listOverview.uniqueCueCount) Cues",
                actionTitle: "New List",
                actionSystemImage: "plus",
                action: appState.beginCreatingShioriList
            ) {
                if shioriStore.hasLoadedListOverview {
                    listGrid(openContextMenu: openContextMenu)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .task {
            appState.loadShioriListOverviewIfNeeded()
        }
        .overlay {
            if let pendingDeletion {
                WorkbenchConfirmationDialog(
                    title: "Delete List",
                    message: "The list “\(pendingDeletion.list.name)” and its Shiori entries will be deleted. The original subtitle and video files will not be deleted.",
                    destructiveTitle: "Delete",
                    cancelTitle: "Cancel",
                    onDestructive: {
                        if appState.deleteShioriList(id: pendingDeletion.id) {
                            self.pendingDeletion = nil
                        }
                    },
                    onCancel: {
                        self.pendingDeletion = nil
                    }
                )
                .zIndex(20)
            }
        }
    }

    private func listGrid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint) -> Void
    ) -> some View {
        LibraryOverviewGrid {
            ForEach(shioriStore.listOverview.lists) { summary in
                ShioriListCard(
                    summary: summary,
                    canDelete: shioriStore.listOverview.lists.count > 1,
                    onOpen: {
                        appState.openShioriList(id: summary.id)
                    },
                    onEdit: {
                        appState.beginEditingShioriList(summary.list)
                    },
                    onDelete: {
                        pendingDeletion = summary
                    },
                    openContextMenu: openContextMenu
                )
            }
        }
    }
}

private struct ShioriListCard: View {
    @Environment(\.isWorkbenchPopupLayerOpen) private var isWorkbenchPopupLayerOpen
    let summary: ShioriListSummary
    let canDelete: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint) -> Void
    @State private var isHovered = false

    private var isHoverActive: Bool {
        isHovered && !isWorkbenchPopupLayerOpen
    }

    var body: some View {
        Button(action: onOpen) {
            LibraryOverviewCardContent(
                title: summary.list.name,
                description: summary.list.description
            ) {
                cover
            }
        }
        .buttonStyle(LibraryOverviewCardButtonStyle(isHovered: isHoverActive))
        .onHover { isHovered = $0 }
        .onChange(of: isWorkbenchPopupLayerOpen) { isOpen in
            if isOpen {
                isHovered = false
            }
        }
        .libraryCardContextMenuTrigger(
            isEnabled: true,
            isHovered: isHoverActive,
            items: contextMenuItems,
            openContextMenu: openContextMenu
        )
        .pointerOnHover(isEnabled: !isWorkbenchPopupLayerOpen)
        .accessibilityLabel(summary.list.name)
    }

    private var cover: some View {
        LibraryCoverFrame {
            ZStack(alignment: .bottomTrailing) {
                ShioriListCoverView(coverPath: summary.list.coverPath)

                Text("\(summary.cueCount) Cues")
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeLibraryTimeBadge,
                        weight: .semibold
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.libraryTimeBadgeText)
                    .monospacedDigit()
                    .padding(
                        .horizontal,
                        WorkbenchControlMetrics.redesignLibraryTimeBadgeHorizontalPadding
                    )
                    .padding(
                        .vertical,
                        WorkbenchControlMetrics.redesignLibraryTimeBadgeVerticalPadding
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius: WorkbenchControlMetrics.redesignLibraryTimeBadgeRadius,
                            style: .continuous
                        )
                        .fill(WorkbenchRedesignColors.libraryTimeBadgeBg)
                    )
                    .padding(8)
            }
        }
        .scaleEffect(
            isHoverActive ? WorkbenchControlMetrics.redesignLibraryCoverHoverScale : 1
        )
        .animation(
            .easeOut(duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration),
            value: isHoverActive
        )
    }

    private var contextMenuItems: [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(
                title: "Edit List",
                systemImage: "square.and.pencil",
                action: onEdit
            ),
            LibraryCardContextMenuItem(
                title: "Delete List",
                systemImage: "trash",
                isEnabled: canDelete,
                action: onDelete
            ),
        ]
    }
}
