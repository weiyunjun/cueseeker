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
}
