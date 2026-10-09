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

    /// Loads subfolders under a specific root folder on demand.
    func loadFileSubfolders(rootPath: String) {
        let standardized = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        guard let database = indexedContentDatabase else {
            library.fileSubfolderStatusByRootPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }
        guard library.fileSubfoldersByRootPath[standardized] == nil else {
            return
        }

        let rootURL = URL(fileURLWithPath: standardized)
        do {
            let subfolders = try database.subfolders(under: rootURL)
            library.fileSubfoldersByRootPath[standardized] = subfolders
            library.fileSubfolderStatusByRootPath[standardized] = .completed
        } catch {
            library.fileSubfoldersByRootPath[standardized] = []
            library.fileSubfolderStatusByRootPath[standardized] = .failed(Self.errorMessage(for: error))
        }
    }

    /// Loads objects (videos and subtitles) in a specific folder on demand.
    func loadFileObjects(folderPath: String) {
        let standardized = URL(fileURLWithPath: folderPath).standardizedFileURL.path
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

    /// Hydrates subfolders under a specific root folder on demand.
    func hydrateFileSubfoldersAsync(rootPath: String) {
        loadFileSubfolders(rootPath: rootPath)
    }

    /// Hydrates objects (videos and subtitles) in a specific folder on demand.
    func hydrateFileObjectsAsync(folderPath: String) {
        loadFileObjects(folderPath: folderPath)
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
