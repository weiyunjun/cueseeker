# ASS System Font Alias Step 5

Requirement: `docs/human/requirements/20260603-Bug-ASS System Font Alias Name Table.md`

## Scope

- Added a playback regression test for the reported ASS font names:
  - `华文中宋` -> `STZhongsong`
  - `EPSON 太明朝体Ｂ` -> `EPSON-FUTO-MINCHO`
  - `方正准圆_GBK` -> `FZZhunYuan-M02`
- Verified that unmatched ASS font names remain unchanged, so missing-font cases still fall through to libass/CoreText fallback instead of being rewritten to an arbitrary replacement.
- Kept this step test-focused; no production playback or indexing behavior changed.

## Verification

- `swift test --package-path apps/macos-native --filter assFont`
- `swift test --package-path apps/macos-native`
- CoreText process-registration probe for installed fonts:
  - `STZhongsong` resolved to `STZhongsong`
  - `EPSON-FUTO-MINCHO` resolved to `EPSON-FUTO-MINCHO`
  - `FZZhunYuan-M02` resolved to `FZY3K--GBK1-0`
  - `HYn3gj` resolved to `HYn3gj`

The targeted command passed 9 Swift Testing cases. The full suite passed 180
Swift Testing cases and 7 XCTest cases.

## Result

The fifth implementation step matched expectations: the reported Attack on
Titan and Legal High font names are covered by regression tests, missing fonts
are preserved for normal libass fallback, and the installed-font probe confirms
the expected CoreText names are resolvable after process registration.
