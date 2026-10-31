import CoreGraphics
import SwiftUI

struct ExcerptListCoverView<Overlay: View>: View {
    let coverPath: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    private let overlay: Overlay
    @State private var loadedImage: LoadedImage?
    @State private var activeRequestID: UUID?
    @State private var loadFailed = false

    private struct LoadedImage {
        let path: String
        let image: CGImage
    }

    init(
        coverPath: String?,
        imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    ) where Overlay == EmptyView {
        self.coverPath = coverPath
        self.imageVerticalAlignment = imageVerticalAlignment
        self.overlay = EmptyView()
    }

    init(
        coverPath: String?,
        imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.coverPath = coverPath
        self.imageVerticalAlignment = imageVerticalAlignment
        self.overlay = overlay()
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

    private var isDecodeFailed: Bool {
        if loadFailed {
            return true
        }
        guard let key else {
            return false
        }
        return LibraryCoverImagePipeline.shared.hasFailedDecode(for: key)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let currentImage {
                LibraryCoverFillImage(
                    image: currentImage,
                    verticalAlignment: imageVerticalAlignment
                )
                overlay
            } else if hasValidPath && !isDecodeFailed {
                Color.clear
            } else {
                defaultCover
                overlay
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
            if activeRequestID != nil {
                activeRequestID = nil
            }
            if loadedImage?.path != path || loadFailed {
                loadedImage = LoadedImage(path: path, image: cached)
                loadFailed = false
            }
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
