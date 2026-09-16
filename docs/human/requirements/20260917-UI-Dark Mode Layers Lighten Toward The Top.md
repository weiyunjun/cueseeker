# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Core Tokens / 颜色；Inputs、Selection Controls、Buttons、Icon Button、Shortcut Action Button、Keycap、Menu、Table、Dialog、Subtitle Focus Cue、Settings Category Layout、Task Card Layout、Command Panel）
- `docs/human/design/UI Application Rules.md`（界面层级）

# 需求描述

## 1. 范围

仅 Dark：主窗口、设置窗口、播放页的 Playback Overlay 与 Command Panel。Light 外观不变。

## 2. 规则

1. 越上层越亮。
   - 主窗口与设置窗口：Sidebar < 页面 < 表格与设置卡片 < 对话框 < 菜单。
   - 播放页：视频 < Playback Overlay < Command Panel < 菜单。
2. 菜单始终最亮，包括在对话框与 Command Panel 内打开的菜单。
3. 控件底色、Hover、Disabled、分隔线与 Keycap 使用半透明白色，在任何表面上都比该表面亮。

## 3. 改动

### 3.1 表面

| Token | Dark |
| --- | --- |
| `--color-app-sidebar-bg` | `#111113` |
| `--color-bg-surface` | `#1C1C1F` |
| `--color-app-topbar-bg` | `#1C1C1F` |
| `--color-settings-group-bg` | `#26262A` |
| `--color-bg-popover` | `#36363B` |
| `--color-dialog-scrim` | `rgba(0,0,0,0.50)` |

新增：

| Token | 取值 | 使用位置 |
| --- | --- | --- |
| `--color-table-bg` | Light `#FFFFFF`；Dark `#26262A` | Workbench Search 与 Excerpt 表格，含表头 |
| `--color-bg-dialog` | Light `#FFFFFF`；Dark `#2F2F34` | Dialog Container、Task Card、Command Panel |
| `--color-command-panel-scrim` | Light `rgba(0,0,0,0.32)`；Dark `rgba(0,0,0,0.32)` | Command Panel 遮罩，取代代码中的固定值 |

### 3.2 控件与状态

1. 新增 `--color-bg-control`：Light `#FFFFFF`；Dark `rgba(255,255,255,0.08)`。Text Field、Text Area、Search Field、Number Field、Shortcut Field、Segmented Control、Filter Chip Default、Button / Neutral 与 Destructive 的 Default Background 由 `--color-bg-surface` 改为它。

| Token | Dark |
| --- | --- |
| `--color-bg-hover` | `rgba(255,255,255,0.12)` |
| `--color-bg-disabled` | `rgba(255,255,255,0.04)` |
| `--color-bg-checkbox-unchecked` | `rgba(255,255,255,0.08)` |
| `--color-border-control` | `#4A4A52` |
| `--color-border-muted` | `#4A4A52` |
| `--color-border-checkbox` | `#5A5A62` |
| `--color-border-divider` | `rgba(255,255,255,0.10)` |
| `--color-border-disabled` | `rgba(255,255,255,0.10)` |
| `--color-row-hover` | `#2E2E33` |
| `--color-row-selected` | `#36363C` |
| `--color-overlay-surface-keycap-bg`、`--color-popover-surface-keycap-bg` | `rgba(255,255,255,0.10)` |
| `--color-overlay-surface-keycap-bg-hover`、`--color-popover-surface-keycap-bg-hover` | `rgba(255,255,255,0.16)` |
| `--color-overlay-surface-shortcut-button-bg-hover`、`--color-popover-surface-shortcut-button-bg-hover` | `rgba(255,255,255,0.06)` |

2. Icon Button 的 Surface Hover：在 `--color-table-bg`、`--color-bg-dialog`、`--color-settings-group-bg` 上也为 `--color-bg-hover`。
3. Command Panel 内的 Shortcut Action Button 与 Keycap 继续使用 Popover Surface 变体。
4. Search Field 的 Disabled 边框由 `--color-border-control` 改为 `--color-border-disabled`，与设计文档一致；Select Mode 下的搜索框即此状态。

### 3.3 文字

| Token | Dark |
| --- | --- |
| `--color-text-primary` | `#E4E4E4` |
| `--color-text-muted` | `#979797` |
| `--color-subtitle-focus-cue-selected` | `rgba(255,255,255,0.88)` |

## 4. 保持不变

1. Light 下全部颜色不变；新增 Token 的 Light 值与改动前相同。
2. 强调色相关颜色、Player Chrome、Playback Overlay 背景、状态色与语言标签颜色不变。
3. 尺寸、圆角、阴影与布局不变。
4. Checkbox 的绘制方式不变：未勾选只画圆圈，内部透明。

# 验收

1. Light 下各界面外观与改动前一致。
2. Dark 下主窗口、设置窗口与播放页的明暗顺序符合第 2 节；对话框与 Command Panel 内打开的菜单比所在表面亮。
3. Dark 下按钮、输入框、搜索框、分段控件、Filter Chip 在页面、表格、设置卡片、对话框与 Command Panel 上都比所在表面亮；Hover 比 Default 亮，Disabled 比 Default 暗，Disabled 的边框在所在表面上可见。
4. Dark 下表格行、菜单项、图标按钮与快捷键按钮的 Hover 在所在表面上可见。
5. Dark 下 `--color-text-muted` 在页面、表格与对话框上的对比度不低于 4.5:1。
6. 本次改动不新增任何自动化端到端或单元用例的失败。