# 说明
1. 本文档由人类维护，定义播放相关界面布局（`L-07` ~ `L-09`）：Player、Playback Overlay、Command Panel。
2. 播放页顶底栏显隐、浮层层级屏蔽与全屏规则详见 `/docs/human/design/ui/UI Interaction Rules.md`。

# 3. Layouts（Part 2：Player, Overlay & Command Panel `L-07` ~ `L-09`）

## 3.7 Player

### L-07.1 Player Topbar Layout

#### Structure

1. Window Controls
2. Return Action
3. Flexible Spacer
4. Player Title
5. Flexible Spacer
6. Trailing Function Region
   1. Task Entry
   2. Settings Entry

#### Components

- Window Controls：系统原生红绿灯
- Icon Button / Default：返回 Workbench
- Player Title
- Icon Button / Default
- Information Badge / Task Count Badge

#### Sizes

- Height：`--height-app-topbar`
- Task to Settings Gap：`--spacing-1`
- Padding Inline：Leading `--padding-player-topbar-x`，Trailing `--padding-app-topbar-trailing`
- Window Controls：与 App Topbar Layout 同一位置，起点 `--spacing-6`，在 45px 控制带内垂直居中
- Return Action：与 Window Controls 同一水平中线
- Return Action Gap：`--gap-player-window-controls-return`
- Fullscreen：Window Controls 由系统标题栏显示，Return Action 起点改为 `--padding-player-topbar-x`
- 居中元素可用宽度：顶栏宽度减去左右占用较大一侧的两倍，居中元素始终在顶栏中线上

#### Surface

- Gradient Start：`--color-player-topbar-gradient-start`
- Gradient End：`--color-player-topbar-gradient-end`

#### States

- Visible
- Interaction Suppressed
- Hidden

### L-07.2 Player Bottom Control Bar Layout

#### Structure

1. Progress Region
2. Controls Row
   1. Left Control Group
   2. Flexible Spacer
   3. Right Control Group

#### Components

- Player Progress Scrubber Layout
- Icon Button / Default
- Player Volume Control
- Player Speed Button

#### Sizes

- Height：`--height-player-bottom-control-bar`
- Controls Row Height：`--height-player-bottom-controls-row`
- Padding Inline：`--padding-player-chrome-x`
- Padding Bottom：`--padding-player-chrome-bottom`
- Progress Top Padding：`--padding-player-progress-top`
- Left Control Gap：`--spacing-1`
- Right Control Gap：`--spacing-1`

#### Surface

- Gradient Start（Bottom）：`--color-player-topbar-gradient-start`
- Gradient End（Top）：`--color-player-topbar-gradient-end`

#### States

- Visible
- Interaction Suppressed
- Hidden

### L-07.3 Player Progress Scrubber Layout

#### Structure

1. Current Time
2. Player Progress Scrubber
3. Remaining Time
4. Player Progress Time Capsule
   - Presence：Hover or Dragging

#### Components

- Player Time Display
- Player Progress Scrubber
- Player Progress Time Capsule

#### Sizes

- Padding Inline：`--padding-player-chrome-x` + `--spacing-2`
- Time to Scrubber Gap：`--spacing-3`
- Hit Area Height：`--height-player-progress-hit-area`
- Track Height：`--height-player-progress-track`
- Hover Track Height：`--height-player-progress-track-hover`

#### States

- Default
- Hover
- Dragging
- No Duration

### L-07.4 Playback Feedback Overlay Layout

#### Position

- Anchor：Player Stage Center
- 水平与垂直双向居中，内容变长时以中心为基准向两侧延伸，达到最大宽度后换行并向上下延伸
- Layer：Above Video, Playback Overlay and Command Panel

#### Timing

- Duration：Playback Feedback / Duration
- 列表中没有有效项时导航（上一个、下一个、Auto Switch、视频播完自动播放下一个）：由 Playback Feedback 呈现（持续 1 秒），文案按来源为 `No Available Results`、`No Available Excerpts`、`No Available Videos`

#### Components

- Playback Feedback

#### States

- Hidden
- Entering
- Visible
- Exiting

### L-07.5 Player Error Banner Layout

#### Position

- Anchor：App 窗口左上角，不锚定视频画面
- Padding Top：`--height-app-topbar` 与 `--spacing-3` 之和
- Padding Leading：`--spacing-6`
- 窗口变窄使视频出现黑边时仍在顶栏之下，可落在黑边上；全屏同此规则
- Layer：Above Video, Playback Overlay and Command Panel
- 不随 Player UI 隐藏

#### Lines

| 行 | 出现条件 | 文案 |
| --- | --- | --- |
| 视频 | 视频文件无法加载 | `Couldn’t load the video file: <绝对路径>` |
| 视频 | 播放器的其它错误 | `Playback error: <播放器给出的原因>` |
| 字幕 | 字幕文件无法读取 | `Couldn’t load the subtitle file: <绝对路径>` |
| 无效项 | 播放或打开不在数据库中的项 | `This item is no longer in the library` |

- 文案不区分 ASS 与 SRT，也不出现渲染器等内部名称

#### Timing

- Duration：Player Error Banner / Duration，自出现起计时；对应的视频或字幕被替换时提前消失，两者以先到者为准。视频那一行的来源是当前视频，字幕那一行的来源是当前字幕，切换视频同样视为替换
- 同一行出现新的报错时替换旧的并重新计时
- 焦点、指针与窗口是否可见都不影响计时；暂停、播放、拖动进度、开关 Playback Overlay 同样不影响
- 各行均消失时框消失

#### Components

- Player Error Banner

#### States

- Hidden
- Entering
- Visible
- Exiting

## 3.8 Playback Overlay

### L-08.1 Playback Overlay Layout

#### Structure

1. Overlay Surface
2. Playback Topbar
3. View Content Region
4. Playback Footer

#### Components

- Playback Topbar Layout
- Playback Current Layout
- Playback Playlist Layout
- Playback Collage Editor Layout
- Playback Footer Layout

#### Surface

- Background：`--color-subtitle-focus-overlay-bg`
- Shadow：`--shadow-player-overlay`

#### Sizes

- Content Padding：`--spacing-8`

#### States

- Closed
- Opening
- Current
- Playlist
- Editing Collage
- Covered
  - 触发：Command Panel 打开
  - 内容照常显示，不接受指针、滚轮与键盘
  - 已展开的菜单保持展开
- Closing

### L-08.2 Playback Topbar Layout

#### Structure / Normal

1. Window Controls
2. Return Action
3. Tabs
4. Trailing Function Region
   1. Collage Action：仅 Current
   2. Task Entry
   3. Settings Entry

#### Structure / Editing Collage

1. Window Controls
2. Return Action
3. Editing Title
4. Trailing Function Region
   1. Collage Action：Open
   2. Task Entry
   3. Settings Entry

#### Components

- Window Controls：系统原生红绿灯
- Icon Button / Default：返回 Workbench
- Icon Button / Default
- Information Badge / Task Count Badge
- Segmented Control
- Editing Title：与 Tab / Selected 的 Label 相同，无 Selection Indicator

#### Sizes

- Height：`--height-app-topbar`
- Segmented Control：默认在顶栏水平居中；空间不足时保持与左、右按钮区至少 `--spacing-3` 间距并向空余一侧偏移
- Editing Title 最大宽度：顶栏的居中元素可用宽度

#### Spacing

- Trailing Margin：`--padding-app-topbar-trailing`
- Trailing Gap：`--spacing-1`
- Window Controls 与 Return Action：与 Player Topbar Layout 同一位置

#### Keyboard

- Focused Tab：None
- `Tab`：Switch Current / Playlist

#### States

- Current
- Playlist
- Editing Collage

### L-08.3 Playback Footer Layout

#### Structure

1. Status
2. Action Region

#### Components

- Shortcut Action Button
- Keycap

#### Sizes

- Minimum Height：`--min-height-playback-footer`
- Action Gap：`--spacing-1`

#### Layout

- Status 靠左，动作按钮靠右
- 一行放不下时动作按钮换行并右对齐，区域随之增高，内容不省略

#### Actions

| 所在界面 | Status | 动作 |
| --- | --- | --- |
| Playback Current | 字幕条数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |
| Playback Current / Editing Collage | 已选字幕条数 / 字幕条数 | Copy Collage `C`、Export Collage `E`、Select `Return` |
| Playback Playlist / Subtitle Playlist | 字幕条数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |
| Playback Playlist / Video Playlist | 视频数 | Play `Return` |
| Command Panel Root | None | Open `Return` |
| Command Panel / Recent Videos | 视频数 | Open `Return` |
| Command Panel / Recent Excerpt Lists | 摘录集数 | Open `Return` |
| Command Panel / Search Results | 结果数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |

- Save to Excerpt List 打开 Excerpt Destination Submenu 选择目标列表，不直接保存；结果由 Playback Feedback 呈现，Icon 为实心书签
- 对不在数据库中的项执行 Save to Excerpt List 或 Copy Deep Link 时拦截，由 Playback Feedback 呈现（持续 1 秒），Icon 为 warning，文案 `Not in Library`，面板保持打开；执行 Play 时关闭 Playback Overlay，进入黑屏播放界面并由 Player Error Banner 报错
- 在 Command Panel 的 Recent Excerpt Lists 中打开没有有效项的列表时拦截，由 Playback Feedback 呈现（持续 1 秒），文案 `No Available Excerpts`，面板保持打开
- `S`、`C`、`X`、`E` 为默认键位，Keycap 显示 Settings / Shortcuts 中的当前键位，修饰键（⌃、⌥、⇧、⌘）与主键各占一个 Keycap；快捷键已清空或冲突时不显示 Keycap

#### States

- Default

### L-08.4 Playback Current Layout

#### Structure

1. Subtitle Region
   1. Playback Cue Reel / Focus Cue Reel
   2. Vertical Scrollbar

#### Components

- Playback Cue Reel / Focus Cue Reel
- Subtitle Focus Cue
- Playback Cue Metadata
- Scrollbar / Vertical

#### Sizes

- Maximum Content Width：`--width-subtitle-focus-content-max`
- Cue Gap：`--gap-subtitle-focus-cue`

#### Cue Timeline

- Marker：None
- Metadata Ordinal：None

#### States

- Loading
- Ready
- Empty：当前字幕不在数据库中时，显示 Empty State / Empty Hint，文案 `This subtitle is no longer in the library.`
- Scrolling
- Settling

### L-08.5 Playback Playlist Layout

#### Structure / Subtitle Playlist

1. Subtitle Region
   1. Playback Cue Reel / Cue Result Reel
   2. Vertical Scrollbar

#### Structure / Video Playlist

1. Library Episode Grid

#### Components

- Playback Cue Reel / Cue Result Reel
- Playback Cue Result
- Playback Cue Metadata
- Scrollbar / Vertical
- Library Episode Grid Layout
- Recent Watching Card Layout

#### Cue Timeline / Subtitle Playlist

- Marker：None
- Metadata Ordinal：Cue Playlist 1-based Position，形如 `#238`

#### States

- Subtitle Playlist
- Video Playlist
- Loading
- Ready
- Empty：播放列表中没有仍在数据库中的项时，显示 Empty State / Empty Hint，文案 `No items in this playlist are in the library.`

### L-08.6 Playback Collage Editor Layout

#### Structure

1. Collage Preview Region
2. Subtitle Selection Region

#### Collage Preview Region

1. Section Title
2. Collage Image Viewport

#### Subtitle Selection Region

1. Playback Cue Reel / Focus Cue Reel
2. Vertical Scrollbar

#### Components

- Section Title
- Playback Cue Reel / Focus Cue Reel
- Subtitle Focus Cue
- Checkbox / Playback Selection Checkbox
- Playback Cue Metadata
- Scrollbar / Vertical

#### Sizes

- Region Width：1fr / 1fr
- Region Padding：`--spacing-8`
- Section Gap：`--spacing-4`

#### Cue Timeline

- Marker：Checkbox / Playback Selection Checkbox
- Metadata Ordinal：None

#### States

- Loading Preview
- Ready
- Rendering
- Selection Limit Reached
- Exporting
- Group Hovered
  - 指针所在的截图组整体放大：Scale `--scale-collage-group-hover`，Duration `--duration-collage-group-hover`，easeOut
  - 放大部分越过图片边缘与相邻组，不被裁切；其余画面不变

## 3.9 Command Panel

### L-09.1 Command Panel Root Layout

#### Structure / Empty Query

1. Search Field
2. Option List
   1. Recent Videos
   2. Recent Excerpt Lists
3. Footer

#### Structure / Filled Query

1. Search Field
2. Option List
   1. Search Action
   2. Recent Videos
   3. Recent Excerpt Lists
3. Footer

#### Components

- Search Field
- Menu Item / Action Menu Item
- Playback Footer Layout
- Scrollbar / Vertical

#### Surface

- Background：`--color-bg-dialog`
- Scrim：`--color-command-panel-scrim`

#### Layer

- 位于 Playback Overlay 之上
- 打开期间独占指针、滚轮与键盘
- 不关闭下层已展开的菜单

#### States

- Empty Query
- Filled Query
- Navigating
- Opening Secondary

### L-09.2 Command Panel Secondary Layout

#### Structure

1. Header
   1. Back Action
   2. Title
2. Content Region
3. Footer

#### Components

- Icon Button
- Section Title
- Playback Footer Layout
- Scrollbar / Vertical

#### Variants

- Recent Videos
  - Content：Recent Watching Card Grid（按 Recent Layout 时间分组展示）
- Recent Excerpt Lists
  - Content：Excerpt List Card Grid（按 Recent Layout 时间分组展示）
- Search Results
  - Content：Command Panel Search Results Layout

### L-09.3 Command Panel Search Results Layout

#### Structure

1. Playback Cue Reel / Cue Result Reel
2. Vertical Scrollbar

#### Components

- Playback Cue Reel / Cue Result Reel
- Playback Cue Result
- Playback Cue Metadata
- Scrollbar / Vertical

#### Cue Timeline

- Marker：None
- Metadata Ordinal：Search Result 1-based Position，形如 `#238`

#### States

- Loading
- Results
- Empty
- Scrolling
- Settling
