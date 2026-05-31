# ASS Bilingual Physical Order Step 3

Requirement: `docs/human/requirements/20260531-Bug-ASS Bilingual Physical Order.md`

## Scope

- Verified the implementation and searched for performance regressions after
  keeping ASS physical ordering entirely in the index-time parser path.
- Confirmed the step 2 code diff touched only `ASSParser.swift` plus the
  implementation record, leaving search, sidebar, database read, and playback
  rendering paths unchanged.

## Verification

- `swift test --filter ASSParserTests` passed.
- `swift test --filter searchReadsASSIndexTimePhysicalOrderWithoutRuntimeReordering`
  passed.
- `swift test --filter CueSeekerCoreTests` passed with 93 tests.
- `swift test` passed with 169 tests.

## Search Performance

Benchmarks used a temporary copy of the current app database at
`/private/tmp/cueuseeker-bench.sqlite`.

- `swift run SearchBench /private/tmp/cueuseeker-bench.sqlite 巨人 1000`
  - Warmup: 26.05 ms.
  - Hot runs: min 7.04 ms, median 7.05 ms, average 7.08 ms, max 7.18 ms.
  - Results: 591 rows across 27 file summaries.
- `swift run SearchBench /private/tmp/cueuseeker-bench.sqlite 信じる 1000`
  - Warmup: 10.99 ms.
  - Hot runs: min 0.55 ms, median 0.56 ms, average 0.57 ms, max 0.59 ms.
  - Results: 20 rows across 15 file summaries.

Outcome: no search-stage computation was added, and the measured hot search
times showed no suspicious regression.
