# 版本
main

# 需求描述
1. 准备修改Search及Shiori界面。如图所示，将现在的2栏改造为3栏：搜索框及其他按钮，筛选条件可视化数据面板，结果表格
2. 可以点击Filter按钮，显示/隐藏筛选条件可视化数据面板。当显示时，Filter按钮的外观和当前弹出菜单时Filter按钮的外观一致。
3. 所有筛选条件，都可以多选。
4. 每次搜索都要进行全量搜索，保证数据面板可以显示正确的数据，这里本质上是一种数据范畴分布的显示。
5. 数据卡片内部多选默认是或的关系，例如选1~3s和3~5s其实就是同时选择这2组。但是数据卡片之间是且的关系，即同时满足这几个数据卡片条件的结果。
6. 数据卡片必须抽象为 Search 与 Shiori 可复用的筛选组件，布局不得假设数据卡片数量固定为 4。后续可以增加内置数据卡片和用户自定义数据卡片；本版本只实现 Duration、Character、Language、Watch Status 四张数据卡片。
7. 旧的筛选的相关功能及代码，不用了可以删除
8. 重启App后Search页面时默认显示筛选数据面板，默认全部选择，且选择需要持久化。重启App后Shiori二级页面时默认不显示筛选数据面板，默认全部选择，且选择需要持久化。持久化，Search和Shiori的不同，每个Shiori二级页面也不同。Command Panel界面的Search那里先维持现状（即按照现在的临时空Filter处理，后续会在界面里支持筛选条件，放到搜索结果列表左侧替代现在的封面），后续再支持，先处理Workbench这里的代码。
9. exact结果出来之前，输入搜索词以后，数据卡片的数字都要显示Calculating，且disable所有选项，禁止修改。
10.搜索条件一，Duration，选择时钟图标，4个选项：<1s，1~2.999s，3~4.999s，≥5s。
11.搜索条件二：Character，选择T的图标，4个选项：1-10，11-20，21-30，31+。
12.搜索条件三：Language，选择地球图标，选项：以及数据库当前所有包含的语言。只需要列出单个语言，如果一个字幕被认为是多语言的，那么可以会被算在多个语言中。换言之，所有选项数字之和可能会大于字幕数量总和。
13. 搜索条件四：Watch Status，选择眼球图标，3个选项：Finished，Watching，Unwatched。
14. Filter按钮处，不再显示数字。
15. Language/Watch Status 卡片取代现有全局语言与观看范围设置。
16. 数据卡片数字是始终表示搜索词命中的完整分布。

# 修改流程

## Step 1：修正数据卡片筛选语义

定义 Duration、Character、Language、Watch Status 四类筛选项：

- 数据卡片中不存在 `All` 选项，只显示实际分类选项。
- 没有已保存状态时，每张卡片默认选中全部可用选项。
- 选中全部选项等于该卡片不限制结果。
- 卡片内多个选项之间为 OR。
- 卡片之间为 AND。
- 一张卡片没有选中任何选项时，筛选结果为 0。
- 新出现的可用选项默认选中；已经不存在的选项不参与筛选。
- Language 仅列出数据库包含的单个语言及 Unknown；多语言 Cue 可同时归入多个 Language 类别，因此各语言计数之和可能大于 Cue 总数。
- Watch Status 直接读取观看状态，不读取观看进度。
- 不再计算启用筛选条件的数据卡片数量。

验收：

- 纯逻辑测试覆盖全选、部分选择、单选、多选和全部取消。
- 卡片内 OR、卡片间 AND 正确。
- 全选不限制结果，全部取消返回 0 条结果。
- 不涉及 UI。

## Step 2：建立索引阶段的分布缓存

- index 阶段生成 Duration、Character、Language 的分类与汇总缓存。
- 索引增删改时同步更新。
- Watch Status 在索引关系变化或观看状态变化时更新。
- 空搜索词只读取缓存，不扫描 Cue 表。

验收：

- 缓存数量与数据库直接统计一致。
- 打开 Search 空页面不触发全 Cue 扫描。
- 修改观看状态只更新 Watch Status 分布。

## Step 3：让 Search exact 产出完整分布快照

每次输入搜索词时：

- exact 搜索覆盖完整结果域。
- 同步生成四类分布计数和每条结果的紧凑分类值。
- exact 完成前数据卡片显示 `Calculating`，所有选项 Disabled，禁止修改。
- 新查询立即废弃旧查询的分布快照。

验收：

- exact 数量、结果 ID、分布数量来自同一 generation。
- 旧查询结果不能覆盖新查询。
- 不增加第二次全量搜索。

## Step 4：实现内存筛选投影

- 筛选只作用于完整结果快照。
- 保留原始搜索排序。
- 点击筛选选项不访问数据库、不执行 FTS、不创建新的 exact task。
- 只替换表格使用的有序结果 ID 投影。
- 数据卡片数字始终表示搜索词命中的完整分布，不随当前筛选选择变化。

验收：

- 卡片内 OR、卡片间 AND 正确。
- 全选、部分选择、单选、多选和全部取消正确。
- 筛选前后排序不变。
- Filter 操作不触发数据库搜索。
- 在当前完整数据库规模下进行性能测试；若结果不支持即时响应，停止并报告，不继续 UI 步骤。

## Step 5：实现 Search 三栏界面

界面调整为：

1. Toolbar
2. 筛选条件可视化数据面板
3. 结果表格

同时实现：

- Filter 按钮显示或隐藏筛选数据面板。
- Filter 按钮不显示数字或 Badge。
- 数据面板显示时，Filter 按钮使用当前弹出菜单打开时的外观。
- App 启动后，Search 筛选数据面板默认显示。
- Search 的筛选选择需要持久化。
- 没有已保存状态时，所有选项默认选中；存在已保存状态时恢复该状态。
- 数据面板的显示或隐藏状态不持久化。
- 数据面板使用基于容器可用宽度的自适应 Grid，不固定列数，也不与当前四张数据卡片绑定。
- Filter Data Card 最小宽度为 200px；卡片间距使用 `--spacing-3`。
- 列数按照可用宽度和 Filter Data Card 最小宽度自动计算，最少保持 2 列，允许 3 列及更多列。
- 末行允许不足当前列数，末行卡片保持与同一 Grid 其他卡片相同的列宽。
- 数据面板不使用横向滚动。
- 卡片高度由内容决定，不设置固定卡片高度或固定面板高度。
- 同一行的卡片统一使用该行自然内容高度最高卡片的高度；不同行分别计算高度。
- 删除 Search 中已被替代的旧 Filter Editor。
- 移除被 Language 和 Watch Status 数据卡片取代的全局设置入口。
- Command Panel 保持临时空 Filter，不接入本次筛选状态。
- Filter Data Card 使用 `--color-bg-surface`、`--color-border-control`、`--radius-control` 和 `--spacing-3`。
- Card Title 使用 `--font-size-control`、Font Weight `600` 和 `--color-text-secondary`。
- Card Title Icon 使用 `--size-checkbox` 和 `--color-text-secondary`。
- Option Label 使用 `--font-size-body` 和 `--color-text-muted`。
- Option Count 使用 `--font-size-caption` 和 `--color-text-muted`。
- Card Title Icon 与 Option Checkbox 占用相同宽度的 Leading Control Column，并保持水平中心线一致。
- Card Title 与 Option Label 从 Leading Control Column 后的同一水平位置开始。
- Option Count 在卡片尾部右对齐。
- Filter Data Card Checkbox 为圆形；Unchecked 使用 `--color-bg-checkbox-unchecked` 和 `--color-border-checkbox`，Checked 背景使用 `--color-text-muted`，Checkmark 使用 `--color-checkbox-icon`。
- Checkbox 与 Option Label 的间距使用 `--spacing-2`。
- Option 整行均为 Checkbox 的点击区域。
- Calculating 状态下 Count 显示 `Calculating`，全部 Option 为 Disabled，并遵守全局 Disabled 规则。

验收：
- App 最小窗口宽度下保持 2 列，卡片内容和表格均可正常使用。
- 中间窗口宽度允许出现 3 列；布局不能只处理 4 列和 2 列。
- 增加或删除数据卡片时，Grid 根据实际卡片数量和可用宽度自动重新排列。
- 同一行卡片等高，不同行分别按各自最高卡片确定高度。
- Filter Data Card 和 Filter Data Panel 的所有视觉数值均能对应到 UI.md 的 Token、Component 或 Layout 规则，不存在只保留在代码中的独立 UI 数值。
- 点击筛选选项不刷新 App Root、Sidebar、Shiori、Settings 或其他无关界面。
- 点击筛选选项只允许更新当前 Filter Data Panel 的选择状态、Search Result Count 和 Search 结果表格投影。
- 渐进投影的后续批次只刷新结果表格；数据卡片分布不重新计算。
- 使用 UI Invalidation Probe 覆盖上述刷新范围。
- 自动化测试验证默认状态、持久化恢复、筛选交互和面板显示状态。
- App 重启后 Search 数据面板默认显示。
- Filter 按钮没有数字或 Badge。
- **视觉验收由你执行。**
- 每项 UI 改动完成后，我按以下格式提供 `UI.md` 精确原文：


修改前

```md
原始内容
```

修改后

```md
建议替换内容
```

你验收后修改 `UI.md`，但暂不提交。

## Step 6：让 Shiori 接入相同的数据筛选能力

- Shiori 使用与 Search 相同的数据卡片定义和筛选算法。
- 数据范围限定为当前 Shiori List。
- Search 使用一份独立的持久化筛选状态。
- 每个 Shiori 二级页面分别保存自己的持久化筛选状态。
- Search 与 Shiori 状态互不影响。
- 不同 Shiori 二级页面之间的状态互不影响。
- 没有已保存状态时，当前 Shiori 二级页面的所有选项默认选中。
- Shiori 数据、列表内容或 Watch Status 变化时重建对应快照。
- 数据变化后，新出现的可用选项默认选中，已经不存在的选项不参与筛选。
- 本版本不增加 Shiori 专属数据卡片。

验收：

- 四类筛选结果与当前 Shiori List 数据一致。
- 切换 Shiori List 不会复用其他页面的筛选状态或分布快照。
- 重启 App 后能够按 Shiori 二级页面恢复筛选选择。
- Search 和 Shiori 状态互不影响。
- 不同 Shiori 二级页面之间的状态互不影响。

## Step 7：实现 Shiori 三栏界面

- 接入与 Search 共用的数据卡片组件和响应式布局。
- Shiori 完整复用 Step 5 定义的 Filter Data Card Component 和 Filter Data Panel Layout，不增加 Shiori 独立的尺寸、颜色、Checkbox 或响应式布局规则。
- Shiori 与 Search 只允许在默认显示状态、数据范围和持久化状态来源上存在差异。
- Filter 按钮显示或隐藏筛选数据面板。
- Filter 按钮不显示数字或 Badge。
- App 启动后，Shiori 二级页面的筛选数据面板默认隐藏。
- Shiori 数据面板的显示或隐藏状态不持久化。
- 打开数据面板时恢复当前 Shiori 二级页面持久化的筛选选择。
- 没有已保存状态时，所有选项默认选中。
- 删除 Shiori 中已被替代的旧 Filter Editor。
- 保持 Shiori 表格、选择、Tags、播放和列表行为不变。

验收：

- 自动化测试验证默认隐藏、按页面恢复选择和页面间状态隔离。
- App 重启后 Shiori 二级页面的数据面板默认隐藏。
- Filter 按钮没有数字或 Badge。
- 自动化回归通过。
- **视觉验收由你执行。**
- 每项 UI 改动完成后，同样提供 `UI.md` 修改前和修改后精确原文；验收后由你更新，但暂不提交。

## Step 8：清理旧路径并完成整体回归

仅删除已经没有调用方的：

- 旧 Filter Builder UI。
- 旧 Filter Rule 会话状态。
- 被新数据卡片替代的全局 Language 和 Watch Scope。
- 已被替代的数据卡片数量或 Badge 逻辑。
- 迁移后无用途的转换和测试代码。

保留仍被 Context 或 Command Panel 使用的路径，直到确认已有替代。

验收：

- Search、Shiori、Context、Playback、Command Panel、Select、复制和导出回归通过。
- Filter 操作没有数据库搜索。
- 空搜索词没有全 Cue 扫描。
- Search 与各 Shiori 二级页面的持久化状态相互隔离。
- 完整测试通过后才进入下一步。

## Step 9：最终同步并提交 UI.md

全部功能与视觉步骤验收完成后：

- 汇总并复核所有 `UI.md` 修改前和修改后内容。
- 你确认 `UI.md` 已准确记录最终稳定结果。
- 此时才提交 `UI.md`，避免中途方案反复污染历史。
- 完成最终需求验收和实现记录。
- UI.md 必须覆盖本需求最终接受的全部可见 UI 数值、Token、Component、状态、交互和 Layout。
- 不允许任何已接受的 UI 数值或规则只存在于 SwiftUI 代码、工程记录或需求单中。
- UI.md 与最终实现逐项核对完成后才能提交 UI.md。