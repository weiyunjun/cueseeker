# 2026-11-17 Unified Bug Reproduction Verification And Plain-Language Communication Rules

## Covering Requirement

- `docs/human/requirements/20261117-Engineering-Unified Bug Reproduction Verification And Plain-Language Communication Rules.md`

## Summary of Steps

1. Updated `docs/engineering/02_git_workflow.md` (`## 11. AI Assistant Interaction Rules`):
   - Extended source-verified bug reporting and concrete UI reproduction rules from Code Review alone to all collaboration stages (solution alignment, root-cause investigation, design/approach discussion, and Code Review).
   - Required verifying real UI labels, controls, menu items, and shortcut definitions in source code together with the latest product/interaction rules under `docs/human/design/` before reporting any suspected bug or collateral unexposed defect; dropping unreachable theoretical branches directly; prohibiting fabricated hypothetical UI scenarios inferred backward from code-branch differences; prohibiting framing existing working behavior as an active bug (anti-regression constraints must be labeled as existing working behavior); and prohibiting inventing bugs to justify refactoring (consolidating duplicated logic must be stated plainly as code cleanup).
   - Enforced the concise plain-language three-part bug presentation format (one-sentence symptom on the specific screen, exact UI reproduction steps with concrete controls and key/pointer actions, and expected vs. actual behavior) without internal state or mechanism jargon, and prohibited padding simple UI actions with convoluted backstories.
   - Required collateral suspected bugs surfaced during solution alignment or approach discussion to be listed separately with concrete reproduction steps for human verification first, forbidding folding unverified collateral bugs into requirement scope or expanding change scope prior to human confirmation.
2. Synchronized the machine-local global collaboration rules file (`GEMINI.md`) with the exact same all-stage bug verification, plain-language expression, and pre-scope human reproduction rules.

## Verification & Outcome

- Verified `scripts/verify_engineering_doc_lang.sh` passes on all updated engineering documentation files with zero non-English prose violations.
- Inspected `git status` and `git diff` to confirm only `docs/engineering/02_git_workflow.md` and this implementation record were modified in the repository, with zero edits to production code, test files, or `docs/human/`.
- Outcome matches all acceptance criteria in the covering requirement document.
