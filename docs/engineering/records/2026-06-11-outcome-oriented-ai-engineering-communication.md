# Outcome-Oriented AI Engineering Communication

Human requirement:

- `docs/human/requirements/20260611-Engineering-Outcome Oriented AI Engineering Communication.md`

## Scope

This record covers the June 11 engineering rule update for AI communication
when discussing bugs, regressions, fix plans, and implementation approaches.

## Changes

- Added an AI interaction rule requiring outcome-oriented engineering
  explanations before code identifiers.
- Required bug and implementation explanations to cover root cause, fix
  mechanism, recurrence prevention, design compatibility, and staged execution
  when applicable.
- Clarified that file paths, function names, variable names, and line numbers
  are supporting evidence, not a substitute for a causal explanation.

## Verification

- Reviewed the committed human-owned requirement and confirmed it covers the
  engineering rule change.
- Checked the updated rule placement in `docs/engineering/02_git_workflow.md`
  under AI Assistant Interaction Rules.

## Outcome

- Future AI responses for engineering investigation and implementation planning
  must explain the human-readable cause, effect, and verification story first,
  then use code locations only as evidence.
