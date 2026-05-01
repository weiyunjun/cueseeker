# ADR-0008: Project Rename to CueSeeker

Status: Accepted

## Background

The project started under the predecessor name `SubFinderX`.
That name described the original subtitle search prototype, but the product
direction has expanded toward subtitle-powered context review, playback
navigation, favorites, dynamic lists, and future phrase discovery.

The old name also carried a temporary prototype tone. The project needs a
clearer public identity before open-source publication, potential App Store
distribution, or future iPadOS planning.

## Decision

The active project name is `CueSeeker`.

The Chinese product name is `字幕求索`.

The legacy Flutter implementation under `archive/flutter/` keeps its historical
name and identifiers. It remains an archived reference implementation and should
not be renamed as part of the active project identity change.

## Rationale

`CueSeeker` preserves the idea of search and timestamp seeking while using
`cue`, a domain-relevant term for timed subtitle entries. The name better fits a
tool that finds a line, jumps to the matching media moment, and helps users
collect or review subtitle-backed context.

Keeping the archived Flutter name unchanged makes historical comparison easier
and avoids unnecessary churn in inactive code.

## Tradeoffs

- Existing local development data paths may change from the previous app name
  to `CueSeeker`.
- Documentation and module names need a coordinated rename so new contributors
  do not see mixed active product identities.
- Historical ADRs and proposals may still describe old implementation context,
  but active project references should use `CueSeeker`.

## Alternatives Considered

- Keep `SubFinderX`: rejected because it reads as a prototype search utility and
  does not fit the broader learning and playback workflow direction.
- Use `Subnifier`: rejected because the intended `subtitle + signifier`
  construction is not immediately readable and is harder to pronounce.
- Use `SubSeeker`: rejected because similar names are common and the `Sub`
  prefix is overloaded.
