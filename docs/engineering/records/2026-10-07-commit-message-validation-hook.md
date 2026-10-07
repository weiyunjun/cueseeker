# Commit Message Validation Hook Implementation

Human-owned documents:

- `docs/human/requirements/20261007-Engineering-Commit Message Validation Hook.md`

## Why

1. **Problem**:
   - Despite git workflow conventions documented in `docs/engineering/02_git_workflow.md`, previous commits contained non-compliant commit messages, such as conventional commits formatting (`feat(...)`), lowercase prefixes (`docs:`), and commits lacking citations to `docs/human/` requirement documents.
   - Textual document guidelines alone act as soft constraints; without physical mechanical interception, human and AI contributors can inadvertently commit non-compliant messages.

2. **Goal**:
   - Implement a lightweight, zero-external-dependency local git hook (`commit-msg`) that enforces the `<Area>: <Summary>` format with uppercase Area naming and mandatory `docs/human/` document traceability.

## What changed

1. **Verification Script (`scripts/verify_commit_msg.sh`)**:
   - Validates that the subject line matches `^[A-Z][a-zA-Z0-9 &]*: .+`.
   - Rejects lowercase prefixes, conventional commits, or missing colons.
   - Verifies that the commit message includes a citation to `docs/human/`.
   - Includes a `--install` flag to automatically configure the `.git/hooks/commit-msg` hook in the repository.

2. **Automated Test Suite (`scripts/test_verify_commit_msg.sh`)**:
   - Tests valid single-line and multi-line formats.
   - Verifies rejection of missing `docs/human/`, lowercase prefixes, conventional commit formats, malformed subjects, empty messages, and comment-only messages.

3. **Git Hook Configuration**:
   - Installed `.git/hooks/commit-msg` invoking `scripts/verify_commit_msg.sh`.

## Verification

- `scripts/test_verify_commit_msg.sh`: passed (9/9 tests passed).
- Tested `.git/hooks/commit-msg` integration with simulated git commits.
