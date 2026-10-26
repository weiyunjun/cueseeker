# 2026-10-26 SRT Subtitle Rendering Visual And Layout Alignment With Libass

## Requirement
- `docs/human/requirements/20261026-Feature-SRT Subtitle Rendering Visual And Layout Alignment With Libass.md`

## Summary of Changes
1. **Font `Size` Line-Height Metrics Aligned with `libass` (`SRTSubtitleInlineText.swift`, `SRTSubtitleStyle.swift`):**
   - Updated `SRTFontCache` to read `usWinAscent` and `usWinDescent` from the font's `OS/2` table (falling back to `sTypoAscender` / `-sTypoDescender`, then CoreText `ascent` / `descent`), scaling `pointSize = lineHeight * unitsPerEm / (ascUnits + descUnits)` so that `ascent + descent == lineHeight` at the `1080p` reference height, matching `libass` `Fontsize`.
2. **Glyph Fill, Solid Outline Base, and Stroke Normalization (`SRTSubtitleRenderer.swift`):**
   - Disabled macOS font smoothing (`setShouldSmoothFonts(false)`, `setAllowsFontSmoothing(false)`) and filled text runs directly from their geometric `CGPath`s instead of `CTFrameDraw`, eliminating outward dilation of white text into thin outlines.
   - Normalized glyph paths using `.normalized(using: .winding)` so crossing strokes in CJK characters (e.g. `十`, `木`, `世`) merge into a single contour without acute intersection spikes or internal double-stroke shadows.
   - Filled the interior of the outline layer with `outlineColor` in addition to stroking outward by `outlineWidth`, preventing blur or semi-transparent outlines from hollowing out at the glyph edge.
3. **Synthetic Bold & Inline `<u>` Underline Paths (`SRTSubtitleInlineText.swift`, `SRTSubtitleRenderer.swift`):**
   - Widened synthetic-bold glyph contours by `pointSize / 64` via stroke union and added `pointSize / 64` to character advances before outline and shadow generation.
   - Built geometric rectangle paths for inline `<u>` underlines (`CTFontGetUnderlinePosition` / `CTFontGetUnderlineThickness`) and merged them into the run paths so underlines receive outlines, blur, and shadows.
4. **Letter Spacing, Balanced Wrapping, Margin Anchoring, and Multi-Cue Stacking (`SRTSubtitleInlineText.swift`, `SRTSubtitleRenderer.swift`):**
   - Preserved built-in kerning when `letterSpacing == 0`, disabled ligatures when `letterSpacing > 0`, and excluded trailing `letterSpacing` after the last visible character on a line.
   - Implemented balanced line wrapping (`libass` `WrapStyle = 0`) via `CTTypesetter` within `canvasSize.width - 2 * marginX`.
   - Anchored `Margin X` and `Margin Y` directly to the pure text layout box (`textBounds`), and computed multi-cue collision avoidance from `collisionBounds` (text + outline/box, excluding shadow and blur) while stacking subsequent `Center` cues downward.

## Verification
- Ran `swift test --package-path apps/macos-native --filter CueSeekerPlaybackTests`.
