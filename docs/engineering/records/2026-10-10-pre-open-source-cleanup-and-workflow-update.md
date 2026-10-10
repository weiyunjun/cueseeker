# Pre-Open Source Cleanup And Workflow Update

Human-owned documents:

- `docs/human/requirements/20261010-Engineering-Pre Open Source Cleanup And Workflow Update.md`

## Why

1. **Pre-Open Source Hygiene**:
   - The project is scheduled for open-sourcing on GitHub on 2026-10-11.
   - Historical Rust incremental build outputs (`target/`, 3,425 files) and Flutter build intermediates (`archive/flutter/build/`, 4,197 files, including three 78 MB debug binaries) were accidentally tracked in Git, inflating repository size and risking GitHub file size warnings.
   - Root report residue (`Unnatural.EP10.zh-ja.MagicStar.report.txt`) and early experimental Windows implementations (`apps/windows-native/`, `apps/windows-playback-backend/`, `apps/windows-playback-lab/`) were unmaintained historical drafts that needed pruning before open-sourcing.
2. **Git Workflow Decoupling**:
   - Explicitly decouple granular local Git commits from GitHub remote pushes.
   - Ensure developers and AI assistants maintain strict atomic local commits without auto-pushing to GitHub on every commit, restricting remote pushes to repository owner-triggered milestones.

## What changed

1. **Gitignore Rules (`.gitignore`)**:
   - Added `target/` to ignore Rust build artifacts.
   - Replaced root `/build/` with `**/build/` to ignore nested build outputs across all submodules.
   - Added `*.report.txt` to ignore local diagnostic report files.
2. **Workflow Documentation (`docs/engineering/02_git_workflow.md`)**:
   - Added Section 3.1 defining remote synchronization rules and decoupling local commits from GitHub pushes.
   - Added explicit rule to Section 11 prohibiting AI assistants from executing `git push`.
3. **Repository Cleanups**:
   - Removed tracked build artifacts (`target/`, `archive/flutter/build/`).
   - Removed root local report file (`Unnatural.EP10.zh-ja.MagicStar.report.txt`).
   - Removed legacy experimental Windows codebases (`apps/windows-native/`, `apps/windows-playback-backend/`, `apps/windows-playback-lab/`).

## Verification

- `git status` verification: all 7,600+ legacy/build files cleanly unstaged and removed from Git index.
- Gitignore test: verified `target/` and nested `build/` directories are properly ignored.
