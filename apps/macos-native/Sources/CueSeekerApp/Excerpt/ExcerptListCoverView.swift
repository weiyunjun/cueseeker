import CoreGraphics
import SwiftUI

struct ExcerptListCoverView: View {
    let coverPath: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    @State private var loadedImage: LoadedImage?
    @State private var activeRequestID: UUID?
    @State private var isShimmerVisible = false
    @State private var delayTask: Task<Void, Never>?
    @State private var loadFailed = false

    private struct LoadedImage {
        let path: String
        let image: CGImage
    }

    private var hasValidPath: Bool {
        guard let coverPath, !coverPath.isEmpty else {
            return false
        }
        return true
    }

    var body: some View {
        ZStack {
            if let loadedImage,
               loadedImage.path == coverPath {
                LibraryCoverFillImage(
                    image: loadedImage.image,
                    verticalAlignment: imageVerticalAlignment
                )
                .transition(.opacity)
            } else if hasValidPath && !loadFailed {
                CoverSkeletonShimmerView(isShimmering: isShimmerVisible)
                    .transition(.opacity)
            } else {
                defaultCover
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

    private var defaultCover: some View {
        ZStack {
            Rectangle()
                .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)

            AppIconImage(.bookmarkSimple, size: WorkbenchControlMetrics.redesignCoverPlaceholderIconSize)
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .accessibilityHidden(true)
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
            loadFailed = false
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        if loadedImage?.path != path {
            isShimmerVisible = false
            loadFailed = false

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

            if let image {
                withAnimation(.easeOut(duration: WorkbenchControlMetrics.redesignCoverCrossfadeDuration)) {
                    loadedImage = LoadedImage(path: path, image: image)
                    isShimmerVisible = false
                    loadFailed = false
                }
            } else {
                withAnimation(.easeOut(duration: WorkbenchControlMetrics.redesignCoverCrossfadeDuration)) {
                    loadedImage = nil
                    isShimmerVisible = false
                    loadFailed = true
                }
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
                loadFailed = true
            }
        }
    }
}
