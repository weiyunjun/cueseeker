import Foundation
import CueSeekerCore

protocol LibraryFolderRemovalExecuting: Sendable {
    func removeFolder(_ folder: URL, databaseURL: URL) async throws
}

actor LibraryFolderRemovalExecutor: LibraryFolderRemovalExecuting {
    func removeFolder(_ folder: URL, databaseURL: URL) async throws {
        let database = try SubtitleDatabase(path: databaseURL)
        try database.removeIndexedFolder(folder)
    }
}
