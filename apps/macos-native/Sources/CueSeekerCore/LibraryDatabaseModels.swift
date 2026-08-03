import Foundation

public struct LibraryVideo: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64?
    public let subtitleFileID: Int64?
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat

    public var id: String {
        videoPath
    }

    public init(
        videoFileID: Int64? = nil,
        subtitleFileID: Int64? = nil,
        videoPath: String,
        videoName: String,
        duration: Double?,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat
    ) {
        self.videoFileID = videoFileID
        self.subtitleFileID = subtitleFileID
        self.videoPath = videoPath
        self.videoName = videoName
        self.duration = duration
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
    }
}

public enum LibraryCoverStatus: String, Sendable {
    case generated
    case failed
}

public enum LibraryCoverDisplayProfileVersion: Sendable {
    public static let current = 1
}

public struct LibraryCoverEligibleVideo: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let videoPath: String
    public let videoName: String
    public let fileSize: Int64?
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let folderPath: String
    public let hasUserCover: Bool

    public var id: Int64 {
        videoFileID
    }

    var libraryVideo: LibraryVideo {
        LibraryVideo(
            videoFileID: videoFileID,
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat
        )
    }
}

public struct LibraryVideoCover: Equatable, Sendable {
    public let videoFileID: Int64
    public let masterCoverPath: String
    public let displayCoverPath: String?
    public let displayProfileVersion: Int?
    public let sourceTimeMilliseconds: Int
    public let score: Double?
    public let algorithmVersion: Int
    public let generatedFileSize: Int64?
    public let generatedDuration: Double?
    public let status: LibraryCoverStatus
    public let errorMessage: String?
    public let generatedAt: String
}

public struct LibraryCoverDisplayCandidate: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let videoPath: String
    public let masterCoverPath: String
    public let displayCoverPath: String?
    public let displayProfileVersion: Int?

    public var id: Int64 {
        videoFileID
    }
}

public struct LibraryFolderCover: Equatable, Sendable {
    public let folderPath: String
    public let masterCoverPath: String
    public let sourceVideoFileID: Int64
    public let generatedAt: String
}

public struct LibraryUserCover: Equatable, Sendable {
    public let displayCoverPath: String
    public let revision: String
}

public struct LibraryVideoPresentation: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let subtitleFileID: Int64
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let displayTitle: String
    public let fileExtension: String

    public var id: String {
        videoPath
    }

    public var libraryVideo: LibraryVideo {
        LibraryVideo(
            videoFileID: videoFileID,
            subtitleFileID: subtitleFileID,
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat
        )
    }
}

public struct LibraryFolderPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let videos: [LibraryVideoPresentation]

    public var id: String {
        folderPath
    }
}

public struct LibraryPlaybackHistory: Equatable, Sendable {
    public let videoPath: String
    public let positionMilliseconds: Int
    public let duration: Double?
    public let startedAt: String?
    public let completedAt: String?
    public let updatedAt: String
}

public struct SubtitlePlaybackFinishMetadata: Equatable, Sendable {
    public let primaryStyles: [String]
    public let primaryStyleLastEndMilliseconds: Int?
    public let lastSubtitleEndMilliseconds: Int?

    public init(
        primaryStyles: [String],
        primaryStyleLastEndMilliseconds: Int?,
        lastSubtitleEndMilliseconds: Int?
    ) {
        self.primaryStyles = primaryStyles
        self.primaryStyleLastEndMilliseconds = primaryStyleLastEndMilliseconds
        self.lastSubtitleEndMilliseconds = lastSubtitleEndMilliseconds
    }

    public func finishPointMilliseconds(videoDuration: Double) -> Int? {
        guard videoDuration.isFinite, videoDuration > 0 else {
            return nil
        }

        let videoDurationMilliseconds = Int((videoDuration * 1_000).rounded(.down))
        let thresholdMilliseconds = videoDuration * 1_000 * 0.8

        if let primaryStyleLastEndMilliseconds,
           Double(primaryStyleLastEndMilliseconds) >= thresholdMilliseconds {
            return primaryStyleLastEndMilliseconds
        }

        if let lastSubtitleEndMilliseconds,
           Double(lastSubtitleEndMilliseconds) >= thresholdMilliseconds {
            return lastSubtitleEndMilliseconds
        }

        return videoDurationMilliseconds
    }

    public static func finishPointMilliseconds(
        metadata: SubtitlePlaybackFinishMetadata?,
        videoDuration: Double
    ) -> Int? {
        guard videoDuration.isFinite, videoDuration > 0 else {
            return nil
        }

        guard let metadata else {
            return Int((videoDuration * 1_000).rounded(.down))
        }

        return metadata.finishPointMilliseconds(videoDuration: videoDuration)
    }
}

public enum LibraryWatchState: String, Equatable, Hashable, Sendable {
    case unwatched
    case watching
    case finished

    public init(positionMilliseconds: Int, duration _: Double?) {
        self = max(0, positionMilliseconds) > 0 ? .watching : .unwatched
    }

    public init(
        positionMilliseconds: Int,
        duration _: Double?,
        startedAt: String?,
        completedAt: String?
    ) {
        if completedAt != nil {
            self = .finished
            return
        }

        if startedAt != nil {
            self = .watching
            return
        }

        self = .unwatched
    }
}

public enum SubtitleSearchWatchStateFilter: String, Equatable, Sendable {
    case all
    case onlyFinished
    case watchingAndFinished

    var states: [LibraryWatchState] {
        switch self {
        case .all:
            []
        case .onlyFinished:
            [.finished]
        case .watchingAndFinished:
            [.watching, .finished]
        }
    }
}

public struct RecentLibraryWatchingPresentation: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let subtitleFileID: Int64
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let displayTitle: String
    public let fileExtension: String
    public let folderPath: String
    public let folderTitle: String
    public let episodeNumber: Int
    public let positionMilliseconds: Int
    public let playbackDuration: Double?
    public let startedAt: String?
    public let completedAt: String?
    public let updatedAt: String
    public let coverPath: String?
    public let coverRevision: String?

    public var id: String {
        videoPath
    }

    public var libraryVideo: LibraryVideo {
        LibraryVideo(
            videoFileID: videoFileID,
            subtitleFileID: subtitleFileID,
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat
        )
    }

    public var watchState: LibraryWatchState {
        LibraryWatchState(
            positionMilliseconds: positionMilliseconds,
            duration: playbackDuration ?? duration,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }

    public func replacingCover(path: String, revision: String) -> Self {
        Self(
            videoFileID: videoFileID,
            subtitleFileID: subtitleFileID,
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat,
            displayTitle: displayTitle,
            fileExtension: fileExtension,
            folderPath: folderPath,
            folderTitle: folderTitle,
            episodeNumber: episodeNumber,
            positionMilliseconds: positionMilliseconds,
            playbackDuration: playbackDuration,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            coverPath: path,
            coverRevision: revision
        )
    }
}

public struct CompleteLibraryVideoPresentation: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let subtitleFileID: Int64
    public let videoPath: String
    public let videoName: String
    public let fileSize: Int64?
    public let videoCodec: String?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let frameRate: Double?
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let displayTitle: String
    public let fileExtension: String
    public let episodeNumber: Int
    public let positionMilliseconds: Int
    public let playbackDuration: Double?
    public let startedAt: String?
    public let completedAt: String?
    public let historyUpdatedAt: String?
    public let coverPath: String?
    public let coverRevision: String?

    public var id: String {
        videoPath
    }

    public var libraryVideo: LibraryVideo {
        LibraryVideo(
            videoFileID: videoFileID,
            subtitleFileID: subtitleFileID,
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat
        )
    }

    public var watchState: LibraryWatchState {
        LibraryWatchState(
            positionMilliseconds: positionMilliseconds,
            duration: playbackDuration ?? duration,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }

    public func replacingCover(path: String, revision: String) -> Self {
        Self(
            videoFileID: videoFileID,
            subtitleFileID: subtitleFileID,
            videoPath: videoPath,
            videoName: videoName,
            fileSize: fileSize,
            videoCodec: videoCodec,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            frameRate: frameRate,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat,
            displayTitle: displayTitle,
            fileExtension: fileExtension,
            episodeNumber: episodeNumber,
            positionMilliseconds: positionMilliseconds,
            playbackDuration: playbackDuration,
            startedAt: startedAt,
            completedAt: completedAt,
            historyUpdatedAt: historyUpdatedAt,
            coverPath: path,
            coverRevision: revision
        )
    }
}

public struct CompleteLibraryFolderSummaryPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let coverPath: String?
    public let coverRevision: String?
    public let episodeCount: Int

    public var id: String {
        folderPath
    }

    public func replacingCover(path: String, revision: String) -> Self {
        Self(
            folderPath: folderPath,
            folderTitle: folderTitle,
            coverPath: path,
            coverRevision: revision,
            episodeCount: episodeCount
        )
    }
}

public struct CompleteLibraryFolderDetailPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let videos: [CompleteLibraryVideoPresentation]

    public var id: String {
        folderPath
    }

    public func replacingVideoCover(
        videoPath: String,
        coverPath: String,
        coverRevision: String
    ) -> Self {
        Self(
            folderPath: folderPath,
            folderTitle: folderTitle,
            videos: videos.map { video in
                video.videoPath == videoPath
                    ? video.replacingCover(path: coverPath, revision: coverRevision)
                    : video
            }
        )
    }
}

public struct CompleteLibraryFolderPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let folderCoverPath: String?
    public let folderCoverRevision: String?
    public let lastWatchedEpisodeNumber: Int?
    public let lastWatchedVideoPath: String?
    public let videos: [CompleteLibraryVideoPresentation]

    public var id: String {
        folderPath
    }

    public var continueWatchingVideo: CompleteLibraryVideoPresentation? {
        lastWatchedVideoPath.flatMap { videoPath in
            videos.first { $0.videoPath == videoPath }
        }
            ?? videos.first { $0.watchState == .unwatched }
            ?? videos.first
    }
}
