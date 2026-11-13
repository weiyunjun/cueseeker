import AppKit
import CoreText
@testable import CueSeekerPlayback
import CueSeekerCore
import Foundation
import QuartzCore
import SQLite3
import Testing

extension PlaybackSubtitleFirstFrameTelemetryTests {
    @Test
    @MainActor
    func firstFrameVerticalSyncPresentsVideoAndSubtitleTogetherAndHoldsPreviousSubtitleAcrossTransitions() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0
            SRTSubtitleOverlayView.artificialLoadDelayPathSubstringForTesting = nil
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoOneURL = tempDir.appendingPathComponent("episode-one.mkv")
        let videoTwoURL = tempDir.appendingPathComponent("episode-two.mkv")
        let assOneURL = tempDir.appendingPathComponent("episode-one.ass")
        let assTwoURL = tempDir.appendingPathComponent("episode-one-alt.ass")
        let srtOneURL = tempDir.appendingPathComponent("episode-two.srt")
        let srtTwoURL = tempDir.appendingPathComponent("episode-two-alt.srt")

        try makeVerticalSyncTestVideo(at: videoOneURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 5)
        try makeVerticalSyncTestVideo(at: videoTwoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 5)

        try writeVerticalSyncASSSubtitle(
            at: assOneURL,
            cues: [
                (start: "0:00:00.00", end: "0:00:01.50", text: "Episode One Cue A"),
                (start: "0:00:02.20", end: "0:00:03.80", text: "Episode One Cue B")
            ]
        )
        try writeVerticalSyncASSSubtitle(
            at: assTwoURL,
            cues: [
                (start: "0:00:00.00", end: "0:00:04.20", text: "Alternate ASS Track")
            ]
        )
        try writeVerticalSyncSRTSubtitle(
            at: srtOneURL,
            cues: [
                (index: 1, start: "00:00:00,000", end: "00:00:01,500", text: "Episode Two SRT A"),
                (index: 2, start: "00:00:02,200", end: "00:00:03,800", text: "Episode Two SRT B")
            ]
        )
        try writeVerticalSyncSRTSubtitle(
            at: srtTwoURL,
            cues: [
                (index: 1, start: "00:00:00,000", end: "00:00:04,200", text: "Alternate SRT Track")
            ]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)

        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // 1. Open Episode 1 with ASS delayed 140ms (< 1000ms timeout): video + ASS surface commit together on frame 1.
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.14
        let openGen1 = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(
                    url: assOneURL,
                    format: .ass,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 200
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: openGen1) != nil
        }
        let openCommit1 = try #require(delegateSpy.commit(forGeneration: openGen1))
        #expect(openCommit1.hasVideoSnapshot)
        #expect(openCommit1.hasASSVisibleSurface)
        #expect(!openCommit1.hasSRTImage)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0

        // 2. Seek to a blank silent interval (1_800ms): previous cue stays visible until commit, then clears cleanly at commit.
        let blankSeekGen = try player.seek(toMilliseconds: 1_800, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: blankSeekGen) != nil
        }
        let blankCommit = try #require(delegateSpy.commit(forGeneration: blankSeekGen))
        #expect(blankCommit.hasVideoSnapshot)
        #expect(blankCommit.hasASSBlankSurfaceEvaluated)
        #expect(!blankCommit.hasASSVisibleSurface)
        #expect(!container.hasDisplayedSubtitleImageForTesting)

        // 3. Seek to Cue B (2_500ms), then open Episode 2 with SRT delayed 140ms: previous ASS subtitle stays displayed
        //    throughout preparation (zero blank flash) until Episode 2 video + SRT commit together!
        let cueBGen = try player.seek(toMilliseconds: 2_500, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: cueBGen) != nil
        }
        #expect(container.hasDisplayedSubtitleImageForTesting)

        SRTSubtitleOverlayView.artificialLoadDelayPathSubstringForTesting = scopeToken
        SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0.16
        let openGen2 = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: srtOneURL,
                    format: .srt,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(delegateSpy.commit(forGeneration: openGen2) == nil)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentASSSubtitleFrame()?.surface != nil)

        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: openGen2) != nil
        }
        let openCommit2 = try #require(delegateSpy.commit(forGeneration: openGen2))
        #expect(openCommit2.hasVideoSnapshot)
        #expect(openCommit2.hasSRTImage)
        #expect(!openCommit2.hasASSVisibleSurface)
        #expect(container.currentASSSubtitleFrame() == nil)
        #expect(container.currentSRTSubtitleImage() != nil)

        // 4. Manual subtitle switches across SRT->SRT, SRT->ASS, ASS->ASS, ASS->SRT, and ->nil preserve previous text until ready.
        try player.setPaused(true)
        SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0.12
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.12
        let previousSRTImage = try #require(container.currentSRTSubtitleImage())

        // SRT -> SRT
        player.loadSubtitleSource(
            PlaybackSubtitleSource(url: srtTwoURL, format: .srt, matchedVideoURL: videoTwoURL, initialTimestampMilliseconds: 300)
        )
        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentSRTSubtitleImage() === previousSRTImage)
        try await waitForVerticalSyncCondition {
            container.currentSRTSubtitleImage() != nil && container.currentSRTSubtitleImage() !== previousSRTImage
        }

        // SRT -> ASS
        player.loadSubtitleSource(
            PlaybackSubtitleSource(url: assOneURL, format: .ass, matchedVideoURL: videoTwoURL, initialTimestampMilliseconds: 300)
        )
        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentSRTSubtitleImage() != nil)
        try await waitForVerticalSyncCondition {
            container.currentASSSubtitleFrame()?.surface != nil && container.currentSRTSubtitleImage() == nil
        }

        // ASS -> ASS
        let firstASSSurfaceData = try #require(container.currentASSSubtitleFrame()?.surface?.rgbaData)
        player.loadSubtitleSource(
            PlaybackSubtitleSource(url: assTwoURL, format: .ass, matchedVideoURL: videoTwoURL, initialTimestampMilliseconds: 300)
        )
        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentASSSubtitleFrame()?.surface?.rgbaData == firstASSSurfaceData)
        try await waitForVerticalSyncCondition {
            guard let data = container.currentASSSubtitleFrame()?.surface?.rgbaData else { return false }
            return data != firstASSSurfaceData
        }

        // ASS -> SRT
        player.loadSubtitleSource(
            PlaybackSubtitleSource(url: srtOneURL, format: .srt, matchedVideoURL: videoTwoURL, initialTimestampMilliseconds: 300)
        )
        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentASSSubtitleFrame()?.surface != nil)
        try await waitForVerticalSyncCondition {
            container.currentSRTSubtitleImage() != nil && container.currentASSSubtitleFrame() == nil
        }

        // -> nil clears immediately
        player.loadSubtitleSource(nil)
        #expect(!container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentSRTSubtitleImage() == nil)
        #expect(container.currentASSSubtitleFrame() == nil)

        // 5. Zero subtitle wait when subtitleSource == nil or subtitles are hidden (even with 0.8s subtitle delay configured).
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.80
        SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0.80

        let noSubStart = CACurrentMediaTime()
        let noSubGen = try player.open(PlaybackRequest(videoURL: videoOneURL, startMilliseconds: 200))
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: noSubGen) != nil
        }
        #expect(CACurrentMediaTime() - noSubStart < 0.45)

        player.setSubtitlesVisible(false)
        let hiddenStart = CACurrentMediaTime()
        let hiddenGen = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(
                    url: assOneURL,
                    format: .ass,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 200
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: hiddenGen) != nil
        }
        #expect(CACurrentMediaTime() - hiddenStart < 0.45)
        #expect(!container.hasDisplayedSubtitleImageForTesting)
    }

    @Test
    @MainActor
    func repeatTwoMillisecondAlignmentMatchesTargetCueWithoutSteppingBackward() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let ntscVideoURL = tempDir.appendingPathComponent("ntsc-23976.mkv")
        let srtURL = tempDir.appendingPathComponent("ntsc-repeat.srt")
        // At 24000/1001 fps (~23.976fps), frame 24 PTS is 1001ms (within 2ms pre-target of 1002ms),
        // and frame 49 PTS is 2044ms (post-target when seeking to 2010ms).
        try makeVerticalSyncTestVideo(
            at: ntscVideoURL,
            ffmpegURL: ffmpegURL,
            frameRate: "24000/1001",
            durationSeconds: 4,
            keyframeInterval: 1
        )
        try writeVerticalSyncSRTSubtitle(
            at: srtURL,
            cues: [
                // Starts at 1002ms: raw frame PTS 1001ms would miss this cue without 2ms Repeat alignment!
                (index: 1, start: "00:00:01,002", end: "00:00:01,800", text: "Aligned Repeat Cue"),
                // Starts at 2030ms: seeking to 2010ms lands on frame 49 (~2044ms), which must retarget subtitle to 2044ms!
                (index: 2, start: "00:00:02,030", end: "00:00:03,200", text: "Post-Target Retargeted Cue")
            ]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // Case A: Pre-target within 2ms (raw frame 1001ms, target 1002ms) aligns to 1002ms and renders Cue 1 on frame 1.
        let openGen = try player.open(
            PlaybackRequest(
                videoURL: ntscVideoURL,
                startMilliseconds: 1_002,
                subtitleSource: PlaybackSubtitleSource(
                    url: srtURL,
                    format: .srt,
                    matchedVideoURL: ntscVideoURL,
                    initialTimestampMilliseconds: 1_002
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: openGen) != nil
        }
        let alignedCommit = try #require(delegateSpy.commit(forGeneration: openGen))
        #expect(alignedCommit.milliseconds == 1_002)
        #expect(alignedCommit.hasVideoSnapshot)
        #expect(alignedCommit.hasSRTImage)

        // Repeatedly seeking to 1_002ms (simulating Repeat) stays locked on 1_002ms and never steps backward into < 1_002ms.
        let repeatGen = try player.seek(toMilliseconds: 1_002, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: repeatGen) != nil
        }
        let repeatCommit = try #require(delegateSpy.commit(forGeneration: repeatGen))
        #expect(repeatCommit.milliseconds == 1_002)
        #expect(repeatCommit.hasSRTImage)

        // Case B: Post-target frame grid landing (target 2_010ms -> frame 49 at ~2_044ms) retargets staged subtitle before commit.
        let postTargetGen = try player.seek(toMilliseconds: 2_010, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: postTargetGen) != nil
        }
        let postTargetCommit = try #require(delegateSpy.commit(forGeneration: postTargetGen))
        #expect(postTargetCommit.milliseconds >= 2_030)
        #expect(postTargetCommit.hasSRTImage)
    }


    @Test
    @MainActor
    func directSubtitleReadFailureReleasesImmediatelyWithErrorWhilePostVideoReadyTimeoutReleasesSilentlyAndRecovers() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        let unreadableSRTURL = tempDir.appendingPathComponent("unreadable-\(scopeToken).srt")
        defer {
            _ = chmod(unreadableSRTURL.path, 0o644)
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0
            SRTSubtitleOverlayView.artificialLoadDelayPathSubstringForTesting = nil
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoOneURL = tempDir.appendingPathComponent("error-vs-timeout-1.mkv")
        let videoTwoURL = tempDir.appendingPathComponent("error-vs-timeout-2.mkv")
        try makeVerticalSyncTestVideo(at: videoOneURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 5)
        try makeVerticalSyncTestVideo(at: videoTwoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 5)

        let missingASSURL = tempDir.appendingPathComponent("missing-\(scopeToken).ass")
        try writeVerticalSyncSRTSubtitle(
            at: unreadableSRTURL,
            cues: [(index: 1, start: "00:00:00,000", end: "00:00:02,000", text: "Unreadable Cue")]
        )
        #expect(chmod(unreadableSRTURL.path, 0o000) == 0)

        let corruptASSURL = tempDir.appendingPathComponent("corrupt-\(scopeToken).ass")
        // Invalid UTF-16BE odd-byte payload with BOM that cannot be decoded as text.
        try Data([0xFE, 0xFF, 0xD8, 0x00, 0xFF]).write(to: corruptASSURL)

        let validFirstSRTURL = tempDir.appendingPathComponent("valid-first-\(scopeToken).srt")
        let slowTimeoutASSURL = tempDir.appendingPathComponent("slow-timeout-\(scopeToken).ass")
        let fastFinalSRTURL = tempDir.appendingPathComponent("fast-final-\(scopeToken).srt")
        try writeVerticalSyncSRTSubtitle(
            at: validFirstSRTURL,
            cues: [(index: 1, start: "00:00:00,000", end: "00:00:03,000", text: "Initial Visible Cue")]
        )
        try writeVerticalSyncASSSubtitle(
            at: slowTimeoutASSURL,
            cues: [(start: "0:00:00.00", end: "0:00:04.00", text: "Delayed ASS After Timeout")]
        )
        try writeVerticalSyncSRTSubtitle(
            at: fastFinalSRTURL,
            cues: [
                (index: 1, start: "00:00:00,000", end: "00:00:01,500", text: "Fast Cue A"),
                (index: 2, start: "00:00:02,000", end: "00:00:04,000", text: "Fast Cue B")
            ]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        player.subtitleFirstFrameWaitTimeoutSeconds = 1.5
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // 1. Direct read/decode failures (missing file, chmod 000, corrupt encoding) release IMMEDIATELY (< 0.55s << 1.5s timeout)
        //    and report didFailToLoadSubtitleSource (for the top-left red error banner).
        for (failedURL, format) in [
            (missingASSURL, PlaybackSubtitleSourceFormat.ass),
            (unreadableSRTURL, PlaybackSubtitleSourceFormat.srt),
            (corruptASSURL, PlaybackSubtitleSourceFormat.ass)
        ] {
            let startedAt = CACurrentMediaTime()
            let gen = try player.open(
                PlaybackRequest(
                    videoURL: videoOneURL,
                    startMilliseconds: 200,
                    subtitleSource: PlaybackSubtitleSource(
                        url: failedURL,
                        format: format,
                        matchedVideoURL: videoOneURL,
                        initialTimestampMilliseconds: 200
                    )
                )
            )
            try await waitForVerticalSyncCondition {
                delegateSpy.commit(forGeneration: gen) != nil && delegateSpy.failedSubtitleURLs.contains(failedURL.standardizedMediaURL)
            }
            let elapsed = CACurrentMediaTime() - startedAt
            #expect(elapsed < 0.65)
            let commit = try #require(delegateSpy.commit(forGeneration: gen))
            #expect(commit.hasVideoSnapshot)
            #expect(!commit.hasASSVisibleSurface)
            #expect(!commit.hasSRTImage)
            #expect(!container.hasDisplayedSubtitleImageForTesting)
        }

        // 2. Establish a visible subtitle on Episode 1, then open Episode 2 with a slow ASS subtitle exceeding post-video-ready timeout.
        delegateSpy.failedSubtitleURLs.removeAll()
        let validGen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 250,
                subtitleSource: PlaybackSubtitleSource(
                    url: validFirstSRTURL,
                    format: .srt,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 250
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: validGen) != nil
        }
        #expect(container.hasDisplayedSubtitleImageForTesting)

        player.subtitleFirstFrameWaitTimeoutSeconds = 0.14
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.36

        let timeoutGen = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: slowTimeoutASSURL,
                    format: .ass,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: timeoutGen) != nil
        }
        // At timeout commit: video presents, NO red error is emitted, and stale Episode 1 subtitle is cleared cleanly.
        let timeoutCommit = try #require(delegateSpy.commit(forGeneration: timeoutGen))
        #expect(timeoutCommit.hasVideoSnapshot)
        #expect(!timeoutCommit.hasASSVisibleSurface)
        #expect(!timeoutCommit.hasSRTImage)
        #expect(delegateSpy.failedSubtitleURLs.isEmpty)
        #expect(!container.hasDisplayedSubtitleImageForTesting)

        // Once background ASS preparation finishes (~220ms later), the new subtitle appears automatically without error!
        try await waitForVerticalSyncCondition {
            container.currentASSSubtitleFrame()?.surface != nil
        }
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(delegateSpy.failedSubtitleURLs.isEmpty)

        // 3. Rapid consecutive switches cancel stale wait/timeout so only the latest target commits cleanly.
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.45
        let staleGen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(
                    url: slowTimeoutASSURL,
                    format: .ass,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 200
                )
            )
        )
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0
        let latestGen = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 2_300,
                subtitleSource: PlaybackSubtitleSource(
                    url: fastFinalSRTURL,
                    format: .srt,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 2_300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: latestGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: staleGen) == nil)
        let latestCommit = try #require(delegateSpy.commit(forGeneration: latestGen))
        #expect(latestCommit.hasVideoSnapshot)
        #expect(latestCommit.hasSRTImage)
        #expect(delegateSpy.failedSubtitleURLs.isEmpty)
    }


    @Test
    @MainActor
    func indexedASSPartialLoadingSlicesOnlyActiveWindowReusesMemoryIndexFallsBackOnInvalidationAndNeverWritesDatabase() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let mediaDir = tempDir.appendingPathComponent("Anime-\(scopeToken)", isDirectory: true)
        let cacheDir = tempDir.appendingPathComponent("RemoteSubtitleCache-\(scopeToken)", isDirectory: true)
        let dbDir = tempDir.appendingPathComponent("Database-\(scopeToken)", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let databaseURL = dbDir.appendingPathComponent("CueSeeker.sqlite")

        let videoURL = mediaDir.appendingPathComponent("HeavyEpisode.mkv")
        try makeVerticalSyncTestVideo(at: videoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 12)

        // Build a >300 KB ASS script with same-timestamp bilingual JP+CN lines, out-of-order style-grouped FX lines,
        // and thousands of particle lines spread across 0..120s so a single 5s window is a tiny byte fraction of the file.
        func buildHeavyASSText(title: String, openingText: String, laterWindowText: String) -> String {
            var lines: [String] = [
                "[Script Info]",
                "Title: \(title)",
                "ScriptType: v4.00+",
                "PlayResX: 1280",
                "PlayResY: 720",
                "",
                "[V4+ Styles]",
                "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
                "Style: JP,Helvetica,44,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,24,24,28,1",
                "Style: CN,Helvetica,40,&H00E0FFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,24,24,78,1",
                "Style: FX,Helvetica,36,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,8,20,20,24,1",
                "",
                "[Events]",
                "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
                "Dialogue: 0,0:00:00.10,0:00:02.00,JP,,0,0,0,,\(openingText) JP",
                "Dialogue: 0,0:00:00.10,0:00:02.00,CN,,0,0,0,,\(openingText) CN",
                "Dialogue: 0,0:00:07.00,0:00:09.50,JP,,0,0,0,,\(laterWindowText) JP",
                "Dialogue: 0,0:00:07.00,0:00:09.50,CN,,0,0,0,,\(laterWindowText) CN"
            ]
            lines.reserveCapacity(4_200)
            for idx in 0..<4_000 {
                // Place heavy particle bulk in 0:00:20.00 .. 0:03:00.00 outside the [0..10s] playback windows.
                let startCs = 2_000 + idx * 4
                let endCs = startCs + 4
                let sMin = (startCs / 6000) % 60
                let sSec = (startCs / 100) % 60
                let sRem = startCs % 100
                let eMin = (endCs / 6000) % 60
                let eSec = (endCs / 100) % 60
                let eRem = endCs % 100
                let sTag = String(format: "0:%02d:%02d.%02d", sMin, sSec, sRem)
                let eTag = String(format: "0:%02d:%02d.%02d", eMin, eSec, eRem)
                lines.append("Dialogue: 2,\(sTag),\(eTag),FX,,0,0,0,,{\\pos(\(idx % 1200),\(idx % 700))}Particle-\(idx)-PayloadPaddingText")
            }
            // Out-of-chronological-order FX banner at the very bottom of the file overlapping [0.10s..2.00s]!
            lines.append("Dialogue: 5,0:00:00.15,0:00:01.90,FX,,0,0,0,,Bottom Grouped Sign")
            return lines.joined(separator: "\n")
        }

        let heavyASSText = buildHeavyASSText(title: "Heavy Local", openingText: "Local Opening", laterWindowText: "Local Window Two")
        let heavyASSData = Data(heavyASSText.utf8)
        #expect(heavyASSData.count > 280_000)
        let heavyASSURL = mediaDir.appendingPathComponent("HeavyEpisode.ass")
        try heavyASSData.write(to: heavyASSURL)

        // Remote seed file indexed first, then remapped to an http:// WebDAV media path backed by isolated WebDAVSubtitleCache.
        let remoteSeedURL = mediaDir.appendingPathComponent("RemoteSeed.ass")
        let remoteSeedVideoURL = mediaDir.appendingPathComponent("RemoteSeed.mkv")
        let remoteASSText = buildHeavyASSText(title: "Heavy Remote", openingText: "Remote Opening", laterWindowText: "Remote Window Two")
        let remoteASSData = Data(remoteASSText.utf8)
        try remoteASSData.write(to: remoteSeedURL)
        try Data("stub".utf8).write(to: remoteSeedVideoURL)

        // Embedded [Fonts] ASS (indexed as ineligible -> must fall back seamlessly).
        let embeddedFontsASSURL = mediaDir.appendingPathComponent("EmbeddedFonts.ass")
        let embeddedFontsVideoURL = mediaDir.appendingPathComponent("EmbeddedFonts.mkv")
        let embeddedFontsASS = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [Fonts]
        fontname: dummy_0.ttf
        0123456789ABCDEF

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.10,0:00:03.00,Default,,0,0,0,,Embedded Font Fallback Cue
        """
        try Data(embeddedFontsASS.utf8).write(to: embeddedFontsASSURL)
        try Data("stub".utf8).write(to: embeddedFontsVideoURL)

        // Pre-playback externally edited ASS (indexed, then modified before playback).
        let editedBeforePlayASSURL = mediaDir.appendingPathComponent("EditedBeforePlay.ass")
        let editedBeforePlayVideoURL = mediaDir.appendingPathComponent("EditedBeforePlay.mkv")
        try writeVerticalSyncASSSubtitle(
            at: editedBeforePlayASSURL,
            cues: [(start: "0:00:00.10", end: "0:00:03.00", text: "Before External Edit")]
        )
        try Data("stub".utf8).write(to: editedBeforePlayVideoURL)

        try DatabaseBootstrap.prepare(at: databaseURL)
        do {
            let indexingDB = try IndexingDatabase(path: databaseURL)
            let indexResult = try SubtitleIndexer().index(folder: mediaDir, into: indexingDB)
            #expect(indexResult.indexedSubtitleFiles == 4)
            #expect(indexResult.failedFiles.isEmpty)
        }

        let remoteSubtitleURL = try #require(URL(string: "http://nas.local:5244/dav/\(scopeToken)/RemoteHeavy.ass"))
        let isolatedSubtitleCache = WebDAVSubtitleCache(cacheDirectoryURL: cacheDir)
        _ = try isolatedSubtitleCache.storeSubtitleData(remoteASSData, for: remoteSubtitleURL)
        try remapIndexedSubtitlePathForTesting(
            inDatabaseAt: databaseURL,
            oldPath: remoteSeedURL.mediaPath,
            newPath: remoteSubtitleURL.mediaPath
        )
        try FileManager.default.removeItem(at: remoteSeedURL)

        // Create an unindexed ASS AFTER indexing, and externally edit EditedBeforePlay.ass so its fingerprint is stale.
        let unindexedASSURL = mediaDir.appendingPathComponent("UnindexedEpisode.ass")
        try writeVerticalSyncASSSubtitle(
            at: unindexedASSURL,
            cues: [(start: "0:00:00.10", end: "0:00:03.00", text: "Unindexed Fallback Cue")]
        )
        try writeVerticalSyncASSSubtitle(
            at: editedBeforePlayASSURL,
            cues: [(start: "0:00:00.10", end: "0:00:03.00", text: "After External Edit With Different Byte Size")]
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(15)],
            ofItemAtPath: editedBeforePlayASSURL.path
        )

        // Snapshot DB files & metadata BEFORE playback begins to prove strictly zero DB writes during playback!
        let dbSnapshotBeforePlayback = try captureDatabaseDirectorySnapshot(in: dbDir)

        let renderCache = PlaybackSubtitleRenderCacheReader(
            databaseURL: databaseURL,
            subtitleCache: isolatedSubtitleCache
        )
        ASSIndexedPartialLoadDiagnostics.resetForTesting()
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // A. Local indexed HeavyEpisode.ass: partial window load reads tiny fraction of 280KB+ file, renders JP+CN+bottom FX.
        let localGen = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: heavyASSURL,
                    format: .ass,
                    matchedVideoURL: videoURL,
                    initialTimestampMilliseconds: 300,
                    renderCacheProvider: renderCache
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: localGen) != nil
        }
        let localCommit = try #require(delegateSpy.commit(forGeneration: localGen))
        #expect(localCommit.hasASSVisibleSurface)
        let snapAfterInitialOpen = ASSIndexedPartialLoadDiagnostics.snapshot
        #expect(snapAfterInitialOpen.indexedSessionLoadCount == 1)
        #expect(snapAfterInitialOpen.fullFallbackSessionLoadCount == 0)
        #expect(snapAfterInitialOpen.databaseIndexValidationCount == 1)
        #expect(snapAfterInitialOpen.partialChunkBytesRead > 0)
        #expect(snapAfterInitialOpen.partialChunkBytesRead < heavyASSData.count / 10)

        // Seeking to a second 5s window (7_500ms) slices the new window without re-querying SQLite!
        let windowTwoGen = try player.seek(toMilliseconds: 7_500, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: windowTwoGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: windowTwoGen)?.hasASSVisibleSurface == true)
        let snapAfterWindowSeek = ASSIndexedPartialLoadDiagnostics.snapshot
        #expect(snapAfterWindowSeek.databaseIndexValidationCount == 1)
        #expect(snapAfterWindowSeek.fullFallbackSessionLoadCount == 0)
        #expect(snapAfterWindowSeek.partialChunkBytesRead < heavyASSData.count / 8)

        // Re-opening/rebuilding renderer (e.g. after switching subtitle off and back on) reuses in-memory validated index!
        player.loadSubtitleSource(nil)
        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: heavyASSURL,
                format: .ass,
                matchedVideoURL: videoURL,
                initialTimestampMilliseconds: 7_500,
                renderCacheProvider: renderCache
            )
        )
        try await waitForVerticalSyncCondition {
            ASSIndexedPartialLoadDiagnostics.snapshot.memoryCacheReuseCount >= 1
                && container.currentASSSubtitleFrame()?.surface != nil
        }
        #expect(ASSIndexedPartialLoadDiagnostics.snapshot.databaseIndexValidationCount == 1)

        // B. Mid-playback external edit on HeavyEpisode.ass invalidates index on next window load and seamlessly falls back!
        let editedMidPlayText = heavyASSText + "\nDialogue: 0,0:00:00.10,0:00:10.00,FX,,0,0,0,,Mid-Playback Appended Line\n"
        try Data(editedMidPlayText.utf8).write(to: heavyASSURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(30)],
            ofItemAtPath: heavyASSURL.path
        )
        let midEditSeekGen = try player.seek(toMilliseconds: 400, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: midEditSeekGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: midEditSeekGen)?.hasASSVisibleSurface == true)
        #expect(ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount == 1)

        // C. Cached remote WebDAV ASS subtitle uses indexed partial loading and reads only active window bytes!
        let bytesBeforeRemote = ASSIndexedPartialLoadDiagnostics.snapshot.partialChunkBytesRead
        let indexedCountBeforeRemote = ASSIndexedPartialLoadDiagnostics.snapshot.indexedSessionLoadCount
        let remoteGen = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: remoteSubtitleURL,
                    format: .ass,
                    matchedVideoURL: videoURL,
                    initialTimestampMilliseconds: 300,
                    renderCacheProvider: renderCache
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: remoteGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: remoteGen)?.hasASSVisibleSurface == true)
        let snapAfterRemote = ASSIndexedPartialLoadDiagnostics.snapshot
        #expect(snapAfterRemote.indexedSessionLoadCount == indexedCountBeforeRemote + 1)
        let remoteSlicedBytes = snapAfterRemote.partialChunkBytesRead - bytesBeforeRemote
        #expect(remoteSlicedBytes > 0)
        #expect(remoteSlicedBytes < remoteASSData.count / 10)

        // D. Unindexed ASS, [Fonts] ineligible ASS, and pre-playback externally edited ASS all fall back cleanly and render!
        for fallbackURL in [unindexedASSURL, embeddedFontsASSURL, editedBeforePlayASSURL] {
            let beforeFallbackCount = ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount
            let gen = try player.open(
                PlaybackRequest(
                    videoURL: videoURL,
                    startMilliseconds: 300,
                    subtitleSource: PlaybackSubtitleSource(
                        url: fallbackURL,
                        format: .ass,
                        matchedVideoURL: videoURL,
                        initialTimestampMilliseconds: 300,
                        renderCacheProvider: renderCache
                    )
                )
            )
            try await waitForVerticalSyncCondition {
                delegateSpy.commit(forGeneration: gen) != nil
            }
            let commit = try #require(delegateSpy.commit(forGeneration: gen))
            #expect(commit.hasASSVisibleSurface)
            #expect(ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount == beforeFallbackCount + 1)
        }
        #expect(delegateSpy.failedSubtitleURLs.isEmpty)

        // E. Strictly read-only during playback: SQLite file bytes, mtime, and directory entries (-wal/-shm) are untouched.
        let dbSnapshotAfterPlayback = try captureDatabaseDirectorySnapshot(in: dbDir)
        #expect(dbSnapshotAfterPlayback == dbSnapshotBeforePlayback)
    }


    @Test
    @MainActor
    func backgroundFontWarmupSharesSingleFlightWorkAndReusesEngineAcrossEpisodesAndWindows() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 1. Isolated ASSFontAliasResolver single-flight concurrency: concurrent warmUp() + rewriteRenderScript() calls
        //    share the exact same in-flight environment scan/table build (scan count == 1, build count == 1).
        let isolatedResolver = ASSFontAliasResolver(observeSystemFontChanges: false)
        await withTaskGroup(of: String.self) { group in
            for idx in 0..<8 {
                group.addTask {
                    if idx.isMultiple(of: 2) {
                        isolatedResolver.warmUp()
                        return ""
                    } else {
                        return isolatedResolver.rewriteRenderScript(
                            "[V4+ Styles]\nFormat: Name, Fontname\nStyle: Default,Helvetica\n",
                            requestedFontNames: ["Helvetica"]
                        )
                    }
                }
            }
            for await _ in group {}
        }
        #expect(isolatedResolver.snapshotScanCountForTesting == 1)
        #expect(isolatedResolver.tableBuildCountForTesting == 1)

        // Subsequent calls reuse the in-memory warmed table with zero extra font directory scans.
        isolatedResolver.warmUp()
        _ = isolatedResolver.rewriteRenderScript(
            "[V4+ Styles]\nFormat: Name, Fontname\nStyle: Default,Helvetica\n",
            requestedFontNames: ["Helvetica"]
        )
        #expect(isolatedResolver.snapshotScanCountForTesting == 1)
        #expect(isolatedResolver.tableBuildCountForTesting == 1)

        // 2. Pooled libass CoreText engine + shared ASSFontAliasResolver warmup & reuse across episodes, seeks, and track switches.
        ASSFontAliasResolver.shared.resetForTesting()
        PlaybackPlayer.resetASSEnginePoolForTesting()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<6 {
                group.addTask {
                    PlaybackPlayer.warmUpSubtitleEnvironment()
                }
            }
            for await _ in group {}
        }

        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)

        let videoOneURL = tempDir.appendingPathComponent("font-reuse-ep1.mkv")
        let videoTwoURL = tempDir.appendingPathComponent("font-reuse-ep2.mkv")
        let assEp1URL = tempDir.appendingPathComponent("font-reuse-ep1.ass")
        let assEp1AltURL = tempDir.appendingPathComponent("font-reuse-ep1-alt.ass")
        let assEp2URL = tempDir.appendingPathComponent("font-reuse-ep2.ass")
        try makeVerticalSyncTestVideo(at: videoOneURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 10)
        try makeVerticalSyncTestVideo(at: videoTwoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 6)

        try writeVerticalSyncASSSubtitle(
            at: assEp1URL,
            cues: [
                (start: "0:00:00.10", end: "0:00:02.00", text: "Episode 1 Window 1"),
                (start: "0:00:06.50", end: "0:00:08.50", text: "Episode 1 Window 2")
            ]
        )
        try writeVerticalSyncASSSubtitle(
            at: assEp1AltURL,
            cues: [(start: "0:00:00.10", end: "0:00:09.00", text: "Episode 1 Alternate Track")]
        )
        try writeVerticalSyncASSSubtitle(
            at: assEp2URL,
            cues: [(start: "0:00:00.10", end: "0:00:04.00", text: "Episode 2 Warmed Reuse")]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // Episode 1 open -> cross-window seek -> Episode 2 open: all reuse warmed font environment & pooled libass engine!
        let ep1Gen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp1URL,
                    format: .ass,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep1Gen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep1Gen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)

        // Cross-window seek within Episode 1 (0.3s -> 7.0s) reuses the active engine with zero re-init.
        let ep1Window2Gen = try player.seek(toMilliseconds: 7_000, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep1Window2Gen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep1Window2Gen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)

        // Switching to Episode 2 deterministically serializes old-worker teardown before new-worker checkout,
        // so the warmed pooled engine is always reused with zero concurrent second-slot cold initialization.
        let ep2Gen = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp2URL,
                    format: .ass,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep2Gen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep2Gen)?.hasASSVisibleSurface == true)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)

        // Manual subtitle switch + returning to Episode 1 continues reusing the exact single pooled engine.
        try player.setPaused(true)
        player.loadSubtitleSource(
            PlaybackSubtitleSource(url: assEp1AltURL, format: .ass, matchedVideoURL: videoTwoURL, initialTimestampMilliseconds: 300)
        )
        try await waitForVerticalSyncCondition {
            container.currentASSSubtitleFrame()?.surface != nil
        }
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        let ep1ReturnGen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp1URL,
                    format: .ass,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep1ReturnGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep1ReturnGen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)
    }

    @Test
    @MainActor
    func playingManualSubtitleSwitchWithAnimatedASSPresentsWithoutStarvationOrBlankFlashAndKeepsOldFormatLive() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0
            SRTSubtitleOverlayView.artificialLoadDelayPathSubstringForTesting = nil
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("playing-switch-\(scopeToken).mkv")
        try makeVerticalSyncTestVideo(
            at: videoURL,
            ffmpegURL: ffmpegURL,
            frameRate: "30",
            durationSeconds: 8,
            videoSize: "320x180"
        )

        let srtURL = tempDir.appendingPathComponent("dense-\(scopeToken).srt")
        var denseSRTCues: [(index: Int, start: String, end: String, text: String)] = []
        for idx in 0..<85 {
            let startMs = idx * 90
            let endMs = startMs + 90
            let sSec = startMs / 1_000
            let sRem = startMs % 1_000
            let eSec = endMs / 1_000
            let eRem = endMs % 1_000
            denseSRTCues.append((
                index: idx + 1,
                start: String(format: "00:00:%02d,%03d", sSec, sRem),
                end: String(format: "00:00:%02d,%03d", eSec, eRem),
                text: "Live SRT Tick \(idx)"
            ))
        }
        try writeVerticalSyncSRTSubtitle(at: srtURL, cues: denseSRTCues)

        let animatedASSOneURL = tempDir.appendingPathComponent("animated-one-\(scopeToken).ass")
        let animatedASSTwoURL = tempDir.appendingPathComponent("animated-two-\(scopeToken).ass")
        try writeVerticalSyncASSSubtitle(
            at: animatedASSOneURL,
            cues: [
                (
                    start: "0:00:00.00",
                    end: "0:00:07.80",
                    text: "{\\fad(300,300)\\move(40,320,580,320)}Animated ASS Track One"
                )
            ]
        )
        try writeVerticalSyncASSSubtitle(
            at: animatedASSTwoURL,
            cues: [
                (
                    start: "0:00:00.00",
                    end: "0:00:07.80",
                    text: "{\\fad(300,300)\\move(580,80,40,80)}Animated ASS Track Two"
                )
            ]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        let openGen = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 50,
                subtitleSource: PlaybackSubtitleSource(
                    url: srtURL,
                    format: .srt,
                    matchedVideoURL: videoURL,
                    initialTimestampMilliseconds: 50
                ),
                expectedVideoSize: CGSize(width: 320, height: 180)
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: openGen) != nil
        }
        #expect(!player.isPausedState())
        #expect(container.hasDisplayedSubtitleImageForTesting)

        // 1. SRT -> Animated ASS #1 while actively playing (NO pause!):
        //    Old SRT must keep advancing live during background ASS load, never flash blank, and ASS #1 must commit promptly without chasing-clock starvation.
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.24
        let initialSRTImage = try #require(container.currentSRTSubtitleImage())
        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: animatedASSOneURL,
                format: .ass,
                matchedVideoURL: videoURL
            )
        )
        #expect(player.hasPendingManualSubtitleSwitchForTesting)

        var sawLiveSRTAdvanceDuringStaging = false
        let switch1Deadline = CACurrentMediaTime() + 1.5
        while player.hasPendingManualSubtitleSwitchForTesting && CACurrentMediaTime() < switch1Deadline {
            #expect(!player.isPausedState())
            #expect(container.hasDisplayedSubtitleImageForTesting)
            if let currentSRT = container.currentSRTSubtitleImage(), currentSRT !== initialSRTImage {
                sawLiveSRTAdvanceDuringStaging = true
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!player.hasPendingManualSubtitleSwitchForTesting)
        #expect(sawLiveSRTAdvanceDuringStaging)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentSRTSubtitleImage() == nil)
        let assOneSurface = try #require(container.currentASSSubtitleFrame()?.surface)
        #expect(assOneSurface.destinationY > 90)

        // 2. Animated ASS #1 -> Animated ASS #2 while actively playing:
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0.14
        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: animatedASSTwoURL,
                format: .ass,
                matchedVideoURL: videoURL
            )
        )
        #expect(player.hasPendingManualSubtitleSwitchForTesting)

        let switch2Deadline = CACurrentMediaTime() + 1.5
        while player.hasPendingManualSubtitleSwitchForTesting && CACurrentMediaTime() < switch2Deadline {
            #expect(!player.isPausedState())
            #expect(container.hasDisplayedSubtitleImageForTesting)
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!player.hasPendingManualSubtitleSwitchForTesting)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        let assTwoFrame = try #require(container.currentASSSubtitleFrame())
        let assTwoSurface = try #require(assTwoFrame.surface)
        #expect(assTwoSurface.destinationY < 90)
        ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySecondsForTesting = 0

        // 3. Animated ASS #2 -> SRT while actively playing:
        //    Old animated ASS must continue advancing timestamps live while SRT loads, then swap atomically with zero blank flash.
        SRTSubtitleOverlayView.artificialLoadDelayPathSubstringForTesting = scopeToken
        SRTSubtitleOverlayView.artificialLoadDelaySecondsForTesting = 0.24
        let assTimestampAtSwitch3Start = assTwoFrame.timestampMilliseconds
        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: srtURL,
                format: .srt,
                matchedVideoURL: videoURL
            )
        )
        #expect(player.hasPendingManualSubtitleSwitchForTesting)

        var sawLiveASSAdvanceDuringStaging = false
        let switch3Deadline = CACurrentMediaTime() + 1.5
        while player.hasPendingManualSubtitleSwitchForTesting && CACurrentMediaTime() < switch3Deadline {
            #expect(!player.isPausedState())
            #expect(container.hasDisplayedSubtitleImageForTesting)
            if let liveASSFrame = container.currentASSSubtitleFrame(),
               liveASSFrame.timestampMilliseconds > assTimestampAtSwitch3Start {
                sawLiveASSAdvanceDuringStaging = true
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!player.hasPendingManualSubtitleSwitchForTesting)
        #expect(sawLiveASSAdvanceDuringStaging)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(container.currentSRTSubtitleImage() != nil)
        #expect(container.currentASSSubtitleFrame() == nil)
        #expect(!player.isPausedState())
    }

    @Test
    @MainActor
    func crossResolutionNewVideoOpenAvoidsStalePreviousVideoSizeAndResizesASSSessionInPlace() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let video640URL = tempDir.appendingPathComponent("video-640x360-\(scopeToken).mkv")
        let video480URL = tempDir.appendingPathComponent("video-480x270-\(scopeToken).mkv")
        try makeVerticalSyncTestVideo(
            at: video640URL,
            ffmpegURL: ffmpegURL,
            frameRate: "24",
            durationSeconds: 4,
            videoSize: "640x360"
        )
        try makeVerticalSyncTestVideo(
            at: video480URL,
            ffmpegURL: ffmpegURL,
            frameRate: "24",
            durationSeconds: 4,
            videoSize: "480x270"
        )

        let srt640URL = tempDir.appendingPathComponent("sub-640-\(scopeToken).srt")
        let srt480ExpectedURL = tempDir.appendingPathComponent("sub-480-expected-\(scopeToken).srt")
        let srt480UnknownURL = tempDir.appendingPathComponent("sub-480-unknown-\(scopeToken).srt")
        for (url, label) in [
            (srt640URL, "SRT 640"),
            (srt480ExpectedURL, "SRT 480 Expected"),
            (srt480UnknownURL, "SRT 480 Unknown")
        ] {
            try writeVerticalSyncSRTSubtitle(
                at: url,
                cues: [(index: 1, start: "00:00:00,000", end: "00:00:03,500", text: label)]
            )
        }

        let ass640URL = tempDir.appendingPathComponent("sub-640-\(scopeToken).ass")
        let ass480UnknownURL = tempDir.appendingPathComponent("sub-480-unknown-\(scopeToken).ass")
        let assInPlaceResizeURL = tempDir.appendingPathComponent("sub-inplace-resize-\(scopeToken).ass")
        for (url, label) in [
            (ass640URL, "ASS 640"),
            (ass480UnknownURL, "ASS 480 Unknown"),
            (assInPlaceResizeURL, "ASS In-Place Resize")
        ] {
            try writeVerticalSyncASSSubtitle(
                at: url,
                cues: [(start: "0:00:00.00", end: "0:00:03.50", text: label)]
            )
        }

        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // 1. SRT: 640x360 -> 480x270 with expectedVideoSize builds layout exactly once per open (no stale 640x360 layout).
        let srtGen1 = try player.open(
            PlaybackRequest(
                videoURL: video640URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: srt640URL, format: .srt, matchedVideoURL: video640URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: CGSize(width: 640, height: 360)
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: srtGen1) != nil }
        let srtOverlay = try #require(container.srtOverlayViewForTesting)
        #expect(srtOverlay.layoutBuildCountForTesting == 1)

        let srtGen2 = try player.open(
            PlaybackRequest(
                videoURL: video480URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: srt480ExpectedURL, format: .srt, matchedVideoURL: video480URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: CGSize(width: 480, height: 270)
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: srtGen2) != nil }
        #expect(srtOverlay.layoutBuildCountForTesting == 2)
        #expect(container.currentSRTSubtitleImage() != nil)

        // 2. SRT: 480x270 -> 640x360 -> 480x270 WITHOUT expectedVideoSize waits for actual first frame size instead of laying out twice.
        let srtGen3 = try player.open(
            PlaybackRequest(
                videoURL: video640URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: srt640URL, format: .srt, matchedVideoURL: video640URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: CGSize(width: 640, height: 360)
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: srtGen3) != nil }
        let layoutsBeforeUnindexedSwitch = srtOverlay.layoutBuildCountForTesting

        let srtGen4 = try player.open(
            PlaybackRequest(
                videoURL: video480URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: srt480UnknownURL, format: .srt, matchedVideoURL: video480URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: nil
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: srtGen4) != nil }
        #expect(srtOverlay.layoutBuildCountForTesting == layoutsBeforeUnindexedSwitch + 1)
        #expect(container.currentSRTSubtitleImage() != nil)

        // 3. ASS: 640x360 -> 480x270 WITHOUT expectedVideoSize creates the ASS renderer session once at 480x270 (never at stale 640x360).
        let assGen1 = try player.open(
            PlaybackRequest(
                videoURL: video640URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: ass640URL, format: .ass, matchedVideoURL: video640URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: CGSize(width: 640, height: 360)
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: assGen1) != nil }
        let assOverlay = try #require(container.assOverlayViewForTesting)
        let loadsAfterAss1 = assOverlay.rendererLoadCountForTesting
        let sessionLoadsAfterAss1 = ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount
        #expect(container.currentASSSubtitleFrame()?.frameWidth == 640)
        #expect(container.currentASSSubtitleFrame()?.frameHeight == 360)

        let assGen2 = try player.open(
            PlaybackRequest(
                videoURL: video480URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: ass480UnknownURL, format: .ass, matchedVideoURL: video480URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: nil
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: assGen2) != nil }
        #expect(assOverlay.rendererLoadCountForTesting == loadsAfterAss1 + 1)
        #expect(ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount == sessionLoadsAfterAss1 + 1)
        #expect(container.currentASSSubtitleFrame()?.frameWidth == 480)
        #expect(container.currentASSSubtitleFrame()?.frameHeight == 270)
        #expect(container.currentASSSubtitleFrame()?.surface != nil)

        // 4. ASS in-place canvas resize: when expectedVideoSize (480x270) differs from decoded video frame size (640x360),
        //    and when live videoSize changes later, SFXASSRendererSession resizes in place without recreating or reloading the session!
        let loadsBeforeMismatchOpen = assOverlay.rendererLoadCountForTesting
        let sessionLoadsBeforeMismatchOpen = ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount
        let resizesBeforeMismatchOpen = assOverlay.rendererInPlaceResizeCountForTesting

        let assGen3 = try player.open(
            PlaybackRequest(
                videoURL: video640URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(url: assInPlaceResizeURL, format: .ass, matchedVideoURL: video640URL, initialTimestampMilliseconds: 200),
                expectedVideoSize: CGSize(width: 480, height: 270)
            )
        )
        try await waitForVerticalSyncCondition { delegateSpy.commit(forGeneration: assGen3) != nil }
        #expect(assOverlay.rendererLoadCountForTesting == loadsBeforeMismatchOpen + 1)
        #expect(ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount == sessionLoadsBeforeMismatchOpen + 1)
        #expect(assOverlay.rendererInPlaceResizeCountForTesting == resizesBeforeMismatchOpen + 1)
        #expect(container.currentASSSubtitleFrame()?.frameWidth == 640)
        #expect(container.currentASSSubtitleFrame()?.frameHeight == 360)
        #expect(container.currentASSSubtitleFrame()?.surface != nil)

        try player.setPaused(true)
        let workerBeforeDirectResize = assOverlay.rendererWorkerIdentityForTesting
        container.setVideoSize(CGSize(width: 960, height: 540))
        try await waitForVerticalSyncCondition {
            container.currentASSSubtitleFrame()?.frameWidth == 960
                && container.currentASSSubtitleFrame()?.frameHeight == 540
                && container.currentASSSubtitleFrame()?.surface != nil
        }
        #expect(assOverlay.rendererWorkerIdentityForTesting == workerBeforeDirectResize)
        #expect(assOverlay.rendererLoadCountForTesting == loadsBeforeMismatchOpen + 1)
        #expect(ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount == sessionLoadsBeforeMismatchOpen + 1)
    }

    @Test
    @MainActor
    func nonDefaultEventsFormatOrderRendersFirstAndSecondWindowsAcrossIndexedAndFallbackPaths() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let mediaDir = tempDir.appendingPathComponent("CustomFormatMedia-\(scopeToken)", isDirectory: true)
        let dbDir = tempDir.appendingPathComponent("CustomFormatDB-\(scopeToken)", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let databaseURL = dbDir.appendingPathComponent("CueSeeker.sqlite")

        let ssaVideoURL = mediaDir.appendingPathComponent("ClassicSSA.mkv")
        let ssaSubtitleURL = mediaDir.appendingPathComponent("ClassicSSA.ssa")
        let shuffledVideoURL = mediaDir.appendingPathComponent("ShuffledFormat.mkv")
        let shuffledSubtitleURL = mediaDir.appendingPathComponent("ShuffledFormat.ass")

        try makeVerticalSyncTestVideo(at: ssaVideoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 10)
        try makeVerticalSyncTestVideo(at: shuffledVideoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 10)

        let ssaScript = """
        [Script Info]
        Title: Classic SSA Custom Format
        ScriptType: v4.00
        PlayResX: 640
        PlayResY: 360

        [V4 Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, TertiaryColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, AlphaLevel, Encoding
        Style: Default,Helvetica,36,16777215,65535,0,0,0,0,1,2,1,2,20,20,24,0,1

        [Events]
        Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: Marked=0,0:00:00.20,0:00:03.80,Default,Actor,0000,0000,0000,,SSA First Window Visible Text
        Dialogue: Marked=0,0:00:06.00,0:00:09.20,Default,Actor,0000,0000,0000,,SSA Second Window Visible Text
        """
        try Data(ssaScript.utf8).write(to: ssaSubtitleURL)

        // Custom column order where Start=col0, End=col1, Layer=col2, Style=col8, Text=col9.
        // If Window 1 wiped event_format back to libass defaults (Layer, Start, End, Style, ...),
        // "0:00:00.20" would be parsed as Layer=0, "0:00:03.80" as Start, and "0" as End (Duration <= 0 -> blank!).
        let shuffledASSScript = """
        [Script Info]
        Title: Shuffled Columns ASS
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: CustomMain,Helvetica,36,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Events]
        Format: Start, End, Layer, Effect, MarginV, MarginR, MarginL, Name, Style, Text
        Dialogue: 0:00:00.20,0:00:03.80,0,,24,20,20,Narrator,CustomMain,Shuffled First Window Visible Text
        Dialogue: 0:00:06.00,0:00:09.20,0,,24,20,20,Narrator,CustomMain,Shuffled Second Window Visible Text
        """
        try Data(shuffledASSScript.utf8).write(to: shuffledSubtitleURL)

        try DatabaseBootstrap.prepare(at: databaseURL)
        do {
            let indexingDB = try IndexingDatabase(path: databaseURL)
            let indexResult = try SubtitleIndexer().index(folder: mediaDir, into: indexingDB)
            #expect(indexResult.indexedSubtitleFiles == 2)
            #expect(indexResult.failedFiles.isEmpty)
        }

        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        let cacheReader = PlaybackSubtitleRenderCacheReader(databaseURL: databaseURL)

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        for (videoURL, subtitleURL) in [
            (ssaVideoURL, ssaSubtitleURL),
            (shuffledVideoURL, shuffledSubtitleURL)
        ] {
            // A. Indexed partial-loading path: Window 1 (500ms) and Window 2 (6_500ms) both render visible pixels.
            let indexedBefore = ASSIndexedPartialLoadDiagnostics.snapshot.indexedSessionLoadCount
            let indexedOpenGen = try player.open(
                PlaybackRequest(
                    videoURL: videoURL,
                    startMilliseconds: 500,
                    subtitleSource: PlaybackSubtitleSource(
                        url: subtitleURL,
                        format: .ass,
                        matchedVideoURL: videoURL,
                        initialTimestampMilliseconds: 500,
                        renderCacheProvider: cacheReader
                    ),
                    expectedVideoSize: CGSize(width: 160, height: 90)
                )
            )
            try await waitForVerticalSyncCondition {
                delegateSpy.commit(forGeneration: indexedOpenGen) != nil
            }
            #expect(ASSIndexedPartialLoadDiagnostics.snapshot.indexedSessionLoadCount == indexedBefore + 1)
            let indexedWindowOneSurface = try #require(container.currentASSSubtitleFrame()?.surface)
            #expect(indexedWindowOneSurface.width > 0 && indexedWindowOneSurface.height > 0)

            let indexedWindowTwoGen = try player.seek(toMilliseconds: 6_500, pauseAfterFirstFrame: true)
            try await waitForVerticalSyncCondition {
                delegateSpy.commit(forGeneration: indexedWindowTwoGen) != nil
            }
            let indexedWindowTwoSurface = try #require(container.currentASSSubtitleFrame()?.surface)
            #expect(indexedWindowTwoSurface.width > 0 && indexedWindowTwoSurface.height > 0)

            // B. Unindexed full-fallback windowed path: Window 1 (500ms) and Window 2 (6_500ms) both render visible pixels.
            let fallbackBefore = ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount
            let fallbackOpenGen = try player.open(
                PlaybackRequest(
                    videoURL: videoURL,
                    startMilliseconds: 500,
                    subtitleSource: PlaybackSubtitleSource(
                        url: subtitleURL,
                        format: .ass,
                        matchedVideoURL: videoURL,
                        initialTimestampMilliseconds: 500,
                        renderCacheProvider: nil
                    ),
                    expectedVideoSize: CGSize(width: 160, height: 90)
                )
            )
            try await waitForVerticalSyncCondition {
                delegateSpy.commit(forGeneration: fallbackOpenGen) != nil
            }
            #expect(ASSIndexedPartialLoadDiagnostics.snapshot.fullFallbackSessionLoadCount == fallbackBefore + 1)
            let fallbackWindowOneSurface = try #require(container.currentASSSubtitleFrame()?.surface)
            #expect(fallbackWindowOneSurface.width > 0 && fallbackWindowOneSurface.height > 0)

            let fallbackWindowTwoGen = try player.seek(toMilliseconds: 6_500, pauseAfterFirstFrame: true)
            try await waitForVerticalSyncCondition {
                delegateSpy.commit(forGeneration: fallbackWindowTwoGen) != nil
            }
            let fallbackWindowTwoSurface = try #require(container.currentASSSubtitleFrame()?.surface)
            #expect(fallbackWindowTwoSurface.width > 0 && fallbackWindowTwoSurface.height > 0)
        }
    }

    @Test
    @MainActor
    func rapidConsecutiveEpisodeOpensDeterministicallyReuseWarmedEngine() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        ASSFontAliasResolver.shared.resetForTesting()
        PlaybackPlayer.resetASSEnginePoolForTesting()
        PlaybackPlayer.warmUpSubtitleEnvironment()
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)

        let episodeCount = 5
        var episodes: [(videoURL: URL, assURL: URL)] = []
        for idx in 1...episodeCount {
            let videoURL = tempDir.appendingPathComponent("rapid-ep\(idx).mkv")
            let assURL = tempDir.appendingPathComponent("rapid-ep\(idx).ass")
            try makeVerticalSyncTestVideo(at: videoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 2)
            try writeVerticalSyncASSSubtitle(
                at: assURL,
                cues: [(start: "0:00:00.05", end: "0:00:01.80", text: "Rapid Jump Episode \(idx)")]
            )
            episodes.append((videoURL: videoURL, assURL: assURL))
        }

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        var lastGeneration: UInt = 0
        for episode in episodes {
            lastGeneration = try player.open(
                PlaybackRequest(
                    videoURL: episode.videoURL,
                    startMilliseconds: 300,
                    subtitleSource: PlaybackSubtitleSource(
                        url: episode.assURL,
                        format: .ass,
                        matchedVideoURL: episode.videoURL,
                        initialTimestampMilliseconds: 300
                    )
                )
            )
        }

        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: lastGeneration) != nil
        }
        #expect(delegateSpy.commit(forGeneration: lastGeneration)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)
    }

    @Test
    @MainActor
    func fullFallbackEmptyFontsSectionReusesPoolWhileEmbeddedFontsIsolateWithoutPollutingPool() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        ASSFontAliasResolver.shared.resetForTesting()
        PlaybackPlayer.resetASSEnginePoolForTesting()
        PlaybackPlayer.warmUpSubtitleEnvironment()
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)

        let videoOneURL = tempDir.appendingPathComponent("fonts-empty.mkv")
        let videoTwoURL = tempDir.appendingPathComponent("fonts-embedded.mkv")
        let videoThreeURL = tempDir.appendingPathComponent("fonts-normal.mkv")
        try makeVerticalSyncTestVideo(at: videoOneURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 2)
        try makeVerticalSyncTestVideo(at: videoTwoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 2)
        try makeVerticalSyncTestVideo(at: videoThreeURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 2)

        let emptyFontsASSURL = tempDir.appendingPathComponent("empty-fonts-placeholder.ass")
        let emptyFontsScript = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Fonts]
        ; empty section before Events
        !: legacy template comment

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.10,0:00:01.80,Default,,0,0,0,,Empty Fonts Placeholder Visible

        [Fonts]
        ; trailing empty section at EOF
        !: ignored comment line
          
        """
        try emptyFontsScript.write(to: emptyFontsASSURL, atomically: true, encoding: .utf8)

        let embeddedFontsASSURL = tempDir.appendingPathComponent("real-embedded-fonts.ass")
        let embeddedFontsScript = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Fonts]
        fontname: TestEmbeddedPlaceholder.ttf
        !!

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.10,0:00:01.80,Default,,0,0,0,,Embedded Fonts Isolated Visible
        """
        try embeddedFontsScript.write(to: embeddedFontsASSURL, atomically: true, encoding: .utf8)

        let normalASSURL = tempDir.appendingPathComponent("normal-after-embedded.ass")
        try writeVerticalSyncASSSubtitle(
            at: normalASSURL,
            cues: [(start: "0:00:00.10", end: "0:00:01.80", text: "Normal Reuse After Embedded")]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // 1. Empty [Fonts] section on full-fallback path (no renderCacheProvider) must still reuse the warmed pooled engine (count == 1).
        let emptySource = PlaybackSubtitleSource(
            url: emptyFontsASSURL,
            format: .ass,
            matchedVideoURL: videoOneURL,
            initialTimestampMilliseconds: 300
        )
        #expect(emptySource.renderCacheProvider == nil)
        let emptyGen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 300,
                subtitleSource: emptySource
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: emptyGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: emptyGen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)

        // 2. Non-empty [Fonts] payload must bypass the shared pool and allocate a dedicated engine (+1 -> 2).
        let embeddedGen = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: embeddedFontsASSURL,
                    format: .ass,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: embeddedGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: embeddedGen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 2)

        // 3. Subsequent normal ASS destroys the dedicated engine cleanly and reuses the unpolluted pooled engine (still 2).
        let normalGen = try player.open(
            PlaybackRequest(
                videoURL: videoThreeURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: normalASSURL,
                    format: .ass,
                    matchedVideoURL: videoThreeURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: normalGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: normalGen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 2)
    }

    @Test
    @MainActor
    func fontEnvironmentInvalidationRetiresBorrowedEngineAndRebuildsCleanPoolOnNextOpen() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        defer {
            ASSFontAliasResolver.shared.resetForTesting()
            PlaybackPlayer.resetASSEnginePoolForTesting()
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        ASSFontAliasResolver.shared.resetForTesting()
        PlaybackPlayer.resetASSEnginePoolForTesting()
        PlaybackPlayer.warmUpSubtitleEnvironment()
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)

        let videoOneURL = tempDir.appendingPathComponent("invalidate-ep1.mkv")
        let videoTwoURL = tempDir.appendingPathComponent("invalidate-ep2.mkv")
        let videoThreeURL = tempDir.appendingPathComponent("invalidate-ep3.mkv")
        try makeVerticalSyncTestVideo(at: videoOneURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 3)
        try makeVerticalSyncTestVideo(at: videoTwoURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 3)
        try makeVerticalSyncTestVideo(at: videoThreeURL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 3)

        let assEp1URL = tempDir.appendingPathComponent("invalidate-ep1.ass")
        let assEp2URL = tempDir.appendingPathComponent("invalidate-ep2.ass")
        let assEp3URL = tempDir.appendingPathComponent("invalidate-ep3.ass")
        try writeVerticalSyncASSSubtitle(
            at: assEp1URL,
            cues: [(start: "0:00:00.10", end: "0:00:02.80", text: "Invalidation Episode 1")]
        )
        try writeVerticalSyncASSSubtitle(
            at: assEp2URL,
            cues: [(start: "0:00:00.10", end: "0:00:02.80", text: "Invalidation Episode 2")]
        )
        try writeVerticalSyncASSSubtitle(
            at: assEp3URL,
            cues: [(start: "0:00:00.10", end: "0:00:02.80", text: "Invalidation Episode 3")]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        // 1. Open Episode 1 (borrows the warmed pooled engine).
        let ep1Gen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp1URL,
                    format: .ass,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep1Gen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep1Gen)?.hasASSVisibleSurface == true)

        // 2. Refreshing an isolated non-shared resolver must NOT invalidate the shared renderer pool.
        let isolatedResolver = ASSFontAliasResolver(observeSystemFontChanges: false)
        isolatedResolver.warmUp()
        isolatedResolver.markEnvironmentNeedsRefresh()

        let ep2Gen = try player.open(
            PlaybackRequest(
                videoURL: videoTwoURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp2URL,
                    format: .ass,
                    matchedVideoURL: videoTwoURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep2Gen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep2Gen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 1)

        // 3. While Episode 2 holds the borrowed pooled engine, broadcast a system font registration change.
        NotificationCenter.default.post(
            name: NSNotification.Name(kCTFontManagerRegisteredFontsChangedNotification as String),
            object: nil
        )

        // Active Episode 2 continues rendering cleanly with its checked-out old-generation engine.
        let ep2SeekGen = try player.seek(toMilliseconds: 1_200, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep2SeekGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep2SeekGen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 1)

        // 4. Opening Episode 3 destroys Episode 2's stale engine on close and builds exactly +1 fresh generation engine.
        let ep3Gen = try player.open(
            PlaybackRequest(
                videoURL: videoThreeURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp3URL,
                    format: .ass,
                    matchedVideoURL: videoThreeURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep3Gen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep3Gen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 2)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 2)

        // 5. Subsequent switch back to Episode 1 reuses the newly created pooled generation without extra init.
        let ep1ReuseGen = try player.open(
            PlaybackRequest(
                videoURL: videoOneURL,
                startMilliseconds: 300,
                subtitleSource: PlaybackSubtitleSource(
                    url: assEp1URL,
                    format: .ass,
                    matchedVideoURL: videoOneURL,
                    initialTimestampMilliseconds: 300
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: ep1ReuseGen) != nil
        }
        #expect(delegateSpy.commit(forGeneration: ep1ReuseGen)?.hasASSVisibleSurface == true)
        #expect(PlaybackPlayer.assEngineInitializationCountForTesting == 2)
        #expect(ASSFontAliasResolver.shared.snapshotScanCountForTesting == 2)
    }

    @Test
    @MainActor
    func animatedASSSubtitleOverlayMicroOffsetTimingAAndTimingBAndRefinement() async throws {
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let assURL = tempDir.appendingPathComponent("animated-micro-offset.ass")
        try writeVerticalSyncASSSubtitle(
            at: assURL,
            cues: [
                (start: "0:00:00.50", end: "0:00:03.50", text: "{\\fad(120,120)\\move(60,300,320,300)}Animated Micro Offset")
            ]
        )

        let recorder = MicroOffsetTelemetrySpy()
        PlaybackSubtitleFirstFrameTelemetry.setTestObserver { event in
            recorder.recordFirstFrame(event)
        }

        let overlay = SourceFaithfulASSSubtitleOverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        let targetVideoSize = CGSize(width: 640, height: 360)
        let source = PlaybackSubtitleSource(
            url: assURL,
            format: .ass,
            matchedVideoURL: nil,
            initialTimestampMilliseconds: 1_100
        )

        // Timing A: Render #1 at t_staged (1100ms) completes BEFORE retargetDeferredPresentation to t_actual (1138ms).
        overlay.defersLayerPresentation = true
        let attemptA = PlaybackSubtitleFirstFrameAttempt(
            trigger: .sameVideoSeek,
            source: source,
            targetMilliseconds: 1_100,
            presentationGeneration: 101,
            videoCommittedAt: nil
        )
        let initialStateA = overlay.setPresentation(
            source: source,
            videoSize: targetVideoSize,
            milliseconds: 1_100,
            isVisible: true,
            telemetryAttempt: attemptA
        )
        #expect(initialStateA == .asyncPending)

        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_100, videoSize: targetVideoSize)
        }
        #expect(overlay.rendererRenderDispatchCountForTesting == 1)
        #expect(overlay.rendererRenderCompletionCountForTesting == 1)

        attemptA.updateTargetMilliseconds(1_138)
        overlay.retargetDeferredPresentation(videoSize: targetVideoSize, milliseconds: 1_138)
        #expect(!overlay.isRenderInFlightForTesting)
        #expect(overlay.pendingTimestampMillisecondsForTesting == nil)
        #expect(overlay.rendererRenderDispatchCountForTesting == 1)
        #expect(overlay.isPreparedForPresentation(atMilliseconds: 1_138, videoSize: targetVideoSize))
        #expect(recorder.firstFrameEvents.isEmpty)

        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.hasDisplayedSubtitleImage)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_100)
        #expect(overlay.rendererRenderCompletionCountForTesting == 1)
        #expect(overlay.layerClearCountForTesting == 0)
        #expect(recorder.firstFrameEvents.count == 1)
        #expect(recorder.firstFrameEvents.last?.isSynchronousAtCommit == true)
        #expect(recorder.firstFrameEvents.last?.lagMilliseconds == 0)
        #expect(recorder.firstFrameEvents.last?.targetMilliseconds == 1_138)

        // Wait for background in-place refinement to snap from 1100ms to exact 1138ms without flashing or re-emitting telemetry.
        try await waitForVerticalSyncCondition {
            overlay.rendererRenderCompletionCountForTesting >= 2 && !overlay.isRenderInFlightForTesting
        }
        #expect(overlay.rendererRenderDispatchCountForTesting == 2)
        #expect(overlay.hasDisplayedSubtitleImage)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_138)
        #expect(overlay.layerClearCountForTesting == 0)
        #expect(recorder.firstFrameEvents.count == 1)

        // Timing B: Render #1 at t_staged (1600ms) is still in flight when retargetDeferredPresentation queues 1642ms.
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        ASSIndexedPartialLoadDiagnostics.artificialRenderDelaySecondsForTesting = 0.18

        var preparedCallbackFired = false
        overlay.onPreparedFrameReady = {
            preparedCallbackFired = true
        }

        let baselineDispatchesB = overlay.rendererRenderDispatchCountForTesting
        let baselineCompletionsB = overlay.rendererRenderCompletionCountForTesting
        overlay.defersLayerPresentation = true
        let attemptB = PlaybackSubtitleFirstFrameAttempt(
            trigger: .sameVideoSeek,
            source: source,
            targetMilliseconds: 1_600,
            presentationGeneration: 102,
            videoCommittedAt: nil
        )
        let stateB = overlay.commitPreservedPresentation(
            videoSize: targetVideoSize,
            milliseconds: 1_600,
            attempt: attemptB
        )
        #expect(stateB == .asyncPending)
        #expect(overlay.isRenderInFlightForTesting)

        attemptB.updateTargetMilliseconds(1_642)
        overlay.retargetDeferredPresentation(videoSize: targetVideoSize, milliseconds: 1_642)
        #expect(overlay.pendingTimestampMillisecondsForTesting == 1_642)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 1_642, videoSize: targetVideoSize))

        try await waitForVerticalSyncCondition {
            preparedCallbackFired && overlay.isPreparedForPresentation(atMilliseconds: 1_642, videoSize: targetVideoSize)
        }
        #expect(overlay.pendingTimestampMillisecondsForTesting == nil)
        #expect(overlay.currentTimeMilliseconds == 1_642)
        #expect(overlay.rendererRenderDispatchCountForTesting - baselineDispatchesB == 1)
        #expect(overlay.rendererRenderCompletionCountForTesting - baselineCompletionsB == 1)

        ASSIndexedPartialLoadDiagnostics.artificialRenderDelaySecondsForTesting = 0
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.hasDisplayedSubtitleImage)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_600)
        #expect(overlay.rendererRenderCompletionCountForTesting - baselineCompletionsB == 1)
        #expect(overlay.layerClearCountForTesting == 0)
        #expect(recorder.firstFrameEvents.count == 2)
        #expect(recorder.firstFrameEvents.last?.isSynchronousAtCommit == true)
        #expect(recorder.firstFrameEvents.last?.lagMilliseconds == 0)
        #expect(recorder.firstFrameEvents.last?.targetMilliseconds == 1_642)

        try await waitForVerticalSyncCondition {
            overlay.rendererRenderCompletionCountForTesting >= baselineCompletionsB + 2 && !overlay.isRenderInFlightForTesting
        }
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_642)
        #expect(overlay.layerClearCountForTesting == 0)
        #expect(recorder.firstFrameEvents.count == 2)

        // Verify commitPreservedPresentation reliably renders when currentTimeMilliseconds already equals target
        // while the cached frame still sits at a different timestamp and does not cover target.
        overlay.onPreparedFrameReady = nil
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: targetVideoSize, milliseconds: 2_160, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 2_160, videoSize: targetVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: targetVideoSize, milliseconds: 2_200)
        #expect(overlay.currentTimeMilliseconds == 2_200)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_642)

        let baselineSameTimeDispatches = overlay.rendererRenderDispatchCountForTesting
        let sameTimeAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .sameVideoSeek,
            source: source,
            targetMilliseconds: 2_200,
            presentationGeneration: 103,
            videoCommittedAt: nil
        )
        let sameTimeState = overlay.commitPreservedPresentation(
            videoSize: targetVideoSize,
            milliseconds: 2_200,
            attempt: sameTimeAttempt
        )
        #expect(sameTimeState == .asyncPending)
        #expect(overlay.rendererRenderDispatchCountForTesting == baselineSameTimeDispatches + 1)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 2_200, videoSize: targetVideoSize)
        }
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 2_200)
        #expect(recorder.firstFrameEvents.count == 3)
    }

    @Test
    @MainActor
    func animatedASSSubtitleOverlayRejectsCrossBoundaryOverThresholdAndResolutionChange() async throws {
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let assURL = tempDir.appendingPathComponent("animated-boundaries.ass")
        try writeVerticalSyncASSSubtitle(
            at: assURL,
            cues: [
                (start: "0:00:01.00", end: "0:00:04.00", text: "{\\move(80,300,260,300)}Primary Line"),
                (start: "0:00:02.00", end: "0:00:03.50", text: "Overlay Line")
            ]
        )

        let overlay = SourceFaithfulASSSubtitleOverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        let baseVideoSize = CGSize(width: 640, height: 360)
        let source = PlaybackSubtitleSource(
            url: assURL,
            format: .ass,
            matchedVideoURL: nil,
            initialTimestampMilliseconds: 980
        )

        // 1. Blank (980ms) -> Cue 1 start at 1000ms (1010ms, only +30ms): must NOT reuse blank frame.
        overlay.defersLayerPresentation = true
        _ = overlay.setPresentation(
            source: source,
            videoSize: baseVideoSize,
            milliseconds: 980,
            isVisible: true,
            telemetryAttempt: nil
        )
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 980, videoSize: baseVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 1_010)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 1_010, videoSize: baseVideoSize))
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_010, videoSize: baseVideoSize)
        }
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.hasDisplayedSubtitleImage)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_010)

        // 2. Cue 1 only (1980ms) -> Overlay Cue 2 start at 2000ms (2015ms, only +35ms): must NOT reuse single-line frame.
        let beforeOverlapCompletions = overlay.rendererRenderCompletionCountForTesting
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 1_980, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_980, videoSize: baseVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 2_015)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 2_015, videoSize: baseVideoSize))
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 2_015, videoSize: baseVideoSize)
        }
        #expect(overlay.rendererRenderCompletionCountForTesting - beforeOverlapCompletions >= 2)
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 2_015)

        // 3. Cue 1 tail (3980ms) -> Blank at 4000ms (4010ms, only +30ms): must NOT keep subtitle into blank gap.
        let beforeBlankCompletions = overlay.rendererRenderCompletionCountForTesting
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 3_980, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 3_980, videoSize: baseVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 4_010)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 4_010, videoSize: baseVideoSize))
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 4_010, videoSize: baseVideoSize)
        }
        #expect(overlay.rendererRenderCompletionCountForTesting - beforeBlankCompletions >= 2)
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(!overlay.hasDisplayedSubtitleImage)
        #expect(overlay.currentPresentationFrame()?.surface == nil)

        // 4. Same active set [1000, 2000): exact +50ms is tolerated, +51ms (Timing A and Timing B) and -51ms are rejected.
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 1_200, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_200, videoSize: baseVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 1_250)
        #expect(overlay.isPreparedForPresentation(atMilliseconds: 1_250, videoSize: baseVideoSize))
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        try await waitForVerticalSyncCondition { !overlay.isRenderInFlightForTesting }

        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 1_200, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_200, videoSize: baseVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 1_251)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 1_251, videoSize: baseVideoSize))
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_251, videoSize: baseVideoSize)
        }
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)

        // Negative > 50ms (-51ms) rejected too.
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 1_200, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_200, videoSize: baseVideoSize)
        }
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 1_149)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 1_149, videoSize: baseVideoSize))
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_149, videoSize: baseVideoSize)
        }
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)

        // Timing B with > 50ms offset must queue and wait for Render #2 instead of skipping it.
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        ASSIndexedPartialLoadDiagnostics.artificialRenderDelaySecondsForTesting = 0.14
        let baselineTimingBOverCompletions = overlay.rendererRenderCompletionCountForTesting
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 1_200, attempt: nil)
        overlay.retargetDeferredPresentation(videoSize: baseVideoSize, milliseconds: 1_280)
        #expect(overlay.pendingTimestampMillisecondsForTesting == 1_280)
        ASSIndexedPartialLoadDiagnostics.artificialRenderDelaySecondsForTesting = 0
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_280, videoSize: baseVideoSize)
        }
        #expect(overlay.rendererRenderCompletionCountForTesting - baselineTimingBOverCompletions >= 2)
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_280)

        // 5. Video resolution change during retargetDeferredPresentation must invalidate staged slot despite <= 50ms offset.
        overlay.defersLayerPresentation = true
        _ = overlay.commitPreservedPresentation(videoSize: baseVideoSize, milliseconds: 1_200, attempt: nil)
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_200, videoSize: baseVideoSize)
        }
        let resizeTarget = CGSize(width: 1_280, height: 720)
        let beforeResizeCount = overlay.rendererInPlaceResizeCountForTesting
        overlay.retargetDeferredPresentation(videoSize: resizeTarget, milliseconds: 1_220)
        #expect(overlay.rendererInPlaceResizeCountForTesting == beforeResizeCount + 1)
        #expect(!overlay.isPreparedForPresentation(atMilliseconds: 1_220, videoSize: resizeTarget))
        try await waitForVerticalSyncCondition {
            overlay.isPreparedForPresentation(atMilliseconds: 1_220, videoSize: resizeTarget)
        }
        overlay.flushDeferredLayerPresentation(isSynchronousCommit: true)
        #expect(overlay.currentPresentationFrame()?.frameWidth == 1_280)
        #expect(overlay.currentPresentationFrame()?.frameHeight == 720)
        #expect(overlay.currentPresentationFrame()?.timestampMilliseconds == 1_220)
    }

    @Test
    @MainActor
    func e2ePlaybackPlayerAnimatedASSSubtitleMicroOffsetSyncCommitAndRefinement() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        let scopeToken = tempDir.lastPathComponent
        defer {
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("ntsc-micro-offset.mkv")
        let assURL = tempDir.appendingPathComponent("ntsc-micro-offset.ass")
        try makeVerticalSyncTestVideo(
            at: videoURL,
            ffmpegURL: ffmpegURL,
            frameRate: "24000/1001",
            durationSeconds: 4
        )
        try writeVerticalSyncASSSubtitle(
            at: assURL,
            cues: [
                (start: "0:00:00.50", end: "0:00:03.50", text: "{\\fad(120,120)\\move(80,300,300,300)}E2E Animated Cue")
            ]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)

        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        let recorder = MicroOffsetTelemetrySpy()
        recorder.attach(to: container)

        let source = PlaybackSubtitleSource(
            url: assURL,
            format: .ass,
            matchedVideoURL: videoURL,
            initialTimestampMilliseconds: 500
        )

        // Open initially so video dimensions & font session are ready for seek benchmarks.
        let openGen = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 500,
                subtitleSource: source
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: openGen) != nil
        }
        let overlay = try #require(container.assOverlayViewForTesting)
        try await waitForVerticalSyncCondition { !overlay.isRenderInFlightForTesting }

        // 1. Natural seek to 1_010ms (23.976fps naturally aligns next video frame around ~1_042ms, +32ms <= 50ms):
        //    must commit synchronously on Render #1 (syncReady, lag == 0) then refine to commit.milliseconds in place.
        recorder.resetFirstFrameEvents()
        let seek1BaselineCompletions = overlay.rendererRenderCompletionCountForTesting
        let seek1Gen = try player.seek(toMilliseconds: 1_010, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: seek1Gen) != nil
        }
        let seek1Commit = try #require(delegateSpy.commit(forGeneration: seek1Gen))
        let seek1TelemetryAtCommit = try #require(recorder.commitSnapshot(forGeneration: seek1Gen))
        #expect(seek1Commit.milliseconds > 1_010 && seek1Commit.milliseconds <= 1_060)
        #expect(seek1Commit.hasASSVisibleSurface)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(seek1TelemetryAtCommit.event.subtitleSyncState == .syncReady)
        #expect(seek1TelemetryAtCommit.completionCount - seek1BaselineCompletions == 1)

        try await waitForVerticalSyncCondition {
            overlay.rendererRenderCompletionCountForTesting >= seek1BaselineCompletions + 2
                && !overlay.isRenderInFlightForTesting
        }
        #expect(container.currentASSSubtitleFrame()?.timestampMilliseconds == seek1Commit.milliseconds)
        #expect(overlay.layerClearCountForTesting == seek1TelemetryAtCommit.clearCount)
        let seek1FirstFrameEvents = recorder.firstFrameEvents.filter { $0.presentationGeneration == seek1Gen }
        #expect(seek1FirstFrameEvents.count == 1)
        #expect(seek1FirstFrameEvents.first?.isSynchronousAtCommit == true)
        #expect(seek1FirstFrameEvents.first?.lagMilliseconds == 0)

        // 2. Forced Timing B seek to 1_510ms (video frame around ~1_543ms finishes decoding BEFORE delayed libass render #1):
        //    gate must still commit immediately once Render #1 returns, without waiting for Render #2.
        ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = scopeToken
        ASSIndexedPartialLoadDiagnostics.artificialRenderDelaySecondsForTesting = 0.22
        let seek2BaselineCompletions = overlay.rendererRenderCompletionCountForTesting
        let seek2Gen = try player.seek(toMilliseconds: 1_510, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: seek2Gen) != nil
        }
        ASSIndexedPartialLoadDiagnostics.artificialRenderDelaySecondsForTesting = 0

        let seek2Commit = try #require(delegateSpy.commit(forGeneration: seek2Gen))
        let seek2TelemetryAtCommit = try #require(recorder.commitSnapshot(forGeneration: seek2Gen))
        #expect(seek2Commit.milliseconds > 1_510 && seek2Commit.milliseconds <= 1_560)
        #expect(seek2Commit.hasASSVisibleSurface)
        #expect(container.hasDisplayedSubtitleImageForTesting)
        #expect(seek2TelemetryAtCommit.event.subtitleSyncState == .syncReady)
        #expect(seek2TelemetryAtCommit.completionCount - seek2BaselineCompletions == 1)

        try await waitForVerticalSyncCondition {
            overlay.rendererRenderCompletionCountForTesting >= seek2BaselineCompletions + 2
                && !overlay.isRenderInFlightForTesting
        }
        #expect(container.currentASSSubtitleFrame()?.timestampMilliseconds == seek2Commit.milliseconds)
        #expect(overlay.layerClearCountForTesting == seek2TelemetryAtCommit.clearCount)
        let seek2FirstFrameEvents = recorder.firstFrameEvents.filter { $0.presentationGeneration == seek2Gen }
        #expect(seek2FirstFrameEvents.count == 1)
        #expect(seek2FirstFrameEvents.first?.isSynchronousAtCommit == true)
        #expect(seek2FirstFrameEvents.first?.lagMilliseconds == 0)
    }

    @Test
    @MainActor
    func e2ePlaybackPlayerRejectsCrossBoundaryAndOverThresholdWhilePreservingRepeat2msAlignment() async throws {
        let ffmpegURL = try #require(verticalSyncTestFFmpegURL())
        let tempDir = try makeVerticalSyncTempDirectory()
        defer {
            ASSIndexedPartialLoadDiagnostics.resetForTesting()
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Part A (24fps MKV): Frame 23 = 958ms (2ms before 960ms Repeat start), Frame 48 = 2_000ms (Cue 3 boundary).
        let video24URL = tempDir.appendingPathComponent("fps24-boundary.mkv")
        let assBoundaryURL = tempDir.appendingPathComponent("fps24-boundary.ass")
        try makeVerticalSyncTestVideo(at: video24URL, ffmpegURL: ffmpegURL, frameRate: "24", durationSeconds: 4)
        try writeVerticalSyncASSSubtitle(
            at: assBoundaryURL,
            cues: [
                (start: "0:00:00.10", end: "0:00:00.96", text: "{\\move(60,300,140,300)}Sentence One"),
                (start: "0:00:00.96", end: "0:00:03.00", text: "{\\move(80,300,260,300)}Sentence Two Repeat"),
                (start: "0:00:02.00", end: "0:00:02.80", text: "Sentence Three Overlap")
            ]
        )

        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = try #require(player.renderView as? PlaybackRenderContainerView)
        container.frame = CGRect(x: 0, y: 0, width: 640, height: 360)

        let delegateSpy = VerticalSyncPlayerDelegateSpy(container: container)
        player.delegate = delegateSpy

        let recorder = MicroOffsetTelemetrySpy()
        recorder.attach(to: container)

        let open24Gen = try player.open(
            PlaybackRequest(
                videoURL: video24URL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(
                    url: assBoundaryURL,
                    format: .ass,
                    matchedVideoURL: video24URL,
                    initialTimestampMilliseconds: 200
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: open24Gen) != nil
        }
        let overlay24 = try #require(container.assOverlayViewForTesting)
        try await waitForVerticalSyncCondition { !overlay24.isRenderInFlightForTesting }

        // 1. Repeat sentence-2 start at 960ms: raw frame 958ms (0 <= 960 - 958 <= 2ms) aligns to 960ms.
        let repeatGen = try player.seek(toMilliseconds: 960, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: repeatGen) != nil
        }
        let repeatCommit = try #require(delegateSpy.commit(forGeneration: repeatGen))
        #expect(repeatCommit.milliseconds == 960)
        #expect(repeatCommit.hasASSVisibleSurface)
        try await waitForVerticalSyncCondition { !overlay24.isRenderInFlightForTesting }
        #expect(container.currentASSSubtitleFrame()?.timestampMilliseconds == 960)

        // 2. Cross-boundary seek (1_985ms -> frame lands at 2_000ms crossing Sentence Three Start):
        //    must block for Render #2 instead of reusing the pre-overlap 1_985ms frame.
        let boundaryBaseline = overlay24.rendererRenderCompletionCountForTesting
        let boundaryGen = try player.seek(toMilliseconds: 1_985, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: boundaryGen) != nil
        }
        let boundaryCommit = try #require(delegateSpy.commit(forGeneration: boundaryGen))
        #expect(boundaryCommit.milliseconds == 2_000)
        #expect(boundaryCommit.hasASSVisibleSurface)
        let boundaryCompletionAtCommit = try #require(recorder.commitSnapshot(forGeneration: boundaryGen)?.completionCount)
        #expect(boundaryCompletionAtCommit - boundaryBaseline >= 2)
        #expect(container.currentASSSubtitleFrame()?.timestampMilliseconds == 2_000)

        // Part B (10fps MKV, 100ms per frame): seeking to 1_210ms aligns to 1_300ms (+90ms > 50ms),
        // which must be rejected and re-rendered at 1_300ms before opening the gate.
        let video10URL = tempDir.appendingPathComponent("fps10-over-threshold.mkv")
        let ass10URL = tempDir.appendingPathComponent("fps10-over-threshold.ass")
        try makeVerticalSyncTestVideo(
            at: video10URL,
            ffmpegURL: ffmpegURL,
            frameRate: "10",
            durationSeconds: 3,
            keyframeInterval: 5
        )
        try writeVerticalSyncASSSubtitle(
            at: ass10URL,
            cues: [
                (start: "0:00:00.50", end: "0:00:02.80", text: "{\\move(60,300,300,300)}10fps Animated Cue")
            ]
        )

        let open10Gen = try player.open(
            PlaybackRequest(
                videoURL: video10URL,
                startMilliseconds: 500,
                subtitleSource: PlaybackSubtitleSource(
                    url: ass10URL,
                    format: .ass,
                    matchedVideoURL: video10URL,
                    initialTimestampMilliseconds: 500
                )
            )
        )
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: open10Gen) != nil
        }
        let overlay10 = try #require(container.assOverlayViewForTesting)
        try await waitForVerticalSyncCondition { !overlay10.isRenderInFlightForTesting }

        let overBaseline = overlay10.rendererRenderCompletionCountForTesting
        let overGen = try player.seek(toMilliseconds: 1_210, pauseAfterFirstFrame: true)
        try await waitForVerticalSyncCondition {
            delegateSpy.commit(forGeneration: overGen) != nil
        }
        let overCommit = try #require(delegateSpy.commit(forGeneration: overGen))
        #expect(overCommit.milliseconds == 1_300)
        #expect(overCommit.hasASSVisibleSurface)
        let overCompletionAtCommit = try #require(recorder.commitSnapshot(forGeneration: overGen)?.completionCount)
        #expect(overCompletionAtCommit - overBaseline >= 2)
        #expect(container.currentASSSubtitleFrame()?.timestampMilliseconds == 1_300)
    }
}

private final class MicroOffsetTelemetrySpy: @unchecked Sendable {
    struct CommitSnapshot {
        let event: PlaybackPresentationCommitTelemetryEvent
        let completionCount: Int
        let clearCount: Int
    }

    private let lock = NSLock()
    private var storedFirstFrameEvents: [PlaybackSubtitleFirstFrameTelemetryEvent] = []
    private var storedCommitSnapshots: [UInt: CommitSnapshot] = [:]

    var firstFrameEvents: [PlaybackSubtitleFirstFrameTelemetryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedFirstFrameEvents
    }

    func commitSnapshot(forGeneration generation: UInt) -> CommitSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return storedCommitSnapshots[generation]
    }

    func resetFirstFrameEvents() {
        lock.lock()
        storedFirstFrameEvents.removeAll()
        lock.unlock()
    }

    func recordFirstFrame(_ event: PlaybackSubtitleFirstFrameTelemetryEvent) {
        lock.lock()
        storedFirstFrameEvents.append(event)
        lock.unlock()
    }

    func attach(to container: PlaybackRenderContainerView) {
        PlaybackSubtitleFirstFrameTelemetry.setTestObserver { [weak self] event in
            self?.recordFirstFrame(event)
        }
        PlaybackSubtitleFirstFrameTelemetry.setPresentationCommitTestObserver { [weak self, weak container] event in
            guard let self, let container, Thread.isMainThread else { return }
            let (completionCount, clearCount) = MainActor.assumeIsolated {
                (
                    container.assOverlayViewForTesting?.rendererRenderCompletionCountForTesting ?? 0,
                    container.assOverlayViewForTesting?.layerClearCountForTesting ?? 0
                )
            }
            self.lock.lock()
            self.storedCommitSnapshots[event.generation] = CommitSnapshot(
                event: event,
                completionCount: completionCount,
                clearCount: clearCount
            )
            self.lock.unlock()
        }
    }
}


private final class VerticalSyncPlayerDelegateSpy: PlaybackPlayerDelegate, @unchecked Sendable {
    struct RecordedCommit {
        let generation: UInt
        let milliseconds: Int
        let playing: Bool
        let videoSize: CGSize?
        let hasVideoSnapshot: Bool
        let hasASSVisibleSurface: Bool
        let hasASSBlankSurfaceEvaluated: Bool
        let hasSRTImage: Bool
    }

    weak var container: PlaybackRenderContainerView?
    private(set) var commits: [RecordedCommit] = []
    var failedSubtitleURLs: [URL] = []

    init(container: PlaybackRenderContainerView?) {
        self.container = container
    }

    @MainActor
    func commit(forGeneration generation: UInt) -> RecordedCommit? {
        commits.first(where: { $0.generation == generation })
    }

    func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {}

    func player(_ player: PlaybackPlayer, didFailToLoadSubtitleSource url: URL) {
        let standardized = url.standardizedMediaURL
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.failedSubtitleURLs.append(standardized)
            }
        } else {
            Task { @MainActor in
                self.failedSubtitleURLs.append(standardized)
            }
        }
    }

    @MainActor
    func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool,
        videoSize: CGSize?
    ) {
        let screenshotPresentation = player.captureScreenshotPresentation()
        let assFrame = container?.currentASSSubtitleFrame()
        let srtImage = container?.currentSRTSubtitleImage()
        commits.append(
            RecordedCommit(
                generation: generation,
                milliseconds: milliseconds,
                playing: playing,
                videoSize: videoSize,
                hasVideoSnapshot: screenshotPresentation != nil,
                hasASSVisibleSurface: assFrame?.surface != nil,
                hasASSBlankSurfaceEvaluated: assFrame != nil && assFrame?.surface == nil,
                hasSRTImage: srtImage != nil
            )
        )
    }
}

private struct DatabaseFileEntrySnapshot: Equatable {
    let name: String
    let byteCount: Int
    let modificationTimestampNanoseconds: Int64
    let data: Data
}

private func captureDatabaseDirectorySnapshot(in directoryURL: URL) throws -> [DatabaseFileEntrySnapshot] {
    // Exclude SQLite WAL's transient OS shared-memory reader-mark lock file (-shm), while verifying
    // CueSeeker.sqlite, CueSeeker.sqlite-wal, and any other directory files remain byte-for-byte & mtime identical.
    let urls = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
        options: []
    )
    .filter { !$0.lastPathComponent.hasSuffix("-shm") }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

    return try urls.map { url in
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let mtimeNanos = Int64((mtime * 1_000_000_000.0).rounded())
        let data = try Data(contentsOf: url)
        return DatabaseFileEntrySnapshot(
            name: url.lastPathComponent,
            byteCount: data.count,
            modificationTimestampNanoseconds: mtimeNanos,
            data: data
        )
    }
}

private func remapIndexedSubtitlePathForTesting(
    inDatabaseAt databaseURL: URL,
    oldPath: String,
    newPath: String
) throws {
    var handle: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
          let db = handle
    else {
        if let handle { sqlite3_close(handle) }
        throw NSError(domain: "VerticalSyncTestSQLite", code: 1)
    }
    defer { sqlite3_close(db) }

    var stmt: OpaquePointer?
    let sql = "UPDATE subtitle_files SET subtitle_path = ? WHERE subtitle_path = ?;"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
        throw NSError(domain: "VerticalSyncTestSQLite", code: 2)
    }
    defer { sqlite3_finalize(stmt) }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    _ = newPath.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
    _ = oldPath.withCString { sqlite3_bind_text(stmt, 2, $0, -1, transient) }
    guard sqlite3_step(stmt) == SQLITE_DONE else {
        throw NSError(domain: "VerticalSyncTestSQLite", code: 3)
    }
}

private func makeVerticalSyncTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVerticalSyncTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func verticalSyncTestFFmpegURL() -> URL? {
    let packageDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let repositoryDirectory = packageDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    var searchPaths: [String] = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]
    searchPaths.append(
        contentsOf: ProcessInfo.processInfo.environment["PATH", default: ""]
            .split(separator: ":")
            .map { "\($0)/ffmpeg" }
    )
    if let runtimeRoot = ProcessInfo.processInfo.environment["CUESEEKER_MEDIA_RUNTIME_ROOT"] {
        searchPaths.append("\(runtimeRoot)/bin/ffmpeg")
    }
    searchPaths.append(
        repositoryDirectory
            .appendingPathComponent(".build/media-runtime/arm64-macos13/bin/ffmpeg")
            .path
    )
    return searchPaths
        .map(URL.init(fileURLWithPath:))
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}

private func makeVerticalSyncTestVideo(
    at mediaURL: URL,
    ffmpegURL: URL,
    frameRate: String,
    durationSeconds: Int,
    keyframeInterval: Int = 12,
    videoSize: String = "160x90"
) throws {
    let process = Process()
    process.executableURL = ffmpegURL
    process.arguments = [
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "lavfi",
        "-i",
        "testsrc2=duration=\(durationSeconds):size=\(videoSize):rate=\(frameRate)",
        "-f",
        "lavfi",
        "-i",
        "sine=frequency=440:duration=\(durationSeconds)",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-g",
        "\(keyframeInterval)",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "96k",
        "-shortest",
        "-y",
        mediaURL.path
    ]
    let errorPipe = Pipe()
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let message = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? "unknown error"
        throw NSError(
            domain: "CueSeekerPlaybackTests.VerticalSync",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private func writeVerticalSyncASSSubtitle(
    at url: URL,
    cues: [(start: String, end: String, text: String)]
) throws {
    let dialogueLines = cues.map { cue in
        "Dialogue: 0,\(cue.start),\(cue.end),Default,,0,0,0,,\(cue.text)"
    }.joined(separator: "\n")

    let script = """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    \(dialogueLines)
    """
    try script.write(to: url, atomically: true, encoding: .utf8)
}

private func writeVerticalSyncSRTSubtitle(
    at url: URL,
    cues: [(index: Int, start: String, end: String, text: String)]
) throws {
    let body = cues.map { cue in
        """
        \(cue.index)
        \(cue.start) --> \(cue.end)
        \(cue.text)
        """
    }.joined(separator: "\n\n") + "\n"
    try body.write(to: url, atomically: true, encoding: .utf8)
}

@MainActor
private func waitForVerticalSyncCondition(
    timeoutSeconds: TimeInterval = 5.0,
    condition: @MainActor () -> Bool
) async throws {
    let deadline = CACurrentMediaTime() + timeoutSeconds
    while CACurrentMediaTime() < deadline {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for vertical sync test condition.")
}
