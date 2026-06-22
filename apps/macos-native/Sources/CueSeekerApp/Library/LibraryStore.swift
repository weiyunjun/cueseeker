import Foundation
import CoreGraphics
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
    @Published var completeLibraryFolders: [CompleteLibraryFolderPresentation] = []
    @Published var completeLibraryRevision = 0
    @Published var completeLibraryExpandedFolderPaths: Set<String> = []
    @Published var completeLibraryScrollOffsetY: CGFloat = 0
    @Published var selectedLibraryVideo: LibraryVideo?
}
