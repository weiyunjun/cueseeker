import CueSeekerCore
import SwiftUI

struct LibraryEpisodeGrid: View {
    let rows: [LibraryVideoRow]
    let selectedLibraryVideoPath: String?
    let onOpenVideo: (LibraryVideoRow) -> Void

    var body: some View {
        // v6 `.library-episode-grid`: a wrapping flow (not a fixed-column
        // grid) with gap 10, left-indented 30 to express folder→episode
        // hierarchy. A flow honors the content-driven episode width so a long
        // rank (`EP120`) widens its own card instead of forcing a uniform
        // column (owner decision 2).
        WrapFlowLayout(
            horizontalSpacing: LibraryLayout.gridGap,
            verticalSpacing: LibraryLayout.gridGap
        ) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LibraryEpisodeButton(
                    rank: index + 1,
                    isPlaying: row.video.videoPath == selectedLibraryVideoPath,
                    action: { onOpenVideo(row) }
                )
                .id(row.video.videoPath)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, LibraryLayout.gridLeadingIndent)
        .padding(.top, LibraryLayout.gridTopPadding)
        .padding(.bottom, LibraryLayout.gridBottomPadding)
    }
}

/// Wrapping flow layout for the Library episode grid — places content-width
/// children left to right, wrapping to the next line at the container width.
private struct WrapFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + horizontalSpacing + size.width > maxWidth {
                totalHeight += rowHeight + verticalSpacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? horizontalSpacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : widestRow,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum LibraryLayout {
    static let groupTopPadding: CGFloat = 12
    static let groupBottomPadding: CGFloat = 10
    static let groupBottomMargin: CGFloat = 6
    static let folderHeaderMaxWidth: CGFloat = 720
    static let folderHeaderInsets = EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 8)
    static let folderHeaderCornerRadius: CGFloat = 7
    static let folderHeaderGap: CGFloat = 10
    static let chevronBox: CGFloat = 16
    static let chevronGlyph: CGFloat = 13
    static let chevronTopInset: CGFloat = 2
    static let headingLineGap: CGFloat = 2
    static let titleSize: CGFloat = 13.5
    static let countSize: CGFloat = 12
    static let episodeMinWidth: CGFloat = 66
    static let episodeHeight: CGFloat = 42
    static let episodeHorizontalPadding: CGFloat = 14
    static let episodeCornerRadius: CGFloat = 8
    static let episodeLabelSize: CGFloat = 12.5
    static let gridGap: CGFloat = 10
    static let gridLeadingIndent: CGFloat = 30
    static let gridTopPadding: CGFloat = 8
    static let gridBottomPadding: CGFloat = 12
}
