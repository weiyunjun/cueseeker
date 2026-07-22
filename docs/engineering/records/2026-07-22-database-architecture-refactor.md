# Database Architecture Refactor

## Human-Owned Source

- `docs/human/requirements/20260722-Engineering-Subtitle Database Refactor And Schema 33 Baseline.md`

## Scope

Decompose the cross-domain `SubtitleDatabase` implementation while preserving
the schema-33 data layout and current product behavior. Retire compatibility
with native schema versions 1 through 32, establish explicit connection and
transaction ownership, move callers onto focused database-domain boundaries,
and remove the old God Object without a permanent forwarding facade.

## Steps

### 1. Accepted Engineering Direction

- Added the accepted database architecture decomposition proposal.
- Recorded schema 33 as the current and minimum supported native schema.
- Defined unsupported lower and higher schema behavior without silent deletion
  or version downgrading.
- Added stable architecture rules for bootstrap-only migration, serialized
  write ownership, read-only feature access, domain-specific persistence
  boundaries, and removal of the old facade.
- Recorded the accepted direction in the Unreleased changelog.

## Verification

### Step 1

- Reviewed the committed human-owned requirement.
- Checked the proposal against the shared-core boundary and minimum sufficient
  design rules.
- Checked that this step changes documentation only and does not alter schema,
  source code, or runtime behavior.

## Outcome

Step 1 matches the requirement. Implementation may proceed from schema 33 using
the staged boundaries in the accepted proposal.

## Follow-ups

- Replace historical migration behavior with schema-33 creation and validation.
- Record each subsequent implementation and verification step in this file.
