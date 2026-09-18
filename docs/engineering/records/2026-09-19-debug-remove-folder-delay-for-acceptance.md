# Debug Remove Folder delay for acceptance

Human-owned documents:

- `docs/human/requirements/20260919-Engineering-Debug Remove Folder Delay For Acceptance.md`
- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md` (the requirement this helps accept)

## Why

A Remove Folder task is one database transaction and finishes almost at once, so its running state — the In Progress card without a Remove action, the disabled File page controls and rename menus, and playback continuing while it runs — could not be looked at in the App.

## What changed

- In a Debug build, a Remove Folder task first waits the number of seconds in `CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS`, then removes as before. The wait sits at the start of the removal task itself, so the clean-ups of a removed or interrupted Add Folder, which call the removal executor directly, never wait.
- Unset, non-numeric, non-finite and non-positive values mean no wait. The block is compiled only under `DEBUG`, so a Release build does not read the variable.
- Temporary: it goes once the task concurrency requirement is accepted.

Launch:

```bash
cd apps/macos-native && CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS=15 swift run CueSeeker
```

File: `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`

## Verification

- `swift build` and `swift build -c release --product CueSeeker` both compile. The variable name is present in the Debug binary and absent from the Release binary.
- Without the variable, the removal, addition and nested-root tests pass (33 run together); the two failures in that run are `excerptTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedExcerpt`, the environment-sensitive Excerpt waits that fail in every full run and do not touch this code.
- No automated test sets the variable: it is process-wide, and setting it inside the parallel test run would slow every other removal test. The 15-second wait itself is left to the owner's in-App check.
