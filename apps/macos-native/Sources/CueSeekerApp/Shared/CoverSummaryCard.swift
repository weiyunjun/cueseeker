import SwiftUI

enum CoverSummarySupportingContent: Equatable {
    case description(String)
    case metadata(primary: String, secondary: String)
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
                        .frame(
                            width: layout.contentFrame.width,
                            height: layout.contentFrame.height,
                            alignment: .topLeading
                        )
                        .offset(
                            x: layout.contentFrame.minX,
                            y: layout.contentFrame.minY
                        )
                }
                .frame(
                    width: proxy.size.width,
                    height: layout.cardHeight,
                    alignment: .topLeading
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeCoverSummaryTitle,
                        weight: WorkbenchControlMetrics.redesignFontWeightCoverSummaryTitle
                    ))
                    .foregroundStyle(titleColor(for: form))
                    .lineLimit(1)
                    .truncationMode(.tail)

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
            Text(progress.labelText)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeCaption,
                    weight: .medium
                ))
                .monospacedDigit()
                .foregroundStyle(supportingColor(for: form))
                .lineLimit(1)
                .truncationMode(.tail)
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
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            primaryActionButton(for: form)

            if let secondaryAction {
                secondaryActionButton(secondaryAction, for: form)
            }

            if let onToggleMoreMenu {
                moreMenuButton(action: onToggleMoreMenu, for: form)
            }
        }
    }

    @ViewBuilder
    private func primaryActionButton(for form: CoverSummaryCardForm) -> some View {
        switch form {
        case .split:
            WorkbenchPrimaryButton(
                title: actionKind.title,
                icon: .play,
                iconWeight: .fill,
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
        for form: CoverSummaryCardForm
    ) -> some View {
        switch form {
        case .split:
            WorkbenchButton(
                title: secondaryAction.title,
                icon: secondaryAction.icon,
                isRedesign: true,
                action: secondaryAction.action
            )
        case .backdrop:
            CoverSummaryActionButton(
                title: secondaryAction.title,
                icon: secondaryAction.icon,
                iconWeight: nil,
                action: secondaryAction.action
            )
        }
    }

    private func moreMenuButton(
        action: @escaping () -> Void,
        for form: CoverSummaryCardForm
    ) -> some View {
        ZStack {
            switch form {
            case .split:
                WorkbenchButton(
                    icon: .dotsThree,
                    isRedesign: true,
                    isOpen: isMoreMenuOpen,
                    action: action
                )
            case .backdrop:
                CoverSummaryActionButton(
                    title: nil,
                    icon: .dotsThree,
                    iconWeight: nil,
                    isOpen: isMoreMenuOpen,
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
        case .metadata(let primary, let secondary):
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignCoverSummaryMetaLinesGap
            ) {
                supportingText(primary, color: color, lineLimit: 1)
                supportingText(secondary, color: color, lineLimit: 1)
            }
        }
    }

    private func supportingText(
        _ text: String,
        color: Color,
        lineLimit: Int
    ) -> some View {
        Text(text)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular
            ))
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
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
