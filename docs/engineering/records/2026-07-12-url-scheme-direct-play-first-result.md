# URL Scheme Direct Play First Result

Date: 2026-07-12

## Requirement

- `docs/human/requirements/20260712-Feature-URL Scheme Direct Play First Search Result.md`

## Scope

Add an opt-in URL Scheme behavior that uses the existing complete first visible
search page and plays its first ordered result without rendering an intermediate
Search page.

## Steps

1. Defined setting persistence, reuse of the existing 100-row first-page search,
   the accepted-page decision point, fallback behavior, and generation-bound
   cancellation in `docs/engineering/10_url_scheme.md`.
2. Added the URL Scheme Settings category and the shared-preferences-backed
   `Play First Search Result` toggle, defaulting to off.
3. Added a generation-bound, one-shot URL intent to the existing `startSearch`
   pipeline. It is consumed only after the complete first visible page passes
   existing stale guards, is assigned to `SearchStore`, and is grouped.
4. Reused `openSearchResult` for the first ordered page result and selected
   Search as the playback origin in the same main-actor transaction. Empty and
   failed pages fall back to Search, while new URLs cancel old intents, search
   tasks, exact completion, and active playback independently of the setting.
5. Added regression coverage proving a replacement URL cancels the old intent,
   first-page task, exact-completion task, and playback even when direct play is
   disabled for the replacement request.

## Verification

- `swift test` passed all 7 XCTest tests and 560 Swift Testing tests.
- Settings tests confirmed the toggle defaults off and persists in the shared
  preferences suite.
- Parser and routing tests confirmed the original disabled behavior remains
  unchanged, empty and failed first pages fall back to Search, and only a
  matching generation can consume an intent.
- A real indexing integration test produced a complete two-row first visible
  page through the existing `searchVisiblePage` pipeline and confirmed the
  selected playback item was exactly `searchResults.first`.
- Replacement-command regression coverage confirmed the old intent, first-page
  task, exact-completion task, and playback are cancelled independently of the
  replacement request's setting.
- `scripts/package_macos_app.sh` rebuilt and recursively verified the
  self-contained, ad-hoc-signed ARM64 app.
- Replaced and registered `/Applications/CueSeeker.app`, enabled the option in
  shared preferences, and cold-opened an encoded `大丈夫` URL. The installed
  process opened the media file belonging to the first result of the logged
  standard `visibleWindow` page.
- While that video was active, an unmatched URL closed the media file and the
  same standard first-page pipeline completed with zero results, exercising the
  Search fallback.

## Outcome

Implementation and automated verification match the requirement. The installed
build is ready for human end-to-end acceptance; `Play First Search Result` is
left enabled for that validation.

## Follow-ups

- None for version 1.
