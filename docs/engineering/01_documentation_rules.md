# Documentation Rules

Status: Draft

## 1. Purpose

This document defines documentation rules for CueSeeker.

It expands the documentation governance rules from `docs/engineering/00_project_governance.md` and should be followed before implementation relies on product or engineering decisions.

## 2. Documentation Principles

Project documentation must make decisions explicit before they become implementation assumptions.

Principles:

- Documentation comes before major implementation when project-specific
  meaning, workflow, constraints, or ambiguity must be settled.
- Stable product meaning and accepted workflows belong primarily in
  human-owned design documents.
- Every new change request requires a human-owned requirement document; when
  stable design already exists, the requirement should reference it and record
  only the requested delta.
- Stable engineering behavior belongs in engineering documents.
- Exploratory ideas belong in proposals.
- Hard-to-reverse decisions belong in ADRs.
- Changelog entries record milestone-level progress.
- AI-maintained documentation outside `docs/human/` must be written in English.

## 3. Documentation Language

AI-maintained documentation files outside `docs/human/` must be written in
English.

This applies to:

- Product documents.
- Engineering documents.
- Implementation records.
- Proposals.
- Architecture Decision Records.
- Chronicle entries.
- Changelog entries.
- Release notes.

Human-owned documents under `docs/human/` may use the human owner's chosen
language. The AI must not edit them.

Chinese may appear only when it is part of:

- A literal UI string being discussed.
- User-facing copy that must remain in Chinese.
- An external title or quoted source.
- A necessary example where translation would change meaning.

## 4. Documentation Structure

The active documentation structure is:

```text
docs/
  human/
    requirements/
    design/
  product/
  engineering/
    records/
  proposals/
  decisions/
  chronicle/
  changelog.md
```

Rules:

- `docs/human/design/` is the primary human-owned source for stable product
  meaning, accepted workflows, and design decisions.
- `docs/human/requirements/` records each new change or implementation request.
- `docs/product/` records AI-maintained product facts derived from and aligned
  with human-owned documents.
- `docs/engineering/` records stable engineering rules.
- `docs/engineering/records/` records AI implementation process notes for
  accepted work outside `docs/human/`.
- `docs/proposals/` records proposed changes before acceptance.
- `docs/decisions/` records ADRs.
- `docs/chronicle/` records reasoning provenance for explicitly started
  Socratic architecture alignment sessions.
- `docs/changelog.md` records milestone-level progress.

### 4.1 Human-Owned Design and Requirements

Human-owned design documents exist to align requirements, make workflows
explicit, and remove ambiguity that could cause incompatible implementation.

Rules:

- A new change request must have its own committed requirement document even
  when the requested behavior is already described in `docs/human/design/`.
- The requirement should cite the relevant design document or section and
  focus on the requested delta, execution scope, and acceptance criteria.
- Design documents should record project-specific outcomes, decisions,
  constraints, workflows, edge cases, and unresolved ambiguity.
- Commonplace implementation details with a clear, broadly accepted practice
  need documentation only when CueSeeker has a specific constraint, deviation,
  risk, or acceptance condition.
- Documentation depth should be proportional to decision risk and ambiguity.
  Do not turn stable design into an implementation tutorial or paper when a
  shorter statement can guide implementation and review.
- Iterative implementation and verification are valid ways to discover detail.
  When they change accepted product meaning or workflow, the human-owned design
  and current requirement must be updated before dependent work continues.

## 5. Product Documents

Product documents are AI-maintained descriptions of confirmed product behavior
and user-facing expectations. They are derived views, not a stronger authority
than `docs/human/`.

Product documents should cover:

- Product direction.
- Scope and milestones.
- Functional requirements.
- UI design.
- UX interaction.
- Data model facts.
- Playback requirements.
- Non-goals.

Rules:

- Product documents must not be used as temporary discussion notes.
- Product documents must not hide engineering constraints that belong in engineering rules.
- Stable user-facing behavior must first be covered by the current requirement
  and relevant human-owned design. Product documents must remain aligned when
  they describe the same behavior.

## 6. Engineering Documents

Engineering documents define how the product is built, tested, changed, and released.

The formal engineering document set is:

```text
docs/engineering/
  00_project_governance.md
  01_documentation_rules.md
  02_git_workflow.md
  03_repository_structure.md
  04_architecture_rules.md
  05_database_rules.md
  06_testing_rules.md
  07_release_rules.md
  08_end_to_end_testing.md
  records/
```

Rules:

- `00_project_governance.md` is the top-level governance document.
- Detailed rules should live in the dedicated engineering document for that topic.
- When detailed rules and the governance summary disagree, the disagreement must be resolved before implementation depends on either rule.
- Engineering documents should define constraints and process, not implementation code.
- `docs/engineering/records/` is not a rule source. It records how an
  accepted change was carried out, what was verified, and whether the result
  matched the expected outcome.

## 7. Implementation Records

Use an implementation record when the AI carries out an accepted change outside
`docs/human/`.

Naming format:

```text
docs/engineering/records/YYYY-MM-DD-topic-name.md
```

Recommended sections:

```text
Requirement
Scope
Steps
Verification
Outcome
Follow-ups
```

Rules:

- Each AI-performed change outside `docs/human/` must create or update one
  implementation record.
- The record must cite the current human-owned requirement and any human-owned
  design document it references.
- The record should state each meaningful step, what was changed, what was
  checked, and whether the result matched the expected outcome.
- Implementation records do not replace human-owned requirements, product or
  engineering documents, Git history, tests, or changelog entries.
- Implementation records must not be created under `docs/human/`.

## 8. Proposals

Use a proposal when a change is significant but not yet accepted as stable project direction.

Create a proposal for changes that:

- Add a significant feature.
- Change a core user flow.
- Change the database structure.
- Replace or significantly change playback, indexing, storage, or networking.
- Introduce a new external service.
- Introduce a new macOS system capability with user-visible or release impact.

Naming format:

```text
docs/proposals/YYYY-MM-topic-name.md
```

Recommended proposal sections:

```text
Background
Goals
Non-goals
User flow
UI/UX impact
Data model impact
Technical risk
Acceptance criteria
Decision
```

Rules:

- Accepted product conclusions must be reflected in the relevant human-owned
  design by the human owner and aligned into any derived product documents.
- Accepted engineering conclusions must be merged into the relevant
  engineering documents.
- Rejected or superseded proposals should remain as historical context.
- Implementation should not depend on proposal text that has not been accepted.

## 9. Architecture Decision Records

Use an ADR for major decisions that are expensive to reverse.

Naming format:

```text
docs/decisions/ADR-0001-topic-name.md
```

Use an ADR for decisions such as:

- Native macOS rewrite direction.
- Playback engine selection.
- Sandboxing strategy.
- Signing and notarization strategy.
- Direct compatibility with the archived Flutter database.
- Major schema changes.
- Raising the minimum supported macOS version.

Recommended ADR sections:

```text
Background
Decision
Rationale
Tradeoffs
Alternatives considered
Status
```

Rules:

- ADRs should state the selected decision and why alternatives were not chosen.
- ADRs should be updated or superseded when decisions change.
- ADRs do not replace human-owned design, product, or engineering documents;
  stable conclusions must be reflected in the relevant authority and derived
  rules.

## 10. Chronicle

Use a chronicle entry when an explicitly started Socratic architecture alignment
session produces a meaningful implementation idea, architecture concern,
engineering rule candidate, or proposal direction.

Naming format:

```text
docs/chronicle/YYYY-MM-DD-topic-name.md
```

Recommended sections:

```text
Context
Question Path
Evidence Surfaced
Emerging Insight
Open Questions
Next Update Trigger
```

Rules:

- Chronicle entries apply only to explicitly started Socratic architecture
  alignment sessions.
- Chronicle entries should emphasize why an idea emerged from the question
  path, not list every implementation detail.
- Chronicle entries may be updated as the same Socratic session continues,
  especially when the user explicitly asks for the process record to be
  updated.
- Chronicle entries do not authorize implementation by themselves.
- When a chronicle insight becomes accepted project direction, stable
  conclusions must still move into the relevant product, engineering, proposal,
  ADR, or changelog document.

## 11. Changelog

`docs/changelog.md` records milestone-level progress and user-visible project changes.

Rules:

- The changelog does not replace Git history.
- Git records concrete file changes.
- The changelog records meaningful progress and milestone outcomes.
- Each completed milestone must update the changelog.
- Update the changelog when a milestone is completed, paused, resumed, renamed, or its acceptance status changes.
- Update the changelog when a change affects user-visible behavior, core workflows, product scope, or documented acceptance criteria.
- Update the changelog when an architecture decision, engineering process rule, release rule, database schema rule, sandboxing rule, or other stable project rule is accepted or materially changed.
- Update the changelog when preparing a formal release, tagged milestone, or release candidate.
- Update the changelog when a group of small commits has accumulated into meaningful product or engineering progress.
- Do not add changelog entries for formatting-only edits, wording cleanup that does not change meaning, internal refactors with no behavior or rule impact, test-only maintenance, or transient work in progress.
- Changelog entries should summarize outcomes, not implementation details or individual commits.
- Changelog entries belong in `Unreleased` until a formal release section exists.

## 12. Change Process

Every new change outside `docs/human/` must be covered by its own committed
human-owned requirement before it is made. Stable design documents provide the
authoritative behavior and workflow context but do not replace the requirement
for the current change.

Small documentation changes may directly update stable documents when their
current human-owned requirement is already committed.

Examples:

- Text refinements.
- Minor clarification.
- Formatting cleanup.
- Acceptance criteria clarification.

Medium and large changes require a proposal only when the direction remains
unsettled, and an ADR only when the decision is expensive or hard to reverse.
A stable human-owned design should be referenced instead of duplicated in an
extra proposal.

Examples:

- New feature modules.
- Core workflow changes.
- Data model changes.
- Playback strategy changes.
- Indexing strategy changes.
- Security or credential storage changes.

Required flow for significant changes:

```text
Create the current human-owned requirement and reference or update design
Commit the human-owned requirement and any required design update
Create proposal or ADR when required
Review the decision
Align stable conclusions into human-owned design, product, or engineering docs
Implement
Verify
Update the implementation record
Evaluate changelog trigger and update when required
Commit changes with the relevant human-owned document path in the commit message
```

## 13. Review Rule

Documentation that defines process, product scope, data structure, playback behavior, architecture, testing, or release behavior must be reviewed before implementation depends on it.

Rules:

- Draft documents may guide discussion.
- Draft documents are not final project rules until accepted.
- If implementation must diverge from documentation, update the documentation first or create a proposal or ADR.
