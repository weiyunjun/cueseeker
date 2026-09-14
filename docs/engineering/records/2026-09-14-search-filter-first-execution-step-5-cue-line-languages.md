# Search Filter-First Execution — Step 5: Languages Stored Per Cue Line

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 3.1, 4.1)
- `docs/human/design/Data.md` (section 4, language analysis is part of the published index data)

## Starting Point (commit `00bc9b02`, after Step 4)

Step 4 pushed duration, character length and watch state into the row reads but left the language filter in Swift, so a language-only selection still read every line of every hit. The owner rejected that: the language of a cue is known when the file is indexed, and the requirement puts every Filter Menu selection into the search itself. Reading the code showed why the language could not be pushed down: no table stored it. Three copies of a query-time rule derived it from the file and style detections, the cue group languages and, for a multi-line ASS group without detections, a fresh run of the language recognizer — in Search, in cue content assembly, and as a SQL approximation in the facet count cache that could not express the recognizer branch.

## Implementation

- New table `subtitle_cue_line_languages` (cue id, language code; `unknown` when nothing can be settled), created with schema 49 and cascading with the cue line. `CueLineLanguages` holds the single rule, resolves every line from the file's language analysis while the file is published, inserts the rows next to the cue lines, and reads them in batches.
- Migration 48 → 49 fills the table for the stored lines from the stored detections and cue group languages with the same rule, then rebuilds the facet counts. The table is created before the older migrations run because two of them rebuild the facet counts. On the owner's library the fill wrote 700,613 rows; the App was ready 6 s after launch including the build.
- Search, cue content assembly and the facet count cache read the table. The three query-time rules, the per-file detection loads and the per-group language loads are deleted; the search's SQL condition on cue group languages is gone too.
- The language selection joins the pushed-down filters: the row read keeps only lines that have one of the checked languages, and the benchmark's own language filter uses the same condition. A line's languages in a result are now never an empty set; what used to be empty is `unknown`, which the facet snapshot and the tags already treated the same way.

## Verification

- `swift test --filter "SearchDatabaseTests|DatabaseBootstrapTests|SubtitleIndexerTests|CueFacetCountCacheTests|CueContentDatabaseTests|IndexPathIdentityTests|SearchStoreTests|PlaybackSubtitleDatabaseTests"`: 146 tests pass, all existing language expectations unchanged. New `searchPageFiltersLanguagesInTheRowReadsAndCountsThemFromTheStoredTable` checks a language selection and the benchmark's language filter return only the English file, that the unfiltered snapshot and the facet count cache both count two Japanese and one English line, and that results carry the stored languages. New `migratesSchema48ByStoringTheLanguageOfEveryCueLine` indexes an ASS file with two detected styles and one unstyled line, wipes the table, migrates from 48 again and expects the identical rows (`zh-Hans`, `ja`, `unknown`) and language facet counts.
- Full `swift test`: 1229 tests, 28 issues in 15 tests, the same pre-existing environment-sensitive set as after Step 4 (native playback, Debug E2E scene and width, Library folder removal, Excerpt scroll anchor and refresh-scope counters); none in Search, indexing or migration.
- SearchBench on a fresh copy of the baseline database, which migrated through schemas 48 and 49 on open (9.0 s together): `の` 10.5 / 1192 ms, `今` 4.1 / 150 ms, `大丈夫` 4.1 / 27.9 ms hot medians (visible window / exact). The unfiltered exact scan of `の` is about 0.1 s slower than Step 4's 1075 ms because it now reads the language rows of every line in a chunk instead of one detection row per file; the first page is unchanged.
- App level through the E2E controller after the live database migrated (backup taken first as `CueSeeker.sqlite.backup-20260914-before-schema-49-cue-line-languages`), first page e2e / db → complete e2e / db:

| Selection | `の` result |
| --- | --- |
| Character `31+` (owner's persisted selection), 2,766 results | 188 / 74 → 837 / 606 ms |
| none, 77,145 results | 77 / 32 → 3423 / 2200 ms |
| Language `English` only, 938 results | 193 / 55 → 914 / 689 ms |
| Character `31+` again after restoring it | 209 / 68 → 892 / 645 ms |

- With `English` checked the menu showed Duration 63 / 159 / 253 / 463 and Character 431 / 378 / 107 / 22, both summing to 938, and Language English 938, Japanese 76,097 (capture `step5-english-only.png`). Main-thread gaps of 250 ms or more appeared only during the two unfiltered scans. The owner's `31+` selection was left checked as found (capture `step5-restored.png`).

## Outcome

Matched expectations: a language-only selection now completes in under a second on `の` instead of about two, every Filter Menu card is applied inside the row reads, and one stored rule replaces three derived ones.
