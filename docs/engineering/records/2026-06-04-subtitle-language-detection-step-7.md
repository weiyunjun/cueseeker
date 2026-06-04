# Subtitle Language Detection Step 7

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Fixed search language filtering so it applies to the subtitle line that matched
the query before merged same-timestamp display groups are accepted:

- Loaded ASS/SRT language detections in the search layer and used them during
  candidate validation.
- Kept merged cue-line display intact after the matching line passes the
  language filter.
- Treated `unknown` as matching every non-`All` language filter, as required.
- Preserved legacy cue-group language fallback when fine-grained file/style
  detections are missing.
- Avoided the group-language SQL condition when it could reject unknown matching
  lines before line-level validation.
- Added SearchBench `--language-filter` support for performance checks.

## Verification

- `swift test --filter searchLanguage` passed 3 Swift Testing tests.
- `swift test` passed 199 Swift Testing tests and 7 XCTest tests.

## Performance

Benchmarked against `/private/tmp/cueuseeker-search-language-bench-before.sqlite`
with limit 100. Baseline values are the pre-change `All` filter results; final
values are the post-change Japanese filter results.

| Query | Mode | Baseline All warmup | Japanese warmup | Baseline total | Japanese total |
| --- | --- | ---: | ---: | ---: | ---: |
| `の` | visible window | 14.07 ms | 12.38 ms | 100 | 100 |
| `今日` | visible window | 36.68 ms | 46.12 ms | 100 | 100 |
| `大丈夫` | visible window | 46.11 ms | 54.41 ms | 100 | 100 |
| `の` | exact | 933.97 ms | 891.38 ms | 23168 | 23168 |
| `今日` | exact | 71.26 ms | 97.61 ms | 1346 | 1337 |
| `大丈夫` | exact | 6.55 ms | 9.63 ms | 290 | 290 |

Hot cached SearchBench runs were ignored because the search result cache makes
them near-zero and not representative of first-screen filtering work.

## Outcome

Japanese filtering no longer accepts a merged display group just because a
non-matching line in the same timestamp group is Japanese. First-screen search
still filters during candidate collection, and exact counting keeps using the
same line-level rule.
