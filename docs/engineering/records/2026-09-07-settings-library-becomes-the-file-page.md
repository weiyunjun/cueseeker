# Settings Library becomes the File page

Human-owned documents:

- `docs/human/requirements/20260907-UI-Settings Library Becomes The File Page.md`

## Why

Adding a subtitle folder is the first thing a new reader has to do, and it lived
behind a Settings window, two levels away from the library it feeds. The Library
page even carried an Add Folder button whose only job was to open that window.
The requirement pulls the whole category out into a primary page called File, so
the folders that produce the index sit beside the pages that read it.

Two names had to move for that. File takes the folder glyph, so Library takes a
grid glyph — which is what its page actually is, a grid of folder cards. And the
Library page's own File segment, which shows the indexed tree, becomes Metadata,
leaving the word File to mean the new page.

## What changed

### The File page

A primary page built on the same Workbench Titled Page Layout the other pages
use: title, a paragraph explaining how a video and its subtitles are paired,
the two actions left-aligned under it, the index status, then the root folders.

The status region is conditional rather than empty-by-default: on a profile that
has never indexed, it contributes no height at all and the folder list sits
directly under the buttons. Everything it can say — indexing, indexed with its
counts, failed, removing, removed, plus the startup error and the auxiliary
failures — is what the Settings category said, in the same order.

The database path did not come along. It is a technical detail with no reader
value on a page about folders.

Files: `Library/WorkbenchFileView.swift` (new).

### Confirmation instead of an alert

Removing a folder still asks first, but through the app's own Confirmation
dialog rather than the system alert the Settings category used. A primary page's
confirmation is presented by the window like every other dialog, so it dims and
blocks the window the way the Shiori list deletion already does.

Files: `Library/WorkbenchFileView.swift`.

### Two colour rules

Success had no token: the Settings category painted its checkmark with SwiftUI's
own green, which is neither in the palette nor legible against the surface at the
same weight as the danger red. `--color-success-text` is the existing finished
watch-status green, which puts success and danger at the same lightness.

The Destructive button's icon now carries the danger colour instead of the
neutral secondary. That matches the Destructive menu item, which was already red
in both label and icon. The only other Destructive button in the app is the
Confirmation dialog's, which carries no icon, so nothing else changed on screen.

Files: `Shared/WorkbenchRedesignTokens.swift`,
`Shared/WorkbenchControls/WorkbenchControls.swift`.

### Sidebar and routing

A `file` panel mode between Library and Shiori, the folder glyph on it and a grid
glyph on Library. The page starts no playback, so it resolves to no playback
return context, and it has no second level, so Back stays disabled on it.

The Library page's Add Folder button now selects the File page instead of posting
the show-Settings notification.

Files: `App/WorkbenchLayoutState.swift`, `Workbench/ContentView.swift`,
`Search/SearchView.swift`, `App/AppCoordinator+Playback.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`.

### Settings category removed

The Library category and its sidebar entry are gone and the window opens on Play.
The `settings.library.*` strings stayed as they are: the File page is the only
thing reading them now, and renaming twenty keys across three languages would
have been churn with no reader-visible effect.

`Settings/SettingsLibraryCategory.swift` is now unreferenced. It was left in
place for the owner to remove, along with the `settings.category.library` string
it is the last reader of.

Files: `Settings/SettingsView.swift`.

### Segment rename

`LibraryContentSegment.file` became `.metadata`, with the string key renamed to
match. The accessibility identifier follows the case name, so it is now
`library-segment-metadata`; nothing referenced the old one.

Files: `TableSandbox/WorkbenchTestLibraryView.swift`,
`Resources/*/Localizable.strings`.

## Verification

- `swift build` — clean.
- `swift test` — 1142 tests. The failures are the repository's pre-existing
  environment-dependent set. This was confirmed rather than assumed: the same
  suite was run at `fa350353` with the change stashed, and it failed the same
  tests plus one more (`libraryFolderRemovalAndIndexingRejectEachOther`, 27
  issues at baseline against 24 with the change). No test regressed.
- `plutil -lint` on the three `Localizable.strings` files, plus a key-set
  comparison: the three languages carry identical keys, the three new keys are
  present and `library.segment.file` is gone.

Debug in-app E2E against the running App, main window `1445 × 821`, using the
existing `click`, `keyPress` and `capture` commands. No E2E command or test
facility was added.

- **Sidebar.** Search, Recent with its two children, Library on the grid glyph,
  File on the folder glyph, Shiori, Settings. Clicking File opens the page.
- **File page.** Title, description, Add Folder and Index Now left-aligned under
  it, then the two root folders with their paths and a red Remove. The status
  region contributed no height before the first index of the session.
- **Index Now.** The status appeared in place — `Indexed 2 folder(s)` in the new
  success colour with the counts under it — and the folder list moved down by
  exactly that block.
- **Remove.** The Confirmation dialog opened over a dimmed window naming the
  folder; Esc cancelled it and both folders stayed. The dialog's own Destructive
  button is unchanged.
- **Library.** The segments read Video and Metadata, Video selected, the grid
  unchanged. Add Folder jumped to the File page.
- **Settings.** The window opens on Play and lists Appearance, Search, Language,
  Deep Link, Decode, Maintenance and Developer. Library is gone.
- **Dark.** The File page was checked in Dark — success green, danger red,
  dividers and the two text ramps all read correctly — and returned to Light.

The three languages were verified as string data rather than on screen: the
language selector is a native popup whose menu is not part of the captured
CueSeeker window scene, so switching it is outside what the E2E controller
covers. This is a known gap, not a new one; no facility was added for it.

Outcome matched expectations.
