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
ui/prototypes/cueseeker-liquid-glass-v5/
```

Included App surfaces:

- Main workbench shell.
- Topbar Library, Shiori, and Search controls.
- Search results.
- Library grouped episode grid.
- Shiori grouped cards.
- Active-playback bottom player.
- Expanded playback video surface.
- Expanded playback side panel.
- Playback fullscreen chrome.
- Playback close capsule.

Out of scope for this mapping pass:

- Settings window UI.
- Prototype-only review controls such as theme switching and disable-all
  controls.
- Native window chrome, traffic lights, AppKit fullscreen lifecycle, playback
  backend, database, indexing, Search pagination, lazy loading, and first-screen
  render behavior.

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
| `LiquidGlassSurface` | Shared workbench, bottom-player, sidebar, and video-stage surfaces. |
| `LiquidGlassFeedbackOverlay` | Transient playback input feedback shown over the active video stage. |

Implementation may choose different final Swift type names, but each accepted
component class below must have one native owner. Shared visual rules should
live in that owner, not in individual call sites.

## 5. Component Class Mapping

| HTML class anchor | Product component concept | SwiftUI owner | App usage |
| --- | --- | --- | --- |
| `ui-capsule` | Capsule button base | `LiquidGlassCapsuleButton` / capsule `ButtonStyle` | Shared base for visible pill-shaped text/value controls. |
| `ui-capsule--command` | Capsule command button | `LiquidGlassCapsuleButton.Kind.command` | `Collapse All` and similar compact commands. |
| `ui-capsule--video-close` | Video close capsule command | `LiquidGlassCapsuleButton.Kind.videoClose` | Top-left close command anchored to the active video frame. |
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

Retired active-target component:

- `ui-capsule--source` / `.source-toggle` belonged to the previous
  bottom-player source/title expand-collapse control. The active target UI
  removes that bottom-left collapse control, so SwiftUI should not implement it
  as the entry point for expanded playback. Playback opens from Search, Library,
  or Shiori activation, and closes through the video-stage `Close` capsule.

## 6. Surface Mapping

| App surface | HTML source concept | SwiftUI owner to create or refactor | Behavior owner to preserve |
| --- | --- | --- | --- |
| Main workbench shell | `.window`, `.main`, `.toolbar` | `ContentView`, `AppTopBar`, `LiquidGlassSurface` | `AppState`, `WorkbenchLayoutState`, native window setup. |
| Topbar mode buttons | `ui-icon-button--topbar` | `LiquidGlassIconButton.Kind.topbar` | `activateWorkbenchPanelMode`. |
| Topbar Search | `ui-input-capsule`, `ui-icon-button--embedded` | `LiquidGlassSearchField` | `TopbarSearchInputState`, Return-submit flow. |
| Search page | `.search-state`, result groups, `ui-selectable-card` | Search page view plus `LiquidGlassSelectableCard` | Existing Search query, grouping, lazy loading, load-more, exact counts. |
| Library page | `.library-state`, episode cards | Library page view plus disclosure and episode card components | Existing Library folder grouping, collapse state, open video behavior. |
| Shiori page | `.shiori-state`, grouped cards | Shiori page view plus `LiquidGlassSelectableCard` | Existing Shiori persistence and open behavior. |
| Bottom player | `.player-dock`, `.player-hud` | `BottomPlaybackBar`, `LiquidGlassBottomPlayer` | Active playback session visibility, playback view model, seek, volume, speed, navigation, Shiori, copy, subtitles. |
| Expanded playback | `.video-state`, `.video-stage`, `.video-frame`, `ui-capsule--video-close`, `ui-feedback-overlay` | `PlaybackExpandedLayout`, video stage surface, `LiquidGlassFeedbackOverlay` | Real video aspect ratio, frame-anchored close placement, playback render view lifecycle, playback close lifecycle, playback input feedback. |
| Playback side panel | `.sidebar`, `ui-segmented-control`, `ui-selectable-row` | Playback side-panel views plus segmented and row components | Search navigation snapshot, current subtitle entries, row activation. |
| Fullscreen playback chrome | Prototype bottom-player visual language plus `ui-feedback-overlay` | Fullscreen overlay using same bottom-player and feedback component families | AppKit fullscreen lifecycle, render-view ownership, cursor and chrome visibility timing, playback input feedback. |

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
| `.video-expanded` | `appState.isPlaybackSurfaceExpanded` | Controls expanded playback layout and bottom-player context. |
| `.playback-closed` / no active playback marker | `appState.hasPlaybackSelection == false` or equivalent derived playback-session state | Hides playback UI after close. The bottom player is also hidden whenever `.video-expanded` is false, so non-video Search, Library, and Shiori pages do not show the bottom player. |
| `.sidebar-hidden` | `!appState.isPlaybackSidePanelVisible` | Controls expanded playback side-panel visibility. |
| `body.prototype-fullscreen` | `playbackFullscreenManager.isFullscreen` | Prototype-only App fullscreen state marker. It may promote `.main` to a viewport-covering playback surface and disable ancestor visual effects that block fixed positioning, but must not redefine video-stage, video-frame, side-panel, or bottom-player layout rules. |
| `.player-chrome-visible` | fullscreen or expanded playback player-UI visible state | Drives player UI visibility over video. Player UI means the floating bottom player plus the video-frame `Close` capsule, and it has only visible / not-visible states. |
| `body.player-cursor-hidden` | playback cursor-hidden state | Hides the pointer cursor only while the current player UI state requires cursor hiding. Mouse movement clears this state. |
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
  `ui/prototypes/cueseeker-liquid-glass-v5/component-map.json`.
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
