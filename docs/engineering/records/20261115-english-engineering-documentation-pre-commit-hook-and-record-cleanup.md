# 2026-11-15 English Engineering Documentation Pre-Commit Hook and Record Cleanup

## Covering Requirement

- `docs/human/requirements/20261115-Engineering-English Engineering Documentation Pre-Commit Hook And Record Cleanup.md`
- Branch / Baseline: `main` (before change: `50e4cd3`, requirement commit: `37e71b8`)

## Summary of Steps

1. **Aligned English documentation rules across governance and always-read workflow specs**:
   - Updated `docs/engineering/00_project_governance.md` (Section 3), `docs/engineering/01_documentation_rules.md` (Sections 3 and 6), and `docs/engineering/02_git_workflow.md` (Sections 10 and 11) to explicitly state that all AI-maintained documentation outside `docs/human/` — including `docs/engineering/` specifications, `docs/engineering/records/` implementation records, and `docs/changelog.md` — must be written in English with zero bare Chinese headings, section titles, or narrative prose even when the covering requirement and chat discussion are in Chinese.
   - Clarified the literal copy boundary: non-English UI strings, external source titles, or query examples may appear only inside fenced code blocks, inline backticks (`` `...` ``), or ASCII quotes (`"..."` or `'...'`), and wrapped the two bare Chinese UI labels on line 130 of `docs/changelog.md` (`摘录` and `摘录集`) in inline backticks so full-file pre-commit validation on `docs/changelog.md` passes cleanly.

2. **Added local `pre-commit` verification script and automated test suite**:
   - Created `scripts/verify_engineering_doc_lang.sh` and installed `.git/hooks/pre-commit` via `./scripts/verify_engineering_doc_lang.sh --install`:
     - Inspects only newly staged added/copied/modified/renamed files matching `docs/changelog.md` or `docs/engineering/**/*.md` (ignoring `docs/human/`, source code, and untouched historical records).
     - Strips fenced code blocks, single/multi-backtick inline code spans, ASCII double-quoted literals, and ASCII single-quoted literals (while preserving English contraction/possessive apostrophes), and blocks commits with file and line diagnostics if any CJK ideographs, kana, hangul, or CJK/full-width punctuation remain in headings or prose.
   - Created `scripts/test_verify_engineering_doc_lang.sh` covering valid English records, backtick/ASCII-quote/fenced-block UI literals, rejections for Chinese headings, bare Chinese prose, full-width punctuation, apostrophe-adjacent bare CJK, and Chinese curly quotes, plus isolated Git index staging tests verifying `docs/human/` and untouched legacy record exemptions alongside `docs/engineering/records/` and `docs/changelog.md` blocking.

3. **Cleaned up all 8 November 14–15 implementation records that had drifted into Chinese**:
   - Verified `docs/engineering/records/20261115-hdr-metadata-indexing-file-card-and-file-info-display.md` (already converted to English in `900eeea`) and rewrote the remaining 7 November 14–15 Chinese implementation records into compliant English while preserving all technical details, commit hashes, test commands, test counts, and backtick-wrapped UI copy literals:
     - `20261114-deterministic-subtitle-font-environment-reuse-and-empty-font-section-compatibility.md`
     - `20261114-file-card-rich-metadata-and-unified-duration-format.md`
     - `20261115-breadcrumb-all-folders-copy-and-topbar-dialog-header-token-alignment.md`
     - `20261115-filter-dialog-apply-button-copy-for-empty-search-query.md`
     - `20261115-fix-dialog-child-control-transition-jump-and-premature-system-sheet-scrim-fade.md`
     - `20261115-read-only-text-selection-symmetry-and-interactive-underline-offset-alignment.md`
     - `20261115-remove-thousand-separators-from-cue-queue-gap-and-count-badges.md`
   - Left all earlier historical records prior to November 14 and all files under `docs/human/` untouched.

## Verification & Outcome

- Executed `./scripts/test_verify_engineering_doc_lang.sh`: `12 passed, 0 failed`.
- Executed `./scripts/test_verify_commit_msg.sh`: `23 passed, 0 failed`.
- Executed `./scripts/verify_engineering_doc_lang.sh` across `docs/changelog.md`, all `docs/engineering/*.md` files, and all November 14–15 implementation records: `0` violations.
- Verified `.git/hooks/pre-commit` installation and live staged commit validation, confirming zero edits to `docs/human/` and zero edits to earlier historical records.
