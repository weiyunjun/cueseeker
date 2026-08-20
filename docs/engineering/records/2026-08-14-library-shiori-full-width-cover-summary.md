# Requirement

- `docs/human/requirements/20260814-Feature-Library And Shiori Full Width Cover Summary.md`
- `docs/human/design/UI Design System.md`

# Scope

Expand the shared Cover Summary to the full Library and Shiori detail viewport
directly below the App Topbar. Preserve the existing cover crop, scrim, content,
playback actions, scrolling, pinned controls, and lower-content bounds.

# Architecture

- Platform UI/UX only: shared presentation tokens and existing SwiftUI/AppKit
  layout ownership change.
- Product semantics, persistence, cover generation, and playback execution are
  unchanged.
- No new state, cache, asynchronous lifecycle, or page-specific cover component
  is introduced.

# Steps

1. Updated the provisional shared Cover Summary height to 288 points and its
   outer radius to zero.
2. Removed the Library detail page padding from the shared cover while retaining
   the existing 32-point Episode Grid bounds and 24-point inter-region gap.
3. Removed the Shiori cover's top padding and let the existing scrollable page
   header span the full viewport while its toolbar and table retain their
   existing 32-point bounds.
4. Updated focused layout and scroll-geometry tests for the accepted dimensions
   and full-width scrollable header frame.

# Verification

Pending.

# Outcome

Pending verification.

# Follow-ups

- After owner visual acceptance, the human owner will update
  `docs/human/design/UI Design System.md` with the finalized tokens and layout
  rules.
