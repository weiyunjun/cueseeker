import CoreGraphics
import SwiftUI

struct LibraryOverviewLayout<Content: View>: View {
    let title: String
    let summaryText: String
    let actionTitle: String
    let actionSystemImage: String
    let action: () -> Void
    private let content: Content

    init(
        title: String,
        summaryText: String,
        actionTitle: String,
        actionSystemImage: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summaryText = summaryText
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.action = action
        self.content = content()
    }

    var body: some View {
        WorkbenchScrollView {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignSpacing4
            ) {
                WorkbenchPageTitle(title)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    Text(summaryText)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                    Spacer(minLength: 0)

                    WorkbenchPlainActionButton(
                        title: actionTitle,
                        systemImage: actionSystemImage,
                        isRedesign: true,
                        action: action
                    )
                }
                .frame(height: WorkbenchControlMetrics.redesignHeight)

                content
            }
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignSpacing6
            )
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

struct LibraryOverviewGrid<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth,
                    maximum: WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
                ),
                spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap,
                alignment: .topLeading
            )
        ]
    }

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap
        ) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LibraryCoverFrame<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Color.clear
            .aspectRatio(
                WorkbenchControlMetrics.redesignLibraryCoverAspectRatio,
                contentMode: .fit
            )
            .overlay {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignLibraryCoverRadius,
                    style: .continuous
                )
            )
    }
}

struct LibraryCoverImageFillLayout: Equatable {
    enum VerticalAlignment {
        case top
        case center
    }

    let renderedSize: CGSize
    let offset: CGSize

    static func resolve(
        sourceSize: CGSize,
        containerSize: CGSize,
        verticalAlignment: VerticalAlignment = .top
    ) -> LibraryCoverImageFillLayout {
        let scale = max(
            containerSize.width / sourceSize.width,
            containerSize.height / sourceSize.height
        )
        let renderedSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        return LibraryCoverImageFillLayout(
            renderedSize: renderedSize,
            offset: CGSize(
                width: (containerSize.width - renderedSize.width) / 2,
                height: verticalAlignment == .center
                    ? (containerSize.height - renderedSize.height) / 2
                    : 0
            )
        )
    }
}

struct LibraryCoverFillImage: View {
    let image: CGImage
    var verticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top

    var body: some View {
        GeometryReader { proxy in
            let layout = LibraryCoverImageFillLayout.resolve(
                sourceSize: CGSize(
                    width: image.width,
                    height: image.height
                ),
                containerSize: proxy.size,
                verticalAlignment: verticalAlignment
            )
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(
                    width: layout.renderedSize.width,
                    height: layout.renderedSize.height
                )
                .offset(layout.offset)
        }
    }
}

struct LibraryOverviewCardContent<Cover: View>: View {
    let title: String
    let description: String?
    private let cover: Cover

    init(
        title: String,
        description: String? = nil,
        @ViewBuilder cover: () -> Cover
    ) {
        self.title = title
        self.description = description
        self.cover = cover()
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            cover

            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeLibraryTitle,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let description {
                Text(description.isEmpty ? "\u{00A0}" : description)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeLibraryMeta,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct LibraryOverviewCardButtonStyle: ButtonStyle {
    let isHovered: Bool
    var isSelected = false
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding)
            .frame(
                maxWidth: WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius,
                    style: .continuous
                )
                .fill(
                    (isHovered || isSelected) && isEnabled
                        ? WorkbenchRedesignColors.libraryMediaCardHoverBg
                        : Color.clear
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius,
                    style: .continuous
                )
            )
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(
                configuration.isPressed && isEnabled
                    ? WorkbenchControlMetrics.redesignLibraryMediaCardPressedScale
                    : 1
            )
            .animation(
                .easeOut(
                    duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration
                ),
                value: configuration.isPressed
            )
            .animation(
                .easeOut(
                    duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration
                ),
                value: isHovered
            )
    }
}
