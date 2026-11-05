import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func indexedContentTree() async throws -> [IndexedContentRoot] {
        guard let indexedContentDatabase else {
            throw NSError(
                domain: "CueSeeker.Data",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("status.database_not_initialized")]
            )
        }

        return try await Self.runCancellableDetached(priority: .userInitiated) {
            try indexedContentDatabase.contentTree()
        }
    }

    /// Reads the file tree the Library File segment shows. The tree is only
    /// read when that segment is on screen, and it is re-read once the folder
    /// cards move to a newer revision.
    func hydrateLibraryFileTreeAsync() {
        let revision = library.completeLibraryRevision
        guard library.fileTreeLoadedRevision != revision else {
            return
        }
        if case .loading = library.fileTreeStatus {
            return
        }

        library.fileTreeStatus = .loading
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let roots = try await indexedContentTree()
                library.fileTreeRoots = roots
                library.fileTreeLoadedRevision = revision
                library.fileTreeStatus = .completed
            } catch is CancellationError {
                library.fileTreeStatus = .idle
                return
            } catch {
                library.fileTreeRoots = []
                library.fileTreeLoadedRevision = revision
                library.fileTreeStatus = .failed(Self.errorMessage(for: error))
            }

            // The library moved on while the tree was being read.
            if library.fileTreeLoadedRevision != library.completeLibraryRevision {
                hydrateLibraryFileTreeAsync()
            }
        }
    }

    /// Loads subfolders and root-level direct content objects under a specific root folder on demand.
    func loadFileSubfolders(rootPath: String) {
        let standardized = URL.fromMediaPath(rootPath).mediaPath
        guard let database = indexedContentDatabase else {
            library.fileSubfolderStatusByRootPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }
        if library.fileSubfoldersByRootPath[standardized] == nil {
            let rootURL = URL.fromMediaPath(standardized)
            do {
                let subfolders = try database.subfolders(under: rootURL)
                library.fileSubfoldersByRootPath[standardized] = subfolders
                library.fileSubfolderStatusByRootPath[standardized] = .completed
            } catch {
                library.fileSubfoldersByRootPath[standardized] = []
                library.fileSubfolderStatusByRootPath[standardized] = .failed(Self.errorMessage(for: error))
            }
        }
        loadFileObjects(folderPath: standardized)
    }

    /// Loads objects (videos and subtitles) in a specific folder on demand.
    func loadFileObjects(folderPath: String) {
        let standardized = URL.fromMediaPath(folderPath).mediaPath
        guard let database = indexedContentDatabase else {
            library.fileObjectStatusByFolderPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }
        guard library.fileObjectsByFolderPath[standardized] == nil else {
            return
        }

        do {
            let objects = try database.objects(in: standardized)
            library.fileObjectsByFolderPath[standardized] = objects
            library.fileObjectStatusByFolderPath[standardized] = .completed
        } catch {
            library.fileObjectsByFolderPath[standardized] = []
            library.fileObjectStatusByFolderPath[standardized] = .failed(Self.errorMessage(for: error))
        }
    }

    /// Hydrates subfolders under a specific root folder on demand off the main thread when not yet cached.
    func hydrateFileSubfoldersAsync(rootPath: String) {
        let standardized = URL.fromMediaPath(rootPath).mediaPath
        guard let database = indexedContentDatabase else {
            library.fileSubfolderStatusByRootPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }

        let hasSubfoldersCached = library.fileSubfoldersByRootPath[standardized] != nil
            || library.fileSubfoldersByRootPath[rootPath] != nil
        let hasObjectsCached = library.fileObjectsByFolderPath[standardized] != nil
            || library.fileObjectsByFolderPath[rootPath] != nil

        if hasSubfoldersCached {
            if !hasObjectsCached {
                hydrateFileObjectsAsync(folderPath: standardized)
            }
            return
        }

        guard library.fileSubfolderTasks[standardized] == nil else {
            return
        }

        let revision = library.fileTreeRevision
        library.fileSubfolderStatusByRootPath[standardized] = .loading
        if !hasObjectsCached {
            library.fileObjectStatusByFolderPath[standardized] = .loading
        }

        let rootURL = URL.fromMediaPath(standardized)
        library.fileSubfolderTasks[standardized] = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.library.fileTreeRevision == revision {
                    self.library.fileSubfolderTasks[standardized] = nil
                }
            }

            do {
                let (subfolders, directObjects) = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let loadedSubfolders = try database.subfolders(under: rootURL)
                    let loadedObjects = try database.objects(in: standardized)
                    return (loadedSubfolders, loadedObjects)
                }
                guard !Task.isCancelled, self.library.fileTreeRevision == revision else {
                    return
                }
                self.library.fileSubfoldersByRootPath[standardized] = subfolders
                self.library.fileSubfolderStatusByRootPath[standardized] = .completed
                self.library.fileObjectsByFolderPath[standardized] = directObjects
                self.library.fileObjectStatusByFolderPath[standardized] = .completed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.library.fileTreeRevision == revision else {
                    return
                }
                let message = Self.errorMessage(for: error)
                self.library.fileSubfoldersByRootPath[standardized] = []
                self.library.fileSubfolderStatusByRootPath[standardized] = .failed(message)
                self.library.fileObjectsByFolderPath[standardized] = []
                self.library.fileObjectStatusByFolderPath[standardized] = .failed(message)
            }
        }
    }

    /// Hydrates objects (videos and subtitles) in a specific folder on demand off the main thread when not yet cached.
    func hydrateFileObjectsAsync(folderPath: String) {
        let standardized = URL.fromMediaPath(folderPath).mediaPath
        guard let database = indexedContentDatabase else {
            library.fileObjectStatusByFolderPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }
        guard library.fileObjectsByFolderPath[standardized] == nil,
              library.fileObjectsByFolderPath[folderPath] == nil,
              library.fileObjectTasks[standardized] == nil
        else {
            return
        }

        let revision = library.fileTreeRevision
        library.fileObjectStatusByFolderPath[standardized] = .loading
        library.fileObjectTasks[standardized] = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.library.fileTreeRevision == revision {
                    self.library.fileObjectTasks[standardized] = nil
                }
            }

            do {
                let objects = try await Self.runCancellableDetached(priority: .userInitiated) {
                    try database.objects(in: standardized)
                }
                guard !Task.isCancelled, self.library.fileTreeRevision == revision else {
                    return
                }
                self.library.fileObjectsByFolderPath[standardized] = objects
                self.library.fileObjectStatusByFolderPath[standardized] = .completed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.library.fileTreeRevision == revision else {
                    return
                }
                self.library.fileObjectsByFolderPath[standardized] = []
                self.library.fileObjectStatusByFolderPath[standardized] = .failed(Self.errorMessage(for: error))
            }
        }
    }

    /// Invalidates on-demand file subfolders and objects caches when library data mutates.
    func invalidateFileTreeCache(force: Bool = false) {
        if !force, let held = heldWorkbenchRoute {
            switch held {
            case .fileFolder, .fileFiles:
                fileNeedsReloadAfterIndexedMutation = true
                return
            default:
                break
            }
        }
        for task in library.fileSubfolderTasks.values {
            task.cancel()
        }
        library.fileSubfolderTasks.removeAll(keepingCapacity: false)
        for task in library.fileObjectTasks.values {
            task.cancel()
        }
        library.fileObjectTasks.removeAll(keepingCapacity: false)
        library.fileSubfoldersByRootPath.removeAll(keepingCapacity: false)
        library.fileObjectsByFolderPath.removeAll(keepingCapacity: false)
        library.fileSubfolderStatusByRootPath.removeAll(keepingCapacity: false)
        library.fileObjectStatusByFolderPath.removeAll(keepingCapacity: false)
        library.fileTreeRevision += 1
    }

    func refreshFileOnReappearanceIfNeeded() {
        guard fileNeedsReloadAfterIndexedMutation else {
            return
        }
        fileNeedsReloadAfterIndexedMutation = false
        invalidateFileTreeCache(force: true)
    }
}
