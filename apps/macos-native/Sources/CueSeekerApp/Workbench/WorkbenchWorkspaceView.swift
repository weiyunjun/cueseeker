import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

enum WorkbenchPresentedSurface: Equatable {
    case search
    case recent(WorkbenchRecentSection)
    case libraryRoot
    case libraryFolder(folderPath: String)
    case file
    case excerptOverview
    case excerptList(id: Int64)

    @MainActor
    static func current(from routeState: WorkbenchRouteState) -> WorkbenchPresentedSurface {
        switch routeState.panelMode {
        case .search:
            return .search
        case .recentWatching:
            return .recent(routeState.selectedRecentSection)
        case .testLibrary:
            if let folderPath = routeState.selectedLibraryFolderPath {
                return .libraryFolder(folderPath: folderPath)
            }
            return .libraryRoot
        case .file:
            return .file
        case .excerpt:
            if let listID = routeState.selectedExcerptListID {
                return .excerptList(id: listID)
            }
            return .excerptOverview
        }
    }

    var recentSection: WorkbenchRecentSection {
        if case .recent(let section) = self {
            return section
        }
        return .videos
    }

    var libraryFolderPath: String? {
        if case .libraryFolder(let folderPath) = self {
            return folderPath
        }
        return nil
    }

    var excerptListID: Int64? {
        if case .excerptList(let id) = self {
            return id
        }
        return nil
    }

    var diagnosticLabel: String {
        switch self {
        case .search:
            return "search"
        case .recent(.videos):
            return "recent_videos"
        case .recent(.excerpts):
            return "recent_excerpts"
        case .libraryRoot:
            return "library_overview"
        case .libraryFolder:
            return "library_directory"
        case .file:
            return "file"
        case .excerptOverview:
            return "excerpt_overview"
        case .excerptList:
            return "excerpt_detail"
        }
    }
}

private final class WorkbenchSurfaceTransitionTracker {
    var lastTargetSurface: WorkbenchPresentedSurface?
    var lastPresentedSurface: WorkbenchPresentedSurface?
    var asyncPreparedSurface: WorkbenchPresentedSurface?
    var preparationTask: Task<Void, Never>?

    deinit {
        preparationTask?.cancel()
    }
}

struct WorkbenchWorkspaceView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var routeState: WorkbenchRouteState
    // Observed so a Excerpt detail turns into the unknown page when its list
    // leaves the overview.
    @EnvironmentObject private var excerptStore: ExcerptStore
    @EnvironmentObject private var playback: PlaybackStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var transitionTracker = WorkbenchSurfaceTransitionTracker()
    @State private var asyncPreparedRevision: UInt64 = 0

    private var targetSurface: WorkbenchPresentedSurface {
        WorkbenchPresentedSurface.current(from: routeState)
    }

    private var activeSurface: WorkbenchPresentedSurface? {
        _ = asyncPreparedRevision
        let target = targetSurface
        if transitionTracker.lastTargetSurface != target {
            transitionTracker.lastTargetSurface = target
            transitionTracker.asyncPreparedSurface = nil
        }
        if transitionTracker.asyncPreparedSurface == target
            || appState.isWorkbenchSurfaceReadyForPresentation(target)
        {
            transitionTracker.lastPresentedSurface = target
            return target
        }
        return transitionTracker.lastPresentedSurface
    }

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
                    scheduleSurfacePreparationIfNeeded(for: targetSurface)
                    appState.interfaceLayers.setOpen(
                        .playbackPage,
                        showsPlaybackRoute
                    )
                }
                .onChange(of: targetSurface) { newSurface in
                    scheduleSurfacePreparationIfNeeded(for: newSurface)
                }
                .onDisappear {
                    transitionTracker.preparationTask?.cancel()
                    transitionTracker.preparationTask = nil
                }
                .onChange(of: showsPlaybackRoute) { isOpen in
                    appState.interfaceLayers.setOpen(.playbackPage, isOpen)
                }
            }
        }
    }

    private func scheduleSurfacePreparationIfNeeded(
        for surface: WorkbenchPresentedSurface
    ) {
        let preparationStartedAt = DebugInteractionLatencyProbe.now()
        let previousLabel = transitionTracker.lastPresentedSurface?.diagnosticLabel ?? "none"
        let didChangeSurface = transitionTracker.lastPresentedSurface != surface
        transitionTracker.preparationTask?.cancel()
        transitionTracker.preparationTask = nil
        if appState.isWorkbenchSurfaceReadyForPresentation(surface) {
            transitionTracker.lastPresentedSurface = surface
            if didChangeSurface {
                let swapAt = DebugInteractionLatencyProbe.now()
                DebugInteractionLatencyProbe.recordNavigationPreparation(
                    domain: "workbench",
                    from: previousLabel,
                    to: surface.diagnosticLabel,
                    fallbackTrigger: "surface_ready",
                    preparationStartedAt: preparationStartedAt,
                    dataReadyAt: swapAt,
                    coverStats: appState.cachedFirstScreenCoverStats(for: surface),
                    containerSwapAt: swapAt
                )
            }
            return
        }
        transitionTracker.preparationTask = Task { @MainActor in
            let metrics = await appState.prepareWorkbenchSurfaceForPresentation(surface)
            guard !Task.isCancelled else {
                return
            }
            let swapAt = DebugInteractionLatencyProbe.now()
            transitionTracker.preparationTask = nil
            transitionTracker.lastTargetSurface = surface
            transitionTracker.asyncPreparedSurface = surface
            transitionTracker.lastPresentedSurface = surface
            asyncPreparedRevision &+= 1
            DebugInteractionLatencyProbe.recordNavigationPreparation(
                domain: "workbench",
                from: previousLabel,
                to: surface.diagnosticLabel,
                fallbackTrigger: "async_prepare",
                preparationStartedAt: preparationStartedAt,
                dataReadyAt: metrics.dataReadyAt,
                coverStats: metrics.coverStats,
                containerSwapAt: swapAt
            )
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
                if let surface = activeSurface {
                    switch surface {
                    case .excerptOverview, .excerptList:
                        workbenchExcerptSurface(selectedListID: surface.excerptListID)
                    case .recent(let section):
                        WorkbenchRecentView(presentedSection: section)
                    case .libraryRoot, .libraryFolder:
                        WorkbenchLibraryView(presentedFolderPath: surface.libraryFolderPath)
                    case .file:
                        WorkbenchFileView(tasks: appState.tasks)
                    case .search:
                        workbenchSearchSurface
                    }
                } else {
                    WorkbenchRedesignColors.bgSurface
                        .ignoresSafeArea()
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

    private func workbenchExcerptSurface(selectedListID: Int64?) -> some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            if let listID = selectedListID {
                if appState.isWorkbenchRouteUnknown(.excerptList(id: listID)) {
                    WorkbenchEmptyHint(
                        icon: .excerptQuestion,
                        message: L("excerpt.list.not_found")
                    )
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

@MainActor
extension AppCoordinator {
    func isWorkbenchSurfaceReadyForPresentation(
        _ surface: WorkbenchPresentedSurface
    ) -> Bool {
        switch surface {
        case .search, .file, .excerptList:
            return true
        case .recent(let section):
            guard !recentNeedsReloadAfterIndexedMutation else {
                return false
            }
            switch section {
            case .videos:
                if indexing.selectedFolders.isEmpty {
                    return library.testRecentWatchingStatus == .idle
                        && library.testRecentWatchingItems.isEmpty
                }
                guard Self.isLibraryStatusResolved(library.testRecentWatchingStatus) else {
                    return false
                }
                return Self.areFirstScreenCoversReady(firstScreenRecentVideoCoverKeys())
            case .excerpts:
                guard excerpt.hasLoadedListOverview,
                      excerpt.listOverviewTask == nil,
                      !excerptNeedsReloadAfterIndexedContentMutation
                else {
                    return false
                }
                return Self.areFirstScreenCoversReady(firstScreenRecentExcerptCoverKeys())
            }
        case .libraryRoot:
            guard !libraryNeedsReloadAfterIndexedMutation else {
                return false
            }
            if indexing.selectedFolders.isEmpty {
                return library.completeLibraryStatus == .idle
                    && library.completeLibraryFolderSummaries.isEmpty
            }
            guard Self.isLibraryStatusResolved(library.completeLibraryStatus) else {
                return false
            }
            return Self.areFirstScreenCoversReady(firstScreenLibraryRootCoverKeys())
        case .libraryFolder(let folderPath):
            guard !libraryNeedsReloadAfterIndexedMutation else {
                return false
            }
            if isWorkbenchRouteUnknown(.libraryFolder(folderPath: folderPath)) {
                return true
            }
            guard Self.isLibraryStatusResolved(library.completeLibraryStatus) else {
                return false
            }
            guard let folder = library.completeLibraryFolderSummaries.first(where: {
                $0.folderPath == folderPath
            }) else {
                return Self.isLibraryStatusFailed(library.completeLibraryStatus)
            }
            let detailStatus = library.completeLibraryFolderDetailStatusesByPath[folderPath] ?? .idle
            if Self.isLibraryStatusFailed(detailStatus) {
                return true
            }
            guard library.completeLibraryFolderDetailTasks[folderPath] == nil,
                  let detail = library.completeLibraryFolderDetailsByPath[folderPath],
                  detail.folderPath == folderPath
            else {
                return false
            }
            return Self.areFirstScreenCoversReady(
                firstScreenLibraryFolderCoverKeys(folder: folder, detail: detail)
            )
        case .excerptOverview:
            guard excerpt.hasLoadedListOverview,
                  excerpt.listOverviewTask == nil,
                  !excerptNeedsReloadAfterIndexedContentMutation
            else {
                return false
            }
            return Self.areFirstScreenCoversReady(firstScreenExcerptOverviewCoverKeys())
        }
    }

    @discardableResult
    func prepareWorkbenchSurfaceForPresentation(
        _ surface: WorkbenchPresentedSurface
    ) async -> (dataReadyAt: UInt64, coverStats: LibraryCoverPrewarmStats) {
        switch surface {
        case .search, .file, .excerptList:
            return (DebugInteractionLatencyProbe.now(), .zero)
        case .recent(let section):
            refreshExcerptOnReappearanceIfNeeded()
            refreshRecentOnReappearanceIfNeeded()
            switch section {
            case .videos:
                hydrateTestRecentWatchingAsync()
                await testRecentWatchingTask?.value
                let dataReadyAt = DebugInteractionLatencyProbe.now()
                guard !Task.isCancelled else { return (dataReadyAt, .zero) }
                let stats = await LibraryCoverImagePipeline.shared.prewarm(
                    keys: firstScreenRecentVideoCoverKeys()
                )
                return (dataReadyAt, stats)
            case .excerpts:
                loadExcerptListOverviewIfNeeded()
                await excerpt.listOverviewTask?.value
                let dataReadyAt = DebugInteractionLatencyProbe.now()
                guard !Task.isCancelled else { return (dataReadyAt, .zero) }
                let stats = await LibraryCoverImagePipeline.shared.prewarm(
                    keys: firstScreenRecentExcerptCoverKeys()
                )
                return (dataReadyAt, stats)
            }
        case .libraryRoot:
            refreshLibraryOnReappearanceIfNeeded()
            hydrateCompleteLibraryAsync()
            hydrateTestRecentWatchingAsync()
            await completeLibraryTask?.value
            let dataReadyAt = DebugInteractionLatencyProbe.now()
            guard !Task.isCancelled else { return (dataReadyAt, .zero) }
            let stats = await LibraryCoverImagePipeline.shared.prewarm(
                keys: firstScreenLibraryRootCoverKeys()
            )
            return (dataReadyAt, stats)
        case .libraryFolder(let folderPath):
            refreshLibraryOnReappearanceIfNeeded()
            hydrateCompleteLibraryAsync()
            hydrateTestRecentWatchingAsync()
            await completeLibraryTask?.value
            guard !Task.isCancelled else {
                return (DebugInteractionLatencyProbe.now(), .zero)
            }
            guard !isWorkbenchRouteUnknown(.libraryFolder(folderPath: folderPath)),
                  library.completeLibraryFolderSummaries.contains(where: {
                      $0.folderPath == folderPath
                  })
            else {
                return (DebugInteractionLatencyProbe.now(), .zero)
            }
            hydrateCompleteLibraryFolderDetailAsync(folderPath: folderPath)
            await completeLibraryFolderDetailTasks[folderPath]?.value
            let dataReadyAt = DebugInteractionLatencyProbe.now()
            guard !Task.isCancelled else { return (dataReadyAt, .zero) }
            guard let folder = library.completeLibraryFolderSummaries.first(where: {
                $0.folderPath == folderPath
            }),
                  let detail = library.completeLibraryFolderDetailsByPath[folderPath]
            else {
                return (dataReadyAt, .zero)
            }
            let stats = await LibraryCoverImagePipeline.shared.prewarm(
                keys: firstScreenLibraryFolderCoverKeys(folder: folder, detail: detail)
            )
            return (dataReadyAt, stats)
        case .excerptOverview:
            refreshExcerptOnReappearanceIfNeeded()
            loadExcerptListOverviewIfNeeded()
            await excerpt.listOverviewTask?.value
            let dataReadyAt = DebugInteractionLatencyProbe.now()
            guard !Task.isCancelled else { return (dataReadyAt, .zero) }
            let stats = await LibraryCoverImagePipeline.shared.prewarm(
                keys: firstScreenExcerptOverviewCoverKeys()
            )
            return (dataReadyAt, stats)
        }
    }

    func cachedFirstScreenCoverStats(
        for surface: WorkbenchPresentedSurface
    ) -> LibraryCoverPrewarmStats {
        let keys: [LibraryCoverImageKey]
        switch surface {
        case .search, .file, .excerptList:
            return .zero
        case .recent(.videos):
            keys = firstScreenRecentVideoCoverKeys()
        case .recent(.excerpts):
            keys = firstScreenRecentExcerptCoverKeys()
        case .libraryRoot:
            keys = firstScreenLibraryRootCoverKeys()
        case .libraryFolder(let folderPath):
            guard let folder = library.completeLibraryFolderSummaries.first(where: {
                $0.folderPath == folderPath
            }),
                  let detail = library.completeLibraryFolderDetailsByPath[folderPath]
            else {
                return .zero
            }
            keys = firstScreenLibraryFolderCoverKeys(folder: folder, detail: detail)
        case .excerptOverview:
            keys = firstScreenExcerptOverviewCoverKeys()
        }
        let boundedKeys = LibraryCoverImagePipeline.boundedUniqueKeys(from: keys)
        let hits = boundedKeys.filter {
            LibraryCoverImagePipeline.shared.isReadyForPresentation(for: $0)
        }.count
        return LibraryCoverPrewarmStats(
            totalCount: boundedKeys.count,
            cacheHitCount: hits,
            decodedCount: 0,
            elapsedMilliseconds: 0
        )
    }

    private static func isLibraryStatusResolved(_ status: LibraryStatus) -> Bool {
        switch status {
        case .completed, .failed:
            return true
        case .idle, .loading:
            return false
        }
    }

    private static func isLibraryStatusFailed(_ status: LibraryStatus) -> Bool {
        if case .failed = status {
            return true
        }
        return false
    }

    private static func areFirstScreenCoversReady(
        _ keys: [LibraryCoverImageKey]
    ) -> Bool {
        let boundedKeys = LibraryCoverImagePipeline.boundedUniqueKeys(from: keys)
        return boundedKeys.allSatisfy {
            LibraryCoverImagePipeline.shared.isReadyForPresentation(for: $0)
        }
    }

    private func firstScreenRecentVideoCoverKeys() -> [LibraryCoverImageKey] {
        let orderedItems = RecentTimeSection.group(
            library.testRecentWatchingItems,
            timestamp: \.updatedAt
        ).flatMap(\.items)
        return LibraryCoverImagePipeline.boundedUniqueKeys(
            from: orderedItems.compactMap {
                LibraryCoverImageKey.current(
                    path: $0.coverPath,
                    revision: $0.coverRevision
                )
            }
        )
    }

    private func firstScreenRecentExcerptCoverKeys() -> [LibraryCoverImageKey] {
        let orderedItems = RecentTimeSection.group(
            excerpt.recentListSummaries,
            timestamp: \.list.recentPlayedAt
        ).flatMap(\.items)
        return LibraryCoverImagePipeline.boundedUniqueKeys(
            from: orderedItems.compactMap { summary in
                guard let path = summary.list.coverPath, !path.isEmpty else {
                    return nil
                }
                return LibraryCoverImageKey(path: path, revision: path)
            }
        )
    }

    private func firstScreenLibraryRootCoverKeys() -> [LibraryCoverImageKey] {
        LibraryCoverImagePipeline.boundedUniqueKeys(
            from: library.displayedCompleteLibraryFolderSummaries.compactMap {
                LibraryCoverImageKey.current(
                    path: $0.coverPath,
                    revision: $0.coverRevision
                )
            }
        )
    }

    private func firstScreenLibraryFolderCoverKeys(
        folder: CompleteLibraryFolderSummaryPresentation,
        detail: CompleteLibraryFolderDetailPresentation
    ) -> [LibraryCoverImageKey] {
        var keys: [LibraryCoverImageKey] = []
        if let folderKey = LibraryCoverImageKey.current(
            path: folder.coverPath,
            revision: folder.coverRevision
        ) {
            keys.append(folderKey)
        }
        keys.append(
            contentsOf: detail.videos.compactMap {
                LibraryCoverImageKey.current(
                    path: $0.coverPath,
                    revision: $0.coverRevision
                )
            }
        )
        return LibraryCoverImagePipeline.boundedUniqueKeys(from: keys)
    }

    private func firstScreenExcerptOverviewCoverKeys() -> [LibraryCoverImageKey] {
        LibraryCoverImagePipeline.boundedUniqueKeys(
            from: excerpt.displayedListSummaries.compactMap { summary in
                guard let path = summary.list.coverPath, !path.isEmpty else {
                    return nil
                }
                return LibraryCoverImageKey(path: path, revision: path)
            }
        )
    }
}
