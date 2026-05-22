import Foundation
import CueSeekerCore

@MainActor
final class LibraryStore: ObservableObject {
    @Published var libraryStatus: LibraryStatus = .idle
    @Published var libraryVideos: [LibraryVideo] = []
    @Published var libraryFolderGroups: [LibraryFolderGroup] = []
    @Published var libraryPresentationRevision = 0
    @Published var selectedLibraryVideo: LibraryVideo?
}
