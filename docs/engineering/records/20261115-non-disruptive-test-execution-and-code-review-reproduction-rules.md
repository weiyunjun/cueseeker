# 2026-11-15 Non-Disruptive Test Execution And Code Review Reproduction Rules

## Covering Requirement

- `docs/human/requirements/20261115-Engineering-Non-Disruptive Test Execution And Code Review Reproduction Rules.md`

## Summary of Steps

1. Updated `docs/engineering/02_git_workflow.md` (`## 11. AI Assistant Interaction Rules` and `### 4. Goal-Driven Execution`):
   - Clarified that UI/playback changes verify build plus relevant headless/pure-logic test suites rather than unfiltered full-suite test runs that pop up legacy AppKit windows.
   - Added explicit non-disruptive test execution rules: use `swift build --package-path apps/macos-native` for intermediate compile checks, and use `--filter` on headless pure-logic suites or `--skip` on the five legacy window-popping test suites (`DebugE2EControllerTests`, `WorkbenchInputControlsTests`, `PointerHoverGateTests`, `CueGroupRefreshScopeIntegrationTests`, `PlaybackPageFocusIsolationTests`) both when running `swift test` directly and when generating cross-session implementation prompts, leaving legacy test files untouched.
   - Added Code Review workflow and source-verification rules: verify real UI labels, menu items, and shortcut definitions in source code plus product rules in `docs/human/design/` before reporting any finding; drop or explicitly note theoretical branches unreachable via ordinary UI interaction; output symptom, concrete UI reproduction steps, and expected vs. actual behavior first and wait for human reproduction confirmation before generating any fix prompt or editing code; and after human confirmation, align on pre-change vs. post-change root cause and fix scope before outputting a fix prompt or applying edits.
2. Updated `docs/engineering/06_testing_rules.md` (`## 2. Testing Principles` and `## 14. Regression Policy`):
   - Synchronized the headless/non-disruptive test execution rules and updated wording that previously referenced unfiltered runs of the existing test suite.

## Verification & Outcome

- Inspected `git status` and `git diff` to verify only engineering documentation files (`docs/engineering/02_git_workflow.md`, `docs/engineering/06_testing_rules.md`, and this implementation record) were modified, with zero changes to production code, legacy test files, or `docs/human/`.
- Outcome matches all acceptance criteria in the covering requirement document.
