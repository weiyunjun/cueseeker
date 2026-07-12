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
6. Corrected the presentation timing after installed-app validation exposed an
   intermediate Search page. Direct-play commands now defer window activation
   until the accepted first page has either established Playback or selected
   the Search fallback. Successful playback publishes its visible selection
   before Search becomes the underlying return panel.
7. Removed the eager Playback stop for enabled direct-play commands. Existing
   Playback now remains visible while the first page is pending, then reuses the
   existing same-video seek path or replaces the media source without
   collapsing Playback. Empty and failed results still stop Playback before the
   Search fallback, and disabled commands retain the original Search behavior.
8. Fixed covered-table recovery for empty direct-play fallback. The Search
   table now performs a post-transition reconciliation whenever its standard
   Search response gate becomes active, even when SwiftUI coalesces away the
   previous `onChange` edge, while filter-only and Context tables retain their
   existing deferred-load gate.

## Verification

- `swift test` passed all 7 XCTest tests and 560 Swift Testing tests.
- Settings tests confirmed the toggle defaults off and persists in the shared
  preferences suite.
- Parser and routing tests confirmed the original disabled behavior remains
  unchanged, empty and failed first pages fall back to Search, and only a
  matching generation can consume an intent.
- A real indexing integration test produced a complete two-row first visible
  page through the existing `searchVisiblePage` pipeline and confirmed the
  selected playback item was exactly `searchResults.first`; stopping that
  playback returned to Search with the originating keyword intact.
- Replacement-command regression coverage confirmed the old intent, first-page
  task, exact-completion task, and playback are cancelled independently of the
  replacement request's setting.
- Presentation-readiness coverage confirmed disabled commands present Search
  immediately, failed direct-play commands present only their Search fallback,
  and successful direct-play commands do not become presentation-ready until
  Playback is visible with Search established as its return panel.
- Running-playback coverage confirmed enabled direct-play commands preserve the
  selected result and expanded Playback surface while same-video and
  different-video first pages are pending, replace the return panel with Search
  after success, and stop Playback only for fallback. Disabled commands still
  stop Playback before opening Search.
- A mounted SwiftUI/AppKit integration regression began with 200 Search rows,
  covered the table with Playback, submitted an unmatched URL Scheme query, and
  confirmed the revealed table rebuilt exactly once to zero rows rather than
  retaining the previous query snapshot.
- The covered-table follow-up passed all 7 XCTest tests and 561 Swift Testing
  tests with zero failures.
- The follow-up `URLScheme` test filter passed all 10 parser, settings, routing,
  cancellation, fallback, and real first-page integration tests.
- The follow-up Release app was built, recursively bundle-verified, installed at
  `/Applications/CueSeeker.app`, and cold-launched through Launch Services with
  an encoded `大丈夫` URL. The installed app presented the first result in
  Playback with the direct-play option enabled.
- The playback-reuse follow-up passed all 7 XCTest tests and 560 Swift Testing
  tests. Its Release app was recursively verified, installed at
  `/Applications/CueSeeker.app`, cold-launched with `大丈夫`, and invoked again
  with the same URL while Playback was active. The second invocation retained
  the same app process and Playback presentation, and the process log contained
  no player-stop or audio-engine-restart event after that invocation, matching
  the existing same-video in-session seek path.
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

Implementation and automated verification match the requirement, including the
follow-up correction that removes the visible intermediate Search page. The
installed build is ready for human end-to-end acceptance; `Play First Search
Result` is left enabled for that validation.

## Follow-ups

- None for version 1.
