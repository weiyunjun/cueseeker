# Cue-Centric Documentation Alignment

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Align the active AI-maintained product, architecture, database, playback, UX,
and testing rules with the accepted Cue-centric requirement before dependent
schema and application implementation begins.

## Classification

- Product semantics: individual Cue identity for Search, Context, Shiori,
  playback actions, copy, and export.
- Platform UI/UX: optional Cue Group context remains presentation-only.
- Platform integration: unchanged.
- Playback execution: the selected Cue's own start time is the action target.

## Changes

- Reclassified `subtitle_cue_lines` as product-level Cues and
  `subtitle_cue_groups` as derived indexing and optional-context containers.
- Defined Search results and counts as individual matching Cues while allowing
  group aggregate text to remain an FTS recall optimization.
- Defined version-28 Shiori identity and the data-preserving legacy migration.
- Replaced active rules that required Cue Group result, Shiori, Context, or
  playback identity.
- Added required migration, Search, and playback verification coverage.

## Verification

- Searched active product and engineering rules for normative statements that
  require Search results, Shiori, or playback targets to use Cue Groups.
- Confirmed historical implementation records remain unchanged.
- Confirmed the human-owned requirement and UI design are already committed.

## Outcome

The active AI-maintained documentation now supports the accepted Cue-centric
implementation sequence. Cue Group remains available for indexing and optional
presentation context without replacing individual Cue identity.
