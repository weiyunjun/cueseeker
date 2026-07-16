# Shared Workbench Playback Documentation Alignment

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Align current product, architecture, testing, and E2E documentation with the
implemented shared Workbench Playback Feature model. Historical engineering
records remain unchanged.

## Changes

1. Defined Search, Shiori, Recent, and Library as shared Workbench Feature
   stores hosted by Playback with a capability mask, not Overlay-owned data
   implementations.
2. Replaced obsolete visible-range data-loading language with complete resident
   text collections plus render-only virtualization.
3. Documented shared Search Query/results, temporary empty Filter behavior, and
   Overlay-local state destruction without deleting Feature state.
4. Documented Playback Pointer initialization, Move/Wheel/key behavior, and
   visible-Pointer gating for media-card Hover selection.
5. Replaced the obsolete Focus Ring selection contract with reuse of each
   shared card layout's Hover region and visual.
6. Documented Playback's omission of the Workbench-only `Context` menu item
   while retaining the shared menu host and locked right-click target.
7. Replaced origin-panel close wording with the four-target Playback Return
   Context lifecycle.
8. Updated the E2E procedure to validate the shared Feature state, Pointer and
   menu capability rules, render-only virtualization, and all Return Context
   targets.

## Verification

- `git diff --check` passed.
- Repository search found no remaining current-rule statements that Playback
  Search is independent, a new Overlay Session starts with an empty Search, or
  Playback media selection uses a Focus Ring.
- `docs/human/` is unchanged by this documentation step.

## Outcome

The current documentation now describes one implementation boundary: Workbench
owns Feature data and pipelines; Playback owns only its reviewed host
capabilities, temporary presentation state, Pointer behavior, and Return
Context.
