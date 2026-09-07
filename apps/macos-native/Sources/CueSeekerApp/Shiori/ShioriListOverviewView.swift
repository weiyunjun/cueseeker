import SwiftUI
import CueSeekerCore

struct ShioriListOverviewView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: false
    )

    var body: some View {
        LibraryCardContextMenuHost { _ in
            LibraryOverviewLayout(
                summaryText: L(
                    "shiori.overview.summary",
                    shioriStore.listOverview.lists.count,
                    shioriStore.listOverview.uniqueCueCount
                ),
                actionTitle: L("shiori.new_list"),
                action: { appState.beginCreatingShioriList() }
            ) {
                if shioriStore.hasLoadedListOverview {
                    ShioriListCardGrid(
                        summaries: shioriStore.listOverview.lists,
                        highlight: highlight
                    ) { summary in
                        appState.openShioriList(id: summary.id)
                    }
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
    }
}
