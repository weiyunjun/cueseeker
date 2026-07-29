import Combine
import CoreGraphics
import CueSeekerCore
import CueSeekerPlayback
import Foundation

enum PlaybackCollagePreviewError: Error {
    case renderedGroupCountMismatch
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
        committedGroups = []
        committedRenderedGroups = []
        image = nil
        isRendering = false
        errorDescription = nil
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
