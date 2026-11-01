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
    public let videoBitDepth: Int?
    public let videoPixelFormat: String?
    public let containerFormat: String?
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
        videoBitDepth: Int? = nil,
        videoPixelFormat: String? = nil,
        containerFormat: String? = nil,
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
        self.videoBitDepth = videoBitDepth
        self.videoPixelFormat = videoPixelFormat
        self.containerFormat = containerFormat
        self.audioTracks = audioTracks
        self.subtitles = subtitles.sorted { lhs, rhs in
            VideoSubtitles.compareSubtitles(
                lhsSubtitlePath: lhs.subtitlePath,
                lhsFormat: lhs.format,
                rhsSubtitlePath: rhs.subtitlePath,
                rhsFormat: rhs.format,
                forVideoPath: path
            )
        }
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
    public let rawCueCount: Int
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
        rawCueCount: Int = 0,
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
        self.rawCueCount = rawCueCount
        self.associatedVideoPath = associatedVideoPath
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct FileDetailFolderInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let isRootFolder: Bool
    public let folderCount: Int
    public let videoCount: Int
    public let subtitleCount: Int
    public let addedAt: Date?
    public let updatedAt: Date?

    public init(
        path: String,
        name: String,
        isRootFolder: Bool,
        folderCount: Int,
        videoCount: Int,
        subtitleCount: Int,
        addedAt: Date?,
        updatedAt: Date?
    ) {
        self.path = path
        self.name = name
        self.isRootFolder = isRootFolder
        self.folderCount = folderCount
        self.videoCount = videoCount
        self.subtitleCount = subtitleCount
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}

public enum FileDetailPairedItem: Equatable, Sendable, Identifiable {
    case video(FileDetailVideoInfo)
    case subtitle(FileDetailSubtitleInfo)

    public var id: String {
        switch self {
        case .video(let info):
            return "video:\(info.path)"
        case .subtitle(let info):
            return "subtitle:\(info.path)"
        }
    }

    public var path: String {
        switch self {
        case .video(let info):
            return info.path
        case .subtitle(let info):
            return info.path
        }
    }

    public var name: String {
        switch self {
        case .video(let info):
            return info.name
        case .subtitle(let info):
            return info.name
        }
    }

    public var isVideo: Bool {
        if case .video = self {
            return true
        }
        return false
    }
}

extension LibraryDatabase {
    public func fileDetailVideoInfo(for videoPath: String) throws -> FileDetailVideoInfo? {
        let statement = try database.prepare(
            """
            SELECT vf.path, vf.video_name, vf.file_size, vf.duration,
                   vf.video_width, vf.video_height, vf.frame_rate,
                   vf.video_codec, vf.video_bit_depth, vf.video_pixel_format,
                   vf.container_format, vf.audio_tracks, vf.modified_at
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
        let videoBitDepth = statement.nullableIntColumn(8)
        let videoPixelFormat = statement.nullableStringColumn(9)
        let containerFormat = statement.nullableStringColumn(10)
        let tracks = statement.nullableStringColumn(11)
            .flatMap { try? JSONDecoder().decode([VideoAudioTrack].self, from: Data($0.utf8)) }
            ?? []
        let modifiedAtSec = statement.nullableDoubleColumn(12)
        let dbModifiedDate = modifiedAtSec.map { Date(timeIntervalSince1970: $0) }

        let fileURL = URL.fromMediaPath(path)
        let attributes = path.isRemoteMediaPath
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
            videoBitDepth: videoBitDepth,
            videoPixelFormat: videoPixelFormat,
            containerFormat: containerFormat,
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
                   sf.raw_cue_count, vf.path AS video_path
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
        let dbRawCueCount = statement.nullableIntColumn(5)
        let videoPath = statement.nullableStringColumn(6)

        let cueStatement = try database.prepare(
            """
            SELECT COUNT(*)
            FROM subtitle_cue_lines
            WHERE subtitle_file_id = ?;
            """
        )
        try cueStatement.bind(subtitleFileID, at: 1)
        let cueCount = try cueStatement.step() ? cueStatement.intColumn(0) : 0

        let attributes = path.isRemoteMediaPath
            ? nil
            : (try? FileManager.default.attributesOfItem(atPath: path))
        let createdDate = attributes?[.creationDate] as? Date
        let modifiedDate = (attributes?[.modificationDate] as? Date) ?? dbModifiedDate
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? dbFileSize

        let subtitleURL = URL.fromMediaPath(path)
        let encoding: String
        let fallbackRawCueCount: Int?
        if let data = try? WebDAVSubtitleCache.shared.readSubtitleData(from: subtitleURL) {
            encoding = SubtitleTextDecoder.detectedEncodingName(in: data)
            if dbRawCueCount == nil,
               let contents = try? SubtitleTextDecoder.decode(data, format: format) {
                fallbackRawCueCount = SubtitleRawCueCounter.count(in: contents, format: format)
            } else {
                fallbackRawCueCount = nil
            }
        } else {
            encoding = "-"
            fallbackRawCueCount = nil
        }

        let rawCueCount = dbRawCueCount ?? fallbackRawCueCount ?? cueCount

        return FileDetailSubtitleInfo(
            path: path,
            name: subtitleURL.lastPathComponent,
            fileSize: fileSize,
            format: format,
            encoding: encoding,
            cueCount: cueCount,
            rawCueCount: rawCueCount,
            associatedVideoPath: videoPath,
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )
    }

    public func fileDetailPairedItems(forVideoPath videoPath: String) throws -> [FileDetailPairedItem] {
        guard let videoInfo = try fileDetailVideoInfo(for: videoPath) else {
            return []
        }
        var items: [FileDetailPairedItem] = [.video(videoInfo)]
        for subtitle in videoInfo.subtitles {
            if let subtitleInfo = try fileDetailSubtitleInfo(for: subtitle.subtitlePath) {
                items.append(.subtitle(subtitleInfo))
            }
        }
        return items
    }

    public func fileDetailPairedItems(forSubtitlePath subtitlePath: String) throws -> [FileDetailPairedItem] {
        guard let targetSubtitleInfo = try fileDetailSubtitleInfo(for: subtitlePath) else {
            return []
        }
        if let videoPath = targetSubtitleInfo.associatedVideoPath,
           !videoPath.isEmpty,
           let videoInfo = try fileDetailVideoInfo(for: videoPath) {
            var items: [FileDetailPairedItem] = [.video(videoInfo)]
            var includedTarget = false
            for subtitle in videoInfo.subtitles {
                if subtitle.subtitlePath == targetSubtitleInfo.path {
                    items.append(.subtitle(targetSubtitleInfo))
                    includedTarget = true
                } else if let subtitleInfo = try fileDetailSubtitleInfo(for: subtitle.subtitlePath) {
                    items.append(.subtitle(subtitleInfo))
                }
            }
            if !includedTarget {
                items.append(.subtitle(targetSubtitleInfo))
            }
            return items
        }
        return [.subtitle(targetSubtitleInfo)]
    }

    public func fileDetailFolderInfo(
        for folderPath: String,
        name: String? = nil,
        isRootFolder: Bool
    ) throws -> FileDetailFolderInfo {
        let (standardizedPath, defaultName, variants, pathPrefixes) = Self.folderScopeStrings(for: folderPath)
        let resolvedName = name ?? defaultName

        var folderCount = 0
        var videoCount = 0
        var subtitleCount = 0

        if !pathPrefixes.isEmpty {
            let scopeCondition = pathPrefixes.map { _ in
                "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)"
            }.joined(separator: " OR ")

            if isRootFolder {
                let folderCountExpression: String
                if variants.isEmpty {
                    folderCountExpression = "COALESCE(CAST(vf.folder_id AS TEXT), rtrim(substr(vf.path, 1, length(vf.path) - length(vf.video_name)), '/'))"
                } else {
                    let variantPlaceholders = variants.map { _ in "?" }.joined(separator: ", ")
                    folderCountExpression = """
                    CASE
                        WHEN rtrim(substr(vf.path, 1, length(vf.path) - length(vf.video_name)), '/') IN (\(variantPlaceholders))
                        THEN NULL
                        ELSE COALESCE(CAST(vf.folder_id AS TEXT), rtrim(substr(vf.path, 1, length(vf.path) - length(vf.video_name)), '/'))
                    END
                    """
                }
                let statement = try database.prepare(
                    """
                    SELECT COUNT(DISTINCT \(folderCountExpression)),
                           COUNT(DISTINCT vf.id),
                           COUNT(DISTINCT sf.id)
                    FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
                    JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                    JOIN video_files vf ON vf.id = m.video_file_id
                    WHERE (\(scopeCondition));
                    """
                )
                var bindIndex: Int32 = 1
                for variant in variants {
                    try statement.bind(variant, at: bindIndex)
                    bindIndex += 1
                }
                for prefix in pathPrefixes {
                    try statement.bind(prefix, at: bindIndex)
                    bindIndex += 1
                    try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                    bindIndex += 1
                }
                if try statement.step() {
                    folderCount = statement.intColumn(0)
                    videoCount = statement.intColumn(1)
                    subtitleCount = statement.intColumn(2)
                }
            } else if !variants.isEmpty {
                let variantPlaceholders = variants.map { _ in "?" }.joined(separator: ", ")
                let statement = try database.prepare(
                    """
                    SELECT COUNT(DISTINCT vf.id),
                           COUNT(DISTINCT sf.id)
                    FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
                    JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                    JOIN video_files vf ON vf.id = m.video_file_id
                    WHERE (\(scopeCondition))
                      AND rtrim(substr(vf.path, 1, length(vf.path) - length(vf.video_name)), '/') IN (\(variantPlaceholders));
                    """
                )
                var bindIndex: Int32 = 1
                for prefix in pathPrefixes {
                    try statement.bind(prefix, at: bindIndex)
                    bindIndex += 1
                    try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                    bindIndex += 1
                }
                for variant in variants {
                    try statement.bind(variant, at: bindIndex)
                    bindIndex += 1
                }
                if try statement.step() {
                    videoCount = statement.intColumn(0)
                    subtitleCount = statement.intColumn(1)
                }
            }
        }

        let (addedAt, updatedAt) = try folderDetailTimestamps(
            variants: variants,
            pathPrefixes: pathPrefixes,
            isRootFolder: isRootFolder
        )

        return FileDetailFolderInfo(
            path: standardizedPath,
            name: resolvedName,
            isRootFolder: isRootFolder,
            folderCount: folderCount,
            videoCount: videoCount,
            subtitleCount: subtitleCount,
            addedAt: addedAt,
            updatedAt: updatedAt
        )
    }
}

public struct MediaDetailPropertyItem: Equatable, Sendable {
    public let labelKey: String
    public let value: String

    public init(labelKey: String, value: String) {
        self.labelKey = labelKey
        self.value = value
    }
}

public enum MediaDetailFormatter {
    private static let videoCodecMappings: [(tokens: [String], displayName: String)] = [
        (["hevc", "h265", "h.265"], "HEVC / H.265"),
        (["h264", "avc", "h.264"], "H.264 / AVC"),
        (["av1"], "AV1"),
        (["vp9"], "VP9"),
        (["vp8"], "VP8"),
        (["mpeg4"], "MPEG-4"),
        (["mpeg2video", "mpeg2"], "MPEG-2"),
        (["mpeg1video", "mpeg1"], "MPEG-1"),
        (["prores"], "ProRes"),
        (["wmv3", "wmv2", "wmv1"], "WMV"),
        (["vc1"], "VC-1"),
        (["theora"], "Theora"),
        (["rv40", "rv30"], "RealVideo")
    ]

    private static let audioCodecMappings: [(tokens: [String], displayName: String)] = [
        (["flac"], "FLAC"),
        (["aac", "aac_latm"], "AAC"),
        (["opus"], "Opus"),
        (["vorbis"], "Vorbis"),
        (["mp3", "mp3float"], "MP3"),
        (["mp2", "mp2float"], "MP2"),
        (["alac"], "ALAC"),
        (["ac3", "ac-3"], "AC-3"),
        (["eac3", "e-ac-3"], "E-AC-3"),
        (["truehd"], "TrueHD"),
        (["mlp"], "MLP"),
        (["dts", "dca"], "DTS"),
        (["wmav1", "wmav2", "wmapro", "wmalossless"], "WMA"),
        (["amr_nb", "amr_wb"], "AMR")
    ]

    private static let fileFormatDisplayNames: [String: String] = [
        "mkv": "Matroska Video (.mkv)",
        "mp4": "MPEG-4 Video (.mp4)",
        "webm": "WebM Video (.webm)",
        "flv": "Flash Video (.flv)",
        "avi": "AVI Video (.avi)",
        "mov": "QuickTime Movie (.mov)",
        "ts": "MPEG Transport Stream (.ts)",
        "m2ts": "BDAV MPEG-2 Transport Stream (.m2ts)",
        "mts": "AVCHD MPEG-2 Transport Stream (.mts)",
        "m4v": "MPEG-4 Video (.m4v)",
        "rmvb": "RealMedia Variable Bitrate (.rmvb)",
        "rm": "RealMedia (.rm)",
        "wmv": "Windows Media Video (.wmv)",
        "mpg": "MPEG Program Stream (.mpg)",
        "mpeg": "MPEG Program Stream (.mpeg)",
        "vob": "DVD Video Object (.vob)",
        "asf": "Advanced Systems Format (.asf)",
        "f4v": "Flash MP4 Video (.f4v)",
        "ogv": "Ogg Video (.ogv)",
        "3gp": "3GPP Multimedia (.3gp)",
        "ass": "Advanced SubStation Alpha (.ass)",
        "ssa": "SubStation Alpha (.ssa)",
        "srt": "SubRip Subtitle (.srt)",
        "vtt": "WebVTT Subtitle (.vtt)"
    ]

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static func trimTrailingFractionZeros(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var result = text
        while result.hasSuffix("0") {
            result.removeLast()
        }
        if result.hasSuffix(".") {
            result.removeLast()
        }
        return result
    }

    public static func fileSizeText(_ bytes: Int64) -> String {
        FileSizeFormatter.format(bytes: bytes)
    }

    public static func dateText(_ date: Date?) -> String {
        guard let date else { return "-" }
        return detailDateFormatter.string(from: date)
    }

    public static func durationText(_ duration: Double?) -> String {
        guard let duration, duration > 0 else { return "-" }
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public static func resolutionText(width: Int?, height: Int?) -> String {
        guard let width, let height, width > 0, height > 0 else { return "-" }
        return "\(width) × \(height)"
    }

    public static func frameRateText(_ fps: Double?) -> String {
        guard let fps, fps > 0 else { return "-" }
        let rounded = (fps * 1000).rounded() / 1000
        let formatted = trimTrailingFractionZeros(String(format: "%.3f", rounded))
        return "\(formatted) fps"
    }

    public static func bitrateText(fileSize: Int64, duration: Double?) -> String {
        guard let duration, duration > 0, fileSize > 0 else { return "-" }
        let bps = Double(fileSize * 8) / duration
        let kbps = bps / 1000.0
        let roundedKbps = Int(kbps.rounded())
        guard roundedKbps > 0 else { return "-" }
        if roundedKbps >= 1000 {
            let mbps = (kbps / 1000.0 * 100).rounded() / 100
            let formattedMbps = trimTrailingFractionZeros(String(format: "%.2f", mbps))
            return "\(formattedMbps) Mbps"
        }
        return "\(roundedKbps) kbps"
    }

    public static func codecText(_ codec: String?) -> String {
        guard let trimmed = codec?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "-"
        }
        let lower = trimmed.lowercased()
        for mapping in videoCodecMappings where mapping.tokens.contains(where: { lower.contains($0) }) {
            return mapping.displayName
        }
        return trimmed.uppercased()
    }

    public static func audioCodecText(_ codec: String?) -> String? {
        guard let trimmed = codec?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("pcm_") || lower == "pcm" {
            return "PCM"
        }
        for mapping in audioCodecMappings where mapping.tokens.contains(lower) {
            return mapping.displayName
        }
        return trimmed.uppercased()
    }

    public static func bitDepthText(_ bitDepth: Int?) -> String {
        guard let bitDepth, bitDepth > 0 else { return "-" }
        return "\(bitDepth) bit"
    }

    public static func pixelFormatText(_ pixelFormat: String?) -> String {
        guard let trimmed = pixelFormat?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "-"
        }
        let lower = trimmed.lowercased()
        if lower.contains("420")
            || lower.hasPrefix("nv12")
            || lower.hasPrefix("nv21")
            || lower.hasPrefix("p010")
            || lower.hasPrefix("p016") {
            return "YUV 4:2:0"
        }
        if lower.contains("422")
            || lower.hasPrefix("yuyv")
            || lower.hasPrefix("uyvy")
            || lower.hasPrefix("nv16")
            || lower.hasPrefix("p210")
            || lower.hasPrefix("p216")
            || lower.hasPrefix("v210") {
            return "YUV 4:2:2"
        }
        if lower.contains("444")
            || lower.hasPrefix("nv24")
            || lower.hasPrefix("nv42")
            || lower.hasPrefix("p410")
            || lower.hasPrefix("p416")
            || lower.hasPrefix("ayuv")
            || lower.hasPrefix("v410") {
            return "YUV 4:4:4"
        }
        if lower.contains("410") {
            return "YUV 4:1:0"
        }
        if lower.contains("411") {
            return "YUV 4:1:1"
        }
        if lower.contains("440") {
            return "YUV 4:4:0"
        }
        if lower.contains("rgb") || lower.contains("bgr") || lower.contains("gbr") {
            return "RGB"
        }
        if lower.hasPrefix("gray") || lower.hasPrefix("ya8") || lower.hasPrefix("ya16") {
            return "Grayscale"
        }
        return trimmed
    }

    public static func channelsText(
        _ channels: Int?,
        locale: Locale = Locale(identifier: "en")
    ) -> String? {
        guard let channels, channels > 0 else { return nil }
        let id = locale.identifier.lowercased()
        let isTraditionalChinese = id.contains("hant") || id.contains("tw") || id.contains("hk")
        let isSimplifiedChinese = !isTraditionalChinese && id.hasPrefix("zh")

        switch channels {
        case 1:
            if isTraditionalChinese { return "單聲道 (1.0)" }
            if isSimplifiedChinese { return "单声道 (1.0)" }
            return "Mono (1.0)"
        case 2:
            if isTraditionalChinese { return "立體聲 (2.0)" }
            if isSimplifiedChinese { return "立体声 (2.0)" }
            return "Stereo (2.0)"
        case 6:
            if isTraditionalChinese { return "環繞聲 (5.1)" }
            if isSimplifiedChinese { return "环绕声 (5.1)" }
            return "Surround (5.1)"
        case 8:
            if isTraditionalChinese { return "環繞聲 (7.1)" }
            if isSimplifiedChinese { return "环绕声 (7.1)" }
            return "Surround (7.1)"
        default:
            return "\(channels)ch"
        }
    }

    public static func sampleRateText(_ sampleRate: Int?) -> String? {
        guard let sampleRate, sampleRate > 0 else { return nil }
        let khz = (Double(sampleRate) / 1000.0 * 100).rounded() / 100
        let formatted = trimTrailingFractionZeros(String(format: "%.2f", khz))
        return "\(formatted) kHz"
    }

    public static func audioBitDepthText(_ bitDepth: Int?) -> String? {
        guard let bitDepth, bitDepth > 0 else { return nil }
        return "\(bitDepth) bit"
    }

    public static func languageText(_ languageCode: String?, locale: Locale) -> String? {
        guard let trimmed = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let localized = locale.localizedString(forLanguageCode: trimmed)
            ?? locale.localizedString(forIdentifier: trimmed)
        if let localized = localized?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localized.isEmpty {
            return localized
        }
        return trimmed
    }

    public static func fileFormatText(
        path: String,
        containerFormat: String? = nil
    ) -> String {
        let trimmedContainer = containerFormat?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let ext: String
        if let trimmedContainer, !trimmedContainer.isEmpty {
            ext = trimmedContainer
        } else {
            ext = URL.fromMediaPath(path).pathExtension.lowercased()
        }
        if let displayName = fileFormatDisplayNames[ext] {
            return displayName
        }
        return ext.isEmpty ? "-" : "\(ext.uppercased()) (.\(ext))"
    }

    public static func resolvedVideoContainerExtension(
        formatName: String,
        majorBrand: String? = nil,
        videoCodec: String? = nil,
        fallbackExtension: String
    ) -> String {
        let fallback = fallbackExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let formatTokens = Set(
            formatName
                .lowercased()
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        let brand = majorBrand?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let codec = videoCodec?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if formatTokens == ["webm"] {
            return "webm"
        }
        if formatTokens == ["matroska"] {
            return "mkv"
        }
        if formatTokens.contains("matroska") || formatTokens.contains("webm") {
            if fallback == "mkv" || fallback == "webm" {
                return fallback
            }
            if let codec, ["vp8", "vp9", "av1"].contains(codec) {
                return "webm"
            }
            return "mkv"
        }
        if formatTokens.contains("flv") {
            return "flv"
        }
        if formatTokens.contains("avi") {
            return "avi"
        }
        if formatTokens.contains("mpegts") {
            if ["ts", "m2ts", "mts"].contains(fallback) {
                return fallback
            }
            return "ts"
        }
        if formatTokens.contains("mpeg") || formatTokens.contains("vob") {
            if ["mpg", "mpeg", "vob"].contains(fallback) {
                return fallback
            }
            return formatTokens.contains("vob") ? "vob" : "mpg"
        }
        if formatTokens.contains("asf") {
            if ["wmv", "asf"].contains(fallback) {
                return fallback
            }
            return "wmv"
        }
        if formatTokens.contains("rm") {
            if ["rmvb", "rm"].contains(fallback) {
                return fallback
            }
            return "rmvb"
        }
        if formatTokens.contains("ogg") {
            if fallback == "ogv" {
                return fallback
            }
            return "ogv"
        }
        if !formatTokens.isDisjoint(with: ["mov", "mp4", "m4a", "3gp", "3g2", "mj2"]) {
            if let brand, !brand.isEmpty {
                if brand == "qt" {
                    return "mov"
                }
                if ["f4v", "f4p", "f4a", "f4b"].contains(brand) {
                    return "f4v"
                }
                if ["m4v", "m4vh", "m4vp"].contains(brand) {
                    return "m4v"
                }
                if brand.hasPrefix("3gp") || brand.hasPrefix("3g2") {
                    return "3gp"
                }
                if ["isom", "iso2", "mp41", "mp42", "avc1", "dash"].contains(brand) {
                    if ["mp4", "m4v", "f4v"].contains(fallback) {
                        return fallback
                    }
                    return "mp4"
                }
            }
            if ["mp4", "mov", "m4v", "f4v", "3gp"].contains(fallback) {
                return fallback
            }
            return "mp4"
        }

        return fallback
    }

    public static func audioTrackProperties(
        for track: VideoAudioTrack,
        locale: Locale
    ) -> [MediaDetailPropertyItem] {
        var items: [MediaDetailPropertyItem] = []
        if let codec = audioCodecText(track.codec) {
            items.append(MediaDetailPropertyItem(labelKey: "file_detail.codec", value: codec))
        }
        if let channels = channelsText(track.channels, locale: locale) {
            items.append(MediaDetailPropertyItem(labelKey: "file_detail.channels", value: channels))
        }
        if let sampleRate = sampleRateText(track.sampleRate) {
            items.append(MediaDetailPropertyItem(labelKey: "file_detail.sample_rate", value: sampleRate))
        }
        if let bitDepth = audioBitDepthText(track.bitDepth) {
            items.append(MediaDetailPropertyItem(labelKey: "file_detail.bit_depth", value: bitDepth))
        }
        if let lang = languageText(track.language, locale: locale) {
            items.append(MediaDetailPropertyItem(labelKey: "file_detail.language", value: lang))
        }
        if let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            items.append(MediaDetailPropertyItem(labelKey: "file_detail.track_title", value: title))
        }
        return items
    }
}

extension LibraryDatabase {

    private static func folderScopeStrings(
        for folderPath: String
    ) -> (standardizedPath: String, name: String, variants: [String], prefixes: [String]) {
        if folderPath.isRemoteMediaPath {
            let folderURL = URL.fromMediaPath(folderPath).standardizedMediaURL
            let standardizedPath = folderURL.mediaPath
            return (
                standardizedPath,
                folderURL.lastPathComponent,
                MediaFolderPathMatching.folderPathVariants(forPath: standardizedPath),
                MediaFolderPathMatching.folderPathPrefixes(forPath: standardizedPath)
            )
        }
        let normalized = MediaFolderPathMatching.normalizedFolderPath(folderPath)
        let name = (normalized as NSString).lastPathComponent
        return (
            normalized,
            name,
            MediaFolderPathMatching.folderPathVariants(forPath: normalized),
            MediaFolderPathMatching.folderPathPrefixes(forPath: normalized)
        )
    }

    private func folderDetailTimestamps(
        variants: [String],
        pathPrefixes: [String],
        isRootFolder: Bool
    ) throws -> (addedAt: Date?, updatedAt: Date?) {
        guard !variants.isEmpty else {
            return (nil, nil)
        }
        let placeholders = variants.map { _ in "?" }.joined(separator: ", ")

        if isRootFolder {
            let rootStatement = try database.prepare(
                """
                SELECT created_at, updated_at
                FROM library_root_folders
                WHERE path IN (\(placeholders))
                LIMIT 1;
                """
            )
            for (offset, variant) in variants.enumerated() {
                try rootStatement.bind(variant, at: Int32(offset + 1))
            }
            if try rootStatement.step() {
                let created = Self.parseISO8601Date(rootStatement.stringColumn(0))
                let updated = Self.parseISO8601Date(rootStatement.stringColumn(1)) ?? created
                if created != nil || updated != nil {
                    return (created, updated)
                }
            }

            let spStatement = try database.prepare(
                """
                SELECT created_at,
                       COALESCE(NULLIF(last_successful_index_at, ''), NULLIF(updated_at, ''), created_at)
                FROM search_paths
                WHERE path IN (\(placeholders))
                LIMIT 1;
                """
            )
            for (offset, variant) in variants.enumerated() {
                try spStatement.bind(variant, at: Int32(offset + 1))
            }
            if try spStatement.step() {
                let created = Self.parseISO8601Date(spStatement.stringColumn(0))
                let updated = Self.parseISO8601Date(spStatement.stringColumn(1)) ?? created
                return (created, updated)
            }

            let allSearchPaths = try database.prepare(
                """
                SELECT path,
                       created_at,
                       COALESCE(NULLIF(last_successful_index_at, ''), NULLIF(updated_at, ''), created_at)
                FROM search_paths
                ORDER BY LENGTH(path) DESC, id ASC;
                """
            )
            while try allSearchPaths.step() {
                let outerPath = allSearchPaths.stringColumn(0)
                let (_, _, _, outerPrefixes) = Self.folderScopeStrings(for: outerPath)
                if variants.contains(where: { variant in
                    MediaFolderPathMatching.pathMatchesPrefixes(variant, prefixes: outerPrefixes)
                }) {
                    let outerCreated = Self.parseISO8601Date(allSearchPaths.stringColumn(1))
                    let outerUpdated = Self.parseISO8601Date(allSearchPaths.stringColumn(2)) ?? outerCreated
                    let earliestSubtitleIndexed = try earliestSubtitleIndexedDate(
                        pathPrefixes: pathPrefixes
                    )
                    return (earliestSubtitleIndexed ?? outerCreated, outerUpdated)
                }
            }
            return (nil, nil)
        }

        let folderStatement = try database.prepare(
            """
            SELECT lf.id,
                   lf.created_at,
                   lf.updated_at,
                   sp.created_at,
                   COALESCE(NULLIF(sp.last_successful_index_at, ''), NULLIF(sp.updated_at, ''), sp.created_at)
            FROM library_folders lf
            JOIN search_paths sp ON sp.id = lf.library_id
            WHERE rtrim(sp.path || '/' || lf.relative_path, '/') IN (\(placeholders))
            LIMIT 1;
            """
        )
        for (offset, variant) in variants.enumerated() {
            try folderStatement.bind(variant, at: Int32(offset + 1))
        }
        if try folderStatement.step() {
            let folderID = folderStatement.int64Column(0)
            let rawCreated = folderStatement.stringColumn(1)
            let rawUpdated = folderStatement.stringColumn(2)
            let spCreated = Self.parseISO8601Date(folderStatement.stringColumn(3))
            let spUpdated = Self.parseISO8601Date(folderStatement.stringColumn(4)) ?? spCreated

            let created: Date?
            if let parsed = Self.parseISO8601Date(rawCreated) {
                created = parsed
            } else {
                created = try earliestSubtitleIndexedDate(forFolderID: folderID) ?? spCreated
            }

            let updated: Date?
            if let parsed = Self.parseISO8601Date(rawUpdated) {
                updated = parsed
            } else {
                updated = spUpdated ?? created
            }
            return (created, updated)
        }

        let earliest = try earliestSubtitleIndexedDate(pathPrefixes: pathPrefixes)
        return (earliest, earliest)
    }

    private func earliestSubtitleIndexedDate(forFolderID folderID: Int64) throws -> Date? {
        let statement = try database.prepare(
            """
            SELECT MIN(indexed_at)
            FROM subtitle_files
            WHERE folder_id = ? AND indexed_at != '';
            """
        )
        try statement.bind(folderID, at: 1)
        guard try statement.step(),
              let raw = statement.nullableStringColumn(0)
        else {
            return nil
        }
        return Self.parseISO8601Date(raw)
    }

    private func earliestSubtitleIndexedDate(pathPrefixes: [String]) throws -> Date? {
        guard !pathPrefixes.isEmpty else {
            return nil
        }
        let scopeCondition = pathPrefixes.map { _ in
            "(subtitle_path >= ? AND subtitle_path < ?)"
        }.joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT MIN(indexed_at)
            FROM subtitle_files INDEXED BY idx_subtitle_files_subtitle_path
            WHERE (\(scopeCondition)) AND indexed_at != '';
            """
        )
        var bindIndex: Int32 = 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }
        guard try statement.step(),
              let raw = statement.nullableStringColumn(0)
        else {
            return nil
        }
        return Self.parseISO8601Date(raw)
    }

    private static func parseISO8601Date(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }
}
