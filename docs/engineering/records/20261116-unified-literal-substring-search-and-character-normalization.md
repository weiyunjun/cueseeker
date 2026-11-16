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
- **Schema `69 -> 70` Migration & Headless Cold Search Benchmark (`SearchBench --headless-cold`, 5 rounds, isolated copy of debug library dataset with 638 subtitle files under configured library folder scope, `wal_checkpoint(TRUNCATE)` prior to run)**:
  - One-time `69 -> 70` FTS rebuild + optimize migration on isolated dataset: `1326.10 ms` (`Open connection` reported by `SearchBench`, database `433M -> 438M`).

| Query | Baseline Hits / Files (`Schema 69`) | Post-Change Hits / Files (`Schema 70`) | Baseline 1st / Full (`Schema 69`) | Post-Change 1st / Full (`Schema 70`) | Baseline Pure Backend 1st / Full | Post-Change Pure Backend 1st / Full |
| --- | ---: | ---: | --- | --- | --- | --- |
| `大丈夫` | 1462 / 498 | 1464 / 498 (+2) | 148.84 ms / 189.94 ms | **140.05 ms** / 223.87 ms | 44.61 ms / 85.71 ms (DB 85.10 ms) | **32.56 ms** / 116.39 ms (DB 115.81 ms) |
| `今日` | 2301 / 498 | 2301 / 498 | 126.44 ms / 166.31 ms | 143.20 ms / 248.29 ms | 21.83 ms / 61.70 ms (DB 60.65 ms) | 34.34 ms / 139.42 ms (DB 138.45 ms) |
| `の` | 76817 / 637 | 77679 / 637 (+862) | 125.19 ms / 612.94 ms | 126.42 ms / **499.56 ms** (-113.38 ms) | 21.56 ms / 509.32 ms (DB 457.73 ms) | **19.47 ms** / **392.61 ms** (DB 342.76 ms) |

  - Phase diagnostics confirmed `fts_hits` (`~0.8-1.6 ms`) and zero-allocation `line_validation` (`~3.9 ms` for `大丈夫`, `~6.1 ms` for `今日`) remain fast on cold runs; the round-to-round `~100 ms` variance seen on `大丈夫`/`今日` full completion occurred inside SQLite `F_NOCACHE` `cue_lines` / `count_progress` disk page reads immediately after the benchmark's 100ms debounce sleep (without debounce sleep, cold `searchPage` phase totals ran consistently in `38.6-41.5 ms` for `大丈夫` and `42.0-53.6 ms` for `今日`). High-cardinality `の` improved full completion by `-18.5%` despite recovering `862` additional previously missed boundary matches.

## Outcome

All Search, Excerpt, Filter, and Library/Excerpt overview matching now shares one NFKC-based literal substring and character-normalization contract backed by single-character FTS5 indexing (`Schema 70`) and a zero-allocation UTF-8 validation fast path. Pending user end-to-end UI acceptance on the unmodified real database.
