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
    @Published var libraryPlaybackHistoryRevision = 0
    @Published var selectedLibraryVideo: LibraryVideo?
    @Published var coverEditingSession: LibraryCoverEditingSession?
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
