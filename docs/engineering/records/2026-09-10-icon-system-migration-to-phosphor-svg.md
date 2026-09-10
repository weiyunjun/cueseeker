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
