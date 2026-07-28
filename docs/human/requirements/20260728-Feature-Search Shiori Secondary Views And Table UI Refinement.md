# 版本
main

# 需求描述
1. 准备修改Search及Shiori界面。如图所示，将现在的2栏改造为3栏：搜索框及其他按钮，筛选条件可视化数据面板，结果表格
2. 可以点击Filter按钮，显示/隐藏筛选条件可视化数据面板。当显示时，Filter按钮的外观和当前弹出菜单时Filter按钮的外观一致。
3. 所有筛选条件，都可以多选。
4. 每次搜索都要进行全量搜索，保证数据面板可以显示正确的数据，这里本质上是一种数据范畴分布的显示。
5. 数据卡片内部多选默认是或的关系，例如选1~3s和3~5s其实就是同时选择这2组。但是数据卡片之间是且的关系，即同时满足这几个数据卡片条件的结果。不选任何选项在数据筛选上也处理为全选。一旦勾选任何一个选项，就代表进入筛选了。全部勾选同样是全部选择。
6. 数据卡片必须抽象为 Search 与 Shiori 可复用的筛选组件，布局不得假设数据卡片数量固定为 4。后续可以增加内置数据卡片和用户自定义数据卡片；本版本只实现 Duration、Character、Language、Watch Status 四张数据卡片。
7. 旧的筛选的相关功能及代码，不用了可以删除
8. 重启App后Search页面时默认显示筛选数据面板，默认不选任何选项，且选择需要持久化。重启App后Shiori二级页面时默认不显示筛选数据面板，默认不选任何选项，且选择需要持久化。持久化，Search和Shiori的不同，每个Shiori二级页面也不同。Command Panel界面的Search那里先维持现状（即按照现在的临时空Filter处理，后续会在界面里支持筛选条件，放到搜索结果列表左侧替代现在的封面），后续再支持，先处理Workbench这里的代码。
9. exact结果出来之前，输入搜索词以后，数据卡片的数字都要显示Calculating。所有选项禁止交互和修改，但保持原有Checked或Unchecked视觉，不显示Disabled视觉。
10.搜索条件一，Duration，选择时钟图标，4个选项：<1s，1~2.999s，3~4.999s，≥5s。
11.搜索条件二：Character，选择T的图标，4个选项：1-10，11-20，21-30，31+。
12.搜索条件三：Language，选择地球图标，选项：以及数据库当前所有包含的语言。只需要列出单个语言，如果一个字幕被认为是多语言的，那么可以会被算在多个语言中。换言之，所有选项数字之和可能会大于字幕数量总和。
13. 搜索条件四：Watch Status，选择眼球图标，3个选项：Finished，Watching，Unwatched。
14. Filter按钮处，不再显示数字。
15. Language/Watch Status 卡片取代现有全局语言与观看范围设置。
16. 数据卡片数字，采用disjunctive facet算法，代表在不包含本组筛选且应用其他组筛选的情况下，本组的各个选项对应的数字。
17. Search界面空搜索词时，未产生真实搜索结果，故所有选项的数字都显示0。

# 修改流程

## Step 1：修正数据卡片筛选语义

定义 Duration、Character、Language、Watch Status 四类筛选项：

- 数据卡片中不存在 `All` 选项，只显示实际分类选项。
- 没有已保存状态时，每张卡片默认不选中任何选项。
- 没有选中任何选项时，该卡片不限制结果。
- 选中全部选项时，该卡片同样不限制结果。
- 勾选一个或多个但未覆盖全部可用选项时，该卡片只保留被勾选的分类。
- 卡片内多个选项之间为 OR。
- 卡片之间为 AND。
- 新出现的可用选项默认不选中；已经不存在的选项不参与筛选。
- Language 仅列出数据库包含的单个语言及 Unknown；多语言 Cue 可同时归入多个 Language 类别，因此各语言计数之和可能大于 Cue 总数。
- Watch Status 直接读取观看状态，不读取观看进度。
- 不再计算启用筛选条件的数据卡片数量。

Step 1 验收：筛选语义通过自动化测试。

## Step 2：建立索引阶段的分布缓存

- index 阶段生成 Duration、Character、Language 的分类与汇总缓存。
- 索引增删改时同步更新。
- Watch Status 在索引关系变化或观看状态变化时更新。
- Search 空搜索词时仅使用缓存确定当前可用的 Language Option；所有 Option Count 固定显示 `0`，不扫描 Cue 表。

Step 2 验收：缓存中的可用 Language 正确，空搜索词不扫描 Cue 表且所有 Option Count 为 `0`。

## Step 3：让 Search exact 产出完整分布快照

每次输入搜索词时：

- exact 搜索覆盖完整结果域。
- 同步生成四类分布计数和每条结果的紧凑分类值。
- exact 完成前数据卡片的 Count 显示 `Calculating`。所有选项禁止交互和修改，但保持原有 Checked 或 Unchecked 视觉，不使用 Disabled Token。
- 新查询立即废弃旧查询的分布快照。

Step 3 验收：搜索结果与分布快照属于同一 generation，且不增加第二次全量搜索。

## Step 4：实现内存筛选投影

- 筛选只作用于完整结果快照。
- 保留原始搜索排序。
- 点击筛选选项不访问数据库、不执行 FTS、不创建新的 exact task。
- 只替换表格使用的有序结果 ID 投影。
- Filter Data Card 的 Option Count 按 Step 8 定义的 disjunctive facet 规则计算。

Step 4 验收：筛选语义、排序、首屏响应和渐进加载通过验证，Filter 操作不访问数据库。

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
- 没有已保存状态时，所有选项默认不选中；存在已保存状态时恢复保存的勾选状态。
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
- Calculating 状态下 Count 显示 `Calculating`；全部 Option 禁止交互和修改，但保持原有 Checked 或 Unchecked 视觉，不显示 Disabled 视觉。
- Select 状态下全部 Option 为 Disabled，遵守全局 Disabled 规则，禁止修改筛选条件。

Step 5 验收：功能自动化测试通过；视觉由你验收。视觉验收通过后提供 UI.md 修改前和修改后原文，但暂不提交。

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
- 没有已保存状态时，当前 Shiori 二级页面的所有选项默认不选中。
- Shiori 数据、列表内容或 Watch Status 变化时重建对应快照。
- 数据变化后，新出现的可用选项默认不选中，已经不存在的选项不参与筛选。
- 本版本不增加 Shiori 专属数据卡片。

Step 6 验收：Search、Shiori 及不同 Shiori 页面之间的数据范围和持久化状态正确隔离。

## Step 7：实现 Shiori 三栏界面

- 接入与 Search 共用的数据卡片组件和响应式布局。
- Shiori 完整复用 Step 5 定义的 Filter Data Card Component 和 Filter Data Panel Layout，不增加 Shiori 独立的尺寸、颜色、Checkbox 或响应式布局规则。
- Shiori 与 Search 只允许在默认显示状态、数据范围和持久化状态来源上存在差异。
- Filter 按钮显示或隐藏筛选数据面板。
- Filter 按钮不显示数字或 Badge。
- App 启动后，Shiori 二级页面的筛选数据面板默认隐藏。
- Shiori 数据面板的显示或隐藏状态不持久化。
- 打开数据面板时恢复当前 Shiori 二级页面持久化的筛选选择。
- 没有已保存状态时，所有选项默认不选中。
- 删除 Shiori 中已被替代的旧 Filter Editor。
- 保持 Shiori 表格、选择、Tags、播放和列表行为不变。

Step 7 验收：功能回归通过；视觉由你验收。视觉验收通过后提供 UI.md 修改前和修改后原文，但暂不提交。

## Step 8：实现 disjunctive facet 计数

- 非空 Search 基于当前 exact 结果快照计算。
- Shiori 基于当前 Shiori List 的完整快照计算。
- 计算某张 Filter Data Card 的 Option Count 时，忽略该卡片自身的选择，只应用其他 Filter Data Card 的选择。
- 结果表格和 Result Count Text 继续应用全部 Filter Data Card 的选择。
- 同一次完整快照扫描同时生成有序结果投影、Result Count 和四张 Filter Data Card 的 disjunctive Option Count，不为每张卡片分别扫描。
- 首屏结果继续优先发布，剩余结果和 disjunctive Option Count 使用现有渐进任务完成。
- 点击筛选选项不访问数据库、不执行 FTS、不创建新的 exact task。
- Query 或筛选选择变化时废弃旧 generation 的结果投影和 disjunctive Option Count。
- Search 空搜索词时不执行 disjunctive facet 计算，所有 Option Count 固定显示 `0`。

Step 8 验收：disjunctive Option Count 和完整筛选结果正确；使用查询词 `の` 验证首屏返回及后续渐进加载没有明显回归，Filter 操作不访问数据库。

## Step 9：清理旧路径并完成整体回归

仅删除已经没有调用方的：

- 旧 Filter Builder UI。
- 旧 Filter Rule 会话状态。
- 被新数据卡片替代的全局 Language 和 Watch Scope。
- 已被替代的数据卡片数量或 Badge 逻辑。
- 迁移后无用途的转换和测试代码。

保留仍被 Context 或 Command Panel 使用的路径，直到确认已有替代。

Step 9 验收：完整自动化测试及 Search、Shiori、Context、Playback、Command Panel、Select、复制和导出回归通过。

## Step 10：最终同步并提交 UI.md

Step 10 验收：最终实现与 UI.md 一致，提交 UI.md 并完成整个需求验收。
