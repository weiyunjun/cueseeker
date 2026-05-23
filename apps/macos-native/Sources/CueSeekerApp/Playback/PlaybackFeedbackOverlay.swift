import SwiftUI

struct PlaybackFeedbackOverlay: View {
    let feedback: PlaybackFeedback?

    var body: some View {
        ZStack {
            if let feedback {
                switch feedback.position {
                case .center:
                    centerFeedback(feedback)
                case .leading:
                    sideFeedback(feedback, isTrailing: false)
                case .trailing:
                    sideFeedback(feedback, isTrailing: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.14), value: feedback != nil)
    }

    private func centerFeedback(_ feedback: PlaybackFeedback) -> some View {
        feedbackContent(feedback, isSideFeedback: false, isTrailing: false)
            .frame(height: 80)
            .background(feedbackBackground(cornerRadius: 40))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func sideFeedback(
        _ feedback: PlaybackFeedback,
        isTrailing: Bool
    ) -> some View {
        HStack {
            if isTrailing {
                Spacer()
            }

            feedbackContent(feedback, isSideFeedback: true, isTrailing: isTrailing)
            .frame(height: 80)
            .background(feedbackBackground(cornerRadius: 40))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))

            if !isTrailing {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 25)
    }

    private func feedbackContent(
        _ feedback: PlaybackFeedback,
        isSideFeedback: Bool,
        isTrailing: Bool
    ) -> some View {
        HStack(spacing: 16) {
            if isSideFeedback && isTrailing {
                feedbackText(feedback.text)
                feedbackIcon(feedback.icon, size: 30)
            } else {
                feedbackIcon(feedback.icon, size: 30)
                feedbackText(feedback.text)
            }
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func feedbackIcon(_ icon: PlaybackFeedbackIcon?, size: CGFloat) -> some View {
        if let icon {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.44), radius: 2, y: 1)
            case .copy:
                PlaybackCopyGlyph()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.57, height: size * 0.57)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.44), radius: 2, y: 1)
            }
        }
    }

    @ViewBuilder
    private func feedbackText(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func feedbackBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.56))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.46), radius: 24, y: 14)
    }
}
