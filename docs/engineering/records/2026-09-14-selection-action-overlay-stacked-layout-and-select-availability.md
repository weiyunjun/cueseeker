# Selection Action Overlay stacked layout and Select availability

Human-owned documents:

- `docs/human/requirements/20260914-UI-Selection Action Overlay Stacked Layout And Select Availability.md`
- `docs/human/design/UI Design System.md` (Selection Action Overlay, Selection Action Overlay Layout, Search / Excerpt Toolbar Layout, Checkbox, Icon Button; to be updated by the owner after acceptance)

## Why

At the minimum window width, entering Select Mode widened the whole page and pushed the search field, the filter button and Select out of the window. The overlay laid its count and four actions out on one line whose text may not shrink, so its natural width (about 640 points in Chinese) was wider than the page's 416 points of content. It was a sibling of the table in a stack, and a stack is as wide as its widest child; the frame above it does not clamp an oversized child, and the page frame is top-leading aligned, so everything ran off the right edge. The design only said the container's width follows its content and had no rule for content wider than the table.

The owner also asked for the count to show the selectable total, for invalid rows to be unselectable, and for Select to be unavailable when nothing can be selected.

Classified as platform UI and UX. Nothing in `CueSeekerCore` changes.

## What changed

- The overlay is drawn as the table's overlay instead of beside it in a stack. An overlay is offered the table's size and never feeds back into the page's size, so no content can widen the page again. On the Excerpt List detail, where the table runs to the window edge, the overlay takes the page margins the table's content region has, so it is bounded the same way as on Search.
- The count sits above the actions, both left-aligned, `--spacing-2` apart. The actions wrap onto further lines when the table is too narrow, `--spacing-2` between items and between lines; titles are never cut. The container is as wide as its widest line.
- The wrapping layout already existed, privately, for the Playback Cue footer's actions. It moved to `Shared/WrappingFlowLayout.swift` with a leading or trailing alignment; the footer keeps trailing and behaves as before.
- The count reads `已选取 %d / %d 行`, `已選取 %d / %d 行`, `%d / %d rows selected`: selected rows over selectable rows. The old one/other keys are replaced by one key.
- The row snapshot records its unavailable rows once, when it is built, with the same test the rows use for their unavailable state (`Excerpt.unavailableReason`). A changed Cue is not unavailable. Search rows never are.
- Row selection takes the unavailable rows as unselectable: a click or Space on one changes nothing, select all leaves them out, a Shift range passes over them, and the header is checked once every selectable row is. The anchor is the highest row the operation actually selected. Their checkbox is drawn disabled and takes no focus ring.
- Select Mode needs the exact result set and at least one selectable row, on both pages. The existing exit when that stops holding is unchanged.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WrappingFlowLayout.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueFooter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSelectionActionOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/TableSandboxRowSelectionState.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/TableSandboxRowModelStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchExcerptTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/SchemaWorkbenchCountSummaryTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/TableSandboxRowSelectionStateTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/TableSandboxRowModelStoreTests.swift`

## Verification

Unit tests: the count text and the Select Mode condition (no exact results, or no selectable row, keeps it closed); unselectable rows ignore toggle and Shift click; select all skips them, sets the anchor to the last selectable row and checks the header; a header with no selectable row stays unchecked; a Shift range skips them from nothing selected and from an anchor; a Shift range after select all keeps them out; the resident Excerpt snapshot marks only the unavailable row, not the changed one. The affected suites: 54 tests, all passing.

`swift test`: 1223 tests, 13 failing. Twelve are the set earlier records list as failing on the baseline: the seven native playback timeline, audio, presentation and auto-pause cases, the two Debug E2E scene and window-width cases, and three of the four refresh-scope integration cases. The thirteenth, `playbackExcerptCopiesSettledPrimaryCueAsMarkdownLink`, also fails when run alone: it expects the English `Deep Link Copied` and the app under test resolves to Chinese `已复制 Deep Link`. This change touches neither that feedback nor the language setting; it was not re-run on a clean tree.

In the App: Debug E2E controller, `.build/debug/CueSeeker --cueseeker-debug-e2e` under a PTY, the owner's real library, Chinese, Light, 2×, with the existing `setWidth`, `click`, `keyPress` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures.

1. Excerpt List detail `test` (4 rows), window 480 points: entering Select Mode leaves the cover, the search field, filter and Select exactly where they were. The overlay shows `已选取 0 / 4 行` above the actions, which wrap into two lines (导出到 Anki, 复制 Deep Links / 复制表格, 退出) with every title whole. Select all shows `已选取 4 / 4 行` and a checked header.
2. The same page at 1445 points: the count above, all four actions on one line.
3. Search at 480 points: an empty query and a query with 0 results both show Select disabled, and clicking it does not enter Select Mode. `ave` (241 results): Select Mode shows `已选取 0 / 241 行`, the actions wrap the same way, and the page is not widened.

The window was returned to 1445 points, Select Mode exited and the query cleared.

Not verified in the App: invalid rows, since no list at hand is known to contain one — the unselectable behaviour, the disabled checkbox and the all-invalid Select state are covered by the unit tests above only; the English and Traditional Chinese copy, since the language setting is outside the captured scene.
