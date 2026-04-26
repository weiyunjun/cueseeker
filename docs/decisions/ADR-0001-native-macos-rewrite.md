# ADR-0001: Native macOS Rewrite

Status: Accepted

## Background

SubFinderX started as a Flutter implementation. The project direction has changed toward a focused personal macOS desktop app for local subtitle search and timestamp playback.

The current product direction prioritizes:

- Local subtitle folder selection.
- `.srt` scanning and parsing.
- SQLite + FTS5 search.
- Local video playback from search results.
- Native macOS interaction quality.
- A maintainable local-first data model.

The legacy Flutter implementation has been preserved as a baseline and archived under `archive/flutter/`.

## Decision

SubFinderX will be rewritten as a native macOS application.

The active native implementation will live under:

```text
apps/macos-native/
```

The archived Flutter implementation will remain under:

```text
archive/flutter/
```

The initial native rewrite will target macOS only. Mobile, cross-platform, remote playback, WebDAV, AList, and cloud sync features are out of scope for the early rewrite.

The provisional minimum supported macOS version is macOS 13.0 Ventura.

## Rationale

The product's core value is a fast local desktop workflow:

```text
Search subtitle text
Select a result
Open the matching local video
Seek to the subtitle timestamp
```

A native macOS rewrite better matches the product direction because it can prioritize:

- Native folder selection and file access behavior.
- Native window, keyboard, sidebar, toolbar, and settings patterns.
- Direct control over local playback integration.
- A focused local database and indexing architecture.
- Reduced cross-platform complexity during the early milestones.

The project is optimized for personal macOS usage rather than broad cross-platform distribution.

## Tradeoffs

Benefits:

- Better alignment with macOS-first product goals.
- Simpler early scope.
- More direct access to macOS-specific file access, UI, and playback behavior.
- Less need to preserve mobile or web abstractions.

Costs:

- Flutter cross-platform compatibility is no longer an active goal.
- Existing Flutter UI and app structure cannot be reused directly.
- Native macOS build, signing, sandboxing, and release rules must be documented.
- Playback engine choice remains a separate high-risk decision.

## Alternatives Considered

### Continue Flutter

Continuing the Flutter implementation would preserve the current codebase and cross-platform option.

It was not selected because the confirmed product direction is macOS-first, local-first, and focused on native desktop behavior rather than cross-platform parity.

### Hybrid Rewrite

A hybrid approach could keep some Flutter code while adding native macOS modules.

It was not selected for the early rewrite because it would increase architecture complexity before the minimal local loop is stable.

### Native macOS Rewrite

A native macOS rewrite gives the project a clean architecture boundary and lets early milestones focus on local indexing, search, and playback.

This option was selected.

## Consequences

- Active app code must be created under `apps/macos-native/`.
- Archived Flutter code is reference material, not active implementation.
- Product and engineering documents are the source of truth for the native rewrite.
- Playback engine selection still requires a separate ADR before production implementation depends on it.
- Sandboxing, signing, notarization, and release strategy must be finalized before formal release.
- Direct Flutter database compatibility is not assumed unless a future ADR approves it.

