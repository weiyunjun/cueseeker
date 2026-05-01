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
        .animation(.easeOut(duration: 0.18), value: feedback?.id)
    }

    private func centerFeedback(_ feedback: PlaybackFeedback) -> some View {
        VStack(spacing: feedback.text == nil ? 0 : 10) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 54, weight: .semibold))
                .foregroundColor(.white)

            if let text = feedback.text {
                Text(text)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(
            minWidth: feedback.isCircular ? 96 : 140,
            minHeight: feedback.isCircular ? 96 : 112
        )
        .padding(feedback.isCircular ? 0 : 20)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: feedback.isCircular ? 48 : 16))
        .id(feedback.id)
        .transition(.opacity.combined(with: .scale(scale: 0.86)))
    }

    private func sideFeedback(
        _ feedback: PlaybackFeedback,
        isTrailing: Bool
    ) -> some View {
        HStack {
            if isTrailing {
                Spacer()
            }

            HStack(spacing: 10) {
                if !isTrailing {
                    feedbackIcon(feedback.systemImage)
                }

                if let text = feedback.text {
                    Text(text)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                if isTrailing {
                    feedbackIcon(feedback.systemImage)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.42))
            .clipShape(Capsule())
            .id(feedback.id)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))

            if !isTrailing {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 56)
    }

    private func feedbackIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 30, weight: .semibold))
            .foregroundColor(.white)
    }
}
