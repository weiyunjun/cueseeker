import SwiftUI

struct CoverSummaryCardLayout: Equatable {
    let coverFrame: CGRect
    let blurFrame: CGRect

    static func resolve(containerSize: CGSize) -> CoverSummaryCardLayout {
        let height = WorkbenchControlMetrics.redesignCoverSummaryHeight
        let coverWidth = height
            * WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
        let coverFrame = CGRect(
            x: containerSize.width - coverWidth,
            y: 0,
            width: coverWidth,
            height: height
        )
        let contentFrame = CGRect(
            x: 0,
            y: 0,
            width: min(
                containerSize.width,
                WorkbenchControlMetrics.redesignCoverSummaryContentSafeWidth
            ),
            height: height
        )
        let overlap = coverFrame.intersection(contentFrame)
        return CoverSummaryCardLayout(
            coverFrame: coverFrame,
            blurFrame: overlap.isNull ? .zero : overlap
        )
    }
}

struct CoverSummaryCard<Cover: View>: View {
    let title: String
    let summaryDescription: String
    let actionTitle: String
    let isActionEnabled: Bool
    let action: () -> Void
    let cover: () -> Cover

    init(
        title: String,
        description: String,
        actionTitle: String,
        isActionEnabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder cover: @escaping () -> Cover
    ) {
        self.title = title
        summaryDescription = description
        self.actionTitle = actionTitle
        self.isActionEnabled = isActionEnabled
        self.action = action
        self.cover = cover
    }

    var body: some View {
        ZStack(alignment: .leading) {
            WorkbenchRedesignColors.bgSurface
            coverLayer
            content
        }
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            maxHeight: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            alignment: .leading
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCoverSummaryRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCoverSummaryRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderMuted,
                lineWidth: WorkbenchControlMetrics.redesignCoverSummaryBorderWidth
            )
        )
    }

    private var coverLayer: some View {
        GeometryReader { proxy in
            let layout = CoverSummaryCardLayout.resolve(
                containerSize: proxy.size
            )

            cover()
                .frame(
                    width: layout.coverFrame.width,
                    height: layout.coverFrame.height
                )
                .clipShape(coverShape)
                .position(
                    x: layout.coverFrame.midX,
                    y: layout.coverFrame.midY
                )

            if !layout.blurFrame.isEmpty {
                cover()
                    .frame(
                        width: layout.coverFrame.width,
                        height: layout.coverFrame.height
                    )
                    .blur(
                        radius: WorkbenchControlMetrics.redesignCoverSummaryBlurRadius,
                        opaque: true
                    )
                    .clipShape(coverShape)
                    .mask(alignment: .topLeading) {
                        Rectangle()
                            .frame(
                                width: layout.blurFrame.width,
                                height: layout.blurFrame.height
                            )
                            .offset(
                                x: layout.blurFrame.minX - layout.coverFrame.minX,
                                y: layout.blurFrame.minY - layout.coverFrame.minY
                            )
                    }
                    .position(
                        x: layout.coverFrame.midX,
                        y: layout.coverFrame.midY
                    )
            }
        }
        .allowsHitTesting(false)
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
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)

            Text(summaryDescription)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .lineLimit(2)

            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing3)

            WorkbenchButton(
                title: actionTitle,
                systemImage: "play.fill",
                isRedesign: true,
                action: action
            )
            .disabled(!isActionEnabled)
        }
        .padding(WorkbenchControlMetrics.redesignCoverSummaryContentPadding)
        .frame(
            width: WorkbenchControlMetrics.redesignCoverSummaryContentSafeWidth,
            height: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            alignment: .leading
        )
    }
}
