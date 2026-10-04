import CoreGraphics
import SwiftUI

struct ExcerptListCoverView: View {
    let coverPath: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    @State private var loadedImage: LoadedImage?
    @State private var activeRequestID: UUID?
    @State private var isShimmerVisible = false
    @State private var delayTask: Task<Void, Never>?

    private struct LoadedImage {
        let path: String
        let image: CGImage
    }

    var body: some View {
        ZStack {
            if loadedImage?.path != coverPath {
                CoverSkeletonShimmerView(isShimmering: isShimmerVisible)
                    .transition(.opacity)
            }

            if let loadedImage,
               loadedImage.path == coverPath {
                LibraryCoverFillImage(
                    image: loadedImage.image,
                    verticalAlignment: imageVerticalAlignment
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: coverPath) {
            await loadCover(for: coverPath)
        }
        .onDisappear {
            delayTask?.cancel()
            delayTask = nil
            activeRequestID = nil
        }
    }

    @MainActor
    private func loadCover(for path: String?) async {
        delayTask?.cancel()
        delayTask = nil

        guard let path, !path.isEmpty else {
            activeRequestID = nil
            loadedImage = nil
            isShimmerVisible = false
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        if loadedImage?.path != path {
            isShimmerVisible = false

            delayTask = Task {
                try? await Task.sleep(nanoseconds: WorkbenchControlMetrics.redesignCoverAntiFlickerDelayNanoseconds)
                guard !Task.isCancelled, activeRequestID == requestID else { return }
                withAnimation(.easeIn(duration: 0.15)) {
                    isShimmerVisible = true
                }
            }
        }

        let key = LibraryCoverImageKey(
            path: path,
            revision: path
        )

        do {
            let image = try await LibraryCoverImagePipeline.shared.image(for: key)
            try Task.checkCancellation()
            delayTask?.cancel()
            delayTask = nil

            guard activeRequestID == requestID else {
                return
            }

            withAnimation(.easeOut(duration: WorkbenchControlMetrics.redesignCoverCrossfadeDuration)) {
                loadedImage = image.map { LoadedImage(path: path, image: $0) }
                isShimmerVisible = false
            }
        } catch is CancellationError {
            delayTask?.cancel()
            delayTask = nil
            return
        } catch {
            delayTask?.cancel()
            delayTask = nil
            guard activeRequestID == requestID else {
                return
            }
            withAnimation(.easeOut(duration: WorkbenchControlMetrics.redesignCoverCrossfadeDuration)) {
                loadedImage = nil
                isShimmerVisible = false
            }
        }
    }
}
