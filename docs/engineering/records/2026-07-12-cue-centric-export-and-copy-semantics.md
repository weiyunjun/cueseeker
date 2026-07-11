# Cue-Centric Export And Copy Semantics

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Complete the Cue-centric Anki, Screenshot, and Collage export semantics after
Search, Shiori, Context, and table actions moved to individual Cue identity.
Keep the previously accepted ASS/SRT rendering object and all frame rendering,
midpoint, composition, and Collage crop behavior unchanged.

## Classification

- Export unit: every selected Search or Shiori row contributes exactly one
  primary Cue.
- Collage source constraint: selected Cues must belong to one standardized
  subtitle-file path; video path is not the constraint.
- Presentation-only metadata: Cue display order and event index are carried by
  Screenshot items only to stabilize ordering and filenames. They do not alter
  subtitle rendering.

## Implementation

- Changed Collage eligibility from one standardized video path to one
  standardized subtitle path while preserving the nonempty and 50-item limits.
  Updated the invalid-selection diagnostic to name one subtitle file and Cues.
- Added optional Cue display-order and event-index metadata to Screenshot export
  items and populated it from both Search results and Shiori rows.
- Kept the legacy single-Screenshot filename unchanged. Batch Screenshot export
  now detects every legacy-name collision, ranks colliding items by stable Cue
  timeline and identity, appends deterministic `cue-NN` suffixes, and applies a
  final ordinal suffix if a generated name would still collide. No item can
  overwrite another selected Cue's file.
- Stabilized Collage ordering by Cue start, Cue end, Cue display order, Cue event
  index, and original input ordinal. The final key preserves the caller's order
  only when all Cue identity keys are equal.
- Changed every Search and Shiori Anki entry point to pass exact primary Cue
  `content` instead of a pre-cleaned display-line projection.
- Changed Anki HTML conversion to normalize CRLF and lone CR to LF, HTML-escape
  the complete Cue, and convert every source newline to `<br>`. Consecutive and
  leading/trailing empty lines and source whitespace are preserved.
- Left existing `Copy Cue Text`, `Copy Cue Group Text`, and Copy Table behavior
  unchanged because the preceding table phase already binds them to exact
  primary Cue, ordered Cue Group, and primary-only payloads respectively.

## Verification

- `swift test --filter SubtitleScreenshotExporterTests` passed all 7 tests.
- `swift test --filter AnkiPackageExporterTests` passed all 3 exact-content,
  HTML conversion, and Search/Shiori entry-mapping tests.
- `swift build --target CueSeekerPlaybackTests` passed while the Screenshot
  implementation and its test target were isolated from concurrent Focus UI
  work.
- `swift build` passed for the complete package after the concurrent Focus UI
  phase returned to a stable integration point.
- `swift test --quiet` passed the complete package suite: 525 Swift Testing
  tests and 7 XCTest tests, with 0 failures.
- Independent read-only review found no blocking export issue and confirmed the
  ASS/SRT renderer, midpoint, composition, band detection, and Collage crop
  paths were unchanged.
- Focused Screenshot exporter tests cover standardized subtitle-path
  eligibility, different-video acceptance, different-subtitle rejection,
  empty/51-item rejection, diagnostic wording, unchanged single naming,
  deterministic same-time sibling names, and full stable Collage ordering.
- Focused Anki tests cover CRLF, LF, and CR conversion, consecutive empty lines,
  leading/trailing whitespace, HTML escaping, empty content, and exact Search
  and Shiori entry mapping.
- Screenshot entry tests verify Search and Shiori Cue display/event metadata is
  propagated into export items.

## Outcome

Anki, Screenshot, and Collage now preserve individual-Cue identity and content
through their non-rendering export layers. Same-time sibling Cues remain
distinct and deterministic without changing what ASS/SRT rendering draws or
how frames and Collage strips are produced.
