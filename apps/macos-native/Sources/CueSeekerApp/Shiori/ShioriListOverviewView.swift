import SwiftUI
import CueSeekerCore

struct ShioriListOverviewView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @State private var pendingDeletion: ShioriListSummary?
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: false
    )

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
        .cardHighlightFreeze(highlight)
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
                    highlight: highlight,
                    isCurrent: highlight.currentID == String(summary.id),
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
    let highlight: CardHighlightModel
    let isCurrent: Bool
    let canDelete: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void

    private var cardID: String {
        String(summary.id)
    }

    var body: some View {
        Button {
            highlight.notePress(id: cardID)
            onOpen()
        } label: {
            LibraryOverviewCardContent(
                title: summary.list.name,
                description: summary.list.description
            ) {
                cover
            }
        }
        .buttonStyle(
            LibraryOverviewCardButtonStyle(
                isCurrent: isCurrent,
                isFrozen: layerContext.isFrozen
            )
        )
        .onHover { highlight.noteHover($0, id: cardID) }
        .libraryCardContextMenuTrigger(
            isEnabled: true,
            ownerID: cardID,
            items: contextMenuItems,
            openContextMenu: { items, point, ownerID in
                highlight.notePress(id: cardID)
                openContextMenu(items, point, ownerID)
            }
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
            isCurrent ? WorkbenchControlMetrics.redesignLibraryCoverHoverScale : 1
        )
        .animation(
            .easeOut(duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration),
            value: isCurrent
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
