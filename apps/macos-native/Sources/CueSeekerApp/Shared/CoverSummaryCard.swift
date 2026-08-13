import SwiftUI

enum CoverSummarySupportingContent: Equatable {
    case description(String)
    case metadata(primary: String, secondary: String)
}

enum CoverSummaryActionKind: Equatable {
    case play
    case resume

    var title: String {
        switch self {
        case .play:
            "Play"
        case .resume:
            "Resume"
        }
    }
}

struct CoverSummaryCardLayout: Equatable {
    let backgroundFrame: CGRect
    let contentFrame: CGRect
    let scrimEndLocation: CGFloat

    static func resolve(containerSize: CGSize) -> CoverSummaryCardLayout {
        let width = max(0, containerSize.width)
        let height = WorkbenchControlMetrics.redesignCoverSummaryHeight
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
        let contentWidth = min(availableWidth, boundedWidth)
        let contentFrame = CGRect(
            x: padding,
            y: padding,
            width: contentWidth,
            height: max(0, height - padding * 2)
        )
        let protectedWidth = contentFrame.maxX + padding
        let contentFraction = width > 0 ? protectedWidth / width : 1

        return CoverSummaryCardLayout(
            backgroundFrame: CGRect(x: 0, y: 0, width: width, height: height),
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
    let actionKind: CoverSummaryActionKind
    let isActionEnabled: Bool
    let action: () -> Void
    let cover: () -> Cover

    init(
        title: String,
        supportingContent: CoverSummarySupportingContent,
        actionKind: CoverSummaryActionKind,
        isActionEnabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder cover: @escaping () -> Cover
    ) {
        self.title = title
        self.supportingContent = supportingContent
        self.actionKind = actionKind
        self.isActionEnabled = isActionEnabled
        self.action = action
        self.cover = cover
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = CoverSummaryCardLayout.resolve(
                containerSize: proxy.size
            )

            ZStack(alignment: .topLeading) {
                cover()
                    .frame(
                        width: layout.backgroundFrame.width,
                        height: layout.backgroundFrame.height
                    )
                    .allowsHitTesting(false)

                coverScrim(endLocation: layout.scrimEndLocation)
                    .frame(
                        width: layout.backgroundFrame.width,
                        height: layout.backgroundFrame.height
                    )
                    .allowsHitTesting(false)

                content
                    .frame(
                        width: layout.contentFrame.width,
                        height: layout.contentFrame.height,
                        alignment: .leading
                    )
                    .position(
                        x: layout.contentFrame.midX,
                        y: layout.contentFrame.midY
                    )
            }
            .clipShape(coverShape)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            maxHeight: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            alignment: .leading
        )
        .clipped()
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

    private var coverShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCoverSummaryRadius,
            style: .continuous
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeCoverSummaryTitle,
                    weight: WorkbenchControlMetrics.redesignFontWeightCoverSummaryTitle
                ))
                .foregroundStyle(WorkbenchRedesignColors.coverSummaryText)
                .lineLimit(1)

            supportingContentView

            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing3)

            CoverSummaryActionButton(
                title: actionKind.title,
                action: action
            )
            .disabled(!isActionEnabled)
        }
    }

    @ViewBuilder
    private var supportingContentView: some View {
        switch supportingContent {
        case .description(let description):
            supportingText(description, lineLimit: 2)
        case .metadata(let primary, let secondary):
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignSpacing2
            ) {
                supportingText(primary, lineLimit: 1)
                supportingText(secondary, lineLimit: 1)
            }
        }
    }

    private func supportingText(
        _ text: String,
        lineLimit: Int
    ) -> some View {
        Text(text)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular
            ))
            .foregroundStyle(
                WorkbenchRedesignColors.coverSummaryText.opacity(
                    WorkbenchControlMetrics.redesignCoverSummaryDescriptionOpacity
                )
            )
            .lineLimit(lineLimit)
            .truncationMode(.tail)
    }
}

private struct CoverSummaryActionButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Image(systemName: "play.fill")
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignButtonIconSize,
                        weight: WorkbenchControlMetrics.redesignButtonIconWeight
                    ))
                    .frame(
                        width: WorkbenchControlMetrics.redesignButtonIconSize,
                        height: WorkbenchControlMetrics.redesignButtonIconSize
                    )

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(WorkbenchRedesignColors.coverSummaryText)
            .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignHeight)
            .background(buttonShape.fill(buttonBackground))
            .overlay {
                buttonShape.strokeBorder(
                    WorkbenchRedesignColors.coverSummaryText.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryButtonBorderOpacity
                    ),
                    lineWidth: 1
                )
            }
            .overlay {
                if isFocused && isEnabled {
                    buttonShape
                        .stroke(
                            WorkbenchRedesignColors.focusRing,
                            lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                        )
                        .padding(
                            -WorkbenchControlMetrics.redesignFocusRingPathExpansion
                        )
                }
            }
            .opacity(
                isEnabled
                    ? 1
                    : WorkbenchControlMetrics.redesignCoverSummaryButtonDisabledOpacity
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
    }

    private var buttonBackground: Color {
        WorkbenchRedesignColors.coverSummaryScrim.opacity(
            isHovered && isEnabled
                ? WorkbenchControlMetrics.redesignCoverSummaryButtonHoverBackgroundOpacity
                : WorkbenchControlMetrics.redesignCoverSummaryButtonBackgroundOpacity
        )
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        )
    }
}
