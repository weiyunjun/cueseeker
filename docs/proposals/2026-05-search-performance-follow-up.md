# Search Performance Follow-up

Status: Deferred

## Background

Search responsiveness was investigated after the native app felt slower than
the standalone Search benchmark suggested. The current app now records
project-local Search timing logs under:

```text
logs/search-timing/search-timing-YYYY-MM-DD.log
```

The timing logs show that the visible UI rendering path is not the dominant
cost for the measured slow search case. The slow path is inside
`SubtitleDatabase.searchPage`, after the FTS candidate query returns.

## Investigation Snapshot

Measured on May 11, 2026, local development build, one selected subtitle
folder.

The measured query was a two-character CJK query. The log intentionally records
query length rather than query text.

Search shape:

- Requested page limit: `1000`.
- Returned page results: `1000`.
- Total matching results: `1282`.
- Matching subtitle files: `81`.
- Multi-line candidate cue groups: `943`.
- Loaded cue-line rows: `29740`.

End-to-end timing:

- First result row visible: `1328.66 ms`.
- Debounce wait: `265.73 ms`.
- `database.searchPage`: `1026.52 ms`.
- State assignment after database return: `0.03 ms`.
- Search group rebuild: `1.09 ms`.
- Search completed to first result row visible: `14.55 ms`.

Internal `searchPage` timing:

- Query plan: `0.30 ms`.
- Scope resolution: `0.16 ms`.
- Statement prepare: `1.05 ms`.
- FTS candidate batch: `163.12 ms`.
- Multi-line cue-line load: `130.64 ms`.
- Line-level validation: `110.92 ms`.
- Result sort: `566.72 ms`.
- Page slice: `0.05 ms`.
- File summaries: `51.59 ms`.

## Current Read

The measured bottleneck is not SwiftUI first-row rendering, app-state
assignment, or Search group rebuilding.

The largest observed cost is `db.sort_results`, followed by FTS candidate
loading, cue-line loading, and line-level validation. `db.file_summaries` is
also visible but smaller.

The likely optimization area is Search result ordering and presentation-title
preparation inside or around `SubtitleDatabase.searchPage`. This document does
not prescribe a specific algorithm. The optimization strategy should be chosen
later after feature work priorities are clear.

## Development Decision

This performance issue is a known follow-up and should not block ordinary
feature development.

Rules:

- Keep the detailed Search timing logs available during development.
- Do not pause unrelated feature work solely because this Search hot path still
  needs optimization.
- Before changing the Search ranking, title preparation, or result-summary
  algorithm, compare against the timing snapshot above and capture a new timing
  log for the same broad case.
- Any later optimization should preserve current Search semantics unless a
  separate product or engineering decision changes those semantics first.

## Acceptance Direction

A future optimization pass should be judged against real app timing logs, not
only standalone benchmark output.

Useful comparison metrics:

- `db.search_page_complete phase`.
- `db.sort_results phase`.
- `db.file_summaries phase`.
- `db.fts_batch phase`.
- `database_search_returned phase`.
- `first_result_row_appeared elapsed`.

The next pass should record before-and-after logs for at least:

- The two-character CJK high-result query shape above.
- A lower-result CJK query.
- Repeating the same query without restarting the app.
