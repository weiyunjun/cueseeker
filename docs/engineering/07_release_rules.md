# Release Rules

Status: Draft

## 1. Purpose

This document defines packaging and release rules for CueSeeker.

The early native macOS rewrite is a personal local tool first. Release discipline still matters because signing, sandboxing, file access, and database upgrades can affect user data.

## 2. Release Principles

Releases should be deliberate and reproducible.

Principles:

- Local development builds are not formal releases.
- A formal release must have a documented version, build configuration, and verification checklist.
- Packaging decisions must not silently change file access, database location, or user data behavior.
- Signing, notarization, sandboxing, and entitlements must be documented before a build is treated as distributable.
- Database upgrade behavior must be verified before releasing a build that changes schema.

## 3. Build Types

Expected build types:

- Local development build.
- Local review build.
- Personal release build.
- Future distributable build, if public distribution is later approved.

Rules:

- Local development builds may remain unsigned development builds.
- Local review builds should be reproducible from committed source.
- Personal release builds must pass the release checklist in this document.
- Public distribution is out of scope for the early native rewrite and requires updated product and release documentation.

## 4. Versioning

The final versioning scheme must be documented before the first formal release.

Rules:

- Each formal release must have a human-readable version.
- Each formal release should have a build number or equivalent build identifier.
- Release tags must map clearly to released source state.
- Version changes should not be mixed with unrelated implementation changes.

Provisional milestone labels:

- M1: Native macOS minimal loop.
- M2: macOS experience polish.
- M3: Favorites and personal learning flow.

## 5. Bundle Identity

The app bundle identifier must be chosen before formal packaging.

Rules:

- The bundle identifier must be stable once user data storage depends on it.
- Changing the bundle identifier after release requires a documented migration plan.
- Entitlements and sandbox behavior must match the chosen bundle identity.

## 6. Signing and Notarization

Signing and notarization strategy must be documented before any build is presented as distributable.

Rules:

- Unsigned local builds are acceptable for early development.
- Signed builds must use a documented certificate strategy.
- Notarized builds require a release checklist update.
- Any bundled native dependency that affects signing or notarization must be reviewed before release.
- Playback engine choice may affect signing and notarization and must be considered in the playback ADR.
- ADR-0007 removes production `libmpv` compatibility. Release packaging should
  account for FFmpeg libraries and required non-system FFmpeg dependencies, but
  should not include `libmpv` unless a future ADR reintroduces it.
- The first source ASS subtitle rendering step uses a project-owned ASS Lite
  renderer and should not add an external ASS rendering dependency.
- Future external ASS rendering, font, or text-shaping dependencies must be
  reviewed for packaging, signing, and notarization impact before a build that
  includes those dependencies is treated as releasable.

## 7. Sandboxing and Entitlements

Sandboxing and entitlements directly affect local folder and video access.

Rules:

- ADR-0004 disables App Sandbox for M1 local development and personal builds.
- If sandboxing is later enabled, required entitlements must be documented.
- Security-scoped bookmark behavior must be verified before any sandboxed release if the app relies on persistent folder access.
- If sandboxing remains disabled for a personal release, that release must explicitly verify the unsandboxed setting.
- Release builds must not accidentally change sandbox behavior compared with tested builds.

## 8. Database Upgrade Safety

Releases that change the database schema require explicit verification.

Rules:

- Fresh database creation must pass.
- Migration from the previous released schema must pass.
- Durable user state must be preserved unless a destructive change has an ADR.
- Rebuildable index data may be rebuilt from source subtitle files.
- A release that changes schema must include migration notes.

## 9. Release Checklist

Before a formal release, verify:

```text
Version and build identifier are set
Release source state is committed
Required tests pass
Manual milestone acceptance checks pass
Database fresh-create path passes
Database migration path passes if schema changed
Playback workflow is verified if release includes playback
Folder access behavior is verified
Signing strategy is followed if signing is enabled
Notarization strategy is followed if notarization is enabled
Sandbox and entitlements match documented expectations
Changelog is updated
Release tag is created if this is a tagged release
```

Rules:

- Checklist failures must be fixed or explicitly documented as known release limitations.
- Do not mark a milestone complete only because the app builds.
- Do not release a build with unreviewed schema changes.

## 10. Distribution

Early distribution target:

- Personal local use.

Out of scope for the early rewrite:

- Mac App Store distribution.
- Enterprise deployment.
- Public onboarding.
- Plugin marketplace support.

Rules:

- Any public distribution plan requires product documentation updates.
- Any public distribution plan requires release rule updates.
- Distribution method must not be decided implicitly by build tooling.

## 11. Changelog and Tags

Formal releases must update project records.

Rules:

- `docs/changelog.md` must record formal release progress, release candidates, and tagged release or milestone points.
- Required release changelog entries must be added before creating the corresponding release tag.
- Git tags should mark meaningful release or milestone points.
- Tags must not be moved without explicit approval.
- Release notes must be written in English.

## 12. Known Early Limitations

Until the native app project and packaging strategy exist, the following remain provisional:

- Bundle identifier.
- Versioning scheme.
- Signing strategy.
- Notarization strategy.
- Entitlements.
- Distribution method.

These items must be finalized before a formal distributable release.
