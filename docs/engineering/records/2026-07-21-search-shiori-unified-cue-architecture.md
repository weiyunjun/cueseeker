# Search And Shiori Unified Cue Architecture

## Requirement

- `docs/human/requirements/20260721-Feature-Search Shiori Unified Cue Architecture And Memory Optimization.md`

## Scope

Unify Search and Shiori around one CueID-keyed content source, reduce Shiori to
relation-owned data, establish default-list persistence for a future multi-list
feature, preserve complete in-memory logical results, and bound heavyweight
table presentation resources.

## Steps

1. Accepted ADR-0014 and documented the unified content, relation, residency,
   and presentation-resource ownership rules.
2. Pending: migrate Shiori persistence to relation-owned fields and a default
   list.
3. Pending: introduce the canonical Cue snapshot and move Shiori, Search, and
   Playback consumers to it.
4. Pending: preserve independent surface state and remove full-collection
   reconstruction during switching.
5. Pending: remove full row payload retention from table measurement caches and
   complete regression verification.

## Verification

- Documentation cross-check against the committed human requirement: passed.
- Implementation and automated regression verification: pending.

## Outcome

In progress.

## Follow-ups

- Multi-list UI, list management, and list switching remain a separate future
  requirement.
