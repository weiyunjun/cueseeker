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
        LibraryCardContextMenuHost { _ in
            LibraryOverviewLayout(
                summaryText: L(
                    "excerpt.overview.summary",
                    excerptStore.listOverview.lists.count == 1
                        ? L("excerpt.list_count.one")
                        : L("excerpt.list_count.other", excerptStore.listOverview.lists.count),
                    excerptStore.listOverview.uniqueCueCount == 1
                        ? L("excerpt.cue_count.one")
                        : L("excerpt.cue_count.other", excerptStore.listOverview.uniqueCueCount)
                ),
                actionTitle: L("excerpt.new_list"),
                action: { appState.beginCreatingExcerptList() }
            ) {
                if excerptStore.hasLoadedListOverview {
                    ExcerptListCardGrid(
                        summaries: excerptStore.listOverview.lists,
                        highlight: highlight
                    ) { summary in
                        appState.openExcerptList(id: summary.id)
                    }
                } else {
                    WorkbenchSpinner()
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .cardHighlightFreeze(highlight)
        .task {
            appState.loadExcerptListOverviewIfNeeded()
        }
    }
}
