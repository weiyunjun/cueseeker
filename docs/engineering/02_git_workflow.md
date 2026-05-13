# Git Workflow

Status: Draft

## 1. Purpose

This document defines Git workflow rules for CueSeeker.

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

## 10. AI Assistant Interaction Rules

Rules:

- For every code modification, the AI must explicitly state both the before-modification version and the after-modification version to the user to prevent them from having to scroll through chat history. All Git Hashes MUST be represented in their short hash format (typically 7 characters).
- Unless the user provides an explicit instruction to modify code, all user prompts must be treated as discussion or proposal requests. The AI is strictly prohibited from modifying code without explicit permission.
- Unless the user explicitly asks for a detailed explanation, AI responses
  should be concise and clear, with the most important conclusions emphasized in
  bold so the answer is easy to scan.
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
