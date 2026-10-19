import Foundation

public protocol PlaybackVideoMetadataPersistence: Sendable {
    func libraryVideos(under folders: [URL]) throws -> [LibraryVideo]

    func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        audioTracks: [VideoAudioTrack]
    ) throws
}

public protocol LibraryCoverPersistence: Sendable {
    func libraryCoverEligibleVideos(under folders: [URL]) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverEligibleVideos(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverEligibleVideos(
        inFolderPaths folderPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverDisplayCandidates(under folders: [URL]) throws -> [LibraryCoverDisplayCandidate]
    func libraryCoverDisplayCandidates(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverDisplayCandidate]
    func libraryVideoCover(forVideoFileID videoFileID: Int64) throws -> LibraryVideoCover?

    func upsertLibraryVideoCover(
        videoFileID: Int64,
        masterCoverPath: String,
        displayCoverPath: String?,
        displayProfileVersion: Int?,
        sourceTimeMilliseconds: Int,
        score: Double?,
        algorithmVersion: Int,
        generatedFileSize: Int64?,
        generatedDuration: Double?,
        status: LibraryCoverStatus,
        errorMessage: String?
    ) throws

    func updateLibraryVideoDisplayCover(
        videoFileID: Int64,
        displayCoverPath: String?,
        displayProfileVersion: Int?
    ) throws

    func upsertLibraryFolderCover(
        folderPath: String,
        masterCoverPath: String,
        sourceVideoFileID: Int64
    ) throws

    func deleteLibraryFolderCover(folderPath: String) throws
}

public extension LibraryCoverPersistence {
    func libraryCoverEligibleVideos(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo] {
        let folders = Set(
            videoPaths.map {
                URL.fromMediaPath($0).deletingLastPathComponent()
            }
        )
        return try libraryCoverEligibleVideos(under: Array(folders))
            .filter { videoPaths.contains($0.videoPath) }
    }

    func libraryCoverEligibleVideos(
        inFolderPaths folderPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo] {
        let resolvedFolderPaths = Set(folderPaths.map { path -> String in
            let url = URL.fromMediaPath(path)
            return (url.isWebDAVURL || url.isSMBURL) ? url.mediaPath : url.resolvingSymlinksInPath().path
        })
        return try libraryCoverEligibleVideos(
            under: folderPaths.map(URL.fromMediaPath)
        ).filter {
            let url = URL.fromMediaPath($0.folderPath)
            let candidatePath = (url.isWebDAVURL || url.isSMBURL) ? url.mediaPath : url.resolvingSymlinksInPath().path
            return resolvedFolderPaths.contains(candidatePath)
        }
    }

    func libraryCoverDisplayCandidates(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverDisplayCandidate] {
        let folders = Set(
            videoPaths.map {
                URL.fromMediaPath($0).deletingLastPathComponent()
            }
        )
        return try libraryCoverDisplayCandidates(under: Array(folders))
            .filter { videoPaths.contains($0.videoPath) }
    }

    func upsertLibraryVideoCover(
        videoFileID: Int64,
        masterCoverPath: String,
        sourceTimeMilliseconds: Int,
        score: Double?,
        algorithmVersion: Int,
        generatedFileSize: Int64?,
        generatedDuration: Double?,
        status: LibraryCoverStatus,
        errorMessage: String?
    ) throws {
        try upsertLibraryVideoCover(
            videoFileID: videoFileID,
            masterCoverPath: masterCoverPath,
            displayCoverPath: nil,
            displayProfileVersion: nil,
            sourceTimeMilliseconds: sourceTimeMilliseconds,
            score: score,
            algorithmVersion: algorithmVersion,
            generatedFileSize: generatedFileSize,
            generatedDuration: generatedDuration,
            status: status,
            errorMessage: errorMessage
        )
    }
}

extension LibraryCoverDatabase: LibraryCoverPersistence {}
extension LibraryDatabase: PlaybackVideoMetadataPersistence {}
