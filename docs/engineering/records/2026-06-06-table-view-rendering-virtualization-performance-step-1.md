# Table View Rendering Virtualization Performance - Step 1

Date: 2026-06-06

Human-owned requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Fix the test Search/Shiori table path that synchronously invalidated visible row
heights during AppKit scroll and frame notifications.

## Implementation

- Added a main-actor height invalidation scheduler that coalesces rapid requests.
- Routed scroll and table frame height invalidations through the scheduler.
- Preserved the existing visible-window invalidation behavior, but moved the
  actual `noteHeightOfRows` call out of the immediate scroll callback.

## Verification

- Added async scheduler tests using 20 rapid scroll invalidation requests.
- Test data verifies that the 20 requests produce one actual invalidation and
  retain the latest reason.

## Outcome

The table no longer performs synchronous row-height invalidation from the scroll
notification path. End-to-end validation still needs manual fast-scroll testing
in the app.
