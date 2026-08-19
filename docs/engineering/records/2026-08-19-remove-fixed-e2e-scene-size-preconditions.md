# Remove Fixed E2E Scene Size Preconditions

## Requirement

- `docs/human/requirements/20260819-Engineering-Remove Fixed E2E Scene Size Preconditions.md`

## Scope

- Remove fixed window-size and backing-scale prerequisites from the shared E2E
  rules and affected in-app procedures.
- Preserve current `sceneID`, expected window layout, pre-agreed coordinates,
  and stop-before-interaction safeguards.

## Steps

- Removed the logical-size gate from the shared testing rule.
- Removed fixed scene dimensions and backing scale from the Library Detail,
  shared Video Card, and Workbench Topbar in-app procedures.
- Kept the controller's reported geometry fields documented as protocol output.

## Verification

- Confirmed the affected procedures no longer require a fixed scene size or
  backing scale.
- Confirmed the shared rules still require the current `sceneID`, expected
  window layout, pre-agreed coordinates, and safe early exit on mismatch.
- `git diff --check` passed.

## Outcome

- Debug in-app E2E procedures no longer reject a valid scene only because its
  fixed dimensions or backing scale differ from an earlier capture.
- Coordinate actions remain guarded by scene identity and window layout.
