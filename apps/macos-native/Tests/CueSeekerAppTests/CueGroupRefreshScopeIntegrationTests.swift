import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp
@testable import CueSeekerCore

private enum MountedLibraryFolderRemovalFailure: Error {
    case expected
}

private actor MountedFailingLibraryFolderRemovalExecutor:
    LibraryFolderRemovalExecuting
{
    private var started = false
    private var continuation: CheckedContinuation<Void, Never>?

    func removeFolder(_ folder: URL, databaseURL: URL) async throws {
        started = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        throw MountedLibraryFolderRemovalFailure.expected
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func finish() {
        continuation?.resume()
        continuation = nil
    }
}

@Suite(.serialized)
struct CueGroupRefreshScopeIntegrationTests {
    @MainActor
    @Test
    func showCueGroupInvalidationIsScopedToMountedSearch() async throws {
        try await verifyShowCueGroupInvalidation(surface: .search)
    }

    @MainActor
    @Test
    func showCueGroupInvalidationIsScopedToMountedContext() async throws {
        try await verifyShowCueGroupInvalidation(surface: .context)
    }

    @MainActor
    @Test
    func showCueGroupInvalidationIsScopedToMountedShiori() async throws {
        try await verifyShowCueGroupInvalidation(surface: .shiori)
    }

    @MainActor
    @Test
    func persistedShowCueGroupOnIsUsedForTheFirstMountedTablePresentation() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(scope: uiProbeScope)
        defer { session.finish() }

        try await withMountedCueTable(
            surface: .search,
            initialShowCueGroup: true,
            uiProbeScope: uiProbeScope
        ) { app, _, coordinator in
            #expect(app.settings.showCueGroup)
            #expect(coordinator.showsCueGroupForTesting())
            #expect(session.recording().count(
                "table.search.show_cue_group_owner_update"
            ) == 0)
        }
    }

    @MainActor
    @Test
    func filterOnlySearchRemountReusesResidentProjectionWithoutHydration() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(
            scope: uiProbeScope
        )
        defer { session.finish() }

        try await withMountedCueTable(
            surface: .search,
            usesFilterOnlySearch: true,
            uiProbeScope: uiProbeScope
        ) { app, window, coordinator in
            let rowStore = app.search.tableRowStore
            let versionBefore = rowStore.snapshot.version
            let entryIDsBefore = rowStore.snapshot.orderedEntryIDs
            #expect(rowStore.snapshot.totalRowCount == 200)
            #expect(session.recording().count(
                SubtitleTableProbeSurface.search.counterName(
                    "row_hydration_requested"
                )
            ) > 0)
            coordinator.scrollToRow(100)
            let didCaptureViewport = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                return (app.search.tableViewportAnchor?.rowIndex ?? 0) > 0
            }
            try #require(didCaptureViewport)
            let viewportAnchorBefore = try #require(
                app.search.tableViewportAnchor
            )

            app.activateWorkbenchPanelMode(.shiori)
            let didMountShiori = await waitUntil(timeout: 2) {
                window.contentView?.layoutSubtreeIfNeeded()
                return findSubtitleTableCoordinator(
                    in: window.contentView,
                    surface: .shiori
                ) != nil
            }
            try #require(didMountShiori)
            let recordingBeforeRemount = session.recording()

            app.activateWorkbenchPanelMode(.search)
            let didRemountSearch = await waitUntil(timeout: 2) {
                window.contentView?.layoutSubtreeIfNeeded()
                return findSubtitleTableCoordinator(
                    in: window.contentView,
                    surface: .search
                ) != nil
            }
            try #require(didRemountSearch)
            try await Task.sleep(nanoseconds: 100_000_000)

            let remountRecording = session.recording().delta(
                since: recordingBeforeRemount
            )
            #expect(remountRecording.count(
                SubtitleTableProbeSurface.search.counterName(
                    "row_hydration_requested"
                )
            ) == 0)
            #expect(rowStore.snapshot.version == versionBefore)
            #expect(rowStore.snapshot.orderedEntryIDs == entryIDsBefore)
            #expect(rowStore.snapshot.totalRowCount == 200)
            #expect(app.search.tableViewportAnchor?.entryID == viewportAnchorBefore.entryID)
        }
    }

    @MainActor
    @Test
    func filterOnlySearchRejectsResidentCueIDsAfterSameFolderReindex() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(
            scope: uiProbeScope
        )
        defer { session.finish() }

        try await withMountedCueTable(
            surface: .search,
            usesFilterOnlySearch: true,
            uiProbeScope: uiProbeScope
        ) { app, window, _ in
            let oldEntryIDs = app.search.tableRowStore.snapshot.orderedEntryIDs
            let oldDataRevision = app.search.indexedCueDataRevision
            let recordingBeforeReindex = session.recording()
            let folder = try #require(app.indexing.selectedFolders.first)

            app.indexFolder(folder)

            #expect(app.search.tableProjectionSource == nil)
            #expect(app.search.tableRowStore.snapshot.totalRowCount == 0)
            await app.indexingTask?.value
            let didReloadStableProjection = await waitUntil(timeout: 3) {
                window.contentView?.layoutSubtreeIfNeeded()
                let expectedKey = SearchFilterOnlyProjectionKey(
                    filterSignature: app.search.activeFilterSetSignature,
                    folderPaths: app.indexing.selectedFolders.map(\.path),
                    indexedCueDataRevision: app.search.indexedCueDataRevision
                )
                return app.search.indexedCueDataRevision == oldDataRevision + 1
                    && app.search.tableProjectionSource == .filterOnly(expectedKey)
                    && !app.indexing.isLibraryFolderOperationActive
            }
            try #require(didReloadStableProjection)
            try await Task.sleep(nanoseconds: 100_000_000)

            let reindexRecording = session.recording().delta(
                since: recordingBeforeReindex
            )
            #expect(reindexRecording.count(
                SubtitleTableProbeSurface.search.counterName(
                    "row_hydration_requested"
                )
            ) > 0)
            #expect(Set(app.search.tableRowStore.snapshot.orderedEntryIDs)
                .isDisjoint(with: oldEntryIDs))
        }
    }

    @MainActor
    @Test
    func failedFolderRemovalRestoresMountedResidentSearch() async throws {
        let executor = MountedFailingLibraryFolderRemovalExecutor()
        let uiProbeScope = UUID().uuidString
        try await withMountedCueTable(
            surface: .search,
            libraryFolderRemovalExecutor: executor,
            uiProbeScope: uiProbeScope
        ) { app, window, coordinator in
            app.submitSearch("primary")
            await app.searchTask?.value
            let didLoadCanonicalSearch = await waitUntil(timeout: 2) {
                window.contentView?.layoutSubtreeIfNeeded()
                return app.search.tableRowStore.snapshot.totalRowCount == 200
                    && app.search.tableRowStore.snapshot.orderedEntryIDs
                        == app.search.searchResultCueIDs.map(Int.init)
            }
            try #require(didLoadCanonicalSearch)
            let originalEntryIDs = app.search.tableRowStore.snapshot.orderedEntryIDs
            coordinator.scrollToRow(100)
            let didCaptureViewport = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                return (app.search.tableViewportAnchor?.rowIndex ?? 0) > 0
            }
            try #require(didCaptureViewport)
            let originalAnchor = try #require(app.search.tableViewportAnchor)
            let folder = try #require(app.indexing.selectedFolders.first)

            app.removeFolder(folder)
            let removalTask = try #require(app.folderRemovalTask)
            await executor.waitUntilStarted()

            if case .residentSearch = app.search.tableProjectionSource {
                #expect(app.search.tableRowStore.snapshot.orderedEntryIDs
                    == originalEntryIDs)
            } else {
                Issue.record("Resident Search projection was cleared during removal")
            }

            await executor.finish()
            await removalTask.value
            await app.searchTask?.value
            let didRestoreSearch = await waitUntil(timeout: 2) {
                window.contentView?.layoutSubtreeIfNeeded()
                return app.search.tableRowStore.snapshot.orderedEntryIDs
                    == originalEntryIDs
            }
            try #require(didRestoreSearch)

            #expect(app.indexing.folderRemovalStatus == .idle)
            #expect(app.search.tableRowStore.snapshot.totalRowCount == 200)
            #expect(app.search.tableViewportAnchor?.entryID == originalAnchor.entryID)
        }
    }

    @MainActor
    @Test
    func widthReflowStaysWithMountedTableWhileMountedFocusRemainsStable() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(scope: uiProbeScope)
        defer { session.finish() }

        try await withMountedCueTable(
            surface: .search,
            uiProbeScope: uiProbeScope
        ) { app, window, coordinator in
            app.workbenchLayout.setSidebarVisible(false)
            window.setContentSize(NSSize(width: 1_100, height: 900))
            let didNormalizeWindow = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                guard let contentWidth = window.contentView?.bounds.width else {
                    return false
                }
                return !app.workbenchLayout.isSidebarVisible
                    && abs(contentWidth - 1_100) < 0.5
            }
            try #require(didNormalizeWindow)

            let targetRow = min(150, coordinator.numberOfRowsForTesting() / 2)
            coordinator.scrollToRow(targetRow)
            let didResolveAnchor = await waitUntil(timeout: 1) {
                coordinator.primaryFirstLineScreenYForTesting(row: targetRow) != nil
            }
            try #require(didResolveAnchor)
            let anchorBefore = try #require(
                coordinator.primaryFirstLineScreenYForTesting(row: targetRow)
            )
            let identityBefore = try #require(
                coordinator.primaryCueIdentityForTesting(row: targetRow)
            )
            let rowsVersionBefore = coordinator.rowsVersionForTesting()

            let focusHost = NSHostingView(rootView: AnyView(
                PlaybackSubtitleFocusOverlay(
                    snapshot: cueGroupRefreshScopeFocusSnapshot(),
                    uiProbeScope: uiProbeScope
                )
                .frame(width: 480, height: 360)
            ))
            focusHost.frame = CGRect(x: 0, y: 0, width: 480, height: 360)
            window.contentView?.addSubview(focusHost)
            defer {
                findSubtitleFocusReel(in: focusHost)?.invalidate()
                focusHost.removeFromSuperview()
            }
            let didMountFocus = await waitUntil(timeout: 1) {
                focusHost.layoutSubtreeIfNeeded()
                let recording = session.recording()
                return recording.count("UI.PlaybackSubtitleFocusOverlay.body") > 0
                    && recording.count("playback.subtitle_focus.native_make") > 0
                    && recording.count("playback.subtitle_focus.cue_measurement") > 0
            }
            try #require(didMountFocus)
            let recordingBefore = session.recording()

            window.setContentSize(NSSize(width: 1_180, height: 900))
            let didReflow = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                return session.recording()
                    .delta(since: recordingBefore)
                    .count("table.search.width_reflow_owner_update") > 0
            }
            try #require(didReflow)
            try await Task.sleep(nanoseconds: 50_000_000)
            let recording = session.recording().delta(since: recordingBefore)
            let anchorAfter = try #require(
                coordinator.primaryFirstLineScreenYForTesting(row: targetRow)
            )

            #expect(recording.markCount("ACTION UI.SubtitleTable.search.width_reflow") == 1)
            #expect(recording.count("table.search.width_reflow_owner_update") == 1)
            #expect(recording.count("table.search.dynamic_row_measurement") > 0)
            #expect(recording.count("table.search.dynamic_scroll_anchor_correction") > 0)
            #expect(recording.count("table.search.snapshot_rebuild") == 0)
            #expect(recording.count("table.search.row_hydration_requested") == 0)
            #expect(recording.count("table.search.row_hydration_applied") == 0)
            #expect(recording.count("UI.PlaybackSubtitleFocusOverlay.body") == 0)
            #expect(recording.count("playback.subtitle_focus.native_make") == 0)
            #expect(recording.count("playback.subtitle_focus.native_update") == 0)
            #expect(recording.count("playback.subtitle_focus.layout_update") == 0)
            #expect(recording.count("playback.subtitle_focus.cue_measurement") == 0)
            #expect(recording.count("library.snapshot_rebuild") == 0)
            #expect(recording.count("playback.render_host_update") == 0)
            #expect(coordinator.rowsVersionForTesting() == rowsVersionBefore)
            #expect(coordinator.primaryCueIdentityForTesting(row: targetRow) == identityBefore)
            #expect(abs(anchorAfter - anchorBefore) < 0.5)
        }
    }

    @MainActor
    private func verifyShowCueGroupInvalidation(
        surface: SubtitleTableProbeSurface
    ) async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(
            scope: uiProbeScope
        )
        defer { session.finish() }

        try await withMountedCueTable(
            surface: surface,
            uiProbeScope: uiProbeScope
        ) { app, window, coordinator in
                if surface == .context {
                    let mountedRecording = session.recording()
                    #expect(mountedRecording.count(
                        surface.counterName("row_hydration_requested")
                    ) > 0)
                    #expect(mountedRecording.count(
                        surface.counterName("snapshot_rebuild")
                    ) > 0)
                    #expect(mountedRecording.count(
                        surface.counterName("row_hydration_applied")
                    ) > 0)
                }
                let targetRow = min(150, coordinator.numberOfRowsForTesting() / 2)
                coordinator.scrollToRow(targetRow)
                let didResolveAnchor = await waitUntil(timeout: 1) {
                    coordinator.primaryFirstLineScreenYForTesting(row: targetRow) != nil
                }
                try #require(didResolveAnchor)

                #expect(coordinator.toggleRowCheckboxFromMouseForTesting(row: targetRow))
                let didSelectRow = await waitUntil(timeout: 1) {
                    coordinator.rowSelectionStateForTesting(row: targetRow)
                }
                try #require(didSelectRow)

                let rowCountBefore = coordinator.numberOfRowsForTesting()
                let rowsVersionBefore = coordinator.rowsVersionForTesting()
                let identityBefore = try #require(
                    coordinator.primaryCueIdentityForTesting(row: targetRow)
                )
                let textBefore = try #require(
                    coordinator.primaryCueTextForTesting(row: targetRow)
                )
                let anchorBefore = try #require(
                    coordinator.primaryFirstLineScreenYForTesting(row: targetRow)
                )
                let measurementRangeBeforeCount =
                    coordinator.measurementRowRangeForTesting()?.count ?? 0
                let recordingBefore = session.recording()

                try await pressShowCueGroupToggle(in: window, app: app)
                let didReflow = await waitUntil(timeout: 1) {
                    let delta = session.recording()
                        .delta(since: recordingBefore)
                    return delta.count(
                        surface.counterName("show_cue_group_owner_update")
                    ) > 0
                }
                try #require(didReflow)
                window.contentView?.layoutSubtreeIfNeeded()
                try await Task.sleep(nanoseconds: 50_000_000)

                let recording = session.recording()
                    .delta(since: recordingBefore)
                let anchorAfter = try #require(
                    coordinator.primaryFirstLineScreenYForTesting(row: targetRow)
                )
                let measurementLimit = measurementRangeBeforeCount
                    + (coordinator.measurementRowRangeForTesting()?.count ?? 0)
                    + 2

                #expect(recording.markCount("ACTION UI.ShowCueGroup.changed") == 1)
                #expect(recording.count(surface.counterName("surface_body")) > 0)
                #expect(recording.count(surface.counterName("native_update")) > 0)
                #expect(recording.count(surface.counterName("native_make")) == 0)
                #expect(recording.count(surface.counterName("show_cue_group_owner_update")) == 1)
                #expect(recording.count(surface.counterName("dynamic_row_measurement")) > 0)
                #expect(
                    recording.count(surface.counterName("dynamic_row_measurement"))
                        <= UInt64(measurementLimit)
                )
                #expect(recording.count(surface.counterName("dynamic_scroll_anchor_correction")) > 0)
                #expect(abs(anchorAfter - anchorBefore) < 0.5)

                #expect(coordinator.numberOfRowsForTesting() == rowCountBefore)
                #expect(coordinator.rowsVersionForTesting() == rowsVersionBefore)
                #expect(coordinator.primaryCueIdentityForTesting(row: targetRow) == identityBefore)
                #expect(coordinator.primaryCueTextForTesting(row: targetRow) == textBefore)
                #expect(coordinator.rowSelectionStateForTesting(row: targetRow))

                for counter in forbiddenRefreshScopeCounters(activeSurface: surface) {
                    #expect(recording.count(counter) == 0, "Unexpected refresh: \(counter)")
                }
        }
    }

    @MainActor
    @Test
    func contextHydrationRequestIsRecordedWhenNoSnapshotCanBeApplied() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(
            scope: uiProbeScope
        )
        defer { session.finish() }
        let recordingBefore = session.recording()
        try await withMountedCueTable(
            surface: .context,
            usesMissingContextTarget: true,
            uiProbeScope: uiProbeScope
        ) { _, _, _ in
            let recording = session.recording()
                .delta(since: recordingBefore)
            #expect(recording.count("table.context.row_hydration_requested") > 0)
            #expect(recording.count("table.context.row_hydration_applied") == 0)
        }
    }

    @MainActor
    @Test
    func showCueGroupDoesNotRefreshPlaybackCoveredTableOrMountedRenderHost() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(
            scope: uiProbeScope
        )
        defer { session.finish() }

        try await withMountedCueTable(
            surface: .search,
            uiProbeScope: uiProbeScope
        ) { app, window, coordinator in
            let targetRow = min(120, coordinator.numberOfRowsForTesting() / 2)
            coordinator.scrollToRow(targetRow)
            let didResolveAnchor = await waitUntil(timeout: 1) {
                coordinator.primaryFirstLineScreenYForTesting(row: targetRow) != nil
            }
            try #require(didResolveAnchor)
            let anchorBefore = try #require(
                coordinator.primaryFirstLineScreenYForTesting(row: targetRow)
            )
            let identityBefore = try #require(
                coordinator.primaryCueIdentityForTesting(row: targetRow)
            )
            let rowsVersionBefore = coordinator.rowsVersionForTesting()
            #expect(coordinator.toggleRowCheckboxFromMouseForTesting(row: targetRow))
            let didSelectRow = await waitUntil(timeout: 1) {
                coordinator.rowSelectionStateForTesting(row: targetRow)
            }
            try #require(didSelectRow)

            app.ensurePlayerInitialized()
            app.search.selectedSearchResult = app.search.searchResults.first
            let focusSession = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: cueGroupRefreshScopeFocusOpenSnapshot()
            ))
            #expect(focusSession.publishInitialSnapshot(
                cueGroupRefreshScopeFocusSnapshot(),
                token: focusSession.token
            ))
            app.playback.isPlaybackSurfaceExpanded = true
            let didMountPlayback = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                let recording = session.recording()
                return recording.count("UI.PlaybackPage.body") > 0
                    && recording.count("playback.render_host_native_make") > 0
                    && recording.count("UI.PlaybackSubtitleFocusOverlay.body") > 0
                    && recording.count("playback.subtitle_focus.native_make") > 0
                    && recording.count("playback.subtitle_focus.layout_update") > 0
                    && recording.count("playback.subtitle_focus.cue_measurement") > 0
            }
            try #require(didMountPlayback)
            try await Task.sleep(nanoseconds: 50_000_000)
            let recordingBefore = session.recording()

            try await pressShowCueGroupToggle(in: window, app: app)
            try await Task.sleep(nanoseconds: 100_000_000)
            window.contentView?.layoutSubtreeIfNeeded()
            let recording = session.recording().delta(since: recordingBefore)

            #expect(recording.markCount("ACTION UI.ShowCueGroup.changed") == 1)
            for surface in SubtitleTableProbeSurface.allCases {
                #expect(recording.count(surface.counterName("surface_body")) == 0)
                #expect(recording.count(surface.counterName("native_update")) == 0)
                #expect(recording.count(surface.counterName("show_cue_group_owner_update")) == 0)
                #expect(recording.count(surface.counterName("snapshot_rebuild")) == 0)
                #expect(recording.count(surface.counterName("row_hydration_requested")) == 0)
                #expect(recording.count(surface.counterName("row_hydration_applied")) == 0)
            }
            #expect(recording.count("UI.PlaybackPage.body") == 0)
            #expect(recording.count("playback.render_host_update") == 0)
            #expect(recording.count("playback.high_frequency_chrome_update") == 0)
            #expect(recording.count("UI.PlaybackSubtitleFocusOverlay.body") == 0)
            #expect(recording.count("playback.subtitle_focus.native_make") == 0)
            #expect(recording.count("playback.subtitle_focus.native_update") == 0)
            #expect(recording.count("playback.subtitle_focus.layout_update") == 0)
            #expect(recording.count("playback.subtitle_focus.cue_measurement") == 0)
            #expect(recording.count("playback.subtitle_focus.cue_draw") == 0)
            #expect(recording.count("library.snapshot_rebuild") == 0)

            let recordingBeforeResume = session.recording()
            app.playback.isPlaybackSurfaceExpanded = false
            let didApplyDeferredValue = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                return session.recording()
                    .delta(since: recordingBeforeResume)
                    .count("table.search.show_cue_group_owner_update") > 0
            }
            try #require(didApplyDeferredValue)
            try await Task.sleep(nanoseconds: 50_000_000)
            let resumedRecording = session.recording()
                .delta(since: recordingBeforeResume)
            let anchorAfter = try #require(
                coordinator.primaryFirstLineScreenYForTesting(row: targetRow)
            )

            #expect(resumedRecording.count("table.search.show_cue_group_owner_update") == 1)
            #expect(resumedRecording.count("table.search.snapshot_rebuild") == 0)
            #expect(resumedRecording.count("table.search.row_hydration_requested") == 0)
            #expect(resumedRecording.count("table.search.row_hydration_applied") == 0)
            #expect(coordinator.rowsVersionForTesting() == rowsVersionBefore)
            #expect(coordinator.primaryCueIdentityForTesting(row: targetRow) == identityBefore)
            #expect(coordinator.rowSelectionStateForTesting(row: targetRow))
            #expect(abs(anchorAfter - anchorBefore) < 0.5)
        }
    }

    @MainActor
    @Test
    func urlSchemeEmptyFallbackUsesOverlayWithoutRevealingWorkbenchTable() async throws {
        let uiProbeScope = UUID().uuidString
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting(
            scope: uiProbeScope
        )
        defer { session.finish() }

        try await withMountedCueTable(
            surface: .search,
            uiProbeScope: uiProbeScope
        ) { app, window, coordinator in
            #expect(coordinator.numberOfRowsForTesting() == 200)
            app.settings.urlSchemePlayFirstSearchResultEnabled = true
            let playingResult = app.search.searchResults[0]
            app.search.selectedSearchResult = playingResult
            app.activePlaybackSource = .search
            app.playback.isPlaybackSurfaceExpanded = true
            let overlaySession = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
                    source: SubtitleFocusSourceIdentity(
                        videoPath: playingResult.videoPath,
                        subtitlePath: playingResult.subtitlePath,
                        subtitleFormat: playingResult.subtitleFormat
                    ),
                    timestampMilliseconds: playingResult.startMilliseconds,
                    wasPlaying: false
                ),
                searchStore: app.search
            ))

            let didMountPlayback = await waitUntil(timeout: 1) {
                window.contentView?.layoutSubtreeIfNeeded()
                return session.recording().count("UI.PlaybackPage.body") > 0
            }
            try #require(didMountPlayback)
            try await Task.sleep(nanoseconds: 50_000_000)
            let recordingBefore = session.recording()

            app.handleURLSchemeCommand(.search(keyword: "missing URL result"))
            await app.searchTask?.value
            window.contentView?.layoutSubtreeIfNeeded()

            #expect(app.search.searchQuery == "missing URL result")
            #expect(app.search.searchResults.isEmpty)
            #expect(app.search.selectedSearchResult == playingResult)
            #expect(app.isPlaybackPageVisible)
            #expect(overlaySession.selectedModule == .search)
            #expect(session.recording()
                .delta(since: recordingBefore)
                .count("table.search.snapshot_rebuild") == 0)
        }
    }

    @MainActor
    @Test
    func asynchronousProbeSessionCapturesDeferredMainRunLoopEvents() async throws {
        let session = UIInvalidationProbe.beginAsyncRecordingForTesting()
        defer { session.finish() }

        DispatchQueue.main.async {
            UIInvalidationProbe.count("test.deferred_main_event")
        }
        let didCapture = await waitUntil(timeout: 1) {
            session.recording().count("test.deferred_main_event") == 1
        }
        try #require(didCapture)
    }

    @Test
    func asynchronousProbeSessionsIsolateExactScopesAndSupportOverlap() {
        let scopeA = UUID().uuidString
        let scopeB = UUID().uuidString
        let sessionA = UIInvalidationProbe.beginAsyncRecordingForTesting(scope: scopeA)
        let sessionB = UIInvalidationProbe.beginAsyncRecordingForTesting(scope: scopeB)
        let catchAllSession = UIInvalidationProbe.beginAsyncRecordingForTesting()
        defer {
            sessionA.finish()
            sessionB.finish()
            catchAllSession.finish()
        }

        UIInvalidationProbe.count("test.overlapping_scope", scope: scopeA)
        UIInvalidationProbe.count("test.overlapping_scope", scope: scopeB)
        UIInvalidationProbe.count("test.overlapping_scope")
        UIInvalidationProbe.mark("ACTION test.overlapping_scope", scope: scopeA)
        UIInvalidationProbe.mark("ACTION test.overlapping_scope", scope: scopeB)

        #expect(sessionA.recording().count("test.overlapping_scope") == 1)
        #expect(sessionB.recording().count("test.overlapping_scope") == 1)
        #expect(catchAllSession.recording().count("test.overlapping_scope") == 3)
        #expect(sessionA.recording().markCount("ACTION test.overlapping_scope") == 1)
        #expect(sessionB.recording().markCount("ACTION test.overlapping_scope") == 1)
        #expect(catchAllSession.recording().markCount("ACTION test.overlapping_scope") == 2)

        sessionA.finish()
        let finishedRecording = sessionA.recording()
        UIInvalidationProbe.count("test.overlapping_scope", scope: scopeA)
        UIInvalidationProbe.mark("ACTION test.overlapping_scope", scope: scopeA)
        #expect(sessionA.recording() == finishedRecording)
        #expect(catchAllSession.recording().count("test.overlapping_scope") == 4)
        #expect(catchAllSession.recording().markCount("ACTION test.overlapping_scope") == 3)
    }
}

@MainActor
private func pressShowCueGroupToggle(
    in window: NSWindow,
    app: AppCoordinator
) async throws {
    let hostingView = NSHostingView(
        rootView: SettingsSearchCategory()
            .environmentObject(app.settings)
            .environmentObject(app.settings.cueGroupPresentation)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 560, height: 360)
    window.contentView?.addSubview(hostingView)
    defer { hostingView.removeFromSuperview() }

    var toggle: NSView?
    let didMountToggle = await waitUntil(timeout: 1) {
        hostingView.layoutSubtreeIfNeeded()
        toggle = nativeSwitchDescendant(in: hostingView)
        return toggle != nil
    }
    try #require(didMountToggle)
    let mountedToggle = try #require(toggle)
    _ = mountedToggle.accessibilityPerformPress()
    let didApply = await waitUntil(timeout: 1) {
        app.settings.showCueGroup
    }
    try #require(didApply)
}

@MainActor
private func nativeSwitchDescendant(in root: NSView) -> NSView? {
    if root.accessibilitySubrole() == .switch {
        return root
    }
    for child in root.subviews {
        if let result = nativeSwitchDescendant(in: child) {
            return result
        }
    }
    return nil
}

@MainActor
private func withMountedCueTable(
    surface: SubtitleTableProbeSurface,
    usesMissingContextTarget: Bool = false,
    usesFilterOnlySearch: Bool = false,
    initialShowCueGroup: Bool = false,
    libraryFolderRemovalExecutor: (any LibraryFolderRemovalExecuting)? = nil,
    uiProbeScope: String,
    _ body: @MainActor (AppCoordinator, NSWindow, SubtitleTableView.Coordinator) async throws -> Void
) async throws {
    _ = NSApplication.shared
    let harness = try CueGroupRefreshScopeMountedHarness(
        surface: surface,
        usesMissingContextTarget: usesMissingContextTarget,
        usesFilterOnlySearch: usesFilterOnlySearch,
        initialShowCueGroup: initialShowCueGroup,
        libraryFolderRemovalExecutor: libraryFolderRemovalExecutor,
        uiProbeScope: uiProbeScope
    )
    defer { harness.tearDown() }
    let window = try #require(harness.window)

    if usesMissingContextTarget {
        let didMountContext = await waitUntil(timeout: 2) {
            findSubtitleTableCoordinator(
                in: window.contentView,
                surface: .context
            ) != nil
        }
        try #require(didMountContext)
        try await Task.sleep(nanoseconds: 100_000_000)
        harness.coordinator = findSubtitleTableCoordinator(
            in: window.contentView,
            surface: .context
        )
        try #require(harness.coordinator != nil)
    } else {
        harness.coordinator = await waitForSubtitleTable(
            in: window,
            surface: surface,
            minimumRowCount: 200,
            timeout: 3
        )
        _ = try #require(harness.coordinator)
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    try await body(
        try #require(harness.app),
        window,
        try #require(harness.coordinator)
    )
}

@MainActor
private final class CueGroupRefreshScopeMountedHarness {
    private let suiteName: String
    let userDefaults: UserDefaults
    let root: URL
    var app: AppCoordinator?
    var window: NSWindow?
    var hostingView: NSHostingView<AnyView>?
    var coordinator: SubtitleTableView.Coordinator?
    private var didTearDown = false

    init(
        surface: SubtitleTableProbeSurface,
        usesMissingContextTarget: Bool,
        usesFilterOnlySearch: Bool,
        initialShowCueGroup: Bool,
        libraryFolderRemovalExecutor: (any LibraryFolderRemovalExecuting)?,
        uiProbeScope: String
    ) throws {
        suiteName = "CueGroupRefreshScopeTests-\(UUID().uuidString)"
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CueGroupRefreshScopeTests-\(UUID().uuidString)",
                isDirectory: true
            )
        let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
        let subtitleURL = root.appendingPathComponent("Episode.ass")
        let videoURL = root.appendingPathComponent("Episode.mkv")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let firstCueID: Int64
        do {
            try DatabaseBootstrap.prepare(at: databaseURL)
            let database = try SubtitleDatabase(path: databaseURL)
            try database.replaceCueGroups(
                subtitleFile: subtitleURL,
                videoFile: videoURL,
                format: .ass,
                cueGroups: cueGroupRefreshScopeGroups(groupCount: 200)
            )
            firstCueID = try #require(
                try database.firstCueID(forSubtitleFile: subtitleURL)
            )
        }
        userDefaults.set([root.path], forKey: "selectedFolderPaths")
        userDefaults.set(initialShowCueGroup, forKey: "showCueGroup")

        let app: AppCoordinator
        if let libraryFolderRemovalExecutor {
            app = AppCoordinator(
                userDefaults: userDefaults,
                databaseURL: databaseURL,
                uiProbeScope: uiProbeScope,
                libraryFolderRemovalExecutor: libraryFolderRemovalExecutor
            )
        } else {
            app = AppCoordinator(
                userDefaults: userDefaults,
                databaseURL: databaseURL,
                uiProbeScope: uiProbeScope
            )
        }
        switch surface {
        case .search:
            if usesFilterOnlySearch {
                let rules = [
                    SchemaWorkbenchSearchDefaults.makeFilterRule(
                        join: nil,
                        fieldID: "cues",
                        operatorID: .contains,
                        value: "primary"
                    ),
                ]
                app.search.searchQuery = ""
                app.search.tableFilterRules = rules
                app.search.activeFilterSet = rules.subtitleSearchFilterSet
            } else {
                app.search.searchQuery = "primary"
                app.search.searchResults = cueGroupRefreshScopeSearchResults(
                    subtitlePath: subtitleURL.path,
                    videoPath: videoURL.path,
                    rowCount: 200
                )
                app.search.searchResultCueIDs = app.search.searchResults.map(\.entryID)
                app.search.searchResultTotalCount = app.search.searchResults.count
                app.search.searchStatus = .completed
            }
            app.activateWorkbenchPanelMode(.search)
        case .context:
            app.search.cueContextSearchRequest = CueContextSearchRequest(
                displayTitle: "Episode",
                subtitlePath: subtitleURL.path,
                targetCueID: usesMissingContextTarget ? Int64.max : firstCueID
            )
            app.activateWorkbenchPanelMode(.search)
        case .shiori:
            let sources = cueGroupRefreshScopeShioriSources(
                subtitlePath: subtitleURL.path,
                videoPath: videoURL.path,
                rowCount: 200
            )
            app.shiori.tableRowStore.hydrateShioriRows(
                sources,
                startIndex: 0,
                totalRowCount: sources.count,
                tableName: "shiori",
                probeSurface: .shiori,
                probeScope: uiProbeScope
            )
            app.shiori.installTableResultShioriIDs(
                sources.map { $0.shiori.id }
            )
            app.shiori.markTableRowsLoaded(totalSavedRowCount: sources.count)
            app.activateWorkbenchPanelMode(.shiori)
        }

        let contentView = AnyView(ContentView()
            .environmentObject(app)
            .environmentObject(app.workbenchLayout)
            .environmentObject(app.workbenchLayout.route)
            .environmentObject(app.settings)
            .environmentObject(app.settings.cueGroupPresentation)
            .environmentObject(app.indexing)
            .environmentObject(app.shiori)
            .environmentObject(app.library)
            .environmentObject(app.search)
            .environmentObject(app.playback))
        let hostingView = NSHostingView(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_440, height: 900),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)
        self.app = app
        self.hostingView = hostingView
        self.window = window
    }

    func tearDown() {
        guard !didTearDown else { return }
        didTearDown = true

        app?.stopPlayback()
        coordinator?.quiesceForTesting()
        window?.orderOut(nil)
        CueGroupRefreshScopeHarnessRetention.retain(self)
    }
}

@MainActor
private enum CueGroupRefreshScopeHarnessRetention {
    // Releasing a complete SwiftUI/AppKit graph from swiftpm-testing-helper
    // can crash in objc_autoreleasePoolPop on macOS 15. Keep this bounded
    // suite-local set alive after explicitly disabling global monitors and
    // playback. Production objects do not use this retention path.
    private static var harnesses: [CueGroupRefreshScopeMountedHarness] = []

    static func retain(_ harness: CueGroupRefreshScopeMountedHarness) {
        harnesses.append(harness)
    }
}

@MainActor
private func waitForSubtitleTable(
    in window: NSWindow,
    surface: SubtitleTableProbeSurface,
    minimumRowCount: Int,
    timeout: TimeInterval
) async -> SubtitleTableView.Coordinator? {
    var coordinator: SubtitleTableView.Coordinator?
    let ready = await waitUntil(timeout: timeout) {
        window.contentView?.layoutSubtreeIfNeeded()
        coordinator = findSubtitleTableCoordinator(
            in: window.contentView,
            surface: surface
        )
        return (coordinator?.numberOfRowsForTesting() ?? 0) >= minimumRowCount
    }
    return ready ? coordinator : nil
}

@MainActor
private func findSubtitleTableCoordinator(
    in view: NSView?,
    surface: SubtitleTableProbeSurface
) -> SubtitleTableView.Coordinator? {
    guard let view else {
        return nil
    }
    if let documentView = view as? SubtitleVirtualTableDocumentView,
       let coordinator = documentView.coordinator,
       coordinator.probeSurfaceForTesting() == surface {
        return coordinator
    }
    for subview in view.subviews {
        if let coordinator = findSubtitleTableCoordinator(in: subview, surface: surface) {
            return coordinator
        }
    }
    return nil
}

@MainActor
private func findSubtitleFocusReel(
    in view: NSView?
) -> PlaybackSubtitleFocusReelContainerView? {
    guard let view else {
        return nil
    }
    if let reel = view as? PlaybackSubtitleFocusReelContainerView {
        return reel
    }
    for subview in view.subviews {
        if let reel = findSubtitleFocusReel(in: subview) {
            return reel
        }
    }
    return nil
}

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    condition: () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if condition() {
            return true
        }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)
    } while Date() < deadline
    return condition()
}

private func forbiddenRefreshScopeCounters(
    activeSurface: SubtitleTableProbeSurface
) -> [String] {
    let allSurfaceDataCounters = SubtitleTableProbeSurface.allCases.flatMap { surface in
        [
            surface.counterName("snapshot_rebuild"),
            surface.counterName("row_hydration_requested"),
            surface.counterName("row_hydration_applied"),
        ]
    }
    let inactiveSurfaceCounters = SubtitleTableProbeSurface.allCases
        .filter { $0 != activeSurface }
        .flatMap { surface in
            [
                surface.counterName("surface_body"),
                surface.counterName("native_make"),
                surface.counterName("native_update"),
                surface.counterName("show_cue_group_owner_update"),
                surface.counterName("dynamic_row_measurement"),
                surface.counterName("dynamic_scroll_anchor_correction"),
            ]
        }
    return allSurfaceDataCounters + inactiveSurfaceCounters + [
        "search.query_requested",
        "UI.SearchPresentation.rebuilt",
        "UI.ShioriPresentation.rebuilt",
        "UI.Workbench.body",
        "UI.WorkbenchMainContent.body",
        "UI.ContentView.body",
        "UI.AppTopBar.body",
        "UI.AppSidebar.body",
        "UI.LibraryPanel.body",
        "UI.PlaybackPage.body",
        "UI.PlaybackSubtitleFocusOverlay.body",
        "library.snapshot_rebuild",
        "playback.render_host_update",
        "playback.high_frequency_chrome_update",
        "playback.subtitle_focus.native_make",
        "playback.subtitle_focus.native_update",
        "playback.subtitle_focus.layout_update",
        "playback.subtitle_focus.cue_measurement",
        "playback.subtitle_focus.cue_draw",
    ]
}

private func cueGroupRefreshScopeFocusOpenSnapshot() -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Focus.mkv",
            subtitlePath: "/Media/Focus.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 12_500,
        wasPlaying: false
    )
}

private func cueGroupRefreshScopeFocusSnapshot() -> SubtitleFocusSnapshot {
    var cues: [SubtitleFocusCue] = []
    for ordinal in 6..<16 {
        let startMilliseconds = ordinal * 1_000
        cues.append(SubtitleFocusCue(
            id: Int64(ordinal + 1),
            cueGroupID: Int64(ordinal + 1_001),
            ordinal: ordinal,
            eventIndex: ordinal,
            displayOrder: 0,
            startMilliseconds: startMilliseconds,
            endMilliseconds: startMilliseconds + 900,
            content: "focus cue \(ordinal)\nsecond line"
        ))
    }
    return SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: cues
    )
}

private func cueGroupRefreshScopeGroups(groupCount: Int) -> [SubtitleCueGroup] {
    var groups: [SubtitleCueGroup] = []
    groups.reserveCapacity(groupCount)
    for groupIndex in 0..<groupCount {
        let start = groupIndex * 2_000
        var lines: [SubtitleCueLine] = []
        lines.reserveCapacity(3)
        for siblingIndex in 0..<3 {
            let content = siblingIndex == 2
                ? "primary \(groupIndex)"
                : "context \(siblingIndex) for \(groupIndex)"
            lines.append(SubtitleCueLine(
                eventIndex: groupIndex * 3 + siblingIndex,
                sourceFormat: .ass,
                sourceStyle: siblingIndex == 2 ? "Primary" : "Context",
                sourceLayer: siblingIndex,
                startTimecode: "0:00:00.00",
                endTimecode: "0:00:01.00",
                startMilliseconds: start,
                endMilliseconds: start + 1_000,
                content: content,
                displayX: nil,
                displayY: Double(siblingIndex * 100),
                displayOrder: siblingIndex
            ))
        }
        groups.append(SubtitleCueGroup(
            sequenceNumber: nil,
            startTimecode: "0:00:00.00",
            endTimecode: "0:00:01.00",
            startMilliseconds: start,
            endMilliseconds: start + 1_000,
            searchContent: lines.map(\.content).joined(separator: "\n"),
            cueLines: lines
        ))
    }
    return groups
}

private func cueGroupRefreshScopeSearchResults(
    subtitlePath: String,
    videoPath: String,
    rowCount: Int
) -> [SubtitleSearchResult] {
    (0..<rowCount).map { index in
        let primary = "primary \(index) " + String(
            repeating: "wrapped cue content for dynamic width reflow ",
            count: 8
        )
        let group = [
            "context 0 for \(index)",
            "context 1 for \(index)",
            primary,
        ]
        return SubtitleSearchResult(
            entryID: Int64(index + 1),
            cueGroupID: Int64(index + 1),
            primaryGroupIndex: 2,
            subtitlePath: subtitlePath,
            subtitleFormat: .ass,
            videoPath: videoPath,
            videoName: "Episode.mkv",
            displayTitle: "Episode",
            startMilliseconds: index * 2_000,
            endMilliseconds: index * 2_000 + 1_000,
            content: group[2],
            cueLines: [group[2]],
            cueGroupLines: group,
            languages: [.japanese],
            speakers: []
        )
    }
}

private func cueGroupRefreshScopeShioriSources(
    subtitlePath: String,
    videoPath: String,
    rowCount: Int
) -> [TableSandboxShioriRowSource] {
    (0..<rowCount).map { index in
        let group = [
            "context 0 for \(index)",
            "context 1 for \(index)",
            "primary \(index)",
        ]
        return TableSandboxShioriRowSource(
            shiori: Shiori(
                id: Int64(index + 1),
                subtitlePath: subtitlePath,
                subtitleFormat: .ass,
                videoPath: videoPath,
                videoName: "Episode.mkv",
                startMilliseconds: index * 2_000,
                endMilliseconds: index * 2_000 + 1_000,
                cueEventIndex: index * 3 + 2,
                cueDisplayOrder: 2,
                content: group[2],
                isValid: true,
                createdAt: "2026-07-12T00:00:00Z"
            ),
            displayTitle: "Episode",
            dateAddedText: "26-07-12 00:00",
            languages: [.japanese],
            shioriTags: [],
            cuePresentation: ShioriCuePresentation(
                cueID: Int64(index + 1_000),
                cueGroupID: Int64(index + 1),
                primaryGroupIndex: 2,
                cueGroupTexts: group,
                languages: [.japanese],
                speakers: []
            )
        )
    }
}
