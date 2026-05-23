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
            .frame(height: 60)
            .background(feedbackBackground(cornerRadius: 30))
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
            .frame(height: 60)
            .background(feedbackBackground(cornerRadius: 30))
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
                Image(systemName: "doc.on.doc")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.44), radius: 2, y: 1)
            case .sidebar(let isOpen):
                PlaybackSidebarIconView(isOpen: isOpen, size: size)
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
            .fill(PlaybackTheme.cinematicBacking)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
    }
}
