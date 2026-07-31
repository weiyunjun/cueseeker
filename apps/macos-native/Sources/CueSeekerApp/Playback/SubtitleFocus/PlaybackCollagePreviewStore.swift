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
    typealias RenderGroups = (
        [SubtitleCollageGroup]
    ) async throws -> [SubtitleCollageRenderedGroup]
    typealias Compose = (
        [SubtitleCollageRenderedGroup]
    ) async throws -> CGImage

    @Published private(set) var image: CGImage?
    @Published private(set) var isRendering = false
    @Published private(set) var errorDescription: String?

    private let renderGroups: RenderGroups
    private let compose: Compose
    private var requestedPlan: SubtitleCollageSelectionPlan?
    private var committedPlan: SubtitleCollageSelectionPlan?
    private var committedGroups: [SubtitleCollageGroup] = []
    private var committedRenderedGroups: [SubtitleCollageRenderedGroup] = []
    private var requestGeneration = 0
    private var renderTask: Task<Void, Never>?

    init(
        videoURL: URL,
        subtitleSource: PlaybackSubtitleSource
    ) {
        renderGroups = { groups in
            try await SubtitleScreenshotExporter.renderCollageGroups(
                groups,
                videoURL: videoURL,
                subtitleSource: subtitleSource
            )
        }
        compose = { renderedGroups in
            try await Task.detached(priority: .userInitiated) {
                try SubtitleScreenshotExporter.composeCollage(renderedGroups)
            }.value
        }
    }

    init(
        renderGroups: @escaping RenderGroups,
        compose: @escaping Compose
    ) {
        self.renderGroups = renderGroups
        self.compose = compose
    }

    func update(plan: SubtitleCollageSelectionPlan) {
        guard requestedPlan != plan else {
            return
        }

        requestedPlan = plan
        requestGeneration += 1
        let generation = requestGeneration
        renderTask?.cancel()

        guard !plan.groups.isEmpty else {
            committedPlan = nil
            committedGroups = []
            committedRenderedGroups = []
            image = nil
            isRendering = false
            errorDescription = nil
            return
        }

        let reuse = reusableEdges(
            previousGroups: committedGroups,
            currentGroups: plan.groups,
            previousRenderedGroupCount: committedRenderedGroups.count
        )
        let groupsToRender = Array(plan.groups[reuse.currentReplacementRange])
        let prefix = Array(
            committedRenderedGroups.prefix(reuse.prefixCount)
        )
        let suffix = reuse.suffixCount == 0
            ? []
            : Array(committedRenderedGroups.suffix(reuse.suffixCount))
        let renderGroups = self.renderGroups
        let compose = self.compose

        isRendering = true
        errorDescription = nil
        renderTask = Task { [weak self] in
            do {
                let replacement = try await renderGroups(groupsToRender)
                try Task.checkCancellation()
                guard replacement.count == groupsToRender.count else {
                    throw PlaybackCollagePreviewError.renderedGroupCountMismatch
                }

                let renderedGroups = prefix + replacement + suffix
                let renderedImage = try await compose(renderedGroups)
                try Task.checkCancellation()
                guard let self,
                      self.requestGeneration == generation,
                      self.requestedPlan == plan
                else {
                    return
                }

                self.committedGroups = plan.groups
                self.committedRenderedGroups = renderedGroups
                self.committedPlan = plan
                self.image = renderedImage
                self.isRendering = false
                self.errorDescription = nil
                self.renderTask = nil
            } catch {
                guard let self,
                      self.requestGeneration == generation,
                      self.requestedPlan == plan,
                      !Task.isCancelled,
                      !(error is CancellationError)
                else {
                    return
                }
                self.committedPlan = nil
                self.image = nil
                self.isRendering = false
                self.errorDescription = String(describing: error)
                self.renderTask = nil
            }
        }
    }

    func invalidate() {
        requestGeneration += 1
        renderTask?.cancel()
        renderTask = nil
        requestedPlan = nil
        committedPlan = nil
        committedGroups = []
        committedRenderedGroups = []
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

    private func reusableEdges(
        previousGroups: [SubtitleCollageGroup],
        currentGroups: [SubtitleCollageGroup],
        previousRenderedGroupCount: Int
    ) -> (
        prefixCount: Int,
        suffixCount: Int,
        currentReplacementRange: Range<Int>
    ) {
        guard previousRenderedGroupCount == previousGroups.count else {
            return (0, 0, currentGroups.indices)
        }

        let sharedCount = min(previousGroups.count, currentGroups.count)
        var prefixCount = 0
        while prefixCount < sharedCount,
              previousGroups[prefixCount] == currentGroups[prefixCount] {
            prefixCount += 1
        }

        var suffixCount = 0
        while suffixCount < sharedCount - prefixCount,
              previousGroups[previousGroups.count - suffixCount - 1]
                == currentGroups[currentGroups.count - suffixCount - 1] {
            suffixCount += 1
        }

        return (
            prefixCount,
            suffixCount,
            prefixCount..<(currentGroups.count - suffixCount)
        )
    }
}
