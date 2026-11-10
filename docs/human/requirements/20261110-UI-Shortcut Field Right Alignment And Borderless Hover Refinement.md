# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`

# 需求描述

1. **`C-01.5 Shortcut Field` 键帽右对齐（`UI Components - Controls.md`）**：
   - 将 `Shortcut Field` 内部 `C-08.9 Keycap / Popover Surface` 的水平排布位置（Placement）由 `Leading`（左对齐）调整为 `Trailing`（右对齐），多个键帽之间间距保持 `--spacing-1`（`4px`）。
   - 进入 `Recording` 录制状态时，占位文字（Placeholder）保持 `Leading`（左对齐），清空按钮（`Inline Clear`）保持 `Trailing`（右对齐）。

2. **`C-01.5 Shortcut Field` 默认去框线及 `Hover` / `Pressed` 背景与键帽联动（`UI Design Rules.md`、`UI Components - Controls.md` & `UI Components - Domain.md`）**：
   - **默认与已清空状态（`Default` / `Empty`）**：外层容器去除常驻边框与背景填充（`Background: Transparent`、`Border: None`，圆角保持 `--radius-field: 6px`，尺寸保持 `--width-shortcut-field: 144px` × `--height-field: 30px`、水平内边距 `--padding-field-x: 10px`）。
   - **悬停状态（`Hover`）**：鼠标悬停在未处于录制状态的 `Shortcut Field` 容器热区（`144px` 宽度区域）时，外层容器显示 `--color-bg-hover` 背景（Light `#F3F4F6`、Dark `rgba(255,255,255,0.12)`）；内部 `C-08.9 Keycap / Popover Surface` 同步切换至 `Hover` 状态背景 `--color-popover-surface-keycap-bg-hover`（Light `#E0E3E8`、Dark `rgba(255,255,255,0.16)`）。
   - **按下状态（`Pressed`）**：鼠标左键在未处于录制状态的 `Shortcut Field` 容器热区内按住时，外层容器显示 `--color-bg-pressed` 背景（Light `#E5E7EB`、Dark `rgba(255,255,255,0.16)`）；内部 `C-08.9 Keycap / Popover Surface` 同步切换至 `Pressed` 状态背景 `--color-popover-surface-keycap-bg-pressed`（Light `#D2D6DE`、Dark `rgba(255,255,255,0.22)`），在热区内松开左键后进入 `Recording` 录制状态。
   - **录制状态（`Recording`）与冲突报错状态（`Error`）保持不变**：
     - `Recording` 状态外层容器背景为 `--color-bg-control`（Light `#FFFFFF`、Dark `rgba(255,255,255,0.08)`），边框为 `--color-border-focus`（`macOS accent color`，线宽 `--border-width-control: 1px`）。
     - `Error` 冲突状态外层容器保留红色警示边框 `--color-danger-text`（Light `#B42318`、Dark `#FCA5A5`，线宽 `--border-width-control: 1px`）及下方冲突提示文案。

# 验收标准

1. **键帽右对齐与默认无框线**：在 `Settings -> Shortcuts` 页面（Light Mode 与 Dark Mode）中，未悬停且无冲突的快捷键行不再显示外层输入框边框与底色，所有行的键帽均在右侧固定宽度区域内靠右对齐。
2. **悬停与按下背景及键帽层次联动**：
   - 鼠标移入任意未录制的 `Shortcut Field` 区域（`144px` 宽度）时，圆角容器浮现 `--color-bg-hover` 灰色背景，内部键帽底色加深一档为 `--color-popover-surface-keycap-bg-hover`；
   - 左键按住未松手时，外层容器底色进一步加深为 `--color-bg-pressed`，内部键帽底色同步加深为 `--color-popover-surface-keycap-bg-pressed`；松开左键后进入 `Recording` 录制状态。
3. **录制与冲突状态**：进入录制状态时显示系统强调色焦点外框（`--color-border-focus`）、左侧占位文字与右侧清空按钮；发生快捷键冲突时，保留红色外框（`--color-danger-text`）与下方冲突提示文案；非默认快捷键左侧的「恢复默认」按钮位置与功能保持正常。