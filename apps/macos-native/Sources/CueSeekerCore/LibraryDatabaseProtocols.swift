import Foundation

public protocol PlaybackVideoMetadataPersistence: Sendable {
    func libraryVideos(under folders: [URL]) throws -> [LibraryVideo]

    func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?
    ) throws
}

public protocol LibraryCoverPersistence: Sendable {
    func libraryCoverEligibleVideos(under folders: [URL]) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverDisplayCandidates(under folders: [URL]) throws -> [LibraryCoverDisplayCandidate]
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
