import CoreGraphics
import SwiftUI

struct ExcerptListCoverView: View {
    let coverPath: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    @State private var loadedImage: LoadedImage?
    @State private var activeRequestID: UUID?
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

    private var key: LibraryCoverImageKey? {
        guard let coverPath, !coverPath.isEmpty else { return nil }
        return LibraryCoverImageKey(path: coverPath, revision: coverPath)
    }

    private var currentImage: CGImage? {
        if let coverPath, let loadedImage, loadedImage.path == coverPath {
            return loadedImage.image
        }
        if let key, let cached = LibraryCoverImagePipeline.shared.cachedImage(for: key) {
            return cached
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let currentImage {
                LibraryCoverFillImage(
                    image: currentImage,
                    verticalAlignment: imageVerticalAlignment
                )
            } else if hasValidPath && !loadFailed {
                Color.clear
            } else {
                defaultCover
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: coverPath) {
            await loadCover(for: coverPath)
        }
        .onDisappear {
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
        guard let path, !path.isEmpty else {
            activeRequestID = nil
            loadedImage = nil
            loadFailed = false
            return
        }

        let key = LibraryCoverImageKey(
            path: path,
            revision: path
        )

        if let cached = LibraryCoverImagePipeline.shared.cachedImage(for: key) {
            activeRequestID = nil
            loadedImage = LoadedImage(path: path, image: cached)
            loadFailed = false
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        if loadedImage?.path != path {
            loadFailed = false
        }

        do {
            let image = try await LibraryCoverImagePipeline.shared.image(for: key)
            try Task.checkCancellation()

            guard activeRequestID == requestID else {
                return
            }

            if let image {
                loadedImage = LoadedImage(path: path, image: image)
                loadFailed = false
            } else {
                loadedImage = nil
                loadFailed = true
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID else {
                return
            }
            loadedImage = nil
            loadFailed = true
        }
    }
}
