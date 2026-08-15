import SwiftUI

enum PlaybackCueFooterMetrics {
    /// Provisional --height-playback-cue-footer
    static let height: CGFloat = 48
}

enum PlaybackCueFooterStatus {
    static func cues(totalCount: Int) -> String {
        "\(max(0, totalCount)) cues"
    }

    static func searchResults(
        totalCount: Int,
        previewLimit: Int,
        hasMoreResults: Bool
    ) -> String {
        let resolvedTotalCount = max(0, totalCount)
        let resolvedPreviewLimit = max(0, previewLimit)
        guard resolvedTotalCount > resolvedPreviewLimit || hasMoreResults else {
            return "\(resolvedTotalCount) results"
        }
        return "\(resolvedTotalCount) results "
            + "(Showing first \(resolvedPreviewLimit) results)"
    }
}

struct PlaybackCueFooter: View {
    let status: String
    let actionTitle: String

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            Text(status)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .lineLimit(1)
                .accessibilityIdentifier("playback-cue-footer-status")

            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing3)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                Text("Navigate")
                    .lineLimit(1)
                PlaybackCueFooterKeycap(content: .text("↑"))
                PlaybackCueFooterKeycap(content: .text("↓"))
            }

            Text(actionTitle)
                .lineLimit(1)
            PlaybackCueFooterKeycap(content: .systemImage("return"))
        }
        .font(.system(
            size: WorkbenchControlMetrics.redesignFontSizeBody,
            weight: WorkbenchControlMetrics.redesignFontWeightControl
        ))
        .foregroundStyle(WorkbenchRedesignColors.textMuted)
        .frame(height: PlaybackCueFooterMetrics.height)
        .accessibilityIdentifier("playback-cue-footer")
    }
}

private enum PlaybackCueFooterKeycapContent {
    case text(String)
    case systemImage(String)
}

private struct PlaybackCueFooterKeycap: View {
    let content: PlaybackCueFooterKeycapContent

    var body: some View {
        label
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: WorkbenchControlMetrics.redesignFontWeightControl
            ))
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignKeycapHorizontalPadding
            )
            .frame(minWidth: WorkbenchControlMetrics.redesignKeycapHeight)
            .frame(height: WorkbenchControlMetrics.redesignKeycapHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignKeycapRadius,
                    style: .continuous
                )
                .fill(WorkbenchRedesignColors.keycapBackground)
            }
    }

    @ViewBuilder
    private var label: some View {
        switch content {
        case .text(let text):
            Text(text)
        case .systemImage(let systemName):
            Image(systemName: systemName)
        }
    }
}
