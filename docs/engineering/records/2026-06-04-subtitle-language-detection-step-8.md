# Subtitle Language Detection Step 8

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Fixed language detection to match the updated requirement for full-text,
cleaned subtitle analysis:

- Bumped `SubtitleLanguageRecognizer.algorithmVersion` to `2` so existing
  language manifests are invalidated and files are re-analyzed.
- Changed language detection from per-segment voting to one
  `NLLanguageRecognizer` pass over the merged cleaned text for the SRT file or
  ASS style Name.
- Added the generic Chinese code `zh` and the required rule that
  `zh-Hans + zh-Hant >= 0.9` with both scripts individually below `0.9`
  produces `zh`.
- Kept script-based supplemental detection only for clear mixed-language cases,
  while avoiding redundant `zh + zh-Hans` and avoiding generic `zh` inference
  from Japanese kanji-only lines.
- Updated Chinese search filters so `中文`, `简体中文`, and `繁体中文` match the
  required combinations of `zh`, script-specific Chinese, and `unknown`.
- Added tests for merged cleaned ASS style text, Chinese confidence
  recombination, non-redundant script-specific Chinese output, and `zh` search
  matching.

## Verification

- `swift test --filter SubtitleLanguageRecognizerTests` passed 7 Swift Testing
  tests.
- `swift test --filter SubtitleLanguageAnalyzerTests` passed 6 Swift Testing
  tests.
- `swift test --filter searchLanguageFilterMatchesCueGroupLanguagesOrUnknown`
  passed 1 Swift Testing test.
- `swift test` passed 202 Swift Testing tests and 7 XCTest tests.

## Data Comparison

The old values are read-only queries from the existing app database at
`/Users/weiyunjun/Library/Application Support/CueSeeker/CueSeeker.sqlite`.
The new values are from a temporary `/private/tmp` Swift probe that imports the
current `CueSeekerCore` source and analyzes the original subtitle files without
writing to the user database.

| Sample | Scope | Old algorithm | Old language | Old confidence | New algorithm | New language | New confidence |
| --- | --- | ---: | --- | ---: | ---: | --- | ---: |
| `BanG Dream! - 01` | `Default` | 1 | `unknown` | 0.870869 | 2 | `zh-Hans` | 1.000000 |
| `BanG Dream! - 01` | `OPCN 3` | 1 | `unknown` | 0.870599 | 2 | `en+zh-Hans` | 1.000000 |
| `Girls Band Cry - 01` | `Dial_CH` | 1 | `zh-Hans` | 0.913065 | 2 | `zh-Hans` | 0.999956 |
| `Girls Band Cry - 01` | `Title` | 1 | `unknown` | 0.486884 | 2 | `zh-Hans` | 0.925793 |
| Problem short sentence | direct NLL split | 1-style behavior | `unknown` | 0.604883 | 2 | `zh` | >= 0.9 |

For the short sentence `要是没我在你就成真的小偷了哦 你的明白？`, Apple
NaturalLanguage returns `zh-Hans=0.604883`, `zh-Hant=0.392704`, and
`ja=0.002413`. The new rule combines the Chinese scripts to satisfy the
`zh` threshold instead of treating the sentence as unknown.

## Outcome

The language detector now uses the same cleaned text that is stored in the
database and evaluates it at the file/style scope required by the product
document. The previously visible false `unknown` cases are corrected after
reindexing, while line-level search language filtering remains unchanged from
Step 7.
