# 版本
main

# 需求描述
Playback Overlay Current，Playback Overlay Cue Playlist，Command Panel Search界面，字幕的字体太大了。需要调整：字体大小，包括字幕的字体和Cue Group字体。另外也要注意行距的问题。

# UI文档改动

- 更新 `--font-size-subtitle-focus-cue`：`40px` → `24px`
- 更新 `--line-height-subtitle-focus-cue`：`52px` → `32px`
- 更新 `--font-size-subtitle-focus-cue-group`：`28px` → `20px`
- 更新 `--line-height-subtitle-focus-cue-group`：`38px` → `28px`
- 更新 `--gap-subtitle-focus-internal-line`：`5px` → `3px`
- 更新 `--padding-subtitle-focus-cue-y`：`12px` → `8px`
- Current 的 Nominal Content Height 改为引用 `--line-height-subtitle-focus-cue`。
- Current 的 Base Natural Height 改为引用 `--padding-subtitle-focus-cue-y`。
- Current 一行、两行、三行 Cue Base Natural Height 分别更新为 `48px`、`80px`、`112px`。
- 上述 Token 同时适用于 Playback Overlay Current、字幕型 Playlist 和 Command Panel Search Result。