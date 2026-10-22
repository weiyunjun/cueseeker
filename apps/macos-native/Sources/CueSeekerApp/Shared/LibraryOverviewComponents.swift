import CoreGraphics
import SwiftUI

private struct IsWorkbenchSidebarVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MediaCardGridContainerWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private struct MediaCardCoverSizeKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
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

    var mediaCardCoverSize: CGSize? {
        get { self[MediaCardCoverSizeKey.self] }
        set { self[MediaCardCoverSizeKey.self] = newValue }
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
            WorkbenchScrollView {
                VStack(
                    alignment: .leading,
                    spacing: WorkbenchControlMetrics.redesignSpacing4
                ) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
                        WorkbenchButton(
                            title: actionTitle,
                            icon: .plus,
                            action: action
                        )

                        WorkbenchStatusIndicator(summaryText)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    width: geometry.size.width,
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

struct LibraryOverviewGrid<Data: RandomAccessCollection, ItemContent: View>: View
where Data.Element: Identifiable {
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.isWorkbenchSidebarVisible) private var isWorkbenchSidebarVisible
    @Environment(\.mediaCardGridContainerWidth) private var environmentContainerWidth
    @State private var measuredContainerWidth: CGFloat = 0
    private let items: [Data.Element]
    private let content: (Data.Element) -> ItemContent

    init(
        items: Data,
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = Array(items)
        self.content = content
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

    private var effectiveWidth: CGFloat {
        environmentContainerWidth ?? measuredContainerWidth
    }

    private var resolvedColumnCount: Int {
        guard effectiveWidth > 0 else {
            return maxColumns
        }
        return Self.columnCount(
            containerWidth: effectiveWidth,
            maxColumns: maxColumns
        )
    }

    private var cardWidth: CGFloat? {
        guard effectiveWidth > 0 else {
            return nil
        }
        let gap = WorkbenchControlMetrics.redesignLibraryRecentGridGap
        let totalGap = CGFloat(max(0, resolvedColumnCount - 1)) * gap
        return max(
            0,
            (effectiveWidth - totalGap) / CGFloat(max(1, resolvedColumnCount))
        )
    }

    private var coverSize: CGSize? {
        guard let cardWidth else {
            return nil
        }
        let coverWidth = max(
            0,
            cardWidth - WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding * 2
        )
        let coverHeight = coverWidth / WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
        guard coverWidth > 0 && coverHeight > 0 else {
            return nil
        }
        return CGSize(width: coverWidth, height: coverHeight)
    }

    private var rows: [[Data.Element]] {
        let count = max(1, resolvedColumnCount)
        guard !items.isEmpty else {
            return []
        }
        return stride(from: 0, to: items.count, by: count).map { start in
            Array(items[start..<min(start + count, items.count)])
        }
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap
        ) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowItems in
                HStack(
                    alignment: .top,
                    spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap
                ) {
                    if let cardWidth {
                        ForEach(rowItems) { item in
                            content(item)
                                .frame(width: cardWidth, alignment: .topLeading)
                        }
                    } else {
                        ForEach(rowItems) { item in
                            content(item)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        if rowItems.count < resolvedColumnCount {
                            ForEach(0..<(resolvedColumnCount - rowItems.count), id: \.self) { _ in
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: 0)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
        .environment(\.mediaCardCoverSize, coverSize)
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
    @Environment(\.mediaCardCoverSize) private var environmentCoverSize
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if let environmentCoverSize,
               environmentCoverSize.width > 0,
               environmentCoverSize.height > 0 {
                content
                    .frame(
                        width: environmentCoverSize.width,
                        height: environmentCoverSize.height
                    )
            } else {
                Color.clear
                    .aspectRatio(
                        WorkbenchControlMetrics.redesignLibraryCoverAspectRatio,
                        contentMode: .fit
                    )
                    .overlay {
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
            }
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
    @Environment(\.mediaCardCoverSize) private var environmentCoverSize
    let image: CGImage
    var verticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top

    var body: some View {
        if let environmentCoverSize,
           environmentCoverSize.width > 0,
           environmentCoverSize.height > 0 {
            renderedImage(containerSize: environmentCoverSize)
                .frame(
                    width: environmentCoverSize.width,
                    height: environmentCoverSize.height,
                    alignment: .topLeading
                )
        } else {
            GeometryReader { proxy in
                renderedImage(containerSize: proxy.size)
            }
        }
    }

    private func renderedImage(containerSize: CGSize) -> some View {
        let layout = LibraryCoverImageFillLayout.resolve(
            sourceSize: CGSize(
                width: image.width,
                height: image.height
            ),
            containerSize: containerSize,
            verticalAlignment: verticalAlignment
        )
        return Image(decorative: image, scale: 1)
            .resizable()
            .frame(
                width: layout.renderedSize.width,
                height: layout.renderedSize.height
            )
            .offset(layout.offset)
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
    var isSelected = false
    var isHovered = false
    var isEnabled = true

    init(
        isSelected: Bool = false,
        isHovered: Bool = false,
        isEnabled: Bool = true
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isEnabled = isEnabled
    }

    init(
        isCurrent: Bool,
        isEnabled: Bool = true
    ) {
        self.isSelected = false
        self.isHovered = isCurrent
        self.isEnabled = isEnabled
    }

    private var backgroundFill: Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return WorkbenchRedesignColors.libraryMediaCardSelectedBg
        }
        if isHovered {
            return WorkbenchRedesignColors.libraryMediaCardHoverBg
        }
        return .clear
    }

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
                .fill(backgroundFill)
            )
            // The card answers the pointer over its whole rectangle, corners
            // included, so the press, the hand and Hover share one area. The
            // rounded background is appearance only and does not narrow it.
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.55)
            .animation(nil, value: isSelected)
            .animation(
                .easeOut(
                    duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration
                ),
                value: isHovered
            )
    }
}
