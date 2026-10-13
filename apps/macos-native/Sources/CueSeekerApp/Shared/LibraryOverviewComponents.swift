import CoreGraphics
import SwiftUI

private struct IsWorkbenchSidebarVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MediaCardGridContainerWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var isWorkbenchSidebarVisible: Bool {
        get { self[IsWorkbenchSidebarVisibleKey.self] }
        set { self[IsWorkbenchSidebarVisibleKey.self] = newValue }
    }

    var mediaCardGridContainerWidth: CGFloat? {
        get { self[MediaCardGridContainerWidthKey.self] }
        set { self[MediaCardGridContainerWidthKey.self] = newValue }
    }
}

struct LibraryOverviewLayout<Content: View>: View {
    let summaryText: String
    let actionTitle: String
    let action: () -> Void
    private let content: Content

    init(
        summaryText: String,
        actionTitle: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.summaryText = summaryText
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(
                    alignment: .leading,
                    spacing: WorkbenchControlMetrics.redesignSpacing4
                ) {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    WorkbenchStatusIndicator(summaryText)

                    Spacer(minLength: 0)

                    WorkbenchButton(
                        title: actionTitle,
                        icon: .plus,
                        isRedesign: true,
                        action: action
                    )
                }
                .frame(height: WorkbenchControlMetrics.redesignHeight)
                .workbenchPageInlinePadding()

                content
                    .workbenchMediaCardGridInlinePadding()
                    .environment(
                        \.mediaCardGridContainerWidth,
                        WorkbenchControlMetrics.workbenchMediaCardGridWidth(
                            viewportWidth: geometry.size.width
                        )
                    )
            }
            .padding(
                .top,
                WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
            )
            .padding(
                .bottom,
                WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
            )
                .frame(
                    width: max(
                        geometry.size.width,
                        AppShellLayout.pageContentMinimumWidth
                    ),
                    alignment: .topLeading
                )
                .frame(
                    minHeight: geometry.size.height,
                    alignment: .topLeading
                )
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

struct LibraryOverviewGrid<Content: View>: View {
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.isWorkbenchSidebarVisible) private var isWorkbenchSidebarVisible
    @Environment(\.mediaCardGridContainerWidth) private var environmentContainerWidth
    @State private var measuredContainerWidth: CGFloat = 0
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    static func columnCount(
        containerWidth: CGFloat,
        minimumItemWidth: CGFloat = WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth,
        itemGap: CGFloat = WorkbenchControlMetrics.redesignLibraryRecentGridGap,
        maxColumns: Int = WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithoutSidebar
    ) -> Int {
        WorkbenchControlMetrics.mediaCardGridColumnCount(
            containerWidth: containerWidth,
            minimumItemWidth: minimumItemWidth,
            itemGap: itemGap,
            maxColumns: maxColumns
        )
    }

    private var maxColumns: Int {
        layerContext.layer == .workbenchPage && isWorkbenchSidebarVisible
            ? WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithSidebar
            : WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithoutSidebar
    }

    private var columns: [GridItem] {
        let effectiveWidth = environmentContainerWidth ?? measuredContainerWidth
        guard effectiveWidth > 0 else {
            return [
                GridItem(
                    .adaptive(
                        minimum: WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth,
                        maximum: .infinity
                    ),
                    spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap,
                    alignment: .topLeading
                )
            ]
        }
        let resolvedColumnCount = Self.columnCount(
            containerWidth: effectiveWidth,
            maxColumns: maxColumns
        )
        return Array(
            repeating: GridItem(
                .flexible(
                    minimum: WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth,
                    maximum: .infinity
                ),
                spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap,
                alignment: .topLeading
            ),
            count: resolvedColumnCount
        )
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
        .background {
            if environmentContainerWidth == nil {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            measuredContainerWidth = proxy.size.width
                        }
                        .onChange(of: proxy.size.width) { width in
                            measuredContainerWidth = width
                        }
                }
            }
        }
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

struct LibraryCoverChooser<Content: View>: View {
    let title: String
    let icon: AppIcon
    let isEnabled: Bool
    let action: () -> Void
    private let content: Content

    @State private var isHovered = false

    init(
        title: String,
        icon: AppIcon,
        isEnabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            LibraryCoverFrame {
                ZStack {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isHovered && isEnabled {
                        WorkbenchRedesignColors.libraryCoverEditOverlay

                        VStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                            AppIconImage(
                                icon,
                                size: WorkbenchControlMetrics.redesignLibraryCoverEditOverlayIconSize
                            )

                            Text(title)
                                .font(.system(
                                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                                ))
                        }
                        .foregroundStyle(WorkbenchRedesignColors.libraryCoverEditOverlayContent)
                    }
                }
            }
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .disabled(!isEnabled)
        .onPointerHover { isHovered = $0 && isEnabled }
        .onChange(of: isEnabled) { enabled in
            if !enabled {
                isHovered = false
            }
        }
        .accessibilityLabel(title)
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
    let isCurrent: Bool
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding)
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius,
                    style: .continuous
                )
                .fill(
                    isCurrent && isEnabled
                        ? WorkbenchRedesignColors.libraryMediaCardHoverBg
                        : Color.clear
                )
            )
            // The card answers the pointer over its whole rectangle, corners
            // included, so the press, the hand and Hover share one area. The
            // rounded background is appearance only and does not narrow it.
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.55)
            .animation(
                .easeOut(
                    duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration
                ),
                value: isCurrent
            )
    }
}
