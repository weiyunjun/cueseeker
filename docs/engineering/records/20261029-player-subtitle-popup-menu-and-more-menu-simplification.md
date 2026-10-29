# 2026-10-29 Player Subtitle Popup Menu And More Menu Simplification

## Requirement Reference
- `docs/human/requirements/20261029-UI-Player Subtitle Popup Menu And More Menu Simplification.md`

## Summary of Changes
1. **Player Subtitle Popup Menu & Snapshot Binding (`PlaybackChromeMoreMenu.swift`, `PlaybackChromeView.swift`, `PlaybackVideoStage.swift`, `PlaybackStore.swift`, `MenuGate.swift`, `AppCoordinator+PlaybackSubtitle.swift`, `WorkbenchPopoverControls.swift`)**:
   - Converted the Player Bottom Control Bar subtitle button into a popup menu trigger (`PlaybackSubtitleButtonAnchorKey`, `PlaybackChromeSubtitleMenuOverlay`, `PlaybackSubtitleMenu`, `MenuGate.Kind.playerSubtitleMenu`), showing the `Open` highlight background only while the subtitle menu is open and removing its Tooltip.
   - Bound `PlaybackSubtitleMenu` to the `[VideoSubtitle]` snapshot captured when the menu opens (`PlaybackSubtitleMenuChoice.subtitle(Int)` / `.off`), so clicking an item or `Off` acts directly on the open snapshot without re-querying the database or inferring `Off` from live database counts.
   - Structured `PlaybackSubtitleMenu` with the video's matched subtitles in sorted order (tagging the default subtitle with `Default`), a `WorkbenchMenuDivider`, and a trailing `Off` (`关闭` / `關閉`) item.
   - Implemented single-choice checkmark and click/Enter feedback rules in `AppCoordinator.selectPlaybackSubtitleMenuItem(_:)`:
     - Clicking an already-checked item closes the menu without showing any HUD.
     - Clicking a different subtitle while subtitles are On switches to that subtitle and shows the 1s `Subtitle Switched` (`字幕已切换` / `字幕已切換`) HUD.
     - Clicking `Off` while subtitles are On hides subtitles and shows the 1s `Subtitles Off` (`字幕已关` / `字幕已關`) HUD.
     - Clicking a subtitle while subtitles are Off turns subtitles On and shows `Subtitles On` (`字幕已开` / `字幕已開`) when selecting the previously active subtitle or `Subtitle Switched` (`字幕已切换` / `字幕已切換`) when selecting a different subtitle.
   - Shared `PlaybackWrappedMenuPanelLayout`, `PlaybackHostedMenuSurface`, and `PlaybackChromeMenuItem` between `PlaybackChromeMoreMenuOverlay` and `PlaybackChromeSubtitleMenuOverlay`, and applied `.environment(\.colorScheme, .dark)` inside `WorkbenchPopoverPanel` on `.playerChrome` surfaces so `WorkbenchMenuDivider` and scrollbars render with dark-surface styling in both Light and Dark system appearances.
2. **Simplify `More` (`...`) Menu & Remove Player UI Default Persistence (`PlaybackChromeMoreMenu.swift`, `AppCoordinator+PlaybackAudioTrack.swift`, `AppCoordinator+PlaybackSubtitle.swift`, `PlaybackVideoStage.swift`)**:
   - Simplified `PlaybackMoreSubmenu` to `.audioTrack` only and removed multi-submenu dictionary dispatch and dead disabled-trigger branches, removing `Subtitle`, `Default Audio Track`, and `Default Subtitle` from the `More` menu and removing `setPlaybackDefaultAudioTrack` / `setPlaybackDefaultSubtitle` from the Player UI while keeping the underlying database persistence APIs intact.
   - Kept `Audio Track` always enabled and expandable in the `More` menu; when the video has no audio tracks, its submenu displays a single disabled `No Audio Tracks` (`无音轨` / `沒有音軌`) item via `PlaybackChromeMenuItem(showsCheckmarkSlot: false, isEnabled: false)` (`selectablePositions` is empty).
3. **Localization & HUD Feedback (`Localizable.strings`, `PlaybackViewModel+Feedback.swift`)**:
   - Added `"playback.subtitle_menu.off"`, `"playback.more.no_audio_tracks"`, and `"playback.hud.subtitle_switched"`, and removed unused `"playback.more.subtitle"`, `"playback.more.default_audio_track"`, `"playback.more.default_subtitle"`, `"playback.more.current_tag"`, `"tooltip.player.subtitles.show"`, and `"tooltip.player.subtitles.hide"` across `en.lproj`, `zh-Hans.lproj`, and `zh-Hant.lproj`.

## Verification
- Updated and added unit tests in `PlaybackMoreMenuTests.swift`, `AppLocalizationTests.swift`, and `TooltipTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "PlaybackMoreMenuTests|AppLocalizationTests|TooltipTests"`.
- Outcome matched expectations.
