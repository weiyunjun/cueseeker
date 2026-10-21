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
        #expect(subSession.fileName == "sub.ass")
        #expect(subSession.icon == .subtitles)
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
}
