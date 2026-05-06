# Friendly Search Result Group Titles

Status: Accepted

## Background

CueSeeker currently groups Search results by subtitle file and displays the
source subtitle filename in each group header.

Many anime and subtitle release filenames are long because they include release
group names, source tags, codec tags, language tags, resolution, and other
technical metadata. These filenames are useful for file identity, but they make
the Search result list harder to scan.

The user's local folder name is often a better human-readable work title. For
example, a folder named `葬送的芙莉莲` may contain long subtitle filenames such
as `[Nekomoe kissaten&VCB-Studio] Sousou no Frieren [05][Ma10p_1080p][x265_flac].JPSC.ass`.
In the Search result list, the user mainly needs to recognize the work and
episode order, not the full release filename.

## Goals

- Make Search result group headers significantly easier to read for long
  subtitle filenames.
- Let the user control the displayed work title by renaming the parent folder.
- Preserve source subtitle filenames and paths for identity, playback, and
  diagnostics.
- Derive a stable episode-like sequence number from the subtitle file's natural
  order within its immediate parent folder.
- Match macOS Finder-like natural filename sorting, including numeric ordering
  where `aa2.ass` sorts before `aa11.ass`.
- Avoid changing subtitle files or media files on disk.

## Non-goals

- Renaming subtitle files.
- Renaming video files.
- Parsing episode numbers from release filenames.
- Inferring season, episode, language, release group, or edition metadata from
  filenames.
- Changing subtitle-to-video matching.
- Changing search ranking or FTS behavior.
- Adding a manual title editor in this step.
- Adding a database schema change unless implementation evidence later proves
  that a derived cache is needed.

## User Flow

The expected workflow is:

```text
User organizes subtitle files inside a work folder
User names the parent folder with a readable work title
CueSeeker indexes or searches the selected folder
Search result group headers show "Parent Folder - Sequence"
User can still inspect the full subtitle path in the Playback Inspector
```

Example:

```text
Parent folder:
葬送的芙莉莲

Subtitle file:
[Nekomoe kissaten&VCB-Studio] Sousou no Frieren [05][Ma10p_1080p][x265_flac].JPSC.ass

Friendly Search group title:
葬送的芙莉莲 - 05
```

## UI/UX Impact

Search result group headers should display a friendly title instead of the raw
subtitle filename when the title can be derived.

The friendly title format is:

```text
Parent Folder Name - NN
```

Rules:

- `Parent Folder Name` is the immediate parent folder's last path component.
- `NN` is the subtitle file's one-based rank among visible regular sibling
  subtitle files that share the same final subtitle extension.
- The rank should be zero-padded to at least two digits.
- If the sibling set has 100 or more files, the padding width should expand to
  the digit count of the sibling count.
- Sorting for rank derivation should use macOS Finder-like localized standard
  comparison.
- Numeric runs in filenames should sort by numeric value, so `aa2.ass` comes
  before `aa11.ass`.
- The rank scope is the immediate parent directory, not recursive descendants.
- `.srt` and `.ass` files are ranked independently because they have different
  final subtitle extensions.
- If the friendly title cannot be derived, the app should fall back to the
  subtitle filename currently used by Search result group headers.

The group header should continue to append the per-file result count as plain
text after the display title, separated by two spaces:

```text
葬送的芙莉莲 - 05  3 results
葬送的芙莉莲 - 05  1 result
```

The Playback Inspector should continue to show the full subtitle path so the
user can inspect the exact source file when needed.

## Data Model Impact

No database schema change is required for the initial implementation.

The source subtitle path remains the stable identity for:

- Search result grouping.
- Search result selection.
- Playback source resolution.
- Subtitle-to-video matching.
- Diagnostics.

The friendly title is a derived display projection. It may be computed from the
subtitle path and sibling filesystem state at result presentation time, or from
derived metadata produced during indexing. If future performance evidence
requires caching this projection in SQLite, that cache should be treated as
rebuildable derived index data, not durable user-authored data.

## Technical Risk

Risks:

- Filesystem sibling reads can fail if the parent directory is unavailable,
  moved, or permission-restricted after indexing.
- Sibling files that are not indexed but share the same final subtitle extension
  can affect the derived rank, because the rank intentionally follows folder
  organization rather than search-result membership.
- Locale-aware natural sorting may vary slightly by the user's current macOS
  locale or future OS behavior.
- A folder that mixes main episodes, specials, NCOP/NCED files, or alternate
  subtitle tracks in the same extension may produce ranks that reflect the
  folder's natural order rather than semantic episode numbers.

Mitigations:

- Fall back to the raw subtitle filename when the friendly title cannot be
  derived.
- Keep the full subtitle path visible in the Playback Inspector.
- Document that users can adjust displayed work titles by renaming parent
  folders and can adjust sequence order by organizing or renaming sibling
  subtitle files.
- Use the platform's Finder-like comparison API instead of a project-owned
  ad-hoc natural-sort parser on macOS.

## Acceptance Criteria

- A subtitle file under a parent folder named `葬送的芙莉莲` can display a Search
  result group title such as `葬送的芙莉莲 - 05`.
- The displayed work title comes from the immediate parent folder name.
- The displayed sequence number is one-based.
- The sequence number is derived from visible regular sibling subtitle files
  with the same final subtitle extension.
- The sequence number is padded to at least two digits.
- Finder-like natural sorting is used for sibling ordering.
- `aa2.ass` sorts before `aa11.ass` for rank derivation.
- `.srt` and `.ass` siblings are ranked separately.
- Raw subtitle filenames and paths remain available for identity, playback, and
  diagnostics.
- Search grouping identity remains based on subtitle path, not the friendly
  display title.
- If derivation fails, Search falls back to the raw subtitle filename.
- Automated tests cover friendly title derivation, numeric natural ordering,
  padding width, extension scoping, fallback behavior, and Chinese parent folder
  names.

## Decision

Accepted.

Search result group headers should move from raw subtitle filename display to a
friendly derived title based on the immediate parent folder name and the
subtitle file's Finder-like natural sort rank among same-extension sibling
subtitle files.

This change is display-only. It must not rename user files, change subtitle
matching, change search ranking, or replace source paths as the app's stable
identity.
