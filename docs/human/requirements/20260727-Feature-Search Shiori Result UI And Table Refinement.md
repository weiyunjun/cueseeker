# 版本
main

# 需求描述

1. 现在的Search和Shiori二级界面，整体太挤压了，需要把2侧的空隙增加。直接结果就是搜索框宽度减少，表格宽度减少（还有其它布局变化，我只描述最明显的，用于对齐）
2. 去掉表格的外部框线，保留横线，横线的长度仍然等于表格的宽度
3. 默认不显示checkbox，但是会通过批量按钮，进入Select状态时显示，下面说
4. 去掉第二栏，即不显示xx rows或xx shioris。前者在哪里显示下面会说，后者会随着Shiori二级界面大改而显示出来
5. 去掉+New Filter Set。Filter Sets改名为Filter，图标不变。取消可命名、可复用、全局保存的 Filter Set；分别独立保留 Search 与 Shiori 当前会话内的筛选状态，重启后不恢复。
6. 点击Filter，弹出现在+New Filter Set的界面，但是移除Save Filter Set按钮。
7. Filter按钮，如果存在至少一个筛选时，会在Filter右侧显示筛选数字。筛选数字，是那种两侧都是半圆的，只有1位数时视觉上是圆形，有2位数或更多时是一个胶囊形的样式。Light Mode下背景色可以是黑色或灰色，字体颜色是白色（这里背景色和字体颜色，以及Dark Mode下的颜色你根据现有设计规范调整）
8. 第一栏，从左到右显示：搜索框，Filter按钮，View按钮，Select按钮
9. Select按钮，点击以后，会显示表头和表格的checkbox，如果有任意checkbox被选中，在表格底部中间区域显示一个按钮集合栏，包括：xx selected，Anki按钮，Screenshot按钮，Collage按钮，Copy Table按钮。这些集合栏需要有一个不透明背景，作为overlay悬浮在表格上。checkbox区域，就算没有选中的时候，也要留出来，不要因为Select，造成表格压缩。
10. Select按钮，图标用笔写字的那种编辑图标，进入选择状态以后，名称改为Exit Select。在选择状态下，禁用表格的大部分功能。点击某一行任意区域都可以选中该行，禁用播放字幕，禁用右键菜单，禁用搜索框编辑，禁用Filter和View按钮，禁用表头的按钮，禁用hover到字幕时的下划线效果（表明不可点击），禁用选择文字功能。只能滚动表格，使用滚动条，选择结果或取消结果，和底部Overlay区域交互，以及退出Select状态。
11. 将Cues列和Display Title列，位置互换，列宽计算公式不变。
12. 搜索的时候，等exact结果完全出来以后，在搜索框的X按钮左边，显示一个颜色均为muted的xx results的内容（处理1 result的单数情况）。
13. 当且仅当exact计算完毕，才可以进入Select状态。
14. 表格区域，除了Primary Cue，其它列的内容都改为muted颜色。表头的颜色改为secondary。
15. 取消hover Cues时的背景色变化效果，保留下划线效果。hover行时拥有和hover Cues现在的背景色变化效果。在Select状态，选中某一行以后有更深的背景色变化效果。但是hover已经selected的行，背景色不会叠加。
16. 非Select状态时，checkbox位置显示#列，即当前Search或Shiori结果的序号，它是动态的，仅反映在列表中的实际位置。表头沿用secondary颜色，表格内容沿用muted颜色。#列作为动态序号，且和非Select状态绑定，类似checkbox，不出现在View按钮的列表中。

# 实施步骤

## Step 1：增加页面水平留白
对应条目：1

## Step 2：移除表格外框
对应条目：2

## Step 3：取消 Filter Set，改为会话内 Filter
对应条目：5、6

## Step 4：增加 Filter Count Badge
对应条目：7

## Step 5：调整表格列顺序与文字层级
对应条目：11、14

## Step 6：调整普通模式 Hover
对应条目：15（普通模式部分）

## Step 7：实现 Select 模式核心交互
对应条目：3、9（Selection Column 部分）、10、13、15（Selected 部分）

## Step 8：合并工具栏并增加底部 Action Overlay
对应条目：4、8、9（Action Overlay 部分）、12、16

## Step 9：最终回归与文档汇总
对应条目：1–16

# UI文档改动

- Core Tokens：
  - 增加 Filter Count Badge 的字号、尺寸、水平内边距、圆角和垂直偏移 Token。
  - Filter Count Badge 颜色复用现有 `--color-text-muted` 和 `--color-checkbox-icon`。
  - 删除不再使用的 `--height-table-utility-bar`。

- 全局交互规则：
  - Table Row 作为整行 Hover 和 Selected 视觉的显式例外。
  - 明确表格文字选择仅适用于普通模式；Select 状态下禁用文字选择。

- Search Box：
  - 增加可选 Result Count Text。
  - 仅在 Search exact 结果完整计算后显示。
  - 使用 muted 颜色，位于 Inline Clear Button 左侧。
  - 支持 `1 result` 与 `{N} results`，Shiori 不显示结果数量。

- Filter：
  - 删除 Filter Sets 相关术语。
  - 将 Filter Panel Trigger Button 更新为中性样式的 Filter Button。
  - 增加 Filter Count Badge 的组成、Token、颜色、尺寸和显示规则。
  - Filter Rule Count 为 `0` 时不显示 Badge。
  - 一位数显示为圆形，两位数或更多显示为胶囊形。
  - 删除 Active Accent 和 Trailing Clear 规则。
  - Filter Editor 不提供命名、复用、全局保存或 `Save Filter Set`。
  - Search 与 Shiori 分别保留独立的当前会话筛选状态，App 重启后不恢复。
  - 打开 Filter Editor 时不自动创建规则。
  - 删除最后一条规则后回到 `0` 条规则。

- Search / Shiori Toolbar：
  - 合并为单行 Toolbar。
  - 顺序调整为 `Search Box → Filter → View → Select / Exit Select`。
  - Toolbar 与 Table Viewport 使用 `--spacing-8` 作为左右页面留白，并保持边界对齐。
  - Select 使用 `square.and.pencil`。
  - 进入 Select 状态后显示 `Exit Select`。
  - Search 只有在 exact 结果完整计算后才能进入 Select 状态。
  - 删除独立结果数量栏和 Shiori 数量栏。

- Table 外观：
  - 删除表格外部框线和垂直列分隔线。
  - 仅保留长度等于 Table Content Width 的水平 Row Divider。
  - Header 文字统一使用 `--color-text-secondary`。
  - Cues 与 Display Title 调换位置，保留原列宽权重和最小宽度。
  - Primary Cue 使用 secondary，Extra Cues 和其它数据列内容使用 muted。
  - Interactive Text Cell Hover 不再绘制独立背景，只保留文字色变化和下划线。
  - 普通模式下整行 Hover 使用 `--color-row-hover`。

- Selection Column：
  - 始终保留固定 `50pt` 宽度，不因进入或退出 Select 状态改变其它列宽。
  - 非 Select 状态下，Header 显示 `#`，正文显示从 `1` 开始的动态结果序号。
  - `#` 使用 secondary，正文序号使用 muted。
  - Select 状态下原位切换为 Header 和 Row Checkbox。
  - Selection Column 不出现在 View Menu 中。

- Select 状态：
  - Search Box、Filter、View、Sortable Header Cell 和其它 Header Button 为 Disabled。
  - 点击正文行任意非 Overlay、非 Scrollbar 区域切换该行的选择状态。
  - 禁用 Cue 播放、Shiori Tags Cell 编辑、Row Action Menu、Interactive Text Cell Hover 下划线和表格文字选择。
  - 只允许滚动表格、拖动 Scrollbar、选择或取消结果、操作 Selection Action Overlay，以及退出 Select 状态。
  - 已选择行使用 `--color-row-selected`。
  - Hover 未选择行使用 `--color-row-hover`。
  - Hover 已选择行时不叠加 Hover 背景。

- Selection Action Overlay：
  - 替代原 Count Summary 和 Batch Actions 区域。
  - Checkbox Selected Count 大于 `0` 时显示在表格底部中央。
  - 使用完全不透明的 `--color-bg-popover`，并复用现有边框、圆角、间距和阴影 Token。
  - 内容顺序为 `{N} selected → Anki → Screenshot → Collage → Copy Table`。
  - 清空选择后隐藏。