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
        .animation(.easeOut(duration: 0.16), value: feedback?.id)
    }

    private func centerFeedback(_ feedback: PlaybackFeedback) -> some View {
        feedbackContent(feedback, isSideFeedback: false, isTrailing: false)
            .frame(
                minWidth: feedback.systemImage == nil ? 0 : 108,
                maxWidth: feedback.systemImage == nil ? nil : 280,
                minHeight: feedback.systemImage == nil ? 42 : 98
            )
            .padding(.horizontal, feedback.systemImage == nil ? 18 : 22)
            .padding(.vertical, feedback.systemImage == nil ? 0 : 18)
            .background(feedbackBackground(cornerRadius: feedback.systemImage == nil ? 999 : 20))
        .id(feedback.id)
        .transition(.opacity.combined(with: .scale(scale: 0.88)))
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
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(feedbackBackground(cornerRadius: 999))
            .id(feedback.id)
            .transition(.opacity.combined(with: .scale(scale: 0.88)))

            if !isTrailing {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 56)
    }

    private func feedbackContent(
        _ feedback: PlaybackFeedback,
        isSideFeedback: Bool,
        isTrailing: Bool
    ) -> some View {
        Group {
            if isSideFeedback {
                HStack(spacing: 10) {
                    if !isTrailing {
                        feedbackIcon(feedback.systemImage, size: 30)
                    }

                    feedbackText(feedback.text, isTextOnly: false)

                    if isTrailing {
                        feedbackIcon(feedback.systemImage, size: 30)
                    }
                }
            } else if feedback.systemImage == nil {
                feedbackText(feedback.text, isTextOnly: true)
            } else {
                VStack(spacing: 10) {
                    feedbackIcon(feedback.systemImage, size: 34)
                    feedbackText(feedback.text, isTextOnly: false)
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackIcon(_ name: String?, size: CGFloat) -> some View {
        if let name {
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.44), radius: 2, y: 1)
        }
    }

    @ViewBuilder
    private func feedbackText(_ text: String?, isTextOnly: Bool) -> some View {
        if let text {
            Text(text)
                .font(.system(size: isTextOnly ? 13 : 14, weight: .bold))
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
