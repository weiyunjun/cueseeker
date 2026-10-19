import Foundation

public struct FileDetailVideoInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let fileSize: Int64
    public let duration: Double?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let frameRate: Double?
    public let videoCodec: String?
    public let audioTracks: [VideoAudioTrack]
    public let subtitles: [VideoSubtitle]
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(
        path: String,
        name: String,
        fileSize: Int64,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        audioTracks: [VideoAudioTrack],
        subtitles: [VideoSubtitle],
        createdAt: Date?,
        modifiedAt: Date?
    ) {
        self.path = path
        self.name = name
        self.fileSize = fileSize
        self.duration = duration
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.frameRate = frameRate
        self.videoCodec = videoCodec
        self.audioTracks = audioTracks
        self.subtitles = subtitles
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct FileDetailSubtitleInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let fileSize: Int64
    public let format: SubtitleFormat
    public let encoding: String
    public let cueCount: Int
    public let associatedVideoPath: String?
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(
        path: String,
        name: String,
        fileSize: Int64,
        format: SubtitleFormat,
        encoding: String,
        cueCount: Int,
        associatedVideoPath: String?,
        createdAt: Date?,
        modifiedAt: Date?
    ) {
        self.path = path
        self.name = name
        self.fileSize = fileSize
        self.format = format
        self.encoding = encoding
        self.cueCount = cueCount
        self.associatedVideoPath = associatedVideoPath
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

extension LibraryDatabase {
    public func fileDetailVideoInfo(for videoPath: String) throws -> FileDetailVideoInfo? {
        let statement = try database.prepare(
            """
            SELECT vf.path, vf.video_name, vf.file_size, vf.duration,
                   vf.video_width, vf.video_height, vf.frame_rate,
                   vf.video_codec, vf.audio_tracks, vf.modified_at
            FROM video_files vf
            WHERE vf.path = ?;
            """
        )
        try statement.bind(videoPath, at: 1)
        guard try statement.step() else {
            return nil
        }
        let path = statement.stringColumn(0)
        let name = statement.stringColumn(1)
        let dbFileSize = statement.nullableInt64Column(2) ?? 0
        let duration = statement.nullableDoubleColumn(3)
        let videoWidth = statement.nullableIntColumn(4)
        let videoHeight = statement.nullableIntColumn(5)
        let frameRate = statement.nullableDoubleColumn(6)
        let videoCodec = statement.nullableStringColumn(7)
        let tracks = statement.nullableStringColumn(8)
            .flatMap { try? JSONDecoder().decode([VideoAudioTrack].self, from: Data($0.utf8)) }
            ?? []
        let modifiedAtSec = statement.nullableDoubleColumn(9)
        let dbModifiedDate = modifiedAtSec.map { Date(timeIntervalSince1970: $0) }

        let fileURL = URL.fromMediaPath(path)
        let attributes = (path.isWebDAVPath || path.isSMBPath)
            ? nil
            : (try? FileManager.default.attributesOfItem(atPath: path))
        let createdDate = attributes?[.creationDate] as? Date
        let modifiedDate = (attributes?[.modificationDate] as? Date) ?? dbModifiedDate
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? dbFileSize

        let subtitles = (try? videoSubtitles(forVideoFile: fileURL))?.subtitles ?? []

        return FileDetailVideoInfo(
            path: path,
            name: name,
            fileSize: fileSize,
            duration: duration,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            frameRate: frameRate,
            videoCodec: videoCodec,
            audioTracks: tracks,
            subtitles: subtitles,
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )
    }

    public func fileDetailSubtitleInfo(for subtitlePath: String) throws -> FileDetailSubtitleInfo? {
        let statement = try database.prepare(
            """
            SELECT sf.id, sf.subtitle_path, sf.format, sf.file_size, sf.modified_at,
                   vf.path AS video_path
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf
              ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        guard try statement.step() else {
            return nil
        }
        let subtitleFileID = statement.int64Column(0)
        let path = statement.stringColumn(1)
        let format = SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt
        let dbFileSize = statement.nullableInt64Column(3) ?? 0
        let dbModifiedDate = statement.nullableDoubleColumn(4).map { Date(timeIntervalSince1970: $0) }
        let videoPath = statement.nullableStringColumn(5)

        let cueStatement = try database.prepare(
            """
            SELECT COUNT(*)
            FROM subtitle_cue_lines
            WHERE subtitle_file_id = ?;
            """
        )
        try cueStatement.bind(subtitleFileID, at: 1)
        let cueCount = try cueStatement.step() ? cueStatement.intColumn(0) : 0

        let attributes = (path.isWebDAVPath || path.isSMBPath)
            ? nil
            : (try? FileManager.default.attributesOfItem(atPath: path))
        let createdDate = attributes?[.creationDate] as? Date
        let modifiedDate = (attributes?[.modificationDate] as? Date) ?? dbModifiedDate
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? dbFileSize

        let subtitleURL = URL.fromMediaPath(path)
        let encoding: String
        if let data = try? WebDAVSubtitleCache.shared.readSubtitleData(from: subtitleURL) {
            encoding = SubtitleTextDecoder.detectedEncodingName(in: data)
        } else {
            encoding = "UTF-8"
        }

        return FileDetailSubtitleInfo(
            path: path,
            name: subtitleURL.lastPathComponent,
            fileSize: fileSize,
            format: format,
            encoding: encoding,
            cueCount: cueCount,
            associatedVideoPath: videoPath,
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )
    }
}
