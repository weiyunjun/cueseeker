# Search Settings Scope

## Human-Owned Source

- `docs/human/requirements/20260707-Feature-Search Settings Scope.md`

## Scope

Add a dedicated Settings > Search category, move the primary Search language
setting there, and add a persisted Search Scope setting that filters regular
Search results by matched video watch state.

## Classification

- Product semantics: regular Search may now be scoped to all videos, only
  Finished videos, or Watching plus Finished videos.
- Platform UI/UX: Settings gains a `Search` sidebar category with a
  magnifying-glass icon and two pickers.
- Platform integration: unchanged; the setting persists through UserDefaults.
- Playback execution: unchanged; playback and cue-context execution do not use
  the Search Scope setting.

## Changes

- Added `SearchScope` to app settings with `All`, `Only Finished`, and
  `Watching + Finished` options, defaulting to `All`.
- Added `SettingsSearchCategory` and moved `Primary Search Language` out of the
  Appearance category.
- Added a core `SubtitleSearchWatchStateFilter` and applied it inside regular
  subtitle search SQL before result counts, file summaries, and pagination are
  materialized.
- Wired regular Search page loading, exact count completion, table hydration
  fallback, and per-file group loading to the Search Scope setting.
- Left Cue Context search and Shiori context/search paths without the Search
  Scope filter.
- Updated product requirements to document the Settings > Search category and
  the scope boundary.

## Verification

- `git diff --check`
- `swift test --filter settingsStorePersistsSearchScope`
- `swift test --filter searchFiltersByLibraryWatchState`
- `swift test`

## Outcome

The Search settings category and persisted Search Scope are implemented. Regular
Search now filters at the database query layer so result rows, counts, file
summaries, and pagination stay consistent, while Shiori and Cue Context search
behavior remains unscoped.
