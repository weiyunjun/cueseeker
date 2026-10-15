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
  human-owned design documents under `docs/human/design/`.
- Every new change request requires a human-owned requirement document under
  `docs/human/requirements/`; when stable design already exists, the
  requirement should reference it and record only the requested delta.
- Stable engineering behavior belongs in engineering documents under
  `docs/engineering/`.
- Changelog entries record milestone-level progress.
- AI-maintained documentation outside `docs/human/` must be written in English.

## 3. Documentation Language

AI-maintained documentation files outside `docs/human/` must be written in
English.

This applies to:

- Engineering documents.
- Implementation records.
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
      Design Index.md
      ui/
      data/
      workbench/
      playback/
  engineering/
    records/
  changelog.md
```

Rules:

- `docs/human/design/` is the primary human-owned source for stable product
  meaning, accepted workflows, UI design rules, component/layout specifications,
  and design decisions. `docs/human/design/Design Index.md` is the root routing
  index across the four domains (`ui/`, `data/`, `workbench/`, `playback/`),
  and `docs/human/design/ui/UI Index.md` indexes all UI components (`C-xx`) and
  layouts (`L-xx`).
- `docs/human/requirements/` records each new change or implementation request.
- `docs/engineering/` records stable engineering rules.
- `docs/engineering/records/` records AI implementation process notes for
  accepted work outside `docs/human/`.
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
- When working on UI tasks, the AI should use `docs/human/design/ui/UI Index.md`
  to read `UI Design Rules.md` and `UI Interaction Rules.md` first, and then
  load only the relevant component (`C-xx`), layout (`L-xx`), or token files on
  demand.

## 5. Engineering Documents

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

## 6. Implementation Records

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
- Implementation records do not replace human-owned requirements, design or
  engineering documents, Git history, tests, or changelog entries.
- Implementation records must not be created under `docs/human/`.

## 7. Changelog

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

## 8. Change Process

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

Required flow for changes:

```text
Create the current human-owned requirement and reference or update design
Commit the human-owned requirement and any required design update
Align stable engineering conclusions into engineering docs when required
Implement
Verify
Update the implementation record
Evaluate changelog trigger and update when required
Commit changes with the relevant human-owned document path in the commit message
```

## 9. Review Rule

Documentation that defines process, product scope, data structure, playback behavior, architecture, testing, or release behavior must be reviewed before implementation depends on it.

Rules:

- Draft documents may guide discussion.
- Draft documents are not final project rules until accepted.
- If implementation must diverge from documentation, update the documentation first.
