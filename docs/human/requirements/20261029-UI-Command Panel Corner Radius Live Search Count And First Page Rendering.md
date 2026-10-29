# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/workbench/Search and Filter.md`

# 需求描述

1. **Command Panel 圆角与尺寸规范化（消除私自硬编码，对齐 UI 设计规范）**：
   - **容器与选项行圆角调整**：
     - Command Panel 外层容器圆角由私自硬编码的 `18px` 调整为复用全局对话框圆角 Token `--radius-dialog`（`10px`），阴影使用 `--shadow-popover`。
     - Command Panel 一级界面（`L-09.1 Command Panel Root Layout`）的选项行圆角由私自硬编码的 `10px` 调整为复用 `C-04.3 Menu Item / Action Menu Item` 的标准圆角 Token `--radius-action-menu-item`（`6px`）。
   - **选项行视觉与状态对齐**：
     - 一级选项行高度为 `--height-command-panel-item`（`48px`），水平内边距与内部元素间距为 `--spacing-3`（`12px`），行间距为 `--spacing-1`（`4px`），左侧图标尺寸为 `--size-control-icon`（`21px`）。
     - 选项行 `Hover` 背景色统一使用 `--color-bg-hover`（修正原私自使用表格行选中色的实现），`Selected` 背景色使用 `--color-menu-item-selected-bg`（同时处于 `Selected` 与 `Hover` 时仅显示 `Selected` 背景，不叠加）。
   - **新增与复用尺寸 Token（录入 `UI Tokens.md` 并在 `L-09.1` / `L-09.2` 中体现）**：
     - 新增 `--width-command-panel-max: 1040px`（Command Panel 容器最大宽度）。
     - 新增 `--height-command-panel-max: 720px`（Command Panel 容器最大高度）。
     - 新增 `--inset-command-panel-viewport: 40px`（Command Panel 容器距窗口四边的最小安全边距）。
     - 新增 `--height-command-panel-item: 48px`（Command Panel 一级界面选项行高度）。
     - 新增 `--height-command-panel-header: 58px`（Command Panel 二级界面顶部导航栏高度）。
     - 面板内容区水平及搜索框四周内边距复用 `--spacing-5`（`20px`）。

2. **Command Panel 一级界面输入即触发搜索并实时显示 `xx results`**：
   - **输入/预填即搜**：在 Command Panel 一级界面输入非空搜索词时（包含打开面板自动预填当前焦点台词的场景），复用 Workbench Search 的输入触发与防抖机制（`100ms` 防抖）立即在后台启动搜索，并共享当前生效的 Filter 与 Sort 条件。
   - **右侧结果数展示**：
     - 在一级界面 `Search <搜索词>` 选项行的右侧（`Trailing Slot`）展示当前搜索词的匹配结果数量 `xx results`（单数为 `1 result`，文案格式与 Workbench Search 完全一致）。
     - 样式：字号 `--font-size-body`（`14px`）、字重 Regular（`400`）、颜色 `--color-text-muted`（与左侧搜索词详情一致）；当搜索词过长时，左侧搜索词单行尾部省略截断，右侧 `xx results` 保持完整显示不截断（两者最小间距 `--spacing-3` `12px`）。
     - 显隐时机：仅在当前搜索词的精确结果总数计算完成后显示（含 `0 results`）；防抖等待或后台统计尚未得出当前词精确总数期间隐藏，不显示上一次搜索词的旧计数。
   - **进入二级结果页复用已有搜索**：按 `Return` 或点击 `Search <搜索词>` 进入二级 `Search Results` 界面时，若当前搜索词的搜索已在进行中或已完成，直接复用该搜索状态与结果，不重复重新发起搜索（若仍处于防抖等待期则立即触发执行）。

3. **Command Panel 搜索最多显示 100 条 + 首屏 100 条即刻渲染（与 Workbench Search 对齐）**：
   - **展示上限与首屏统一为 100 条**：
     - Command Panel 搜索结果的最大展示条数由 `50` 条调整为 `100` 条，与 Workbench Search 首屏大小（`100` 条）对齐。
     - 二级界面底部状态栏（`L-08.3 Playback Footer Layout`）在结果总数超过 `100` 条时显示 `xx results (showing first 100)`，不超过 `100` 条时显示 `xx results`。
   - **首屏 100 条先到先渲染，不等全量搜索完成**：
     - 对齐 Workbench Search 的前端渲染逻辑：仅按需读取并渲染前 `100` 条结果。
     - 当搜索首屏 `100` 条结果先产出时，二级 `Search Results` 列表立即渲染这 `100` 条字幕并支持浏览、滚动与操作，不等待全库扫描结束。
     - 后台继续完成全库精确总数统计：统计进行中底部状态栏暂不显示未完成的临时条数；待全库精确总数算出后，仅更新底部状态栏的 `xx results` / `xx results (showing first 100)` 文本，若首屏前 `100` 条结果内容未发生变化，不重置或重复刷新已渲染的字幕列表。

# 验收标准

1. 打开 Command Panel，外层容器圆角为 `10px`（`--radius-dialog`），一级界面选项行圆角为 `6px`（`--radius-action-menu-item`），选项行 Hover 背景为 `--color-bg-hover`、Selected 背景为 `--color-menu-item-selected-bg`，面板与二级顶栏尺寸全部由设计 Token 驱动，无私自硬编码。
2. 打开 Command Panel（含自动预填台词）或在搜索框输入搜索词时，无需按回车即自动在后台开始搜索；统计完成后，`Search <搜索词>` 行最右侧显示准确的 `xx results`（或 `1 result` / `0 results`），检索未完成前不闪现旧数字，超长搜索词不会挤掉右侧结果数。
3. 在一级界面看到结果数后按回车或点击 `Search <搜索词>` 进入二级结果页，直接秒开展示已就绪的搜索结果，不会重新清零重搜。
4. 搜索匹配结果较多的词（如单字母）并进入二级结果页，首屏前 `100` 条结果产出后立即渲染展示，无需等待全库统计结束；全库统计完成后，底部状态栏更新为 `xx results (showing first 100)`，且已渲染的首屏 `100` 条列表不发生闪烁或重置。
5. Command Panel 搜索结果最多展示 `100` 条；在二级结果页修改 Filter 或 Sort 时，首屏 `100` 条与底部状态栏计数均按新条件正确更新，并与 Workbench Search 保持同步。