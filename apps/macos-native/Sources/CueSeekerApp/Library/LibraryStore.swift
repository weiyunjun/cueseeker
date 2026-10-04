import Foundation
import CueSeekerCore

@MainActor
final class LibraryStore: ObservableObject {
    @Published var libraryStatus: LibraryStatus = .idle
    @Published var libraryVideos: [LibraryVideo] = []
    @Published var libraryFolderGroups: [LibraryFolderGroup] = []
    @Published var libraryPresentationRevision = 0
    @Published var recentWatchingStatus: LibraryStatus = .idle
    @Published var recentWatchingItems: [RecentLibraryWatchingPresentation] = []
    @Published var recentWatchingRevision = 0
    @Published var testRecentWatchingStatus: LibraryStatus = .idle
    @Published var testRecentWatchingItems: [RecentLibraryWatchingPresentation] = []
    @Published var testRecentWatchingRevision = 0
    @Published var completeLibraryStatus: LibraryStatus = .idle
    @Published var completeLibraryFolderSummaries: [CompleteLibraryFolderSummaryPresentation] = []
    @Published var completeLibraryFolderDetailsByPath:
        [String: CompleteLibraryFolderDetailPresentation] = [:]
    @Published var completeLibraryFolderDetailStatusesByPath:
        [String: LibraryStatus] = [:]
    @Published var completeLibraryRevision = 0
    @Published var fileTreeStatus: LibraryStatus = .idle
    @Published var fileTreeRoots: [IndexedContentRoot] = []
    /// The `completeLibraryRevision` the tree above was read at, so the File
    /// segment can tell a current tree from one the library has outgrown.
    var fileTreeLoadedRevision: Int?
    @Published var fileSubfoldersByRootPath: [String: [IndexedContentFolder]] = [:]
    @Published var fileObjectsByFolderPath: [String: [IndexedContentObject]] = [:]
    @Published var fileSubfolderStatusByRootPath: [String: LibraryStatus] = [:]
    @Published var fileObjectStatusByFolderPath: [String: LibraryStatus] = [:]
    @Published var fileTreeRevision = 0

    func fileSubfolders(for rootPath: String) -> [IndexedContentFolder] {
        let standardized = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        return fileSubfoldersByRootPath[rootPath] ?? fileSubfoldersByRootPath[standardized] ?? []
    }

    func fileSubfolderStatus(for rootPath: String) -> LibraryStatus {
        let standardized = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        return fileSubfolderStatusByRootPath[rootPath] ?? fileSubfolderStatusByRootPath[standardized] ?? .idle
    }

    func fileObjects(for folderPath: String) -> [IndexedContentObject] {
        let standardized = URL(fileURLWithPath: folderPath).standardizedFileURL.path
        return fileObjectsByFolderPath[folderPath] ?? fileObjectsByFolderPath[standardized] ?? []
    }

    func fileObjectStatus(for folderPath: String) -> LibraryStatus {
        let standardized = URL(fileURLWithPath: folderPath).standardizedFileURL.path
        return fileObjectStatusByFolderPath[folderPath] ?? fileObjectStatusByFolderPath[standardized] ?? .idle
    }
    @Published var libraryPlaybackHistoryRevision = 0
    @Published var selectedLibraryVideo: LibraryVideo?
    @Published var coverEditingSession: LibraryCoverEditingSession?
    @Published var renameSession: LibraryRenameSession?
    @Published var fileDetailSession: FileDetailDialogSession?
    var libraryPlaybackNavigationVideos: [LibraryVideo] = []

    func applyUserCoverSave(
        _ result: LibraryUserCoverSaveResult,
        target: LibraryUserCoverTarget
    ) {
        switch target {
        case .video(let videoPath):
            let recentItems = recentWatchingItems.map { item in
                item.videoPath == videoPath
                    ? item.replacingCover(
                        path: result.displayCoverPath,
                        revision: result.coverRevision
                    )
                    : item
            }
            if recentItems != recentWatchingItems {
                recentWatchingItems = recentItems
            }

            let testRecentItems = testRecentWatchingItems.map { item in
                item.videoPath == videoPath
                    ? item.replacingCover(
                        path: result.displayCoverPath,
                        revision: result.coverRevision
                    )
                    : item
            }
            if testRecentItems != testRecentWatchingItems {
                testRecentWatchingItems = testRecentItems
            }

            var detailsByPath = completeLibraryFolderDetailsByPath
            for (folderPath, detail) in detailsByPath
            where detail.videos.contains(where: { $0.videoPath == videoPath }) {
                detailsByPath[folderPath] = detail.replacingVideoCover(
                    videoPath: videoPath,
                    coverPath: result.displayCoverPath,
                    coverRevision: result.coverRevision
                )
            }
            if detailsByPath != completeLibraryFolderDetailsByPath {
                completeLibraryFolderDetailsByPath = detailsByPath
            }

        case .folder(let folderPath):
            let summaries = completeLibraryFolderSummaries.map { folder in
                folder.folderPath == folderPath
                    ? folder.replacingCover(
                        path: result.displayCoverPath,
                        revision: result.coverRevision
                    )
                    : folder
            }
            if summaries != completeLibraryFolderSummaries {
                completeLibraryFolderSummaries = summaries
            }
        }
    }
}
