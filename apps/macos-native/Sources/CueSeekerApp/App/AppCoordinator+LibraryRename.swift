import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    // MARK: - The dialog

    func requestFolderRename(_ folder: IndexedContentFolder) {
        library.renameSession = LibraryRenameSession(folder: folder)
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

    /// Hands the queue the runner it cannot build itself: the check that the
    /// video is not playing, the two stages against the indexing database,
    /// and the page refresh once the paths have moved.
    func configureRenameRunner() {
        tasks.runRename = { [weak self] request, onStage in
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
        let (database, playingVideoPath) = await MainActor.run {
            (coordinator.indexingDatabase, coordinator.currentPlaybackVideoPath)
        }
        if let playingVideoPath, request.involves(videoPath: playingVideoPath) {
            throw LibraryRenameRefusal.videoPlaying
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

    /// The paths moved: the root list follows a renamed root, and every page
    /// is refreshed the way an Index that touched these folders refreshes it.
    private func applyCompletedRename(_ plan: LibraryRenamePlan) {
        if case .folder = plan.request, let step = plan.steps.first {
            indexing.replaceFolderPathPrefix(step.oldPath, with: step.newPath)
            _ = search.updateFolderScope(indexing.selectedFolders)
        }

        var result = SubtitleIndexingResult()
        result.affectedFolderPaths = plan.affectedFolderPaths
        applyPublishedIndexMutation(result, shioriFallbackFolders: [])
    }
}
