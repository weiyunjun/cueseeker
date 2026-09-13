# SRT subtitle style and position settings

Human-owned documents:

- `docs/human/requirements/20260913-Feature-SRT Subtitle Style And Position Settings.md`
- `docs/human/design/UI Design System.md` (Settings Window Layout, Settings Category Layout, Section Title, Number Field, Form Checkbox, Segmented Control, Button / Neutral) and `docs/human/design/Icon Registry.md`, to be updated by the owner after acceptance

## Why

SRT subtitles were drawn with one fixed look copied from IINA's defaults: bottom centre, white text with a 3 px black outline, and a size of 55 turned into a CoreText 44 pt by eye. The requirement adds Settings / Subtitle so the owner can choose the text style, border, shadow and position, with lengths in pixels of a 720-high picture and the size meaning one line's ascent plus descent, as ASS and mpv measure it. Discussion before the requirement settled the choices by copying existing players: libass for size, synthetic italic and bold, blur and shadow order; mpv for the three border types; Kodi for independent Background Color and Shadow fields with a fixed box padding.

Classified as platform UI and UX (the Settings page) plus playback execution (the SRT renderer). The style is presentation of subtitle overlay execution, so it lives in `CueSeekerPlayback` beside the renderer; no product semantics move and nothing in `CueSeekerCore` changes.

## What changed

- `SRTSubtitleStyle` (new, `CueSeekerPlayback`) holds the seventeen settings and their defaults: system font, size 55, no bold or italic, white text, letter spacing 0, line spacing 8, Outline type, black outline 3, background and shadow black at 50 %, blur 0, shadow offset 0, centre and bottom, margins 25 and 22. The box padding is a fixed 4 and the smallest size 1. Defaults are provisional until the owner's in-App acceptance, as the requirement says.
- `SRTSubtitleRenderer` takes the style. Every face in a cue — the chosen font and each fallback face CoreText would use for characters it lacks — is sized so its ascent plus descent is the size, as libass sizes each face. A face with no italic or bold is slanted (10° for PostScript outlines, GDI's 18.77° otherwise) or widened by a 64th of its size, as libass does; SRT's own `<i>` and `<b>` go through the same path, so they now slant Japanese and Chinese text, which the trait lookup alone left upright. Letter spacing is CoreText kerning; line spacing is paragraph line spacing, which only adds between lines.
- Placement measures each line's ascent and descent and the glyph ink instead of CoreText's frame, which for some faces is taller than the size (Helvetica at 55: frame 66). Margins and alignment place the text with its outline or boxes; shadow and blur extend the placement. The first cue sits at its margins, or in the middle for Center; later cues stack upward for Bottom and Center and downward for Top, without gaps, as before.
- Drawing is shadow, then box or outline, then text. Each part is drawn as one layer so its color's opacity applies once. Blur runs Core Image's Gaussian blur on the outline when there is one and on the text otherwise, with the shadow drawn from the blurred shapes; libass's blur-to-deviation factor is kept. Opaque Box draws one box per line and no outline, its shadow is the boxes'; Background Box draws one box around the lines and keeps the outline, with no shadow; Outline draws no box.
- The overlay view rebuilds its layout when the style changes; the render container keeps the current style for an overlay created later, and `PlaybackPlayer.srtSubtitleStyle` forwards it. The P screenshot reads the overlay's image and so follows.
- `SubtitleScreenshotExporter`'s screenshot, collage and collage-group entry points take the style and pass it to the shared SRT drawing core. ASS paths are untouched.
- `SettingsStore.srtSubtitleStyle` is stored as JSON under `srtSubtitleStyle`. `AppCoordinator` hands it to the player at creation and on every change, to `PlaybackStore`, which passes it to the open Playback Overlay session, and to the Search and Excerpt screenshot exports. A change while the collage editor is open on an SRT video replaces the preview store with one on the new style and renders the current selection again.
- `SettingsSubtitleCategory` (new) is the page, below Shortcuts with the `subtitles` icon: Page Title, then Text, Border, Shadow and Position under Section Titles in one grid whose name column is as wide as the longest name, with the controls `--spacing-6` from it and rows `--spacing-3` apart; a later Section Title adds up to `--spacing-4` above itself. Font shows the face's name and a Choose… button that opens the system font panel, keeping only the face it reports. Colors are SwiftUI's native color well with opacity. Numbers use Number Field without a unit, apply while in range as they are typed and clamp to their lower bound on Return or leaving the field. Bold and Italic are Form Checkboxes; Type and the alignments are Segmented Controls. The rows Type makes irrelevant are disabled: Background Color for Outline, Outline Color and Width for Opaque Box, Shadow Color and Offset for Background Box. Restore Defaults, a Neutral Button with the `arrow-counter-clockwise` icon, is disabled while everything is at its default.
- `--width-settings-window-min` rises from 680 to 760 so Type's three options fit; a provisional `--width-settings-number-field` of 114 matches Settings / Play's field. English, Simplified and Traditional Chinese copy added.
- `docs/changelog.md` records the change.

Files:

- `apps/macos-native/Sources/CueSeekerPlayback/SRTSubtitleStyle.swift` (new)
- `apps/macos-native/Sources/CueSeekerPlayback/SRTSubtitleRenderer.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackPlayer.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsSubtitleCategory.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+SubtitleScreenshotExport.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreviewStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/SRTSubtitleStyleRenderingTests.swift` (new)
- `apps/macos-native/Tests/CueSeekerPlaybackTests/PlaybackRequestTests.swift`, `PlaybackCurrentFrameScreenshotTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SettingsStorePlaybackTests.swift`
- `docs/changelog.md`

## Verification

Unit tests, new in `SRTSubtitleStyleRenderingTests`: a one-line cue is 55 high at 720 and 1.5 times that at 1080 for both Helvetica (ascent plus descent one em, taller CoreText frame) and PingFang SC (1.4 ems); Left/Top and Right/Bottom put the text at the margins and Center in the middle; Top stacks a second cue below the first and Center above it; line spacing 10 adds 10 to a two-line cue and nothing to a one-line cue; Italic makes Hiragino Sans, which has no italic face, wider; Opaque Box paints the background color just inside the box's edge and Outline paints nothing there; the style survives JSON. In `SettingsStorePlaybackTests`, the style survives a new store on the same preferences. The existing SRT renderer, cancellation, current-frame screenshot and exporter tests pass with the style added, as do the localization key parity and collage preview suites.

`swift test`: 1218 tests, 14 failing, all in the set earlier records list as failing on the baseline or under the full suite's load: the seven native playback timeline, audio, presentation and auto-pause cases, the two Debug E2E scene and window-width cases, the four refresh-scope integration cases, and `libraryFolderRemovalAndIndexingRejectEachOther`. None draws a subtitle or reads Settings.

A default-style sample drawn at 1080 through the existing `CUESEEKER_SRT_VISUAL_OUTPUT` hook shows two stacked Japanese cues, white with a black outline, centred at the bottom.

In the App: Debug E2E controller, `swift run CueSeeker --cueseeker-debug-e2e` from a PTY, main window 1445×821 at 2×, Settings window 760×520 at (342, 76), English, Light, with the existing `inspect`, `click`, `scroll`, `keyPress` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures and are not documented procedure coordinates.

1. Subtitle sits below Shortcuts with its icon. The page shows Text, Border, Shadow and Position with every row; the names share one column and at the window's 760 width Type's Outline / Opaque Box / Background Box fits beside it with room to spare. Restore Defaults is disabled.
2. With Type at Outline, clicking Background Color's well opened no color panel: the disabled row takes no input.
3. Clicking Top selected it and enabled Restore Defaults; clicking Restore Defaults put Vertical back on Bottom and disabled the button again. The settings were left at their defaults.

Not verified here and left to the owner's acceptance, as agreed: how the styles look over real video, the system font and color panels, typing decimals (the controller has no period or delete key), the live update while a video plays, the P screenshot, and the Collage preview re-rendering after a change.

## Outcome

Matched expectations for what could be checked. One finding beyond the requirement: CoreText lays some faces out in a frame taller than their ascent plus descent, so placement measures the lines themselves; the first unit test run caught it for Helvetica (11 px off at 55). The default values, including line spacing 8 and the 50 % background and shadow, await the owner's acceptance and the requirement's update.
