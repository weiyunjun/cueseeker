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
            .frame(
                minWidth: feedback.icon == nil ? 0 : 108,
                maxWidth: feedback.icon == nil ? nil : 280,
                minHeight: feedback.icon == nil ? 42 : 98
            )
            .padding(.horizontal, feedback.icon == nil ? 18 : 22)
            .padding(.vertical, feedback.icon == nil ? 0 : 18)
            .background(feedbackBackground(cornerRadius: feedback.icon == nil ? 999 : 20))
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
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(feedbackBackground(cornerRadius: 999))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))

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
                        feedbackIcon(feedback.icon, size: 30)
                    }

                    feedbackText(feedback.text, isTextOnly: false)

                    if isTrailing {
                        feedbackIcon(feedback.icon, size: 30)
                    }
                }
            } else if feedback.icon == nil {
                feedbackText(feedback.text, isTextOnly: true)
            } else {
                VStack(spacing: 10) {
                    feedbackIcon(feedback.icon, size: 34)
                    feedbackText(feedback.text, isTextOnly: false)
                }
            }
        }
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
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.44), radius: 2, y: 1)
            }
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
