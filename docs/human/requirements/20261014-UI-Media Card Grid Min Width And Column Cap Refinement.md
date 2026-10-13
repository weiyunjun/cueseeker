# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

1. **封面卡片最小宽度**：由 `260px` 调整为 `220px`。
2. **网格最大列数**：
   - **存在 Sidebar 时**：每行最多显示 `5` 张卡片。
   - **没有 Sidebar 时**：每行最多显示 `6` 张卡片（Command Panel 因自身宽度限制自然显示 `4` 张卡片）。

# 验收标准

1. Dock 位于左侧或底部时：Workbench 展开 Sidebar 每行显示 5 张卡片，收起 Sidebar 及 Playback Overlay 每行显示 6 张卡片，Command Panel 二级网格界面每行显示 4 张卡片。
2. 窗口缩小时按 `220px` 最小宽度自动递减列数，最小窗口宽度下每行显示 1 张卡片。