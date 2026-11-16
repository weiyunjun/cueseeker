# 2026-11-16 Unified Literal Substring Search and Character Normalization

- **Covering Requirement**: `docs/human/requirements/20261116-Feature-Unified Literal Substring Search And Character Normalization.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/02_git_workflow.md`
  - `docs/engineering/04_architecture_rules.md`
  - `docs/engineering/06_testing_rules.md` (Section 9)
  - `docs/human/design/workbench/Search and Filter.md`
  - `docs/human/design/playback/Command Panel.md`
  - `docs/human/design/workbench/Excerpt and Export.md`
  - `docs/human/design/data/Data.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `ea45df0`, requirement commit `df70274`)

## Scope

1. Unify all Search, Excerpt, Filter, and Library/Excerpt overview text normalization onto one shared rule: Unicode `NFKC` compatibility normalization (`precomposedStringWithCompatibilityMapping` followed by `precomposedStringWithCanonicalMapping` so halfwidth voiced/semi-voiced kana marks compose deterministically), strictly scoped 3-group punctuation mapping (`\u{301C}` -> `"~"`, `\u{22EF}` -> `"..."`, `\u{2018}`/`\u{2019}` -> `"'"`, `\u{201C}`/`\u{201D}` -> `"\""`), locale-independent `.lowercased()`, and Unicode whitespace collapsing to single ASCII `" "` (with query edge trimming).
2. Preserve diacritics (`Mère` vs `Mere`), Japanese voiced/semi-voiced marks and small/large kana (`が` vs `か`, `っ` vs `つ`), hiragana/katakana distinctions, Simplified/Traditional Chinese distinctions, and corner-bracket vs straight-quote distinctions (`「」` vs `""`), while guarding fallback substring matches against slicing base characters away from trailing combining scalars (`String.Index(_, within:)`).
3. Replace implicit FTS operator parsing and token-prefix vs CJK-substring branching with single-character FTS5 tokenization and exact literal contiguous substring matching (treating operators, quotes, colons, asterisks, symbols, and CJK-Latin boundaries literally), migrated cleanly at `Schema 69 -> 70` without bumping `SubtitleCueIndexingRules.algorithmVersion` or adding redundant normalized text columns.
4. Preserve cold-search throughput via a zero-allocation UTF-8 streaming normalization/matching fast path during candidate cue-line verification.

## Summary of Changes

1. **Unified Normalization, FTS Query Planning, Zero-Allocation UTF-8 Fast Path, and Excerpt Matcher (`apps/macos-native/Sources/CueSeekerCore/SearchQueryPlanner.swift`)**:
   - Added `normalizeQuery(_:)`, `normalizeText(_:)`, `matchesNormalized(_:normalizedQuery:)`, and `segmentForFTS(_:)`, collapsing `LineMatchRule` to `.literalSubstring(normalizedQuery:normalizedUTF8:)`.
   - Updated `plan(for:)` to split normalized queries on `" "` and expand each non-empty segment into a double-quoted single-character FTS5 phrase (`""`-escaped) joined by `" AND "`, eliminating `latinPrefix`, `orderedLatinTokens`, `cjkSubstring`, and `explicitFTS`.
   - Updated `vocabularyTerms(in:)` (consumed by `SearchDatabase+FTSDiagnostics`) to emit unique normalized single-character extended grapheme cluster terms.
   - Added `fastNormalizeUTF8` and `containsUTF8Bytes` over invariant ASCII and safe CJK/kana UTF-8 scalar ranges, avoiding Foundation `NFKC`/lowercasing heap allocations for candidate rows on the hot path while falling back seamlessly when arbitrary combining/compatibility/non-ASCII-case scalars appear.
   - Aligned `SubtitleSearchQueryMatcher.matches(_:query:)` to normalize queries and evaluate literal substring matching through the same shared rule.

2. **Single-Character FTS5 Schema, Indexing, and `69 -> 70` Migration**:
   - `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift`: incremented `currentSchemaVersion` from `69` to `70`, extracted shared `subtitleCueGroupsFTSTableSQL` with `tokenize="unicode61 remove_diacritics 0 categories 'L* N* P* S* M*'"`, allowed `previousVersion == 69`, and wired `migrateSchema69To70`.
   - `apps/macos-native/Sources/CueSeekerCore/SearchFTSRows.swift`: applied `SearchQueryPlanner.segmentForFTS` in both `insert` and `rebuild(on:)`, reusing one prepared `INSERT INTO subtitle_cue_groups_fts` statement across rows during rebuild.
   - `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap+Migrations.swift`: implemented `migrateSchema69To70(on:)` inside a single transaction to recreate `subtitle_cue_groups_fts`, run `SearchFTSRows.rebuild(on:)`, run `INSERT INTO subtitle_cue_groups_fts(subtitle_cue_groups_fts) VALUES('optimize');` (preserving fixture FTS rows when `subtitle_cue_groups` is absent), and advance `PRAGMA user_version = 70;` without touching `subtitle_cue_lines`, covering indexes, or `SubtitleCueIndexingRules.algorithmVersion`.

3. **Overview Name Matching and Search Filter Consistency**:
   - `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseModels.swift`: replaced `.diacriticInsensitive`/`.widthInsensitive` comparison in `OverviewNameSearchMatcher.matches` with `SearchQueryPlanner.normalizeQuery` + `SearchQueryPlanner.matchesNormalized` so Japanese dakuten/handakuten remain distinct and `~`/`...`/smart quotes normalize consistently.
   - `apps/macos-native/Sources/CueSeekerCore/SubtitleSearchFilterSet.swift`: updated `SubtitleSearchFilterRule` `signatureValue` (`cacheSignature`) and `.is` / `.isNot` / `.contains` / `.doesNotContain` across scalar and set evaluations to apply `SearchQueryPlanner.normalizeQuery` and `SearchQueryPlanner.matchesNormalized`.

4. **Pure-Logic Unit & Integration Tests**:
   - `apps/macos-native/Tests/CueSeekerCoreTests/SearchQueryPlannerTests.swift`: updated planner/vocabulary/matcher expectations and added normalization fast-path equivalence and combining/grapheme-boundary cases.
   - `apps/macos-native/Tests/CueSeekerCoreTests/SearchDatabaseTests.swift`: updated legacy operator/word-prefix tests for literal substring semantics and added `unifiedLiteralSubstringSearchAndNormalizationMatrixPassesAllCases` covering all 71 requirement verification cases (`#01`-`#71`).
   - `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseBootstrapTests.swift`: updated expected schema version to `70` and added `schema69UpgradesTo70RebuildingSingleCharacterFTSWithoutScanningMediaFiles`.
   - `apps/macos-native/Tests/CueSeekerCoreTests/SubtitleSearchFilterSetTests.swift` and `ExcerptDatabaseTests.swift`: added normalization and literal substring parity coverage for filters, `SubtitleSearchQueryMatcher`, and `OverviewNameSearchMatcher`.

## Verification

- **Build checks**:
  - `swift build --package-path apps/macos-native`: passed (`0` errors).
  - `swift build --package-path apps/macos-native -c release --product SearchBench`: built release benchmark executable.
- **Filtered headless pure-logic tests**:
  - Command: `swift test --package-path apps/macos-native --filter "SearchQueryPlannerTests|SearchDatabaseTests|DatabaseBootstrapTests|SubtitleSearchFilterSetTests|ExcerptDatabaseTests|LibraryDatabaseTests|SubtitleIndexerTests|SearchStoreTests|ExcerptPresentationTests|URLSchemeSearchRoutingTests|PlaybackSearchOverlayTests"`
  - Result: `241` tests passed in `2.250` seconds (`0` failures, `0` skipped, no window-popping suites invoked).
- **Schema `69 -> 70` Migration & Headless Cold Search Benchmark (`SearchBench --headless-cold`, 5 rounds back-to-back on isolated snapshots of the 638-file library dataset, `wal_checkpoint(TRUNCATE)` prior to run)**:
  - One-time `69 -> 70` FTS rebuild + optimize migration on isolated dataset: `1326.10 ms` (`433M -> 438M`).

#### 1. End-to-End Full Chain Cold Benchmark (5 Rounds Average + Raw, incl. 100ms Debounce)

| Query | Hits / Files (`69 -> 70`) | `Schema 69` 1st Avg (Raw, ms) | `Schema 70` 1st Avg (Raw, ms) | `Schema 69` Full Avg (Raw, ms) | `Schema 70` Full Avg (Raw, ms) |
| --- | --- | --- | --- | --- | --- |
| `大丈夫` | `1462/498 -> 1464/498` (+2) | 175.35 ms (`221.68, 136.26, 118.57, 261.53, 138.73`) | **137.30 ms** (`145.01, 124.60, 138.65, 132.80, 145.45`) | 332.38 ms (`591.21, 267.60, 149.09, 395.75, 258.26`) | **207.82 ms** (`261.60, 154.36, 208.92, 158.92, 255.29`) |
| `今日` | `2301/498 -> 2301/498` (0) | 141.87 ms (`203.31, 124.51, 119.83, 124.73, 136.98`) | **127.22 ms** (`117.81, 121.57, 123.34, 135.60, 137.79`) | 257.54 ms (`555.44, 160.36, 162.12, 159.83, 249.94`) | **197.13 ms** (`158.47, 161.22, 156.73, 251.05, 258.19`) |
| `の` | `76817/637 -> 77679/637` (+862) | 125.36 ms (`124.62, 122.42, 127.10, 125.21, 127.45`) | **124.35 ms** (`122.19, 125.02, 129.26, 124.15, 121.11`) | 629.48 ms (`640.18, 646.30, 640.89, 607.75, 612.30`) | **518.61 ms** (`507.94, 485.05, 564.17, 526.04, 509.83`) |

#### 2. Pure Backend Breakdown (5 Rounds Average + Raw, excl. Debounce)

| Query | `Schema 69` Backend 1st Avg (Raw, ms) | `Schema 70` Backend 1st Avg (Raw, ms) | `Schema 69` Backend Full Avg (DB / Commit; Raw, ms) | `Schema 70` Backend Full Avg (DB / Commit; Raw, ms) |
| --- | --- | --- | --- | --- |
| `大丈夫` | 71.73 ms (`116.77, 33.44, 17.30, 156.51, 34.65`) | **33.61 ms** (`39.98, 20.57, 37.98, 29.10, 40.42`) | 228.76 ms (`227.88 / 0.88`; `486.30, 164.78, 47.81, 290.73, 154.18`) | **104.13 ms** (`103.52 / 0.61`; `156.57, 50.34, 108.25, 55.23, 150.26`) |
| `今日` | 39.29 ms (`100.21, 23.41, 19.54, 20.15, 33.12`) | **23.52 ms** (`16.29, 19.62, 18.31, 30.58, 32.78`) | 154.96 ms (`153.85 / 1.11`; `452.35, 59.26, 61.83, 55.25, 146.08`) | **93.43 ms** (`92.05 / 1.38`; `56.95, 59.26, 51.71, 146.03, 153.18`) |
| `の` | 21.72 ms (`22.64, 17.42, 22.87, 20.18, 25.50`) | **20.86 ms** (`20.04, 20.01, 24.22, 19.60, 20.42`) | 525.84 ms (`473.52 / 52.32`; `538.20, 541.29, 536.67, 502.72, 510.35`) | **415.12 ms** (`366.99 / 48.13`; `405.78, 380.04, 459.14, 421.48, 409.14`) |

  - Steady-state cold floor remained unchanged (`~48-55 ms` for `大丈夫`, `~51-61 ms` for `今日`), while high-cardinality `の` improved full completion across all 5 rounds (`525.84 ms -> 415.12 ms` pure backend, `-21.1%`) despite recovering `862` previously missed boundary matches (`+2` for `大丈夫`).

## Outcome

All Search, Excerpt, Filter, and Library/Excerpt overview matching now shares one NFKC-based literal substring and character-normalization contract backed by single-character FTS5 indexing (`Schema 70`) and a zero-allocation UTF-8 validation fast path. Pending user end-to-end UI acceptance on the unmodified real database.
