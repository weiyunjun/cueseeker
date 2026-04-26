# Architecture Rules

Status: Draft

## 1. Purpose

This document defines architecture rules for the native macOS rewrite of SubFinderX.

It is an engineering rule document, not a product requirements document. Product behavior belongs in `docs/product/`.

## 2. Architecture Principles

The native rewrite must prioritize a small, reliable local workflow before broader features.

Core principles:

- Keep the M1 implementation focused on the local subtitle search and playback loop.
- Prefer native macOS capabilities when they satisfy the product requirement.
- Keep persistent data local unless a future proposal explicitly changes that rule.
- Make hard-to-reverse technical decisions through ADRs before production implementation depends on them.
- Keep modules isolated enough that indexing, search, persistence, and playback can be tested independently.
- Avoid introducing remote services, sync layers, or cross-platform abstractions during the early native rewrite.

## 3. Target Platform

Primary platform:

- macOS.

Minimum supported version:

- macOS 13.0 Ventura, provisional.

Rules:

- The app must not depend on Flutter for active native implementation.
- The active native app must live under `apps/macos-native/`.
- Raising the minimum macOS version requires updating product and engineering documentation.
- If a newer minimum version is required by a playback, sandboxing, or UI decision, that decision must be recorded before implementation depends on it.

## 4. Application Stack

The initial native rewrite should use native macOS development tools.

Required stack decisions before implementation:

- UI framework choice.
- Application architecture pattern.
- SQLite access strategy.
- Playback engine strategy.
- Dependency management strategy.
- Sandbox and file-access strategy.
- Packaging and distribution expectations.

Default assumptions until a more specific document or ADR replaces them:

- UI should use native macOS frameworks.
- Persistent search data should use SQLite with FTS5.
- Remote services are out of scope.
- Local file access is central to the app and must be designed explicitly.

## 5. Module Boundaries

The native app should be organized around clear engineering responsibilities.

Expected responsibility areas:

- App shell and window lifecycle.
- Folder selection and file access.
- Subtitle scanning.
- Subtitle parsing.
- Video matching.
- Database persistence and migrations.
- Full-text search.
- Playback.
- Settings and local configuration.
- Error reporting and logging.

Rules:

- Subtitle parsing must not depend on UI state.
- Database persistence must not depend on playback UI state.
- Search must read from the database/index layer, not directly from arbitrary subtitle files.
- Playback must receive a resolved local video path and timestamp, not perform subtitle parsing itself.
- UI state may coordinate workflows, but it must not be the only place where indexing or database rules are enforced.

## 6. Data Flow

The M1 local loop should follow this conceptual flow:

```text
Selected folders
Scan .srt files
Parse subtitle entries
Match local video files
Persist metadata and subtitle entries
Update FTS index
Search indexed text
Open matched video at start_ms
```

Rules:

- Source subtitle files remain the source of truth for indexed subtitle content.
- The SQLite database is an indexed local cache plus local app state, not a replacement for the source files.
- Reindexing must be able to remove stale entries when source subtitle files disappear.
- Search result playback must be based on persisted subtitle timing and matched video path.

## 7. UI Architecture

The UI must support the product's native macOS workflow without forcing future remote or cross-platform assumptions.

Rules:

- The first usable screen should support search and local folder management paths.
- M1 may expose only the settings surface required to manage folders and indexing.
- Broader settings polish belongs to M2.
- Search, indexing status, and playback state should be represented explicitly in UI state.
- Keyboard behavior must preserve standard macOS text editing behavior.
- UI errors should be concise and actionable, with technical detail reserved for logs.

## 8. File Access and Sandboxing

Local subtitle and video file access is a core product requirement.

Rules:

- Folder selection must use native macOS folder selection behavior.
- Persistent access to selected folders must be designed before relying on it across launches.
- If sandboxing is enabled, security-scoped bookmark handling must be documented and tested.
- If sandboxing is deferred for personal local use, that decision must be documented before packaging assumptions depend on it.
- The app must not silently scan folders that the user has not selected or otherwise authorized.

The final sandboxing and persistent file-access strategy may require an ADR.

## 9. Playback Architecture

Playback is a high-risk component.

Rules:

- M1 requires local file playback and timestamp seek only.
- The playback engine must be selected through an ADR before production implementation depends on it.
- The playback ADR must compare AVFoundation, embedded `libmpv`, and any other serious candidate.
- Playback code must not assume remote streams, local HTTP proxying, cache layers, or advanced subtitle rendering.
- Playback errors must be propagated in a form that the UI can present clearly.

## 10. Dependency Management

Dependencies should be introduced conservatively.

Rules:

- Prefer platform APIs and small focused dependencies over broad frameworks.
- Any dependency that affects playback, database access, sandboxing, packaging, or signing must be documented before adoption.
- Dependencies that require bundled native binaries, special signing, or notarization handling require explicit review.
- Package manager and build tooling choices must be documented in or alongside the native app project.

## 11. Logging and Diagnostics

Logging should support debugging without exposing unnecessary personal data.

Rules:

- Logs may include technical diagnostics for indexing, parsing, database, search, playback, and UI errors.
- Logs must not include credentials, tokens, or authentication headers.
- Logs should avoid dumping full user file trees.
- User paths may be logged when necessary to debug local file behavior, but broad recursive listings should be avoided.
- User-facing errors should be shorter and less technical than diagnostic logs.

Recommended error categories:

- File access.
- Subtitle parsing.
- Video matching.
- Database.
- Search.
- Playback.
- UI state.

## 12. Credential and Secret Handling

The early native rewrite should not require stored credentials.

Rules:

- Do not introduce credential storage for M1.
- Do not store passwords, tokens, API keys, or authentication headers in plain text.
- If future features need credentials, prefer macOS Keychain.
- Credential handling requires documentation before implementation.
- Secrets must not be written to Git-tracked files or logs.

## 13. Configuration

Local configuration should remain minimal in M1.

Expected M1 configuration:

- Selected local subtitle folders.
- Indexing state needed to support refresh behavior.
- Window or section persistence only if practical.

Rules:

- Configuration must be local to the user's machine.
- Configuration storage format must be documented before it becomes hard to migrate.
- Configuration should not duplicate large indexed subtitle content outside the database.

## 14. Legacy Flutter Reference

The archived Flutter implementation may be used as a reference, but it is not active code.

Rules:

- Do not import active Flutter dependencies into the native app.
- Do not assume archived database compatibility without a documented database strategy.
- Useful behavior from the archived implementation should be translated into native architecture deliberately.

## 15. ADR Requirements

The following decisions require ADRs before production implementation depends on them:

- Final playback engine.
- Sandboxing and persistent folder access strategy, if non-trivial.
- Direct compatibility with or migration from the archived Flutter database.
- Any destructive or hard-to-reverse schema change.
- Any remote service, sync, or network-backed storage feature.
- Raising the minimum supported macOS version.

