# Icon line width table mirrors the registry

Human-owned documents:

- `docs/human/requirements/20260912-Engineering-Icon Line Width Table Mirrors The Registry.md`
- `docs/human/design/Icon Registry.md`

## Why

`AppIconLineWidth.bySize` says in its own comment that it mirrors the size and line width table in `Icon Registry.md`, and the registry says a size the table does not list must not be used. The mirror was missing the registry's 20px row. Nothing draws an icon at 20pt today, so nothing misbehaved, but the next 20pt icon would have hit the assertion that fires for an undocumented size — a Debug crash, and in Release a silent fall back to the master width. The owner set the 20px line to 1.30px, the same as 18px, before this change.

Classified as platform UI: the table is a presentation constant. No product semantics move.

## What changed

- `AppIconLineWidth.bySize` gained `20: 1.30`, so its size set is the registry's: 14, 16, 18, 20, 21, 23, 31, 42, 47, 57.
- A new test pins the whole table against the registry's values, so a future drift in either direction fails instead of waiting for a draw. Its comment says to update it with the document.
- Nothing else changed: no icon's drawn size moved and no 20pt use site was added.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/AppIcon.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/AppIconAssetTests.swift`

## Verification

`lineWidthTableMirrorsTheIconRegistry` compares the table to the registry's ten rows and passes. `everyIconResolvesAtEveryDocumentedSize` already walks every icon at every size in the table, so it now renders all of them at 20pt as well and passes — that is the assertion path exercised for real, not just the lookup. Icon suite: 5 tests, all passing.

`swift test`: 1206 tests, 15 failures. Fourteen are the names that fail on a clean `584404ea` tree — the native playback timeline, audio, presentation and auto-pause cases, the refresh-scope counts, the Debug E2E scene-geometry cases and the persistence migration case. The fifteenth is `libraryFolderRemovalAndIndexingRejectEachOther`, one of the two tests that flip between runs under the full suite in both directions and pass when run alone. None reads the icon table.

No App pass: the change draws nothing new, and the rendering it enables is covered by the test that builds every icon at 20pt.

Outcome matched expectations.
