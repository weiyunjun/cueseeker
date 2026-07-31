# URL Scheme

Status: Active

## Identity

- The final macOS bundle identifier is `com.cueseeker.app`.
- The application URL scheme is `cueseeker`.
- The preferences suite remains `com.cueseeker.shared`; changing the bundle
  identifier must not split or reset local application state.

## Supported Commands

The supported commands are:

```text
cueseeker://search?q={{keyword}}
cueseeker://cue?id={{CueID}}
```

Common rules:

- The scheme and host are compared case-insensitively.
- The path must be empty or `/`.
- User information, a port, fragments, unknown parameters, duplicate query
  parameters, malformed percent encoding, and unsupported hosts are rejected.
- Invalid URLs are ignored without changing application state or presenting an
  error.

Search rules:

- The host is `search` and exactly one `q` query item is required.
- `URLComponents` performs percent decoding. The decoded keyword is trimmed of
  surrounding whitespace and newlines and must remain non-empty.

Cue rules:

- The host is `cue` and exactly one `id` query item is required.
- The decoded value must be a positive base-10 `Int64` CueID.

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

Every valid Search command must:

1. Preserve and apply the current persisted Workbench facet Filter while
   clearing any cue-context search state and its internal context rule.
2. Put the decoded keyword in the shared Search Feature query.
3. Submit through the existing non-debounced search pipeline.
4. Keep Workbench Search and Command Panel Search synchronized through the
   shared Search Feature state.

The URL handler must not duplicate database search logic.

When optional direct playback is off, presentation is selected immediately:

- If Playback has an active media selection, preserve Playback, pause it as
  required by normal Overlay entry, and open or reuse the Playback
  Multi-Module Overlay on Search.
- Otherwise, select Workbench Search.

When the Overlay is already open, a new Search command switches the existing
Session to Search and replaces its query rather than creating another Session.

## Optional Direct Playback

Settings exposes a URL Scheme category with a `Play First Search Result`
toggle. The toggle is persisted in the shared preferences suite and defaults to
off.

When on, URL Scheme search uses the same non-debounced `startSearch` pipeline
and the same `searchVisiblePage` request with the standard 100-row first-page
limit. It must not issue a separate one-row or Filter-specific query. With an
empty Workbench facet Filter, direct play resolves from that accepted first
visible page. With an active facet Filter, the existing exact-completion task
produces the formal filtered projection, and direct play resolves from that
projection's first result without adding another task or result collection.

While that first page is pending, CueSeeker must not bring an intermediate
Search page to the foreground. A cold URL launch creates the main window
without ordering it front, and a running-state URL command does not reactivate
the window until the direct-play intent resolves. If Playback is already
visible, its current selection, native player session, and expanded surface
remain active while the new first page is pending. A failed or empty result
preserves that Playback source and opens Overlay Search. Without active
Playback, the same outcome opens Workbench Search.

The direct-play decision occurs only after the required formal Search
projection:

1. returns from the database;
2. passes the existing cancellation, query, folder, language, watch-state, and
   active-filter stale-result guards;
3. is assigned to `SearchStore` and filtered by the current Workbench facet
   Filter;
4. exposes the first filtered result, or confirms that the filtered projection
   is empty.

If that accepted projection contains rows, CueSeeker opens its first result
through the existing Search-result playback entry point. It first establishes
the selected result and expanded Playback presentation, then selects Search as
the underlying return panel, and only then presents the main window. Closing
playback therefore returns to the populated, identically filtered Search page
without exposing that page before playback.

When Playback is already visible, the successful result must not collapse or
recreate the Playback presentation. If the result resolves to the same
standardized video path, the existing native player session reloads the
subtitle source and seeks to the result timestamp. If it resolves to a
different video path, the existing Playback presentation stays visible while
the player replaces its media source. Both outcomes replace the Playback return
panel with Search so closing the result returns to the new populated query.

Every valid new URL Scheme command cancels the previous URL intent and current
URL-owned search task. Active Playback is preserved until an accepted result
reuses or replaces its source, or until Search is opened inside its Overlay.
Background indexing and database maintenance are not URL intents and are not
cancelled. A one-shot intent is generation-bound to the command that created
it; stale or superseded work can never start playback or replace presentation.

## Cue Playback

A valid Cue command resolves the CueID through the indexed Cue model and its
active Subtitle-to-Video match. It then starts playback through a Playlist
containing exactly that Cue:

- The Playlist module is present in the Playback Multi-Module Overlay and shows
  the single Cue as its only item.
- The normal Playlist cue-boundary and automatic-switch preferences apply; Cue
  playback does not add a URL-specific auto-close rule.
- Closing Playback restores Workbench Search through the normal Playback Return
  Context mechanism.
- A new URL Scheme command supersedes unresolved Cue lookup or playback intent
  from an older command.

Unavailable CueIDs do not fall back to a keyword search or another Cue.

## Cue Markdown Link Serialization

Playback Overlay Cue-link copy emits one CommonMark/GFM-compatible plain-text
fragment in the form `[Cue text](cueseeker://cue?id={CueID})`. The label splits
LF, CRLF, CR, and Unicode line breaks, trims horizontal whitespace from each
nonempty line, and joins the remaining lines with one ASCII space. It
backslash-escapes `\\`, `[`, `]`, `<`, `>`, `*`, `_`, backtick, `~`, `&`, and
`|`. A label with no visible content becomes `Cue #{CueID}`.

## Packaging and Verification

The packaged `Info.plist` must declare the final bundle identifier and one URL
type containing the `cueseeker` scheme. Bundle verification must fail when
either value is missing or different.

Parser behavior, search-state transitions, Cue lookup and Playlist behavior,
command supersession, and invalid-input no-op behavior require automated tests.
Final acceptance additionally requires both cold and running-state launches
through macOS Launch Services.
