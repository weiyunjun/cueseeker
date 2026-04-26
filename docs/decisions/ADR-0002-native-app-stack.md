# ADR-0002: Native App Stack

Status: Accepted

## Background

SubFinderX is being rewritten as a native macOS application. Before M1 implementation starts, the project needs a stable app stack decision for UI, architecture, dependency management, database access, and platform baseline.

The M1 goal is the native macOS minimal loop:

```text
Select local subtitle folders
Index .srt files
Search indexed subtitle text
Open the matching local video at the subtitle timestamp
```

## Decision

The native macOS app will use:

- Language: Swift.
- UI framework: SwiftUI for the app shell and main views.
- Native integration: AppKit bridges where SwiftUI is insufficient.
- App lifecycle: native macOS app lifecycle.
- Minimum macOS version: macOS 13.0 Ventura, provisional.
- Project location: `apps/macos-native/`.
- Dependency management: Swift Package Manager where possible.
- Database engine: SQLite with FTS5.
- SQLite access: a small project-owned persistence layer over SQLite rather than a broad ORM for M1.
- Concurrency: Swift concurrency for UI-safe asynchronous work where practical.
- Architecture style: feature-oriented modules with explicit service boundaries.

Expected M1 responsibility areas:

- App shell and window lifecycle.
- Folder selection and file access.
- Subtitle scanning.
- Subtitle parsing.
- Video matching.
- Database persistence and migrations.
- Full-text search.
- Playback integration.
- Settings surface for folder and indexing management.
- Error reporting and diagnostics.

## Rationale

Swift and native macOS frameworks align with the project's macOS-first direction.

SwiftUI gives a fast path to a native app shell, while AppKit remains available for macOS-specific details such as file panels, responder behavior, advanced window behavior, and embedded playback views.

A small project-owned SQLite persistence layer keeps the M1 database behavior explicit and testable. It also avoids committing too early to a larger abstraction before the schema, migration rules, and FTS behavior settle.

Swift Package Manager keeps dependency management close to the native toolchain and avoids introducing extra package systems before they are needed.

## Tradeoffs

Benefits:

- Native macOS user experience.
- Direct access to macOS file, window, keyboard, and app lifecycle behavior.
- Lower cross-platform complexity.
- Clear boundary between active native code and archived Flutter reference code.
- Easier testing of parser, indexing, database, and search modules outside the UI.

Costs:

- Flutter UI and cross-platform abstractions cannot be reused directly.
- Some macOS behavior may require AppKit bridges in addition to SwiftUI.
- A project-owned SQLite layer requires discipline around migrations and tests.
- SwiftUI behavior may need manual verification for desktop interaction polish.

## Alternatives Considered

### Continue Flutter

Continuing Flutter would preserve the existing app structure and cross-platform potential.

It was rejected by ADR-0001 because the project direction is native macOS, local-first, and optimized for personal desktop usage.

### AppKit-Only Native App

An AppKit-only app would provide mature desktop control and predictable macOS behavior.

It was not selected as the default because M1 benefits from a faster declarative UI path, and AppKit can still be used where needed.

### SwiftUI With AppKit Bridges

SwiftUI with AppKit bridges balances implementation speed and native macOS integration.

This option was selected.

### Third-Party Database ORM

A third-party ORM could reduce boilerplate.

It was not selected for M1 because explicit schema, migration, FTS5, and test behavior are more important than abstraction convenience at this stage.

## Consequences

- The native app project should be created under `apps/macos-native/`.
- Active app code should be Swift.
- SwiftUI should be the default UI layer.
- AppKit bridges are allowed for file access, window behavior, keyboard behavior, and embedded playback.
- SQLite schema and migration behavior must follow `docs/engineering/05_database_rules.md`.
- Dependency additions that affect signing, packaging, playback, or database behavior require review.
- Raising the minimum macOS version requires documentation updates and may require a new ADR.

