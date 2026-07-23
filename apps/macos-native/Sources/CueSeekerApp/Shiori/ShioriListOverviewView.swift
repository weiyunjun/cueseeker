import SwiftUI
import CueSeekerCore

struct ShioriListOverviewView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @State private var pendingDeletion: ShioriListSummary?

    var body: some View {
        LibraryCardContextMenuHost { openContextMenu in
            ScrollView {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    summaryRow

                    if shioriStore.hasLoadedListOverview {
                        listGrid(openContextMenu: openContextMenu)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)
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

    private var summaryRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            Text(
                "\(shioriStore.listOverview.lists.count) Lists · "
                    + "\(shioriStore.listOverview.uniqueCueCount) Cues"
            )
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)

            Spacer(minLength: 0)

            WorkbenchPlainActionButton(
                title: "New List",
                systemImage: "plus",
                isRedesign: true,
                action: appState.beginCreatingShioriList
            )
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private func listGrid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint) -> Void
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth,
                        maximum: WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
                    ),
                    spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap,
                    alignment: .top
                ),
            ],
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap
        ) {
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

struct ShioriListDetailHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchIconButton(
                systemImage: "chevron.left",
                isRedesign: true,
                action: onBack
            )

            Text("Shiori")
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .allowsHitTesting(false)
        }
    }
}

private struct ShioriListCard: View {
    let summary: ShioriListSummary
    let canDelete: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint) -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                cover

                Text(summary.list.name)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeLibraryTitle,
                        weight: .semibold
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 17, maxHeight: 17, alignment: .leading)

                Text(summary.list.description)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeLibraryMeta,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 15, maxHeight: 15, alignment: .leading)
            }
        }
        .buttonStyle(ShioriListCardButtonStyle(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .libraryCardContextMenuTrigger(
            isEnabled: true,
            isHovered: isHovered,
            items: contextMenuItems,
            openContextMenu: openContextMenu
        )
        .pointerOnHover(isEnabled: true)
        .accessibilityLabel(summary.list.name)
    }

    private var cover: some View {
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
        .aspectRatio(
            WorkbenchControlMetrics.redesignLibraryCoverAspectRatio,
            contentMode: .fit
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignLibraryCoverRadius,
                style: .continuous
            )
        )
        .scaleEffect(
            isHovered ? WorkbenchControlMetrics.redesignLibraryCoverHoverScale : 1
        )
        .animation(
            .easeOut(duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration),
            value: isHovered
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

private struct ShioriListCardButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding)
            .frame(
                maxWidth: WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius,
                    style: .continuous
                )
                .fill(
                    isHovered
                        ? WorkbenchRedesignColors.libraryMediaCardHoverBg
                        : Color.clear
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius,
                    style: .continuous
                )
            )
            .scaleEffect(
                configuration.isPressed
                    ? WorkbenchControlMetrics.redesignLibraryMediaCardPressedScale
                    : 1
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
