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
    var libraryPlaybackNavigationVideos: [LibraryVideo] = []
}
