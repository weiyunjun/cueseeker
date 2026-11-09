# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`

# 需求描述

1. **播放器界面（`Player Chrome`）独立样式体系与半透明浮层无边框统一**：
   - 播放页本体（`Player Chrome`：顶栏、底栏控制条、进度条与时间胶囊、左下角台词队列控制栏、播放器弹出菜单及音轨二级菜单、`Playback Feedback`、`Player Error Banner` 及其触发的 `Tooltip`）脱离工作台 Light / Dark Mode 体系，在 Light Mode 与 Dark Mode 下恒定使用同一套 `Player Chrome` 专属样式（`Playback Overlay` 与 `Command Panel` 仍跟随系统 Light / Dark Mode）。
   - 播放器界面下的所有半透明黑底浮层（播放器弹出菜单及音轨二级菜单、`Tooltip`、`Playback Feedback`、左下角台词队列控制栏、进度条时间胶囊）背景统一为 `--color-player-menu-bg`（`rgba(0,0,0,0.55)`），且**全部去除描边（`Border: None`）**。

2. **播放器弹出菜单、分隔线与滚动条独立样式（`C-04.1`、`C-04.2`、`C-04.3`、`C-04.4`、`C-07.1`）**：
   - `Player Subtitle Menu`、`Player Speed Menu`、`Player More Menu` 与 `Audio Track Submenu` 容器背景为 `--color-player-menu-bg`（`rgba(0,0,0,0.55)`），无边框（`Border: None`），阴影为 `--shadow-player-overlay`（`0 12px 24px rgba(0,0,0,0.42)`）。
   - 菜单项（`C-04.3`）在 `Player Chrome` 下默认文字与图标颜色为 `--color-player-text-primary`（`rgba(255,255,255,0.94)`），Hover 底色为 `--color-player-menu-item-hover-bg`（`rgba(255,255,255,0.12)`），Disabled 文字与图标颜色为 `--color-player-text-tertiary`（`rgba(255,255,255,0.34)`）。
   - 菜单分隔线（`C-04.4`）在 `Player Chrome` 下颜色为新增的 `--color-player-menu-divider`（Light `rgba(255,255,255,0.10)`、Dark `rgba(255,255,255,0.10)`）。
   - 菜单内容溢出时的垂直滚动条（`C-07.1`）在 `Player Chrome` 下默认滑块色为新增的 `--color-player-scrollbar-thumb-default`（Light `rgba(255,255,255,0.24)`、Dark `rgba(255,255,255,0.24)`），Hover / Dragging 滑块色为新增的 `--color-player-scrollbar-thumb-interactive`（Light `rgba(255,255,255,0.38)`、Dark `rgba(255,255,255,0.38)`）。

3. **播放器 `C-08.6 Tooltip`、`C-08.9 Keycap` 与 `C-09.5 Playback Feedback` 样式统一**：
   - **`C-08.6 Tooltip`（`Player Chrome` 表面）**：容器背景为 `--color-player-menu-bg`（`rgba(0,0,0,0.55)`），无边框（`Border: None`），圆角保持 `--radius-control`（`8px`），阴影为 `--shadow-player-overlay`（`0 12px 24px rgba(0,0,0,0.42)`），主文字颜色为 `--color-player-text-primary`（`rgba(255,255,255,0.94)`）。
   - **`C-08.9 Keycap / Player Chrome` 变体**：播放器 Tooltip 右侧快捷键使用 `Keycap / Player Chrome`，无边框，背景为新增的 `--color-player-keycap-bg`（Light `rgba(255,255,255,0.14)`、Dark `rgba(255,255,255,0.14)`），内部文字与图标颜色为 `--color-player-text-primary`（`rgba(255,255,255,0.94)`）。
   - **`C-09.5 Playback Feedback`**：容器背景由 `--color-player-topbar-gradient-start` 改为 `--color-player-menu-bg`（`rgba(0,0,0,0.55)`），保持无边框与无阴影。

4. **`C-12.7 Player Cue Queue Control Bar`（左下角 `Auto Pause`、`Auto Switch` 与 `Gap Stepper`）样式简化**：
   - **外层容器**：背景保持 `--color-player-menu-bg`（`rgba(0,0,0,0.55)`），去除外框描边（`Border: None`）。
   - **开关按钮（`Auto Pause`、`Auto Switch`）**：去除左侧状态圆点，仅保留文字标签（字号 `--font-size-caption: 12px`、字重 `600`、高 `--height-player-cue-control: 28px`、圆角 `--radius-player-cue-control: 6px`、左右内边距 `--padding-player-cue-toggle-x: 10px`）；各状态配色为：
     - `Default（Off）`：背景 `Transparent`，文字 `--color-player-text-secondary`（`rgba(255,255,255,0.62)`）；
     - `Hover（Off）` 与 `Open（On，含 Hover）`：背景 `--color-player-control-bg-hover`（`rgba(255,255,255,0.16)`），文字 `--color-player-text-primary`（`rgba(255,255,255,0.94)`）；
     - `Pressed`：背景 `--color-player-control-bg-pressed`（`rgba(255,255,255,0.24)`），文字 `--color-player-text-primary`（`rgba(255,255,255,0.94)`）；
     - `Disabled`：背景 `Transparent`，文字 `--color-player-text-tertiary`（`rgba(255,255,255,0.34)`）。
   - **`Gap Stepper`（`- 500 ms +`）**：去除内层容器背景、内边框与内边距，且与左侧开关按钮之间不加分隔竖线，直接平铺于控制栏内；两侧加减按钮尺寸统一为 `--height-player-cue-control` × `--height-player-cue-control`（`28px × 28px`）、圆角为 `--radius-player-cue-control`（`6px`）、图标尺寸保持 `--size-player-cue-stepper-icon`（`14px`）。

5. **播放页其余组件 Token 对齐与废弃 Token 清理**：
   - 播放页顶栏按钮（`C-03.2 Icon Button`）与任务数量角标（`C-08.3 Task Count Badge`）在 `Player Chrome` 下处于 `Disabled` 态时统一使用 `--color-player-text-tertiary`（`rgba(255,255,255,0.34)`）；音量滑块（`C-12.5`）填充与滑块圆点统一引用 `--color-player-error-content`（`#FFFFFF`）。
   - 从 `UI Tokens.md` 中移除废弃及未使用的 11 个 Token：`--color-player-cue-control-bar-border`、`--color-player-cue-control-stepper-bg`、`--color-player-cue-control-stepper-border`、`--color-player-cue-control-status-active`、`--size-player-cue-status-dot`、`--gap-player-cue-toggle-dot`、`--padding-player-cue-stepper`、`--size-player-cue-stepper-button`、`--radius-player-cue-stepper-button`、`--color-player-control-bg-active`、`--color-player-menu-item-selected-bg`。

# 验收标准

1. **半透明浮层统一与无细白边**：
   - 在 Light Mode 与 Dark Mode 下进入播放页，字幕菜单、倍速菜单、更多与音轨二级菜单、悬停弹出的 `Tooltip`（及内部快捷键键帽）、左上角 `Playback Feedback`、左下角台词队列控制栏以及进度条时间胶囊均呈现统一的 `rgba(0,0,0,0.55)` 半透明黑底，所有浮层外框与内框均无 `1px` 细白边，且在浅色与深色模式下外观完全一致。
2. **播放器菜单、Tooltip 键帽与滚动条表现**：
   - 在播放器顶底栏及左下角控制栏悬停触发带快捷键的 `Tooltip` 时，气泡为 `rgba(0,0,0,0.55)` 半透明黑底、主文字为 `rgba(255,255,255,0.94)`，内部键帽底色为 `rgba(255,255,255,0.14)`、文字/图标为 `rgba(255,255,255,0.94)`。
   - 在 Light Mode 下打开包含多条字幕或音轨的播放器菜单，分隔线为 `rgba(255,255,255,0.10)`，溢出时显示的滚动条滑块为半透明白色（默认 `0.24`、交互 `0.38`），不会出现浅色模式的亮灰滑块。
3. **左下角台词队列控制栏外观与交互**：
   - `Auto Pause` 与 `Auto Switch` 不再显示左侧圆点，关闭时为透明底配次要白字（`0.62`），悬停或开启（`Open`）时为 `0.16` 半透明白底配主白字（`0.94`），按下时为 `0.24` 半透明白底，禁用时为透明底配三级暗白字（`0.34`）。
   - 右侧 `Gap Stepper` 无内层套框、无内描边、无左侧分隔竖线，`-` 与 `+` 按钮尺寸（`28×28px`）及圆角（`6px`）与左侧开关按钮完全一致。