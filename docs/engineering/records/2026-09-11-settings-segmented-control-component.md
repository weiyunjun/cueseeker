# One Segmented Control for both settings choosers

Human-owned documents:

- `docs/human/requirements/20260911-UI-Settings Segmented Control Component.md`
- `docs/human/design/UI Design System.md` (to be updated by the owner after acceptance)

## Why

Appearance Mode and Decoder each drew their own three-way chooser. The two were line-for-line copies kept private to their settings pages, so nothing else could use them, and every value in them was written in place: 12pt Medium labels, 72×26 options, a 2pt gap, 3pt padding, 7 and 5 corners, and system colours instead of design tokens. The design document had no such component. The owner wants it defined once so later screens can call it.

## What changed

- A shared Segmented Control replaces both copies. The caller passes the options, the selection, each option's title and its accessibility label; the two settings pages now call it and their private copies are gone.
- Every value comes from a token. New, and provisional until the design document takes them: `--height-segmented-control` 32, `--padding-segmented-control` 3, `--gap-segmented-control` 2, `--font-size-segmented-control` 12, `--color-segmented-control-selected-bg` (macOS accent) and `--color-segmented-control-selected-content` (white). Reused: `--radius-control`, `--font-weight-control`, `--padding-control-x`, `--color-bg-surface`, `--color-border-control`, `--border-width-control` and `--color-text-primary`.
- The selected block's height and corner are derived rather than tokens of their own: the control's height less its padding on both sides, and the control's corner less that padding, concentric the way a menu item is with its menu. Both corners use the continuous curve the buttons use, where the copies used a circular one.
- Every option takes the widest option's own width — its label plus `--padding-control-x` on each side, rounded up to a whole point — through a small layout that measures the options. A fixed option width would cut a longer label off in another language.
- Behaviour is unchanged: no hover, the press does not change the look, the control never takes focus, and the accessibility label and selected state read as before.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSegmentedControl.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsAppearanceCategory.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsDecodeCategory.swift`

## Verification

Debug E2E controller, main window 1445×821 at 2×, Settings window 760×520 at (342, 76), with the existing `click`, `keyPress` and `capture` commands; no E2E facility was added. The Settings entry, category and option coordinates were read off this session's captures and are not documented procedure coordinates. The same captures were taken on the build before the change and on the build after it, and the control was measured in pixels.

- Height: 32pt before and after; the selected block 26pt in both.
- Labels: every label's ink box is the same size and on the same rows before and after (for example `Software` 102×19 px, `Auto` 52×18 px), so the type is unchanged.
- Width: Appearance 226 → 184pt (each option 58), Decoder 226 → 262pt (each option 84). Both stay right-aligned in their row.
- Light: the border goes from a half-point `#E6E6E6` line, the outer half of a centred stroke that was clipped, to a full point of `#E5E7EB`. The background stays white.
- Dark: the control's background goes from `#1E1E1E` to the page's own `#18181B`, the border from a half-point `#343434` to a full point of `#3F3F46`, and unselected labels from `#DDDDDD` to `#F7F7F7`.
- Clicking Software selected it at once; clicking Hardware put it back. Clicking Dark switched the app to dark and Light switched it back. Both settings were left as found: Light and Hardware.

`swift test`: 1176 tests, run with and without this change on the same tree. Without it, 13 fail; with it, 15. The three that fail only with it — library folder removal progress, native rapid-seek presentation, the auto-pause seek boundary — each passed three times out of three when run alone with the change, and all three belong to the suite's existing environment- and timing-dependent families. One library folder removal test failed only without it. `shioriTableStartsAtTopAfterPanelRemount` fails the same way on both trees, including when run alone. No failure is new, and none of the failing tests reads a settings page or a segmented control.

## Known limits

The two controls are no longer the same width. Each follows its own labels, as the requirement asks.

The title and description beside each control, and the settings page title, are still written in place. The requirement leaves them out of scope.

## Follow-up: the tokens are in the design document

The owner accepted the look and recorded it in `docs/human/design/UI Design System.md` in `52bbbca1`: the six new tokens, the Segmented Control under Selection Controls, and its place in the Settings Category Layout components.

The four size and type tokens in code no longer say they are provisional. The two colours never carried that note. The code's values already matched the document, so nothing else changed.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`

Verification: `swift build` is clean. The change is a comment, so the App's look and behaviour are unchanged.
