# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **外观模式切换至 `Auto` 时立即同步跟随系统外观**：
   - 在 `Settings > General > Appearance` 中将 `Appearance Mode` 在 `Light`、`Dark` 与 `Auto` 之间任意切换时，主窗口与设置窗口的窗口外框及窗口内部所有界面内容均应立即切换为目标外观；切回 `Auto` 时立即恢复与当前 macOS 系统外观（浅色或深色）一致，无需切换到其他应用再切回才能生效，也不得出现窗口外框已变为系统外观而内部画面仍停留在切换前外观的不一致状态。

# 验收标准

1. **macOS 系统浅色模式下切回 `Auto` 立即恢复浅色**：
   - 当 macOS 系统处于浅色模式时，在设置中依次将 `Appearance Mode` 从 `Light` 切换为 `Dark`、再切换为 `Auto`，主窗口与设置窗口的内部画面及窗口外框均立即恢复为浅色模式，不出现画面仍停留在深色或窗口边框与内容明暗不一致的现象。
2. **macOS 系统深色模式下切回 `Auto` 立即恢复深色**：
   - 当 macOS 系统处于深色模式时，在设置中依次将 `Appearance Mode` 从 `Dark` 切换为 `Light`、再切换为 `Auto`，主窗口与设置窗口的内部画面及窗口外框均立即恢复为深色模式。