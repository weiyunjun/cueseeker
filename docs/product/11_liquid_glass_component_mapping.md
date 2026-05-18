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
- Video page centered overlay panel (replaces the former right side panel).
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
| `ui-icon-button--circle` | Circular icon button | `LiquidGlassIconButton.Kind.circle` | Bottom-player utility controls such as volume, Shiori, copy, fullscreen. |
| `ui-icon-button--toggle` | Circular icon toggle button | `LiquidGlassIconButton.Kind.toggle` | Subtitle visibility, side-panel visibility, and topbar mode toggles when selected state applies. |
| `ui-icon-button--topbar` | Topbar circular icon button | `LiquidGlassIconButton.Kind.topbar` | Library and Shiori topbar buttons. |
| `ui-icon-button--embedded` | Embedded circular icon button | `LiquidGlassIconButton.Kind.embedded` | Search-field clear action. |
| `ui-icon-button--transport` | Transport icon button | `LiquidGlassIconButton.Kind.transport` | Previous episode, previous result, next result, next episode. |
| `ui-icon-button--transport-primary` | Primary transport icon button | `LiquidGlassIconButton.Kind.primaryTransport` | Play or pause control. |
| `ui-input-capsule` | Search field capsule | `LiquidGlassSearchField` | Topbar Search input. |
| `ui-segmented-control` | Segmented control container | `LiquidGlassSegmentedControl` | Playback side-panel tabs. |
| `ui-segmented-control__option` | Segmented control option | `LiquidGlassSegmentedControl.Option` | Search Results and Subtitles tab buttons. |
| `ui-selectable-card` | Selectable card | `LiquidGlassSelectableCard` | Search result cards, Shiori cards, Library episode cards where the card treatment is accepted. |
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
| `ui-is-selected` | Selected state marker | `LiquidGlassControlState.selected` | Playback side-panel selected rows, selected toggles, and selected menu items. Search, Library, and Shiori main-page cards must not use this for playback selection visuals. |
| `ui-is-active` | Active state marker | `LiquidGlassControlState.active` | Active segmented option and active transient control states. |

### 5.1 Video-page top bar anchors (v6)

These are surface-level component anchors (not `ui-*` classes) introduced by the
info-page / video-page refactor. They are Player UI and share the
`player-chrome-visible` show/hide state with the bottom player.

| HTML class anchor | Product component concept | SwiftUI owner | App usage |
| --- | --- | --- | --- |
| `.video-topbar` | Video-page top bar surface | `LiquidGlassVideoTopBar` | Full-width bar at the top of the video page; centered title with a left control cluster. Windowed-only; hidden in fullscreen, where the macOS native fullscreen titlebar takes over (see doc 12 §12). |
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
| Main workbench shell | `.window`, `.main`, `.toolbar` | `ContentView`, `AppTopBar`, `LiquidGlassSurface` | `AppState`, `WorkbenchLayoutState`, native window setup. The workbench `.toolbar` is the info-page chrome only and is hidden while the video page is shown. |
| Topbar mode buttons | `ui-icon-button--topbar` | `LiquidGlassIconButton.Kind.topbar` | `activateWorkbenchPanelMode`. |
| Topbar Search | `ui-input-capsule`, `ui-icon-button--embedded` | `LiquidGlassSearchField` | `TopbarSearchInputState`, Return-submit flow. |
| Search page | `.search-state`, result groups, `ui-selectable-card` | Search page view plus `LiquidGlassSelectableCard` | Existing Search query, grouping, lazy loading, load-more, exact counts. |
| Library page | `.library-state`, episode cards | Library page view plus disclosure and episode card components | Existing Library folder grouping, collapse state, open video behavior. |
| Shiori page | `.shiori-state`, grouped cards | Shiori page view plus `LiquidGlassSelectableCard` | Existing Shiori persistence and open behavior. |
| Bottom player | `.player-dock`, `.player-hud` | `BottomPlaybackBar`, `LiquidGlassBottomPlayer` | Active playback session visibility, playback view model, seek, volume, speed, navigation, Shiori, copy, subtitles. |
| Video page | `.video-state`, `.video-stage`, `.video-frame`, `ui-feedback-overlay` | `PlaybackExpandedLayout`, video stage surface, `LiquidGlassFeedbackOverlay` | Dedicated full-window presentation layered above a live info page; real video aspect ratio; playback render view lifecycle; playback close lifecycle (returns to the originating info page); playback input feedback. The feedback overlay renders above the centered overlay panel. |
| Video page top bar | `.video-topbar`, `.video-traffic`, `.vt-dot`, `.vt-close`, `.vt-min`, `.vt-zoom`, `.video-title` | `LiquidGlassVideoTopBar`, `LiquidGlassWindowControlButton` | Player UI; shares `player-chrome-visible` show/hide with the bottom player. Close returns to the originating info page; zoom enters fullscreen. Native NSWindow traffic lights are suppressed on the video page. |
| Video page overlay panel | `.sidebar`, `ui-segmented-control`, `ui-selectable-row` | Overlay-panel views plus segmented and row components | Search navigation snapshot, current subtitle entries, row activation. Centered floating overlay over the video; does NOT squeeze the video stage; visibility is independent of `player-chrome-visible` and is driven only by the bottom-bar panel toggle; never auto-hides. |
| Fullscreen playback chrome | Prototype bottom-player and video-page top bar visual language plus `ui-feedback-overlay` | Fullscreen overlay using the same bottom-player, top-bar, and feedback component families | AppKit fullscreen lifecycle, render-view ownership, cursor and chrome visibility timing, playback input feedback. |

## 7. Control State Mapping

SwiftUI must represent the same state vocabulary as the HTML prototype.

| HTML state source | SwiftUI state source | Notes |
| --- | --- | --- |
| `:hover` | `onHover` local state | Applies to buttons, cards, rows, sliders, and popup items. |
| `:active` | `ButtonStyle.Configuration.isPressed` or drag state | Pressed state should be local and transient. |
| `:focus-within` | focus binding or AppKit text-view focus callback | Used by the Search field capsule. |
| `[disabled]` | `Environment(\.isEnabled)` | Disabled visual treatment must be owned by the component style. |
| `aria-pressed="true"` | Boolean binding such as `isSelected` | Used by toggle controls. It does not imply `ui-is-selected` unless the component mapping explicitly uses selected visual styling. The playback Shiori button is not a pressed-state control. |
| `aria-expanded="true"` | Boolean binding such as `isExpanded` | Used by menus and disclosure controls. The retired source/title capsule must not be reintroduced as the expanded-playback toggle. |
| `ui-is-selected` | `LiquidGlassControlState.selected` | Persistent selected state for playback side-panel rows and selected controls only. Main Search, Library, and Shiori cards should not retain selected visuals after activation. |
| `ui-is-active` | `LiquidGlassControlState.active` | Active tab or active transient selection. |
| `.is-dragging` | `@GestureState` or local drag state | Sliders should use this for thumb and track emphasis. |
| `body[data-theme]` | `AppAppearanceMode` / color scheme | Theme tokens should derive from App appearance mode, not prototype-only controls. |
| `.video-expanded` | `appState.isPlaybackSurfaceExpanded` | Controls the video-page presentation. The video page is a dedicated full-window presentation layered above a live info page; the workbench `.toolbar` is hidden while it is shown. |
| `.playback-closed` / no active playback marker | `appState.hasPlaybackSelection == false` or equivalent derived playback-session state | Hides playback UI after close. The bottom player is also hidden whenever `.video-expanded` is false, so non-video Search, Library, and Shiori pages do not show the bottom player. |
| `.sidebar-hidden` | `!appState.isPlaybackSidePanelVisible` | Controls the centered overlay panel visibility. Driven only by the bottom-bar panel toggle; independent of `player-chrome-visible`; the panel never auto-hides. |
| `body.prototype-fullscreen` | `playbackFullscreenManager.isFullscreen` | Prototype-only App fullscreen state marker. It may promote `.main` to a viewport-covering playback surface and disable ancestor visual effects that block fixed positioning, but must not redefine video-stage, video-frame, side-panel, or bottom-player layout rules. |
| `.player-chrome-visible` | video-page player-UI visible state | Drives Player UI visibility over the video. Player UI now means the bottom player plus the video-page top bar (the Close capsule is removed). Show/hide follows the Player-UI / cursor visibility state machine (v1) defined in `docs/product/12_liquid_glass_ux_mapping.md`. |
| `body.player-cursor-hidden` | playback cursor-hidden state | Hides the pointer cursor per the Player-UI / cursor visibility state machine (v1) in `docs/product/12_liquid_glass_ux_mapping.md`. Only real pointer movement (not clicks or keys) re-shows it. |
| `data-feedback-position` on `ui-feedback-overlay` | `PlaybackFeedbackPosition` | Center for most commands, leading for rewind and previous-result navigation, trailing for forward seek and next-result navigation. |
| `data-feedback-has-icon` on `ui-feedback-hud` | Optional feedback icon state | Text-only feedback hides the icon and selects the `ui-feedback-hud--text-capsule` compact capsule modifier. |
| `.is-visible` on `ui-feedback-hud` | Transient feedback presentation state | Shows the HUD while feedback is active; repeated commands update content in place instead of replaying the full entry animation. |

Icon asset rule:

- The copy-current-subtitle command uses the prototype `#copy` glyph, not a
  platform substitute. SwiftUI should implement it as a mapped custom symbol or
  shared vector asset so the button and feedback HUD match the HTML icon.
- Playback command feedback uses the same HUD component when its content
  changes repeatedly. Repeated commands may update text and run a small update
  pulse, but must not remount the HUD or replay the full entry animation.

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
| `--highlight`, `--highlight-text` | `LiquidGlassTokens.searchHighlight` | Search match highlighting. |
| `--search-page-*` | Page-specific semantic tokens | May be folded into general tokens if App surfaces share the same values. |
| `--mono`, `--sf` | Typography tokens | App uses native SF fonts and monospaced digits where needed. |

Rules:

- Token names in Swift should describe semantic role, not CSS implementation
  details.
- Shared token changes should be made once and consumed by all component
  styles.
- App implementation may use native materials and color-scheme behavior when
  they preserve the accepted visual intent.

## 9. Synchronization Workflow

HTML and Swift do not synchronize automatically. The sync contract is a
documented engineering workflow.

Required workflow for future UI class changes:

1. Update the HTML prototype source first.
2. If the change adds, removes, or redefines a `ui-*` class, update this
   mapping document in the same documentation change.
3. During App implementation, update the corresponding Swift component owner,
   not every individual call site.
4. If a class is prototype-only, mark it as such and keep it out of production
   SwiftUI.
5. If a class is surface layout only, document whether Swift should mirror it
   with a named view or implement the layout directly in the owning surface.
6. Visual verification should compare the prototype surface and App surface by
   component concept, state, and layout role.

Optional future automation:

- Add a machine-readable component manifest such as
  `ui/prototypes/cueseeker-liquid-glass-v6/component-map.json`.
- Generate a Swift enum skeleton from that manifest.
- Add a drift check that reports unmapped `ui-*` classes in the prototype.

This automation is optional. The first App rewrite can proceed with this
document as the source of truth.

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

- Should `ui-selectable-card` cover both Search/Shiori result cards and Library
  episode cards, or should Library episodes get a separate class anchor?
- Should topbar Library and Shiori buttons be modeled as `topbar` plus
  `toggle`, or as a distinct topbar-toggle variant?
- Should fullscreen playback chrome use the exact bottom-player component with
  a fullscreen context, or a separate component that shares the same token and
  button families?
- Should a component manifest be introduced before the App rewrite, or after
  the first native implementation proves the mapping stable?
