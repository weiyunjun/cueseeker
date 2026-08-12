import SwiftUI

struct CoverSummaryCardLayout: Equatable {
    let coverFrame: CGRect
    let contentFrame: CGRect
    let blendFrame: CGRect

    static func resolve(containerSize: CGSize) -> CoverSummaryCardLayout {
        let height = WorkbenchControlMetrics.redesignCoverSummaryHeight
        let coverWidth = height
            * WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
        let coverFrame = CGRect(
            x: 0,
            y: 0,
            width: coverWidth,
            height: height
        )
        let contentWidth = WorkbenchControlMetrics.redesignCoverSummaryContentSafeWidth
        let contentX = max(
            0,
            min(coverFrame.maxX, containerSize.width - contentWidth)
        )
        let contentFrame = CGRect(
            x: contentX,
            y: 0,
            width: contentWidth,
            height: height
        )
        let overlap = coverFrame.intersection(contentFrame)
        return CoverSummaryCardLayout(
            coverFrame: coverFrame,
            contentFrame: contentFrame,
            blendFrame: overlap.isNull ? .zero : overlap
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
        GeometryReader { proxy in
            let layout = CoverSummaryCardLayout.resolve(
                containerSize: proxy.size
            )

            ZStack(alignment: .topLeading) {
                coverLayer(layout: layout)
                contentBackground(layout: layout)
                content
                    .position(
                        x: layout.contentFrame.midX,
                        y: layout.contentFrame.midY
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            maxHeight: WorkbenchControlMetrics.redesignCoverSummaryHeight,
            alignment: .leading
        )
        .clipped()
    }

    private func coverLayer(layout: CoverSummaryCardLayout) -> some View {
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
            .allowsHitTesting(false)
    }

    private func contentBackground(layout: CoverSummaryCardLayout) -> some View {
        let solidWidth = max(
            0,
            layout.contentFrame.width - layout.blendFrame.width
        )

        return HStack(spacing: 0) {
            if !layout.blendFrame.isEmpty {
                coverBlend
                    .frame(
                        width: layout.blendFrame.width,
                        height: layout.contentFrame.height
                    )
            }

            if solidWidth > 0 {
                WorkbenchRedesignColors.bgSurface
                    .frame(
                        width: solidWidth,
                        height: layout.contentFrame.height
                    )
            }
        }
        .frame(
            width: layout.contentFrame.width,
            height: layout.contentFrame.height
        )
        .clipShape(coverShape)
        .position(
            x: layout.contentFrame.midX,
            y: layout.contentFrame.midY
        )
        .allowsHitTesting(false)
    }

    private var coverBlend: LinearGradient {
        LinearGradient(
            stops: [
                .init(
                    color: WorkbenchRedesignColors.bgSurface.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryBlendLeadingOpacity
                    ),
                    location: WorkbenchControlMetrics.redesignCoverSummaryBlendLeadingLocation
                ),
                .init(
                    color: WorkbenchRedesignColors.bgSurface.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryBlendMiddleOpacity
                    ),
                    location: WorkbenchControlMetrics.redesignCoverSummaryBlendMiddleLocation
                ),
                .init(
                    color: WorkbenchRedesignColors.bgSurface.opacity(
                        WorkbenchControlMetrics.redesignCoverSummaryBlendTrailingOpacity
                    ),
                    location: WorkbenchControlMetrics.redesignCoverSummaryBlendTrailingLocation
                ),
                .init(
                    color: WorkbenchRedesignColors.bgSurface.opacity(0),
                    location: 1
                ),
            ],
            startPoint: .top,
            endPoint: .bottom
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
