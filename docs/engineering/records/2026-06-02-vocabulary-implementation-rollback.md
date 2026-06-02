# Vocabulary Implementation Rollback

Date: 2026-06-02

Human-owned document:

- `docs/human/requirements/archive/20260601-Feature-Vocabulary.md`

## Request

The human-owned vocabulary requirement was marked as canceled and archived.
The implementation should return to the state before the vocabulary feature
implementation was applied on `main`, while preserving the archived requirement
document for historical traceability.

## Steps

- Reverted the vocabulary implementation commits from `3f6f2b6` through
  `8e1f2be` as one staged rollback change.
- Removed vocabulary persistence, topbar entry points, editor UI, list/detail
  UI, Shiori-derived examples, playback wiring, and related tests introduced by
  those commits.
- Removed the superseded vocabulary implementation records that described the
  canceled implementation path.
- Added this rollback record to document the cancellation-driven implementation
  rollback.

## Verification

- `swift test` from `apps/macos-native` passed.

## Outcome

The vocabulary implementation rollback was applied successfully, and the
macOS native test suite passed after the rollback.
