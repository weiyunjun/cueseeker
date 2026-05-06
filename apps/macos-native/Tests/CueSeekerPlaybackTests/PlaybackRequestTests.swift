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
@MainActor
func playbackRenderContainerUsesSourceFaithfulOverlayForASSSource() async throws {
    let view = PlaybackRenderContainerView()
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerASSOverlay-\(UUID().uuidString)")
        .appendingPathExtension("ass")
    defer {
        try? FileManager.default.removeItem(at: subtitleURL)
    }

    try """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default, Helvetica, 32, &H00FFFFFF, &H000000FF, &H80000000, &H40000000, 0, 0, 0, 0, 100, 100, 0, 0, 1, 2, 1, 2, 20, 20, 20, 1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:00.00,0:00:02.00,Default,,0,0,0,,Hello
    """.write(to: subtitleURL, atomically: true, encoding: .utf8)

    view.setVideoSize(CGSize(width: 640, height: 360))
    view.setSourceFaithfulASSSubtitleSource(
        PlaybackSubtitleSource(url: subtitleURL, format: .ass)
    )

    #expect(view.subviews.contains { String(describing: type(of: $0)).contains("SourceFaithfulASSSubtitleOverlayView") })
    #expect(!view.subviews.contains { String(describing: type(of: $0)).contains("NativeASSSubtitleOverlayView") })
    try await Task.sleep(nanoseconds: 100_000_000)
}

@Test
func playbackDecodeModeRawValuesMatchSettingsControlValues() {
    #expect(PlaybackDecodeMode.allCases.map(\.rawValue) == ["hardware", "software", "auto"])
    #expect(PlaybackDecodeMode.hardware.displayName == "hardware")
    #expect(PlaybackDecodeMode.software.displayName == "software")
    #expect(PlaybackDecodeMode.auto.displayName == "auto")
}

@Test
func sourceFaithfulASSSubtitleLayoutMapsLibassTopOriginToLayerBottomOrigin() {
    let frame = SourceFaithfulASSSubtitleLayout.surfaceFrame(
        destinationX: 120,
        destinationY: 300,
        width: 200,
        height: 40,
        frameWidth: 640,
        frameHeight: 360,
        videoRect: CGRect(x: 10, y: 20, width: 640, height: 360)
    )

    #expect(frame == CGRect(x: 130, y: 40, width: 200, height: 40))
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
            preparationTimeWindow: timeWindow
        )
    )

    #expect(request.subtitleSource?.preparationTimeWindow == timeWindow)
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
