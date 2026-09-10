# The interface draws its own icons

Human-owned documents:

- `docs/human/requirements/20260910-UI-Icon System Migration To Phosphor SVG.md`

## Why

Every glyph in the interface was an SF Symbol named by a string literal written wherever it was drawn. Two things followed from that.

The first is a licence wall. SF Symbols may only be used on Apple platforms, so a Windows build could not carry a single one of them; each of the sixty-odd glyphs would have to be found again from scratch.

The second is that icons were the one part of the design system no document could reach. Colours and sizes already had a token layer that mirrors the design document; icons had sixty-five string literals spread across twenty-one files, of which the design document recorded exactly three. Nothing could be checked, and nothing stopped the next icon from being invented in place.

## What changed

**One list names every icon, and the interface names cases from it.** `AppIcon` holds one case per glyph, its raw value being the Phosphor asset that draws it. No view spells a graphic any more; the parameters that used to carry `systemImage: String` now carry `icon: AppIcon`, so an icon that does not exist is a compile error rather than an empty square at runtime.

**Stroke weight follows the size the caller asks for, not the icon.** Vector art scales its strokes with it, so one master drawn for 24pt looks thin at 12pt and heavy at 32pt — across the six sizes the design system uses, a single weight would vary by 2.7×. `AppIconWeight.tier(forSize:)` picks Light below 18pt and Regular above, which holds the drawn stroke between 1.13pt and 1.50pt everywhere. Because Phosphor ships each weight as its own outlined artwork, this is a file choice rather than a number to tune.

**Fill is a state, not a size.** The filled cut says "this is on" — a ticked box, a playing transport, a saved bookmark — so callers ask for it directly and it bypasses the size tier.

**The assets are plain SVG files.** SwiftPM does not run `actool`, so an asset catalog is copied rather than compiled and resolves to nothing; this was measured before the approach was chosen. macOS reads SVG through `NSImage` directly, which needs no catalog, no PDF conversion and no external tool. The files are template images, so the existing colour tokens tint them unchanged.

**AppKit drawing shares the same store.** The subtitle table and the collage checkboxes draw through `NSImage` rather than SwiftUI and used to build a symbol configuration per draw. `AppIconStore.tintedImage` returns the glyph already filled with one colour and keeps each icon/size/colour combination, which matters because the table redraws these while scrolling.

**One case of merged meaning.** The subtitle toggle drew a hollow and a filled speech bubble for off and on. Both places that draw it already say the state another way — the control bar through the button's selected background, the feedback overlay through its own sentence — so both now draw the same glyph.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/AppIcon.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/` (new: 125 Phosphor SVGs plus their MIT licence)
- 44 view and model files under `apps/macos-native/Sources/CueSeekerApp/`
- 9 test files under `apps/macos-native/Tests/CueSeekerAppTests/`

## Verification

- `swift build` clean, no warnings.
- `swift test`: 1176 tests. The 15 failures match a clean `HEAD` baseline built from `git archive` and run the same way, so none of them come from this change. They are the pre-existing parallel-execution and audio-device set; each passes when run alone.
- Three tests asserted the old mechanism rather than the result — two compared an `NSImage.SymbolConfiguration` that a rasterised SVG does not carry. They now assert what still holds: the drawn size, and that the glyph arrives already filled with the documented control colour.
- New `AppIconAssetTests` resolves every case at both stroke tiers and every state variant at fill, so a missing or misnamed asset fails the suite instead of drawing nothing.
- Visual acceptance through the Debug in-app E2E controller: Shiori covers and sidebar, Search field and filter, File buttons, Library second level, and the playback control bar. The first pass caught three `.fill` sources that lost their weight in the bulk conversion — the Resume button, the Shiori save feedback, and the primary-button path they share; the second pass confirmed the fix.

## Outcome

Matched expectations. The interface draws from Phosphor everywhere, no graphic name remains as a string literal, and the assets are the portable form a Windows build can carry.

Two things are recorded rather than resolved:

- **The minimum supported system is macOS 13; this machine is macOS 15.** Whether `NSImage` reads SVG directly on macOS 13 is untested. If it does not, the fallback is PDF, which was measured working the same way; the SVG masters stay the source either way.
- **`tray` and `list-bullets` were added although the requirement's table omits them.** Both back branches that cannot currently be reached, and the table left them out for that reason; converting the code wholesale needed them anyway. They cost two files and disappear with the dead branches.

## Follow-up: the sub-24px band, twice

The first pass drew Light below 18pt. In the running app that reads as 0.66–0.84pt of stroke, roughly half of the 1.50pt the playback feedback overlay draws at 24pt, and about half of what the SF Symbols it replaced were drawing at the same sizes. The owner read the two sizes that looked right — the 24pt feedback overlay and the 44pt cover placeholder, both Regular — against the sizes that looked thin, all Light, and asked for everything below 24pt to move to Regular while the sizes above it stay as they are.

`AppIconWeight.tier(forSize:)` now answers Regular for every size. The size stays in the signature so a band can be split off again without touching a view. Verified in the running app through the E2E controller: Search and File at 14–18pt now carry the same stroke as the 24pt overlay.

Regular still read light beside the text, so the band moved once more, to Bold. `AppIconWeight` gained that cut and all 59 icons gained the artwork; below 24px the drawn stroke is now 1.03pt at 11px through 1.69pt at 18px, against 1.50pt for the 24px overlay that reads correctly. Sizes from 24px up are untouched at Regular.

This puts the code ahead of the requirement, which still records Light below 18px. The owner is tuning and has held the requirement edit until the reading settles; the requirement needs it before this is treated as final.

## Follow-up: stroke masters, one line width per size

Bold overshot: 1.31pt at 14px against an owner target of about 1.0pt, with Regular undershooting at 0.88pt. Phosphor's four cuts sit at 8, 12, 16 and 24 units, so no published file lands between them. The earlier conclusion that Phosphor's widths are baked into the artwork was wrong. The files under `assets/` are outlined, but the same repository keeps the originals under `raw/`, drawn as centre-line strokes with one `stroke-width` per cut. Thin, Light, Regular and Bold share the same geometry there; only that number changes. All 59 icons exist in `raw/regular`.

**Each icon is now one stroke master, and the line width is a number chosen at draw time.** The regular files were replaced by their `raw/regular` originals, every line drawn at 16 units. `AppIconLineWidth.bySize` mirrors the requirement's line width table, one entry per display size in use (10–44pt). `AppIconStore` reads the master, rewrites the 16 to `points × 256 ÷ size`, and loads the result through `NSImage(data:)`, caching per icon and size. A size missing from the table trips an assertion in Debug and draws the master unchanged in Release, so an undocumented size surfaces during development instead of silently picking a width.

**Solid dots follow the line.** Warning, warning-circle, question, image, hard-drives and list-bullets carry solid dots, which a line width cannot reach. Across Phosphor's cuts the dot radius is always half the line width plus 4 units (8, 10, 12 and 16 for 8, 12, 16 and 24), so each dot was redrawn as a radius-4 circle stroked at the master width. At 16 it renders identically to the original radius-12 dot, and it grows with the line from then on.

**Fill is untouched.** The seven solid state variants draw no lines, pass through the rewrite unchanged, and keep their files. `AppIconWeight` is down to `regular` and `fill`; the size tier and its Light and Bold cuts are gone.

Measured before the swap, in a scratch harness outside the project: a raw master at 16 units against the outlined Regular it replaces differs by under 1% of covered pixels across magnifying-glass, x, check, warning, gear and speaker-high. Round caps and joins render, `currentColor` resolves opaque, and a master rewritten to 24 units covers 1.49–1.53× the area, as expected.

The 59 `-light.svg` and 59 `-bold.svg` files are no longer referenced. They stay in the tree until the owner removes them.

The PDF fallback recorded above no longer fits: a PDF cannot have its line width rewritten at draw time. If macOS 13 turns out not to read SVG, that needs its own decision; the SVG masters stay the source either way.

Verification:

- `swift build` clean, no warnings.
- `AppIconAssetTests` now resolves every icon at every documented size and checks that every stroke master draws all of its lines at the one master width, so a line the rewrite cannot reach fails the suite.
- `swift test`: 1177 tests, 15 failures in the parallel run. Rerun alone, 13 pass. The other two, `shioriTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedShiori`, fail the same way on a clean `HEAD` built from `git archive`, so neither comes from this change.
- Debug in-app E2E controller: Shiori (18pt sidebar, topbar entries, 44pt cover placeholder), File (14pt button icons, Remove), and Search (16pt field, filter and select-mode icons) all draw from the stroke masters at their table widths.

The owner removed the 118 unused Light and Bold files, committed on their own.

## Follow-up: heavier small sizes

The first table ran from 0.80pt at 10pt to 1.50pt at 24pt. The owner asked for heavier small sizes, flattening that ramp to 1.10pt at 10pt through 1.45pt at 20pt, in 0.05pt steps with one 0.10pt step from 12 to 14pt. 24pt and above are unchanged. Only `AppIconLineWidth.bySize` changed.

The owner is still tuning, and the requirement's line width table stays at the first values until the reading settles. The code is ahead of the requirement until then.

Verification: `swift build` clean, no warnings. The icon and checkbox tests pass (18). In the Debug in-app E2E controller, the Shiori sidebar and File buttons draw visibly heavier than in the previous capture.

## Follow-up: sizes are icon boxes

Every icon came out smaller than the SF Symbol it replaced. The owner noticed it first in the table row menu. The migration carried each number across unchanged, but the number meant something else on each side. For SF Symbols it was a point size: a symbol is laid out like a character of that font size and its box follows its own metrics, so `doc.on.doc` at 14pt reports 18 × 20 and `folder` 19 × 15. For Phosphor it is the whole square box the 256-unit canvas is drawn into, and Phosphor keeps its drawing in roughly the middle three quarters of that canvas: `copy` spans 40 to 216 at its line centres, about 10.9pt of ink in a 14pt box at the current line width. Across the seven menu glyphs, a Phosphor icon at the old number drew on average 0.77 of the SF Symbol's height.

Every icon size is therefore now read as an icon box and scaled by 1.3 from the number it had, rounded: 10→13, 11→14, 12→16, 13→17, 14→18, 16→21, 18→23, 20→26, 24→31, 32→42, 36→47, 44→57. This is a starting point to be tuned against the owner's pre-migration build, not a derived rule; glyphs that fill their canvas, such as the checkbox circles, may now read larger than before. The line width table was re-keyed in step, so each place keeps the width the owner tuned for it; the owner adjusts widths next.

- The shared size constants took the new values and are marked provisional against the design document's old ones. The checkbox sizes scale with them, including the table and collage checkboxes, whose layout follows their box.
- The sizes that were bare numbers at call sites now have names. The cover placeholder (Shiori and Library) and the empty state glyph are in `WorkbenchControlMetrics`; the primary transport glyph is in `PlaybackChromeMetrics`, and the cue state marker in `SubtitleTableMetrics`. The keycap glyph drew at the caption font size, so it gets its own size rather than moving the font.
- Menu rows sized their icon slots with the control icon size, a slot wider than the 14pt glyph it held. Every Phosphor glyph is a square box, so each slot is now the menu icon box itself (18). The slot would otherwise have grown to 21 and widened the gap before each label.
- The dialog close button is placed by its glyph's ink. That ink was a measured SF Symbol figure, 9.5, and has been stale since the migration. It is now derived from Phosphor's `x`: its strokes span 144 of 256 units, plus the line width across the two round caps.
- Branches no view renders (the pre-redesign control paths and the unused card group header) were scaled in place rather than named, so every size an icon can be drawn at stays in the table.

The requirement still records the old sizes and line widths; the owner holds the edit until the reading settles.

Verification:

- `swift build` clean, no warnings.
- `swift test`: 1177 tests, 15 failures in the parallel run. Rerun alone, 13 pass. The other two are the Shiori table tests that fail the same way on a clean `HEAD`. One name, `failedLibraryFolderRemovalPreservesFolderAndPresentationState`, was new in this parallel run and passes alone.
- Debug in-app E2E controller: File (18pt button icons, 23pt sidebar), Shiori overview and list detail (21pt search field, filter and select-mode icons, 18pt Resume). A right click on the first row's index cell after a pointer move lit the row but did not open the row menu, and the following Command-Q was refused as `keyWindowUnavailable`, so the app was not active at that point. The row menu at 18pt is left to the owner's check.
