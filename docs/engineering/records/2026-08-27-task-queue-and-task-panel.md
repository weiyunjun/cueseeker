# One task at a time, and a panel that says so

Human-owned documents:

- `docs/human/requirements/20260827-Feature-Task Queue And Task Panel.md`

## Why

Exporting to Anki was fire-and-forget. Each export started its own detached task, so two selections exported at once ran two ffmpeg pipelines against the same disk; nothing on screen said an export was running, how far it had got, or that it had failed — a failure only reached a `print`. There was no way to stop one either.

The requirement turns that into a queue with a face: one task runs at a time, the top bar says how many are left, and a panel shows what is running, what finished, and what did not.

## What changed

### The queue

`TaskQueueStore` owns Current, Completed and Incomplete. Enqueueing inserts a row and starts the task only if nothing else is running; when a task ends the next one starts. That is the whole concurrency rule — there is no executor, no semaphore and no actor beyond the main one the store already lives on, because a queue of one only ever has to answer "is something running".

A task is one command the reader gave, so the destination is chosen where the command is given: the save panel still opens on the Anki button, and the queued card can name the file and folder it is going to write before it starts.

### What survives a launch, and what does not

The history is persisted; the work is not. Schema 45 adds `task_records` — kind, file name, folder, card count, state, error and two timestamps.

Progress is deliberately not a column. It moves once per exported card and means nothing to a later launch, which never resumes a task, so writing it would put the database in the path of every tick for an answer it could never give back.

Running and queued rows are written all the same, and that is what makes the interruption rule work. A row still marked running or queued belongs to a process that is gone, so the next launch closes it out as Incomplete before reading the history. A crash cannot write anything on the way down; the only way to know a task never finished is to have said, in advance, that it had started. The cues a queued export holds stay in memory, which is why the queue is not resumed but retired.

### The panel is a sheet, like the App's other three dialogs

It is presented from the window root beside Edit Cover, the Shiori List Editor and Confirmation, so the dimming, the input barrier and Escape all come from the one modal presentation the App has. It is the fourth member of the existing dialog layer rather than a layer of its own, so the workbench page underneath reads as covered without anything new being ranked.

A confirmation raised from inside the panel is presented by the panel, not written to the app-level holder: a sheet is presented by the surface it belongs to, and the window root is already presenting the panel. That is the stacking case the design has always allowed and nothing had yet used. The panel keeps it in local state, so no second holder exists.

The close button carries `.keyboardShortcut(.cancelAction)`, which is how Edit Cover, the Shiori List Editor and Confirmation already give Escape to their own cancel path.

This was not the first shape. The panel was originally drawn in the window with a hand-painted dim and an event shield, because the accepted requirement asked it to collapse back into the button that opened it and a sheet is animated by macOS. When the owner dropped that animation and asked for an ordinary modal close, the only reason for the second presentation route disappeared with it, and the shield, the dim token, the extra interface layer, the anchor plumbing between the top bar and the panel, and a second keyDown monitor all came out.

### Refreshing only what moved

Progress is its own observable object, one per entry, and only the running card's progress row observes it. A card going from its ninth cue to its tenth re-reads two lines; the tabs, the other cards and the panel frame are not touched.

### Cancellation reaches ffmpeg

Cancelling used to be checked only between cards, so a cancel could sit for several seconds behind the cue already in flight. `runProcess` now adopts its `Process` into a small lock-guarded box and terminates it from the cancellation handler, and adopts it after checking for a cancel that already arrived so a cancelled task never launches one more helper. Whatever error the termination produces on the way down, the store records the outcome the reader asked for: the task they removed is Incomplete with "Cancelled by user", not with a process exit code.

### The tab indicator

The Design System's Tab component gives the indicator `--color-accent`, and the Playback Overlay's Current / Playlist tabs — which the requirement points at — use `--color-playback-module-sidebar-selected`. Those two human-owned statements disagree, and this implementation quietly followed the first, which put a blue underline in a panel whose sibling control has a black one.

Reporting the conflict was the required move and did not happen. The owner has since resolved it in the requirement, which is the more recently modified document: the tabs use the Playback Overlay's selected and unselected colours, and the Design System's Tab entry is to be brought into line when this is accepted.

### Two things found by running the App

The panel's shadow was applied to the panel. SwiftUI casts such a shadow from every leaf inside, which haloed the tab labels, and it rasterized the scroll view's AppKit layer out of the background it was supposed to sit on — the card area was a transparent hole onto the dimmed page. The shadow now belongs to the panel's background shape.

The entry button took the window's focus on launch and showed a focus ring, on any page with no search field and a disabled Back. It is App chrome like the sidebar toggle beside it, so it is `.focusable(false)`, which puts the page's own first control back at the head of the focus order.

### A third, found by the owner: the completion time was not on the trailing edge

The card's secondary line claimed the row — it carried `maxWidth: .infinity` inside the component itself. With one such line per row that looks right, because filling the row is the same as starting at the leading padding. Put two of them in the row that carries the card count and the completion time, and both ask for all the width available: SwiftUI splits it between them and the spacer meant to push them apart gets nothing. The time then sat left-aligned in the right half rather than on the card's trailing edge.

Filling is a decision for the row, not for the line, so the component now sizes to its own text. The single-line rows still start at the leading padding and still truncate at the trailing one, because a `VStack` proposes its own width to them; the count-and-time row now has a spacer with room to work.

The trash button on the first row was left alone. Its 32-point box does sit on the 12-point padding, but its 16-point glyph is centred inside, so the glyph reads 20 points in. That is the Icon Button geometry the accepted Dialog close button already uses, and changing it here alone would put the two out of step.

Files:

- `apps/macos-native/Sources/CueSeekerCore/TaskRecordDatabase.swift` — new. Records, states, and the launch sweep.
- `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift` — schema 45; `task_records` added to the fresh create and to `migrateSchema44To45`, which reads and rewrites nothing.
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskQueueStore.swift` — new. The queue, the progress object, and the export runner seam.
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift` — new. Host, scrim, panel, tabs, cards.
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift` — new. Icon Button plus the count badge.
- `apps/macos-native/Sources/CueSeekerApp/Export/AnkiPackageExporter.swift` — per-card progress callback; process termination on cancel.
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+AnkiExport.swift` — enqueues instead of running.
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift` — opens the task database, owns the store, reports the panel layer.
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift` — the dialog layer's documentation names the panel.
- `apps/macos-native/Sources/CueSeekerApp/Workbench/AppTopbarLayout.swift` — trailing function region.
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift` — entry button in the top bar; the panel's sheet at the window root.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift` — task count badge tokens.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift` — task badge, panel and progress bar metrics.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/TableSandboxRowModelStore.swift` — the Date Added format takes a `Date` too, so the table column and the panel's history cannot drift.
- `apps/macos-native/Sources/CueSeekerApp/Resources/*/Localizable.strings` — task strings in all three languages.
- `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseBootstrapTests.swift`, `IndexPathIdentityTests.swift` — schema expectations follow `currentSchemaVersion` instead of a literal.

Reused rather than added: `WorkbenchIconButton` and its Open state (the filter button's), `WorkbenchBadge` with the watch-status colours, the library progress track and fill, `WorkbenchConfirmationSession`, `WorkbenchScrollView`, `WorkbenchEmptyHint`, and the Playback Overlay's tab geometry.

## Verification

`swift build`: clean.

`swift test`: 1120 tests, 22 of them new and all passing. The failing set was compared against a pristine `HEAD` copy expanded with `git archive` into a temporary directory, so the owner's working tree was never reverted. Baseline: 15 distinct failures — the known native playback timeline, presentation transition, refresh scope, window geometry, submenu and shared-persistence ones. Changed tree: 13 of those 15, plus the 6 suite-parallelism flakes earlier records already describe; `LibraryFolderRemovalTests` passes 8 of 8 alone and `PlaybackSubtitleFocusKeyboardActionTests` 33 of 33 alone. No failure outside the baseline set and no new distinct failure.

The new tests cover the queue's own behaviour through an injected export runner, so no ffmpeg or real video is involved: one task runs while the rest wait, Current keeps the order tasks were started in, a queued card carries the file, folder and count it will write, a finished export moves to Completed and releases the next one, a failed one moves to Incomplete carrying its error, progress is reported on the running task, removing a running task stops it and records the removal rather than the cancellation error, the queue keeps going after that, deleting a record clears it from the history and the database, and a second launch closes out everything the first left running or queued. The database's own tests cover the table, insertion, ordering, state and error write-through, deletion, the launch sweep, and that the history survives reopening the connection.

The panel was driven in the App after it became a sheet. Opening it produces a second window of kind `sheet`, 460 by 440, frontmost over the main window — the same shape Edit Cover and Confirmation produce. The tab indicator and the selected label are the Playback Overlay's black; the header's trailing control is an X. Clicking a card's delete raises a third window, a 360 by 182 sheet stacked on the panel with the panel dimmed behind it, which is the stacking case this change is the first to use; cancelling it returns to the panel alone. Escape closes the panel, and reopening it lands on Current after Completed had been selected.

The trailing alignment was measured on the owner's own Completed records with the Debug E2E controller: the completion time's right edge and the card count's left edge now sit the same 12 points from the card's borders, matching the file name and folder rows above them.

Two tests, `playbackShioriCopiesSettledPrimaryCueAsMarkdownLink` and `screenshotCopiedFeedbackUsesRequiredIconAndText`, began failing between the first run and this one because they compare against hard-coded English feedback text and the App's persisted language is now Chinese. Both fail identically on the pristine `HEAD` copy, so they are environment-driven and not caused by this change.

Behaviour was measured with the Debug E2E controller against the owner's real library. The entry button renders at the top bar's trailing edge on the Shiori page. Clicking it opens the panel: the sidebar, top bar and page dim together, the button holds the accent Open look, and the tab bar, the minimise button and the Current empty state render. Clicking Completed switches the tab. Clicking the page at (500, 650) with the panel open changes nothing underneath and does not close the panel. Escape closes it and the page returns to full brightness. The minimise button closes it and the button returns to Default. Reopening lands on Current after Completed had been selected.

Three acceptance points stay the owner's manual check, for the reason stated before implementation started: the destination is chosen through `NSSavePanel`, a system-owned panel the in-app controller cannot drive, so no automated path reaches an enqueued task. That leaves the progress numbers and bar, the count badge and the interruption case to manual acceptance. No test capability was added for them.

## Open for review

- The entry button's icon is `list.bullet.rectangle`. The requirement does not name one and the owner said the choice needed discussion.
- The three tabs show an empty hint when they have no cards. The requirement does not ask for one; a blank panel on first open seemed worse than a line of text.
- The panel's width and height and the count badge's size and font are new metrics. They are named constants, not literals at the use site, and belong in the Design System when this is accepted.
- The panel draws the shadow the Design System's Dialog anatomy lists, inside a sheet window that already casts one. Confirmation, which was accepted, draws none. One of the two is wrong; deciding which is a Design System question rather than something to settle silently here.
- The close button takes the sheet's focus and shows a focus ring at rest, the same as the other dialogs' close buttons.
