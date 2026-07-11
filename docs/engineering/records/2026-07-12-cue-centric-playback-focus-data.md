# Cue-Centric Playback Subtitle Focus Data And Actions

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Change Playback Subtitle Focus loading, selection, navigation identity, and
keyboard actions from Cue Group units to individual Cue units. Preserve the
existing overlay and reel presentation in this phase so content-driven Focus UI
geometry can be implemented independently.

## Classification

- Product semantics: every Focus item, ordinal, default selection, and action
  target represents exactly one `subtitle_cue_lines` Cue.
- Stable identity: Cue line ID identifies a loaded item; subtitle path, event
  index, and exact Cue timing form the durable identity used by Shiori.
- Stable ordering: Cue ordinals use Cue Group start, Cue Group end, Cue Group
  ID, Cue display order, Cue event index, and Cue line ID, in that order.

## Implementation

- Replaced the group-shaped Focus item with an individual-Cue payload carrying
  Cue line ID, owning Cue Group ID, stable ordinal, event index, display order,
  exact Cue start/end time, and exact complete content. `text` remains an exact
  projection of the single Cue content for the existing Focus renderer.
- Changed initial-window and complete-collection reads to query Cue lines
  directly in one shared stable order. Total count, ordinals, pagination, and
  the standard 6-before / selected / 3-after window now all use Cue units.
- Implemented the documented default selection branches: choose the physically
  bottommost Cue in the active Cue Group; otherwise choose the last Cue in
  stable order whose group starts before the captured timestamp; when no Cue
  precedes the timestamp, choose the first Cue.
- Carried exact Cue identity through the immutable keyboard-action context.
  Copy uses the exact complete Cue content, Play uses the exact Cue start time,
  and Shiori selection includes Cue line ID, Cue Group ID, event index, display
  order, timing, and content.
- Changed Focus Shiori duplicate detection from timestamp-only lookup to durable
  Cue identity lookup. Same-time sibling Cues can therefore be saved
  independently, while repeating S on the same Cue remains idempotent.
- Updated Core, session, action, and overlay-layout fixtures to construct
  explicit individual-Cue identities without changing Reel or theme behavior.

## Verification

- `swift test --filter SubtitleFocusTests` passed 7 Core Focus tests.
- `swift test --filter PlaybackSubtitleFocusKeyboardActionTests` passed 9
  keyboard-action tests.
- `swift test --filter PlaybackSubtitleFocusSessionStoreTests` passed 21
  session lifecycle, navigation, loading, and deferred-action tests.
- `swift test` passed the complete package suite: 525 Swift Testing tests and
  7 XCTest tests, with 0 failures.
- `swift build` and `git diff --check` passed.
- Focused coverage verifies 10-Cue window distribution, boundary filling,
  first-Cue fallback, preceding-Cue selection, bottommost active-group
  selection, one-Cue-per-item ordering, complete 2,500-Cue reads, exact
  multi-line copy content, exact Cue action metadata, settled-Cue action
  targeting, same-time sibling Shiori identity, and repeated-save idempotence.

## Outcome

Playback Subtitle Focus now loads and acts on one stable Cue at a time. Cue
Group identity is retained only as ownership metadata needed by downstream
Context and Shiori operations; it no longer defines Focus list items, ordinals,
copy payloads, playback targets, or save identity.
