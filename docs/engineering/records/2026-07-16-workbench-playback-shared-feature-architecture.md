# Workbench And Playback Shared Feature Architecture

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Replace the previous Playback data-window interpretation with explicit
engineering rules for Workbench-owned feature data, shared paging, complete
loaded-result retention, presentation-only virtualization, reviewed
Playback-specific differences, same-commit removal of replaced code, and the
smallest implementation that satisfies the requirement.

## Steps

1. Recorded `SearchStore`, `ShioriStore`, and `LibraryStore` as the authoritative
   owners used by both Workbench and Playback.
2. Kept paging and batching available through the existing Workbench Feature
   Store pipelines while prohibiting a second Playback paging or window cache.
3. Separated complete loaded-result residency from visible-plus-overscan
   rendering, measurement, placement, scrolling, and scrollbar virtualization.
4. Recorded the reviewed allowlist of Playback-specific host differences.
5. Required each feature migration to remove its replaced Playback data path in
   the same commit and prohibited compatibility, shadow, and speculative
   abstraction layers.

## Verification

- Compared the architecture rules with the committed human-owned requirement.
- Confirmed that the rules preserve existing Workbench paging rather than
  prohibiting pagination.
- Confirmed that the Playback exception list contains only the differences
  reviewed by the project owner.
- `git diff --check` passed.

## Outcome

The engineering boundary now treats Playback as a presentation host over
Workbench-owned feature data. Paging remains reusable, complete loaded text is
not reduced to a Playback window, and implementation may proceed feature by
feature without preserving the replaced parallel architecture.

## Follow-Ups

- Migrate Search and Search-origin Playlist data first.
- Migrate Shiori.
- Migrate Recent and Library.
- Remove the remaining obsolete Playback window infrastructure after its final
  live consumer is migrated.
