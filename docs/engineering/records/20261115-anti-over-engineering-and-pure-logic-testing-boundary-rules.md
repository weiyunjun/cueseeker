# Anti Over-Engineering And Pure-Logic Testing Boundary Rules

- Date: 2026-11-15
- Related Requirement: `docs/human/requirements/20261115-Engineering-Anti Over-Engineering And Pure-Logic Testing Boundary Rules.md`
- Scope: `docs/engineering`

## Changes Made

- **Scoped automated testing to deterministic pure logic and prohibited production test backdoors**:
  - Updated `docs/engineering/06_testing_rules.md` (§2 `Testing Principles` and §14 `Regression Policy`) and `docs/engineering/02_git_workflow.md` (§11 `AI Assistant Interaction Rules` and `Goal-Driven Execution`) to confine automated tests to pure data calculation, subtitle parsing, search matching, SQLite persistence/migrations, and UI-independent domain rules on core paths and key boundaries.
  - Removed legacy rules that prompted automated reproduction/smoke harnesses for UI and playback presentation regressions, defaulting window, hover, cursor, menu/popup, visual typography, and video/subtitle frame presentation changes to build verification, existing test suite pass, and human E2E acceptance.
  - Prohibited fake window/view hierarchies and synthetic mouse/keyboard event scaffolding in unit tests, as well as test-only properties, artificial delay switches, reset entry points, and probe counters in production code.
- **Clarified minimum sufficient design vs. design-rule consistency**:
  - Updated `docs/engineering/04_architecture_rules.md` (§2.4 `Minimum Sufficient Design`) and `docs/engineering/02_git_workflow.md` (§4.1 `Complexity Checks`) so prohibiting hardcoding and private special-case implementations applies to product/interaction rule alignment with `docs/human/design/` rather than building heavy generalized engines or intermediate models without explicit approval.
- **Added alignment-stage scope estimates and acceptance subtraction rules**:
  - Updated `docs/engineering/02_git_workflow.md` (§4.1 and §11) to require plain-language change-scope estimates during solution alignment and to prioritize deleting redundant branches/state over stacking patch flags during iterative acceptance tuning.

## Verification

- Reviewed `git diff` across `docs/engineering/02_git_workflow.md`, `docs/engineering/04_architecture_rules.md`, `docs/engineering/06_testing_rules.md`, and the implementation record; zero source or test files were modified.
