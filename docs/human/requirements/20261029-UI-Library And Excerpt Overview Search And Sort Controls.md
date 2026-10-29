# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/playback/Playback Edge Cases.md`

# 需求描述

1. **Library 一级界面与 Excerpt 一级界面顶栏布局与搜索框**：
   - **顶栏结构统一（从左到右）**：
     - **Library 一级界面**：依次为搜索框（`C-01.3 Search Field`）、排序按钮（`Button / Neutral`，图标 `funnel-simple`）、文件夹数量（`xx folders`，`Workbench Status Indicator`）。
     - **Excerpt 一级界面**：依次为搜索框（`C-01.3 Search Field`）、排序按钮（`Button / Neutral`，图标 `funnel-simple`）、新建摘录集按钮（`Button / Neutral`，图标 `plus`）、摘录集与台词数量（`xx lists  yy cues`，`Workbench Status Indicator`）。
   - **搜索框尺寸与响应式折行规则（两界面统一）**：
     - 新增尺寸 Tokens：`--width-overview-search-field: 240px`（常规固定宽度）、`--min-width-overview-search-field: 180px`（最小宽度）；同行元素间距复用 `--spacing-4`（`16px`），控件高度复用 `--height-control`（`36px`）。
     - 当顶栏单行剩余宽度不足以在保持搜索框 `--width-overview-search-field`（`240px`）的前提下完整容纳末尾的数量统计时，搜索框维持 `240px` 不变，末尾的数量统计自动另起一行靠左对齐，上下两行间距复用 `--spacing-2`（`8px`）。
     - 仅当数量统计折至第二行后，第一行剩余宽度仍不足以容纳搜索框（`240px`）与同行操作按钮时，搜索框从 `--width-overview-search-field`（`240px`）向 `--min-width-overview-search-field`（`180px`）收缩。
   - **搜索行为、文案与空状态**：
     - 进入 Library 一级界面与 Excerpt 一级界面时，搜索框默认不自动聚焦；搜索词在 App 运行期间保留（从二级返回或跨 Sidebar Tab 切换不清空），点击清除按钮或重启 App 后清空。
     - **Library 一级界面**：占位提示词为 `搜索文件夹…` / `搜尋資料夾…` / `Search folders...`，按文件夹名称实时过滤卡片，`xx folders` 随搜索结果实时变化。当媒体库本身无任何文件夹时维持隐藏顶栏并展示空媒体库状态（图标 `video`）；当存在文件夹但搜索命中为 0 时，顶栏保持常驻，下方卡片区域居中展示搜索无结果空状态（图标 `search-no-results`，文案 `未找到匹配的文件夹。` / `找不到相符的資料夾。` / `No matching folders found.`）。
     - **Excerpt 一级界面**：占位提示词为 `搜索摘录集…` / `搜尋摘錄集…` / `Search excerpt lists...`，仅按摘录集名称实时过滤卡片，`xx lists  yy cues`（命中的摘录集数及其中去重后的有效台词数）随搜索结果实时变化。当搜索命中为 0 时，顶栏保持常驻，下方卡片区域居中展示搜索无结果空状态（图标 `search-no-results`，文案 `未找到匹配的摘录集。` / `找不到相符的摘錄集。` / `No matching excerpt lists found.`）。

2. **Excerpt 一级界面排序按钮与交互**：
   - 点击排序按钮展开与按钮左边缘对齐的 Radio Menu，提供两个选项：
     - 创建时间从旧到新（默认）：`最早创建` / `最早建立` / `Oldest Created`
     - 创建时间从新到旧：`最晚创建` / `最晚建立` / `Latest Created`
   - 排序选择持久化保存。
   - 在搜索或特定排序状态下新建、编辑或删除摘录集时，卡片列表与顶部数量统计立即按当前搜索词与排序方式更新展示；卡片右键菜单中“删除摘录集”的禁用判断保持按全局实际摘录集总数是否仅剩 1 个为准，不受搜索过滤影响。

3. **数据库边界情况的数据冻结（Hold）规则**：
   - 当 Library 一级界面或 Excerpt 一级界面已加载展示后，若后台发生数据库内容变更（如新增文件夹、重新索引、移除文件夹），在当前页面输入/修改/清空搜索词或切换排序方式时，均严格基于页面已加载的数据进行过滤与排序，不拉取更新后的数据库内容；仅当离开当前一级界面并重新进入时，才按最新数据库状态刷新。

# 验收标准

1. Library 一级界面顶栏从左到右为搜索框、排序、文件夹数量；Excerpt 一级界面顶栏从左到右为搜索框、排序、新建摘录集、摘录集与台词数量，搜索框常规宽度为 `240px`、最小宽度为 `180px`。
2. 缩小窗口宽度时，两个一级界面均优先保持搜索框 `240px` 固定宽度并将末尾的数量统计折至第二行靠左显示（行距 `8px`）；继续缩窄至第一行空间不足时，搜索框平滑收缩至不低于 `180px`。
3. Library 一级界面按文件夹名称搜索，Excerpt 一级界面按摘录集名称搜索，顶栏数量统计均随搜索结果实时变化；搜索无结果时顶栏常驻、下方居中展示 `search-no-results` 图标及对应三语文案；搜索词在 App 运行期间跨页面切换保留、重启后清空，进入页面时不自动聚焦搜索框。
4. Excerpt 一级界面排序按钮支持 `最早创建`（默认）与 `最晚创建` 并持久化保存；搜索或切换排序状态下新建、编辑、删除摘录集能即时按当前搜索词与排序更新，且仅在全局只剩 1 个摘录集时禁用删除。
5. 页面加载后后台发生数据库变更时，在 Library 一级界面与 Excerpt 一级界面内搜索或切换排序均维持数据冻结，不拉取新数据库数据，离开再返回后才刷新。