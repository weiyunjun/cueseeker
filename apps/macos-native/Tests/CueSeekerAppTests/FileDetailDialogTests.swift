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

        AppLocalization.apply(.simplifiedChinese)
        #expect(L("file_detail.folder_title") == "文件夹详情")
        #expect(L("file_detail.section.folder_info") == "文件夹信息")
        #expect(L("file_detail.section.index_info") == "索引信息")
        #expect(L("file_detail.folder_count") == "文件夹数")
        #expect(L("file_detail.video_count") == "视频数")
        #expect(L("file_detail.subtitle_count") == "字幕数")
        #expect(L("file_detail.added") == "添加时间")
        #expect(L("file_detail.updated") == "更新时间")

        AppLocalization.apply(.traditionalChinese)
        #expect(L("file_detail.folder_title") == "資料夾詳情")
        #expect(L("file_detail.section.folder_info") == "資料夾資訊")
        #expect(L("file_detail.section.index_info") == "索引資訊")
        #expect(L("file_detail.folder_count") == "資料夾數")
        #expect(L("file_detail.video_count") == "影片數")
        #expect(L("file_detail.subtitle_count") == "字幕數")
        #expect(L("file_detail.added") == "加入時間")
        #expect(L("file_detail.updated") == "更新時間")
    }

    @Test
    func fileDetailDialogMetricTokens() {
        #expect(WorkbenchControlMetrics.redesignDetailFileIconContainerSize == 40)
        #expect(WorkbenchControlMetrics.redesignDetailFileTitleLineHeight == 20)
        #expect(WorkbenchControlMetrics.redesignDetailLabelMinWidth == 100)
        #expect(WorkbenchControlMetrics.redesignDetailIndexLabelMinWidth == 40)
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

        #expect(WorkbenchFileDetailDialog.pixelFormatText("yuv420p") == "yuv420p")
        #expect(WorkbenchFileDetailDialog.pixelFormatText(nil) == "-")

        #expect(WorkbenchFileDetailDialog.channelsText(1) == "1ch")
        #expect(WorkbenchFileDetailDialog.channelsText(2) == "2ch")
        #expect(WorkbenchFileDetailDialog.channelsText(6) == "6ch")
        #expect(WorkbenchFileDetailDialog.channelsText(8) == "8ch")
        #expect(WorkbenchFileDetailDialog.channelsText(nil) == nil)

        #expect(WorkbenchFileDetailDialog.sampleRateText(48_000) == "48,000 Hz")
        #expect(WorkbenchFileDetailDialog.sampleRateText(44_100) == "44,100 Hz")
        #expect(WorkbenchFileDetailDialog.sampleRateText(nil) == nil)

        #expect(WorkbenchFileDetailDialog.audioBitDepthText(24) == "24 bit")
        #expect(WorkbenchFileDetailDialog.audioBitDepthText(nil) == nil)
        #expect(WorkbenchFileDetailDialog.audioBitDepthText(0) == nil)

        defer {
            AppLocalization.apply(.english)
        }
        AppLocalization.apply(.english)
        #expect(WorkbenchFileDetailDialog.languageText("eng") == "English")
        #expect(WorkbenchFileDetailDialog.languageText("jpn") == "Japanese")

        AppLocalization.apply(.simplifiedChinese)
        #expect(WorkbenchFileDetailDialog.languageText("eng") == "英语")
        #expect(WorkbenchFileDetailDialog.languageText("jpn") == "日语")
    }
}
