import Foundation
import Testing
@testable import CueSeekerPlayback

@Test
@MainActor
func playbackRenderContainerViewInitializesWithoutAttachingBackendView() {
    let view = PlaybackRenderContainerView()

    #expect(view.subviews.isEmpty)
    #expect(view.wantsLayer)
}

@Test
func playbackDecodeModeRawValuesMatchSettingsControlValues() {
    #expect(PlaybackDecodeMode.allCases.map(\.rawValue) == ["hardware", "software", "auto"])
    #expect(PlaybackDecodeMode.hardware.displayName == "hardware")
    #expect(PlaybackDecodeMode.software.displayName == "software")
    #expect(PlaybackDecodeMode.auto.displayName == "auto")
}

@Test
@MainActor
func playbackPlayerStoresDecodeModeSetting() {
    let player = PlaybackPlayer()

    #expect(player.decodeMode == .auto)

    player.decodeMode = .software

    #expect(player.decodeMode == .software)
}

@Test
func playbackRequestRejectsMissingVideoFile() throws {
    let missingVideo = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerMissingVideo-\(UUID().uuidString)")
        .appendingPathExtension("mkv")

    #expect(throws: PlaybackError.missingVideoFile(missingVideo.path)) {
        _ = try PlaybackRequest(videoURL: missingVideo, startMilliseconds: 1_000)
    }
}

@Test
func playbackRequestClampsNegativeStartMilliseconds() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let request = try PlaybackRequest(videoURL: videoURL, startMilliseconds: -250)

    #expect(request.videoURL == videoURL)
    #expect(request.startMilliseconds == 0)
}

@Test
func playbackRequestStoresASSSubtitleSource() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let subtitleURL = videoURL.deletingPathExtension().appendingPathExtension("ass")
    let request = try PlaybackRequest(
        videoURL: videoURL,
        startMilliseconds: 1_000,
        subtitleSource: PlaybackSubtitleSource(url: subtitleURL, format: .ass)
    )

    #expect(request.subtitleSource?.url == subtitleURL)
    #expect(request.subtitleSource?.format == .ass)
}

@Test
func playbackRequestStoresASSSubtitleTimeWindow() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let subtitleURL = videoURL.deletingPathExtension().appendingPathExtension("ass")
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 1_000,
        endMilliseconds: 9_000
    )
    let request = try PlaybackRequest(
        videoURL: videoURL,
        startMilliseconds: 1_000,
        subtitleSource: PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            timeWindow: timeWindow
        )
    )

    #expect(request.subtitleSource?.timeWindow == timeWindow)
}

@Test
func playbackSubtitleTimeWindowDetectsOverlappingCues() {
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 2_000,
        endMilliseconds: 5_000
    )

    #expect(!timeWindow.overlaps(startMilliseconds: 1_000, endMilliseconds: 2_000))
    #expect(timeWindow.overlaps(startMilliseconds: 1_500, endMilliseconds: 2_500))
    #expect(timeWindow.overlaps(startMilliseconds: 5_000, endMilliseconds: 5_000))
    #expect(!timeWindow.overlaps(startMilliseconds: 5_001, endMilliseconds: 6_000))
}

@Test
func playbackSubtitleTrackSelectsCueForCurrentTime() {
    let track = PlaybackSubtitleTrack(cues: [
        PlaybackSubtitleCue(startMilliseconds: 1_000, endMilliseconds: 2_500, text: "First line"),
        PlaybackSubtitleCue(startMilliseconds: 3_000, endMilliseconds: 4_000, text: "Second line")
    ])

    #expect(track.activeText(at: 0.999) == nil)
    #expect(track.activeText(at: 1.0) == "First line")
    #expect(track.activeText(at: 2.499) == "First line")
    #expect(track.activeText(at: 2.5) == nil)
    #expect(track.activeText(at: 3.0) == "Second line")
}

@Test
func playbackSubtitleTrackJoinsOverlappingCues() {
    let track = PlaybackSubtitleTrack(cues: [
        PlaybackSubtitleCue(startMilliseconds: 2_000, endMilliseconds: 4_000, text: "Second"),
        PlaybackSubtitleCue(startMilliseconds: 1_000, endMilliseconds: 3_000, text: "First"),
        PlaybackSubtitleCue(startMilliseconds: 1_000, endMilliseconds: 3_000, text: "   ")
    ])

    #expect(track.activeText(at: 2.5) == "First\nSecond")
}

@Test
@MainActor
func playbackPlayerStoresNonDefaultNativeSpeed() throws {
    let player = PlaybackPlayer()

    try player.setDoubleProperty("speed", value: 1.5)

    #expect(try player.getDoubleProperty("speed") == 1.5)
}

@Test
@MainActor
func playbackPlayerClampsNativeSpeedRange() throws {
    let player = PlaybackPlayer()

    try player.setDoubleProperty("speed", value: 3.0)
    #expect(try player.getDoubleProperty("speed") == 2.0)

    try player.setDoubleProperty("speed", value: 0.25)
    #expect(try player.getDoubleProperty("speed") == 0.5)
}
