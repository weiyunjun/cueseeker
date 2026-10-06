# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`

# 需求描述

1. **现状问题**：
   - 当用户在 macOS 系统设置中切换系统强调色（System Accent Color，如从蓝色改为紫色）时，表格头部的 SwiftUI Checkbox 能实时变色，但表格行内的 Checkbox（以及其他纯 AppKit 绘制的带色图标）仍停留在旧强调色，必须重启 App 才能更新。
2. **产生原因**：
   - `AppIconStore.tintedImage` 将带有颜色的图标离屏烘焙为位图并缓存在 `tintedCache` 中，缓存 Key 仅包含 `color.hashValue`。动态单例 `NSColor.controlAccentColor` 改变时不改变 `hashValue`，且缺少缓存失效与系统颜色变更监听机制。
3. **修复要求**：
   - `AppIconStore` 监听系统颜色变更通知（`NSColor.systemColorsDidChangeNotification`），在强调色或系统颜色发生变化时清空 `tintedCache`。
   - 依赖该图标缓存的原生表格视图（`SubtitleTableView`）在系统颜色变化时触发重绘刷新，确保无需重启 App 即可实时响应系统强调色变更。

# 验收标准

1. 打开含有勾选 Checkbox 的 Search 或 Excerpt 表格。
2. 在 macOS 系统设置中切换强调色（如从蓝色切换为紫色/绿色/石墨色等）。
3. 无需重启 App，表格行内的 Checkbox 与表头 Checkbox、选择横幅颜色一致，立即实时更新为新选取的系统强调色。