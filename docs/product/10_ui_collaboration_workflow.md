# UI Collaboration Workflow

Status: Draft

## 1. Purpose

This document defines the stable collaboration workflow for CueSeeker interface
design and App implementation.

During the active native UI restructure, the native SwiftUI/AppKit
implementation is the authoritative UI surface. Local HTML prototypes are
reference and review artifacts that can help explore or communicate a design,
but they no longer gate Swift implementation.

## 2. Directory Ownership

UI collaboration artifacts belong under the repository-level `ui/` directory:

```text
ui/
  prototypes/
  references/
  assets/
```

Stable product rules and known differences between HTML prototypes and the App
belong in `docs/product/`.

## 3. Collaboration Flow

The default UI collaboration flow is Swift-first:

```text
User defines or approves the App UI goal
Assistant implements the approved UI direction in native SwiftUI/AppKit
Assistant verifies build, tests, and any agreed manual/E2E acceptance checks
User reviews the native App result and requests alignment fixes
Assistant updates stable product, component, UX, or proposal documents when the
accepted Swift behavior becomes stable direction
Assistant updates or creates HTML prototypes only when they are useful as
reference artifacts, review handoff material, or explicit prototype-first work
```

Rules:

- App code may be changed for an App UI request once the user explicitly
  approves implementation. A local HTML prototype is not required first unless
  the user explicitly asks for prototype-first work.
- Native Swift implementation and accepted product behavior are authoritative.
  HTML prototypes must not override working Swift behavior, native App
  constraints, Search/Library/Shiori semantics, playback execution, or
  performance boundaries.
- `docs/product/11_liquid_glass_component_mapping.md` should be synchronized
  when accepted Swift implementation stabilizes component classes, token
  ownership, SwiftUI component ownership, or production/prototype-only
  boundaries.
- `docs/product/12_liquid_glass_ux_mapping.md` should be synchronized when
  accepted Swift implementation stabilizes layout, sizing, state lifetime,
  interaction flow, timing, animation, visibility, keyboard behavior, focus
  behavior, or native implementation boundaries.
- Stable UI/UX documents and backend-related documents must be updated when the
  accepted Swift implementation changes playback lifecycle, state ownership,
  persistence boundaries, or backend teardown semantics.
- For large native App UI rewrites, an accepted step document under
  `docs/proposals/` must define the implementation phases and acceptance gates.
  If the phase order or acceptance criteria change, update that step document
  before modifying App code.
- The mapping documents are not optional implementation notes. They record the
  stable semantic contract after Swift behavior is accepted, so future UI work
  can distinguish durable product direction from temporary implementation
  details.
- When the user returns a revised HTML file from another AI workflow, confirm
  whether the user wants prototype-first visual alignment or Swift-first native
  implementation. The default remains Swift-first.
- Large-scale HTML prototype changes must fork a new versioned prototype source
  directory instead of overwriting the currently accepted or reviewable
  prototype, so the user can compare the before and after designs side by side.
- If a required interaction is unclear, confirm it before finalizing either the
  Swift implementation or an HTML reference artifact.

## 3.1 Component Vocabulary

UI alignment should use stable component concepts before implementation details.

Rules:

- Describe elements by component class first, such as `search field capsule`,
  `circular icon toggle button`, `capsule command button`, `segmented control`,
  `result card`, or `rounded-rectangle popup menu`.
- If the user asks what a component concept means, explain it by visible shape
  and behavior first. Use a familiar element analogy second. Do not lead with
  raw measurements, colors, or CSS values unless the user explicitly asks for
  implementation detail.
- Every accepted UI element must be classified in the relevant UI design
  document. The classification should make clear whether a change targets one
  specific element or the whole component class.
- If a requested UI change is ambiguous about scope, ask whether it should be a
  special treatment for that element or a rule change for every element in the
  same component class.
- Component class names are product vocabulary. HTML classes, SwiftUI views,
  AppKit views, and CSS selectors may use different names as long as the
  documented component concept is preserved.

## 4. Prototype Requirements

When local HTML prototypes are used, they must be easy to review, diff, and
edit with web-focused AI tools.

Rules:

- The primary editable prototype format is a normal web source directory with
  `index.html`, `styles.css`, and `script.js`.
- The editable source directory should be the only place where iterative UI
  changes are made. Generated standalone HTML files are exports, not source.
- Every time the editable HTML prototype is modified, a bundled standalone HTML
  export must be generated or refreshed in the same prototype directory.
- The default export name is `standalone.html`, such as
  `ui/prototypes/cueseeker-liquid-glass-v4/standalone.html`.
- The bundled standalone export exists so the current prototype can be handed
  to another AI or tool without additional packaging steps.
- Generated standalone exports must be treated as disposable artifacts. If an
  export needs further design changes, the changes should be made in the source
  directory and then exported again.
- Prototypes should include basic UI behavior such as disclosure, expansion,
  popovers, menus, selected states, hover states, pressed states, and disabled
  states where relevant.
- Prototypes do not need to implement real product behavior such as video
  playback, indexing, database access, or file-system access.
- Complex UI may be split across multiple focused HTML prototypes. For example,
  a playback page prototype may show the video frame and side panel, while a
  separate prototype may isolate detailed control-menu interactions.
- When a prototype change affects a broad visual system, such as theme support,
  component taxonomy, page-wide layout, or the shared bottom player style, the
  assistant should create a new versioned source directory under
  `ui/prototypes/` before editing the prototype and leave the prior prototype
  available for visual comparison.
- New prototype directories should use the stable prototype name plus a version
  number, such as `cueseeker-liquid-glass-v4/`. Do not encode the change
  semantics in the directory name; Git history and the changelog record what
  changed.
- The new prototype directory should be registered or proposed in the prototype
  registry once it becomes the accepted baseline.

## 5. HTML And App Differences

HTML prototypes and the native macOS App may differ when platform behavior,
Swift implementation, product behavior, or performance constraints require it.

Known acceptable difference categories:

- Native macOS window chrome, traffic-light controls, full-screen behavior, and
  system titlebar mechanics.
- System materials, vibrancy, focus rings, font rendering, accessibility
  behavior, and user-selected accent colors.
- Native media playback, file access, sandboxing, indexing, and database state.
- Performance-driven virtualization, lazy loading, and rendering details that
  preserve the accepted visual result.
- Prototype-only test controls used to review themes, disabled states, or other
  visual states. These controls may sit outside the prototype window, but their
  placement and behavior must be documented as HTML-only review fixtures before
  App implementation.

Rules:

- Differences that affect stable visible layout, state, interaction, wording,
  or timing should be documented when the Swift behavior is accepted as stable.
- HTML limitations must not silently become App product behavior.
- App implementation should preserve accepted visual hierarchy and interaction
  intent, but the accepted Swift result is the source of truth during active
  native UI restructuring.

## 6. Design Style

CueSeeker should remain a focused native macOS desktop tool.

Style rules:

- Prefer quiet, dense, readable work surfaces over marketing-style layouts.
- Keep playback, Search, Library, and Shiori controls visually direct and
  utilitarian.
- Use native macOS interaction expectations where they do not conflict with the
  accepted HTML visual direction.
- Avoid decorative hero sections, one-off ornament, and ambiguous controls.
- Preserve the current topbar-driven workbench direction unless a later accepted
  UI prototype and product document supersede it.

## 7. Prototype Registry

Active App surface reference mapping:

Current Cue-centric precedence rule: Search, Shiori, and
Playback Multi-Module Overlay are native-only accepted surfaces. The grouped Search /
Shiori card and `Collapse All` behaviors in older HTML prototypes are
**Superseded** and must not be used to regress the App. Native AppKit table
virtualization, dynamic Cue geometry, `Show Cue Group` refresh isolation, and
Focus accepted placement are intentional native differences.

Current proposed review fork:

```text
ui/prototypes/cueseeker-liquid-glass-v5/
```

This directory is the active review fork for Liquid Glass control states, theme
review, disabled-state review, active-playback bottom-player control sizing,
expanded playback video geometry, fullscreen feedback, playback-close UX, and
split-source prototype editing. It does not replace the accepted baseline in
the table below until the user accepts it.

| App surface | HTML reference prototype | Coverage status | Known native App differences |
| --- | --- | --- | --- |
| Main workbench shell | `ui/prototypes/cueseeker-liquid-glass-standalone.html` | Current Liquid Glass visual baseline for the search-state shell and active-playback bottom player | Native titlebar, traffic lights, full-screen transition behavior, system materials, font rendering, and accessibility focus behavior remain App-native |
| Search results | Native App; older grouped-card HTML is Superseded | Current native virtual Cue table with dynamic rows; one primary Cue per row, optional Cue Group context above it | AppKit virtualization, exact Cue counts/pages, complete text, `16 + 24P + 20S` row geometry, stable-anchor reflow, and presentation-only `Show Cue Group` are App-authoritative |
| Search-launched playback overlay and bottom player | `ui/prototypes/cueseeker-liquid-glass-standalone.html` | Current visual baseline for the video surface, close capsule, subtitle overlay, right playback side panel, active-playback bottom player, speed menu, and visibility toggles | App playback, seeking, close lifecycle, file access, fullscreen presentation, subtitle rendering, and persisted playback state remain native behaviors |
| Shiori playback control | Superseded | Retired from normal playback chrome | Exact-Cue Shiori saving is available in eligible Playback Multi-Module Overlay modules through `S`; idempotence and feedback remain native behaviors |
| Library view | Pending | Waiting for a dedicated accepted HTML prototype | Not yet documented |
| Full Shiori view | Native App; older grouped-card HTML is Superseded | Current native virtual Cue table with dynamic rows, Tags, Time, and Date Added | Shiori identity/tag ownership is one Cue; optional Cue Group content is presentation-only and table refresh stays locally scoped |
| Playback Multi-Module Overlay | Native App only | Current Cue reel, shared Playlist/Search/Shiori Cue Result reel, Recent/Library media layouts, and fixed Sidebar; no HTML baseline | Temporary Session lifecycle, module order, Current `max(52L, visual-line stack height) + 24` geometry, shared virtualization, live Search, exact-Primary-Cue actions, and visible-plus-overscan work are App-authoritative |
| Settings windows | Pending | Waiting for a dedicated accepted HTML prototype | Native macOS settings-window behavior is expected |

When a prototype is accepted or superseded, this registry must record the
corresponding `ui/prototypes/*.html` file and any known native App differences.
