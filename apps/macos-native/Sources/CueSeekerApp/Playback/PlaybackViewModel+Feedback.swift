import Foundation
import SwiftUI
import CueSeekerPlayback

enum ExcerptFeedbackState {
    case removed
    case unavailable
}

struct PlaybackFeedback: Identifiable, Equatable {
    let id = UUID()
    let icon: AppIcon?
    let iconWeight: AppIconWeight?
    let text: String?

    init(
        icon: AppIcon? = nil,
        iconWeight: AppIconWeight? = nil,
        text: String?
    ) {
        self.icon = icon
        self.iconWeight = iconWeight
        self.text = text
    }
}

@MainActor
extension PlaybackViewModel {
    func showSubtitleCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                icon: copied ? .copy : .warning,
                text: copied ? L("playback.hud.cue_text_copied") : L("playback.hud.no_subtitle")
            ),
            durationMilliseconds: copied ? 1_500 : 3_000
        )
    }

    func showCollageFeedback(_ event: PlaybackCollageFeedbackEvent) {
        switch event {
        case .noCueSelected:
            showFeedback(
                PlaybackFeedback(
                    icon: .warning,
                    text: L("playback.hud.collage_no_cue_selected")
                ),
                durationMilliseconds: 3_000
            )
        case .notReady:
            showFeedback(
                PlaybackFeedback(
                    icon: .warning,
                    text: L("playback.hud.collage_not_ready")
                ),
                durationMilliseconds: 3_000
            )
        case .copyFailed:
            showFeedback(
                PlaybackFeedback(
                    icon: .warning,
                    text: L("playback.hud.copy_failed")
                ),
                durationMilliseconds: 3_000
            )
        case .exportFailed:
            showFeedback(
                PlaybackFeedback(
                    icon: .warning,
                    text: L("playback.hud.export_failed")
                ),
                durationMilliseconds: 3_000
            )
        case .copySucceeded:
            showFeedback(
                PlaybackFeedback(
                    icon: .copy,
                    text: L("playback.hud.collage_copied")
                ),
                durationMilliseconds: 1_500
            )
        case .exportSucceeded:
            showFeedback(
                PlaybackFeedback(
                    icon: .export,
                    text: L("playback.hud.collage_exported")
                ),
                durationMilliseconds: 1_500
            )
        }
    }

    func showSelectedTextCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                icon: copied ? .copy : .warning,
                text: copied ? L("playback.hud.selected_text_copied") : L("playback.hud.copy_failed")
            ),
            durationMilliseconds: copied ? 1_500 : 3_000
        )
    }

    func showScreenshotCopiedFeedback() {
        showFeedback(
            PlaybackFeedback(
                icon: .camera,
                text: L("playback.hud.screenshot_copied")
            ),
            durationMilliseconds: 1_500
        )
    }

    func showAutoPauseFeedback() {
        showFeedback(
            PlaybackFeedback(
                icon: .pause,
                iconWeight: .fill,
                text: L("playback.hud.auto_pause")
            )
        )
    }

    func showSubtitleMarkdownLinkCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                icon: copied ? .copy : .warning,
                text: copied ? L("playback.hud.deep_link_copied") : L("playback.hud.no_subtitle")
            ),
            durationMilliseconds: copied ? 1_500 : 3_000
        )
    }

    /// A `Save to Excerpt` result on the playback page and in the Command Panel.
    /// The sentence is the registry's, the same one the Workbench shows in a
    /// Toast; only the container differs, and every outcome wears the same
    /// bookmark.
    func showExcerptSaveFeedback(
        message: String,
        icon: AppIcon? = .bookmarkSimple,
        iconWeight: AppIconWeight? = .fill,
        durationMilliseconds: UInt64 = 1_500
    ) {
        showFeedback(
            PlaybackFeedback(
                icon: icon,
                iconWeight: iconWeight,
                text: message
            ),
            durationMilliseconds: durationMilliseconds
        )
    }

    func showExcerptFeedback(_ state: ExcerptFeedbackState) {
        let feedback: PlaybackFeedback = switch state {
        case .removed:
            PlaybackFeedback(
                icon: .bookmarkSimple,
                text: L("playback.hud.excerpt_removed")
            )
        case .unavailable:
            PlaybackFeedback(
                icon: .warning,
                text: L("playback.hud.no_subtitle")
            )
        }

        let duration: UInt64 = switch state {
        case .removed: 1_500
        case .unavailable: 3_000
        }

        showFeedback(feedback, durationMilliseconds: duration)
    }

    func showPlayPauseFeedback(isPlaying: Bool) {
        showFeedback(
            PlaybackFeedback(
                icon: isPlaying ? .play : .pause,
                iconWeight: .fill,
                text: isPlaying ? L("playback.play") : L("playback.pause")
            )
        )
    }

    func showSearchNavigationFeedback(
        direction: SearchResultNavigationDirection,
        hasResult: Bool
    ) {
        showFeedback(
            PlaybackFeedback(
                icon: direction == .previous ? .caretLeft : .caretRight,
                text: hasResult
                    ? (direction == .previous ? L("playback.hud.previous_result") : L("playback.hud.next_result"))
                    : (direction == .previous ? L("playback.hud.first_result") : L("playback.hud.last_result"))
            ),
            durationMilliseconds: 1_000
        )
    }

    func showLibraryNavigationFeedback(
        direction: SearchResultNavigationDirection,
        hasResult: Bool
    ) {
        showFeedback(
            PlaybackFeedback(
                icon: direction == .previous ? .caretLeft : .caretRight,
                text: hasResult
                    ? (direction == .previous ? L("playback.hud.previous_library_video") : L("playback.hud.next_library_video"))
                    : (direction == .previous ? L("playback.hud.first_video") : L("playback.hud.last_video"))
            ),
            durationMilliseconds: 1_000
        )
    }

    /// Save to Excerpt List or Copy Deep Link on a cue the library no longer
    /// holds.
    func showNotInLibraryFeedback() {
        showFeedback(
            PlaybackFeedback(
                icon: .warning,
                text: L("playback.hud.not_in_library")
            ),
            durationMilliseconds: 3_000
        )
    }

    /// Previous, next or Auto Switch from an item the library no longer holds,
    /// or a Recent Excerpt List opened, with nothing the library still holds
    /// to go to.
    func showNoAvailableNavigationFeedback(
        direction: SearchResultNavigationDirection?,
        text: String
    ) {
        let icon: AppIcon = switch direction {
        case .previous: .caretLeft
        case .next: .caretRight
        case nil: .warning
        }
        showFeedback(
            PlaybackFeedback(
                icon: icon,
                text: text
            ),
            durationMilliseconds: 1_000
        )
    }

    func showExcerptNavigationFeedback(
        direction: SearchResultNavigationDirection,
        hasResult: Bool
    ) {
        showFeedback(
            PlaybackFeedback(
                icon: direction == .previous ? .caretLeft : .caretRight,
                text: hasResult
                    ? (direction == .previous ? L("playback.hud.previous_excerpt") : L("playback.hud.next_excerpt"))
                    : (direction == .previous ? L("playback.hud.first_excerpt") : L("playback.hud.last_excerpt"))
            ),
            durationMilliseconds: 1_000
        )
    }

    func showFullscreenFeedback(enteringFullscreen: Bool) {
        showFeedback(
            PlaybackFeedback(
                text: enteringFullscreen ? L("playback.hud.enter_fullscreen") : L("playback.hud.exit_fullscreen")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showSubtitleFeedback(isVisible: Bool) {
        showFeedback(
            PlaybackFeedback(
                icon: .subtitles,
                text: isVisible ? L("playback.hud.subtitles_on") : L("playback.hud.subtitles_off")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showSubtitleSwitchedFeedback() {
        showFeedback(
            PlaybackFeedback(
                icon: .subtitles,
                text: L("playback.hud.subtitle_switched")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showSpeedFeedback(_ speed: Double) {
        showFeedback(
            PlaybackFeedback(
                icon: .speedometer,
                text: Self.formatSpeed(speed)
            )
        )
    }

    func showVolumeFeedback(_ volume: Double, isIncrease: Bool?) {
        let icon: AppIcon
        if volume <= 0 {
            icon = .speakerX
        } else if let isIncrease {
            icon = isIncrease ? .speakerHigh : .speakerLow
        } else {
            icon = .speakerHigh
        }

        showFeedback(
            PlaybackFeedback(
                icon: icon,
                text: volume > 0 ? "\(Int(volume.rounded()))%" : L("playback.hud.muted")
            )
        )
    }

    func showFeedback(
        _ nextFeedback: PlaybackFeedback,
        durationMilliseconds: UInt64 = 1_000
    ) {
        feedback = nextFeedback
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: durationMilliseconds * 1_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.feedback = nil
                self?.accumulatedForwardSeconds = 0
                self?.accumulatedRewindSeconds = 0
            }
        }
    }
}
