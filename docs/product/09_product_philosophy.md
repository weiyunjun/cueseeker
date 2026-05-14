# Product Philosophy

Status: Draft

## 1. Purpose

This document records the product philosophy behind CueSeeker.

It does not replace the functional requirements, UI rules, playback
requirements, or data model documents. It explains why those documents should
keep the product narrow, local-first, and grounded in user-owned subtitle and
video material.

## 2. Core Belief

CueSeeker starts from affection for source material.

The product assumes that people learn most willingly from material they already
care about: favorite anime, films, dramas, music-related scenes, YouTube videos,
characters, voice performances, recurring phrases, and community memory.

The app should help users turn that affection into searchable, reviewable, and
exportable raw learning material.

The product should not make users learn from generic course material before
they are emotionally invested. It should help them learn from the works they
already want to revisit.

## 3. Product Identity

CueSeeker is a local subtitle corpus workbench for language learning and media
memory.

The core identity is:

```text
Import local subtitle and video material
Search a word or phrase
Compare the real contexts where it appears
Open the matching video moments
Collect or export the raw material for further study
```

The product is not primarily:

- A general-purpose media player.
- A media library manager.
- A subtitle editor.
- A streaming-service learning extension.
- An AI explanation or translation tool.
- A crawler for online video platforms.
- A full spaced-repetition system.

CueSeeker can integrate with later learning workflows, but its first value is
to make the user's own material searchable, comparable, and playable.

## 4. Target Audience

The product remains rooted in the project owner's personal learning workflow,
but the intended distributable audience is a small group of heavy users who
share similar habits.

These users may include:

- Japanese and English learners who prefer real media context over course
  examples.
- Chinese-speaking users with local anime, film, drama, or YouTube subtitle
  collections.
- Fansub-aware users who value subtitle timing, bilingual subtitles, ASS
  styling, and source context.
- Fan creators, clip makers, and community members who revisit lines, scenes,
  memes, character speech habits, and emotional anchors.
- Users who want to collect raw subtitle, screenshot, audio, or video material
  and then study it in tools such as Anki, Markdown notes, or their own
  workflows.

CueSeeker should be usable by broader subtitle and media users, but it should
not dilute its design around generic mass-market onboarding.

## 5. Community Respect

CueSeeker is a passion project and a tribute to fansub and fan-creation
communities.

This does not only mean that the app is free or open source. It means the
product should respect the work and habits of these communities:

- Respect user-owned local material.
- Respect source subtitle files as meaningful work, not disposable text.
- Respect fansub timing, translation choices, bilingual layout, and ASS
  presentation where practical.
- Respect community memory around iconic lines, songs, character phrases, and
  scenes.
- Respect fan creators who need to locate, verify, and revisit source moments.
- Avoid replacing user understanding with automatic explanation.

CueSeeker should help users return to the original scene. It should not pull
attention away from the source material unless the user explicitly exports or
hands that material to another learning workflow.

## 6. Learning Philosophy

CueSeeker is a learning product, but it is not a complete learning system.

It is one bridge in a larger workflow:

```text
Loved source material
Raw subtitle and video data
CueSeeker search, comparison, playback, and collection
User-verified study methods such as Anki, notes, or review sessions
```

CueSeeker should not decide the meaning of a word for the user. It should show
the real contexts in which the word or phrase appears, especially when those
contexts come from familiar material.

For example, searching a character-specific phrase such as `desuwa` can turn a
single language pattern into a set of observable character moments. Searching an
emotionally loaded phrase such as `春日影` can recover community memory across
episodes and related works. The product value comes from seeing the pattern
inside real scenes, not from receiving a generic definition.

## 7. Raw Data Principle

CueSeeker should produce and organize high-quality raw material.

Raw material may include:

- Subtitle text.
- Matched source video timestamps.
- Nearby subtitle context.
- Screenshots.
- Audio clips.
- Short video clips.
- Source metadata such as work title, episode, subtitle path, video path,
  timestamp, language tags when known, and user tags when added.

Export workflows may later send this material to Anki, Markdown notes, URL
Scheme targets, or other user-controlled systems.

The export model should be metadata-friendly and template-friendly, but it does
not need to become the only learning workflow. Users should remain free to
interpret, translate, annotate, and process their own data elsewhere.

## 8. Search Philosophy

Search should enable comparison.

The most important moment is not merely finding one result. It is searching a
word or phrase and seeing many familiar contexts at once, then moving quickly
through the matching video moments.

The first distributable success criterion is:

```text
Import a local library
Search a word
See many results
Click one result
Keep switching through the matching moments smoothly
```

This is the minimum experience that can make the product feel distinct.

Search suggestions, when implemented, may prioritize nearby or recent subtitle
content because CueSeeker is built around the user's current corpus, not a
global dictionary.

Advanced linguistic features such as Japanese morphological analysis, kanji and
kana equivalence, romanization recall, semantic expansion, or automatic
explanation should not be assumed. They require separate design because they can
add complexity, false matches, and product drift.

## 9. AI Boundary

CueSeeker should not include AI-powered explanation, translation, transcription,
semantic search, or cloud processing as core product behavior.

Users may prepare their own subtitles using any external method, including AI
tools, before importing them. CueSeeker's responsibility is to index and present
the resulting local subtitle and video material faithfully.

This boundary keeps the product:

- Local-first.
- Predictable.
- Respectful of user-owned data.
- Focused on source material rather than generated interpretation.

## 10. Content Boundary

CueSeeker should operate on material the user has already prepared or can access
through supported local-first protocols.

The app should not crawl online video platforms or act as a downloader. YouTube
support, if added, should be based on local video and subtitle files, local CC
exports, or explicitly supported protocol-backed material. WebDAV support may
extend storage access later, but it should not change the product identity from
user-controlled material to platform crawling.

The app should include appropriate boundary language where export features
could be used with copyrighted material. CueSeeker should support private study,
verification, and fan creation workflows without encouraging unauthorized
redistribution of source clips.

## 11. Product Temperament

CueSeeker should feel quiet, native, personal, and source-respecting.

It should avoid becoming:

- A generic tool drawer.
- A course platform.
- A social platform.
- A media center.
- A video scraping tool.
- A one-click AI tutor.

The product should stay close to its founding loop:

```text
Search loved material
Compare real contexts
Return to the scene
Collect useful raw data
Study through the user's chosen method
```

When future features are evaluated, they should be accepted only if they
strengthen this loop.
