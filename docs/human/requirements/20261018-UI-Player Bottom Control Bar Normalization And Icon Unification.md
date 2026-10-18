# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **Tokens 变更（`UI Tokens.md`）**：
   - 修改进度条轨道颜色：`--color-player-progress-track` 改为 `rgba(255,255,255,0.24)`，`--color-player-progress-hover-track` 改为 `rgba(255,255,255,0.38)`。
   - 修改底栏高度：`--height-player-bottom-controls-row` 改为 `44px`，`--height-player-bottom-control-bar` 改为 `90px`。
   - 新增：`--padding-player-speed-button-x`: `10px`、`--width-player-volume-slider`: `68px`、`--size-player-volume-thumb`: `10px`、`--width-player-volume-value`: `32px`、`--padding-player-volume-trailing`: `10px`、`--duration-player-volume-expand`: `0.18s`。
   - 移除废弃的早期底栏与旧版倍速菜单专用 Tokens：`--size-player-circle-button`、`--size-player-circle-button-icon`、`--height-player-capsule-button`、`--padding-player-capsule-button-x`、`--width-player-speed-button`、`--radius-player-capsule`、`--color-player-control-bg`、`--color-player-icon-selected`、`--gap-player-bottom-left-controls`、`--gap-player-bottom-right-controls`、`--gap-player-time-label`、`--width-player-speed-menu`、`--height-player-speed-menu`、`--height-player-speed-menu-item`、`--font-size-player-speed-menu-item`、`--font-size-player-speed-menu-check`、`--padding-player-speed-menu-item-x`、`--radius-player-speed-menu`、`--radius-player-speed-menu-item`。

2. **底栏背景与图标按钮对齐顶栏（`L-07.2`、`C-03.2`）**：
   - 底栏铺设与顶栏对称的自下而上暗色渐变背景（底部起点 `--color-player-topbar-gradient-start`: `rgba(18,18,24,0.66)`，顶部终点 `--color-player-topbar-gradient-end`: `rgba(18,18,24,0)`）。
   - 移除底栏圆形按钮（`C-12.1`）与双按钮胶囊组（`C-12.4`），底栏所有图标按钮统一使用 `C-03.2 Icon Button / Default`（尺寸 `--size-icon-button: 32px`、圆角 `--radius-control: 8px`、图标 `--size-control-icon: 21px` 线宽 `1.35px`；左侧播放/暂停、上一个、下一个保持 `Fill` 实心字重，其余保持 `Regular` 线性字重）。
   - 移除原有的常驻独立黑底与双层同心缩放动画：默认态背景全透明、图标为 `--color-player-text-primary`（禁用态为 `--color-player-text-tertiary`）；Hover、菜单打开（`Open`）以及字幕处于开启状态时，容器直接填充单层 `--color-player-control-bg-hover`（`rgba(255,255,255,0.16)`），图标保持 `--color-player-text-primary`。
   - 底栏左右两组控件的间距均统一为 `--spacing-1`（`4px`），与顶栏按钮间距一致。

3. **进度条与两端时间显示（`L-07.3`、`C-12.3`、`C-12.5`、`C-12.6`）**：
   - 移除底栏左侧按钮组内的时间胶囊，改为在进度条左右两端分别展示**当前时间**（如 `06:07`）与**剩余时间**（带负号，如 `-17:34`），时间文字与进度条之间的水平间距为 `--spacing-3`（`12px`）。
   - 两端时间均使用 `--font-size-player-time`（`12px`）等宽数字，颜色均为 `--color-player-text-primary`（`rgba(255,255,255,0.94)`），无背景底托、无 Hover 效果。
   - 进度条上方悬停/拖拽时间预览框（`C-12.6`）改为单层 `--color-player-menu-bg` 背景、圆角 `--radius-field`（`6px`），距进度条热区上沿 `--spacing-1`（`4px`）。

4. **音量控件、倍速按钮与播放菜单规范化（`C-12.2`、`C-12.7`、`C-04.1`）**：
   - **音量控件（`C-12.7`）**：收起态为 `32×32px` 图标按钮；悬停展开时容器高 `--size-icon-button`（`32px`）、圆角 `--radius-control`（`8px`）、背景 `--color-player-control-bg-hover`，内部滑块宽 `--width-player-volume-slider`（`68px`）、高 `--height-player-progress-track`（`3px`）、圆点 `--size-player-volume-thumb`（`10px`），百分比文字字号 `--font-size-player-time`（`12px`）、宽 `--width-player-volume-value`（`32px`）、右侧内边距 `--padding-player-volume-trailing`（`10px`），展开/收起过渡时长 `--duration-player-volume-expand`（`0.18s`）。
   - **倍速按钮（`C-12.2`）**：高 `--size-icon-button`（`32px`）、圆角 `--radius-control`（`8px`）、水平内边距 `--padding-player-speed-button-x`（`10px`）、字号 `--font-size-player-time`（`12px`）；默认背景透明，Hover 与倍速菜单打开（`Open`）期间显示 `--color-player-control-bg-hover` 背景。
   - **倍速菜单与更多菜单（`Player Speed Menu` / `Player More Menu`）**：几何尺寸统一对齐全局 `C-04.1 Menu`（外圆角 `--radius-menu: 12px`、内边距 `--padding-menu: 6px`、菜单项高 `--height-select-menu-item: 32px`、菜单项圆角 `--radius-select-menu-item: 6px`、水平内边距 `--padding-menu-item: 10px`、字号 `--font-size-control: 14px`、勾选图标 `16px`），表面颜色保持 `--color-player-menu-bg` 与 `--color-player-menu-item-hover-bg`。

# 验收标准

1. 播放页底栏展示自下而上的暗色渐变遮罩，底栏所有图标按钮与顶栏图标按钮外观、尺寸（`32×32px`、`8px` 圆角、`21px` 图标）、间距（`4px`）及单层 Hover/Open 背景（`rgba(255,255,255,0.16)`）完全一致，无常驻黑圆底与同心缩放动画。
2. 字幕开启时，字幕按钮显示 `rgba(255,255,255,0.16)` 圆角背景与白色图标；字幕关闭时无常驻背景。
3. 进度条左端显示当前时间、右端显示带负号的剩余时间（间距 `12px`，均为 `12px` 等宽一级亮白文字，无背景与 Hover 效果）；拖动或点击进度条时两端时间与上方 `6px` 圆角时间预览框实时更新；进度条未播放轨道在暗色画面下清晰可见。
4. 音量控件悬停展开为 `32px` 高、`8px` 圆角的半透明长条，滑块与 `12px` 百分比文字正常交互；即使在 `600px` 最窄窗口下展开音量条，底栏两侧控件也不发生挤压重叠。
5. 点击倍速按钮（`1x`）或更多按钮（`⋮`）弹出菜单期间，挂靠按钮保持 `Open` 高亮背景；两个菜单的圆角、内边距、菜单项高度与字号均与全局菜单规格一致。