# Playback continues when content leaves the database

Human-owned documents:

- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md`
- `docs/human/design/Data.md` (补充说明 7, which the requirement replaces until the design is updated after acceptance)

## Step 1: one Debug delay for Add Folder, Index and Remove Folder

### What changed

- The Remove Folder delay moved out of the removal itself into the three task runners. In a Debug build, Add Folder, Index and Remove Folder each wait the seconds in `CUESEEKER_DEBUG_TASK_DELAY_SECONDS` before starting their work; the task shows as running meanwhile.
- The take-backs of an unfinished Add Folder (removed while running, or left by the previous launch) call the removal executor directly, so they never wait.
- `CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS` is gone. The switch stays for later acceptance work rather than being removed after this one.

Launch:

```bash
cd apps/macos-native && CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker
```

File: `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`

### Verification

- `swift build` compiles.
- No automated test sets the variable, for the reason the 2026-09-19 record gives: it is process-wide and would slow every other task test in the parallel run. The wait itself is left to the owner's in-App check.
