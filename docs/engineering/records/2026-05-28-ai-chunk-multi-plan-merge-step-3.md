# AI Chunk Multi-Plan Merge Step 3 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-AI Chunk Multi Plan Merge.md`

## Scope

- Merge multiple valid AI Chunking plans into the final chunk list.
- Use the first valid plan as the merge base.
- Split each base chunk with chunks from later valid plans when those chunks
  exactly cover the same range.
- Preserve translations from the selected split chunks.
- De-duplicate the ordered merged output while keeping the earliest chunk and
  translation.

## Steps

1. Added final item merging after response validation.
   Result: single valid plans still return directly, while multi-plan responses
   now pass through the merge pipeline.
2. Built a split candidate search over validated chunk ranges.
   Result: a base chunk can be replaced by later-plan chunks only when the
   selected chunks fully cover the base chunk range without crossing its
   boundary.
3. Ordered split candidates by valid-plan order and chunk order.
   Result: when multiple later plans provide a matching split chunk, the earlier
   plan wins.
4. Allowed split coverage to come from multiple valid plans.
   Result: one base chunk can be split by combining compatible chunks from more
   than one later plan.
5. Added final ordered de-duplication.
   Result: the final list is ordered as merged plan, first valid plan, second
   valid plan, third valid plan, while repeated chunk text keeps the earliest
   translation.
6. Added tests for ordinary splitting, cross-plan splitting, first-valid-plan
   base selection, and de-duplication translation precedence.
   Result: the multi-plan merge behavior is covered independently of network
   requests.

## Verification

- Initial `swift test` runs built successfully but intermittently crashed during
  the existing SettingsStore appearance application path with an `NSApp`
  implicitly-unwrapped optional failure.
- A later `swift test` run passed from `apps/macos-native` with 160 Swift
  Testing tests and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- Step 3 is implemented and verified.
