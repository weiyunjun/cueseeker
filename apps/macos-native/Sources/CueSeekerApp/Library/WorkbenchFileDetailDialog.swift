import AppKit
import CueSeekerCore
import SwiftUI

@MainActor
final class FileDetailDialogSession: ObservableObject, Identifiable {
    enum DetailKind {
        case video(FileDetailVideoInfo)
        case subtitle(FileDetailSubtitleInfo)
    }

    let id = UUID()
    let kind: DetailKind

    init(kind: DetailKind) {
        self.kind = kind
    }

    var fileName: String {
        switch kind {
        case .video(let info):
            return info.name
        case .subtitle(let info):
            return info.name
        }
    }

    var icon: AppIcon {
        switch kind {
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

    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L("file_detail.title"))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    fileHeaderRow

                    switch session.kind {
                    case .video(let videoInfo):
                        videoContent(videoInfo)
                    case .subtitle(let subtitleInfo):
                        subtitleContent(subtitleInfo)
                    }
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
                .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .frame(
            maxHeight: max(
                100,
                availableSize.height
                    - WorkbenchControlMetrics.redesignDialogTopPadding
                    - WorkbenchControlMetrics.redesignDialogInset
            )
        )
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .background(WorkbenchRedesignColors.bgDialog)
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignDialogCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignDialogCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderDivider,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .workbenchDialogCloseButton(closesOnEscape: true, onClose: onClose)
    }

    // MARK: - File Header Row

    private var fileHeaderRow: some View {
        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchCardIcon(
                icon: session.icon,
                size: WorkbenchControlMetrics.redesignDetailFileIconContainerSize
            )

            Text(session.fileName)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: 2 * WorkbenchControlMetrics.redesignDetailFileTitleLineHeight,
                    alignment: .leading
                )
        }
    }

    // MARK: - Video Content

    @ViewBuilder
    private func videoContent(_ info: FileDetailVideoInfo) -> some View {
        // Video Section
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

        // Audio Sections (split into Audio #1, Audio #2...)
        if info.audioTracks.isEmpty {
            SettingsGroup(title: "\(L("file_detail.audio")) #1") {
                FileDetailRow(label: L("file_detail.codec"), value: L("file_detail.none"))
            }
        } else {
            ForEach(Array(info.audioTracks.enumerated()), id: \.offset) { index, track in
                SettingsGroup(title: "\(L("file_detail.audio")) #\(index + 1)") {
                    audioTrackRows(track)
                }
            }
        }

        // Subtitles Section (#1, #2...)
        SettingsGroup(title: L("file_detail.subtitles")) {
            if info.subtitles.isEmpty {
                FileDetailRow(label: "#1", value: L("file_detail.none"), isIndex: true)
            } else {
                ForEach(Array(info.subtitles.enumerated()), id: \.offset) { index, subtitle in
                    if index > 0 {
                        SettingsRowDivider()
                    }
                    FileDetailRow(
                        label: "#\(index + 1)",
                        value: URL.fromMediaPath(subtitle.subtitlePath).lastPathComponent,
                        isIndex: true
                    )
                }
            }
        }

        // File Details Section
        fileDetailsSection(
            path: info.path,
            fileSize: info.fileSize,
            createdAt: info.createdAt,
            modifiedAt: info.modifiedAt
        )
    }

    @ViewBuilder
    private func audioTrackRows(_ track: VideoAudioTrack) -> some View {
        var hasRow = false

        if let codec = track.codec?.trimmingCharacters(in: .whitespacesAndNewlines), !codec.isEmpty {
            FileDetailRow(label: L("file_detail.codec"), value: codec.uppercased())
            let _ = (hasRow = true)
        }

        if let channels = Self.channelsText(track.channels) {
            if hasRow { SettingsRowDivider() }
            FileDetailRow(label: L("file_detail.channels"), value: channels)
            let _ = (hasRow = true)
        }

        if let sampleRate = Self.sampleRateText(track.sampleRate) {
            if hasRow { SettingsRowDivider() }
            FileDetailRow(label: L("file_detail.sample_rate"), value: sampleRate)
            let _ = (hasRow = true)
        }

        if let bitDepth = Self.audioBitDepthText(track.bitDepth) {
            if hasRow { SettingsRowDivider() }
            FileDetailRow(label: L("file_detail.bit_depth"), value: bitDepth)
            let _ = (hasRow = true)
        }

        if let lang = Self.languageText(track.language) {
            if hasRow { SettingsRowDivider() }
            FileDetailRow(label: L("file_detail.language"), value: lang)
            let _ = (hasRow = true)
        }

        if let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if hasRow { SettingsRowDivider() }
            FileDetailRow(label: L("file_detail.track_title"), value: title)
            let _ = (hasRow = true)
        }

        if !hasRow {
            FileDetailRow(label: L("file_detail.codec"), value: "-")
        }
    }

    // MARK: - Subtitle Content

    @ViewBuilder
    private func subtitleContent(_ info: FileDetailSubtitleInfo) -> some View {
        // Subtitle Specifications
        SettingsGroup(title: L("file_detail.subtitle_specs")) {
            FileDetailRow(label: L("file_detail.encoding"), value: info.encoding)
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.raw_lines"),
                value: String.localizedStringWithFormat(L("file_detail.lines_count"), Int64(info.rawCueCount))
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.valid_lines"),
                value: String.localizedStringWithFormat(L("file_detail.lines_count"), Int64(info.cueCount))
            )
        }

        // Associated Video Section
        SettingsGroup(title: L("file_detail.video")) {
            if let videoPath = info.associatedVideoPath, !videoPath.isEmpty {
                FileDetailRow(
                    label: "#1",
                    value: URL.fromMediaPath(videoPath).lastPathComponent,
                    isIndex: true
                )
            } else {
                FileDetailRow(label: "#1", value: L("file_detail.none"), isIndex: true)
            }
        }

        // File Details Section
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
        createdAt: Date?,
        modifiedAt: Date?
    ) -> some View {
        SettingsGroup(title: L("file_detail.file_details")) {
            FileDetailRow(label: L("file_detail.file_size"), value: Self.fileSizeText(fileSize))
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.format"), value: Self.fileFormatText(path: path))
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
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func dateText(_ date: Date?) -> String {
        guard let date else { return "-" }
        return Self.detailDateFormatter.string(from: date)
    }

    static func durationText(_ duration: Double?) -> String {
        guard let duration, duration > 0 else { return "-" }
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func resolutionText(width: Int?, height: Int?) -> String {
        guard let width, let height, width > 0, height > 0 else { return "-" }
        return "\(width) × \(height)"
    }

    static func frameRateText(_ fps: Double?) -> String {
        guard let fps, fps > 0 else { return "-" }
        let rounded = (fps * 1000).rounded() / 1000
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) fps"
        } else {
            return String(format: "%.3f fps", fps)
        }
    }

    static func bitrateText(fileSize: Int64, duration: Double?) -> String {
        guard let duration, duration > 0, fileSize > 0 else { return "-" }
        let bps = Double(fileSize * 8) / duration
        let kbps = Int((bps / 1000).rounded())
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedKbps = formatter.string(from: NSNumber(value: kbps)) ?? "\(kbps)"
        return "\(formattedKbps) kbps"
    }

    static func codecText(_ codec: String?) -> String {
        guard let codec = codec?.trimmingCharacters(in: .whitespacesAndNewlines), !codec.isEmpty else {
            return "-"
        }
        let lower = codec.lowercased()
        if lower.contains("hevc") || lower.contains("h265") || lower.contains("h.265") {
            return "HEVC / H.265"
        }
        if lower.contains("h264") || lower.contains("avc") || lower.contains("h.264") {
            return "H.264 / AVC"
        }
        if lower.contains("av1") {
            return "AV1"
        }
        if lower.contains("vp9") {
            return "VP9"
        }
        return codec.uppercased()
    }

    static func bitDepthText(_ bitDepth: Int?) -> String {
        guard let bitDepth, bitDepth > 0 else { return "-" }
        return "\(bitDepth) bit"
    }

    static func pixelFormatText(_ pixelFormat: String?) -> String {
        guard let trimmed = pixelFormat?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return "-"
        }
        return trimmed
    }

    static func channelsText(_ channels: Int?) -> String? {
        guard let channels, channels > 0 else { return nil }
        return "\(channels)ch"
    }

    static func sampleRateText(_ sampleRate: Int?) -> String? {
        guard let sampleRate, sampleRate > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formatted = formatter.string(from: NSNumber(value: sampleRate)) ?? "\(sampleRate)"
        return "\(formatted) Hz"
    }

    static func audioBitDepthText(_ bitDepth: Int?) -> String? {
        guard let bitDepth, bitDepth > 0 else { return nil }
        return "\(bitDepth) bit"
    }

    static func languageText(_ languageCode: String?) -> String? {
        guard let trimmed = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let locale = AppLocalization.locale
        let localized = locale.localizedString(forLanguageCode: trimmed)
            ?? locale.localizedString(forIdentifier: trimmed)
        if let localized = localized?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localized.isEmpty {
            return localized
        }
        return trimmed
    }

    static func fileFormatText(path: String) -> String {
        let ext = URL.fromMediaPath(path).pathExtension.lowercased()
        switch ext {
        case "mkv": return "Matroska Video (.mkv)"
        case "mp4": return "MPEG-4 Video (.mp4)"
        case "mov": return "QuickTime Movie (.mov)"
        case "avi": return "AVI Video (.avi)"
        case "webm": return "WebM Video (.webm)"
        case "ass": return "Advanced SubStation Alpha (.ass)"
        case "ssa": return "SubStation Alpha (.ssa)"
        case "srt": return "SubRip Subtitle (.srt)"
        case "vtt": return "WebVTT Subtitle (.vtt)"
        default: return ext.isEmpty ? "-" : "\(ext.uppercased()) (.\(ext))"
        }
    }
}

// MARK: - Reusable File Detail Row

struct FileDetailRow: View {
    let label: String
    let value: String
    var isIndex: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            Text(label)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .frame(
                    minWidth: isIndex
                        ? WorkbenchControlMetrics.redesignDetailIndexLabelMinWidth
                        : WorkbenchControlMetrics.redesignDetailLabelMinWidth,
                    alignment: .leading
                )

            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing4)

            Text(value)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .monospacedDigit()
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        .padding(.vertical, WorkbenchControlMetrics.redesignSettingsRowVerticalPadding)
        .frame(minHeight: WorkbenchControlMetrics.redesignSettingsRowMinHeight)
    }
}
