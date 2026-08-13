# Requirement

- `docs/human/requirements/20260813-Feature-Library Detail Shared Cover Summary.md`
- `docs/human/design/UI Design System.md`

# Scope

Generalize the existing Shiori detail Cover Summary into one constrained shared
component and add it above the Library Folder Detail Episode Grid. Reuse the
existing Recent and playback paths without changing persistence, query order,
validity rules, or playback execution.

# Architecture

- Platform UI/UX: shared Cover Summary content variants, action labels, cover
  crop, and Library detail layout.
- Application orchestration: Library Resume calls the existing Recent Videos
  action; Library Play prepares the existing folder navigation scope and opens
  its first current Episode.
- Product semantics, persistence, and playback execution remain unchanged.

# Steps

1. Replaced the Shiori-specific description field with constrained description
   and two-line metadata variants while retaining one shared typography,
   spacing, scrim, sizing, and button implementation.
2. Centralized the Cover Summary Play and Resume labels in the shared
   component and migrated Shiori without changing its recent-item fallback.
3. Added the Library Folder Detail title, current Episode-derived
   `xx videos yy subtitles` line, full folder path, and action to the same
   Cover Summary component.
4. Kept the Cover Summary and Episode Grid inside the existing single scroll
   view with the same horizontal bounds and existing spacing tokens.
5. Loaded the complete Recent Videos projection on Library entry. A matching
   folder item uses the existing Recent Videos open action; otherwise Play
   prepares the current detail videos and opens the first item. The button uses
   the chosen target's existing file-availability rule for its Disabled state.
6. Reused the existing Library cover loader and aspect-fill renderer with the
   accepted center-crop alignment only for this full-width summary.
7. Added a focused shared-action-label test while retaining the existing
   responsive Cover Summary, crop, Shiori projection, and Library snapshot
   coverage.

# Verification

- `swift test --filter 'CoverSummaryCardTests|LibraryCoverFrameTests|LibraryRouteSnapshotReuseTests|ShioriPresentationTests'`
  passes 19 focused shared-summary, cover-crop, Recent/Library refresh, and
  Shiori projection tests.
- `swift build -c release --product CueSeeker`
  succeeds.
- The documented Debug in-app E2E flow passes in the real 1433 × 821-point,
  2× Light Mode window. The current `Ave Mujica` detail shows `13 videos 13
  subtitles`, `/Volumes/Samsung/影视/Ave Mujica`, and Resume over its current
  folder cover. The named detail and scrolled captures verify center-crop fill,
  shared horizontal bounds, and one page scroll context; no playback action was
  activated and the starting Shiori route was restored.
- `git diff --check`
  passes.

# Outcome

Shiori and Library Folder Detail now use one adaptive Cover Summary. Library
derives all displayed folder metadata and the Play target from its current
detail projection, while Resume remains identical to opening that folder's
current Recent Videos item.

# Follow-up

- Final Dark Mode and additional resize acceptance remains with the owner; the
  implementation run covered Light Mode and scrolling at the standard window.
- After acceptance, the human owner will update
  `docs/human/design/UI Design System.md` with the finalized shared variants
  and Library layout.
