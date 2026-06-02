# ASS System Font Alias Step 1

Requirement: `docs/human/requirements/20260603-Bug-ASS System Font Alias Name Table.md`

## Scope

- Added installed font file `name` table parsing for ASS font aliases that CoreText descriptors do not expose directly.
- Added localized Windows Unicode and selected Macintosh encoding decoding for font family, full name, PostScript, typographic, and WWS name records.
- Scanned standard installed font directories and registered supported font files for the current process before rebuilding the CoreText descriptor collection.
- Matched parsed font collection faces by PostScript name before adding aliases, avoiding cross-face alias contamination.
- Preferred a CoreText-resolvable canonical name that is also present in the parsed font metadata when descriptor family/display names are unreliable.
- Kept the existing render-script rewrite flow unchanged; this step only strengthens the alias table used before libass session creation.

## Verification

- `swift test --package-path apps/macos-native --filter assFont`
- `swift test --package-path apps/macos-native`
- Temporary Swift/CoreText probe after process-registering standard font directories:
  `STZhongsong`, `EPSON-FUTO-MINCHO`, and `HYn3gj` resolved to matching PostScript names.

Both commands passed. The targeted coverage includes parsing a synthetic installed-font `name` table where `华文中宋` maps to `STZhongsong`, and canonical-name selection for an EPSON-style PostScript fallback.

## Result

The first implementation step matched expectations: installed fonts whose ASS-facing names exist in the font file `name` table can now contribute aliases even when CoreText does not expose those localized names as descriptor family or display names.
