# Documentation Rules

Status: Draft

## 1. Purpose

This document defines documentation rules for CueSeeker.

It expands the documentation governance rules from `docs/engineering/00_project_governance.md` and should be followed before implementation relies on product or engineering decisions.

## 2. Documentation Principles

Project documentation must make decisions explicit before they become implementation assumptions.

Principles:

- Documentation comes before major implementation.
- Stable product behavior belongs in product documents.
- Stable engineering behavior belongs in engineering documents.
- Exploratory ideas belong in proposals.
- Hard-to-reverse decisions belong in ADRs.
- Changelog entries record milestone-level progress.
- All project documentation must be written in English.

## 3. Documentation Language

All documentation files under `docs/` must be written in English.

This applies to:

- Product documents.
- Engineering documents.
- Proposals.
- Architecture Decision Records.
- Changelog entries.
- Release notes.

Chinese may appear only when it is part of:

- A literal UI string being discussed.
- User-facing copy that must remain in Chinese.
- An external title or quoted source.
- A necessary example where translation would change meaning.

## 4. Documentation Structure

The active documentation structure is:

```text
docs/
  product/
  engineering/
  proposals/
  decisions/
  changelog.md
```

Rules:

- `docs/product/` records stable product facts.
- `docs/engineering/` records stable engineering rules.
- `docs/proposals/` records proposed changes before acceptance.
- `docs/decisions/` records ADRs.
- `docs/changelog.md` records milestone-level progress.

## 5. Product Documents

Product documents describe confirmed product behavior and user-facing expectations.

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
- Stable user-facing behavior must be reflected in product documents before implementation depends on it.

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
```

Rules:

- `00_project_governance.md` is the top-level governance document.
- Detailed rules should live in the dedicated engineering document for that topic.
- When detailed rules and the governance summary disagree, the disagreement must be resolved before implementation depends on either rule.
- Engineering documents should define constraints and process, not implementation code.

## 7. Proposals

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

- Accepted proposal conclusions must be merged into the relevant product or engineering documents.
- Rejected or superseded proposals should remain as historical context.
- Implementation should not depend on proposal text that has not been accepted.

## 8. Architecture Decision Records

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
- ADRs do not replace product or engineering documents; stable conclusions must be reflected in the relevant rules.

## 9. Changelog

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

## 10. Change Process

Small documentation changes may directly update stable documents.

Examples:

- Text refinements.
- Minor clarification.
- Formatting cleanup.
- Acceptance criteria clarification.

Medium and large changes require a proposal or ADR first.

Examples:

- New feature modules.
- Core workflow changes.
- Data model changes.
- Playback strategy changes.
- Indexing strategy changes.
- Security or credential storage changes.

Required flow for significant changes:

```text
Create proposal or ADR
Review the decision
Merge stable conclusions into product or engineering docs
Implement
Verify
Evaluate changelog trigger and update when required
Commit changes
```

## 11. Review Rule

Documentation that defines process, product scope, data structure, playback behavior, architecture, testing, or release behavior must be reviewed before implementation depends on it.

Rules:

- Draft documents may guide discussion.
- Draft documents are not final project rules until accepted.
- If implementation must diverge from documentation, update the documentation first or create a proposal or ADR.
