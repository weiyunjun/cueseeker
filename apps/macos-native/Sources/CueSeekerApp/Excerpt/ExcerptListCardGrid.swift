import CoreGraphics
import CueSeekerCore
import SwiftUI

/// The one Excerpt list card grid. The Excerpt page, both Recent interfaces and
/// the Command Panel show the same card with the same menu, so they all come
/// through here instead of each building their own.
struct ExcerptListCardGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var excerptStore: ExcerptStore
    /// Set when the page already hosts the menu at its own root. The grid then
    /// uses that host, so the menu covers the whole page instead of only the
    /// grid it was opened from.
    @Environment(\.libraryCardContextMenuOpen) private var pageContextMenuOpen
    let summaries: [ExcerptListSummary]
    @ObservedObject var highlight: CardHighlightModel
    var groupsByRecentSection: Bool = false
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (ExcerptListSummary) -> Void

    private var sections: [(section: RecentTimeSection, items: [ExcerptListSummary])] {
        RecentTimeSection.group(summaries, timestamp: \.list.recentPlayedAt)
    }

    var body: some View {
        if let pageContextMenuOpen {
            grid(openContextMenu: pageContextMenuOpen)
        } else {
            LibraryCardContextMenuHost { grid(openContextMenu: $0) }
        }
    }

    @ViewBuilder
    private func grid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        if groupsByRecentSection {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignSpacing3
            ) {
                ForEach(sections, id: \.section) { group in
                    VStack(
                        alignment: .leading,
                        spacing: WorkbenchControlMetrics.redesignSpacing3
                    ) {
                        RecentSectionTitleView(title: group.section.localizedTitle)
                        sectionGrid(
                            summaries: group.items,
                            openContextMenu: openContextMenu
                        )
                    }
                }
            }
            .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
                guard itemFrameCoordinateSpace != nil else {
                    return
                }
                onItemFramesChange(frames)
            }
        } else {
            sectionGrid(summaries: summaries, openContextMenu: openContextMenu)
                .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
                    guard itemFrameCoordinateSpace != nil else {
                        return
                    }
                    onItemFramesChange(frames)
                }
        }
    }

    private func sectionGrid(
        summaries: [ExcerptListSummary],
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        LibraryOverviewGrid {
            ForEach(summaries) { summary in
                ExcerptListCard(
                    summary: summary,
                    highlight: highlight,
                    isCurrent: highlight.currentID == String(summary.id),
                    canDelete: excerptStore.listOverview.lists.count > 1,
                    onOpen: { onOpen(summary) },
                    onEdit: { appState.beginEditingExcerptList(summary.list) },
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
    }

    private func requestDeletion(of summary: ExcerptListSummary) {
        appState.confirmation.session = WorkbenchConfirmationSession(
            title: L("excerpt.delete_list"),
            message: L("excerpt.delete_list.message", summary.list.name),
            destructiveTitle: L("excerpt.delete"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                if appState.deleteExcerptList(id: summary.id) {
                    appState.confirmation.session = nil
                }
            },
            onCancel: {
                appState.confirmation.session = nil
            }
        )
    }
}

private struct ExcerptListCard: View {
    let summary: ExcerptListSummary
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
        .focusable(false)
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
                ExcerptListCoverView(coverPath: summary.list.coverPath)

                Text(summary.cueCount == 1 ? L("excerpt.cue_count.one") : L("excerpt.cue_count.other", summary.cueCount))
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
                title: L("excerpt.edit_list"),
                icon: .notePencil,
                action: onEdit
            ),
            LibraryCardContextMenuItem(
                title: L("excerpt.delete_list"),
                icon: .trash,
                isEnabled: canDelete,
                action: onDelete
            ),
        ]
    }
}
