import SwiftUI

struct LibraryFolderHeader: View {
    let folderTitle: String
    let episodeCount: Int
    let playingRank: Int?
    let isCollapsed: Bool
    let onToggle: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // v6 `.library-group-header`: align-items flex-start, gap 10, padding
        // 8 8 8 4, max width 720, radius 7 + subtle hover; shared chevron in a
        // 16pt box (text-3, 0°/90° over 160ms) with a 2pt top inset.
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: LibraryLayout.folderHeaderGap) {
                Image(systemName: "chevron.right")
                    .font(.system(size: LibraryLayout.chevronGlyph, weight: .semibold))
                    .foregroundStyle(tokens.text3)
                    .frame(
                        width: LibraryLayout.chevronBox,
                        height: LibraryLayout.chevronBox,
                        alignment: .center
                    )
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.16), value: isCollapsed)
                    .padding(.top, LibraryLayout.chevronTopInset)

                VStack(alignment: .leading, spacing: LibraryLayout.headingLineGap) {
                    Text(folderTitle)
                        .font(.system(size: LibraryLayout.titleSize, weight: .bold))
                        .foregroundStyle(tokens.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitleText)
                        .font(.system(size: LibraryLayout.countSize))
                        .foregroundStyle(tokens.text3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(LibraryLayout.folderHeaderInsets)
            .frame(maxWidth: LibraryLayout.folderHeaderMaxWidth, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: LibraryLayout.folderHeaderCornerRadius,
                    style: .continuous
                )
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
    }

    private var subtitleText: String {
        let label = episodeCount == 1
            ? L("library.episode_count.one")
            : L("library.episode_count.other", episodeCount)
        if let rank = playingRank {
            return L("library.playing_episode", label, rank)
        }
        return label
    }
}
