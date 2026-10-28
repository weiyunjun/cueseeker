import AppKit
import CueSeekerCore
import SwiftUI

@MainActor
final class FileDetailDialogSession: ObservableObject, Identifiable {
    enum DetailKind {
        case folder(FileDetailFolderInfo)
        case video(FileDetailVideoInfo)
        case subtitle(FileDetailSubtitleInfo)
    }

    let id = UUID()
    let kind: DetailKind

    init(kind: DetailKind) {
        self.kind = kind
    }

    var dialogTitle: String {
        switch kind {
        case .folder:
            return L("file_detail.folder_title")
        case .video, .subtitle:
            return L("file_detail.title")
        }
    }

    var fileName: String {
        switch kind {
        case .folder(let info):
            return info.name
        case .video(let info):
            return info.name
        case .subtitle(let info):
            return info.name
        }
    }

    var icon: AppIcon {
        switch kind {
        case .folder(let info):
            return FileFolderGroupingResolver.folderIcon(forFolderPath: info.path)
        case .video:
            return .video
        case .subtitle:
            return .subtitles
        }
    }
}

struct WorkbenchFileDetailDialog: View {
    @ObservedObject var session: FileDetailDialogSession
    let onClose: () -> Void

    var body: some View {
        WorkbenchDetailDialogContainer(
            dialogTitle: session.dialogTitle,
            icon: session.icon,
            headerTitle: session.fileName,
            onClose: onClose
        ) {
            switch session.kind {
            case .folder(let folderInfo):
                folderContent(folderInfo)
            case .video(let videoInfo):
                videoContent(videoInfo)
            case .subtitle(let subtitleInfo):
                subtitleContent(subtitleInfo)
            }
        }
    }

    // MARK: - Folder Content

    @ViewBuilder
    private func folderContent(_ info: FileDetailFolderInfo) -> some View {
        SettingsGroup(title: L("file_detail.section.folder_info")) {
            FileDetailRow(
                label: L("file_detail.path"),
                value: RemoteAddressParser.decodedDisplayAddress(info.path)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.folder_count"),
                value: "\(info.folderCount)"
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.video_count"),
                value: "\(info.videoCount)"
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.subtitle_count"),
                value: "\(info.subtitleCount)"
            )
        }

        SettingsGroup(title: L("file_detail.section.index_info")) {
            FileDetailRow(
                label: L("file_detail.added"),
                value: Self.dateText(info.addedAt)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.updated"),
                value: Self.dateText(info.updatedAt)
            )
        }
    }

    // MARK: - Video Content

    @ViewBuilder
    private func videoContent(_ info: FileDetailVideoInfo) -> some View {
        SettingsGroup(title: L("file_detail.video")) {
            FileDetailRow(
                label: L("file_detail.resolution"),
                value: Self.resolutionText(width: info.videoWidth, height: info.videoHeight)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.frame_rate"),
                value: Self.frameRateText(info.frameRate)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.codec"),
                value: Self.codecText(info.videoCodec)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.bit_depth"),
                value: Self.bitDepthText(info.videoBitDepth)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.pixel_format"),
                value: Self.pixelFormatText(info.videoPixelFormat)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.bitrate"),
                value: Self.bitrateText(fileSize: info.fileSize, duration: info.duration)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.duration"),
                value: Self.durationText(info.duration)
            )
        }

        let validAudioTracks = Self.validAudioTrackPropertyGroups(for: info.audioTracks)
        ForEach(Array(validAudioTracks.enumerated()), id: \.offset) { index, items in
            SettingsGroup(title: "\(L("file_detail.audio")) #\(index + 1)") {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    if itemIndex > 0 {
                        SettingsRowDivider()
                    }
                    FileDetailRow(label: L(item.labelKey), value: item.value)
                }
            }
        }

        SettingsGroup(title: L("file_detail.subtitles")) {
            WorkbenchDetailIndexedRows(
                values: info.subtitles.map { URL.fromMediaPath($0.subtitlePath).lastPathComponent }
            )
        }

        fileDetailsSection(
            path: info.path,
            fileSize: info.fileSize,
            containerFormat: info.containerFormat,
            createdAt: info.createdAt,
            modifiedAt: info.modifiedAt
        )
    }

    static func validAudioTrackPropertyGroups(
        for tracks: [VideoAudioTrack]
    ) -> [[MediaDetailPropertyItem]] {
        let locale = AppLocalization.locale
        return tracks
            .map { MediaDetailFormatter.audioTrackProperties(for: $0, locale: locale) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Subtitle Content

    @ViewBuilder
    private func subtitleContent(_ info: FileDetailSubtitleInfo) -> some View {
        SettingsGroup(title: L("file_detail.subtitle_specs")) {
            FileDetailRow(label: L("file_detail.encoding"), value: info.encoding)
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.raw_lines"),
                value: "\(info.rawCueCount)"
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.valid_lines"),
                value: "\(info.cueCount)"
            )
        }

        SettingsGroup(title: L("file_detail.associated_video")) {
            let videoNames: [String] = {
                guard let videoPath = info.associatedVideoPath, !videoPath.isEmpty else { return [] }
                return [URL.fromMediaPath(videoPath).lastPathComponent]
            }()
            WorkbenchDetailIndexedRows(values: videoNames)
        }

        fileDetailsSection(
            path: info.path,
            fileSize: info.fileSize,
            createdAt: info.createdAt,
            modifiedAt: info.modifiedAt
        )
    }

    // MARK: - File Details Common Section

    private func fileDetailsSection(
        path: String,
        fileSize: Int64,
        containerFormat: String? = nil,
        createdAt: Date?,
        modifiedAt: Date?
    ) -> some View {
        SettingsGroup(title: L("file_detail.file_details")) {
            FileDetailRow(label: L("file_detail.file_size"), value: Self.fileSizeText(fileSize))
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.format"),
                value: Self.fileFormatText(path: path, containerFormat: containerFormat)
            )
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.path"), value: path)
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.created"), value: Self.dateText(createdAt))
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.modified"), value: Self.dateText(modifiedAt))
        }
    }

    // MARK: - Format Helpers

    static func fileSizeText(_ bytes: Int64) -> String {
        MediaDetailFormatter.fileSizeText(bytes)
    }

    static func dateText(_ date: Date?) -> String {
        MediaDetailFormatter.dateText(date)
    }

    static func durationText(_ duration: Double?) -> String {
        MediaDetailFormatter.durationText(duration)
    }

    static func resolutionText(width: Int?, height: Int?) -> String {
        MediaDetailFormatter.resolutionText(width: width, height: height)
    }

    static func frameRateText(_ fps: Double?) -> String {
        MediaDetailFormatter.frameRateText(fps)
    }

    static func bitrateText(fileSize: Int64, duration: Double?) -> String {
        MediaDetailFormatter.bitrateText(fileSize: fileSize, duration: duration)
    }

    static func codecText(_ codec: String?) -> String {
        MediaDetailFormatter.codecText(codec)
    }

    static func bitDepthText(_ bitDepth: Int?) -> String {
        MediaDetailFormatter.bitDepthText(bitDepth)
    }

    static func pixelFormatText(_ pixelFormat: String?) -> String {
        MediaDetailFormatter.pixelFormatText(pixelFormat)
    }

    static func channelsText(_ channels: Int?) -> String? {
        MediaDetailFormatter.channelsText(channels)
    }

    static func sampleRateText(_ sampleRate: Int?) -> String? {
        MediaDetailFormatter.sampleRateText(sampleRate)
    }

    static func audioBitDepthText(_ bitDepth: Int?) -> String? {
        MediaDetailFormatter.audioBitDepthText(bitDepth)
    }

    static func languageText(_ languageCode: String?) -> String? {
        MediaDetailFormatter.languageText(languageCode, locale: AppLocalization.locale)
    }

    static func fileFormatText(path: String, containerFormat: String? = nil) -> String {
        MediaDetailFormatter.fileFormatText(path: path, containerFormat: containerFormat)
    }
}
