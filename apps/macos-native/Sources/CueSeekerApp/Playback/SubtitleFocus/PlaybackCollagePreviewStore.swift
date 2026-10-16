import AppKit
import Combine
import CoreGraphics
import CueSeekerCore
import CueSeekerPlayback
import Foundation

enum PlaybackCollagePreviewError: Error {
    case renderedGroupCountMismatch
}

enum PlaybackCollageFeedbackEvent: Equatable, Sendable {
    case noCueSelected
    case notReady
    case copySucceeded
    case copyFailed
    case exportSucceeded
    case exportFailed
}

enum PlaybackCollageActionReadiness {
    case emptySelection
    case notReady
    case failed
    case ready(image: CGImage, plan: SubtitleCollageSelectionPlan)
}

private struct PlaybackCollageImageActionWorkItem: @unchecked Sendable {
    let image: CGImage
}

/// One group's strip of the published preview: its height in image pixels,
/// and the reel ordinal of the first cue of the group actually drawn there —
/// for a stand-in, the group whose old image is on screen.
struct PlaybackCollagePreviewSegment: Equatable {
    let height: Int
    let firstCueOrdinal: Int
}

@MainActor
final class PlaybackCollagePreviewStore: ObservableObject {
    typealias RenderGroup = (
        SubtitleCollageGroup
    ) async throws -> SubtitleCollageRenderedGroup
    typealias Compose = (
        [SubtitleCollageRenderedGroup]
    ) async throws -> SubtitleCollageComposition

    @Published private(set) var image: CGImage?
    /// The strips of `image` in display order, published with it.
    @Published private(set) var segments: [PlaybackCollagePreviewSegment] = []
    @Published private(set) var isRendering = false
    @Published private(set) var errorDescription: String?

    private let renderGroup: RenderGroup
    private let compose: Compose
    private var requestedPlan: SubtitleCollageSelectionPlan?
    private var committedPlan: SubtitleCollageSelectionPlan?
    private var renderedGroups: [(
        group: SubtitleCollageGroup,
        rendered: SubtitleCollageRenderedGroup
    )] = []
    // The groups the preview currently shows, in plan order; a publish is
    // skipped when the available set has not changed.
    private var publishedGroups: [SubtitleCollageGroup] = []
    private var publishGeneration = 0
    private var requestGeneration = 0
    private var renderTask: Task<Void, Never>?
    // Each group is an independent frame grab and subtitle render, so missing
    // groups render side by side, bounded by the machine's performance cores.
    private static let maximumConcurrentGroupRenders = 4

    init(
        videoURL: URL,
        subtitleSource: PlaybackSubtitleSource,
        srtSubtitleStyle: SRTSubtitleStyle
    ) {
        renderGroup = { group in
            let rendered = try await SubtitleScreenshotExporter.renderCollageGroups(
                [group],
                videoURL: videoURL,
                subtitleSource: subtitleSource,
                srtSubtitleStyle: srtSubtitleStyle
            )
            guard let renderedGroup = rendered.first, rendered.count == 1 else {
                throw PlaybackCollagePreviewError.renderedGroupCountMismatch
            }
            return renderedGroup
        }
        compose = { renderedGroups in
            try await Task.detached(priority: .userInitiated) {
                try SubtitleScreenshotExporter.composeCollage(renderedGroups)
            }.value
        }
    }

    init(
        renderGroup: @escaping RenderGroup,
        compose: @escaping Compose
    ) {
        self.renderGroup = renderGroup
        self.compose = compose
    }

    func update(plan: SubtitleCollageSelectionPlan) {
        guard requestedPlan != plan else {
            return
        }

        requestedPlan = plan
        errorDescription = nil

        guard !plan.groups.isEmpty else {
            stopRendering()
            committedPlan = nil
            renderedGroups = []
            publishedGroups = []
            clearImage()
            isRendering = false
            return
        }

        isRendering = true
        // What this plan already has is shown at once; the rest follows as it
        // renders.
        publishAvailableGroups()
        startRenderingIfNeeded()
    }

    private func startRenderingIfNeeded() {
        guard renderTask == nil else {
            // The running worker re-reads the requested plan after each batch,
            // so a new selection needs no second worker and no interruption.
            return
        }

        requestGeneration += 1
        let generation = requestGeneration
        let renderGroup = self.renderGroup
        let compose = self.compose
        renderTask = Task { [weak self] in
            await self?.render(renderGroup: renderGroup, compose: compose)
            self?.releaseRenderTask(generation: generation)
        }
    }

    private func render(
        renderGroup: @escaping RenderGroup,
        compose: @escaping Compose
    ) async {
        while !Task.isCancelled {
            guard let plan = requestedPlan, !plan.groups.isEmpty else {
                isRendering = false
                return
            }

            let missing = plan.groups
                .filter { renderedGroup(for: $0) == nil }
                .prefix(Self.maximumConcurrentGroupRenders)
            if !missing.isEmpty {
                // Never interrupted: the batch is rendered to completion and
                // every finished group kept, then the loop picks up whatever
                // plan is current now.
                if let failure = await renderBatch(
                    Array(missing),
                    renderGroup: renderGroup
                ) {
                    // A plan that has moved on may not need the failed group any
                    // more; only a failure the current plan depends on is reported.
                    guard requestedPlan == plan else {
                        continue
                    }
                    report(failure, whileRendering: plan)
                    return
                }
                continue
            }

            let assembled = plan.groups.compactMap { renderedGroup(for: $0) }
            guard assembled.count == plan.groups.count else {
                report(
                    PlaybackCollagePreviewError.renderedGroupCountMismatch,
                    whileRendering: plan
                )
                return
            }

            do {
                // Composed once more in full, so the committed image can never
                // be a partial publish that lands late.
                publishedGroups = plan.groups
                publishGeneration += 1
                let composition = try await compose(assembled)
                guard !Task.isCancelled else {
                    return
                }
                guard requestedPlan == plan else {
                    continue
                }
                pruneRenderedGroups(to: plan.groups)
                committedPlan = plan
                publish(composition, for: plan.groups)
                isRendering = false
                errorDescription = nil
                return
            } catch {
                report(error, whileRendering: plan)
                return
            }
        }
    }

    /// Shows what the current plan can show now, in plan order; missing groups
    /// appear once they finish. Copy and Export stay unavailable until the plan
    /// is committed in full.
    private func publishAvailableGroups() {
        guard let plan = requestedPlan else {
            return
        }
        let displayed = displayableGroups(for: plan)
        let displayedGroups = displayed.map(\.group)
        guard displayedGroups != publishedGroups else {
            return
        }
        publishedGroups = displayedGroups
        publishGeneration += 1
        let generation = publishGeneration
        guard !displayed.isEmpty else {
            clearImage()
            return
        }

        let assembled = displayed.map(\.rendered)
        let compose = self.compose
        Task { [weak self] in
            guard let composition = try? await compose(assembled),
                  let self,
                  self.publishGeneration == generation
            else {
                return
            }
            self.publish(composition, for: displayedGroups)
        }
    }

    /// The image and its segments are one publication: a click reads the
    /// segments of the very picture on screen.
    private func publish(
        _ composition: SubtitleCollageComposition,
        for groups: [SubtitleCollageGroup]
    ) {
        image = composition.image
        segments = zip(composition.groupHeights, groups).map { height, group in
            PlaybackCollagePreviewSegment(
                height: height,
                firstCueOrdinal: group.cues.map(\.ordinal).min() ?? 0
            )
        }
    }

    private func clearImage() {
        image = nil
        segments = []
    }

    private func renderBatch(
        _ groups: [SubtitleCollageGroup],
        renderGroup: @escaping RenderGroup
    ) async -> Error? {
        // Unstructured on purpose: cancelling the worker does not cut a batch
        // short, so the worker stops at the batch boundary and nothing waits.
        let renders = groups.map { group in
            Task { () async -> Error? in
                do {
                    let rendered = try await renderGroup(group)
                    self.keep(rendered, for: group)
                    self.publishAvailableGroups()
                    return nil
                } catch {
                    return error
                }
            }
        }
        var failure: Error?
        for render in renders {
            if let error = await render.value {
                failure = failure ?? error
            }
        }
        return failure
    }

    private func report(
        _ error: Error,
        whileRendering plan: SubtitleCollageSelectionPlan
    ) {
        guard !Task.isCancelled,
              !(error is CancellationError),
              requestedPlan == plan
        else {
            return
        }
        committedPlan = nil
        publishedGroups = []
        clearImage()
        isRendering = false
        errorDescription = String(describing: error)
    }

    private func releaseRenderTask(generation: Int) {
        guard requestGeneration == generation else {
            return
        }
        renderTask = nil
    }

    private func stopRendering() {
        requestGeneration += 1
        renderTask?.cancel()
        renderTask = nil
    }

    func invalidate() {
        stopRendering()
        requestedPlan = nil
        committedPlan = nil
        renderedGroups = []
        publishedGroups = []
        clearImage()
        isRendering = false
        errorDescription = nil
    }

    var writeImageToPasteboard: @Sendable (CGImage) async throws -> Void = { image in
        let pngData = try PlaybackScreenshotPasteboardWriter.pngData(for: image)
        try await MainActor.run {
            try PlaybackScreenshotPasteboardWriter.write(pngData)
        }
    }

    var chooseExportDestination: @MainActor (String) -> URL? = { defaultFileName in
        SubtitleCollageSavePanel.destinationURL(defaultFileName: defaultFileName)
    }

    var exportImageToFile: @Sendable (CGImage, URL) async throws -> Void = { image, destinationURL in
        try SubtitleScreenshotExporter.exportCollage(
            image: image,
            to: destinationURL
        )
    }

    var canUseCurrentResult: Bool {
        currentActionResult() != nil
    }

    func actionReadiness() -> PlaybackCollageActionReadiness {
        guard let requestedPlan, !requestedPlan.groups.isEmpty else {
            return .emptySelection
        }
        if errorDescription != nil {
            return .failed
        }
        if isRendering || committedPlan != requestedPlan {
            return .notReady
        }
        guard let image, let committedPlan else {
            return .failed
        }
        return .ready(image: image, plan: committedPlan)
    }

    func currentActionResult() -> (
        image: CGImage,
        plan: SubtitleCollageSelectionPlan
    )? {
        guard case let .ready(image, plan) = actionReadiness() else {
            return nil
        }
        return (image, plan)
    }

    @discardableResult
    func copyCurrentResult(
        completion: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) -> Bool {
        guard let result = currentActionResult() else {
            return false
        }
        let workItem = PlaybackCollageImageActionWorkItem(image: result.image)
        let writeImageToPasteboard = self.writeImageToPasteboard

        Task.detached(priority: .userInitiated) {
            do {
                try await writeImageToPasteboard(workItem.image)
                await MainActor.run {
                    completion?(true)
                }
            } catch {
                print("Failed to copy playback Collage: \(error)")
                await MainActor.run {
                    completion?(false)
                }
            }
        }
        return true
    }

    @discardableResult
    func exportCurrentResult(
        displayTitle: String,
        completion: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) -> Bool {
        guard let result = currentActionResult(),
              let destinationURL = chooseExportDestination(
                SubtitleScreenshotExporter
                    .defaultCollageFileName(
                        displayTitle: displayTitle,
                        plan: result.plan
                    )
              )
        else {
            return false
        }
        let workItem = PlaybackCollageImageActionWorkItem(image: result.image)
        let exportImageToFile = self.exportImageToFile

        Task.detached(priority: .userInitiated) {
            do {
                try await exportImageToFile(workItem.image, destinationURL)
                await MainActor.run {
                    completion?(true)
                }
            } catch {
                print("Failed to export playback Collage: \(error)")
                await MainActor.run {
                    completion?(false)
                }
            }
        }
        return true
    }

    private func renderedGroup(
        for group: SubtitleCollageGroup
    ) -> SubtitleCollageRenderedGroup? {
        renderedGroups.first { $0.group == group }?.rendered
    }

    /// Each rendered group of the plan, and for a missing group the image of a
    /// kept group that shares a cue with it — the same group whose content just
    /// changed — so the preview overwrites it in place instead of removing it
    /// and inserting it back. Each kept image stands in once; a missing group
    /// with nothing to borrow is left out until it renders.
    private func displayableGroups(
        for plan: SubtitleCollageSelectionPlan
    ) -> [(group: SubtitleCollageGroup, rendered: SubtitleCollageRenderedGroup)] {
        var used: [SubtitleCollageGroup] = []
        var displayed: [(group: SubtitleCollageGroup, rendered: SubtitleCollageRenderedGroup)] = []
        for group in plan.groups {
            let cueIDs = Set(group.cues.map(\.id))
            let entry = renderedGroups.first { $0.group == group }
                ?? renderedGroups.first { entry in
                    !used.contains(entry.group)
                        && entry.group.cues.contains { cueIDs.contains($0.id) }
                }
            guard let entry else {
                continue
            }
            used.append(entry.group)
            displayed.append(entry)
        }
        return displayed
    }

    private func keep(
        _ rendered: SubtitleCollageRenderedGroup,
        for group: SubtitleCollageGroup
    ) {
        guard renderedGroup(for: group) == nil else {
            return
        }
        renderedGroups.append((group: group, rendered: rendered))
    }

    private func pruneRenderedGroups(to groups: [SubtitleCollageGroup]) {
        renderedGroups.removeAll { entry in
            !groups.contains(entry.group)
        }
    }
}
