import CoreGraphics
import CueSeekerCore
import SwiftUI

/// The one Shiori list card grid. The Shiori page, both Recent interfaces and
/// the Command Panel show the same card with the same menu, so they all come
/// through here instead of each building their own.
struct ShioriListCardGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    /// Set when the page already hosts the menu at its own root. The grid then
    /// uses that host, so the menu covers the whole page instead of only the
    /// grid it was opened from.
    @Environment(\.libraryCardContextMenuOpen) private var pageContextMenuOpen
    let summaries: [ShioriListSummary]
    @ObservedObject var highlight: CardHighlightModel
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (ShioriListSummary) -> Void

    var body: some View {
        if let pageContextMenuOpen {
            grid(openContextMenu: pageContextMenuOpen)
        } else {
            LibraryCardContextMenuHost { grid(openContextMenu: $0) }
        }
    }

    private func grid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        LibraryOverviewGrid {
            ForEach(summaries) { summary in
                ShioriListCard(
                    summary: summary,
                    highlight: highlight,
                    isCurrent: highlight.currentID == String(summary.id),
                    canDelete: shioriStore.listOverview.lists.count > 1,
                    onOpen: { onOpen(summary) },
                    onEdit: { appState.beginEditingShioriList(summary.list) },
                    onDelete: { requestDeletion(of: summary) },
                    openContextMenu: openContextMenu
                )
                .background {
                    if let itemFrameCoordinateSpace {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: LibraryItemFramePreferenceKey.self,
                                value: [
                                    String(summary.id): proxy.frame(
                                        in: .named(itemFrameCoordinateSpace)
                                    )
                                ]
                            )
                        }
                    }
                }
                .id(String(summary.id))
            }
        }
        .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
            guard itemFrameCoordinateSpace != nil else {
                return
            }
            onItemFramesChange(frames)
        }
    }

    private func requestDeletion(of summary: ShioriListSummary) {
        appState.confirmation.session = WorkbenchConfirmationSession(
            title: L("shiori.delete_list"),
            message: L("shiori.delete_list.message", summary.list.name),
            destructiveTitle: L("shiori.delete"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                if appState.deleteShioriList(id: summary.id) {
                    appState.confirmation.session = nil
                }
            },
            onCancel: {
                appState.confirmation.session = nil
            }
        )
    }
}

private struct ShioriListCard: View {
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
            LibraryOverviewCardButtonStyle(isCurrent: isCurrent)
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
                icon: .notePencil,
                action: onEdit
            ),
            LibraryCardContextMenuItem(
                title: L("shiori.delete_list"),
                icon: .trash,
                isEnabled: canDelete,
                action: onDelete
            ),
        ]
    }
}
