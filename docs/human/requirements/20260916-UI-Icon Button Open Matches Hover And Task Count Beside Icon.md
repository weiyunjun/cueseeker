# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon Button、Information Badge / Task Count Badge）

# 需求描述

## 1. 范围

1. 有 Open 态的纯图标按钮：Task Entry、Settings Entry、Filter Trigger、Select Mode Action、Collage Action。
2. Task Entry 的任务数量，出现在工作台顶栏、Playback Overlay 顶栏与播放页顶栏。

## 2. 改动

### 2.1 Icon Button Open

1. Open 外观与 Hover 相同：背景为所在表面的 Surface Hover，图标颜色不变。
2. 删除原 Open 外观（背景 `--color-text-muted`，图标 `--color-icon-on-dark`）。

### 2.2 Task Count Badge

1. 位置：由按钮右下角改为紧靠图标右侧，成为按钮的一部分，按钮向左变宽；Hover 与 Open 背景同时覆盖图标与数字，点击数字等同点击按钮。数量为 0 时隐藏，按钮恢复为正方形。
2. 尺寸：

| 部位 | 取值 |
| --- | --- |
| 高度 | `--size-control-icon`，删除 `--size-task-count-badge` |
| 形状 | 1 位数为圆形，2 位及以上为胶囊形 |
| 左右内边距 | `--spacing-1` |
| 与图标间距 | `--spacing-1`，从图标字形墨迹右缘量起 |
| 右缘到按钮右缘 | 与图标方框到按钮上缘的距离相同 |
| 字号 | `--font-size-task-count-badge` 改为 `13px` |
| 字重 | 新增 `--font-weight-task-count-badge`：`600` |

3. 颜色：数字颜色与所在按钮的图标颜色相同；圆形背景按所在表面取值，删除 `--color-task-count-badge-bg` 与 `--color-task-count-badge-text`：

| 所在表面 | Default | Hover / Open |
| --- | --- | --- |
| `--color-bg-surface` | `--color-popover-surface-keycap-bg` | `--color-popover-surface-keycap-bg-hover` |
| `--color-subtitle-focus-overlay-bg` | `--color-overlay-surface-keycap-bg` | `--color-overlay-surface-keycap-bg-hover` |
| `--color-player-topbar-gradient-start` | 新增 `--color-player-task-count-badge-bg`：Light `rgba(255,255,255,0.16)`；Dark `rgba(255,255,255,0.16)` | 新增 `--color-player-task-count-badge-bg-hover`：Light `rgba(255,255,255,0.28)`；Dark `rgba(255,255,255,0.28)` |

## 3. 保持不变

1. 任务数量的含义与显示条件不变。
2. 各按钮的图标、Hover 背景与触发条件不变。

# 验收

1. 三个顶栏在 Light 与 Dark 下，无任务、1 位数、2 位数的 Default、Hover、Open 外观与本文一致。
2. Settings Entry、Filter Trigger、Select Mode Action、Collage Action 的 Open 与各自 Hover 外观相同。
3. 本次改动不新增任何自动化端到端或单元用例的失败。