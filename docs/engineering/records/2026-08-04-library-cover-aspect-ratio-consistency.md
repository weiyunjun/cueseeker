# Library Cover Aspect Ratio Consistency

## Requirement

- `docs/human/requirements/20260804-Bug-Library Cover Aspect Ratio Consistency.md`
- `docs/human/design/UI.md`

## Classification

- Platform UI/UX: keeps every Library Cover presentation inside the shared
  16:9 frame defined by the existing UI token.
- Product semantics, persistence, platform integration, and playback
  execution: unchanged.

## Scope

- Added one shared Library Cover frame that resolves 16:9 geometry before it
  overlays image, progress, Badge, or placeholder content.
- Reused that frame for Library folders, Library episodes, Recent Videos,
  Recent Shioris, Shiori List cards, and the Shiori List editor preview.
- Kept the existing adaptive card widths, fixed episode-cover dimensions,
  image fill-and-crop behavior, overlays, interactions, and crop editor.
- Added a layout regression test covering 16:9, 4:3, square, and portrait
  image sources.

## Verification

- `swift build`: passed.
- Focused Library Cover, Shiori editor, Playback Library, media selection, and
  shared multi-module host run: 48 tests passed.
- The new layout test passed for 16:9, 4:3, square, and portrait image sources.
- `swift test`: ran 950 tests and reported 23 issues in unrelated concurrent
  native playback timing, playback presentation, Subtitle Focus, Library
  removal, UI refresh-probe, and row-menu pointer tests.
- All full-suite failures passed when rerun in focused selections: 5 native
  playback timeline tests, 2 native presentation-transition tests, and 4
  individual Subtitle Focus, Library removal, refresh-scope, and row-menu tests.
- Source scan confirmed that Library Cover display geometry now resolves only
  through the shared frame; the remaining image-only aspect fit belongs to the
  crop editor.
- `git diff --check`: passed.

## Outcome

Library Cover geometry is now independent of decoded image dimensions and
source aspect ratio. Shared Workbench and Playback hosts receive the same 16:9
frame without changing cover data, crop results, overlays, or interactions.
