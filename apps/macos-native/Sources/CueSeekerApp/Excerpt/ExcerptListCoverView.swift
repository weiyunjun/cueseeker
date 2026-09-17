import CoreGraphics
import SwiftUI

struct ExcerptListCoverView: View {
    let coverPath: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    @State private var loadedImage: CGImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)

            if let loadedImage {
                LibraryCoverFillImage(
                    image: loadedImage,
                    verticalAlignment: imageVerticalAlignment
                )
            } else {
                AppIconImage(.heart, size: WorkbenchControlMetrics.redesignCoverPlaceholderIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: coverPath) {
            await loadCover()
        }
    }

    @MainActor
    private func loadCover() async {
        guard let coverPath, !coverPath.isEmpty else {
            loadedImage = nil
            return
        }
        let key = LibraryCoverImageKey(
            path: coverPath,
            revision: coverPath
        )
        do {
            loadedImage = try await LibraryCoverImagePipeline.shared.image(for: key)
        } catch {
            loadedImage = nil
        }
    }
}
