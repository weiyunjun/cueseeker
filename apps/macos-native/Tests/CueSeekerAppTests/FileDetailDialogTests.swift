import AppKit
import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite
@MainActor
struct FileDetailDialogTests {
    @Test
    func fileDetailDialogSessionProperties() {
        let videoInfo = FileDetailVideoInfo(
            path: "/path/to/video.mkv",
            name: "video.mkv",
            fileSize: 1024 * 1024 * 100,
            duration: 120.0,
            videoWidth: 1920,
            videoHeight: 1080,
            frameRate: 23.976,
            videoCodec: "hevc",
            audioTracks: [],
            subtitles: [],
            createdAt: nil,
            modifiedAt: nil
        )

        let session = FileDetailDialogSession(kind: .video(videoInfo))
        #expect(session.fileName == "video.mkv")
        #expect(session.icon == .video)

        let subtitleInfo = FileDetailSubtitleInfo(
            path: "/path/to/sub.ass",
            name: "sub.ass",
            fileSize: 5000,
            format: .ass,
            encoding: "UTF-8",
            cueCount: 42,
            associatedVideoPath: "/path/to/video.mkv",
            createdAt: nil,
            modifiedAt: nil
        )

        let subSession = FileDetailDialogSession(kind: .subtitle(subtitleInfo))
        #expect(subSession.dialogTitle == L("file_detail.title"))
        #expect(subSession.fileName == "sub.ass")
        #expect(subSession.icon == .subtitles)

        let localFolderInfo = FileDetailFolderInfo(
            path: "/Media/Anime",
            name: "Anime",
            isRootFolder: true,
            folderCount: 3,
            videoCount: 24,
            subtitleCount: 48,
            addedAt: nil,
            updatedAt: nil
        )
        let localFolderSession = FileDetailDialogSession(kind: .folder(localFolderInfo))
        #expect(localFolderSession.dialogTitle == L("file_detail.folder_title"))
        #expect(localFolderSession.fileName == "Anime")
        #expect(localFolderSession.icon == .folder)

        let networkFolderInfo = FileDetailFolderInfo(
            path: "smb://nas.local/Media/Anime",
            name: "Anime",
            isRootFolder: true,
            folderCount: 1,
            videoCount: 12,
            subtitleCount: 12,
            addedAt: nil,
            updatedAt: nil
        )
        let networkFolderSession = FileDetailDialogSession(kind: .folder(networkFolderInfo))
        #expect(networkFolderSession.dialogTitle == L("file_detail.folder_title"))
        #expect(networkFolderSession.fileName == "Anime")
        #expect(networkFolderSession.icon == .folderSmb)
    }

    @Test
    func folderDetailDialogSessionAndLocalization() {
        defer {
            AppLocalization.apply(.english)
        }

        AppLocalization.apply(.english)
        #expect(L("file_detail.folder_title") == "Folder Info")
        #expect(L("file_detail.section.folder_info") == "Folder Info")
        #expect(L("file_detail.section.index_info") == "Index Info")
        #expect(L("file_detail.folder_count") == "Folder Count")
        #expect(L("file_detail.video_count") == "Video Count")
        #expect(L("file_detail.subtitle_count") == "Subtitle Count")
        #expect(L("file_detail.added") == "Added")
        #expect(L("file_detail.updated") == "Updated")
        #expect(L("file_detail.subtitles") == "Associated Subtitles")
        #expect(L("file_detail.associated_video") == "Associated Video")
        #expect(L("file_detail.raw_lines") == "Raw Cues")
        #expect(L("file_detail.valid_lines") == "Valid Cues")
        #expect(L("task_detail.indexed_subtitles") == "Subtitle Count")

        AppLocalization.apply(.simplifiedChinese)
        #expect(L("file_detail.get_info") == "查看详情")
        #expect(L("file_detail.folder_title") == "文件夹详情")
        #expect(L("file_detail.section.folder_info") == "文件夹信息")
        #expect(L("file_detail.section.index_info") == "索引信息")
        #expect(L("file_detail.folder_count") == "文件夹数量")
        #expect(L("file_detail.video_count") == "视频数量")
        #expect(L("file_detail.subtitle_count") == "字幕数量")
        #expect(L("file_detail.path") == "位置")
        #expect(L("file_detail.added") == "添加时间")
        #expect(L("file_detail.updated") == "更新时间")
        #expect(L("file_detail.subtitles") == "关联字幕")
        #expect(L("file_detail.associated_video") == "关联视频")
        #expect(L("file_detail.raw_lines") == "原始台词数")
        #expect(L("file_detail.valid_lines") == "有效台词数")
        #expect(L("task_detail.indexed_subtitles") == "字幕数量")

        AppLocalization.apply(.traditionalChinese)
        #expect(L("file_detail.get_info") == "查看詳情")
        #expect(L("file_detail.folder_title") == "資料夾詳情")
        #expect(L("file_detail.section.folder_info") == "資料夾資訊")
        #expect(L("file_detail.section.index_info") == "索引資訊")
        #expect(L("file_detail.folder_count") == "資料夾數量")
        #expect(L("file_detail.video_count") == "影片數量")
        #expect(L("file_detail.subtitle_count") == "字幕數量")
        #expect(L("file_detail.path") == "位置")
        #expect(L("file_detail.added") == "加入時間")
        #expect(L("file_detail.updated") == "更新時間")
        #expect(L("file_detail.subtitles") == "關聯字幕")
        #expect(L("file_detail.associated_video") == "關聯影片")
        #expect(L("file_detail.raw_lines") == "原始台詞數")
        #expect(L("file_detail.valid_lines") == "有效台詞數")
        #expect(L("task_detail.indexed_subtitles") == "字幕數量")
    }

    @Test
    func fileDetailDialogMetricTokens() {
        #expect(WorkbenchControlMetrics.redesignDetailFileIconContainerSize == 40)
        #expect(WorkbenchControlMetrics.redesignDetailFileTitleLineHeight == 20)
        #expect(WorkbenchControlMetrics.redesignDetailLabelMinWidth == 100)
        #expect(WorkbenchControlMetrics.redesignDetailIndexLabelMinWidth == 40)
        #expect(WorkbenchControlMetrics.redesignTaskDetailProgressBarWidth == 140)
        #expect(WorkbenchControlMetrics.redesignDialogWidthXLarge == 720)
        #expect(WorkbenchControlMetrics.redesignDialogInset == 24)
        #expect(WorkbenchControlMetrics.redesignSettingsGroupRadius == 10)
    }

    @Test
    func infoIconResolves() {
        let image = AppIconStore.image(.info, size: 20)
        #expect(image != nil)
    }

    @Test
    func formattingHelpers() {
        #expect(WorkbenchFileDetailDialog.resolutionText(width: 1920, height: 1080) == "1920 × 1080")
        #expect(WorkbenchFileDetailDialog.resolutionText(width: nil, height: 1080) == "-")

        #expect(WorkbenchFileDetailDialog.bitDepthText(8) == "8 bit")
        #expect(WorkbenchFileDetailDialog.bitDepthText(10) == "10 bit")
        #expect(WorkbenchFileDetailDialog.bitDepthText(nil) == "-")

        defer {
            AppLocalization.apply(.english)
        }
        AppLocalization.apply(.english)
        #expect(WorkbenchFileDetailDialog.pixelFormatText("yuv420p") == "YUV 4:2:0")
        #expect(WorkbenchFileDetailDialog.pixelFormatText("yuv420p10le") == "YUV 4:2:0")
        #expect(WorkbenchFileDetailDialog.pixelFormatText("yuv422p10le") == "YUV 4:2:2")
        #expect(WorkbenchFileDetailDialog.pixelFormatText("yuv444p") == "YUV 4:4:4")
        #expect(WorkbenchFileDetailDialog.pixelFormatText("rgb24") == "RGB")
        #expect(WorkbenchFileDetailDialog.pixelFormatText(nil) == "-")

        #expect(WorkbenchFileDetailDialog.channelsText(1) == "Mono (1.0)")
        #expect(WorkbenchFileDetailDialog.channelsText(2) == "Stereo (2.0)")
        #expect(WorkbenchFileDetailDialog.channelsText(6) == "Surround (5.1)")
        #expect(WorkbenchFileDetailDialog.channelsText(8) == "Surround (7.1)")
        #expect(WorkbenchFileDetailDialog.channelsText(nil) == nil)

        #expect(WorkbenchFileDetailDialog.sampleRateText(48_000) == "48 kHz")
        #expect(WorkbenchFileDetailDialog.sampleRateText(44_100) == "44.1 kHz")
        #expect(WorkbenchFileDetailDialog.sampleRateText(22_050) == "22.05 kHz")
        #expect(WorkbenchFileDetailDialog.sampleRateText(nil) == nil)

        #expect(WorkbenchFileDetailDialog.frameRateText(23.9760239) == "23.976 fps")
        #expect(WorkbenchFileDetailDialog.frameRateText(29.97) == "29.97 fps")
        #expect(WorkbenchFileDetailDialog.frameRateText(24.0) == "24 fps")

        #expect(WorkbenchFileDetailDialog.durationText(1422) == "23:42")
        #expect(WorkbenchFileDetailDialog.durationText(3661) == "01:01:01")

        #expect(WorkbenchFileDetailDialog.bitrateText(fileSize: 831_660_000, duration: 1422) == "4.68 Mbps")
        #expect(WorkbenchFileDetailDialog.bitrateText(fileSize: 500_000, duration: 5.0) == "800 kbps")

        #expect(WorkbenchFileDetailDialog.audioBitDepthText(24) == "24 bit")
        #expect(WorkbenchFileDetailDialog.audioBitDepthText(nil) == nil)
        #expect(WorkbenchFileDetailDialog.audioBitDepthText(0) == nil)

        #expect(WorkbenchFileDetailDialog.languageText("eng") == "English")
        #expect(WorkbenchFileDetailDialog.languageText("jpn") == "Japanese")

        AppLocalization.apply(.simplifiedChinese)
        #expect(WorkbenchFileDetailDialog.languageText("eng") == "英语")
        #expect(WorkbenchFileDetailDialog.languageText("jpn") == "日语")
        #expect(WorkbenchFileDetailDialog.channelsText(1) == "单声道 (1.0)")
        #expect(WorkbenchFileDetailDialog.channelsText(2) == "立体声 (2.0)")
        #expect(WorkbenchFileDetailDialog.channelsText(6) == "环绕声 (5.1)")
        #expect(WorkbenchFileDetailDialog.channelsText(8) == "环绕声 (7.1)")

        AppLocalization.apply(.traditionalChinese)
        #expect(WorkbenchFileDetailDialog.channelsText(1) == "單聲道 (1.0)")
        #expect(WorkbenchFileDetailDialog.channelsText(2) == "立體聲 (2.0)")
        #expect(WorkbenchFileDetailDialog.channelsText(6) == "環繞聲 (5.1)")
        #expect(WorkbenchFileDetailDialog.channelsText(8) == "環繞聲 (7.1)")
        AppLocalization.apply(.english)

        // 1000-based decimal file size formatting aligned with File cards
        #expect(WorkbenchFileDetailDialog.fileSizeText(100_000_000) == "100.00 MB")
        #expect(WorkbenchFileDetailDialog.fileSizeText(1_500_000_000) == "1.50 GB")
        #expect(WorkbenchFileDetailDialog.fileSizeText(0) == "0 B")

        // Centralized dictionary mappings in MediaDetailFormatter
        #expect(MediaDetailFormatter.codecText("hevc") == "HEVC / H.265")
        #expect(MediaDetailFormatter.codecText("h264") == "H.264 / AVC")
        #expect(MediaDetailFormatter.codecText("flac") == "FLAC")
        #expect(MediaDetailFormatter.codecText(nil) == "-")
        #expect(MediaDetailFormatter.audioCodecText("pcm_s16le") == "PCM")
        #expect(MediaDetailFormatter.audioCodecText("pcm_s24le") == "PCM")
        #expect(MediaDetailFormatter.audioCodecText("eac3") == "E-AC-3")
        #expect(MediaDetailFormatter.audioCodecText("ac3") == "AC-3")
        #expect(MediaDetailFormatter.audioCodecText("truehd") == "TrueHD")
        #expect(MediaDetailFormatter.audioCodecText("opus") == "Opus")
        #expect(MediaDetailFormatter.audioCodecText("vorbis") == "Vorbis")

        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.mkv") == "Matroska Video (.mkv)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.mp4") == "MPEG-4 Video (.mp4)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.webm") == "WebM Video (.webm)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.flv") == "Flash Video (.flv)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.avi") == "AVI Video (.avi)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.mov") == "QuickTime Movie (.mov)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.ts") == "MPEG Transport Stream (.ts)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.m2ts") == "BDAV MPEG-2 Transport Stream (.m2ts)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.MTS") == "AVCHD MPEG-2 Transport Stream (.mts)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.m4v") == "MPEG-4 Video (.m4v)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.rmvb") == "RealMedia Variable Bitrate (.rmvb)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.rm") == "RealMedia (.rm)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.wmv") == "Windows Media Video (.wmv)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.mpg") == "MPEG Program Stream (.mpg)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.mpeg") == "MPEG Program Stream (.mpeg)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.vob") == "DVD Video Object (.vob)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.asf") == "Advanced Systems Format (.asf)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.f4v") == "Flash MP4 Video (.f4v)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.ogv") == "Ogg Video (.ogv)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.3gp") == "3GPP Multimedia (.3gp)")
        #expect(MediaDetailFormatter.fileFormatText(path: "/Videos/ep01.ass") == "Advanced SubStation Alpha (.ass)")

        // Probed container format overrides disguised extension in File Detail Format row
        #expect(
            MediaDetailFormatter.fileFormatText(
                path: "/Videos/disguised.f4v",
                containerFormat: "flv"
            ) == "Flash Video (.flv)"
        )
        #expect(
            MediaDetailFormatter.fileFormatText(
                path: "/Videos/disguised.mp4",
                containerFormat: "mkv"
            ) == "Matroska Video (.mkv)"
        )
        #expect(
            MediaDetailFormatter.fileFormatText(
                path: "/Videos/disguised.mp4",
                containerFormat: "webm"
            ) == "WebM Video (.webm)"
        )

        // Container family resolution from FFmpeg demuxer format_name + major_brand + videoCodec
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "flv",
                majorBrand: nil,
                fallbackExtension: "f4v"
            ) == "flv"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "matroska",
                majorBrand: nil,
                fallbackExtension: "mp4"
            ) == "mkv"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "webm",
                majorBrand: nil,
                fallbackExtension: "mp4"
            ) == "webm"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "matroska,webm",
                majorBrand: nil,
                videoCodec: "vp9",
                fallbackExtension: "mp4"
            ) == "webm"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "matroska,webm",
                majorBrand: nil,
                videoCodec: "av1",
                fallbackExtension: "flv"
            ) == "webm"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "matroska,webm",
                majorBrand: nil,
                videoCodec: "hevc",
                fallbackExtension: "mp4"
            ) == "mkv"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "matroska,webm",
                majorBrand: nil,
                fallbackExtension: "webm"
            ) == "webm"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "mov,mp4,m4a,3gp,3g2,mj2",
                majorBrand: "isom",
                fallbackExtension: "mkv"
            ) == "mp4"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "mov,mp4,m4a,3gp,3g2,mj2",
                majorBrand: "qt  ",
                fallbackExtension: "mp4"
            ) == "mov"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "mov,mp4,m4a,3gp,3g2,mj2",
                majorBrand: "3gp4",
                fallbackExtension: "mp4"
            ) == "3gp"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "mov,mp4,m4a,3gp,3g2,mj2",
                majorBrand: "M4V ",
                fallbackExtension: "mp4"
            ) == "m4v"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "mpeg",
                majorBrand: nil,
                fallbackExtension: "vob"
            ) == "vob"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "mpegts",
                majorBrand: nil,
                fallbackExtension: "m2ts"
            ) == "m2ts"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "asf",
                majorBrand: nil,
                fallbackExtension: "wmv"
            ) == "wmv"
        )
        #expect(
            MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: "rm",
                majorBrand: nil,
                fallbackExtension: "rmvb"
            ) == "rmvb"
        )

        // Empty audio tracks produce no displayable properties (so Audio #1 card is omitted)
        let emptyTrack = VideoAudioTrack(
            language: nil,
            title: nil,
            codec: "",
            channels: nil,
            sampleRate: nil,
            bitDepth: nil
        )
        #expect(MediaDetailFormatter.audioTrackProperties(for: emptyTrack, locale: Locale(identifier: "en_US")).isEmpty)

        let validTrack = VideoAudioTrack(
            language: "jpn",
            title: "Main",
            codec: "flac",
            channels: 2,
            sampleRate: 48_000,
            bitDepth: 24
        )
        #expect(MediaDetailFormatter.audioTrackProperties(for: validTrack, locale: Locale(identifier: "en_US")).count == 6)
    }

    @Test
    func fileDetailDialogRendersInHostingViewAcrossAllKinds() {
        let videoWithoutAudio = FileDetailVideoInfo(
            path: "/Videos/Show/EP01.mkv",
            name: "EP01.mkv",
            fileSize: 1024 * 1024 * 250,
            duration: 1420,
            videoWidth: 1920,
            videoHeight: 1080,
            frameRate: 23.976,
            videoCodec: "hevc",
            audioTracks: [],
            subtitles: [],
            createdAt: nil,
            modifiedAt: nil
        )
        let subtitleInfo = FileDetailSubtitleInfo(
            path: "/Videos/Show/EP01.ass",
            name: "EP01.ass",
            fileSize: 32_768,
            format: .ass,
            encoding: "-",
            cueCount: 350,
            rawCueCount: 380,
            associatedVideoPath: nil,
            createdAt: nil,
            modifiedAt: nil
        )
        let folderInfo = FileDetailFolderInfo(
            path: "smb://nas.local/Media/Show%20Name",
            name: "Show Name",
            isRootFolder: true,
            folderCount: 2,
            videoCount: 12,
            subtitleCount: 12,
            addedAt: nil,
            updatedAt: nil
        )

        for kind in [
            FileDetailDialogSession.DetailKind.video(videoWithoutAudio),
            .subtitle(subtitleInfo),
            .folder(folderInfo)
        ] {
            let dialog = WorkbenchFileDetailDialog(
                session: FileDetailDialogSession(kind: kind),
                onClose: {}
            )
            let host = NSHostingView(rootView: dialog)
            host.layoutSubtreeIfNeeded()
            let fittingSize = host.fittingSize
            #expect(fittingSize.width == WorkbenchControlMetrics.redesignDialogWidthXLarge)
            #expect(fittingSize.height > 100)
        }
    }

    @Test
    func pairedFilesSwitcherSessionAndMenuRendering() {
        let videoInfo = FileDetailVideoInfo(
            path: "/Videos/Show/[SubGroup] Long Episode Title - 01 [1080p].mkv",
            name: "[SubGroup] Long Episode Title - 01 [1080p].mkv",
            fileSize: 1024 * 1024 * 800,
            duration: 1450.0,
            videoWidth: 1920,
            videoHeight: 1080,
            frameRate: 23.976,
            videoCodec: "hevc",
            videoBitDepth: 10,
            videoPixelFormat: "yuv420p10le",
            containerFormat: "mkv",
            audioTracks: [],
            subtitles: [
                VideoSubtitle(subtitleFileID: 1, subtitlePath: "/Videos/Show/Ep01.chs.ass", format: .ass),
                VideoSubtitle(subtitleFileID: 2, subtitlePath: "/Videos/Show/Ep01.jpn.srt", format: .srt)
            ],
            createdAt: nil,
            modifiedAt: nil
        )
        let sub1 = FileDetailSubtitleInfo(
            path: "/Videos/Show/Ep01.chs.ass",
            name: "Ep01.chs.ass",
            fileSize: 64_000,
            format: .ass,
            encoding: "UTF-8",
            cueCount: 320,
            rawCueCount: 360,
            associatedVideoPath: videoInfo.path,
            createdAt: nil,
            modifiedAt: nil
        )
        let sub2 = FileDetailSubtitleInfo(
            path: "/Videos/Show/Ep01.jpn.srt",
            name: "Ep01.jpn.srt",
            fileSize: 28_000,
            format: .srt,
            encoding: "UTF-8",
            cueCount: 310,
            rawCueCount: 310,
            associatedVideoPath: videoInfo.path,
            createdAt: nil,
            modifiedAt: nil
        )

        let pairedItems: [FileDetailPairedItem] = [
            .video(videoInfo),
            .subtitle(sub1),
            .subtitle(sub2)
        ]

        let session = FileDetailDialogSession(pairedItems: pairedItems, initialSelectedIndex: 1)
        #expect(session.isFileDetail)
        #expect(session.selectedIndex == 1)
        #expect(session.fileName == "Ep01.chs.ass")
        #expect(session.icon == .subtitles)
        #expect(session.kind == .subtitle(sub1))

        session.selectItem(at: 0)
        #expect(session.selectedIndex == 0)
        #expect(session.fileName == videoInfo.name)
        #expect(session.icon == .video)
        #expect(session.kind == .video(videoInfo))

        session.selectItem(at: 2)
        #expect(session.selectedIndex == 2)
        #expect(session.fileName == "Ep01.jpn.srt")
        #expect(session.icon == .subtitles)
        #expect(session.kind == .subtitle(sub2))

        // Out-of-bounds index is ignored and keeps the frozen snapshot selection
        session.selectItem(at: 99)
        #expect(session.selectedIndex == 2)

        // Trigger state colors follow Pressed whitelist rules
        #expect(
            FileDetailPairedSwitcherTrigger.resolvedBackgroundColor(
                isPressed: false,
                isOpen: false,
                isHovered: false
            ) == WorkbenchRedesignColors.tableBg
        )
        #expect(
            FileDetailPairedSwitcherTrigger.resolvedBackgroundColor(
                isPressed: false,
                isOpen: true,
                isHovered: false
            ) == WorkbenchRedesignColors.bgHover
        )
        #expect(
            FileDetailPairedSwitcherTrigger.resolvedBackgroundColor(
                isPressed: true,
                isOpen: true,
                isHovered: true
            ) == WorkbenchRedesignColors.bgPressed
        )
        #expect(
            FileDetailPairedSwitcherTrigger.resolvedBorderColor(
                isPressed: false,
                isOpen: false,
                isHovered: false
            ) == WorkbenchRedesignColors.borderControl
        )
        #expect(
            FileDetailPairedSwitcherTrigger.resolvedBorderColor(
                isPressed: false,
                isOpen: true,
                isHovered: false
            ) == WorkbenchRedesignColors.borderControlHover
        )

        // Render menu popover in NSHostingView and verify width matches trigger width (672px)
        let highlight = MenuHighlightModel()
        highlight.open(selectablePositions: Array(pairedItems.indices))
        let popover = FileDetailPairedSwitcherMenuPopover(
            items: pairedItems,
            width: WorkbenchControlMetrics.redesignDialogWidthXLarge - 2 * WorkbenchControlMetrics.redesignDialogInset,
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight,
            onSelect: { _ in }
        )
        let popoverHost = NSHostingView(rootView: popover)
        popoverHost.layoutSubtreeIfNeeded()
        #expect(popoverHost.fittingSize.width == 672)
        #expect(popoverHost.fittingSize.height >= 3 * WorkbenchControlMetrics.redesignMenuItemHeight)
    }
}
