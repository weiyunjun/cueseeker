# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Information Badge / Task Count Badge）

# 需求描述

## 1. 范围

Task Count Badge 的全部位置：Task Entry（工作台顶栏、Playback Overlay 顶栏、播放页顶栏）、Filter Trigger、Filter Dialog 的 Section Header。

## 2. 改动

### 2.1 颜色

1. Background：与所在按钮的图标颜色相同；在 Section Header 内与名称颜色相同。
2. Text Color：`--color-bg-surface`；在 `--color-player-topbar-gradient-start` 上为 `--color-player-icon-selected`。
3. 按钮 Hover 或 Open 时，Badge 外观不变。
4. 删除 `--color-player-task-count-badge-bg` 与 `--color-player-task-count-badge-bg-hover`，Badge 不再使用 Keycap 颜色。

### 2.2 形状

1. 1 位数：宽与高相等，为正圆。
2. 2 位及以上：左右内边距 `--spacing-2`，为胶囊形。
3. 两端为正半圆，数字在 Badge 内水平、垂直居中。

## 3. 保持不变

1. Badge 的位置、高度、字号、字重与显示条件不变。
2. Playback Overlay 底部的快捷键提示不变。
3. Icon Button 的 Hover 与 Open 外观不变。

# 验收

1. Light 与 Dark 下，三个顶栏的 Task Entry、Filter Trigger 与 Section Header 在 1 位数、2 位数时，Badge 外观与本文一致；按钮 Hover、Open 时 Badge 不变。
2. 1 位数为正圆；2 位数为两端正半圆的胶囊，左右对称，数字居中。
3. Playback Overlay 底部快捷键提示外观不变。
4. 本次改动不新增任何自动化端到端或单元用例的失败。