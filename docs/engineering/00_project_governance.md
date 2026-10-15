# CueSeeker Project Governance and Workflow

## 1. Document Status

Status: Draft

Scope: Project workflow, documentation rules, change management, technical stack governance, repository structure, Git usage, database migration rules, playback selection rules, credential storage rules, logging strategy, testing strategy, packaging strategy, legacy-code archival, milestone governance, and change records.

This document defines how the project is managed. It is not a product requirements document and should not be used to define detailed product behavior.

## 2. Governance Principles

CueSeeker should be managed through explicit documents and small, reviewable implementation steps.

The project follows these principles:

- Documentation comes before major implementation when a project-specific
  decision, workflow, or ambiguity must be settled.
- Human-owned design documents are the primary source for stable product
  meaning and accepted workflows.
- New change requests require human-owned requirement documents, which should
  reference the relevant stable design instead of restating it.
- Stable engineering rules belong in engineering documents.
- Exploratory changes start as proposals.
- Expensive or hard-to-reverse decisions are recorded as ADRs.
- Git history must preserve meaningful project stages.
- Legacy code must be archived only after a Git baseline exists.
- AI-maintained project documents must be written in English.

## 3. Documentation Language

AI-maintained documentation files outside `docs/human/` must be written in
English.

This applies to:

- Product documents.
- Engineering documents.
- Proposals.
- ADRs.
- Chronicle entries.
- Changelog entries.
- Release notes.

Human-owned documents under `docs/human/` may use the human owner's chosen
language and must not be edited by the AI.

Chinese may appear in AI-maintained documentation only when it is part of a
literal UI string, user-facing copy being discussed, an external source title,
or a necessary example.

## 4. Documentation System

Project documentation is organized into human-owned authority and
AI-maintained engineering records:

```text
docs/
  human/
    requirements/
    design/
      Design Index.md
      ui/
      data/
      workbench/
      playback/
  engineering/
    records/
  changelog.md
```

### 4.1 Human-Owned Documents

`docs/human/` is the authoritative human-maintained area.

- `docs/human/design/` records stable product meaning, accepted workflows, UI
  design rules, component/layout specifications, and decisions that must remain
  consistent across future changes. `docs/human/design/Design Index.md` is the
  root routing index across the `ui/`, `data/`, `workbench/`, and `playback/`
  domains.
- `docs/human/requirements/` records each new change or implementation request.
  A requirement should cite the relevant design document and describe only the
  requested delta, scope, and acceptance needs when the design already covers
  the stable behavior.
- Design documents should resolve requirements, workflows, and meaningful
  ambiguity. They do not need tutorial-style explanations of commonplace
  implementation practices unless a project-specific constraint, deviation,
  risk, or acceptance condition makes that detail necessary.
- The AI may review human-owned documents but must not modify them.

### 4.2 Engineering Documents

`docs/engineering/` records engineering rules, architecture constraints, development workflow, repository conventions, testing rules, database rules, and release rules.

Recommended structure:

```text
docs/engineering/
  00_project_governance.md
  01_documentation_rules.md
  02_git_workflow.md
  03_repository_structure.md
  04_architecture_rules.md
  05_database_rules.md
  06_testing_rules.md
  07_release_rules.md
  08_end_to_end_testing.md
  records/
```

This document is the top-level governance document. Detailed rules live in the dedicated files listed above.

### 4.3 Changelog

`docs/changelog.md` records milestone-level changes and user-visible project progress.

The changelog does not replace Git commits. Git records concrete file changes. The changelog records meaningful project progress and milestone outcomes.

The changelog must be updated when a completed milestone, user-visible behavior change, accepted architecture or process rule, release milestone, or accumulated group of small commits changes meaningful project status. Routine formatting, wording cleanup, internal refactors without behavior or rule impact, test-only maintenance, and transient work in progress do not require entries.

Detailed changelog update rules are defined in `docs/engineering/01_documentation_rules.md`.

## 5. Documentation Change Process

### 5.1 Small Documentation Changes

Small documentation changes may directly update the relevant stable document when covered by a committed human-owned requirement.

Examples:

- Text refinements.
- Minor UI detail clarification.
- Acceptance criteria clarification.
- Small non-structural corrections.
- Formatting cleanup.

### 5.2 Medium and Large Changes

Medium and large changes require a committed human-owned requirement and alignment with the relevant design document under `docs/human/design/`.

Examples:

- New feature modules.
- Core workflow changes.
- Data model changes.
- Playback strategy changes.
- Indexing strategy changes.
- Security or credential storage changes.

Required flow:

```text
Create and commit the human-owned requirement
Reference or update the relevant human-owned design
Align stable engineering conclusions into engineering docs when required
Implement
Verify
Update the implementation record under docs/engineering/records/
Evaluate changelog trigger and update when required
Commit changes
```

### 5.3 Documentation Review Rule

Documentation that defines process, product scope, data structure, playback behavior, or architecture must be reviewed before implementation depends on it.

Draft documents may guide discussion, but they are not final project rules until accepted.

## 6. Git Workflow

### 6.1 Baseline Initialization

Before restructuring the repository, the current Flutter implementation must be frozen as a baseline.

Recommended commands:

```bash
git init
git add .
git commit -m "Baseline Flutter implementation"
git tag flutter-baseline
git switch -c native-macos-rewrite
```

If Git user identity is not configured locally, configure it before the first commit.

### 6.2 Commit Granularity

Commits should represent understandable project steps, not arbitrary file batches.

Recommended commit boundaries:

- Initialize documentation structure.
- Freeze Flutter baseline.
- Archive Flutter implementation.
- Create native macOS app shell.
- Implement local subtitle indexing.
- Implement SQLite FTS search.
- Implement local video timestamp playback.
- Implement macOS experience polish items.
- Implement Shiori and personal learning flow.

### 6.3 Commit Message Format

Use concise English commit messages:

```text
Area: concise change summary
```

Examples:

```text
Docs: add project governance rules
Archive: move Flutter implementation under archive/flutter
Native: add macOS app shell
Search: implement local subtitle FTS query
Playback: add local video seek prototype
```

### 6.4 Safety Rules

Destructive Git operations must not be run unless explicitly requested.

Do not run by default:

```bash
git reset --hard
git clean -fd
git checkout -- .
```

## 7. Technical Stack Governance

The project technical stack must be documented before active implementation starts.

The technical stack document should live at:

```text
docs/engineering/04_architecture_rules.md
```

The technical stack must define:

- Primary application platform.
- UI framework.
- Application architecture pattern.
- Database engine.
- Search engine.
- Playback engine.
- Package and dependency management.
- Minimum supported macOS version.
- Whether sandboxing is enabled.
- Whether the app is intended for local-only usage or distribution.

The initial native rewrite assumes:

- Platform: macOS.
- Minimum supported macOS version: macOS 13.0 Ventura, provisional.
- UI layer: native macOS development.
- Database: SQLite with FTS5.
- Remote services: out of scope for the early rewrite.

Final choices for playback engine, sandboxing, and distribution strategy require dedicated documentation or ADRs before implementation depends on them.

The minimum supported macOS version may be raised before implementation if a documented architecture decision requires newer system APIs.

## 8. Repository Structure

Target structure after the native rewrite starts:

```text
CueSeeker/
  apps/
    macos-native/
  archive/
    flutter/
  docs/
    human/
      requirements/
      design/
    engineering/
      records/
    changelog.md
  ui/
    prototypes/
    references/
    assets/
  scripts/
```

### 8.1 Active Application Code

`apps/` contains active application implementations.

The native macOS rewrite should live under:

```text
apps/macos-native/
```

### 8.2 Archived Code

`archive/` contains old implementations retained for reference.

The existing Flutter implementation should eventually move to:

```text
archive/flutter/
```

The Flutter implementation must not be moved before a Git baseline commit and `flutter-baseline` tag exist.

The archived Flutter code remains useful as reference for:

- SQLite schema.
- SRT parsing.
- FTS query behavior.
- Existing playback experiments.
- Existing UX decisions.

Archived code is not active implementation code.

### 8.3 Documentation as Source of Truth

Human-owned design documents under `docs/human/design/` are the primary source
for confirmed product meaning and workflows. Engineering documents under
`docs/engineering/` are the source of truth for engineering constraints.

If implementation needs to diverge from documented behavior, update the relevant
document first.

## 9. Database Migration Rules

Database rules must be documented before the native app starts writing persistent user data.

Detailed rules should live at:

```text
docs/engineering/05_database_rules.md
```

Stable data meaning should live primarily at:

```text
docs/human/design/data/Data.md
docs/human/design/data/Cue Parsing.md
```

Database rules must define:

- Database file location.
- Schema versioning mechanism.
- Migration execution order.
- Rollback or backup expectations.
- Compatibility with the archived Flutter database.
- Rules for destructive schema changes.
- Rules for indexes and FTS tables.
- Rules for test fixtures and sample data.

Any schema change requires a current committed human-owned requirement. When
stable data meaning changes, the human owner must update
`docs/human/design/data/Data.md`.

Database changes must include migration notes. Schema changes should not be hidden only inside implementation code.

## 10. Playback Selection Rules

Playback is a high-risk module. Stable product behavior must be covered by the
current requirement and relevant human-owned design under:

```text
docs/human/design/playback/
```

The playback implementation strategy must also be covered by:

```text
docs/engineering/04_architecture_rules.md
```

The native app uses the native-only playback backend (`AVSampleBufferDisplayLayer` + `AVSampleBufferAudioRenderer` + FFmpeg demux/decode + `libass` subtitle rendering).

Playback architecture evaluation must consider:

- Codec compatibility.
- Timestamp seek accuracy.
- Subtitle loading.
- Hardware acceleration.
- Fullscreen behavior.
- Rendering and visual effect constraints.
- Distribution and signing impact.
- Maintenance risk.

M1 only requires local video playback and timestamp seek.

The following are out of scope for M1:

- Remote playback.
- Local HTTP proxy.
- Local cache strategy.
- Advanced subtitle rendering.
- Real-time video image processing.
- Advanced glass or blur effects.

## 11. Credential Storage Rules

Credential and secret handling must be documented before any feature stores credentials.

Detailed rules should live at:

```text
docs/engineering/04_architecture_rules.md
```

or a future dedicated security document if credential handling becomes complex.

Credential rules must define:

- What counts as a credential or secret.
- Where credentials are stored.
- Whether macOS Keychain is required.
- Whether credentials may ever be written to plain text files.
- How credentials are excluded from logs.
- How credential migration is handled.
- How credentials are deleted.

Default rule:

- Do not store passwords, tokens, API keys, or authentication headers in plain text.
- Prefer macOS Keychain for stored credentials.
- Do not write secrets into Git-tracked files.
- Do not print secrets into logs.

## 12. Logging Rules

Logging strategy must be documented before non-trivial implementation starts.

Detailed rules should live at:

```text
docs/engineering/04_architecture_rules.md
```

Logging rules must define:

- Log levels.
- Log destinations.
- Whether logs are persisted.
- Whether logs are user-accessible.
- How long persisted logs are retained.
- How personally sensitive paths or credentials are redacted.
- How playback, indexing, database, and UI errors are categorized.

Default rule:

- Logs may include technical diagnostics.
- Logs must not include credentials.
- Logs should avoid dumping full user file trees unless explicitly needed for debugging.
- User-visible errors should be concise and actionable.

## 13. Testing Strategy

Testing strategy must be documented before implementation is considered complete for any milestone.

Detailed rules should live at:

```text
docs/engineering/06_testing_rules.md
docs/engineering/08_end_to_end_testing.md
```

Testing rules must define:

- Required unit tests.
- Required integration tests.
- Manual acceptance checks.
- Test data location.
- Database migration test expectations.
- Playback verification expectations.
- UI smoke test expectations.
- End-to-end test documentation, log handoff, and acceptance evidence
  expectations for runtime-sensitive changes.

At minimum, the native rewrite should cover:

- SRT parsing.
- Timecode parsing.
- Video/subtitle filename matching.
- SQLite schema creation.
- FTS query behavior.
- Database migrations.
- Local search workflow.
- Local playback timestamp seek smoke test.

Milestones must not be marked complete until their acceptance criteria have been verified.

## 14. Packaging and Release Rules

Packaging and release strategy must be documented before any distributed build is treated as a release.

Detailed rules should live at:

```text
docs/engineering/07_release_rules.md
```

Release rules must define:

- Build configuration.
- App bundle identifier.
- Versioning scheme.
- Signing strategy.
- Notarization strategy.
- Sandbox strategy.
- Required entitlements.
- Database backup expectation before upgrade.
- Release checklist.
- Distribution method.

Early local builds may remain unsigned development builds.

Signed or notarized builds require a release checklist update before release.

## 15. Rewrite Milestones

Milestones are historical planning checkpoints. Current detailed product
behavior is governed primarily by `docs/human/design/`.

### M0: Governance and Baseline

Goal:

- Confirm project governance.
- Confirm documentation structure.
- Initialize Git if needed.
- Freeze the Flutter baseline.
- Archive the Flutter implementation.

Acceptance criteria:

- `flutter-baseline` tag exists.
- Existing Flutter code is preserved.
- `archive/flutter/` exists after archival.
- Documentation directories exist.

### M1: Native macOS Minimal Loop

Goal:

- Create a native macOS project.
- Select a local subtitle directory.
- Scan `.srt` files.
- Parse subtitle entries.
- Write entries to SQLite + FTS5.
- Search subtitle text.
- Click a search result to open a same-directory video at the matching timestamp.

Acceptance criteria:

- The M1 app does not depend on Flutter.
- Local subtitle search works.
- Local video timestamp playback works.
- Remote playback, advanced visual effects, and complex cache logic are out of scope for M1.

### M2: macOS Experience Polish

Goal:

- Native menu bar.
- Keyboard shortcut system.
- Window behavior refinement.
- Sandbox permission strategy.
- Keychain integration if credential storage exists.
- Packaging, signing, and notarization preparation.
- UI/UX refinement for the core local workflow.

### M3: Shiori and Personal Learning Flow

Goal:

- Save the current subtitle as Shiori.
- List Shiori records.
- Toggle Shiori with keyboard interaction.
- Persist Shiori identity reliably.

## 16. Data Model Rules

Data structure is high-stability project material.

The following changes must be covered by a committed human-owned requirement.
When stable data meaning changes, the human owner must update
`docs/human/design/data/Data.md` before implementation depends on it:

- Table structure changes.
- Field meaning changes.
- Primary key or unique index changes.
- Shiori identity rule changes.
- Search path storage changes.
- Flutter data compatibility changes.

This section exists as a governance reminder. Detailed database migration rules are defined in Section 9 and `docs/engineering/05_database_rules.md`.

## 17. Playback Rules

This section exists as a governance reminder. Detailed playback selection rules are defined in Section 10.

## 18. Change Records

Project change records have three layers:

1. Git commits record concrete file changes.
2. `docs/changelog.md` records milestone progress.
3. `docs/engineering/records/` records AI implementation steps and verification.

These layers do not replace each other.

Each completed milestone must update:

```text
docs/changelog.md
```

Other changelog triggers are defined in `docs/engineering/01_documentation_rules.md`.

## 19. Current Priority

Current priority:

1. Maintain stable product meaning and accepted workflows primarily in
   `docs/human/design/`, with each new requirement citing the relevant design.
2. Refine incomplete product details through small implementation and
   verification loops, updating human-owned decisions before behavior diverges.
3. Correct architecture boundaries and development bottlenecks that materially
   reduce iteration speed, while preserving accepted product behavior.
4. Keep Rust shared-core implementation paused. Continue native macOS
   refinement along the future shared-core boundary without adding Rust
   scaffold, FFI, fixtures, shadow-mode code, or production replacement.
