import SwiftUI

/// Playback feedback has one anchor: the centre of the stage. Direction is
/// carried by the icon, not by where the capsule lands, so every message
/// arrives in the same place and the eye never has to look for it.
struct PlaybackFeedbackOverlay: View {
    let feedback: PlaybackFeedback?

    var body: some View {
        ZStack {
            Color.clear

            if let feedback {
                capsule(feedback)
                    // The message wraps at the smaller of its own ceiling and
                    // the space the stage leaves beside the viewport margin.
                    .frame(maxWidth: PlaybackChromeMetrics.feedbackMaxWidth)
                    .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing6)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        // Only the capsule's presence animates. Its content is swapped in
        // place, so a held-down seek key redraws the counter without the
        // capsule fading underneath it.
        .animation(ToastCenter.motion, value: feedback != nil)
    }

    private func capsule(_ feedback: PlaybackFeedback) -> some View {
        HStack(
            alignment: .feedbackFirstLineCenter,
            spacing: WorkbenchControlMetrics.redesignSpacing3
        ) {
            feedbackIcon(feedback.icon, weight: feedback.iconWeight)
            feedbackText(feedback.text)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        // A single line stays inside the 52px floor, which still sets its
        // height; the padding only takes over once a message wraps.
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        .frame(minHeight: PlaybackChromeMetrics.feedbackMinimumHeight)
        .background(feedbackBackground)
    }

    @ViewBuilder
    private func feedbackIcon(_ icon: AppIcon?, weight: AppIconWeight?) -> some View {
        if let icon {
            AppIconImage(
                icon,
                size: PlaybackChromeMetrics.feedbackIconSize,
                weight: weight
            )
                .foregroundColor(icon == .warning ? WorkbenchRedesignColors.warningText : .white)
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
                .foregroundColor(WorkbenchRedesignColors.toastText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .alignmentGuide(.feedbackFirstLineCenter) { _ in
                    WorkbenchControlMetrics.firstLineCenter(
                        fontSize: PlaybackChromeMetrics.feedbackFontSize
                    )
                }
        }
    }

    /// The unified Toast & Playback Feedback surface: dark translucent base with frosted glass and 1px border.
    private var feedbackBackground: some View {
        let shape = RoundedRectangle(
            cornerRadius: PlaybackChromeMetrics.feedbackRadius
        )

        return shape
            .fill(WorkbenchRedesignColors.toastBg)
            .background(
                shape
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                shape.strokeBorder(
                    WorkbenchRedesignColors.toastBorder,
                    lineWidth: 1
                )
            )
    }
}
