import CueSeekerCore
import SwiftUI

struct PlaybackCollageEditorContent: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let cues: [SubtitleFocusCue]
    let displayTitle: String
    let initialCueID: Int64?

    var body: some View {
        HStack(spacing: 0) {
            PlaybackTheme.subtitleFocusOverlayBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlaybackCollageSelectionView(
                session: session,
                cues: cues,
                displayTitle: displayTitle,
                initialCueID: initialCueID
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PlaybackCollageSelectionView: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let cues: [SubtitleFocusCue]
    let displayTitle: String
    let initialCueID: Int64?

    @FocusState private var isScrollFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(
                    alignment: .leading,
                    spacing: PlaybackSubtitleFocusMetrics.cueGap
                ) {
                    ForEach(cues) { cue in
                        let isSelected = session.collageSelectionPlan.contains(
                            cueID: cue.id
                        )
                        let isEnabled = isSelected
                            || session.collageSelectionPlan.canSelectAnotherCue
                        PlaybackCollageCueSelectionRow(
                            cue: cue,
                            displayTitle: displayTitle,
                            isSelected: isSelected,
                            isEnabled: isEnabled
                        ) {
                            _ = session.toggleCollageCueSelection(cue)
                        }
                        .id(cue.id)
                    }
                }
                .padding(PlaybackSubtitleFocusMetrics.contentInset)
            }
            .focusable()
            .focused($isScrollFocused)
            .task {
                await Task.yield()
                if let initialCueID {
                    proxy.scrollTo(initialCueID, anchor: .center)
                }
                isScrollFocused = true
            }
        }
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
        .accessibilityIdentifier("playback-collage-selection-list")
    }
}

struct PlaybackCollageCueSelectionRow: View {
    let cue: SubtitleFocusCue
    let displayTitle: String
    let isSelected: Bool
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                selectionIndicator
                    .padding(
                        .top,
                        PlaybackCollageSelectionMetrics.checkboxTopPadding
                    )

                VStack(
                    alignment: .leading,
                    spacing: PlaybackSubtitleFocusMetrics.informationCueGap
                ) {
                    informationBadges

                    Text(cue.text)
                        .font(.system(
                            size: PlaybackSubtitleFocusMetrics.cueFontSize,
                            weight: .semibold
                        ))
                        .lineSpacing(
                            PlaybackSubtitleFocusMetrics.internalLineGap
                        )
                        .foregroundStyle(cueTextColor)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: PlaybackSubtitleFocusMetrics.cueLineHeight,
                            alignment: .topLeading
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, PlaybackSubtitleFocusMetrics.cueVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
        .pointerOnHover(isEnabled: isEnabled)
        .accessibilityLabel(cue.text)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("playback-collage-cue-\(cue.id)")
    }

    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: PlaybackCollageSelectionMetrics.checkboxSize))
            .foregroundStyle(selectionIndicatorColor)
            .frame(
                width: PlaybackCollageSelectionMetrics.checkboxSize,
                height: PlaybackCollageSelectionMetrics.checkboxSize
            )
    }

    private var informationBadges: some View {
        HStack(spacing: PlaybackSubtitleFocusMetrics.informationBadgeGap) {
            informationBadge(displayTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            informationBadge(PlaybackCueInformationText.timeRange(
                startMilliseconds: cue.startMilliseconds,
                endMilliseconds: cue.endMilliseconds
            ))
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: PlaybackSubtitleFocusMetrics.informationBadgeRowHeight,
            alignment: .leading
        )
    }

    private func informationBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(
                size: PlaybackSubtitleFocusMetrics.informationBadgeFontSize,
                weight: .semibold
            ))
            .foregroundStyle(informationBadgeTextColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(
                .horizontal,
                PlaybackSubtitleFocusMetrics.informationBadgeHorizontalPadding
            )
            .padding(
                .vertical,
                PlaybackSubtitleFocusMetrics.informationBadgeVerticalPadding
            )
            .frame(
                height: PlaybackSubtitleFocusMetrics.informationBadgeRowHeight
            )
            .background(
                informationBadgeBackground,
                in: RoundedRectangle(
                    cornerRadius: PlaybackSubtitleFocusMetrics.informationBadgeRadius
                )
            )
    }

    private var selectionIndicatorColor: Color {
        if !isEnabled {
            return WorkbenchRedesignColors.iconDisabled
        }
        return isSelected
            ? WorkbenchRedesignColors.textMuted
            : WorkbenchRedesignColors.borderCheckbox
    }

    private var cueTextColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        return isSelected
            ? PlaybackTheme.subtitleFocusCueSelected
            : PlaybackTheme.subtitleFocusCueUnselected
    }

    private var informationBadgeBackground: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        return Color(nsColor: isSelected
            ? PlaybackTheme.informationBadgeBackgroundNative
            : PlaybackTheme.informationBadgeUnselectedBackgroundNative)
    }

    private var informationBadgeTextColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        return Color(nsColor: isSelected
            ? PlaybackTheme.informationBadgeTextNative
            : PlaybackTheme.informationBadgeUnselectedTextNative)
    }
}
