# Search Result Segment Playback Step 1

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Scope:

- Added native playback support for an optional `[start_ms, end_ms)` segment
  boundary.
- Kept existing open and seek calls as the default unbounded playback path.
- Added bounded open and seek entry points that carry `endMilliseconds`.
- Added a native segment-finished delegate event and Swift wrapper forwarding.
- Prevented video frames at or after the segment end from being submitted.
- Trimmed the final scheduled audio buffer to the segment end so no samples
  beyond `end_ms` are scheduled.

Verification:

- Ran `swift build` in `apps/macos-native`.
- Result: passed.

Outcome:

- Step 1 implements the playback-kernel boundary and event surface only.
- Settings, automatic next navigation, Auto-play Gap, probe-level timing tests,
  and user end-to-end acceptance remain future steps.
