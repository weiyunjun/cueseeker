import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    // MARK: - The dialog

    func requestFolderRename(_ folder: IndexedContentFolder) {
        library.renameSession = LibraryRenameSession(folder: folder)
    }

    func requestRootFolderRename(_ url: URL) {
        library.renameSession = LibraryRenameSession(rootFolder: url)
    }

    func requestFileGroupRename(_ object: IndexedContentObject) {
        guard let session = LibraryRenameSession(object: object) else {
            return
        }
        library.renameSession = session
    }

    /// Queues the rename the dialog holds and closes it. The dialog has
    /// already applied the name rules; the disk and the database are checked
    /// by the task itself when it starts.
    func confirmRename(_ session: LibraryRenameSession) {
        guard session.validate() else {
            return
        }
        tasks.enqueueRename(
            session.request,
            oldPaths: session.oldPaths,
            newPaths: session.newPaths
        )
        library.renameSession = nil
    }

    func closeRenameDialog() {
        library.renameSession = nil
    }

    // MARK: - The task

    /// Hands the queue the runner it cannot build itself: the two stages
    /// against the indexing database and the page refresh once the paths move.
    func configureRenameRunner() {
        tasks.runRename = { [weak self] request, onStage in
            await AppCoordinator.waitForDebugTaskDelay()
            try await AppCoordinator.runRename(request, onStage: onStage, coordinator: self)
        }
    }

    nonisolated private static func runRename(
        _ request: LibraryRenameRequest,
        onStage: @escaping @Sendable (TaskRenameStage) -> Void,
        coordinator: AppCoordinator?
    ) async throws {
        guard let coordinator else {
            throw CancellationError()
        }
        let database = await MainActor.run {
            coordinator.indexingDatabase
        }
        guard let database else {
            throw LibraryRenameError.databaseUpdateFailed(L("status.database_not_initialized"))
        }

        let renamer = LibraryRenamer(database: database)
        let plan = try await Task.detached(priority: .userInitiated) {
            try renamer.checkConflicts(request)
        }.value
        onStage(.renaming)
        try await Task.detached(priority: .userInitiated) {
            try renamer.perform(plan)
        }.value
        await MainActor.run {
            coordinator.applyCompletedRename(plan)
        }
    }

    /// The paths moved: the root list, File routes, facet filters, and resident
    /// page states follow the new paths in place without a full re-search.
    private func applyCompletedRename(_ plan: LibraryRenamePlan) {
        if case .folder = plan.request, let step = plan.steps.first {
            indexing.replaceFolderPathPrefix(step.oldPath, with: step.newPath)
            _ = search.updateFolderScope(indexing.selectedFolders)
        }
        workbenchLayout.rewriteFolderPaths(plan.steps)
        heldWorkbenchRoute = heldWorkbenchRoute?.rewritingFolderPaths(plan.steps)

        settings.rewriteFacetFilterFolderPaths(plan.steps)
        search.applyRename(plan.steps, databaseURL: databaseURL)
        settings.searchFacetFilter = search.searchFacetFilter
        applyRenameToExcerpt(plan.steps)

        invalidateFileTreeCache(force: true)
        switch workbenchLayout.currentRoute {
        case .fileFolder(let rootPath):
            loadFileSubfolders(rootPath: rootPath)
        case .fileFiles(let rootPath, let folderPath):
            loadFileSubfolders(rootPath: rootPath)
            loadFileObjects(folderPath: folderPath)
        default:
            break
        }

        let folders = indexing.selectedFolders
        var updatedLibrary = false
        var updatedRecentWatching = false
        var updatedTestRecentWatching = false
        var updatedCompleteLibrary = false
        if let libraryDatabase {
            if let snapshot = try? libraryDatabase.libraryPresentation(under: folders) {
                libraryTask?.cancel()
                applyLibraryPresentation(snapshot)
                library.libraryStatus = .completed
                updatedLibrary = true
            }
            if let snapshot = try? libraryDatabase.recentLibraryWatching(under: folders) {
                recentWatchingTask?.cancel()
                applyRecentWatching(snapshot)
                library.recentWatchingStatus = .completed
                updatedRecentWatching = true
            }
            if library.testRecentWatchingStatus != .idle || !library.testRecentWatchingItems.isEmpty,
               let snapshot = try? libraryDatabase.recentLibraryWatching(
                   under: folders,
                   limit: Int.max,
                   includesNeverPlayed: true
               ) {
                testRecentWatchingTask?.cancel()
                applyTestRecentWatching(snapshot)
                library.testRecentWatchingStatus = .completed
                updatedTestRecentWatching = true
            }
            if let snapshot = try? libraryDatabase.completeLibraryFolderSummaries(under: folders) {
                completeLibraryTask?.cancel()
                applyCompleteLibrary(snapshot)
                library.completeLibraryStatus = .completed
                updatedCompleteLibrary = true
            }
        }
        if !updatedLibrary {
            refreshLibrary(force: true)
        }
        if !updatedRecentWatching {
            refreshRecentWatching(force: true)
        }
        if !updatedTestRecentWatching {
            refreshLoadedTestRecentWatching(force: true)
        }
        if !updatedCompleteLibrary {
            refreshCompleteLibrary(force: true)
        }
    }
}
