import AppKit
import Carbon.HIToolbox
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite("Tooltip System & Usage Registry", .serialized)
struct TooltipTests {
    @Test
    func geometryDefaultsToTopCenteredAndFlipsToBottomWhenTopSafeMarginOverflows() {
        let visibleRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let size = CGSize(width: 120, height: 28)

        let normalAnchor = CGRect(x: 386, y: 200, width: 28, height: 28)
        let normalFrame = TooltipGeometry.frame(
            anchor: normalAnchor,
            size: size,
            visibleRect: visibleRect
        )
        #expect(normalFrame.midX == normalAnchor.midX)
        #expect(normalFrame.maxY == normalAnchor.minY - TooltipGeometry.gap)

        // Anchor too close to top edge (200 -> 20): 20 - 8 - 28 = -16 < 8 -> flips to bottom.
        let topEdgeAnchor = CGRect(x: 386, y: 20, width: 28, height: 28)
        let flippedFrame = TooltipGeometry.frame(
            anchor: topEdgeAnchor,
            size: size,
            visibleRect: visibleRect
        )
        #expect(flippedFrame.midX == topEdgeAnchor.midX)
        #expect(flippedFrame.minY == topEdgeAnchor.maxY + TooltipGeometry.gap)
    }

    @Test
    func geometryShiftsHorizontallyWithinWindowSafeMargins() {
        let visibleRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let size = CGSize(width: 200, height: 28)

        let leftAnchor = CGRect(x: 12, y: 100, width: 28, height: 28)
        let leftFrame = TooltipGeometry.frame(
            anchor: leftAnchor,
            size: size,
            visibleRect: visibleRect
        )
        #expect(leftFrame.minX == TooltipGeometry.windowSafeMargin)

        let rightAnchor = CGRect(x: 760, y: 100, width: 28, height: 28)
        let rightFrame = TooltipGeometry.frame(
            anchor: rightAnchor,
            size: size,
            visibleRect: visibleRect
        )
        #expect(rightFrame.maxX == visibleRect.maxX - TooltipGeometry.windowSafeMargin)
    }

    @MainActor
    @Test
    func dynamicPlaybackShortcutFormattingResolvesDefaultModifiedClearedAndConflictedKeys() {
        var keymap = PlaybackShortcutKeymap()

        // Default keys
        #expect(
            TooltipShortcut.action(.playPause).resolvedText(keymap: keymap) == "Space"
        )
        #expect(
            TooltipShortcut.action(.previous).resolvedText(keymap: keymap) == "A"
        )
        #expect(
            TooltipShortcut.action(.next).resolvedText(keymap: keymap) == "D"
        )
        #expect(
            TooltipShortcut.action(.repeatCue).resolvedText(keymap: keymap) == "R"
        )
        #expect(
            TooltipShortcut.action(.copyScreenshot).resolvedText(keymap: keymap) == "P"
        )
        #expect(
            TooltipShortcut.action(.toggleSubtitles).resolvedText(keymap: keymap) == "Q"
        )
        #expect(
            TooltipShortcut.action(.toggleFullscreen).resolvedText(keymap: keymap) == "F"
        )
        #expect(
            TooltipShortcut.action(.editCollage).resolvedText(keymap: keymap) == "P"
        )

        // Modified key (Shift + V -> ⇧V)
        keymap.set(
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_V), shift: true),
            for: .toggleSubtitles
        )
        #expect(
            TooltipShortcut.action(.toggleSubtitles).resolvedText(keymap: keymap) == "⇧V"
        )

        // Multi-modifier + Space (⌃⌥⇧⌘Space)
        let multiSpace = PlaybackShortcutKey(
            keyCode: UInt16(kVK_Space),
            command: true,
            option: true,
            control: true,
            shift: true
        )
        #expect(multiSpace.tooltipDisplayText == "⌃⌥⇧⌘Space")

        // Cleared key -> omitted (nil)
        keymap.set(nil, for: .repeatCue)
        #expect(
            TooltipShortcut.action(.repeatCue).resolvedText(keymap: keymap) == nil
        )

        // Conflicting key -> omitted (nil) for both conflicting actions
        keymap.set(
            PlaybackShortcutKey(keyCode: UInt16(kVK_Space)),
            for: .copyScreenshot
        )
        #expect(
            TooltipShortcut.action(.playPause).resolvedText(keymap: keymap) == nil
        )
        #expect(
            TooltipShortcut.action(.copyScreenshot).resolvedText(keymap: keymap) == nil
        )
    }

    @MainActor
    @Test
    func tooltipCenterEnforcesOneSecondHoverDelayWarmupSkipWindowAndForcedReset() async throws {
        var currentTime = Date(timeIntervalSinceReferenceDate: 10_000)
        let center = TooltipCenter(
            skipWindowDelay: 0.3,
            now: { currentTime }
        )
        let targetA = UUID()
        let targetB = UUID()
        let targetC = UUID()
        let anchorA = CGRect(x: 100, y: 100, width: 28, height: 28)
        let anchorB = CGRect(x: 200, y: 100, width: 28, height: 28)
        let anchorC = CGRect(x: 300, y: 100, width: 28, height: 28)

        // 1. Exiting before 1s (tooltip not shown yet) does NOT open the skip window
        center.hoverBegan(
            targetID: targetA,
            surface: .main,
            scenarioID: "topbar.entry.tasks",
            anchorRect: anchorA,
            content: .standard(
                label: "Tasks",
                shortcut: .none,
                wrapsText: false
            ),
            hoverDelay: 0.04
        )
        #expect(center.activeItem == nil)
        center.hoverEnded(targetID: targetA)
        #expect(center.lastHoverDismissedAt == nil)

        // Entering targetA again still requires waiting the full hoverDelay
        center.hoverBegan(
            targetID: targetA,
            surface: .main,
            scenarioID: "topbar.entry.tasks",
            anchorRect: anchorA,
            content: .standard(
                label: "Tasks",
                shortcut: .none,
                wrapsText: false
            ),
            hoverDelay: 0.04
        )
        #expect(center.activeItem == nil)

        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(center.activeItem?.targetID == targetA)
        #expect(center.activeItem?.scenarioID == "topbar.entry.tasks")

        // 2. Exiting a shown tooltip via hoverEnded opens the 300ms skip window;
        // entering targetB within 300ms (e.g. 150ms later) shows targetB immediately without waiting.
        center.hoverEnded(targetID: targetA)
        #expect(center.activeItem == nil)
        #expect(center.lastHoverDismissedAt == currentTime)

        currentTime = currentTime.addingTimeInterval(0.15)
        center.hoverBegan(
            targetID: targetB,
            surface: .main,
            scenarioID: "topbar.entry.settings",
            anchorRect: anchorB,
            content: .standard(
                label: "Settings",
                shortcut: .fixed("⌘,"),
                wrapsText: false
            ),
            hoverDelay: 1.0
        )
        #expect(center.activeItem?.targetID == targetB)
        #expect(center.activeItem?.scenarioID == "topbar.entry.settings")

        // 3. Entering an adjacent targetC directly while targetB is still active also shows immediately.
        center.hoverBegan(
            targetID: targetC,
            surface: .main,
            scenarioID: "topbar.navigation.back",
            anchorRect: anchorC,
            content: .standard(
                label: "Back",
                shortcut: .none,
                wrapsText: false
            ),
            hoverDelay: 1.0
        )
        #expect(center.activeItem?.targetID == targetC)

        // 4. Exiting targetC and waiting > 300ms (e.g. 350ms) expires the skip window;
        // next hover restores the full hoverDelay wait.
        center.hoverEnded(targetID: targetC)
        #expect(center.activeItem == nil)
        currentTime = currentTime.addingTimeInterval(0.35)

        center.hoverBegan(
            targetID: targetB,
            surface: .main,
            scenarioID: "topbar.entry.settings",
            anchorRect: anchorB,
            content: .standard(
                label: "Settings",
                shortcut: .fixed("⌘,"),
                wrapsText: false
            ),
            hoverDelay: 0.04
        )
        #expect(center.activeItem == nil)
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(center.activeItem?.targetID == targetB)

        // 5. Forced hide (click/scroll/key/menu/dialog via hideImmediately / dismissFromUserInteraction)
        // immediately clears the skip window and suppresses re-showing until pointer exits,
        // and moving to another button within 300ms still requires the full hoverDelay wait.
        center.dismissFromUserInteraction()
        #expect(center.activeItem == nil)
        #expect(center.lastHoverDismissedAt == nil)

        center.updateAnchor(
            targetID: targetB,
            anchorRect: anchorB,
            content: .standard(
                label: "Settings",
                shortcut: .fixed("⌘,"),
                wrapsText: false
            )
        )
        try await Task.sleep(nanoseconds: 60_000_000)
        #expect(center.activeItem == nil)

        currentTime = currentTime.addingTimeInterval(0.05)
        center.hoverEnded(targetID: targetB)
        center.hoverBegan(
            targetID: targetA,
            surface: .main,
            scenarioID: "topbar.entry.tasks",
            anchorRect: anchorA,
            content: .standard(
                label: "Tasks",
                shortcut: .none,
                wrapsText: false
            ),
            hoverDelay: 0.04
        )
        // Must NOT show immediately because previous tooltip was force-hidden
        #expect(center.activeItem == nil)
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(center.activeItem?.targetID == targetA)

        // Also verify that if a tooltip exits normally (opening skip window) and then a key/click/menu
        // occurs before entering the next button, hideImmediately() clears the skip window timestamp.
        center.hoverEnded(targetID: targetA)
        #expect(center.lastHoverDismissedAt != nil)
        center.hideImmediately()
        #expect(center.lastHoverDismissedAt == nil)

        currentTime = currentTime.addingTimeInterval(0.05)
        center.hoverBegan(
            targetID: targetB,
            surface: .main,
            scenarioID: "topbar.entry.settings",
            anchorRect: anchorB,
            content: .standard(
                label: "Settings",
                shortcut: .fixed("⌘,"),
                wrapsText: false
            ),
            hoverDelay: 0.04
        )
        #expect(center.activeItem == nil)
        try await Task.sleep(nanoseconds: 70_000_000)
        #expect(center.activeItem?.targetID == targetB)

        center.hoverEnded(targetID: targetB)
        #expect(center.activeItem == nil)
    }

    @Test
    func truncationDetectionRequiresIntrinsicWidthToExceedRenderedWidth() {
        #expect(!TooltipGeometry.isTextTruncated(intrinsicWidth: 100, renderedWidth: 100))
        #expect(!TooltipGeometry.isTextTruncated(intrinsicWidth: 100.3, renderedWidth: 100))
        #expect(TooltipGeometry.isTextTruncated(intrinsicWidth: 140, renderedWidth: 100))
        #expect(!TooltipGeometry.isTextTruncated(intrinsicWidth: 140, renderedWidth: 0))
    }

    @MainActor
    @Test
    func tooltipOverlayViewRendersActiveItemInHostingViewWithoutReentrancyCrash() {
        let suiteName = "TooltipTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: userDefaults)
        let center = TooltipCenter()
        let rootView = TooltipOverlayView(surface: .main, center: center)
            .environmentObject(settings.playbackShortcuts)
            .environmentObject(settings.localization)
            .frame(width: 800, height: 600)

        let host = NSHostingView(rootView: rootView)
        host.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let targetA = UUID()
        center.hoverBegan(
            targetID: targetA,
            surface: .main,
            scenarioID: "topbar.entry.tasks",
            anchorRect: CGRect(x: 120, y: 20, width: 28, height: 28),
            content: .standard(
                label: "Tasks",
                shortcut: .none,
                wrapsText: false
            )
        )
        center.revealPendingNowForTesting()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        #expect(center.activeItem?.targetID == targetA)

        // Switching to a CueState tooltip and laying out must also complete cleanly.
        let targetB = UUID()
        center.hoverBegan(
            targetID: targetB,
            surface: .main,
            scenarioID: "table.cue_state.unavailable",
            anchorRect: CGRect(x: 240, y: 120, width: 16, height: 16),
            content: .cueState(.unavailable(.videoMissing))
        )
        center.revealPendingNowForTesting()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        #expect(center.activeItem?.targetID == targetB)

        center.dismiss()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        #expect(center.activeItem == nil)
        window.orderOut(nil)

        let singleLineBubble = NSHostingView(
            rootView: TooltipStandardBubbleView(
                label: "Tasks",
                shortcutText: nil,
                wrapsText: false
            )
        )
        singleLineBubble.layoutSubtreeIfNeeded()
        #expect(abs(singleLineBubble.fittingSize.height - WorkbenchControlMetrics.redesignHeight) < 0.5)
        #expect(TooltipGeometry.inlineShortcutSpacing == WorkbenchControlMetrics.redesignSpacing2)
        #expect(TooltipGeometry.truncatedTextMaxWidth == WorkbenchControlMetrics.redesignTooltipMaxWidth)
        #expect(TooltipCenter.defaultHoverDelay == WorkbenchControlMetrics.redesignTooltipHoverDelay)
        #expect(TooltipCenter.defaultSkipWindowDelay == WorkbenchControlMetrics.redesignTooltipSkipWindowDelay)
        #expect(WorkbenchControlMetrics.redesignTooltipSkipWindowDelay == 0.3)
    }

    @Test
    func allTooltipLocalizationKeysAndLegacyCopyUpdatesResolveInAllThreeLanguages() {
        let requiredKeys = [
            "topbar.back",
            "topbar.forward",
            "topbar.show_sidebar",
            "topbar.hide_sidebar",
            "task.entry",
            "topbar.settings",
            "playback.play",
            "playback.pause",
            "playback.mute",
            "playback.repeat",
            "settings.shortcuts.action.repeatCue",
            "common.close",
            "table.state.content_changed",
            "table.state.changed_after_reindex",
            "table.state.previous",
            "table.state.current",
            "table.state.unavailable",
            "tooltip.topbar.back.disabled",
            "tooltip.topbar.forward.disabled",
            "tooltip.playback.return_to_workbench",
            "tooltip.playback_overlay.collage.edit",
            "tooltip.playback_overlay.collage.exit",
            "tooltip.command_panel.back",
            "tooltip.player.previous.cue",
            "tooltip.player.previous.cue.disabled",
            "tooltip.player.previous.video",
            "tooltip.player.previous.video.disabled",
            "tooltip.player.next.cue",
            "tooltip.player.next.cue.disabled",
            "tooltip.player.next.video",
            "tooltip.player.next.video.disabled",
            "tooltip.player.unmute",
            "tooltip.player.repeat.disabled",
            "tooltip.player.copy_screenshot",
            "tooltip.player.subtitles.show",
            "tooltip.player.subtitles.hide",
            "tooltip.player.speed",
            "tooltip.player.fullscreen.enter",
            "tooltip.player.fullscreen.exit",
            "tooltip.player.fullscreen.disabled",
            "tooltip.input.search.clear",
            "tooltip.input.shortcut.clear",
            "tooltip.settings.shortcuts.restore_default",
            "tooltip.anki_export.choose_folder",
            "tooltip.anki_export.add_item",
            "tooltip.disabled.anki_export.all_items_added",
            "tooltip.disabled.cover_summary.no_playable_content",
            "tooltip.disabled.file.task_or_compaction_running",
            "tooltip.disabled.file.index_now.no_folder",
            "tooltip.disabled.filter.reset",
            "tooltip.disabled.settings.play.auto_switch",
            "tooltip.disabled.settings.subtitle.restore_defaults",
            "tooltip.disabled.settings.maintenance.actions",
            "tooltip.disabled.edit_cover.save"
        ]

        let concreteLanguages: [AppLanguage] = [
            .english,
            .simplifiedChinese,
            .traditionalChinese
        ]
        for language in concreteLanguages {
            for key in requiredKeys {
                let value = localized(key, language: language)
                #expect(!value.isEmpty, "Missing localization for \(key) in \(language.rawValue)")
                #expect(value != key, "Unresolved key \(key) in \(language.rawValue)")
            }
        }

        // Verify legacy copy updates explicitly
        #expect(localized("topbar.back", language: .simplifiedChinese) == "后退")
        #expect(localized("topbar.back", language: .traditionalChinese) == "後退")
        #expect(localized("playback.repeat", language: .english) == "Replay Current Cue")
        #expect(localized("playback.repeat", language: .simplifiedChinese) == "重播当前台词")
        #expect(localized("playback.repeat", language: .traditionalChinese) == "重播目前台詞")
        #expect(localized("settings.shortcuts.action.repeatCue", language: .english) == "Replay Current Cue")
        #expect(localized("settings.shortcuts.action.repeatCue", language: .simplifiedChinese) == "重播当前台词")
        #expect(localized("settings.shortcuts.action.repeatCue", language: .traditionalChinese) == "重播目前台詞")
    }

    private func localized(_ key: String, language: AppLanguage) -> String {
        AppLocalization._bundleForTesting(language).localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }
}
