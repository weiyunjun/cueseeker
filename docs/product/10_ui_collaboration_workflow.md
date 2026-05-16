# UI Collaboration Workflow

Status: Draft

## 1. Purpose

This document defines the stable collaboration workflow for CueSeeker interface
design and App implementation.

The local HTML prototype is the visual alignment source for UI work. App code
should follow only after the relevant HTML has been visually accepted.

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

The default UI collaboration flow is:

```text
User provides an original HTML draft
Assistant recreates or updates the local HTML prototype
User reviews visual differences and requests alignment fixes
Assistant updates the HTML prototype until accepted
Assistant documents stable rules and known HTML/App differences
Assistant implements the accepted design in App code only after explicit approval
```

Rules:

- Every App interface modification must start with a local HTML prototype under
  `ui/prototypes/`.
- App code must not be changed for a UI request until the relevant HTML
  prototype has been visually aligned and the user has explicitly approved App
  implementation.
- When the user returns a revised HTML file from another AI workflow, treat that
  file as the new original draft and repeat the alignment flow.
- Large-scale HTML prototype changes must fork a new prototype file instead of
  overwriting the currently accepted or reviewable file, so the user can compare
  the before and after designs side by side.
- If a required interaction is unclear, confirm it before finalizing the HTML
  prototype.

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

Local HTML prototypes must be easy to share with web-focused AI tools.

Rules:

- Each prototype should be a single self-contained HTML file with bundled CSS
  and JavaScript.
- CSS and JavaScript may be split out only when the split is explicitly useful
  for a complex prototype and documented near the prototype.
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
  assistant should create a new self-contained HTML file under `ui/prototypes/`
  and leave the prior prototype available for visual comparison.
- New prototype files should use the stable prototype name plus a version
  number, such as `cueseeker-liquid-glass-v2.html`. Do not encode the change
  semantics in the file name; Git history and the changelog record what changed.
- The new file should be registered or proposed in the prototype registry once
  it becomes the accepted baseline.

## 5. HTML And App Differences

HTML prototypes and the native macOS App may differ when platform behavior
requires it.

Known acceptable difference categories:

- Native macOS window chrome, traffic-light controls, full-screen behavior, and
  system titlebar mechanics.
- System materials, vibrancy, focus rings, font rendering, accessibility
  behavior, and user-selected accent colors.
- Native media playback, file access, sandboxing, indexing, and database state.
- Performance-driven virtualization, lazy loading, and rendering details that
  preserve the accepted visual result.

Rules:

- Differences that affect visible layout, state, interaction, wording, or
  timing must be documented before or with App implementation.
- HTML limitations must not silently become App product behavior.
- App implementation should preserve the accepted visual hierarchy and
  interaction intent even when native controls require implementation-specific
  details.

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

Active App surface mapping:

| App surface | Required HTML prototype | Coverage status | Known native App differences |
| --- | --- | --- | --- |
| Main workbench shell | `ui/prototypes/cueseeker-liquid-glass-standalone.html` | Current Liquid Glass visual baseline for the search-state shell and persistent bottom player | Native titlebar, traffic lights, full-screen transition behavior, system materials, font rendering, and accessibility focus behavior remain App-native |
| Search results | `ui/prototypes/cueseeker-liquid-glass-standalone.html` | Current visual baseline for grouped Search results, result cards, disclosure behavior, and fixed `Collapse All` behavior | App data, lazy loading, virtualization, exact counts, and result ordering must come from the native Search pipeline |
| Search-launched playback overlay and bottom player | `ui/prototypes/cueseeker-liquid-glass-standalone.html` | Current visual baseline for the video surface, subtitle overlay, right playback side panel, bottom player, speed menu, and visibility toggles | App playback, seeking, file access, fullscreen presentation, subtitle rendering, and persisted playback state remain native behaviors |
| Shiori playback control | `ui/prototypes/cueseeker-liquid-glass-standalone.html` | Current visual baseline for the bottom-player Shiori toggle state | App Shiori persistence, duplicate handling, and feedback timing remain native behaviors |
| Library view | Pending | Waiting for a dedicated accepted HTML prototype | Not yet documented |
| Full Shiori view | Pending | Waiting for a dedicated accepted HTML prototype | Not yet documented |
| Settings windows | Pending | Waiting for a dedicated accepted HTML prototype | Native macOS settings-window behavior is expected |

When a prototype is accepted or superseded, this registry must record the
corresponding `ui/prototypes/*.html` file and any known native App differences.
