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

    /// Pre-hydrates subfolders for all selected root folders so Level 2 displays instantly.
    func hydrateFileRootsAsync() {
        let folders = indexing.selectedFolders
        guard !folders.isEmpty, let database = indexedContentDatabase else {
            return
        }

        for rootURL in folders {
            let rootPath = rootURL.standardizedFileURL.path
            guard library.fileSubfoldersByRootPath[rootPath] == nil,
                  library.fileSubfolderStatusByRootPath[rootPath] != .loading
            else {
                continue
            }
            library.fileSubfolderStatusByRootPath[rootPath] = .loading

            Task { [weak self] in
                guard let self else { return }
                do {
                    let subfolders = try await Self.runCancellableDetached(priority: .userInitiated) {
                        try database.subfolders(under: rootURL)
                    }
                    guard !Task.isCancelled else { return }
                    self.library.fileSubfoldersByRootPath[rootPath] = subfolders
                    self.library.fileSubfolderStatusByRootPath[rootPath] = .completed
                } catch is CancellationError {
                    self.library.fileSubfolderStatusByRootPath[rootPath] = .idle
                } catch {
                    self.library.fileSubfoldersByRootPath[rootPath] = []
                    self.library.fileSubfolderStatusByRootPath[rootPath] = .failed(Self.errorMessage(for: error))
                }
            }
        }
    }

    /// Hydrates subfolders under a specific root folder on demand.
    func hydrateFileSubfoldersAsync(rootPath: String) {
        let standardized = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        guard let database = indexedContentDatabase else {
            library.fileSubfolderStatusByRootPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }
        guard library.fileSubfoldersByRootPath[standardized] == nil,
              library.fileSubfolderStatusByRootPath[standardized] != .loading
        else {
            return
        }

        library.fileSubfolderStatusByRootPath[standardized] = .loading
        let rootURL = URL(fileURLWithPath: standardized)
        Task { [weak self] in
            guard let self else { return }
            do {
                let subfolders = try await Self.runCancellableDetached(priority: .userInitiated) {
                    try database.subfolders(under: rootURL)
                }
                guard !Task.isCancelled else { return }
                self.library.fileSubfoldersByRootPath[standardized] = subfolders
                self.library.fileSubfolderStatusByRootPath[standardized] = .completed
            } catch is CancellationError {
                self.library.fileSubfolderStatusByRootPath[standardized] = .idle
            } catch {
                self.library.fileSubfoldersByRootPath[standardized] = []
                self.library.fileSubfolderStatusByRootPath[standardized] = .failed(Self.errorMessage(for: error))
            }
        }
    }

    /// Hydrates objects (videos and subtitles) in a specific folder on demand.
    func hydrateFileObjectsAsync(folderPath: String) {
        let standardized = URL(fileURLWithPath: folderPath).standardizedFileURL.path
        guard let database = indexedContentDatabase else {
            library.fileObjectStatusByFolderPath[standardized] = .failed(L("status.database_not_initialized"))
            return
        }
        guard library.fileObjectsByFolderPath[standardized] == nil,
              library.fileObjectStatusByFolderPath[standardized] != .loading
        else {
            return
        }

        library.fileObjectStatusByFolderPath[standardized] = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                let objects = try await Self.runCancellableDetached(priority: .userInitiated) {
                    try database.objects(in: standardized)
                }
                guard !Task.isCancelled else { return }
                self.library.fileObjectsByFolderPath[standardized] = objects
                self.library.fileObjectStatusByFolderPath[standardized] = .completed
            } catch is CancellationError {
                self.library.fileObjectStatusByFolderPath[standardized] = .idle
            } catch {
                self.library.fileObjectsByFolderPath[standardized] = []
                self.library.fileObjectStatusByFolderPath[standardized] = .failed(Self.errorMessage(for: error))
            }
        }
    }

    /// Invalidates on-demand file subfolders and objects caches when library data mutates.
    func invalidateFileTreeCache() {
        library.fileSubfoldersByRootPath.removeAll(keepingCapacity: false)
        library.fileObjectsByFolderPath.removeAll(keepingCapacity: false)
        library.fileSubfolderStatusByRootPath.removeAll(keepingCapacity: false)
        library.fileObjectStatusByFolderPath.removeAll(keepingCapacity: false)
        library.fileTreeRevision += 1
    }
}
