import AppKit
import SwiftUI

enum CoverSummarySecondaryMetadataInteraction: Equatable {
    case none
    case clickablePath(id: String, action: () -> Void)
    case expandableDescription(fullText: String)

    static func == (
        lhs: CoverSummarySecondaryMetadataInteraction,
        rhs: CoverSummarySecondaryMetadataInteraction
    ) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            true
        case (.clickablePath(let lhsID, _), .clickablePath(let rhsID, _)):
            lhsID == rhsID
        case (.expandableDescription(let lhsText), .expandableDescription(let rhsText)):
            lhsText == rhsText
        default:
            false
        }
    }
}

enum CoverSummarySupportingContent: Equatable {
    case description(String)
    case metadata(
        primary: String,
        secondary: String,
        secondaryInteraction: CoverSummarySecondaryMetadataInteraction = .none
    )
}

struct CoverSummaryProgress: Equatable {
    let labelText: String
    let fraction: Double

    init(labelText: String, fraction: Double) {
        self.labelText = labelText
        self.fraction = min(1, max(0, fraction))
    }
}

struct CoverSummarySecondaryAction {
    let title: String
    let icon: AppIcon
    let action: () -> Void
}

enum CoverSummaryActionKind: Equatable {
    case play
    case resume

    var title: String {
        switch self {
        case .play:
            L("library.play")
        case .resume:
            L("library.resume")
        }
    }
}

/// Which of the two accepted Cover Summary forms the available width resolves to.
enum CoverSummaryCardForm: Equatable {
    /// Cover on the leading side, content beside it, no backdrop or scrim.
    case split
    /// Cover fills the card at 16:9, content sits over the scrim.
    case backdrop
}

struct CoverSummaryCardLayout: Equatable {
    let form: CoverSummaryCardForm
    let cardHeight: CGFloat
    let coverFrame: CGRect
    let contentFrame: CGRect
    let scrimEndLocation: CGFloat

    /// Card height for a given available width. Callers that own the page scroll
    /// geometry resolve the header height through this instead of a constant.
    static func height(forCardWidth width: CGFloat) -> CGFloat {
        resolve(containerWidth: width).cardHeight
    }

    static func resolve(containerWidth: CGFloat) -> CoverSummaryCardLayout {
        let width = max(0, containerWidth)
        return width >= WorkbenchControlMetrics.redesignCoverSummarySplitMinimumWidth
            ? splitLayout(width: width)
            : backdropLayout(width: width)
    }

    private static func splitLayout(width: CGFloat) -> CoverSummaryCardLayout {
        let coverWidth = WorkbenchControlMetrics.redesignCoverSummarySplitCoverWidth
        let coverHeight = WorkbenchControlMetrics.redesignCoverSummarySplitCoverHeight
        let contentX = coverWidth + WorkbenchControlMetrics.redesignCoverSummarySplitGap

        return CoverSummaryCardLayout(
            form: .split,
            cardHeight: coverHeight,
            coverFrame: CGRect(x: 0, y: 0, width: coverWidth, height: coverHeight),
            contentFrame: CGRect(
                x: contentX,
                y: 0,
                width: max(0, width - contentX),
                height: coverHeight
            ),
            scrimEndLocation: 1
        )
    }

    private static func backdropLayout(width: CGFloat) -> CoverSummaryCardLayout {
        let height = WorkbenchControlMetrics.redesignCoverSummaryBackdropHeight
        let padding = WorkbenchControlMetrics.redesignCoverSummaryContentPadding
        let availableWidth = max(0, width - padding * 2)
        let preferredWidth = width
            * WorkbenchControlMetrics.redesignCoverSummaryContentPreferredFraction
        let boundedWidth = min(
            WorkbenchControlMetrics.redesignCoverSummaryContentMaxWidth,
            max(
                WorkbenchControlMetrics.redesignCoverSummaryContentMinWidth,
                preferredWidth
            )
        )
        // The content column matches the split form's height, so the text and
        // action area does not resize when the form changes.
        let contentFrame = CGRect(
            x: padding,
            y: WorkbenchControlMetrics.redesignCoverSummaryBackdropBlockPadding,
            width: min(availableWidth, boundedWidth),
            height: WorkbenchControlMetrics.redesignCoverSummarySplitCoverHeight
        )
        let protectedWidth = contentFrame.maxX + padding
        let contentFraction = width > 0 ? protectedWidth / width : 1

        return CoverSummaryCardLayout(
            form: .backdrop,
            cardHeight: height,
            coverFrame: CGRect(x: 0, y: 0, width: width, height: height),
            contentFrame: contentFrame,
            scrimEndLocation: min(
                1,
                max(
                    WorkbenchControlMetrics.redesignCoverSummaryScrimTransparentLocation,
                    contentFraction
                )
            )
        )
    }
}

struct CoverSummaryDescriptionPopoverLayout: Equatable {
    let frame: CGRect
    let textWidth: CGFloat
    let textHeight: CGFloat
    let maxHeight: CGFloat
    let needsScroll: Bool

    static func resolve(
        contentFrame: CGRect,
        descriptionTopOffset: CGFloat,
        descriptionText: String,
        font: NSFont = .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeBody,
            weight: .regular
        )
    ) -> CoverSummaryDescriptionPopoverLayout {
        let paddingX = WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingX
        let paddingY = WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingY
        let lineHeight = WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription
        let clampedTop = min(max(0, descriptionTopOffset), contentFrame.height)
        // C-07.1 Scrollbar is Overlay (Reserved Gutter: None), so the text wrapping
        // width is always the full contentFrame.width.
        let textWidth = max(0, contentFrame.width)
        let popoverWidth = textWidth + paddingX * 2
        // The container expands outward by paddingY (8px) above the first line of text
        // and caps its bottom outer edge at contentFrame.maxY (Action Row bottom edge).
        let maxHeight = max(0, (contentFrame.height - clampedTop) + paddingY)
        let naturalTextHeight = max(
            lineHeight,
            WorkbenchSelectableTextNSView.measuredMultilineHeight(
                for: descriptionText,
                font: font,
                lineHeight: lineHeight,
                width: textWidth
            )
        )
        let unscrolledTotalHeight = naturalTextHeight + paddingY * 2
        let needsScroll = unscrolledTotalHeight > maxHeight + 0.5
        let height = min(maxHeight, unscrolledTotalHeight)

        return CoverSummaryDescriptionPopoverLayout(
            frame: CGRect(
                x: contentFrame.minX - paddingX,
                y: contentFrame.minY + clampedTop - paddingY,
                width: popoverWidth,
                height: height
            ),
            textWidth: textWidth,
            textHeight: naturalTextHeight,
            maxHeight: maxHeight,
            needsScroll: needsScroll
        )
    }
}

private let coverSummaryContentColumnCoordinateSpace = "CoverSummaryCard.contentColumn"

struct CoverSummaryCard<Cover: View>: View {
    let title: String
    let supportingContent: CoverSummarySupportingContent
    let progress: CoverSummaryProgress?
    let actionKind: CoverSummaryActionKind
    let isActionEnabled: Bool
    let action: () -> Void
    let secondaryAction: CoverSummarySecondaryAction?
    let moreMenuAnchor: MenuAnchorHandle?
    let isMoreMenuOpen: Bool
    let onToggleMoreMenu: (() -> Void)?
    let cover: () -> Cover

    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var interfaceLayerContext
    @State private var isDescriptionPopoverOpen = false
    @State private var isSecondaryMetadataHovered = false
    @State private var secondaryLineOffsetY: CGFloat = 68

    init(
        title: String,
        supportingContent: CoverSummarySupportingContent,
        progress: CoverSummaryProgress? = nil,
        actionKind: CoverSummaryActionKind,
        isActionEnabled: Bool,
        action: @escaping () -> Void,
        secondaryAction: CoverSummarySecondaryAction? = nil,
        moreMenuAnchor: MenuAnchorHandle? = nil,
        isMoreMenuOpen: Bool = false,
        onToggleMoreMenu: (() -> Void)? = nil,
        @ViewBuilder cover: @escaping () -> Cover
    ) {
        self.title = title
        self.supportingContent = supportingContent
        self.progress = progress
        self.actionKind = actionKind
        self.isActionEnabled = isActionEnabled
        self.action = action
        self.secondaryAction = secondaryAction
        self.moreMenuAnchor = moreMenuAnchor
        self.isMoreMenuOpen = isMoreMenuOpen
        self.onToggleMoreMenu = onToggleMoreMenu
        self.cover = cover
    }

    var body: some View {
        CoverSummaryCardSizingLayout {
            GeometryReader { proxy in
                let layout = CoverSummaryCardLayout.resolve(
                    containerWidth: proxy.size.width
                )

                ZStack(alignment: .topLeading) {
                    // One cover instance serves both forms. Keeping it out of
                    // any form branch preserves its view identity, so a width
                    // change reuses the already decoded image instead of
                    // rebuilding the cover and falling back to its placeholder
                    // for a few frames.
                    ZStack(alignment: .topLeading) {
                        cover()

                        if layout.form == .backdrop {
                            coverScrim(endLocation: layout.scrimEndLocation)
                        }
                    }
                    .frame(
                        width: layout.coverFrame.width,
                        height: layout.coverFrame.height
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: coverRadius(for: layout.form),
                            style: .continuous
                        )
                    )
                    .allowsHitTesting(false)

                    contentColumn(form: layout.form)
                        .coordinateSpace(name: coverSummaryContentColumnCoordinateSpace)
                        .frame(
                            width: layout.contentFrame.width,
                            height: layout.contentFrame.height,
                            alignment: .topLeading
                        )
                        .offset(
                            x: layout.contentFrame.minX,
                            y: layout.contentFrame.minY
                        )

                    if isDescriptionPopoverOpen,
                       let fullText = expandableDescriptionFullText
                    {
                        let popoverLayout = CoverSummaryDescriptionPopoverLayout.resolve(
                            contentFrame: layout.contentFrame,
                            descriptionTopOffset: secondaryLineOffsetY,
                            descriptionText: fullText
                        )

                        CoverSummaryDescriptionDetailPopover(
                            fullText: fullText,
                            form: layout.form,
                            textColor: supportingColor(for: layout.form),
                            layout: popoverLayout,
                            interfaceLayers: interfaceLayers,
                            interfaceLayerContext: interfaceLayerContext,
                            onDismiss: {
                                isDescriptionPopoverOpen = false
                            }
                        )
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: layout.cardHeight,
                    alignment: .topLeading
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: supportingContent) { _ in
            isDescriptionPopoverOpen = false
        }
        .onChange(of: interfaceLayerContext.isCovered) { isCovered in
            if isCovered {
                isDescriptionPopoverOpen = false
            }
        }
        .onDisappear {
            isDescriptionPopoverOpen = false
        }
    }

    private var expandableDescriptionFullText: String? {
        guard case .metadata(_, _, .expandableDescription(let fullText)) = supportingContent,
              !fullText.isEmpty
        else {
            return nil
        }
        return fullText
    }

    private func coverRadius(for form: CoverSummaryCardForm) -> CGFloat {
        switch form {
        case .split:
            WorkbenchControlMetrics.redesignLibraryCoverRadius
        case .backdrop:
            WorkbenchControlMetrics.redesignCoverSummaryRadius
        }
    }

    private func coverScrim(endLocation: CGFloat) -> LinearGradient {
        let baseEnd = WorkbenchControlMetrics
            .redesignCoverSummaryScrimTransparentLocation
        let locationScale = endLocation / baseEnd

        return LinearGradient(
            stops: [
                .init(
                    color: WorkbenchRedesignColors.coverSummaryScrim.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryScrimLeadingOpacity
                    ),
                    location: WorkbenchControlMetrics
                        .redesignCoverSummaryScrimLeadingLocation
                ),
                .init(
                    color: WorkbenchRedesignColors.coverSummaryScrim.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryScrimStrongOpacity
                    ),
                    location: WorkbenchControlMetrics
                        .redesignCoverSummaryScrimStrongLocation * locationScale
                ),
                .init(
                    color: WorkbenchRedesignColors.coverSummaryScrim.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryScrimMiddleOpacity
                    ),
                    location: WorkbenchControlMetrics
                        .redesignCoverSummaryScrimMiddleLocation * locationScale
                ),
                .init(
                    color: WorkbenchRedesignColors.coverSummaryScrim.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryScrimTrailingOpacity
                    ),
                    location: WorkbenchControlMetrics
                        .redesignCoverSummaryScrimTrailingLocation * locationScale
                ),
                .init(
                    color: WorkbenchRedesignColors.coverSummaryScrim.opacity(0),
                    location: endLocation
                ),
                .init(
                    color: WorkbenchRedesignColors.coverSummaryScrim.opacity(0),
                    location: 1
                ),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func contentColumn(form: CoverSummaryCardForm) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignCoverSummaryTitleMetaGap
            ) {
                WorkbenchSelectableText(
                    title,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeCoverSummaryTitle,
                    weight: WorkbenchControlMetrics.redesignFontWeightCoverSummaryTitle,
                    color: titleColor(for: form),
                    lineLimit: 1,
                    truncationMode: .tail
                )

                supportingContentView(color: supportingColor(for: form))
            }

            // Both forms give the column the same height, so the action row
            // always sits at its bottom-leading corner.
            Spacer(minLength: 0)

            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignCoverSummaryProgressActionsGap
            ) {
                if let progress {
                    progressView(progress, form: form)
                }

                actionRow(for: form)
            }
        }
    }

    private func progressView(
        _ progress: CoverSummaryProgress,
        form: CoverSummaryCardForm
    ) -> some View {
        let clampedFraction = min(1, max(0, progress.fraction))
        let trackWidth = WorkbenchControlMetrics.redesignCoverSummaryProgressWidth
        let trackHeight = WorkbenchControlMetrics.redesignCoverSummaryProgressTrackHeight

        return VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignCoverSummaryProgressLabelGap
        ) {
            WorkbenchSelectableText(
                progress.labelText,
                fontSize: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: .medium,
                monospacedDigits: true,
                color: supportingColor(for: form),
                lineLimit: 1,
                truncationMode: .tail
            )
            .frame(maxWidth: trackWidth, alignment: .leading)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(progressTrackColor(for: form))

                Capsule()
                    .fill(progressFillColor(for: form))
                    .frame(width: trackWidth * clampedFraction)
            }
            .frame(width: trackWidth, height: trackHeight)
        }
    }

    private func actionRow(for form: CoverSummaryCardForm) -> some View {
        WorkbenchAccessibilityReader { accessibility in
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
                primaryActionButton(
                    for: form,
                    isFocused: accessibility?.isFocused(.coverSummaryPrimaryButton) == true
                )

                if let secondaryAction {
                    secondaryActionButton(
                        secondaryAction,
                        for: form,
                        isFocused: accessibility?.isFocused(.coverSummaryEditCoverButton) == true
                    )
                }

                if let onToggleMoreMenu {
                    moreMenuButton(
                        action: onToggleMoreMenu,
                        for: form,
                        isFocused: accessibility?.isFocused(.coverSummaryMoreButton) == true
                    )
                }
            }
            .onAppear {
                accessibility?.onToggleCoverSummaryMoreMenu = onToggleMoreMenu
            }
            .onDisappear {
                accessibility?.onToggleCoverSummaryMoreMenu = nil
            }
        }
    }

    @ViewBuilder
    private func primaryActionButton(for form: CoverSummaryCardForm, isFocused: Bool) -> some View {
        switch form {
        case .split:
            WorkbenchPrimaryButton(
                title: actionKind.title,
                icon: .play,
                iconWeight: .fill,
                isFocused: isFocused,
                action: action
            )
            .disabled(!isActionEnabled)
            .workbenchTooltip(
                scenarioID: "disabled.cover_summary.no_playable_content",
                isActive: !isActionEnabled,
                label: L("tooltip.disabled.cover_summary.no_playable_content")
            )
        case .backdrop:
            CoverSummaryActionButton(
                title: actionKind.title,
                icon: .play,
                iconWeight: .fill,
                isFocused: isFocused,
                action: action
            )
            .disabled(!isActionEnabled)
            .workbenchTooltip(
                scenarioID: "disabled.cover_summary.no_playable_content",
                isActive: !isActionEnabled,
                label: L("tooltip.disabled.cover_summary.no_playable_content")
            )
        }
    }

    @ViewBuilder
    private func secondaryActionButton(
        _ secondaryAction: CoverSummarySecondaryAction,
        for form: CoverSummaryCardForm,
        isFocused: Bool
    ) -> some View {
        switch form {
        case .split:
            WorkbenchButton(
                title: secondaryAction.title,
                icon: secondaryAction.icon,
                isFocused: isFocused,
                action: secondaryAction.action
            )
        case .backdrop:
            CoverSummaryActionButton(
                title: secondaryAction.title,
                icon: secondaryAction.icon,
                iconWeight: nil,
                isFocused: isFocused,
                action: secondaryAction.action
            )
        }
    }

    private func moreMenuButton(
        action: @escaping () -> Void,
        for form: CoverSummaryCardForm,
        isFocused: Bool
    ) -> some View {
        ZStack {
            switch form {
            case .split:
                WorkbenchButton(
                    icon: .dotsThree,
                    isOpen: isMoreMenuOpen,
                    isFocused: isFocused,
                    action: action
                )
            case .backdrop:
                CoverSummaryActionButton(
                    title: nil,
                    icon: .dotsThree,
                    iconWeight: nil,
                    isOpen: isMoreMenuOpen,
                    isFocused: isFocused,
                    action: action
                )
            }
        }
        .background {
            if let moreMenuAnchor {
                MenuAnchorProbe(handle: moreMenuAnchor)
            }
        }
    }

    private func titleColor(for form: CoverSummaryCardForm) -> Color {
        switch form {
        case .split:
            WorkbenchRedesignColors.textPrimary
        case .backdrop:
            WorkbenchRedesignColors.coverSummaryText
        }
    }

    private func supportingColor(for form: CoverSummaryCardForm) -> Color {
        switch form {
        case .split:
            WorkbenchRedesignColors.textSecondary
        case .backdrop:
            WorkbenchRedesignColors.coverSummaryText.opacity(
                WorkbenchControlMetrics.redesignCoverSummaryDescriptionOpacity
            )
        }
    }

    private func progressTrackColor(for form: CoverSummaryCardForm) -> Color {
        switch form {
        case .split:
            WorkbenchRedesignColors.borderControl
        case .backdrop:
            WorkbenchRedesignColors.coverSummaryText.opacity(0.24)
        }
    }

    private func progressFillColor(for form: CoverSummaryCardForm) -> Color {
        switch form {
        case .split:
            WorkbenchRedesignColors.accent
        case .backdrop:
            WorkbenchRedesignColors.coverSummaryText
        }
    }

    @ViewBuilder
    private func supportingContentView(color: Color) -> some View {
        switch supportingContent {
        case .description(let description):
            supportingText(description, color: color, lineLimit: 2)
        case .metadata(let primary, let secondary, let secondaryInteraction):
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignCoverSummaryMetaLinesGap
            ) {
                supportingText(primary, color: color, lineLimit: 1)
                secondarySupportingText(
                    secondary,
                    color: color,
                    interaction: secondaryInteraction
                )
            }
        }
    }

    @ViewBuilder
    private func secondarySupportingText(
        _ text: String,
        color: Color,
        interaction: CoverSummarySecondaryMetadataInteraction
    ) -> some View {
        switch interaction {
        case .none:
            supportingText(text, color: color, lineLimit: 1)

        case .clickablePath(_, let action):
            WorkbenchSelectableText(
                text,
                fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular,
                color: color,
                lineLimit: 1,
                lineHeight: WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription,
                truncationMode: .tail,
                preferredPointerShape: .grab,
                showsUnderline: isSecondaryMetadataHovered,
                onTap: action
            )
            .contentShape(Rectangle())
            .onPointerHover(showsHand: true) { isHovered in
                isSecondaryMetadataHovered = isHovered
            }
            .onDisappear {
                isSecondaryMetadataHovered = false
            }

        case .expandableDescription:
            WorkbenchSelectableText(
                text,
                fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular,
                color: color,
                lineLimit: 1,
                lineHeight: WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription,
                truncationMode: .tail,
                preferredPointerShape: .grab,
                showsUnderline: false,
                onTap: {
                    isDescriptionPopoverOpen = true
                }
            )
            .opacity(isDescriptionPopoverOpen ? 0 : 1)
            .contentShape(Rectangle())
            .onPointerHover(showsHand: true) { _ in }
            .background {
                GeometryReader { textGeo in
                    Color.clear
                        .onAppear {
                            secondaryLineOffsetY = textGeo.frame(
                                in: .named(coverSummaryContentColumnCoordinateSpace)
                            ).minY
                        }
                        .onChange(
                            of: textGeo.frame(
                                in: .named(coverSummaryContentColumnCoordinateSpace)
                            ).minY
                        ) { newMinY in
                            secondaryLineOffsetY = newMinY
                        }
                }
            }
        }
    }

    private func supportingText(
        _ text: String,
        color: Color,
        lineLimit: Int
    ) -> some View {
        WorkbenchSelectableText(
            text,
            fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
            weight: .regular,
            color: color,
            lineLimit: lineLimit,
            lineHeight: WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription,
            truncationMode: .tail
        )
    }
}

private struct CoverSummaryDescriptionDetailPopover: View {
    private static let escapeKeyCode: UInt16 = 53

    let fullText: String
    let form: CoverSummaryCardForm
    let textColor: Color
    let layout: CoverSummaryDescriptionPopoverLayout
    let interfaceLayers: InterfaceLayerRegistry?
    let interfaceLayerContext: InterfaceLayerContext
    let onDismiss: () -> Void

    private var popoverCornerRadius: CGFloat {
        WorkbenchControlMetrics.redesignCornerRadius
    }

    private var popoverShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: popoverCornerRadius,
            style: .continuous
        )
    }

    private var scrollbarAppearanceMode: TableScrollbarAppearanceMode {
        switch form {
        case .split:
            .inherited
        case .backdrop:
            .playerChrome
        }
    }

    /// A menu surface belongs to the layer it freezes, so its own scrollbar and
    /// selectable text are only frozen when a higher layer covers that layer.
    private var popoverChildLayerContext: InterfaceLayerContext {
        InterfaceLayerContext(
            layer: interfaceLayerContext.layer,
            coveredLayers: interfaceLayerContext.coveredLayers,
            frozenLayers: interfaceLayerContext.coveredLayers
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WorkbenchScrollView(
                .vertical,
                scrollbarInset: TableScrollbarPrimitiveMetrics.inset,
                scrollbarAppearanceMode: scrollbarAppearanceMode
            ) {
                WorkbenchSelectableText(
                    fullText,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular,
                    color: textColor,
                    lineLimit: nil,
                    lineHeight: WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription,
                    alignment: .leading,
                    isSelectable: true,
                    preferredPointerShape: .iBeam,
                    allowsMenuModalInteraction: true
                )
                .frame(
                    width: layout.textWidth,
                    height: layout.textHeight,
                    alignment: .topLeading
                )
                .padding(
                    .horizontal,
                    WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingX
                )
                .padding(
                    .vertical,
                    WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingY
                )
            }
            .environment(\.interfaceLayerContext, popoverChildLayerContext)
            .frame(
                width: layout.frame.width,
                height: layout.frame.height,
                alignment: .topLeading
            )
            .clipShape(popoverShape)
            .background {
                popoverBackground
            }
            .overlay {
                popoverBorder
            }
            .offset(
                x: layout.frame.minX,
                y: layout.frame.minY
            )

            MenuGateClientView(
                gate: interfaceLayers?.menuGate,
                owner: interfaceLayerContext.layer,
                kind: .coverSummaryDescriptionPopover,
                menuFrame: layout.frame,
                handleKey: { keyCode, _ in
                    if keyCode == Self.escapeKeyCode {
                        onDismiss()
                        return true
                    }
                    return false
                },
                dismiss: { _ in
                    onDismiss()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var popoverBackground: some View {
        switch form {
        case .split:
            popoverShape
                .fill(WorkbenchRedesignColors.bgPopover)
                .shadowToken(
                    WorkbenchRedesignColors.shadowPopover,
                    cornerRadius: popoverCornerRadius
                )
        case .backdrop:
            popoverShape
                .fill(WorkbenchRedesignColors.coverSummaryDescriptionPopoverBackdropBg)
                .shadow(
                    color: PlaybackTheme.overlayShadowColor,
                    radius: PlaybackTheme.overlayShadowRadius,
                    y: PlaybackTheme.overlayShadowYOffset
                )
        }
    }

    @ViewBuilder
    private var popoverBorder: some View {
        switch form {
        case .split:
            popoverShape
                .strokeBorder(
                    WorkbenchRedesignColors.borderControl,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
        case .backdrop:
            popoverShape
                .strokeBorder(
                    WorkbenchRedesignColors.coverSummaryText.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryButtonBorderOpacity
                    ),
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
        }
    }
}

/// Gives the card a height derived from the width it is offered, so the two
/// forms can differ in height without the page guessing which one applies.
private struct CoverSummaryCardSizingLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        return CGSize(
            width: width,
            height: CoverSummaryCardLayout.height(forCardWidth: width)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(bounds.size)
            )
        }
    }
}

private struct CoverSummaryActionButton: View {
    let title: String?
    var icon: AppIcon = .play
    var iconWeight: AppIconWeight? = .fill
    var isOpen: Bool = false
    var isFocused: Bool = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @State private var isPressed = false

    private var hasTitle: Bool {
        guard let title else { return false }
        return !title.isEmpty
    }

    private var iconSize: CGFloat {
        hasTitle
            ? WorkbenchControlMetrics.redesignButtonIconSize
            : WorkbenchControlMetrics.redesignControlIconSize
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                AppIconImage(
                    icon,
                    size: iconSize,
                    weight: iconWeight
                )
                    .frame(
                        width: iconSize,
                        height: iconSize
                    )

                if let title, !title.isEmpty {
                    Text(title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeControl,
                            weight: WorkbenchControlMetrics.redesignFontWeightControl
                        ))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(WorkbenchRedesignColors.coverSummaryText)
            .padding(
                .horizontal,
                hasTitle ? WorkbenchControlMetrics.redesignControlPaddingX : 0
            )
            .frame(
                width: hasTitle ? nil : WorkbenchControlMetrics.redesignHeight,
                height: WorkbenchControlMetrics.redesignHeight
            )
            .background(buttonShape.fill(buttonBackground))
            .overlay {
                buttonShape.strokeBorder(
                    WorkbenchRedesignColors.coverSummaryText.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryButtonBorderOpacity
                    ),
                    lineWidth: 1
                )
            }
            .opacity(
                isEnabled
                    ? 1
                    : WorkbenchControlMetrics.redesignCoverSummaryButtonDisabledOpacity
            )
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var buttonBackground: Color {
        let opacity: Double
        if isPressed && isEnabled {
            opacity = WorkbenchControlMetrics.redesignCoverSummaryButtonPressedBackgroundOpacity
        } else if (isHovered || isOpen) && isEnabled {
            opacity = WorkbenchControlMetrics.redesignCoverSummaryButtonHoverBackgroundOpacity
        } else {
            opacity = WorkbenchControlMetrics.redesignCoverSummaryButtonBackgroundOpacity
        }
        return WorkbenchRedesignColors.coverSummaryText.opacity(opacity)
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        )
    }
}
