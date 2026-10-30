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

struct WorkbenchOverviewActionBarLayout: Layout {
    struct Resolution: Equatable {
        let searchFieldWidth: CGFloat
        let wrapsStatusToSecondRow: Bool
        let totalSize: CGSize
    }

    static func resolve(
        availableWidth: CGFloat,
        buttonWidths: [CGFloat],
        statusSize: CGSize,
        preferredSearchWidth: CGFloat = WorkbenchControlMetrics.redesignOverviewSearchFieldWidth,
        minSearchWidth: CGFloat = WorkbenchControlMetrics.redesignOverviewSearchFieldMinWidth,
        controlHeight: CGFloat = WorkbenchControlMetrics.redesignHeight,
        horizontalSpacing: CGFloat = WorkbenchControlMetrics.redesignSpacing4,
        verticalRowSpacing: CGFloat = WorkbenchControlMetrics.redesignSpacing2
    ) -> Resolution {
        let buttonsWidth = buttonWidths.reduce(0, +)
        let firstRowGaps = CGFloat(buttonWidths.count) * horizontalSpacing
        let firstRowPreferredWidth = preferredSearchWidth + firstRowGaps + buttonsWidth
        let singleRowRequiredWidth = firstRowPreferredWidth
            + (statusSize.width > 0 ? horizontalSpacing + statusSize.width : 0)

        let resolvedAvailableWidth = availableWidth.isFinite
            ? max(0, availableWidth)
            : singleRowRequiredWidth

        if resolvedAvailableWidth >= singleRowRequiredWidth {
            return Resolution(
                searchFieldWidth: preferredSearchWidth,
                wrapsStatusToSecondRow: false,
                totalSize: CGSize(
                    width: resolvedAvailableWidth,
                    height: controlHeight
                )
            )
        }

        let availableForSearch = resolvedAvailableWidth - firstRowGaps - buttonsWidth
        let clampedSearchWidth = min(
            preferredSearchWidth,
            max(minSearchWidth, availableForSearch)
        )
        let totalHeight = controlHeight
            + (statusSize.height > 0 ? verticalRowSpacing + statusSize.height : 0)
        return Resolution(
            searchFieldWidth: clampedSearchWidth,
            wrapsStatusToSecondRow: true,
            totalSize: CGSize(
                width: resolvedAvailableWidth,
                height: totalHeight
            )
        )
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else {
            return .zero
        }
        let buttonSubviews = subviews.count >= 2
            ? Array(subviews.dropFirst().dropLast())
            : []
        let statusSubview = subviews.count >= 2 ? subviews.last : nil
        let buttonWidths = buttonSubviews.map {
            $0.sizeThatFits(.unspecified).width
        }
        let statusSize = statusSubview?.sizeThatFits(.unspecified) ?? .zero
        return Self.resolve(
            availableWidth: proposal.width ?? .infinity,
            buttonWidths: buttonWidths,
            statusSize: statusSize
        ).totalSize
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        guard !subviews.isEmpty else {
            return
        }
        let buttonSubviews = subviews.count >= 2
            ? Array(subviews.dropFirst().dropLast())
            : []
        let statusSubview = subviews.count >= 2 ? subviews.last : nil
        let buttonSizes = buttonSubviews.map {
            $0.sizeThatFits(.unspecified)
        }
        let statusSize = statusSubview?.sizeThatFits(.unspecified) ?? .zero
        let resolution = Self.resolve(
            availableWidth: bounds.width,
            buttonWidths: buttonSizes.map(\.width),
            statusSize: statusSize
        )

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: resolution.searchFieldWidth,
                height: WorkbenchControlMetrics.redesignHeight
            )
        )

        var currentX = bounds.minX
            + resolution.searchFieldWidth
            + WorkbenchControlMetrics.redesignSpacing4
        for (buttonSubview, buttonSize) in zip(buttonSubviews, buttonSizes) {
            let buttonY = bounds.minY
                + (WorkbenchControlMetrics.redesignHeight - buttonSize.height) / 2
            buttonSubview.place(
                at: CGPoint(x: currentX, y: buttonY),
                anchor: .topLeading,
                proposal: ProposedViewSize(buttonSize)
            )
            currentX += buttonSize.width + WorkbenchControlMetrics.redesignSpacing4
        }

        if let statusSubview {
            if resolution.wrapsStatusToSecondRow {
                let statusY = bounds.minY
                    + WorkbenchControlMetrics.redesignHeight
                    + WorkbenchControlMetrics.redesignSpacing2
                statusSubview.place(
                    at: CGPoint(x: bounds.minX, y: statusY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(statusSize)
                )
            } else {
                let statusY = bounds.minY
                    + (WorkbenchControlMetrics.redesignHeight - statusSize.height) / 2
                statusSubview.place(
                    at: CGPoint(x: currentX, y: statusY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(statusSize)
                )
            }
        }
    }
}

struct LibraryOverviewLayout<Content: View>: View {
    let searchPlaceholder: String
    @Binding var searchText: String
    let sortOptions: [SchemaWorkbenchSortOption]
    let selectedSortOptionID: String
    let onSelectSortOption: (String) -> Void
    let summaryText: String
    let actionTitle: String?
    let action: (() -> Void)?
    let emptySearchMessage: String?
    private let content: Content

    init(
        searchPlaceholder: String = "",
        searchText: Binding<String> = .constant(""),
        sortOptions: [SchemaWorkbenchSortOption] = [],
        selectedSortOptionID: String = "",
        onSelectSortOption: @escaping (String) -> Void = { _ in },
        summaryText: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        emptySearchMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.searchPlaceholder = searchPlaceholder
        self._searchText = searchText
        self.sortOptions = sortOptions
        self.selectedSortOptionID = selectedSortOptionID
        self.onSelectSortOption = onSelectSortOption
        self.summaryText = summaryText
        self.actionTitle = actionTitle
        self.action = action
        self.emptySearchMessage = emptySearchMessage
        self.content = content()
    }

    var body: some View {
        SchemaWorkbenchSortMenuHost(
            sortOptions: sortOptions,
            selectedSortOptionID: selectedSortOptionID,
            onSelectSortOption: onSelectSortOption
        ) { sortMenu in
            GeometryReader { geometry in
                let emptyMinHeight = max(
                    0,
                    geometry.size.height
                        - WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                        - WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                        - WorkbenchControlMetrics.redesignHeight
                        - WorkbenchControlMetrics.redesignSpacing4
                )
                WorkbenchScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: WorkbenchControlMetrics.redesignSpacing4
                    ) {
                        WorkbenchAccessibilityReader { accessibility in
                            WorkbenchOverviewActionBarLayout {
                                WorkbenchSearchField(
                                    placeholder: searchPlaceholder,
                                    text: $searchText,
                                    autofocus: false,
                                    isSearchAccessibilityFocused: accessibility?.isFocused(.toolbarSearchField) == true,
                                    isClearAccessibilityFocused: accessibility?.isFocused(.toolbarSearchClearButton) == true,
                                    onBindAccessibilityTextField: { field in
                                        accessibility?.activeSearchTextField = field
                                    }
                                )

                                WorkbenchButton(
                                    title: sortMenu.sortTitle,
                                    icon: .funnelSimple,
                                    isOpen: sortMenu.isSortMenuOpen,
                                    isFocused: accessibility?.isFocused(.toolbarSortButton) == true,
                                    action: sortMenu.toggleSortMenu
                                )
                                .background(MenuAnchorProbe(handle: sortMenu.sortButtonAnchor))

                                if let actionTitle, let action {
                                    WorkbenchButton(
                                        title: actionTitle,
                                        icon: .plus,
                                        isFocused: accessibility?.isFocused(.excerptNewListButton) == true,
                                        action: action
                                    )
                                }

                                WorkbenchStatusIndicator(summaryText)
                            }
                            .onAppear {
                                accessibility?.onToggleToolbarSortMenu = sortMenu.toggleSortMenu
                            }
                            .onDisappear {
                                accessibility?.onToggleToolbarSortMenu = nil
                            }
                        }
                        .workbenchPageInlinePadding()

                        if let emptySearchMessage {
                            WorkbenchEmptyHint(
                                icon: .searchNoResults,
                                message: emptySearchMessage
                            )
                            .frame(minHeight: emptyMinHeight)
                            .workbenchPageInlinePadding()
                        } else {
                            content
                                .workbenchMediaCardGridInlinePadding()
                                .environment(
                                    \.mediaCardGridContainerWidth,
                                    WorkbenchControlMetrics.workbenchMediaCardGridWidth(
                                        viewportWidth: geometry.size.width
                                    )
                                )
                        }
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
        }
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

struct LibraryOverviewGrid<Data: RandomAccessCollection, ItemContent: View>: View
where Data.Element: Identifiable {
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.isWorkbenchSidebarVisible) private var isWorkbenchSidebarVisible
    @Environment(\.mediaCardGridContainerWidth) private var environmentContainerWidth
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
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
        .onAppear {
            if layerContext.layer == .workbenchPage {
                workbenchAccessibility?.cardGridColumnCount = max(1, resolvedColumnCount)
            }
        }
        .onChange(of: resolvedColumnCount) { newCount in
            if layerContext.layer == .workbenchPage {
                workbenchAccessibility?.cardGridColumnCount = max(1, newCount)
            }
        }
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
                .allowsHitTesting(false)

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
                    .allowsHitTesting(false)
            }
        }
    }
}

struct LibraryOverviewCardSurface<Content: View>: View {
    var isSelected = false
    var isHovered = false
    var isFocused = false
    var isEnabled = true
    var animatesHover = true
    let action: () -> Void
    private let content: Content

    init(
        isSelected: Bool = false,
        isHovered: Bool = false,
        isFocused: Bool = false,
        isEnabled: Bool = true,
        animatesHover: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isFocused = isFocused
        self.isEnabled = isEnabled
        self.animatesHover = animatesHover
        self.action = action
        self.content = content()
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

    private var hoverAnimation: Animation? {
        guard animatesHover else {
            return nil
        }
        return .easeOut(
            duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration
        )
    }

    var body: some View {
        content
            .padding(WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding)
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
            .background {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius,
                        style: .continuous
                    )
                    .fill(backgroundFill)

                    if isEnabled {
                        Button(action: action) {
                            Color.clear
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(StaticButtonStyle())
                        .focusable(false)
                    }
                }
            }
            // The card answers the pointer over its whole rectangle, corners
            // included, so the press, the hand and Hover share one area. The
            // rounded background is appearance only and does not narrow it.
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.55)
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius
            )
            .animation(nil, value: isSelected)
            .animation(hoverAnimation, value: isHovered)
    }
}

struct LibraryOverviewCardButtonStyle: ButtonStyle {
    var isSelected = false
    var isHovered = false
    var isEnabled = true
    var animatesHover = true

    init(
        isSelected: Bool = false,
        isHovered: Bool = false,
        isEnabled: Bool = true,
        animatesHover: Bool = true
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isEnabled = isEnabled
        self.animatesHover = animatesHover
    }

    init(
        isCurrent: Bool,
        isEnabled: Bool = true,
        animatesHover: Bool = true
    ) {
        self.isSelected = false
        self.isHovered = isCurrent
        self.isEnabled = isEnabled
        self.animatesHover = animatesHover
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

    private var hoverAnimation: Animation? {
        guard animatesHover else {
            return nil
        }
        return .easeOut(
            duration: WorkbenchControlMetrics.redesignLibraryCoverHoverDuration
        )
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
            .animation(hoverAnimation, value: isHovered)
    }
}
