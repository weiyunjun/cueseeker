import AppKit
@testable import CueSeekerPlayback
import CueSeekerCore
import Foundation
import QuartzCore
import Testing

@Suite(.serialized)
struct PlaybackSubtitleFirstFrameTelemetryTests {
    @Test
    @MainActor
    func newVideoOpenWithASSSubtitleEmitsTelemetryAfterLayerUpdate() async throws {
        let ffmpegURL = try #require(telemetryTestFFmpegURL())
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("ass-open.mkv")
        let subtitleURL = tempDir.appendingPathComponent("opening-track.ass")
        try makeTelemetryTestVideo(at: videoURL, ffmpegURL: ffmpegURL)
        try writeASSSubtitleFile(
            at: subtitleURL,
            cues: [
                (start: "0:00:00.00", end: "0:00:01.50", text: "Opening ASS Line"),
                (start: "0:00:02.20", end: "0:00:03.80", text: "Second ASS Line")
            ]
        )

        let recorder = TelemetryRecorder(container: nil)
        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = player.renderView as? PlaybackRenderContainerView
        container?.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        recorder.attach(container: container)

        let request = try PlaybackRequest(
            videoURL: videoURL,
            startMilliseconds: 200,
            subtitleSource: PlaybackSubtitleSource(
                url: subtitleURL,
                format: .ass,
                matchedVideoURL: videoURL,
                initialTimestampMilliseconds: 200
            )
        )
        let generation = try player.open(request)

        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == generation })
                && recorder.firstFrames.count == 1
        }

        let commit = try #require(recorder.commits.first(where: { $0.generation == generation }))
        #expect(commit.subtitleSyncState == .asyncPending)
        #expect(commit.subtitleFileName == "opening-track.ass")

        let recorded = try #require(recorder.firstFrames.first)
        #expect(recorded.hasASSFrame)
        #expect(recorded.event.trigger == .newVideoOpen)
        #expect(recorded.event.format == .ass)
        #expect(recorded.event.subtitleFileName == "opening-track.ass")
        #expect(recorded.event.preparationMilliseconds > 0)
        #expect(recorded.event.firstFrameMilliseconds >= 0)
        #expect(recorded.event.lagMilliseconds >= 0)
        #expect(!recorded.event.isSynchronousAtCommit)
        #expect(recorded.event.presentationGeneration == generation)

        // Let continuous playback advance briefly across time without switching;
        // frame-by-frame ticks must not emit extra telemetry events.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(recorder.firstFrames.count == 1)
    }

    @Test
    @MainActor
    func newVideoOpenWithSRTSubtitleAndSameVideoSeekReuseEmitAccurateTelemetry() async throws {
        let ffmpegURL = try #require(telemetryTestFFmpegURL())
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("srt-flow.mkv")
        let firstSRTURL = tempDir.appendingPathComponent("track-one.srt")
        let secondSRTURL = tempDir.appendingPathComponent("track-two.srt")
        try makeTelemetryTestVideo(at: videoURL, ffmpegURL: ffmpegURL)
        try writeSRTSubtitleFile(
            at: firstSRTURL,
            cues: [
                (index: 1, start: "00:00:00,000", end: "00:00:01,500", text: "SRT Cue One"),
                (index: 2, start: "00:00:01,800", end: "00:00:03,500", text: "SRT Cue Two")
            ]
        )
        try writeSRTSubtitleFile(
            at: secondSRTURL,
            cues: [
                (index: 1, start: "00:00:00,000", end: "00:00:04,000", text: "Replacement SRT")
            ]
        )

        let recorder = TelemetryRecorder(container: nil)
        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = player.renderView as? PlaybackRenderContainerView
        container?.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        recorder.attach(container: container)

        let openGeneration = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(
                    url: firstSRTURL,
                    format: .srt,
                    matchedVideoURL: videoURL,
                    initialTimestampMilliseconds: 200
                )
            )
        )

        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == openGeneration })
                && recorder.firstFrames.count == 1
        }

        let openCommit = try #require(
            recorder.commits.first(where: { $0.generation == openGeneration })
        )
        #expect(openCommit.subtitleSyncState == .asyncPending)
        let openEvent = try #require(recorder.firstFrames.first)
        #expect(openEvent.hasSRTImage)
        #expect(openEvent.event.trigger == .newVideoOpen)
        #expect(openEvent.event.format == .srt)
        #expect(openEvent.event.subtitleFileName == "track-one.srt")
        #expect(openEvent.event.preparationMilliseconds > 0)
        #expect(!openEvent.event.isSynchronousAtCommit)

        // Same-video seek preserving an already prepared SRT layout must commit synchronously
        // with 0 prep and 0 lag relative to video first frame.
        let preserveSeekGen = try player.seek(toMilliseconds: 2_100, pauseAfterFirstFrame: true)
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == preserveSeekGen })
                && recorder.firstFrames.count == 2
        }

        let preserveCommit = try #require(
            recorder.commits.first(where: { $0.generation == preserveSeekGen })
        )
        #expect(preserveCommit.subtitleSyncState == .syncReady)
        let preserveEvent = recorder.firstFrames[1]
        #expect(preserveEvent.hasSRTImage)
        #expect(preserveEvent.event.trigger == .sameVideoSeek)
        #expect(preserveEvent.event.format == .srt)
        #expect(preserveEvent.event.preparationMilliseconds == 0)
        #expect(preserveEvent.event.lagMilliseconds == 0)
        #expect(preserveEvent.event.isSynchronousAtCommit)
        #expect(preserveEvent.event.level == .debug)

        // Same-video seek replacing with a different SRT file must measure source prep > 0.
        let replaceSeekGen = try player.seek(
            toMilliseconds: 500,
            subtitleSource: PlaybackSubtitleSource(
                url: secondSRTURL,
                format: .srt,
                matchedVideoURL: videoURL,
                initialTimestampMilliseconds: 500
            )
        )
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == replaceSeekGen })
                && recorder.firstFrames.count == 3
        }

        let replaceCommit = try #require(
            recorder.commits.first(where: { $0.generation == replaceSeekGen })
        )
        #expect(replaceCommit.subtitleSyncState == .asyncPending)
        let replaceEvent = recorder.firstFrames[2]
        #expect(replaceEvent.hasSRTImage)
        #expect(replaceEvent.event.trigger == .sameVideoSeek)
        #expect(replaceEvent.event.format == .srt)
        #expect(replaceEvent.event.subtitleFileName == "track-two.srt")
        #expect(replaceEvent.event.preparationMilliseconds > 0)
        #expect(!replaceEvent.event.isSynchronousAtCommit)
    }

    @Test
    @MainActor
    func sameVideoSeekReusingReadyASSWithinSameCueAndOutsideCueReportsExpectedStates() async throws {
        let ffmpegURL = try #require(telemetryTestFFmpegURL())
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("ass-seek.mkv")
        let subtitleURL = tempDir.appendingPathComponent("seek-track.ass")
        try makeTelemetryTestVideo(at: videoURL, ffmpegURL: ffmpegURL)
        try writeASSSubtitleFile(
            at: subtitleURL,
            cues: [
                (start: "0:00:00.00", end: "0:00:01.60", text: "Cue Range One"),
                (start: "0:00:02.40", end: "0:00:04.00", text: "Cue Range Two")
            ]
        )

        let recorder = TelemetryRecorder(container: nil)
        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = player.renderView as? PlaybackRenderContainerView
        container?.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        recorder.attach(container: container)

        let openGen = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 200,
                autoStopAtMilliseconds: 1_500,
                subtitleSource: PlaybackSubtitleSource(
                    url: subtitleURL,
                    format: .ass,
                    matchedVideoURL: videoURL,
                    initialTimestampMilliseconds: 200
                )
            )
        )

        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == openGen })
                && recorder.firstFrames.count == 1
        }
        #expect(recorder.commits.last?.subtitleSyncState == .asyncPending)
        #expect(recorder.firstFrames[0].event.preparationMilliseconds > 0)

        // Pause at 400ms inside the exact same ASS valid range [0..1600): layer is synchronously ready.
        let inCueSeekGen = try player.seek(toMilliseconds: 400, pauseAfterFirstFrame: true)
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == inCueSeekGen })
                && recorder.firstFrames.count == 2
        }

        let inCueCommit = try #require(
            recorder.commits.first(where: { $0.generation == inCueSeekGen })
        )
        #expect(inCueCommit.subtitleSyncState == .syncReady)
        let inCueEvent = recorder.firstFrames[1].event
        #expect(inCueEvent.trigger == .sameVideoSeek)
        #expect(inCueEvent.format == .ass)
        #expect(inCueEvent.preparationMilliseconds == 0)
        #expect(inCueEvent.lagMilliseconds == 0)
        #expect(inCueEvent.isSynchronousAtCommit)

        // Seek to 2_800ms (Cue Two, outside [0..1600)): reuses worker (prep=0) and renders async.
        let crossCueSeekGen = try player.seek(toMilliseconds: 2_800, pauseAfterFirstFrame: true)
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == crossCueSeekGen })
                && recorder.firstFrames.count == 3
        }

        let crossCueCommit = try #require(
            recorder.commits.first(where: { $0.generation == crossCueSeekGen })
        )
        #expect(crossCueCommit.subtitleSyncState == .asyncPending)
        let crossCueEvent = recorder.firstFrames[2]
        #expect(crossCueEvent.event.trigger == .sameVideoSeek)
        #expect(crossCueEvent.event.format == .ass)
        #expect(crossCueEvent.event.preparationMilliseconds == 0)
        #expect(!crossCueEvent.event.isSynchronousAtCommit)
        #expect(crossCueEvent.hasASSFrame)
    }

    @Test
    @MainActor
    func manualSubtitleSwitchEmitsTelemetryForSRTAndASSAfterNoSubtitleOpen() async throws {
        let ffmpegURL = try #require(telemetryTestFFmpegURL())
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("switch-video.mkv")
        let srtURL = tempDir.appendingPathComponent("manual-switch.srt")
        let assURL = tempDir.appendingPathComponent("manual-switch.ass")
        try makeTelemetryTestVideo(at: videoURL, ffmpegURL: ffmpegURL)
        try writeSRTSubtitleFile(
            at: srtURL,
            cues: [(index: 1, start: "00:00:00,000", end: "00:00:04,000", text: "Manual SRT")]
        )
        try writeASSSubtitleFile(
            at: assURL,
            cues: [(start: "0:00:00.00", end: "0:00:04.00", text: "Manual ASS")]
        )

        let recorder = TelemetryRecorder(container: nil)
        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let container = player.renderView as? PlaybackRenderContainerView
        container?.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
        recorder.attach(container: container)

        let openGen = try player.open(
            PlaybackRequest(videoURL: videoURL, startMilliseconds: 300)
        )
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == openGen })
        }
        #expect(recorder.commits.last?.subtitleSyncState == .noSubtitle)
        #expect(recorder.firstFrames.isEmpty)

        // Manual switch to SRT
        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: srtURL,
                format: .srt,
                matchedVideoURL: videoURL,
                initialTimestampMilliseconds: 300
            )
        )
        try await waitForTelemetryCondition {
            recorder.firstFrames.count == 1
        }
        let srtEvent = recorder.firstFrames[0]
        #expect(srtEvent.hasSRTImage)
        #expect(srtEvent.event.trigger == .manualSubtitleSwitch)
        #expect(srtEvent.event.format == .srt)
        #expect(srtEvent.event.subtitleFileName == "manual-switch.srt")
        #expect(srtEvent.event.preparationMilliseconds > 0)
        #expect(srtEvent.event.lagMilliseconds == 0)
        #expect(!srtEvent.event.isSynchronousAtCommit)

        // Manual switch to ASS
        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: assURL,
                format: .ass,
                matchedVideoURL: videoURL,
                initialTimestampMilliseconds: 500
            )
        )
        try await waitForTelemetryCondition {
            recorder.firstFrames.count == 2
        }
        let assEvent = recorder.firstFrames[1]
        #expect(assEvent.hasASSFrame)
        #expect(assEvent.event.trigger == .manualSubtitleSwitch)
        #expect(assEvent.event.format == .ass)
        #expect(assEvent.event.subtitleFileName == "manual-switch.ass")
        #expect(assEvent.event.preparationMilliseconds > 0)
        #expect(assEvent.event.lagMilliseconds == 0)
        #expect(!assEvent.event.isSynchronousAtCommit)
    }

    @Test
    @MainActor
    func hiddenSubtitlesDistinguishHiddenAtCommitAndEmitNoTelemetry() async throws {
        let ffmpegURL = try #require(telemetryTestFFmpegURL())
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("hidden-video.mkv")
        let srtURL = tempDir.appendingPathComponent("hidden-track.srt")
        let assURL = tempDir.appendingPathComponent("hidden-track.ass")
        try makeTelemetryTestVideo(at: videoURL, ffmpegURL: ffmpegURL)
        try writeSRTSubtitleFile(
            at: srtURL,
            cues: [(index: 1, start: "00:00:00,000", end: "00:00:04,000", text: "Hidden SRT")]
        )
        try writeASSSubtitleFile(
            at: assURL,
            cues: [(start: "0:00:00.00", end: "0:00:04.00", text: "Hidden ASS")]
        )

        let recorder = TelemetryRecorder(container: nil)
        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        player.setSubtitlesVisible(false)
        recorder.attach(container: nil)

        let gen = try player.open(
            PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: 200,
                subtitleSource: PlaybackSubtitleSource(
                    url: srtURL,
                    format: .srt,
                    matchedVideoURL: videoURL,
                    initialTimestampMilliseconds: 200
                )
            )
        )
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == gen })
        }
        #expect(recorder.commits.last?.subtitleSyncState == .hidden)

        player.loadSubtitleSource(
            PlaybackSubtitleSource(
                url: assURL,
                format: .ass,
                matchedVideoURL: videoURL,
                initialTimestampMilliseconds: 300
            )
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(recorder.firstFrames.isEmpty)
    }

    @Test
    @MainActor
    func supersededSwitchesAndStopCancellationEmitZeroDirtyTelemetry() async throws {
        let ffmpegURL = try #require(telemetryTestFFmpegURL())
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let videoURL = tempDir.appendingPathComponent("cancel-video.mkv")
        let firstASS = tempDir.appendingPathComponent("superseded-first.ass")
        let secondASS = tempDir.appendingPathComponent("superseded-second.ass")
        let firstSRT = tempDir.appendingPathComponent("superseded-first.srt")
        let secondSRT = tempDir.appendingPathComponent("superseded-second.srt")
        try makeTelemetryTestVideo(at: videoURL, ffmpegURL: ffmpegURL)
        try writeASSSubtitleFile(
            at: firstASS,
            cues: [(start: "0:00:00.00", end: "0:00:03.00", text: "First ASS")]
        )
        try writeASSSubtitleFile(
            at: secondASS,
            cues: [(start: "0:00:00.00", end: "0:00:03.00", text: "Second ASS")]
        )
        try writeSRTSubtitleFile(
            at: firstSRT,
            cues: [(index: 1, start: "00:00:00,000", end: "00:00:03,000", text: "First SRT")]
        )
        try writeSRTSubtitleFile(
            at: secondSRT,
            cues: [(index: 1, start: "00:00:00,000", end: "00:00:03,000", text: "Second SRT")]
        )

        let recorder = TelemetryRecorder(container: nil)
        recorder.attach(container: nil)

        let assView = SourceFaithfulASSSubtitleOverlayView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 360)
        )
        let firstASSAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: PlaybackSubtitleSource(url: firstASS, format: .ass),
            targetMilliseconds: 500,
            presentationGeneration: 1,
            videoCommittedAt: nil
        )
        _ = assView.setPresentation(
            source: firstASSAttempt.source,
            videoSize: CGSize(width: 640, height: 360),
            milliseconds: 500,
            isVisible: true,
            telemetryAttempt: firstASSAttempt
        )
        let secondASSAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: PlaybackSubtitleSource(url: secondASS, format: .ass),
            targetMilliseconds: 500,
            presentationGeneration: 2,
            videoCommittedAt: nil
        )
        _ = assView.setPresentation(
            source: secondASSAttempt.source,
            videoSize: CGSize(width: 640, height: 360),
            milliseconds: 500,
            isVisible: true,
            telemetryAttempt: secondASSAttempt
        )

        try await waitForTelemetryCondition { recorder.firstFrames.count == 1 }
        #expect(recorder.firstFrames.map(\.event.subtitleFileName) == ["superseded-second.ass"])

        let srtView = SRTSubtitleOverlayView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 360)
        )
        let firstSRTAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: PlaybackSubtitleSource(url: firstSRT, format: .srt),
            targetMilliseconds: 500,
            presentationGeneration: 3,
            videoCommittedAt: nil
        )
        _ = srtView.setPresentation(
            source: firstSRTAttempt.source,
            videoSize: CGSize(width: 640, height: 360),
            milliseconds: 500,
            isVisible: true,
            telemetryAttempt: firstSRTAttempt
        )
        let secondSRTAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: PlaybackSubtitleSource(url: secondSRT, format: .srt),
            targetMilliseconds: 500,
            presentationGeneration: 4,
            videoCommittedAt: nil
        )
        _ = srtView.setPresentation(
            source: secondSRTAttempt.source,
            videoSize: CGSize(width: 640, height: 360),
            milliseconds: 500,
            isVisible: true,
            telemetryAttempt: secondSRTAttempt
        )

        try await waitForTelemetryCondition { recorder.firstFrames.count == 2 }
        #expect(recorder.firstFrames.map(\.event.subtitleFileName) == [
            "superseded-second.ass",
            "superseded-second.srt"
        ])

        // Cancelling via PlaybackPlayer rapid switch & stop must suppress aborted generations.
        let player = PlaybackPlayer()
        player.setVolume(0)
        defer { try? player.stop() }
        player.decodeMode = .software
        let openGen = try player.open(PlaybackRequest(videoURL: videoURL, startMilliseconds: 100))
        try await waitForTelemetryCondition {
            recorder.commits.contains(where: { $0.generation == openGen })
        }

        player.loadSubtitleSource(PlaybackSubtitleSource(url: firstASS, format: .ass))
        player.loadSubtitleSource(PlaybackSubtitleSource(url: secondSRT, format: .srt))
        try player.stop()

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(recorder.firstFrames.count == 2)
    }

    @Test
    @MainActor
    func continuousPlaybackTimeUpdatesEmitZeroTelemetryEvents() async throws {
        let tempDir = try makeTelemetryTempDirectory()
        defer {
            PlaybackSubtitleFirstFrameTelemetry.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let assURL = tempDir.appendingPathComponent("continuous.ass")
        let srtURL = tempDir.appendingPathComponent("continuous.srt")
        try writeASSSubtitleFile(
            at: assURL,
            cues: [
                (start: "0:00:00.00", end: "0:00:01.00", text: "One"),
                (start: "0:00:01.00", end: "0:00:02.00", text: "Two")
            ]
        )
        try writeSRTSubtitleFile(
            at: srtURL,
            cues: [
                (index: 1, start: "00:00:00,000", end: "00:00:01,000", text: "One"),
                (index: 2, start: "00:00:01,000", end: "00:00:02,000", text: "Two")
            ]
        )

        let recorder = TelemetryRecorder(container: nil)
        recorder.attach(container: nil)

        let assView = SourceFaithfulASSSubtitleOverlayView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 360)
        )
        let assSource = PlaybackSubtitleSource(url: assURL, format: .ass)
        _ = assView.setPresentation(
            source: assSource,
            videoSize: CGSize(width: 640, height: 360),
            milliseconds: 100,
            isVisible: true,
            telemetryAttempt: PlaybackSubtitleFirstFrameAttempt(
                trigger: .newVideoOpen,
                source: assSource,
                targetMilliseconds: 100,
                presentationGeneration: 1,
                videoCommittedAt: CACurrentMediaTime()
            )
        )
        try await waitForTelemetryCondition { recorder.firstFrames.count == 1 }

        for tick in [300, 600, 1_100, 1_500] {
            assView.currentTimeMilliseconds = tick
            try await Task.sleep(nanoseconds: 40_000_000)
        }
        #expect(recorder.firstFrames.count == 1)

        let srtView = SRTSubtitleOverlayView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 360)
        )
        let srtSource = PlaybackSubtitleSource(url: srtURL, format: .srt)
        _ = srtView.setPresentation(
            source: srtSource,
            videoSize: CGSize(width: 640, height: 360),
            milliseconds: 100,
            isVisible: true,
            telemetryAttempt: PlaybackSubtitleFirstFrameAttempt(
                trigger: .newVideoOpen,
                source: srtSource,
                targetMilliseconds: 100,
                presentationGeneration: 2,
                videoCommittedAt: CACurrentMediaTime()
            )
        )
        try await waitForTelemetryCondition { recorder.firstFrames.count == 2 }

        for tick in [300, 600, 1_100, 1_500] {
            srtView.currentTimeMilliseconds = tick
        }
        try await Task.sleep(nanoseconds: 60_000_000)
        #expect(recorder.firstFrames.count == 2)
    }

    @Test
    @MainActor
    func warnEscalationThresholdsAndZeroDiskLoggingGuarantee() {
        defer { PlaybackSubtitleFirstFrameTelemetry.resetForTesting() }

        #expect(!AppLogger.shared.isEnabled)
        let defaultLogDir = AppLogger.defaultLogDirectoryURL()
        let beforeFiles = (try? FileManager.default.contentsOfDirectory(
            atPath: defaultLogDir.path
        )) ?? []

        let recorder = TelemetryRecorder(container: nil)
        recorder.attach(container: nil)

        let source = PlaybackSubtitleSource(
            url: URL(fileURLWithPath: "/tmp/threshold-check.ass"),
            format: .ass
        )
        let baseTime: CFTimeInterval = 0.0

        // Exactly at 33.0ms lag (not > 33) and 33.0ms total (< 200) -> .debug
        let atLagLimitAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .sameVideoSeek,
            source: source,
            targetMilliseconds: 500,
            presentationGeneration: 10,
            startedAt: baseTime,
            videoCommittedAt: baseTime
        )
        atLagLimitAttempt.markPrepStarted(at: baseTime)
        atLagLimitAttempt.markPrepFinished(at: baseTime + 0.020)
        atLagLimitAttempt.completeAsynchronously(at: baseTime + 0.033)

        // Lag > 33.0ms -> .warn
        let highLagAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .sameVideoSeek,
            source: source,
            targetMilliseconds: 500,
            presentationGeneration: 11,
            startedAt: baseTime,
            videoCommittedAt: baseTime
        )
        highLagAttempt.markReusedSource(renderStartedAt: baseTime)
        highLagAttempt.completeAsynchronously(at: baseTime + 0.0335)

        // Prep + firstFrame == 199.0ms without video commit lag -> .debug
        let justUnderTotalAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: source,
            targetMilliseconds: 500,
            presentationGeneration: nil,
            startedAt: baseTime,
            videoCommittedAt: nil
        )
        justUnderTotalAttempt.markPrepStarted(at: baseTime)
        justUnderTotalAttempt.markPrepFinished(at: baseTime + 0.150)
        justUnderTotalAttempt.completeAsynchronously(at: baseTime + 0.199)

        // Prep + firstFrame == 200.0ms without video commit lag -> .warn
        let atTotalThresholdAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: source,
            targetMilliseconds: 500,
            presentationGeneration: nil,
            startedAt: baseTime,
            videoCommittedAt: nil
        )
        atTotalThresholdAttempt.markPrepStarted(at: baseTime)
        atTotalThresholdAttempt.markPrepFinished(at: baseTime + 0.150)
        atTotalThresholdAttempt.completeAsynchronously(at: baseTime + 0.200)

        AppLogger.shared.flush()
        let afterFiles = (try? FileManager.default.contentsOfDirectory(
            atPath: defaultLogDir.path
        )) ?? []
        #expect(beforeFiles == afterFiles)

        let events = recorder.firstFrames.map(\.event)
        #expect(events.count == 4)
        #expect(events[0].level == .debug)
        #expect(events[1].level == .warn)
        #expect(events[2].level == .debug)
        #expect(events[3].level == .warn)

        // Verify Release diagnostic telemetry gating isolates normal debug logs
        // while still allowing persistent warn logs through.
        #expect(AppLogLevel.defaultMinimumLevel(for: .release, telemetryMode: .debugOnly) == .info)
        #expect(AppLogLevel.defaultMinimumLevel(for: .release, telemetryMode: .debugAndRelease) == .debug)
        #expect(AppLogLevel.defaultMinimumLevel(for: .debug, telemetryMode: .debugOnly) == .debug)
        #expect(AppLogLevel.warn >= AppLogLevel.info)
        #expect(AppLogLevel.debug < AppLogLevel.info)
    }
}

private struct RecordedSubtitleFirstFrame {
    let event: PlaybackSubtitleFirstFrameTelemetryEvent
    let hasASSFrame: Bool
    let hasSRTImage: Bool
}

private final class TelemetryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCommits: [PlaybackPresentationCommitTelemetryEvent] = []
    private var storedFirstFrames: [RecordedSubtitleFirstFrame] = []
    private weak var container: PlaybackRenderContainerView?

    init(container: PlaybackRenderContainerView?) {
        self.container = container
    }

    var commits: [PlaybackPresentationCommitTelemetryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedCommits
    }

    var firstFrames: [RecordedSubtitleFirstFrame] {
        lock.lock()
        defer { lock.unlock() }
        return storedFirstFrames
    }

    func attach(container: PlaybackRenderContainerView?) {
        lock.lock()
        self.container = container
        lock.unlock()

        PlaybackSubtitleFirstFrameTelemetry.setPresentationCommitTestObserver { [weak self] commit in
            self?.appendCommit(commit)
        }
        PlaybackSubtitleFirstFrameTelemetry.setTestObserver { [weak self] event in
            self?.appendFirstFrame(event)
        }
    }

    private func appendCommit(_ commit: PlaybackPresentationCommitTelemetryEvent) {
        lock.lock()
        storedCommits.append(commit)
        lock.unlock()
    }

    private func appendFirstFrame(_ event: PlaybackSubtitleFirstFrameTelemetryEvent) {
        lock.lock()
        let activeContainer = container
        lock.unlock()
        let (hasASSFrame, hasSRTImage): (Bool, Bool)
        if Thread.isMainThread, let activeContainer {
            (hasASSFrame, hasSRTImage) = MainActor.assumeIsolated {
                (
                    activeContainer.currentASSSubtitleFrame() != nil,
                    activeContainer.currentSRTSubtitleImage() != nil
                )
            }
        } else {
            (hasASSFrame, hasSRTImage) = (false, false)
        }
        lock.lock()
        storedFirstFrames.append(
            RecordedSubtitleFirstFrame(
                event: event,
                hasASSFrame: hasASSFrame,
                hasSRTImage: hasSRTImage
            )
        )
        lock.unlock()
    }
}

private func writeASSSubtitleFile(
    at url: URL,
    cues: [(start: String, end: String, text: String)]
) throws {
    let lines = cues.map {
        "Dialogue: 0,\($0.start),\($0.end),Default,,0,0,0,,\($0.text)"
    }.joined(separator: "\n")
    let content = """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default, Helvetica, 32, &H00FFFFFF, &H000000FF, &H80000000, &H40000000, 0, 0, 0, 0, 100, 100, 0, 0, 1, 2, 1, 2, 20, 20, 20, 1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    \(lines)
    """
    try content.write(to: url, atomically: true, encoding: .utf8)
}

private func writeSRTSubtitleFile(
    at url: URL,
    cues: [(index: Int, start: String, end: String, text: String)]
) throws {
    let blocks = cues.map { cue in
        """
        \(cue.index)
        \(cue.start) --> \(cue.end)
        \(cue.text)
        """
    }.joined(separator: "\n\n")
    try blocks.write(to: url, atomically: true, encoding: .utf8)
}

@MainActor
private func waitForTelemetryCondition(
    timeoutSeconds: TimeInterval = 5,
    condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for subtitle first-frame telemetry condition.")
}

private func makeTelemetryTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSubtitleTelemetryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func telemetryTestFFmpegURL() -> URL? {
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

private func makeTelemetryTestVideo(
    at mediaURL: URL,
    ffmpegURL: URL
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
        "testsrc2=duration=5:size=160x90:rate=24",
        "-f",
        "lavfi",
        "-i",
        "sine=frequency=440:duration=5",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-g",
        "12",
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
            domain: "CueSeekerPlaybackTests.SubtitleTelemetry",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
