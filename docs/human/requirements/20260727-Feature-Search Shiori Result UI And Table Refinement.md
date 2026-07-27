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
