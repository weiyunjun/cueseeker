# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`：2.3 Buttons - Button - Variants - Destructive

# 需求

将 Destructive Button 调整为 Neutral Button 的危险操作变体：

1. 可用状态的 Label Color 和 Border Color 使用 `--color-danger-text`。
2. 背景、图标、尺寸及交互状态规则与 Neutral Button 一致。
3. Disabled 状态完全沿用 Neutral Button。

# 验收标准

1. Default、Hover、Focused 状态下，文字和边框使用危险红色。
2. 除文字和边框颜色外，Destructive Button 与 Neutral Button 的视觉及状态表现一致。
3. Light Mode 和 Dark Mode 均使用对应设计 Token。