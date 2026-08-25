import SwiftUI
import CueSeekerCore

struct ShioriListOverviewView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @State private var pendingDeletion: ShioriListSummary?

    var body: some View {
        LibraryCardContextMenuHost { openContextMenu in
            LibraryOverviewLayout(
                title: L("sidebar.shiori"),
                summaryText: L(
                    "shiori.overview.summary",
                    shioriStore.listOverview.lists.count,
                    shioriStore.listOverview.uniqueCueCount
                ),
                actionTitle: L("shiori.new_list"),
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
                    title: L("shiori.delete_list"),
                    message: L("shiori.delete_list.message", pendingDeletion.list.name),
                    destructiveTitle: L("shiori.delete"),
                    cancelTitle: L("common.cancel"),
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
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
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
    /// Answers for the layer this card is actually on: the workbench page, or
    /// the Command Panel or Playback Overlay that reuses the same grid. While
    /// frozen the card keeps the picture it had and stops following the
    /// pointer.
    @Environment(\.interfaceLayerContext) private var layerContext
    let summary: ShioriListSummary
    let canDelete: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    @State private var isHovered = false
    @Environment(\.libraryCardContextMenuOwner) private var contextMenuOwnerID

    private var contextMenuOwnerIdentity: String {
        String(summary.id)
    }

    private var isHoverActive: Bool {
        if let contextMenuOwnerID {
            return contextMenuOwnerID == contextMenuOwnerIdentity
        }
        return isHovered
    }

    var body: some View {
        Button(action: onOpen) {
            LibraryOverviewCardContent(
                title: summary.list.name,
                description: summary.list.description
            ) {
                cover
            }
            // A Button decides the pointer for its own area, so the hand
            // goes on the label rather than around the Button.
            .handPointer(isEnabled: !layerContext.isFrozen)
        }
        .buttonStyle(LibraryOverviewCardButtonStyle(isHovered: isHoverActive))
        .onHover { hovering in
            guard !layerContext.isFrozen else {
                return
            }
            isHovered = hovering
        }
        .libraryCardContextMenuTrigger(
            isEnabled: true,
            ownerID: contextMenuOwnerIdentity,
            items: contextMenuItems,
            openContextMenu: openContextMenu
        )
        .accessibilityLabel(summary.list.name)
    }

    private var cover: some View {
        LibraryCoverFrame {
            ZStack(alignment: .bottomTrailing) {
                ShioriListCoverView(coverPath: summary.list.coverPath)

                Text(L("shiori.cue_count", summary.cueCount))
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
                title: L("shiori.edit_list"),
                systemImage: "square.and.pencil",
                action: onEdit
            ),
            LibraryCardContextMenuItem(
                title: L("shiori.delete_list"),
                systemImage: "trash",
                isEnabled: canDelete,
                action: onDelete
            ),
        ]
    }
}
