import Foundation
import CueSeekerCore

protocol LibraryFolderRemovalExecuting: Sendable {
    /// Removes a root and what it holds, except what lies in `nestedRoots`,
    /// the groups inside it that stay. Answers whether any indexed content
    /// rows were removed.
    @discardableResult
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws -> Bool
}

actor LibraryFolderRemovalExecutor: LibraryFolderRemovalExecuting {
    @discardableResult
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws -> Bool {
        let database = try IndexingDatabase(path: databaseURL)
        return try database.removeIndexedFolder(folder, keepingNestedRoots: nestedRoots)
    }
}
