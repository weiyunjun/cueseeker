# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Keycap、Keycap Group、Playback Overlay Layout、Command Panel Root Layout、Command Panel Secondary Layout、Command Panel Search Results Layout）
- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽、菜单模态、Hover 与选中、按下、指针）

# 需求描述

## 1. 底部区域合并为一个组件

Playback Overlay 与 Command Panel 现在各有一套底部区域实现，键帽的尺寸、字重与底色各写各的，已经开始漂移。本次合并为同一个组件，两个界面共用结构与尺寸，只有配色按所在界面区分。

## 2. 底部区域的内容与顺序

左侧计数文字的内容与位置不变。右侧改为一组动作按钮，从左到右依次为：

1. Save to Shiori，键位 `S`
2. Copy Cue Text，键位 `C`
3. Copy Deep Link，键位 `X`
4. Play，键位回车

各界面按自身实际可用的动作显示，不显示不可用的动作：

| 位置 | 右侧显示 | 左侧计数 |
| --- | --- | --- |
| Playback Overlay / Current | 四个按钮 | 字幕条数 |
| Playback Overlay / Current（拼贴选择态） | 仅 Select 回车 | 字幕条数 |
| Playback Overlay / Playlist（字幕） | 四个按钮 | 字幕条数 |
| Playback Overlay / Playlist（剧集网格） | 仅 Play 回车 | 视频数 |
| Command Panel / 搜索结果 | 四个按钮 | 结果数 |
| Command Panel / 根页 | 仅 Open 回车 | 无 |
| Command Panel / Recent Videos | 仅 Open 回车 | 视频数 |
| Command Panel / Recent Shioris | 仅 Open 回车 | 栞数 |

不再显示 Navigate 说明，方向键键帽（含 Recent Videos 的左右方向键）一并不再显示。**键盘导航功能全部保留，只是不再在底部写出来。**

Playback Overlay 的剧集网格现在没有底部区域，本次新增，与 Command Panel 的 Recent Videos 一致地显示视频数。

## 3. 动作说明改为可点击按钮

「文字 + 键位」合为一个按钮，鼠标左键点击后执行的动作与按对应快捷键完全一致。

- 按钮只有 Default 与 Hover 两态，不做按下态，符合《UI Application Rules》「按下」一节。
- 键位继续用现有的方块键帽样式，字母键显示字母，回车显示回车符号。键帽图形本身后续单独调整，本次不动。
- 按钮在所在界面被更高层覆盖、或该界面的菜单打开期间不响应 Hover 与点击；播放页指针隐藏期间不出现 Hover。
- 点击按钮不改变当前焦点，Command Panel 的搜索框在点击后仍可继续输入。
- 当前没有可操作的目标时（例如搜索结果为空），按钮照常可点击，点击后不发生任何事，不做禁用态。
- 指针在按钮上为箭头，不使用手型。

## 4. 键帽与按钮的配色

键帽底色与所在界面的底色过于接近，Playback Overlay 上几乎看不出键帽边界。本次按界面各配一套固定色，使「界面底色 → 按钮 Hover 底色 → 键帽默认底色 → 键帽 Hover 底色」四级逐级加深。按钮 Hover 时，其内部键帽同时切换到键帽 Hover 底色。

Playback Overlay：

- 按钮 Hover 底色：Light `#EDEEF2`；Dark `#2C2C30`
- 键帽默认底色：Light `#E1E4E9`；Dark `#35353A`
- 键帽 Hover 底色：Light `#D2D6DE`；Dark `#414147`

Command Panel：

- 按钮 Hover 底色：Light `#F7F8FA`；Dark `#252529`
- 键帽默认底色：Light `#EDEFF2`；Dark `#2E2E33`
- 键帽 Hover 底色：Light `#E0E3E8`；Dark `#3A3A40`

原 `--color-keycap-bg` 取值与 `--color-bg-hover` 相同的做法退役。文字颜色与字重不变。

## 5. 完整显示与自适应高度

底部内容必须完整显示，不省略、不截断。窗口变窄导致一行放不下时，动作按钮换行，底部区域随之增高，最小高度维持现有值。

Playback Overlay / Current 的字幕滚动区高度现在按底部区域的固定高度扣减，改为按实测高度扣减。

## 6. 文案

- Copy Cue Text 与 Copy Deep Link 复用行右键菜单已有文案。
- Save to Shiori 新增文案，简体、繁体、英文三套。
- Play、Open、Select 沿用现有文案。

## 7. 不变项

1. 左下角计数文字的内容、字号与颜色不变。
2. 四个动作的功能行为不变，本次只新增点击入口。
3. 键盘导航与快捷键的按键映射不变。
4. Playback Overlay 与 Command Panel 的界面底色、层级与输入归属不变。
5. 键帽的尺寸、圆角、字号与文字颜色不变。
6. 键帽图形样式本身不变，后续单独调整。

## 8. 文档

本次改动稳定并验收后，更新 `docs/human/design/UI Design System.md`：新增底部动作按钮组件、为 Keycap 补充 Hover 态与两套界面配色、为 Playback Overlay Layout 补上现在缺失的 Footer 结构、更新 Command Panel 三个 Layout 的 Footer 说明。

# 验收

1. Playback Overlay 的 Current 与 Playlist（字幕）底部从左到右显示 Save to Shiori S、Copy Cue Text C、Copy Deep Link X、Play 回车，左下角计数不变。
2. 逐个点击这四个按钮，效果与按 S、C、X、回车完全一致。
3. Playback Overlay 的剧集网格底部出现区域，左侧显示视频数，右侧只有 Play 回车，点击可播放当前选中剧集。
4. 拼贴选择态底部只显示 Select 回车。
5. Command Panel 根页、Recent Videos、Recent Shioris 底部只显示 Open 回车；Recent Videos 的左右方向键仍然可用。
6. Command Panel 搜索结果底部显示四个按钮，点击效果与快捷键一致。
7. 所有界面均不再出现 Navigate 说明与方向键键帽。
8. Playback Overlay 与 Command Panel 上，键帽在 Light 与 Dark 下都能看清边界；Hover 按钮时按钮底色出现，且键帽底色进一步加深。
9. 指针停在按钮上时为箭头，不是手型。
10. Command Panel 里点击底部按钮后，搜索框仍可继续输入。
11. 打开更高层界面或该界面的菜单后，底部按钮不再响应 Hover 与点击。
12. 把窗口拖到很窄，底部内容换行完整显示，不出现省略号或截断；Current 的字幕滚动区不被底部区域遮挡。
13. 现有自动化端到端与单元用例全部通过。
