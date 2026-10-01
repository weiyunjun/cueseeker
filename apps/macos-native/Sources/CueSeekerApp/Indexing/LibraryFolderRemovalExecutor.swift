import Foundation
import CueSeekerCore

protocol LibraryFolderRemovalExecuting: Sendable {
    /// Removes a root and what it holds, except what lies in `nestedRoots`,
    /// the groups inside it that stay.
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws
}

actor LibraryFolderRemovalExecutor: LibraryFolderRemovalExecuting {
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws {
        AppPerformanceProbe.breadcrumb("LibraryFolderRemovalExecutor.removeFolder.openingDatabase folder=\(folder.path)")
        let database = try IndexingDatabase(path: databaseURL)
        AppPerformanceProbe.breadcrumb("LibraryFolderRemovalExecutor.removeFolder.removeIndexedFolder.begin")
        try database.removeIndexedFolder(folder, keepingNestedRoots: nestedRoots)
        AppPerformanceProbe.breadcrumb("LibraryFolderRemovalExecutor.removeFolder.removeIndexedFolder.end")
    }
}
