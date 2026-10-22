import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct WorkbenchWorkspaceView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var routeState: WorkbenchRouteState
    // Observed so a Excerpt detail turns into the unknown page when its list
    // leaves the overview.
    @EnvironmentObject private var excerptStore: ExcerptStore
    @EnvironmentObject private var playback: PlaybackStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppPerformanceProbe.measure("WorkbenchWorkspaceView.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.Workbench.body",
                scope: appState.uiProbeScope
            )

            return GeometryReader { geometry in
                let showsPlaybackRoute = appState.isPlaybackPageVisible

                ZStack {
                    mainContent
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipped()
                        .allowsHitTesting(!showsPlaybackRoute)
                        .disabled(showsPlaybackRoute)
                        .accessibilityHidden(showsPlaybackRoute)

                    if showsPlaybackRoute {
                        PlaybackPageView(
                            playbackSurface: AnyView(playbackSurface),
                            appState: appState,
                            onClose: {
                                appState.workbenchLayout.clearSearchFocus()
                                appState.stopPlayback()
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .zIndex(10)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(LayoutPerformanceProbe(name: "WorkbenchWorkspaceView.root.layout"))
                // This is where the playback page is routed over the whole
                // workbench, so this is where that layer is registered.
                .onAppear {
                    appState.interfaceLayers.setOpen(
                        .playbackPage,
                        showsPlaybackRoute
                    )
                }
                .onChange(of: showsPlaybackRoute) { isOpen in
                    appState.interfaceLayers.setOpen(.playbackPage, isOpen)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        AppPerformanceProbe.measure("WorkbenchWorkspaceView.mainContent.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.WorkbenchMainContent.body",
                scope: appState.uiProbeScope,
                details: "mode=\(routeState.panelMode.rawValue)"
            )

            return Group {
                switch routeState.panelMode {
                case .excerpt:
                    workbenchExcerptSurface
                case .recentWatching:
                    WorkbenchRecentView()
                case .testLibrary:
                    WorkbenchLibraryView()
                case .file:
                    WorkbenchFileView(tasks: appState.tasks)
                case .search:
                    workbenchSearchSurface
                }
            }
        }
    }

    private var playbackSurface: some View {
        PlaybackView(
            player: appState.playbackPlayer,
            viewModel: playback.playbackViewModel,
            uiProbeScope: appState.uiProbeScope
        )
    }

    private var workbenchSearchSurface: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            WorkbenchSearchView(
                rowStore: appState.search.tableRowStore,
                isTableResponseActive: !appState.isPlaybackPageVisible
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workbenchExcerptSurface: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            if let listID = routeState.selectedExcerptListID {
                if appState.isWorkbenchRouteUnknown(.excerptList(id: listID)) {
                    WorkbenchEmptyHint(message: L("excerpt.list.not_found"))
                } else {
                    WorkbenchExcerptTableView(
                        isTableResponseActive: !appState.isPlaybackPageVisible
                    )
                }
            } else {
                ExcerptListOverviewView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
