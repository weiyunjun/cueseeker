import CueSeekerCore
import SwiftUI

struct WorkbenchRecentView: View {
    // Observed so the tab labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var routeState: WorkbenchRouteState
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var excerpt: ExcerptStore
    var presentedSection: WorkbenchRecentSection? = nil
    /// One highlight for the page: only one card may be lit at a time.
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: false
    )

    private var activeSection: WorkbenchRecentSection {
        presentedSection ?? routeState.selectedRecentSection
    }

    var body: some View {
        // The menu belongs to the page, not to one tab of it, so the page
        // hosts it.
        LibraryCardContextMenuHost(
            interfaceID: activeSection.rawValue
        ) { _ in
        GeometryReader { geometry in
            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchLibraryMetrics.sectionSpacing) {
                    let emptyMinHeight = max(
                        0,
                        geometry.size.height
                            - WorkbenchLibraryMetrics.pageTopPadding
                            - WorkbenchLibraryMetrics.pageBottomPadding
                    )
                    switch activeSection {
                    case .videos:
                        recentVideosContent(
                            status: library.testRecentWatchingStatus,
                            items: library.testRecentWatchingItems,
                            emptyMinHeight: emptyMinHeight
                        )
                    case .excerpts:
                        recentExcerptsContent(
                            excerpt.recentListSummaries,
                            emptyMinHeight: emptyMinHeight
                        )
                    }
                }
                .padding(.top, WorkbenchLibraryMetrics.pageTopPadding)
                .padding(.bottom, WorkbenchLibraryMetrics.pageBottomPadding)
                .environment(
                    \.mediaCardGridContainerWidth,
                    WorkbenchControlMetrics.workbenchMediaCardGridWidth(
                        viewportWidth: geometry.size.width
                    )
                )
                .frame(
                    width: geometry.size.width,
                    alignment: .topLeading
                )
                .frame(
                    minHeight: geometry.size.height,
                    alignment: .topLeading
                )
            }
        }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .cardHighlightFreeze(highlight)
        .onChange(of: activeSection) { _ in
            highlight.reset()
            appState.refreshExcerptOnReappearanceIfNeeded()
            appState.refreshRecentOnReappearanceIfNeeded()
        }
        .task {
            appState.hydrateTestRecentWatchingAsync()
            appState.loadExcerptListOverviewIfNeeded()
        }
        .onAppear {
            appState.refreshRecentOnReappearanceIfNeeded()
        }
        .onChange(of: appState.isPlaybackPageVisible) { isVisible in
            if !isVisible {
                appState.reloadExcerptListOverview()
                appState.refreshRecentOnReappearanceIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func recentVideosContent(
        status: LibraryStatus,
        items: [RecentLibraryWatchingPresentation],
        emptyMinHeight: CGFloat
    ) -> some View {
        if !items.isEmpty {
            RecentWatchingGrid(
                items: items,
                highlight: highlight,
                onOpen: { item in
                    Task {
                        await appState.openRecentLibraryWatching(item)
                    }
                }
            )
            .workbenchMediaCardGridInlinePadding()
        } else if case .failed(let message) = status {
            WorkbenchEmptyHint(icon: .videoQuestion, message: message)
                .frame(minHeight: emptyMinHeight)
                .workbenchPageInlinePadding()
        } else if status == .completed || appState.indexing.selectedFolders.isEmpty {
            WorkbenchEmptyHint(
                icon: .video,
                message: L("library.recent_watching_empty")
            )
            .frame(minHeight: emptyMinHeight)
            .workbenchPageInlinePadding()
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: emptyMinHeight)
        }
    }

    @ViewBuilder
    private func recentExcerptsContent(
        _ summaries: [ExcerptListSummary],
        emptyMinHeight: CGFloat
    ) -> some View {
        if !summaries.isEmpty {
            ExcerptListCardGrid(
                summaries: summaries,
                highlight: highlight,
                groupsByRecentSection: true
            ) { summary in
                appState.openRecentExcerpt(summary)
            }
            .workbenchMediaCardGridInlinePadding()
        } else if excerpt.hasLoadedListOverview {
            WorkbenchEmptyHint(
                icon: .excerpt,
                message: L("library.recent_excerpts_empty")
            )
            .frame(minHeight: emptyMinHeight)
            .workbenchPageInlinePadding()
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: emptyMinHeight)
        }
    }
}

extension RecentTimeSection {
    var localizedTitle: String {
        switch self {
        case .last7Days:
            return L("recent.section.last_7_days")
        case .last30Days:
            return L("recent.section.last_30_days")
        case .earlier:
            return L("recent.section.earlier")
        case .neverPlayed:
            return L("recent.section.never_played")
        }
    }
}

struct RecentSectionTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                weight: .semibold
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding
            )
    }
}
