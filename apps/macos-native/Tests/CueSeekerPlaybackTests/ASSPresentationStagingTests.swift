import Foundation
import Testing
@testable import CueSeekerPlayback

@Test
@MainActor
func assPreparationRetainsActivePresentationUntilPreparedSourceCommits() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerASSPresentationStagingTests-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let activeURL = directory.appendingPathComponent("active.ass")
    let targetURL = directory.appendingPathComponent("target.ass")
    try assPresentationStagingScript(
        text: "Active presentation",
        start: "0:00:00.00",
        end: "0:00:02.00"
    ).write(to: activeURL, atomically: true, encoding: .utf8)
    try assPresentationStagingScript(
        text: "Target presentation",
        start: "0:00:05.00",
        end: "0:00:07.00"
    ).write(to: targetURL, atomically: true, encoding: .utf8)

    let activeSource = PlaybackSubtitleSource(url: activeURL, format: .ass)
    let targetSource = PlaybackSubtitleSource(url: targetURL, format: .ass)
    let videoSize = CGSize(width: 640, height: 360)
    let view = SourceFaithfulASSSubtitleOverlayView(
        frame: CGRect(origin: .zero, size: videoSize)
    )
    view.videoSize = videoSize
    view.currentTimeMilliseconds = 1_000
    view.setSource(activeSource)

    let activePresentationBecameVisible = await waitForASSPresentationStagingCondition {
        view.hasVisibleSubtitleSurfaceForTesting
    }
    #expect(activePresentationBecameVisible)
    #expect(view.activeSourceForTesting == activeSource)
    let activeWorker = view.rendererWorkerIdentityForTesting

    var completedToken: UUID?
    var preparationResult: Result<Void, SourceFaithfulASSSubtitlePreparationError>?
    let preparedToken = view.prepareSource(
        targetSource,
        at: 6_000,
        videoSize: videoSize
    ) { token, result in
        completedToken = token
        preparationResult = result
    }

    #expect(view.activeSourceForTesting == activeSource)
    #expect(view.rendererWorkerIdentityForTesting == activeWorker)
    #expect(view.hasVisibleSubtitleSurfaceForTesting)

    let targetPreparationFinished = await waitForASSPresentationStagingCondition {
        preparationResult != nil
    }
    #expect(targetPreparationFinished)
    #expect(completedToken == preparedToken)
    try (try #require(preparationResult)).get()

    #expect(view.activeSourceForTesting == activeSource)
    #expect(view.preparedSourceForTesting == targetSource)
    #expect(view.rendererWorkerIdentityForTesting == activeWorker)
    #expect(view.hasVisibleSubtitleSurfaceForTesting)

    #expect(view.commitPreparedSource(preparedToken))
    #expect(view.activeSourceForTesting == targetSource)
    #expect(view.preparedSourceForTesting == nil)
    #expect(view.rendererWorkerIdentityForTesting != activeWorker)
    #expect(view.hasVisibleSubtitleSurfaceForTesting)
}

@Test
@MainActor
func assPreparationRejectsStaleTokenAndCommitsPreparedClearAtomically() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerASSPreparedClearTests-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let activeURL = directory.appendingPathComponent("active.ass")
    let supersededURL = directory.appendingPathComponent("superseded.ass")
    try assPresentationStagingScript(
        text: "Active presentation",
        start: "0:00:00.00",
        end: "0:00:02.00"
    ).write(to: activeURL, atomically: true, encoding: .utf8)
    try assPresentationStagingScript(
        text: "Superseded presentation",
        start: "0:00:05.00",
        end: "0:00:07.00"
    ).write(to: supersededURL, atomically: true, encoding: .utf8)

    let activeSource = PlaybackSubtitleSource(url: activeURL, format: .ass)
    let supersededSource = PlaybackSubtitleSource(url: supersededURL, format: .ass)
    let videoSize = CGSize(width: 640, height: 360)
    let view = SourceFaithfulASSSubtitleOverlayView(
        frame: CGRect(origin: .zero, size: videoSize)
    )
    view.videoSize = videoSize
    view.currentTimeMilliseconds = 1_000
    view.setSource(activeSource)

    #expect(await waitForASSPresentationStagingCondition {
        view.hasVisibleSubtitleSurfaceForTesting
    })
    let activeWorker = view.rendererWorkerIdentityForTesting

    var supersededPreparation: Result<Void, SourceFaithfulASSSubtitlePreparationError>?
    let supersededToken = view.prepareSource(
        supersededSource,
        at: 6_000,
        videoSize: videoSize
    ) { _, result in
        supersededPreparation = result
    }
    #expect(await waitForASSPresentationStagingCondition {
        supersededPreparation != nil
    })
    try (try #require(supersededPreparation)).get()
    #expect(view.preparedSourceForTesting == supersededSource)

    var clearPreparation: Result<Void, SourceFaithfulASSSubtitlePreparationError>?
    let clearToken = view.prepareSource(
        nil,
        at: 6_000,
        videoSize: videoSize
    ) { _, result in
        clearPreparation = result
    }
    #expect(await waitForASSPresentationStagingCondition {
        clearPreparation != nil
    })
    try (try #require(clearPreparation)).get()

    #expect(view.hasPreparedPresentationForTesting)
    #expect(view.activeSourceForTesting == activeSource)
    #expect(view.rendererWorkerIdentityForTesting == activeWorker)
    #expect(view.hasVisibleSubtitleSurfaceForTesting)
    #expect(!view.commitPreparedSource(supersededToken))
    #expect(view.activeSourceForTesting == activeSource)
    #expect(view.hasVisibleSubtitleSurfaceForTesting)

    #expect(view.commitPreparedSource(clearToken))
    #expect(view.activeSourceForTesting == nil)
    #expect(!view.hasPreparedPresentationForTesting)
    #expect(!view.hasVisibleSubtitleSurfaceForTesting)
}

@MainActor
private func waitForASSPresentationStagingCondition(
    timeoutSeconds: TimeInterval = 5,
    condition: @escaping @MainActor () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return condition()
}

private func assPresentationStagingScript(
    text: String,
    start: String,
    end: String
) -> String {
    """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default, Helvetica, 32, &H00FFFFFF, &H000000FF, &H80000000, &H40000000, 0, 0, 0, 0, 100, 100, 0, 0, 1, 2, 1, 2, 20, 20, 20, 1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,\(start),\(end),Default,,0,0,0,,\(text)
    """
}
