# Speaker Subtitle ASS CRLF Fix

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Fix ASS speaker subtitle rewriting for real MyGO subtitle files that use CRLF
line endings.

## Root Cause

The ASS speaker rewriter split scripts by searching Swift `String` characters
for `"\n"`. Real MyGO `.ass` files use CRLF line endings, which prevented the
rewriter from parsing any `Dialogue:` events from the full script.

## Implementation

- Replaced the custom `String.firstIndex(of: "\n")` line splitter with
  Foundation line-range enumeration that preserves the original line
  terminators.
- Added rewriter diagnostics for parsed, unmatched, and matched ASS dialogue
  counts.
- Added regression coverage for CRLF ASS scripts and layer-1 bilingual
  `Dial_CH` speaker targets.

## Verification

- Passed: `swift test --filter SubtitleSpeakerDisplay`
- Passed temporary local verification against real MyGO EP01 `.scjp.ass`, where
  the rewritten script contains `长崎素世: 小祥`.
