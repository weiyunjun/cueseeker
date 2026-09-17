# Five icons change their drawing, and a star joins the set

Human-owned documents:

- `docs/human/requirements/20260918-UI-Icon Replacements And Anki Star.md`
- `docs/human/design/Icon Registry.md`

## Why

Five glyphs had drifted from what they stand for. The bookmark said "saved for later" where Excerpt means something the owner picked out and keeps. The photo frame said "a picture" where the button takes one. Two different actions — turn on Select Mode in the Workbench, and open the Collage editor over the player — were both drawing the same pencil-on-a-page, so neither told you which one it was. And the Task entry wore a ticked checklist, which reads as a list of things you tick off rather than what the panel actually is: a queue of background jobs the app runs one at a time, with a progress bar and a history.

The sixth is new. The owner wants Anki's five-pointed star available for work that has not started yet.

## What changed

**Nothing moved and nothing resized.** Every replacement is a different file behind the same `AppIcon` case at the same call site, drawn at the same size with the same colour token. No view learned a new literal; the registry stayed the one place a glyph is named.

**Excerpt is a heart, everywhere it appears.** Six call sites carried the bookmark — the sidebar, the Command Panel's Recent Excerpt Lists row, the table row menu's Remove Excerpt, the 57px list cover placeholder, the Workbench Toast and the playback feedback overlay — plus the filled cut the overlay draws when a cue is saved. All seven now draw `heart` and `heart-fill`. One semantic, one glyph: had only the sidebar changed, the same action would have worn two shapes depending on where you did it.

**The screenshot button is a camera, and so is its feedback.** The control bar button and the "screenshot copied" overlay are the action and its confirmation, so they change together.

**The two pencils separate.** Collage takes `images-square`, a stack of pictures, which is what the editor assembles. Select Mode takes `list-checks`, freed by the Task entry. `note-pencil` is left with one use, Edit List, and its meaning in the registry narrows to "edit".

**The Task entry is a tray.** A tray holds things being worked through, which is what the queue is, and it carries the remaining-count badge without arguing with it. `queue` was the obvious name and the wrong picture: Phosphor draws it as a list with a play triangle, and this app already has a Playlist in the Playback Overlay for that to be confused with.

**`anki-star` is drawn here rather than taken from Phosphor.** It is the star from Anki's mark: solid, tilted 18 degrees counter-clockwise so the top point leans left, with the document body and the white outline of the original dropped so the interface can tint it like every other icon.

Solid is the point of it — the original is a filled shape — but the registry defines Fill as a *state* variant that carries no lines and stays out of the line width table, and this icon has no stroked cut to be a state of. So it is drawn as a filled path that also strokes its own outline at the master width, with the round caps and joins the spec asks for. It is solid, its corners are round like the original's, and it needs no change to how icons are assembled or tested: the line width rewrite finds its one `stroke-width="16"` and scales it with the size like any other master.

**The star has no call site yet.** The requirement reserves it, so the case exists and is marked reserved in the source. The asset tests already resolve every case at every documented size, so it is checked rather than dead.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/AppIcon.swift` — `bookmarkSimple` → `heart`, `image` → `camera`, new `imagesSquare`, `tray`, `ankiStar`
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/` — new `heart.svg`, `heart-fill.svg`, `camera.svg`, `images-square.svg`, `tray.svg` from Phosphor's stroke originals, and `anki-star.svg` drawn to the same spec
- 10 view and model files under `apps/macos-native/Sources/CueSeekerApp/`
- 4 test files under `apps/macos-native/Tests/CueSeekerAppTests/`

`bookmark-simple.svg`, `bookmark-simple-fill.svg` and `image.svg` are no longer referenced by anything. They stay in the tree for the owner to remove.

## Verification

- `swift build` clean, no warnings.
- `swift test`: 1258 tests, 28 failures in the parallel run. Every one of them was re-run alone: all pass except `excerptTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedExcerpt`, which are the pair recorded as failing on a clean `HEAD` in `2026-09-10-icon-system-migration-to-phosphor-svg.md` under their earlier Shiori names. The rest are the known parallel-execution and audio-device set. None of them come from this change.
- `AppIconAssetTests` resolves all six new and changed glyphs at every documented size, checks `heart-fill` as a state variant, and confirms `anki-star` draws its one line at the master width — so the filled-and-stroked construction is covered by the same rule as every other master.
- Four tests asserted the old glyph by name and now assert the new one: the two Excerpt toast assertions, the row menu's Remove Excerpt icon, and the screenshot feedback icon.
- Visual acceptance is the owner's, in the running app, per the requirement.

## Outcome

Matched expectations, with one thing decided along the way rather than beforehand.

The requirement asks for a solid star and the registry defines Fill as a state variant. The two do not meet: a solid-only icon is neither a stroke master nor a state of one. Drawing it as a filled path that strokes its own outline satisfies both readings and leaves the assembly and the tests untouched. The alternative — a Fill-only asset with no regular cut — would have needed a new rule in the registry for fill-only icons and a matching change to the two asset tests, which is more machinery than one star is worth. The registry should record which of the two it means when the owner backfills it.

Awaiting owner acceptance before `docs/human/design/Icon Registry.md` and `docs/human/design/UI Design System.md` are backfilled.
