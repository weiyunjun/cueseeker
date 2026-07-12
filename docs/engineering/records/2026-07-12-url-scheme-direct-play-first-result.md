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

- Pending implementation.

## Outcome

Pending implementation and human end-to-end acceptance.

## Follow-ups

- None for version 1.
