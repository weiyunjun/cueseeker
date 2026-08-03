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
- Removed loaded-image intrinsic dimensions from cover-stack measurement and
  laid out each image directly from the resolved Cover Region.
- Filled loaded Library and Shiori images from the top center: narrower images
  crop only at the bottom, while wider images crop equally at the leading and
  trailing edges.
- Reused that frame for Library folders, Library episodes, Recent Videos,
  Recent Shioris, Shiori List cards, and the Shiori List editor preview.
- Kept the existing adaptive card widths, fixed episode-cover dimensions,
  image fill-and-crop behavior, overlays, interactions, and crop editor.
- Added layout regression coverage for exact overlay bounds and for 16:9,
  4:3, square, portrait, and 21:9 image geometry.

## Verification

- `swift build`: passed.
- Focused Library Cover, Shiori editor, Playback Library, media selection, and
  shared multi-module host run: 48 tests passed.
- Follow-up top-center crop run over the same shared surfaces: 50 tests passed,
  including exact 4:3, 16:9, and 21:9 geometry plus Badge bounds.
- The layout coverage passed for 16:9, 4:3, square, portrait, and 21:9 image
  sources, including Badge bounds.
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
