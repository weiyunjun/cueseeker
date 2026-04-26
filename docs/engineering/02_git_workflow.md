# Git Workflow

Status: Draft

## 1. Purpose

This document defines Git workflow rules for SubFinderX.

Git history should preserve meaningful project stages and make the native macOS rewrite reviewable.

## 2. Repository State

The repository has already been initialized for the native rewrite.

Known baseline:

- Baseline commit: `064fa30 Baseline Flutter implementation`
- Baseline tag: `flutter-baseline`
- Archive commit: `b7db6de Archive: move Flutter implementation under archive/flutter`
- Active branch: `native-macos-rewrite`

Rules:

- The archived Flutter implementation must remain available under `archive/flutter/`.
- Active native macOS work should happen on `native-macos-rewrite` unless a later workflow changes this.
- Do not rewrite the baseline or archive history.

## 3. Branching Rules

The current active development branch is:

```text
native-macos-rewrite
```

Rules:

- Use small reviewable changes on the active branch during early solo development.
- Create topic branches only when a change becomes large enough to benefit from isolation.
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
- Implement favorites and personal learning flow.

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
- M3 favorites and personal learning flow.

Rules:

- Use tags for meaningful milestones, not every minor change.
- Release tags must align with `docs/engineering/07_release_rules.md` after release rules are active.
- Do not move existing milestone tags without explicit approval.

## 8. Changelog Relationship

Git commits and changelog entries serve different purposes.

Rules:

- Git records concrete file changes.
- `docs/changelog.md` records milestone-level progress.
- Each completed milestone should update the changelog.
- Small internal commits do not need individual changelog entries unless they change user-visible behavior or milestone status.

## 9. Documentation Before Implementation

When a technical or product rule is missing, add or update documentation before relying on implementation assumptions.

Rules:

- Product behavior changes must update product documents.
- Engineering process or architecture changes must update engineering documents.
- Expensive or hard-to-reverse decisions require ADRs.
- Significant proposed changes should start in `docs/proposals/`.

