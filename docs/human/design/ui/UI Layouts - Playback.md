# 说明
1. 本文档由人类维护，定义播放相关界面布局（`L-07` ~ `L-09`）：Player、Playback Overlay、Command Panel。
2. 播放页顶底栏显隐、浮层层级屏蔽与全屏规则详见 `/docs/human/design/ui/UI Interaction Rules.md`；字幕流与浮层文本选择规则详见 `/docs/human/design/ui/UI Text Selection Rules.md`。

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
   1. Command Panel Entry
   2. Task Entry
   3. Settings Entry

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
- Window Controls：与 App Topbar Layout 同一位置，起点 `--spacing-6`，在 `--height-window-controls-band` 控制带内垂直居中
- Return Action：与 Window Controls 同一水平中线
- Return Action Gap：`--gap-player-window-controls-return`
- Fullscreen：Window Controls 由系统标题栏显示，Return Action 起点改为 `--padding-player-topbar-x`
- 居中元素可用宽度：顶栏宽度减去左右占用较大一侧（含 `--spacing-3` 间距）的两倍，居中元素始终在顶栏中线上

#### Surface

- Gradient Start：`--color-player-topbar-gradient-start`
- Gradient End：`--color-player-topbar-gradient-end`

#### States

- Visible
- Hidden

### L-07.2 Player Bottom Control Bar Layout

#### Structure

1. Player Cue Queue Control Bar
   - Presence：仅台词队列播放（Search / Excerpt 来源）显示；视频列表播放（Library / Recent 来源）隐藏
2. Progress Region
3. Controls Row
   1. Left Control Group
   2. Flexible Spacer
   3. Right Control Group

#### Components

- Player Cue Queue Control Bar
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
- Cue Queue Control Bar Leading：`--padding-player-chrome-x`（与左侧播放按钮左缘对齐）
- Cue Queue Control Bar Bottom to Progress Hit Area Gap：`--spacing-1`（位于 `Player Progress Time Capsule` 层级之下）

#### Surface

- Gradient Start（Bottom）：`--color-player-topbar-gradient-start`
- Gradient End（Top）：`--color-player-topbar-gradient-end`

#### States

- Visible
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

- Anchor：App 窗口左上角，不锚定视频画面
- Padding Top：`--height-app-topbar` 与 `--spacing-3` 之和；当 `Player Error Banner` 同时可见时，排列在 `Player Error Banner` 下方 `--spacing-3` 处
- Padding Leading：`--spacing-6`
- Layer：Above Video（仅在播放器画面展示；当 `Playback Overlay` 或 `Command Panel` 打开时隐藏）
- 不随 Player UI 隐藏

#### Timing

- Duration：Playback Feedback / Duration
- 列表中没有有效项时在播放器画面导航（上一个、下一个、Auto Switch、视频播完自动播放下一个）：由 Playback Feedback 呈现（持续 1 秒），文案按来源为 `No Available Results`、`No Available Excerpts`、`No Available Videos`
- 加载状态（Spinner + `Loading` 文案）：常规操作 HUD 优先级高于加载状态；无操作 HUD 时等待画面超过 `--delay-playback-loading-feedback` 仍未就绪则显示加载状态，有操作 HUD 时待操作 HUD 结束后再按 `--delay-playback-loading-feedback` 计时，超时仍未就绪才显示加载状态；画面就绪或加载失败时立即消失

#### Components

- Playback Feedback

#### States

- Hidden
- Visible

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
- Collage
- Covered
  - 触发：Command Panel 打开
  - 内容照常显示，不接受指针、滚轮与键盘
  - 已展开的菜单保持展开
- Closing

### L-08.2 Playback Topbar Layout

#### Structure

1. Window Controls
2. Return Action
3. Tabs
4. Trailing Function Region
   1. Command Panel Entry
   2. Task Entry
   3. Settings Entry

#### Components

- Window Controls：系统原生红绿灯
- Icon Button / Default：返回 Playback
- Icon Button / Default
- Information Badge / Task Count Badge
- Tabs
- Tab

#### Sizes

- Height：`--height-app-topbar`
- Tabs：默认在顶栏水平居中；空间不足时保持与左、右按钮区至少 `--spacing-3` 间距并向空余一侧偏移

#### Spacing

- Trailing Margin：`--padding-app-topbar-trailing`
- Trailing Gap：`--spacing-1`
- Window Controls 与 Return Action：与 Player Topbar Layout 同一位置

#### Keyboard

- `Tab` / `Shift + Tab`：按无障碍顺序遍历组件（详见 [`UI Accessibility Rules.md`](UI%20Accessibility%20Rules.md)）

#### States

- Current
- Playlist
- Collage

### L-08.3 Playback Footer Layout

#### Structure

1. Status
2. Action Region

#### Components

- Shortcut Action Button
- Keycap

#### Sizes

- Minimum Height：`--min-height-playback-footer`
- Action Gap：`--spacing-2`

#### Layout

- Status 靠左，动作按钮靠右
- 一行放不下时动作按钮换行并右对齐，区域随之增高，内容不省略

#### Actions

| 所在界面 | Status | 动作 |
| --- | --- | --- |
| Playback Current | 字幕条数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |
| Playback Collage | 已选字幕条数 / 字幕条数 | Copy Collage `P`、Export Collage `E`、Select `Return` |
| Playback Playlist / Subtitle Playlist | 字幕条数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |
| Playback Playlist / Video Playlist | 视频数 | Play `Return` |
| Command Panel Root | None | Open `Return`（选中 Copy Current Cue 时为 Copy `Return`） |
| Command Panel / Recent Videos | 视频数 | Open `Return` |
| Command Panel / Recent Excerpt Lists | 摘录集数 | Open `Return` |
| Command Panel / Search Results | 结果数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |

- Save to Excerpt List 打开 Excerpt Destination Submenu 选择目标列表，不直接保存；结果由当前界面右下角 Toast 呈现，成功时 Icon 为实心书签，失败或已存在时 Icon 为 warning
- 对不在数据库中的项执行 Save to Excerpt List 或 Copy Deep Link 时拦截，由当前界面右下角 Toast 呈现（持续 3 秒），Icon 为 warning，文案 `Cue Not in Library`，面板保持打开；执行 Play 时关闭浮层，进入黑屏播放界面并由 Player Error Banner 报错；从 Playback Overlay 正常执行 Play 进入播放时不显示 `Play` Playback Feedback
- 在 Command Panel 的 Recent Excerpt Lists 中打开没有有效项的列表时拦截，由 Command Panel 右下角 Toast 呈现（持续 3 秒），Icon 为 warning，文案 `No Available Excerpts`，面板保持打开
- `S`、`C`、`X`、`P`、`E` 为默认键位，Keycap 显示 Settings / Shortcuts 中的当前键位，修饰键（⌃、⌥、⇧、⌘）与主键各占一个 Keycap；快捷键已清空或冲突时不显示 Keycap

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
- Empty：当前字幕不在数据库中时，居中显示 Empty State（图标 `subtitle-question`），文案 `This subtitle is no longer in the library.`
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
- Empty：播放列表中没有仍在数据库中的项时，居中显示 Empty State（Subtitle Playlist 图标为 `subtitle-question`，Video Playlist 图标为 `video-question`），文案 `No items in this playlist are in the library.`

### L-08.6 Playback Collage Editor Layout

#### Structure

1. Collage Preview Region
2. Subtitle Selection Region

#### Collage Preview Region

1. Collage Image Viewport

#### Subtitle Selection Region

1. Playback Cue Reel / Focus Cue Reel
2. Vertical Scrollbar

#### Components

- Empty State
- Playback Cue Reel / Focus Cue Reel
- Subtitle Focus Cue
- Checkbox / Playback Selection Checkbox
- Playback Cue Metadata
- Scrollbar / Vertical

#### Sizes

- Region Width：1fr / 1fr
- Region Padding：`--spacing-8`

#### Cue Timeline

- Marker：Checkbox / Playback Selection Checkbox
- Metadata Ordinal：None

#### States

- Loading Preview
- Ready
- Empty Selection：未勾选任何字幕（已选条数为 0）时，左侧预览区容器内居中显示 Empty State（图标 `collage-hint`），文案 `Select subtitles to build a collage.`
- Empty：当前字幕不在数据库中时，居中显示 Empty State（图标 `subtitle-question`），文案 `This subtitle is no longer in the library.`
- Rendering
- Selection Limit Reached
- Exporting
- Group Hovered
  - 指针所在的截图组整体放大：Scale `--scale-collage-group-hover`，Duration `--duration-collage-group-hover`，easeOut
  - 放大部分越过图片边缘与相邻组，不被裁切；其余画面不变

## 3.9 Command Panel

### L-09.1 Command Panel Root Layout

#### Structure / Empty Query

1. Search Field（占位提示 `Search cues`）
2. Option List
   1. Copy Current Cue（存在可用台词时显示，标题右侧单行显示当前台词）
   2. Recent Videos
   3. Recent Excerpt Lists
3. Footer

#### Structure / Filled Query

1. Search Field
2. Option List
   1. Search Action（精确结果数统计完成后，右侧 Trailing Slot 显示 `xx results`）
   2. Copy Current Cue（存在可用台词时显示，标题右侧单行显示当前台词）
   3. Recent Videos
   4. Recent Excerpt Lists
3. Footer

#### Components

- Search Field
- Menu Item / Action Menu Item
- Playback Footer Layout
- Scrollbar / Vertical

#### Sizes

- Maximum Width：`--width-command-panel-max`
- Maximum Height：`--height-command-panel-max`
- Viewport Inset：`--inset-command-panel-viewport`
- Content Padding：`--spacing-5`
- Option Item Height：`--height-command-panel-item`
- Option Item Radius：`--radius-action-menu-item`

#### Surface

- Background：`--color-bg-dialog`
- Radius：`--radius-dialog`
- Shadow：`--shadow-popover`
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
   3. Filter Trigger：仅 Search Results
   4. Sort Trigger：仅 Search Results
2. Content Region
3. Footer

#### Components

- Icon Button
- Section Title
- Button / Neutral
- Menu
- Information Badge / Task Count Badge
- Playback Footer Layout
- Scrollbar / Vertical

#### Sizes

- Header Height：`--height-command-panel-header`
- Content Horizontal Padding：`--spacing-5`

#### Variants

- Recent Videos
  - Content：Recent Watching Card Grid（按 Recent Layout 时间分组展示；无记录时，若 `File` 无任何已入库文件夹则居中展示带 `Go to File` 按钮的 `folder-hint` Empty State，点击退出播放页并进入工作台 `File` 一级界面；否则居中展示图标 `video` 的 Empty State，文案 `No recent videos yet.`）
- Recent Excerpt Lists
  - Content：Excerpt List Card Grid（按 Recent Layout 时间分组展示；无摘录集时，若 `File` 无任何已入库文件夹则居中展示带 `Go to File` 按钮的 `folder-hint` Empty State，点击退出播放页并进入工作台 `File` 一级界面；否则居中展示图标 `excerpt` 的 Empty State，文案 `No recent excerpt lists yet.`）
- Search Results
  - Header：右侧依次为 Filter Trigger、Sort Trigger，样式与交互同 Search / Excerpt Toolbar Layout 的 Search
  - Content：Command Panel Search Results Layout

### L-09.3 Command Panel Search Results Layout

#### Structure

1. Playback Cue Reel / Cue Result Reel（最多显示前 100 条结果，首屏 100 条就绪后即刻渲染）
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
- Results（精确总数统计完成后，Footer Status 显示 `xx results`；超过 100 条时显示 `xx results (Showing first 100 results)`）
- Empty：无匹配结果时居中展示 Empty State（图标 `search-no-results`）
- Scrolling
- Settling
