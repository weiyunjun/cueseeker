import CueSeekerCore
import SwiftUI

struct LibraryFolderGroupView: View {
    let group: LibraryFolderGroup
    let isCollapsed: Bool
    let selectedLibraryVideoPath: String?
    let onToggle: () -> Void
    let onOpenVideo: (LibraryVideo) -> Void

    var body: some View {
        // v6 `.library-group`: top/bottom padding + a bottom margin, and
        // intentionally NO bottom hairline (owner decision 3, a deliberate
        // surface difference vs the Search `.group`).
        VStack(spacing: 0) {
            LibraryFolderHeader(
                folderTitle: group.folderTitle,
                episodeCount: group.videos.count,
                playingRank: playingRank,
                isCollapsed: isCollapsed,
                onToggle: onToggle
            )

            if !isCollapsed {
                LibraryEpisodeGrid(
                    rows: group.videos,
                    selectedLibraryVideoPath: selectedLibraryVideoPath,
                    onOpenVideo: onOpenVideo
                )
            }
        }
        .padding(.top, LibraryLayout.groupTopPadding)
        .padding(.bottom, LibraryLayout.groupBottomPadding + LibraryLayout.groupBottomMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var playingRank: Int? {
        guard let path = selectedLibraryVideoPath,
              let index = group.videos.firstIndex(where: { $0.video.videoPath == path })
        else {
            return nil
        }
        return index + 1
    }
}
