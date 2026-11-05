import SwiftUI

/// Top-left player stage feedback (`C-09.5` / `L-07.4`). Appears and disappears
/// immediately with no transition, using a flat dark translucent rounded mask
/// (`--color-player-topbar-gradient-start`) with no border or shadow.
struct PlaybackFeedbackOverlay: View {
    let feedback: PlaybackFeedback?

    var body: some View {
        if let feedback {
            capsule(feedback)
                .frame(
                    maxWidth: PlaybackChromeMetrics.feedbackMaxWidth,
                    alignment: .leading
                )
                .allowsHitTesting(false)
        }
    }

    private func capsule(_ feedback: PlaybackFeedback) -> some View {
        HStack(
            alignment: .feedbackFirstLineCenter,
            spacing: WorkbenchControlMetrics.redesignSpacing3
        ) {
            feedbackLeadingGraphic(feedback)
            feedbackText(feedback.text)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        .background(feedbackBackground)
    }

    @ViewBuilder
    private func feedbackLeadingGraphic(_ feedback: PlaybackFeedback) -> some View {
        if feedback.showsSpinner {
            WorkbenchSpinner(
                size: PlaybackChromeMetrics.feedbackIconSize,
                trackColor: PlaybackTheme.feedbackSpinnerTrack,
                indicatorColor: PlaybackTheme.feedbackSpinnerIndicator
            )
            .alignmentGuide(.feedbackFirstLineCenter) { dimensions in
                dimensions[VerticalAlignment.center]
            }
        } else if let icon = feedback.icon {
            AppIconImage(
                icon,
                size: PlaybackChromeMetrics.feedbackIconSize,
                weight: feedback.iconWeight
            )
            .foregroundColor(PlaybackTheme.textPrimary)
            .alignmentGuide(.feedbackFirstLineCenter) { dimensions in
                dimensions[VerticalAlignment.center]
            }
        }
    }

    @ViewBuilder
    private func feedbackText(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(
                    .system(
                        size: PlaybackChromeMetrics.feedbackFontSize,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    )
                    // Accumulated seek seconds and volume percentages change
                    // digit by digit; tabular figures keep the capsule from
                    // breathing while they do.
                    .monospacedDigit()
                )
                .lineSpacing(PlaybackChromeMetrics.feedbackLeading)
                .padding(.vertical, PlaybackChromeMetrics.feedbackLeading / 2)
                .foregroundColor(PlaybackTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .alignmentGuide(.feedbackFirstLineCenter) { _ in
                    PlaybackChromeMetrics.feedbackLineHeight / 2
                }
        }
    }

    private var feedbackBackground: some View {
        RoundedRectangle(
            cornerRadius: PlaybackChromeMetrics.feedbackRadius,
            style: .continuous
        )
        .fill(PlaybackTheme.topbarGradientStart)
    }
}
