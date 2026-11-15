# 2026-11-15 Conventional Commit Format And Strict Single-Line Requirement Hook

## Covering Requirement

- `docs/human/requirements/20261115-Engineering-Conventional Commit Format And Strict Single-Line Requirement Hook.md`

## Summary of Steps

1. Updated `scripts/verify_commit_msg.sh` and reinstalled `.git/hooks/commit-msg`:
   - Enforced single-line pure English printable ASCII commit messages (rejecting multi-line bodies, CJK characters, full-width punctuation, tabs, and leading/trailing spaces).
   - Replaced legacy uppercase `<Area>:` validation with a strict lowercase `<type>: ` whitelist (`feat`, `fix`, `docs`, `refactor`, `perf`, `style`, `test`, `build`, `ci`, `chore`, `revert`) while explicitly forbidding `<type>(<scope>):`.
   - Required concise multi-word English summaries without embedded `docs/human/` or `requirements/` paths.
   - Required trailing parentheses to contain exactly one relative requirement path `(docs/human/requirements/<requirement>.md)` (rejecting leading `/`, subdirectories, `docs/human/design/` paths, and multiple joined paths) and verified that the referenced requirement file exists in the repository.
2. Updated `scripts/test_verify_commit_msg.sh`:
   - Added isolated deterministic test cases covering valid `feat:`, `docs:`, `chore:`, and `fix:` commits as well as rejections for multi-line bodies, uppercase prefixes, scoped prefixes, unknown types, Chinese/full-width characters, single-word vague summaries, bare paths, leading slashes, `design/` paths, multiple paths, archived subdirectory paths, non-existent requirement files, leading/trailing spaces, and empty/comment-only messages.
3. Updated `docs/engineering/02_git_workflow.md`, `docs/engineering/00_project_governance.md`, and `docs/engineering/01_documentation_rules.md`:
   - Aligned commit message format specifications and traceability rules to the new single-line Conventional Commit format with a single trailing requirement path, removing legacy uppercase area prefixes and rules that previously instructed citing `docs/human/design/` or multiple paths in commit messages.

## Verification & Outcome

- Executed `./scripts/test_verify_commit_msg.sh`: all 23 test cases passed (`23 passed, 0 failed`).
- Verified `.git/hooks/commit-msg` installation and validated the live commit through the updated hook.
- Inspected `git status` and `git diff` to confirm zero unintended changes and zero edits to `docs/human/`.
- Outcome matches all acceptance criteria in the covering requirement document.
