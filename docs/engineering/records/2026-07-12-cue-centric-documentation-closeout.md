# Cue-Centric Documentation Closeout

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Complete the final active-document audit after the Cue-centric database,
Search, Shiori, Context, export/copy, Playback Subtitle Focus, native table, and
refresh-scope implementation phases. Remove the remaining active conflicts with
the former grouped-card and fixed-height Focus designs without changing the
human-owned documents.

## Classification

- Documentation alignment only: no production or test code changes.
- Product semantics: individual Cue identity remains authoritative.
- UI/UX: Search, Shiori, and Context use the shared native dynamic Cue table;
  Playback Subtitle Focus uses the native dynamic Cue reel.
- Historical preservation: retired grouped-card material may remain only when
  explicitly marked Legacy or Superseded and non-normative.

## Changes

- Added the complete Cue-centric milestone at the top of `docs/changelog.md`,
  explicitly superseding older grouped-card, group-header export, and fixed
  Focus descriptions.
- Aligned `docs/product/01_scope_and_milestones.md`,
  `02_functional_requirements.md`, `03_ui_design.md`,
  `04_ux_interaction.md`, `05_data_model.md`,
  `06_playback_requirements.md`, and `08_search_interface_llm_brief.md` with
  individual-Cue Search/Shiori/Context identity, Cue-based export/copy, dynamic
  table geometry, Show Cue Group presentation, and dynamic Subtitle Focus.
- Aligned `docs/product/10_ui_collaboration_workflow.md`,
  `11_liquid_glass_component_mapping.md`, and
  `12_liquid_glass_ux_mapping.md` so native Cue tables and the native Focus reel
  take precedence over the historical HTML grouped-card mappings.
- Updated `docs/engineering/04_architecture_rules.md`,
  `06_testing_rules.md`, and `08_end_to_end_testing.md` with the Cue-table and
  Focus architecture, Japanese-first Shiori migration rule, exact geometry,
  accepted placement, visible-plus-overscan work, stable anchors, and refresh
  isolation.
- Appended a correction to the first documentation-alignment record and closed
  the Phase 4D follow-up in the table-UI record. The earlier claims are retained
  as history but no longer imply that the then-unreviewed mapping documents
  were already aligned.

## Requirement Closure

1. Search, Shiori, Context, Playback Subtitle Focus, copy, and export use stable
   individual-Cue identity; Cue Group remains derived optional context.
2. Search defaults to the matching primary Cue only.
3. Shiori records and tags belong to one Cue; legacy migration prefers a
   Japanese Cue and then the physically bottommost eligible Cue.
4. Context uses the primary Cue and the shared Cue table.
5. Anki, Screenshot, Collage, Copy Cue Text, and Context targets are Cue-based;
   Collage keeps only the same-subtitle-file constraint and its renderer is
   unchanged.
6. The persistent native Show Cue Group switch defaults Off, adds secondary
   context above the primary Cue, preserves shared interaction, and exposes
   Copy Cue Group Text only while On.
7. Search, Shiori, and Context show all source and wrapped text with
   `max(40, 16 + 24P + 20S)` dynamic rows and stable-anchor reflow.
8. Playback Subtitle Focus presents one Cue per item, applies the documented
   initial-selection fallbacks, measures `52L + 24`, centers fitting Cues,
   top-aligns oversized Cues, and targets the exact settled Cue for `S`, `C`,
   and Space.
9. The detailed human UI contract is represented by the active product,
   architecture, testing, E2E, and component/UX mapping documents.

## Verification

- Independent read-only code and test audit found no implementation gap across
  requirements 1–9 and found direct production/test coverage for all six
  Playback Subtitle Focus subrequirements.
- Confirmed Screenshot and Collage renderer/composition paths were not changed;
  Collage eligibility uses standardized subtitle path and does not add a
  separate video-path constraint.
- Searched active documents for obsolete Cue Group action targets, group-header
  exports, fixed Focus heights, and current grouped-card/Collapse All rules.
  Remaining occurrences are either Library-specific or explicitly marked
  Legacy/Superseded.
- Confirmed `docs/human/` has no worktree changes.
- `swift test --quiet` passed 548 Swift Testing tests and 7 XCTest tests with no
  failures.
- `swift build --quiet` passed.
- `git diff --check` passed.

## Outcome

Requirements 1–9 are implemented, tested, traceable to the two human-owned
sources, and represented consistently across active AI-maintained documents.
Historical grouped-card material remains available only as clearly superseded
context and cannot override the current Cue-centric native behavior.
