# Git Workflow

Status: Draft

## 1. Purpose

This document defines Git workflow rules for CueSeeker.

Git history should preserve meaningful project stages and make active macOS
development reviewable.

## 2. Repository State

The repository has already been initialized for the native rewrite.

Known baseline:

- Baseline commit: `064fa30 Baseline Flutter implementation`
- Baseline tag: `flutter-baseline`
- Archive commit: `b7db6de Archive: move Flutter implementation under archive/flutter`
- Active branch: `main`

Rules:

- The archived Flutter implementation must remain available under `archive/flutter/`.
- Active native macOS work is based on `main`.
- The previous `native-macos-rewrite` branch is retired and must not be used
  for new work.
- The previous `ui/restructure` branch is retired after its accepted work moved
  into `main`; it must not be used for new work.
- Do not rewrite the baseline or archive history.

## 3. Branching Rules

The stable integration branch is:

```text
main
```

Small, tightly scoped changes may be committed directly on `main` when the
owner explicitly asks for the modification and the change is low risk.
Major features, risky UI work, long-lived experiments, and work that benefits
from review isolation should start from `main` on a feature branch.

Feature branch naming:

```text
feature/<short-topic>
```

Examples:

```text
feature/anki-export
feature/search-polish
feature/playback-export
```

Rules:

- Create feature branches from the current `main`.
- Keep feature branch commits small and reviewable.
- Merge or otherwise integrate accepted feature work back to `main` before
  treating it as stable project direction.
- Delete retired or completed local feature branches after their useful work is
  integrated or explicitly abandoned.
- Do not create `git worktree`s or per-session `claude/*` branches for normal
  ongoing development. Any worktrees or `claude/*` branches left by earlier
  tooling are legacy, are not part of the current workflow, and may be removed.
- Do not mix unrelated documentation, architecture, database, UI, and playback changes in one large commit.
- Keep experimental work behind proposals or ADRs before it becomes stable implementation.

## 4. Commit Granularity

Commits should represent understandable project steps.

Recommended commit boundaries:

- Initialize documentation structure.
- Freeze Flutter baseline.
- Archive Flutter implementation.
- Establish engineering rules.
- Create native macOS app shell.
- Implement local subtitle scanning.
- Implement SRT parsing.
- Implement SQLite schema and migrations.
- Implement FTS search.
- Implement local video timestamp playback.
- Implement macOS experience polish.
- Implement Shiori and personal learning flow.

Rules:

- Avoid arbitrary file-batch commits.
- Avoid mixing mechanical formatting with behavior changes.
- Commit documentation changes separately when they define rules for later implementation.
- Tests should be committed with the implementation they verify when practical.

## 5. Commit Message Format

Use concise English commit messages.

Format:

```text
Area: concise change summary
```

Examples:

```text
Docs: add project governance rules
Archive: move Flutter implementation under archive/flutter
Native: add macOS app shell
Search: implement local subtitle FTS query
Playback: add local video seek prototype
```

Rules:

- The area should describe the main change domain.
- The summary should be imperative or descriptive, but concise.
- Do not use vague summaries such as `update`, `fix`, or `changes` by themselves.
- Commit messages must be in English.

## 6. Safety Rules

Destructive Git operations must not be run unless explicitly requested.

Do not run by default:

```bash
git reset --hard
git clean -fd
git checkout -- .
```

Rules:

- Do not discard user changes.
- Do not rewrite shared or meaningful history without explicit approval.
- Before committing, inspect `git status` and include only intended files.
- If unrelated files are modified, leave them untouched unless the user asks otherwise.

## 7. Tag Rules

Tags should mark meaningful project points.

Existing required tag:

```text
flutter-baseline
```

Future tag candidates:

- First native macOS shell.
- M1 minimal local loop.
- M2 macOS experience polish.
- M3 Shiori and personal learning flow.

Rules:

- Use tags for meaningful milestones, not every minor change.
- Release tags must align with `docs/engineering/07_release_rules.md` after release rules are active.
- Do not move existing milestone tags without explicit approval.

## 8. Changelog Relationship

Git commits and changelog entries serve different purposes.

Rules:

- Git records concrete file changes.
- `docs/changelog.md` records milestone-level progress.
- Each completed milestone must update the changelog.
- Small internal commits do not need individual changelog entries unless they change user-visible behavior or milestone status.
- Before committing, check whether the change triggers the changelog rules in `docs/engineering/01_documentation_rules.md`.
- When a changelog update is required, include it in the same commit or change set that completes the milestone, accepts the rule, or prepares the release.
- Multiple related small commits may be represented by one changelog entry when they form a single meaningful outcome.

## 9. Documentation Before Implementation

When a technical or product rule is missing, add or update documentation before relying on implementation assumptions.

Rules:

- Product behavior changes must update product documents.
- Engineering process or architecture changes must update engineering documents.
- Expensive or hard-to-reverse decisions require ADRs.
- Significant proposed changes should start in `docs/proposals/`.

## 10. Implementation Traceability

Every change outside `docs/human/` must be traceable to a human-maintained
requirement document or stabilized design/planning document.

This is a project rule for human ownership and review, not only an AI assistant
rule.

Rules:

- Changes outside `docs/human/` include application source, tests, scripts,
  prototypes, build files, configuration files, product documents, engineering
  documents, proposals, ADRs, changelog entries, and AI-maintained process
  records.
- Before a change outside `docs/human/` is implemented or accepted, the
  responsible human owner must make sure the change is reflected in either a
  requirement document under `docs/human/requirements/` or a design/planning
  document under `docs/human/design/`.
- The covering human-owned document must be committed before the AI modifies
  files outside `docs/human/`. An uncommitted human-owned document may be
  reviewed or discussed, but it does not authorize dependent AI-maintained
  documentation or code changes.
- Requirement documents record historical change or implementation requests.
  Design/planning documents record stabilized product content, expected
  behavior, or the accepted initialization of a new feature.
- If no human-owned requirement or design/planning document covers a requested
  change outside `docs/human/`, the missing document is a process blocker. The
  human owner should create or update the human-owned document before the change
  proceeds.
- When a requirement changes, the human-owned document must be updated before
  dependent AI-maintained documentation or code changes proceed.
- The AI must not satisfy this requirement by editing `docs/human/`. It may
  only report that the required human-owned documentation is missing or propose
  text outside `docs/human/` for the human owner to apply manually.
- Each AI-performed change outside `docs/human/` must create or update an
  implementation record under `docs/engineering/records/` that cites the
  relevant human-owned document and records the steps taken, verification
  performed, and whether the result matched expectations.
- Every commit must include the relevant `docs/human/` document path in the
  commit message. For commits that change only `docs/human/`, cite the
  human-owned document path or paths changed by that commit.

## 11. AI Assistant Interaction Rules

Rules:

- For every code modification, the AI must explicitly state both the before-modification version and the after-modification version to the user to prevent them from having to scroll through chat history. All Git Hashes MUST be represented in their short hash format (typically 7 characters).
- For every documentation or code modification outside `docs/human/`, the AI
  must confirm that a committed human-owned requirement or design document
  covers the change before editing.
- Unless the user provides an explicit instruction to modify code, all user prompts must be treated as discussion or proposal requests. The AI is strictly prohibited from modifying code without explicit permission.
- Human-owned documentation lives under `docs/human/`. It is the
  authoritative human-maintained documentation area for requirements, design,
  planning, product meaning, and stable human decisions.
- The AI must never create, edit, rename, move, delete, format, or otherwise
  modify files under `docs/human/` at any time. This prohibition still applies
  if a user asks the AI to update a human-owned document. In that case, the AI
  may only provide proposed text, review notes, or a suggested change for the
  human owner to apply manually.
- Requirement documents under `docs/human/requirements/` record historical
  change requests or implementation requests. Design and planning documents
  under `docs/human/design/` record stabilized product content and expected
  behavior.
- When `docs/human/` conflicts with AI-maintained documentation, proposals,
  implementation assumptions, source comments, or code names, the AI must treat
  `docs/human/` as the stronger product/documentation authority, report the
  conflict, and ask for alignment before relying on the conflicting lower
  authority source.
- If a human-owned document is ambiguous, incomplete, or hard for the AI to
  understand, the AI must report the unclear point and ask for clarification or
  suggest explanatory text outside `docs/human/`. It must not silently reinterpret
  or directly fix the human-owned document.
- If a human-owned document required for a requested change is missing or
  uncommitted, the AI must report the blocker. It may help review or commit
  human-owned documentation when explicitly asked, but it must not modify files
  outside `docs/human/` until the covering human-owned document is committed.
- The AI must not use an older human-owned requirement as authority for a new
  regression fix, same-area follow-up, build behavior change, runtime dependency
  change, or scope expansion unless that older document explicitly covers the
  requested work. New regressions and new implementation requests require their
  own current human-owned requirement or design document before dependent
  changes proceed.
- Build and dependency fixes must preserve existing build override semantics
  unless the human-owned requirement explicitly asks to change them. If a fix
  changes compiler include paths, linker search paths, runtime library roots, or
  fallback dependency selection, verification must check the actual linked or
  loaded dependency, not only that compilation succeeds.
- For every AI-performed change outside `docs/human/`, the AI must create or
  update a matching implementation record under `docs/engineering/records/`.
  The record must identify the relevant `docs/human/` document and summarize
  the implementation steps, verification, and outcome.
- When committing, the AI must include the relevant `docs/human/` path in the
  commit message. If multiple human-owned documents cover one commit, include
  each relevant path.
- Unless the user explicitly asks for a detailed explanation, AI responses
  should be concise and clear, with the most important conclusions emphasized in
  bold so the answer is easy to scan.
- When explaining a bug, regression, fix plan, or implementation approach, the
  AI must use outcome-oriented engineering communication before naming code
  symbols. The explanation should answer, as applicable: why the bug happened,
  what mechanism the fix uses, how the change prevents recurrence, whether the
  approach conflicts with existing design direction, and which execution steps
  are needed with the purpose of each step.
- Code identifiers, file paths, function names, variable names, and line numbers
  are supporting evidence only. They must not replace the causal explanation,
  and they should normally appear after the human-readable engineering summary
  unless the user explicitly asks only for code locations.
- When an implementation step has an agreed benchmark or acceptance metric, and
  the measured result is a regression or does not support the stated goal, the
  AI must stop and report the result before continuing to the next step. It
  must not silently reinterpret the step as a success, layer on an unapproved
  mitigation, or continue the sequence as if the benchmark had passed.
- If benchmark data shows that a change is a negative optimization, the default
  follow-up is to revert or disable that change and document the result. Keeping
  the negative change requires explicit user approval and a documented reason
  separate from the failed performance goal.
- When the user explicitly starts a Socratic architecture alignment session,
  the AI should treat the session as iterative discovery, not implementation.
  The user leads with repeated narrowing questions, and the AI should answer
  each question narrowly, emphasize the key conclusion in bold, state known
  evidence and uncertainty, and avoid expanding into unrelated architecture
  explanation unless asked.
- During a Socratic architecture alignment session, the AI may inspect existing
  project documents and source code to answer factual questions, but must not
  modify files unless the user explicitly changes the session into a
  modification request.
- During a Socratic architecture alignment session, the AI should preserve
  continuity across questions by connecting each answer to the current narrowed
  topic and by surfacing the next most useful distinction only when it helps the
  user choose the following question.
- When an explicitly started Socratic architecture alignment session produces a
  meaningful implementation idea, architecture concern, engineering rule
  candidate, or proposal direction, the AI should maintain a process summary in
  `docs/chronicle/` when the user requests that record. The chronicle should
  emphasize why the idea emerged from the question path, not repeat the concrete
  code changes that belong in Git history and `docs/changelog.md`.
- During the active native UI restructure, App interface implementation is
  Swift-first: after the user explicitly approves App implementation, the AI
  may update native SwiftUI/AppKit code before updating HTML prototypes.
- HTML prototypes under `ui/prototypes/` are reference and review artifacts,
  not the source of truth for active native UI implementation. The accepted
  Swift implementation and stable product documents are authoritative.
- Liquid Glass component and UX mapping documents should be synchronized when
  component classes, tokens, SwiftUI ownership, layout, state, interaction,
  timing, behavior, or native-difference rules become stable. They do not block
  exploratory or in-progress Swift UI implementation, but they must be updated
  before a UI phase is declared complete or accepted as stable direction.
- The AI must not regress native App behavior just to match static HTML
  prototype data, layout shortcuts, or browser-only implementation details.
- If the user provides an original HTML draft, the AI must confirm whether the
  user wants prototype-first visual alignment or Swift-first implementation.
  The default workflow remains Swift-first unless the user explicitly asks for
  prototype-first work.
- HTML prototypes should be self-contained files with bundled CSS and
  JavaScript unless a documented complex-prototype reason justifies splitting
  assets.
- HTML prototypes should include basic interaction states such as disclosure,
  expansion, menu or popover examples, selected states, hover feedback, pressed
  states, and disabled states where relevant. They do not need to implement real
  product behavior such as video playback, indexing, database access, or
  file-system access.
- Complex UI may be split across multiple focused HTML prototypes when one
  prototype would be difficult to review or edit.
- Known differences between the accepted HTML prototype and the native App must
  be documented in the relevant product UI document before or with App
  implementation.
- If an HTML prototype conflicts with the current implemented UI design or
  documented product direction, the AI must explicitly confirm the intended
  direction with the user before implementing the conflicting interpretation.
- Rust shared-core implementation is currently paused. When modifying macOS
  code, the AI must preserve the future shared-core boundary from
  `docs/engineering/04_architecture_rules.md`: product semantics belong in
  `CueSeekerCore` or another isolated product-domain module, SwiftUI/AppKit
  owns presentation and platform interaction, and native playback owns media
  execution only.
- The AI must not add Rust shared-core scaffold, fixtures, FFI, shadow-mode
  code, or production replacement unless the user explicitly restarts the
  shared-core migration.
- Before implementing a new macOS feature, the AI must classify the feature as
  product semantics, platform UI/UX, platform integration, or playback
  execution, and keep durable product meaning out of SwiftUI views, AppKit
  bridges, and native playback classes.

## The Solution

Four principles in one file that directly address these issues:

| Principle | Addresses |
|-----------|-----------|
| **Think Before Coding** | Wrong assumptions, hidden confusion, missing tradeoffs |
| **Simplicity First** | Overcomplication, bloated abstractions |
| **Surgical Changes** | Orthogonal edits, touching code you shouldn't |
| **Goal-Driven Execution** | Leverage through tests-first, verifiable success criteria |

## The Four Principles in Detail

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

LLMs often pick an interpretation silently and run with it. This principle forces explicit reasoning:

- **State assumptions explicitly** — If uncertain, ask rather than guess
- **Present multiple interpretations** — Don't pick silently when ambiguity exists
- **Push back when warranted** — If a simpler approach exists, say so
- **Stop when confused** — Name what's unclear and ask for clarification

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

Combat the tendency toward overengineering:

- No features beyond what was asked
- No abstractions for single-use code
- No "flexibility" or "configurability" that wasn't requested
- No error handling for impossible scenarios
- If 200 lines could be 50, rewrite it

**The test:** Would a senior engineer say this is overcomplicated? If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- Match existing style, even if you'd do it differently
- If you notice unrelated dead code, mention it — don't delete it

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused
- Don't remove pre-existing dead code unless asked

**The test:** Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform imperative tasks into verifiable goals:

| Instead of... | Transform to... |
|--------------|-----------------|
| "Add validation" | "Write tests for invalid inputs, then make them pass" |
| "Fix the bug" | "Write a test that reproduces it, then make it pass" |
| "Refactor X" | "Ensure tests pass before and after" |

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let the LLM loop independently. Weak criteria ("make it work") require constant clarification.
