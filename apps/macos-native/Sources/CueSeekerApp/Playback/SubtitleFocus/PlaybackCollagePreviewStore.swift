import AppKit
import Combine
import CoreGraphics
import CueSeekerCore
import CueSeekerPlayback
import Foundation

enum PlaybackCollagePreviewError: Error {
    case renderedGroupCountMismatch
}

private struct PlaybackCollageImageActionWorkItem: @unchecked Sendable {
    let image: CGImage
}

@MainActor
final class PlaybackCollagePreviewStore: ObservableObject {
    typealias RenderGroup = (
        SubtitleCollageGroup
    ) async throws -> SubtitleCollageRenderedGroup
    typealias Compose = (
        [SubtitleCollageRenderedGroup]
    ) async throws -> CGImage

    @Published private(set) var image: CGImage?
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
    private var requestGeneration = 0
    private var renderTask: Task<Void, Never>?

    init(
        videoURL: URL,
        subtitleSource: PlaybackSubtitleSource
    ) {
        renderGroup = { group in
            let rendered = try await SubtitleScreenshotExporter.renderCollageGroups(
                [group],
                videoURL: videoURL,
                subtitleSource: subtitleSource
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
            image = nil
            isRendering = false
            return
        }

        isRendering = true
        startRenderingIfNeeded()
    }

    private func startRenderingIfNeeded() {
        guard renderTask == nil else {
            // The running worker re-reads the requested plan after each group,
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

            if let missing = plan.groups.first(where: { renderedGroup(for: $0) == nil }) {
                do {
                    // Never interrupted: one group is rendered to completion and
                    // kept, then the loop picks up whatever plan is current now.
                    let rendered = try await renderGroup(missing)
                    keep(rendered, for: missing)
                } catch {
                    report(error, whileRendering: plan)
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
                let renderedImage = try await compose(assembled)
                guard !Task.isCancelled else {
                    return
                }
                guard requestedPlan == plan else {
                    continue
                }
                pruneRenderedGroups(to: plan.groups)
                committedPlan = plan
                image = renderedImage
                isRendering = false
                errorDescription = nil
                return
            } catch {
                report(error, whileRendering: plan)
                return
            }
        }
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
        image = nil
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
        image = nil
        isRendering = false
        errorDescription = nil
    }

    var canUseCurrentResult: Bool {
        currentActionResult() != nil
    }

    func currentActionResult() -> (
        image: CGImage,
        plan: SubtitleCollageSelectionPlan
    )? {
        guard !isRendering,
              let image,
              let committedPlan,
              committedPlan == requestedPlan
        else {
            return nil
        }
        return (image, committedPlan)
    }

    @discardableResult
    func copyCurrentResult() -> Bool {
        guard let result = currentActionResult() else {
            return false
        }
        let workItem = PlaybackCollageImageActionWorkItem(image: result.image)

        Task.detached(priority: .userInitiated) {
            do {
                let pngData = try PlaybackScreenshotPasteboardWriter.pngData(
                    for: workItem.image
                )
                try await MainActor.run {
                    try PlaybackScreenshotPasteboardWriter.write(pngData)
                }
            } catch {
                print("Failed to copy playback Collage: \(error)")
            }
        }
        return true
    }

    @discardableResult
    func exportCurrentResult(displayTitle: String) -> Bool {
        guard let result = currentActionResult(),
              let destinationURL = SubtitleCollageSavePanel.destinationURL(
                defaultFileName: SubtitleScreenshotExporter
                    .defaultCollageFileName(
                        displayTitle: displayTitle,
                        plan: result.plan
                    )
              )
        else {
            return false
        }
        let workItem = PlaybackCollageImageActionWorkItem(image: result.image)

        Task.detached(priority: .userInitiated) {
            do {
                try SubtitleScreenshotExporter.exportCollage(
                    image: workItem.image,
                    to: destinationURL
                )
            } catch {
                print("Failed to export playback Collage: \(error)")
            }
        }
        return true
    }

    private func renderedGroup(
        for group: SubtitleCollageGroup
    ) -> SubtitleCollageRenderedGroup? {
        renderedGroups.first { $0.group == group }?.rendered
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
