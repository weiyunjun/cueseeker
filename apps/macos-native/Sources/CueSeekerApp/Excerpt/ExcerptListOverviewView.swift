import SwiftUI
import CueSeekerCore

struct ExcerptListOverviewView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var excerptStore: ExcerptStore
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: false
    )

    var body: some View {
        let displayedLists = excerptStore.displayedListSummaries
        let displayedListCount = displayedLists.count
        let displayedCueCount = excerptStore.displayedUniqueCueCount

        Group {
            if excerptStore.hasLoadedListOverview {
                LibraryCardContextMenuHost { _ in
                    LibraryOverviewLayout(
                        searchPlaceholder: L("excerpt.overview.search_placeholder"),
                        searchText: $excerptStore.overviewSearchDraft,
                        sortOptions: ExcerptOverviewSortOrder.workbenchSortOptions,
                        selectedSortOptionID: excerptStore.overviewSortOrder.rawValue,
                        onSelectSortOption: { optionID in
                            if let order = ExcerptOverviewSortOrder(rawValue: optionID) {
                                excerptStore.overviewSortOrder = order
                            }
                        },
                        summaryText: L(
                            "excerpt.overview.summary",
                            displayedListCount == 1
                                ? L("excerpt.list_count.one")
                                : L("excerpt.list_count.other", displayedListCount),
                            displayedCueCount == 1
                                ? L("excerpt.cue_count.one")
                                : L("excerpt.cue_count.other", displayedCueCount)
                        ),
                        actionTitle: L("excerpt.new_list"),
                        action: { appState.beginCreatingExcerptList() },
                        emptySearchMessage: displayedLists.isEmpty
                            ? L("excerpt.overview.search_no_results")
                            : nil
                    ) {
                        ExcerptListCardGrid(
                            summaries: displayedLists,
                            highlight: highlight
                        ) { summary in
                            appState.openExcerptList(id: summary.id)
                        }
                    }
                }
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .cardHighlightFreeze(highlight)
        .task {
            appState.loadExcerptListOverviewIfNeeded()
        }
        .onAppear {
            appState.refreshExcerptOnReappearanceIfNeeded()
        }
    }
}
