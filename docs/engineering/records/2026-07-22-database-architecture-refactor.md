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

### 2. Schema 33 Compatibility Baseline

- Replaced the historical incremental migration path with one atomic schema-33
  creation transaction for empty databases.
- Made schema 33 validation idempotent and non-mutating.
- Added an explicit unsupported-version error for schema versions 1 through 32
  and versions newer than 33; rejection leaves `user_version` unchanged.
- Removed obsolete migration helpers, compatibility tests, and old-version test
  fixtures now that pre-33 databases are intentionally unsupported.

## Verification

### Step 1

- Reviewed the committed human-owned requirement.
- Checked the proposal against the shared-core boundary and minimum sufficient
  design rules.
- Checked that this step changes documentation only and does not alter schema,
  source code, or runtime behavior.

### Step 2

- Ran the six focused schema-baseline tests covering fresh creation, current
  schema idempotence, lower/higher version rejection, and Shiori schema/index
  creation; all passed.
- Ran the complete 829-test Swift suite. Database coverage passed; one unrelated
  shared-preferences migration assertion failed in the combined run and passed
  immediately when rerun in isolation.
- Ran `git diff --check`; no whitespace errors were reported.

## Outcome

Steps 1 and 2 match the requirement. The runtime now treats schema 33 as its
only supported existing database version, and the removed compatibility path
reduces the database implementation and its tests before domain extraction.

## Follow-ups

- Extract connection/bootstrap ownership and focused domain persistence APIs.
- Record each subsequent implementation and verification step in this file.
