# 版本

main

# 关联设计

- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/playback/Command Panel.md`

# 需求描述

1. **统一 Search、Excerpt 二级详情页与 Command Panel 搜索结果页的筛选与排序控件**：
   - 三处界面共用同一套「筛选按钮 + 排序按钮」组合与「排序下拉菜单」控制逻辑，移除 Command Panel 搜索结果页中的私有重复实现与硬编码。
   - 排序选项列表与当前选中状态由各界面按业务规则传入：Search 与 Command Panel 搜索结果页共用搜索排序项（默认排序、字符数最多、字符数最少）与排序状态；Excerpt 二级详情页使用摘录排序项（添加日期最早、添加日期最晚、字符数最多、字符数最少）及各摘录集独立的排序状态。
   - 三处界面的排序菜单在弹出定位、键盘方向键与回车/Esc 交互、滚轮隔离，以及打开筛选对话框或被更高层级界面遮挡时自动收起的行为上完全保持一致。

# 验收标准

1. 在 Search 界面、Excerpt 二级详情页、Command Panel 搜索结果页中，筛选按钮（含已选条件数量角标与 `Open` 态）与排序按钮（含当前排序文案与 `Open` 态）的外观、间距及交互表现完全一致。
2. 在上述三处界面打开排序菜单时，均支持鼠标悬停、键盘上下方向键移动高亮、回车确认选择、Esc 或点击外部关闭；当打开筛选对话框或被上层界面遮挡时，已展开的排序菜单均自动收起。
3. Search 与 Command Panel 搜索结果页展示 3 个搜索排序项且状态实时同步；Excerpt 二级详情页展示 4 个摘录排序项且按各摘录集独立保持。