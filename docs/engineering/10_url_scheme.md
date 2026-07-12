# URL Scheme

Status: Active

## Identity

- The final macOS bundle identifier is `com.cueseeker.app`.
- The application URL scheme is `cueseeker`.
- The preferences suite remains `com.cueseeker.shared`; changing the bundle
  identifier must not split or reset local application state.

## Version 1 Contract

The only supported command is:

```text
cueseeker://search?q={{keyword}}
```

Rules:

- The scheme and host are compared case-insensitively.
- The host must be `search`; the path must be empty or `/`.
- Exactly one `q` query item is required.
- `URLComponents` performs percent decoding. The decoded keyword is trimmed of
  surrounding whitespace and newlines and must remain non-empty.
- User information, a port, fragments, unknown parameters, duplicate `q`
  parameters, malformed percent encoding, and unsupported hosts are rejected.
- Invalid URLs are ignored without changing application state or presenting an
  error in version 1.

Non-ASCII keywords should be percent-encoded when links are constructed. macOS
may deliver a decoded URL object, but the parser must not depend on raw Unicode
being accepted by every external launcher.

## Delivery

The AppKit delegate registers an Apple Event handler for
`kInternetEventClass` / `kAEGetURL` before application launch completes. A
valid command received before the main window exists is retained and consumed
after the window is created. A valid command received while running is handled
immediately on the main actor.

Only the most recently received pending command is retained during startup.
Every running-state command is processed once.

## Search Behavior

When optional direct playback is off, handling a valid search command must:

1. Leave fullscreen and stop active playback, preserving the existing playback
   history behavior.
2. Select the Search workbench panel.
3. Clear the active search filter set and any cue-context search state.
4. Put the decoded keyword in the visible search field.
5. Submit through the existing non-debounced search pipeline.
6. Make the main window key and activate CueSeeker. Optional direct playback
   defers this step until its first-page outcome is ready.

The URL handler must not duplicate database search logic.

## Optional Direct Playback

Settings exposes a URL Scheme category with a `Play First Search Result`
toggle. The toggle is persisted in the shared preferences suite and defaults to
off.

When off, the version 1 Search behavior remains unchanged. When on, URL Scheme
search uses the same non-debounced `startSearch` pipeline and the same
`searchVisiblePage` request with the standard 100-row first-page limit. It must
not issue a separate one-row query, observe published rows to guess completion,
or wait for the later exact-count completion task.

While that first page is pending, CueSeeker must not bring an intermediate
Search page to the foreground. A cold URL launch creates the main window
without ordering it front, and a running-state URL command does not reactivate
the window until the direct-play intent resolves. If Playback is already
visible, its current selection, native player session, and expanded surface
remain active while the new first page is pending. A failed or empty result
stops that playback and selects Search before presenting the window.

The direct-play decision occurs only after the complete first visible page:

1. returns from the database;
2. passes the existing cancellation, query, folder, language, watch-state, and
   active-filter stale-result guards;
3. is assigned to `SearchStore` and grouped by the normal presentation path.

If that accepted page contains rows, CueSeeker opens `page.results.first`
through the existing Search-result playback entry point. It first establishes
the selected result and expanded Playback presentation, then selects Search as
the underlying return panel, and only then presents the main window. Closing
playback therefore returns to the populated Search page without exposing that
page before playback. If the page is empty or the search cannot produce a page,
CueSeeker displays the populated or failed Search page instead.

When Playback is already visible, the successful result must not collapse or
recreate the Playback presentation. If the result resolves to the same
standardized video path, the existing native player session reloads the
subtitle source and seeks to the result timestamp. If it resolves to a
different video path, the existing Playback presentation stays visible while
the player replaces its media source. Both outcomes replace the Playback return
panel with Search so closing the result returns to the new populated query.
When an empty or failed result reveals Search immediately after Playback, the
native Search table must reconcile its cached row snapshot with `SearchStore`
after the covered-table gate reopens; rows from the previous query must never
remain visible in the fallback.

Every valid new URL Scheme command cancels the previous URL intent and current
search task. With optional direct playback off, the command stops active
playback before opening Search. With direct playback on, active playback is
preserved until the accepted page reuses or replaces its source, or until an
empty or failed result stops it for Search fallback. Background indexing and
database maintenance are not URL intents and are not cancelled. A one-shot
intent is generation-bound to the search that created it; stale or superseded
pages can never start playback.

## Packaging and Verification

The packaged `Info.plist` must declare the final bundle identifier and one URL
type containing the `cueseeker` scheme. Bundle verification must fail when
either value is missing or different.

Parser behavior, search-state transitions, and invalid-input no-op behavior
require automated tests. Final acceptance additionally requires both cold and
running-state launches through macOS Launch Services.
