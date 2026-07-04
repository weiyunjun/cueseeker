# Accent Color UI Integration

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Accent Color UI Integration.md`
- `docs/human/design/UI.md`

## Scope

Align the native macOS UI color tokens requested by the human-owned documents
so focus treatments, Library and Recent media progress, media-card hover
surfaces, and playback progress use the current macOS system accent color.

## Classification

- Product semantics: unchanged; playback position, watch progress, search, and
  Library behavior keep the same meaning.
- Platform UI/UX: focus borders and rings, media-card hover fills, Library and
  Recent progress fills, and player progress fills now follow the system accent
  color.
- Platform integration: unchanged; the change reuses SwiftUI `Color.accentColor`
  and AppKit `NSColor.controlAccentColor`.
- Playback execution: unchanged; only the visual progress fill color changed.

## Changes

- Added a shared AppKit helper for system-accent colors with light and dark
  appearance opacity.
- Replaced the redesign focus border with the macOS control accent color and
  made the focus ring use the documented light and dark opacity values.
- Replaced Library and Recent cover progress fill tokens with the macOS accent
  color.
- Replaced Library and Recent media-card hover background tokens with the
  documented low-opacity accent color.
- Replaced the player progress fill token with SwiftUI `Color.accentColor`, so
  the played track and progress thumb use the same system accent.
- Updated the shared Liquid Glass card hover fill to use the same low-opacity
  accent treatment.

## Verification

- `git diff --check` passed.
- `swift build` passed in `apps/macos-native`.

## Outcome

The requested UI accent-color integration is implemented without changing
product behavior or playback execution. Focus treatments, video-card hover
surfaces, Library and Recent cover progress, and player timeline progress now
derive from the macOS system accent color.
