# Requirement

- `docs/human/requirements/20260813-Feature-Shiori Detail Adaptive Cover Summary.md`
- `docs/human/design/UI Design System.md`

# Scope

Replace only the Shiori detail Cover Summary's split/overlap presentation with
the accepted full-width Scheme B iteration. Preserve its height, metadata,
playback action, scrolling, toolbar, table, and persistence behavior.

# Steps

1. Made the existing summary card use its full container as one rounded cover
   background while retaining the existing 252-point height.
2. Reused the cover image's aspect-fill layout with a Shiori-detail-only center
   alignment, so resizing changes uniform-scale cropping without stretching,
   padding, extending, or rewriting the stored image.
3. Replaced the surface blend with one centralized black scrim whose accepted
   Scheme B stops fade left-to-right to transparent.
4. Made the text region prefer 50% of the live card width, bounded to 448–720
   points and reduced only when the card's padded inner width is smaller.
5. Kept title, two-line secondary description, Resume/Play, and Disabled states;
   used fixed white summary foregrounds so the card itself is identical in
   Light and Dark appearances.
6. Added focused layout and crop tests for full-width 5:1 geometry, responsive
   text bounds, compact fallback, scrim values, and vertical center cropping.

# Verification

- `swift test --filter 'CoverSummaryCardTests|LibraryCoverFrameTests'` passes 11
  focused tests.
- `swift test --filter 'CoverSummaryCardTests|LibraryCoverFrameTests|ShioriPresentationTests|WorkbenchControlMetricsTests'`
  passes 16 focused layout, cover, controls, and Shiori presentation tests.
- `swift test --filter 'SubtitleTableVirtualRowTests|SubtitleTableScrollbarMetricsTests|CoverSummaryCardTests|DebugE2EControllerTests'`
  passes 110 table, scrollbar, summary, and E2E-controller regression tests.
- `swift build -c release --product CueSeeker` succeeds.
- Real Debug E2E capture at a 1433 × 821-point app window verifies the wide,
  approximately 5:1 presentation using the current database and stored covers.
  The card and table content are equally wide, the image fills through both
  edges, the crop remains centered, the description stays at two lines, and
  the right side remains unobscured.
- Real Light and Dark captures of list 5 show identical Cover Summary pixels
  and layout inside the card while surrounding app chrome changes appearance.
- Real Dark captures checked all five current list covers. Text remains visible
  on bright, dark, warm, and high-detail left-side source imagery.

# Outcome

The Shiori detail page now renders its cover as one responsive full-width
background with the accepted left-side protection gradient and centered
aspect-fill crop. No database, cover file, other cover component, or page
behavior changed.

# Follow-up

- Final visual acceptance remains with the owner.
- After acceptance, the human owner will update
  `docs/human/design/UI Design System.md` with the finalized tokens and rules.
