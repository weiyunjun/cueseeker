# Quick Search Chunk Actions Step 4 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-Quick Search Chunk Actions.md`

## Scope

- Mark the corresponding text segment in the current-sentence row when a chunk
  is selected.
- Reuse the existing chunk selected visual style as the source style.
- Keep the weaker sentence-side state as a minimal parameter adjustment, not a
  separate highlight system.

## Steps

1. Extracted the chunk token rendering into a shared Quick Search helper.
   Result: the chunk result row and sentence-side mapped segment now share the
   same font, padding, corner radius, foreground, and selected background shape.
2. Rendered the current sentence as plain text segments plus one selected token
   when the selected chunk text can be matched.
   Result: the selected chunk visually maps to its source location in the
   sentence row.
3. Made the sentence-side selected token weaker only by lowering the selected
   background opacity.
   Result: the mapping follows the selected chunk style without adding a new
   yellow highlight, underline, color family, or shape.
4. Added matching logic for repeated chunk text.
   Result: when the same chunk text appears multiple times, the selected chunk
   index maps to the matching occurrence order when possible.
5. Added tests for ordinary chunk-to-sentence matching and repeated chunk text
   matching.
   Result: the core mapping behavior is covered independently of SwiftUI
   rendering.

## Verification

- `git diff --check` passed.
- `swift test` passed from `apps/macos-native` with 165 Swift Testing tests
  and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- Step 4 is implemented and verified.
