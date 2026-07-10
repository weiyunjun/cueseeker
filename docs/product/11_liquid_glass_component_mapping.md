# Liquid Glass Component Mapping

Status: Draft

## 1. Purpose

This document defines the mapping contract between the Liquid Glass HTML
prototype component classes and the native SwiftUI implementation.

The goal is to make the App UI rewrite maintainable: HTML prototype classes
remain the design-system vocabulary, while SwiftUI implements equivalent native
components, styles, and control states.

This document is a review draft. App implementation should not depend on it as
accepted direction until the user approves it.

## 2. Scope

Current HTML source:

```text
ui/prototypes/cueseeker-liquid-glass-v6/
```

This pass reflects the info-page / video-page refactor
(`docs/proposals/2026-05-ui-info-page-video-page-refactor.md`, ADR-0013): the
video page is a dedicated full-window presentation, the playback side panel is a
centered overlay, the video-page Close capsule is removed, and a custom
video-page top bar replaces it.

Included App surfaces:

- Main workbench shell (info page only; hidden on the video page).
- Topbar Library, Shiori, and Search controls (info page only).
- Search results.
- Library grouped episode grid.
- Shiori grouped cards.
- Active-playback bottom player.
- Video page video surface (dedicated full-window presentation).
- Video page top bar (custom traffic-light cluster plus centered title).
- Video page right-aligned overlay panel (replaces the former squeezing side panel).
- Playback fullscreen chrome.

Out of scope for this mapping pass:

- Settings window UI.
- Prototype-only review controls such as theme switching and disable-all
  controls.
- The real native NSWindow traffic lights, AppKit fullscreen lifecycle, playback
  backend, database, indexing, Search pagination, lazy loading, and first-screen
  render behavior. The real NSWindow traffic lights are suppressed on the video
  page; the in-scope video-page traffic-light cluster is a custom-drawn product
  control, not the native window buttons.

## 3. Mapping Principles

Rules:

- HTML `ui-*` classes are semantic design-system anchors, not literal App
  implementation code.
- SwiftUI does not natively support CSS-style class selectors. The App must
  implement the same taxonomy with native components, `ButtonStyle`,
  `ViewModifier`, token structs, and enum variants.
- Swift component names should preserve the component concept even when their
  internal Swift type names differ from HTML class names.
- The App should not parse prototype HTML or CSS at runtime.
- A visual change to a shared HTML class must be mirrored by updating the
  corresponding Swift component style in the same implementation change.
- New broad component classes must be added to this mapping before App
  implementation relies on them.
- Surface-specific layout classes may stay HTML-only if the Swift view has a
  clearer native layout boundary.

## 4. SwiftUI Style Model

The native implementation should use a small Liquid Glass UI layer rather than
copying style code into each screen.

Expected SwiftUI building blocks:

| SwiftUI concept | Purpose |
| --- | --- |
| `LiquidGlassTokens` | Shared color, material, shadow, border, radius, spacing, typography, and timing values. |
| `LiquidGlassControlState` | Normal, hovered, pressed, focused, selected, active, disabled, and dragging states. |
| `LiquidGlassIconButton` | Circular icon button family, including toggle and transport variants. |
| `LiquidGlassCapsuleButton` | Capsule button family, including source, command, value, and test-only variants. |
| `LiquidGlassSearchField` | Search input capsule with embedded clear action. |
| `LiquidGlassSegmentedControl` | Two or more compact segmented options. |
| `LiquidGlassSelectableCard` | Selectable result-style card surface. |
| `LiquidGlassSelectableRow` | Selectable sidebar/list row surface. |
| `LiquidGlassSlider` | Playback progress and volume slider family. |
| `LiquidGlassPopupMenu` | Rounded-rectangle popup menu and menu item family. |
| `LiquidGlassSurface` | Shared workbench, bottom-player, overlay-panel, and video-stage surfaces. |
| `LiquidGlassFeedbackOverlay` | Transient playback input feedback shown over the active video stage, above the overlay panel. |
| `LiquidGlassVideoTopBar` | Video-page top bar: left window-control cluster plus centered video title. |
| `LiquidGlassWindowControlButton` | Custom-drawn traffic-light control (close, minimize, zoom) with app-defined semantics, not the native NSWindow buttons. |

Implementation may choose different final Swift type names, but each accepted
component class below must have one native owner. Shared visual rules should
live in that owner, not in individual call sites.

## 5. Component Class Mapping

| HTML class anchor | Product component concept | SwiftUI owner | App usage |
| --- | --- | --- | --- |
| `ui-capsule` | Capsule button base | `LiquidGlassCapsuleButton` / capsule `ButtonStyle` | Shared base for visible pill-shaped text/value controls. |
| `ui-capsule--command` | Capsule command button | `LiquidGlassCapsuleButton.Kind.command` | `Collapse All` and similar compact commands. |
| `ui-capsule--value` | Fixed-width value capsule | `LiquidGlassCapsuleButton.Kind.value` | Playback speed control. |
| `ui-capsule--test` | Prototype-only test capsule | No production App component | HTML review controls only. |
| `ui-prototype-control` | Prototype-only review control | No production App component | Must not appear in production App UI. |
| `ui-icon-button` | Icon button base | `LiquidGlassIconButton` / icon `ButtonStyle` | Shared base for icon-only controls. |
| `ui-icon-button--circle` | Circular icon button | `LiquidGlassIconButton.Kind.circle` | Bottom-player utility controls such as volume, subtitle visibility, and fullscreen. |
| `ui-icon-button--toggle` | Circular icon toggle button | `LiquidGlassIconButton.Kind.toggle` | Side-panel visibility and topbar mode toggles when selected state applies. |
| `ui-icon-button--topbar` | Topbar circular icon button | `LiquidGlassIconButton.Kind.topbar` | Library and Shiori topbar buttons. |
| `ui-icon-button--embedded` | Embedded circular icon button | `LiquidGlassIconButton.Kind.embedded` | Search-field clear action. |
| `ui-icon-button--transport` | Transport icon button | `LiquidGlassIconButton.Kind.transport` | Previous episode, previous result, next result, next episode. |
| `ui-icon-button--transport-primary` | Primary transport icon button | `LiquidGlassIconButton.Kind.primaryTransport` | Play or pause control. |
| `ui-input-capsule` | Search field capsule | `LiquidGlassSearchField` | Topbar Search input. |
| `ui-segmented-control` | Segmented control container | `LiquidGlassSegmentedControl` | Playback side-panel tabs. |
| `ui-segmented-control__option` | Segmented control option | `LiquidGlassSegmentedControl.Option` | Search Results and Subtitles tab buttons. |
| `ui-selectable-card` | Selectable card | `LiquidGlassSelectableCard` | All three info-page cards share this one owner. v6 markup: `result-card ui-selectable-card` (Search), `result-card shiori-card ui-selectable-card` (Shiori), `library-episode-card ui-selectable-card` (Library); `shiori-card` / `library-episode-card` are surface modifiers, not separate owners. Adopted by Search in P5.2-1, Library in P5.3, Shiori in P5.4-1. The Library episode card draws the shared `LiquidGlassTokens` card skin (fill / hover / shadow) directly rather than wrapping the `LiquidGlassSelectableCard` view, because its Library-launched "playing" treatment (doc 12 §7.2) is a main-page retained-playback indicator that the wrapper's selected state explicitly must not represent (that selected state is sidebar-reuse only; see this file's component header). The token source is still shared, so the skin stays single-sourced. |
| `ui-selectable-row` | Selectable sidebar row | `LiquidGlassSelectableRow` | Playback side-panel result and subtitle rows. |
| `ui-popup-menu` | Rounded-rectangle popup menu | `LiquidGlassPopupMenu` | Playback speed menu. |
| `ui-popup-menu__item` | Popup menu item | `LiquidGlassPopupMenu.Item` | Playback speed options. |
| `ui-slider` | Slider base | `LiquidGlassSlider` | Shared slider behavior and visuals. |
| `ui-slider--progress` | Playback progress slider | `LiquidGlassSlider.Kind.progress` | Bottom-player scrubber. |
| `ui-slider--volume` | Volume slider | `LiquidGlassSlider.Kind.volume` | Volume popover slider. |
| `ui-feedback-overlay` | Video feedback overlay layer | `LiquidGlassFeedbackOverlay` | Non-interactive layer over the active video stage. |
| `ui-feedback-hud` | Transient feedback HUD | `LiquidGlassFeedbackOverlay.HUD` | Play, pause, seek, volume, speed, subtitle, Shiori, copy, and fullscreen feedback, with center, leading, and trailing positions. |
| `ui-feedback-hud--text-capsule` | Text-only feedback capsule modifier | `LiquidGlassFeedbackOverlay.HUD.Kind.textCapsule` | Independent compact capsule HUD for text-only feedback such as fullscreen enter and exit. No icon slot or icon spacing is reserved. |
| `ui-feedback-icon` | Feedback icon | `LiquidGlassFeedbackOverlay.Icon` | Command icon inside the transient video feedback HUD; omitted for text-only fullscreen enter and exit feedback. |
| `ui-feedback-label` | Feedback label | `LiquidGlassFeedbackOverlay.Label` | Short command or state label inside the transient video feedback HUD. |
| `ui-is-selected` | Selected state marker | `LiquidGlassControlState.selected` | Playback side-panel selected rows, selected toggles, and selected menu items. Search, Library, and Shiori main-page cards must not use this for retained playback *selection* visuals (finding F). Carve-out: the Library episode card's Library-launched *playing* indicator (doc 12 §7.2) is a mandated ongoing-playback state, not a selection visual, and is kept; it uses a Library-specific treatment, not this shared selected state. |
| `ui-is-active` | Active state marker | `LiquidGlassControlState.active` | Active segmented option and active transient control states. |

### 5.1 Video-page top bar anchors (v6)

These are surface-level component anchors (not `ui-*` classes) introduced by the
info-page / video-page refactor. They are Player UI and share the
`player-chrome-visible` show/hide state with the bottom player.

| HTML class anchor | Product component concept | SwiftUI owner | App usage |
| --- | --- | --- | --- |
| `.video-topbar` | Video-page top bar surface | `LiquidGlassVideoTopBar` | Full-width bar at the top of the video page; centered title with a left control cluster. Windowed-only; hidden in fullscreen, where the macOS native fullscreen titlebar takes over (see doc 12 §12). Acts as a standard window titlebar for native window management: empty-area drag moves the window and double-click performs the system `AppleActionOnDoubleClick` (zoom/minimize) — native mechanics outside the HTML prototype (see doc 12 §15). |
| `.video-traffic` | Window-control cluster | `LiquidGlassVideoTopBar` cluster group | Groups the three custom window-control buttons. |
| `.vt-dot` | Window-control button base | `LiquidGlassWindowControlButton` | Shared base for the custom traffic-light controls; glyph reveals on cluster hover/focus. |
| `.vt-close` | Close control (red) | `LiquidGlassWindowControlButton.Kind.close` | Closes the video page and returns to the originating info page. It is NOT a quit/window-close. |
| `.vt-min` | Minimize control (yellow) | `LiquidGlassWindowControlButton.Kind.minimize` | Minimizes the app window to the Dock (native `NSWindow.miniaturize`); a native-mechanics control handled outside the HTML prototype. |
| `.vt-zoom` | Zoom control (green) | `LiquidGlassWindowControlButton.Kind.zoom` | Enters fullscreen. |
| `.video-title` | Centered video title | `LiquidGlassVideoTopBar` title | Centered alias of the playing source; truncates with ellipsis. |
| `.video-topbar-spacer` | Layout balance spacer | Layout-only | Keeps the title optically centered opposite the control cluster; no Swift component required. |

Retired active-target components:

- `ui-capsule--source` / `.source-toggle` belonged to the previous
  bottom-player source/title expand-collapse control. The active target UI
  removes that bottom-left collapse control, so SwiftUI should not implement it
  as the entry point for expanded playback. Playback opens from Search, Library,
  or Shiori activation.
- `ui-capsule--video-close` / `.video-close-button` was the video-frame-anchored
  close capsule. The v6 refactor removes it; closing the video page is now the
  `.vt-close` control in the video-page top bar, which returns to the
  originating info page. SwiftUI must not implement the close capsule.

## 6. Surface Mapping

| App surface | HTML source concept | SwiftUI owner to create or refactor | Behavior owner to preserve |
| --- | --- | --- | --- |
| Main workbench shell | `.window`, `.main`, `.toolbar` | `ContentView`, `AppTopBar`, `LiquidGlassSurface` | `AppCoordinator`, `WorkbenchLayoutState`, native window setup. The workbench `.toolbar` is the info-page chrome only and is hidden while the video page is shown. |
| Topbar mode buttons | `ui-icon-button--topbar` | `LiquidGlassIconButton.Kind.topbar` | `activateWorkbenchPanelMode`. |
| Topbar Search | `ui-input-capsule`, `ui-icon-button--embedded` | `LiquidGlassSearchField` | `TopbarSearchInputState`, Return-submit flow. |
| Search page | `.search-state`, result groups, `ui-selectable-card` | Search page view plus `LiquidGlassSelectableCard` | Existing Search query, grouping, lazy loading, load-more, exact counts. |
| Library page | `.library-state`, episode cards | Library page view plus disclosure and episode card components | Existing Library folder grouping, collapse state, open video behavior. |
| Shiori page | `.shiori-state`, grouped cards | Shiori page view plus `LiquidGlassSelectableCard` | Existing Shiori persistence and open behavior. |
| Info-page empty / loading / failed / no-results states | State demo `.state-view`, `.state-spinner`, `.load-more` (separate `ui/state-demos/info-page-card-states/` prototype, outside `ui/prototypes/`) | Shared info-page state views (`SearchStatus`-driven Search states; Library `selectedFolders`/`libraryStatus`; Shiori empty) | `SearchStore` / `LibraryStore` / `ShioriStore` status; see doc 12 §6.1/§7.1/§8. Provisional state authority only (condition→state + whether it animates), not final visual. |
| Bottom player | `.player-dock`, `.player-hud` | `BottomPlaybackBar`, `LiquidGlassBottomPlayer` | Active playback session visibility, playback view model, seek, volume, speed, navigation, and subtitle visibility. Normal playback chrome has no Shiori or copy command. |
| Video page | `.video-state`, `.video-stage`, `.video-frame`, `ui-feedback-overlay` | `PlaybackExpandedLayout`, video stage surface, `LiquidGlassFeedbackOverlay` | Dedicated full-window presentation layered above a live info page; real video aspect ratio; playback render view lifecycle; playback close lifecycle (returns to the originating info page); playback input feedback. The feedback overlay renders above the playback overlay panel. |
| Video page top bar | `.video-topbar`, `.video-traffic`, `.vt-dot`, `.vt-close`, `.vt-min`, `.vt-zoom`, `.video-title` | `LiquidGlassVideoTopBar`, `LiquidGlassWindowControlButton` | Player UI; shares `player-chrome-visible` show/hide with the bottom player. Close returns to the originating info page; zoom enters fullscreen. Native NSWindow traffic lights are suppressed on the video page. |
| Video page overlay panel | `.sidebar`, `ui-segmented-control`, `ui-selectable-row` | Overlay-panel views plus segmented and row components | Search navigation snapshot, current subtitle entries, row activation. Right-aligned floating overlay over the video; does NOT squeeze the video stage; visibility is independent of `player-chrome-visible` and is driven only by the bottom-bar panel toggle; never auto-hides. The native scrollbar may show a fixed-width light thumb with transparent track/gutter. |
| Fullscreen playback chrome | Prototype bottom-player and video-page top bar visual language plus `ui-feedback-overlay` | Fullscreen overlay using the same bottom-player, top-bar, and feedback component families | AppKit fullscreen lifecycle, render-view ownership, cursor and chrome visibility timing, playback input feedback. |

Info-page state views note: the empty / loading / failed / no-results states
are specified by a separate focused interactive prototype,
`ui/state-demos/info-page-card-states/`, kept outside `ui/prototypes/` by owner
decision (see `docs/proposals/2026-05-info-page-card-visual-rebuild.md`, "P5.0
C2"). Its `.demo-*` control bar is prototype-only and is not an App component
(treat like `ui-prototype-control`). `.state-view` maps to a shared
`SearchStatus`/Library/Shiori state view; `.state-spinner` and `.load-more` are
the loading and incremental-load-more indicators. Known difference (deferred):
the demo's state-view treatment leans native and diverges from the accepted
Liquid Glass card visual; pixel-level visual reconciliation is out of the
current Phase 5 layout/operation scope and is deferred to a later visual pass.

## 7. Control State Mapping

SwiftUI must represent the same state vocabulary as the HTML prototype.

| HTML state source | SwiftUI state source | Notes |
| --- | --- | --- |
| `:hover` | `onHover` local state | Applies to buttons, cards, rows, sliders, and popup items. |
| `:active` | `ButtonStyle.Configuration.isPressed` or drag state | Pressed state should be local and transient. |
| `:focus-within` | focus binding or AppKit text-view focus callback | Used by the Search field capsule. |
| `[disabled]` | `Environment(\.isEnabled)` | Disabled visual treatment must be owned by the component style. |
| `aria-pressed="true"` | Boolean binding such as `isSelected` | Used by toggle controls. It does not imply `ui-is-selected` unless the component mapping explicitly uses selected visual styling. |
| `aria-expanded="true"` | Boolean binding such as `isExpanded` | Used by menus and disclosure controls. The retired source/title capsule must not be reintroduced as the expanded-playback toggle. |
| `ui-is-selected` | `LiquidGlassControlState.selected` | Persistent selected state for playback side-panel rows and selected controls only. Main Search, Library, and Shiori cards should not retain selected visuals after activation. |
| `ui-is-active` | `LiquidGlassControlState.active` | Active tab or active transient selection. |
| `.is-dragging` | `@GestureState` or local drag state | Sliders should use this for thumb and track emphasis. |
| `body[data-theme]` | `AppAppearanceMode` / color scheme | Theme tokens should derive from App appearance mode, not prototype-only controls. |
| `.video-expanded` | `appState.isPlaybackSurfaceExpanded` | Controls the video-page presentation. The video page is a dedicated full-window presentation layered above a live info page; the workbench `.toolbar` is hidden while it is shown. |
| `.playback-closed` / no active playback marker | `appState.hasPlaybackSelection == false` or equivalent derived playback-session state | Hides playback UI after close. The bottom player is also hidden whenever `.video-expanded` is false, so non-video Search, Library, and Shiori pages do not show the bottom player. |
| `.sidebar-hidden` | `!appState.isPlaybackSidePanelVisible` | Controls the right-aligned overlay panel visibility. Driven only by the bottom-bar panel toggle; independent of `player-chrome-visible`; the panel never auto-hides. |
| `body.prototype-fullscreen` | `playbackFullscreenManager.isFullscreen` | Prototype-only App fullscreen state marker. It may promote `.main` to a viewport-covering playback surface and disable ancestor visual effects that block fixed positioning, but must not redefine video-stage, video-frame, side-panel, or bottom-player layout rules. |
| `.player-chrome-visible` | video-page player-UI visible state | Drives Player UI visibility over the video. Player UI now means the bottom player plus the video-page top bar (the Close capsule is removed). Show/hide follows the Player-UI / cursor visibility state machine (v4) defined in `docs/product/12_liquid_glass_ux_mapping.md`; player focus means the current effective interaction target still belongs to the player, not merely that CueSeeker is foreground or the window is key. |
| `body.player-cursor-hidden` | playback cursor-hidden state | Hides the pointer cursor per the Player-UI / cursor visibility state machine (v4) in `docs/product/12_liquid_glass_ux_mapping.md`. The current player decides cursor visibility only while the cursor is governed by that player: the player area exists, the live cursor position is inside it, and the player has focus. When that condition is false, final cursor visibility belongs to whichever other rule owns it. |
| `data-feedback-position` on `ui-feedback-overlay` | `PlaybackFeedbackPosition` | Center for most commands, leading for rewind and previous-result navigation, trailing for forward seek and next-result navigation. |
| `data-feedback-has-icon` on `ui-feedback-hud` | Optional feedback icon state | Text-only feedback hides the icon and selects the `ui-feedback-hud--text-capsule` compact capsule modifier. |
| `.is-visible` on `ui-feedback-hud` | Transient feedback presentation state | Shows the HUD while feedback is active; repeated commands update content in place instead of replaying the full entry animation. |

Icon asset rule:

- The copy glyph remains available to the shared feedback HUD for cue-scoped
  Playback Subtitle Focus feedback; it is not a normal-playback bottom-player
  button.
- Playback command feedback uses the same HUD component when its content
  changes repeatedly. Repeated commands may update text and run a small update
  pulse, but must not remount the HUD or replay the full entry animation.

Main-page selected-visual correction: the `ui-is-selected` rows above forbid
retained playback-selection visuals on main Search / Library / Shiori cards
(proposal "P5.0 Confirmed Audit" finding F). The Search card and the shared
`CardGroupHeader` selected visuals were excised in P5.2-2. The `ShioriCard`
was rebuilt onto the shared `LiquidGlassSelectableCard` in P5.4-1 and the
`selectedShiori` / `isSelected` plumbing was excised in P5.4-2, so no main
card retains a playback-selection visual; the dead Shiori legacy cluster was
retired in P5.4-3 and the orphaned `SearchLayout` removed in P5.4-4. Library
has no separable dead path; its old code was replaced in place within the P5.3
rebuild, and the Library episode card's Library-launched *playing* indicator
is the doc 12 §7.2 mandated state, not a forbidden selection visual (carve-out
in the `ui-is-selected` row above). See proposal "P5.3 / P5.4 Old-Code Audit &
Deletion Plan".

## 8. Token Mapping

The App should translate CSS custom properties into Swift tokens by semantic
role, not by copying CSS names mechanically.

| HTML token group | Swift token group | Notes |
| --- | --- | --- |
| `--glass-window-*` | `LiquidGlassTokens.windowSurface` | Main workbench material, border, and shadow. |
| `--glass-hud-*` | `LiquidGlassTokens.hudSurface` | Bottom player and floating chrome surfaces. |
| `--glass-thin-*` | `LiquidGlassTokens.thinSurface` | Lighter nested controls and panels. |
| `--hairline`, `--hairline-soft` | `LiquidGlassTokens.hairline` | Borders and separators. |
| `--text`, `--text-2`, `--text-3`, `--text-4` | `LiquidGlassTokens.text` | Primary through quaternary text roles. |
| `--accent`, `--accent-soft` | `LiquidGlassTokens.accent` | App accent emphasis and soft selected treatment. |
| `--card-*`, `--card-selected-*`, `--row-*` | `LiquidGlassTokens.selectableCardSurface` | Selectable-card / list-row surface, hover, and selected skins. The authoritative skin is the later v6 token-override layer (theme-driven, `styles.css` L1758); the hardcoded-light base values (L563) are not the authority and must not be replicated. |
| `--highlight`, `--highlight-text` | `LiquidGlassTokens.searchHighlight` | Search match highlighting. |
| `--search-page-*` | Page-specific semantic tokens | Info-page (Search / Library / Shiori) surface; page background light `#f4f4f6` / dark `#1f2027`. Concrete confirmed values: proposal "P5.2-B Confirmed Pixel Spec". |
| `--search-page-pill-*`, `--field-*` (topbar) | `LiquidGlassTokens.topbarControlSurface` | Topbar search-field capsule (`LiquidGlassSearchField`) and topbar tool buttons (`LiquidGlassIconButton.Kind.topbar`); concrete values in proposal "P5.2-B Confirmed Pixel Spec". NSWindow traffic lights stay native and are not aligned. |
| `--mono`, `--sf` | Typography tokens | App uses native SF fonts and monospaced digits where needed. |

Rules:

- Token names in Swift should describe semantic role, not CSS implementation
  details.
- Shared token changes should be made once and consumed by all component
  styles.
- App implementation may use native materials and color-scheme behavior when
  they preserve the accepted visual intent.
- The Search card subtitle `.line` font weight and opacity are
  App-authoritative (owner decision 2026-05-19): the v6 prototype was updated
  to match the App (weight 600, opacity 0.88; commit `7c2ea1f`), not the
  reverse. Concrete P5.2-B card / topbar / page pixel values are
  single-sourced in the proposal "P5.2-B Confirmed Pixel Spec"; this document
  maps semantic roles only.

## 9. Synchronization Workflow

HTML and Swift do not synchronize automatically. During the active native UI
restructure, SwiftUI/AppKit implementation is authoritative and HTML prototypes
are reference artifacts.

Required workflow for future stable UI class changes:

1. Implement the approved UI direction in the corresponding Swift component
   owner, not every individual call site.
2. If the accepted Swift result adds, removes, or redefines component concepts,
   token ownership, or `ui-*` reference classes, update this mapping document
   before the UI phase is declared complete.
3. Update HTML prototypes when they are useful reference artifacts or when the
   user explicitly asks for prototype-first visual alignment.
4. If a class is prototype-only, mark it as such and keep it out of production
   SwiftUI.
5. If a class is surface layout only, document whether Swift should mirror it
   with a named view or implement the layout directly in the owning surface.
6. Visual verification should judge the native App surface first and compare
   any HTML reference by component concept, state, and layout role.

Optional future automation:

- Add a machine-readable component manifest such as
  `ui/prototypes/cueseeker-liquid-glass-v6/component-map.json`.
- Generate a Swift enum skeleton from that manifest.
- Add a drift check that reports unmapped `ui-*` classes in the prototype.

This automation is optional. The active App rewrite can proceed Swift-first and
then synchronize this document once the native UI direction is accepted.

## 10. Non-Synchronized Boundaries

The following must not be synchronized from HTML classes into Swift:

- Prototype-only sample data.
- Prototype-only test controls.
- Browser-specific CSS behavior such as `backdrop-filter` implementation
  details when native materials are more appropriate.
- Fake window controls or prototype desktop wallpaper.
- Static video aspect ratio.
- Mock JavaScript state machines.
- Any behavior already owned by App product logic, including Search lazy
  loading, first-screen rendering, playback state, indexing, database access,
  Shiori persistence, and fullscreen lifecycle.

## 11. Review Questions

Open questions before this document becomes accepted:

- Resolved (v6, 2026-05-20): `ui-selectable-card` covers all three —
  Search/Shiori result cards and Library episode cards — under one
  `LiquidGlassSelectableCard` owner, with `shiori-card` / `library-episode-card`
  as surface modifiers (see §5). Library episodes do not get a separate anchor.
- Should topbar Library and Shiori buttons be modeled as `topbar` plus
  `toggle`, or as a distinct topbar-toggle variant?
- Should fullscreen playback chrome use the exact bottom-player component with
  a fullscreen context, or a separate component that shares the same token and
  button families?
- Should a component manifest be introduced before the App rewrite, or after
  the first native implementation proves the mapping stable?
