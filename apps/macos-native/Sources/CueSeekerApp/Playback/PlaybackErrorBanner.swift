import SwiftUI

/// The player's one error surface: the video line above the subtitle line in a
/// single box, then the line refusing an item the library no longer holds, as
/// wide as its text up to the width it is given. It is anchored
/// to the window rather than to the picture, so a window too narrow for the
/// video leaves it on the letterbox, and it stays while the Player UI hides.
/// See `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
/// Database Records.md`.
struct PlaybackErrorBanner: View {
    let messages: [PlaybackErrorLine: String]

    var body: some View {
        let shownLines = PlaybackErrorLine.allCases.filter { messages[$0] != nil }
        ZStack(alignment: .topLeading) {
            if !shownLines.isEmpty {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    ForEach(shownLines, id: \.self) { shownLine in
                        line(messages[shownLine] ?? "")
                    }
                }
                .padding(.horizontal, PlaybackChromeMetrics.errorHorizontalPadding)
                .padding(.vertical, PlaybackChromeMetrics.errorVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: PlaybackChromeMetrics.errorRadius)
                        .fill(PlaybackTheme.errorBackground)
                )
                .transition(.opacity)
            }
        }
        .animation(ToastCenter.motion, value: shownLines)
    }

    private func line(_ message: String) -> some View {
        HStack(
            alignment: .feedbackFirstLineCenter,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            AppIconImage(.warning, size: PlaybackChromeMetrics.errorIconSize)
                .foregroundColor(PlaybackTheme.errorContent)
                .alignmentGuide(.feedbackFirstLineCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

            // A wrapped path keeps to the text column instead of running back
            // under the icon.
            Text(message)
                .font(.system(
                    size: PlaybackChromeMetrics.errorFontSize,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .lineSpacing(PlaybackChromeMetrics.errorLeading)
                .padding(.vertical, PlaybackChromeMetrics.errorLeading / 2)
                .foregroundColor(PlaybackTheme.errorContent)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .alignmentGuide(.feedbackFirstLineCenter) { _ in
                    PlaybackChromeMetrics.errorLineHeight / 2
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}
