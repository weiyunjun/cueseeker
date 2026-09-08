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
                    // The stage offers the whole window, so without this the
                    // label's ceiling would become its width and every capsule
                    // would be as wide as the longest one can be.
                    .fixedSize(horizontal: true, vertical: false)
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
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            feedbackIcon(feedback.icon)
            feedbackText(feedback.text)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        .frame(height: PlaybackChromeMetrics.feedbackHeight)
        .background(feedbackBackground)
    }

    @ViewBuilder
    private func feedbackIcon(_ icon: PlaybackFeedbackIcon?) -> some View {
        if let icon {
            Image(systemName: Self.symbolName(for: icon))
                .font(
                    .system(
                        size: PlaybackChromeMetrics.feedbackIconSize,
                        weight: .semibold
                    )
                )
                .foregroundColor(PlaybackTheme.textPrimary)
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
                .foregroundColor(PlaybackTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: PlaybackChromeMetrics.topbarTitleMaxWidth, alignment: .leading)
        }
    }

    private static func symbolName(for icon: PlaybackFeedbackIcon) -> String {
        switch icon {
        case .system(let name):
            name
        case .copy:
            "doc.on.doc"
        }
    }

    /// The speed menu's surface without its shadow. The capsule appears over
    /// the picture and over the light Subtitle Focus panel alike, and a scrim
    /// heavy enough to read on video casts a grey cloud on the panel, so the
    /// border and the fill carry the separation on their own.
    private var feedbackBackground: some View {
        let shape = RoundedRectangle(
            cornerRadius: PlaybackChromeMetrics.feedbackRadius
        )

        return shape
            .fill(PlaybackTheme.menuBackground)
            .background(.ultraThinMaterial, in: shape)
            .overlay(
                shape.strokeBorder(
                    PlaybackTheme.textTertiary.opacity(0.3),
                    lineWidth: WorkbenchControlMetrics.hairlineWidth
                )
            )
    }
}
