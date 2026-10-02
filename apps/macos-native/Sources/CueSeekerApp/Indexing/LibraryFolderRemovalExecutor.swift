import Foundation
import CueSeekerCore

protocol LibraryFolderRemovalExecuting: Sendable {
    /// Removes a root and what it holds, except what lies in `nestedRoots`,
    /// the groups inside it that stay.
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws
}

actor LibraryFolderRemovalExecutor: LibraryFolderRemovalExecuting {
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws {
        let database = try IndexingDatabase(path: databaseURL)
        try database.removeIndexedFolder(folder, keepingNestedRoots: nestedRoots)
    }
}
