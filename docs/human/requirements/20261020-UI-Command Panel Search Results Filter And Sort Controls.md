# 版本

main

# 关联设计

- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/playback/Command Panel.md`

# 需求描述

1. **Command Panel 搜索结果页顶栏加入筛选与排序按钮（`L-09.2 Command Panel Secondary Layout`）**：
   - 在 Command Panel 的搜索结果二级页（`Search Results`）顶部返回按钮所在一栏的右侧，从左到右依次加入**筛选按钮（Filter）**与**排序按钮（Sort）**；`Recent Videos` 与 `Recent Excerpt Lists` 二级页顶栏保持不变。
   - 两个按钮的外观、图标、文案、角标、间距、弹出筛选对话框与排序单选菜单的内容及行为，均与 Workbench 搜索页完全一致。
   - 顶栏搜索词标题默认水平居中；空间不足时与左侧返回按钮、右侧筛选按钮保持安全间距并单行省略截断。

2. **状态共享与交互规则**：
   - Command Panel 搜索结果页与 Workbench 搜索页共用同一套筛选条件与排序方式（含跨重启持久化）；在任意一处修改筛选或排序，另一处及当前搜索结果列表、底部结果计数同步更新生效。
   - 在 Command Panel 搜索结果页打开筛选对话框或排序菜单期间，遵循全局界面层级与菜单模态规则：关闭筛选对话框或排序菜单后仅回到 Command Panel 搜索结果页，不关闭或回退 Command Panel。
   - 本版本这两个按钮不做手柄交互支持。

# 验收标准

1. Command Panel 搜索结果页顶栏右侧正确展示筛选与排序按钮，标题在空间不足时正确避让截断；其余二级页不展示这两个按钮。
2. 筛选按钮角标、筛选对话框、排序按钮与单选菜单的展示及交互与 Workbench 搜索页完全一致，修改后当前 Command Panel 结果与 Workbench 搜索页双向同步生效。
3. 筛选对话框与排序菜单打开及按 `Esc`/点击外部关闭时，均正确停留在 Command Panel 搜索结果页。