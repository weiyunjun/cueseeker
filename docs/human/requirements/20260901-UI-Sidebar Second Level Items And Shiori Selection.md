# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Sidebar Item、App Sidebar Layout、Size）

# 需求描述

## 1. 标签构成

Sidebar 的导航项固定为六项，自上而下：Search、Recent、Recent Videos、Recent Shioris、Library、Shiori。其中 Recent Videos 与 Recent Shioris 为二级项，其余为一级项。

## 2. 移除展开收起

1. 移除 Recent 与 Shiori 的展开箭头，Sidebar Item 不再有 Trailing Indicator，也不再有 Expanded 与 Collapsed 状态。
2. Recent Videos 与 Recent Shioris 常驻显示，不可折叠。
3. `--size-app-sidebar-item-chevron` 随之无使用者，退役。

## 3. Shiori 不再列出列表

1. Shiori 项下不再显示任何 Shiori 列表名。
2. 承载列表名的滚动容器一并移除，Sidebar 的导航区不再滚动。
3. 进入具体 Shiori 列表的路径仍是 Shiori 总览界面，列表数据与打开方式不变。

## 4. 二级标签的图标

1. Recent Videos 使用 `film`，Recent Shioris 使用 `bookmark`。
2. 图标的尺寸与颜色规则与一级项的前置图标一致。
3. Sidebar Item / Child 的 Leading Icon 由 None 改为 Required。

## 5. 二级标签的缩进

1. 二级项前置图标的左边缘，与一级项标签的左边缘对齐。
2. 二级项图标与标签的间距，与一级项相同。

## 6. Shiori 一级项的选中态

1. 打开任一 Shiori 列表的二级界面时，Sidebar 的 Shiori 保持选中，与 Library 的处理一致。
2. Recent 的选中规则不变：选中 Recent Videos 或 Recent Shioris 时，Recent 不高亮。

## 7. 保持不变

1. Sidebar 的宽度、内外边距、项高度、圆角与项间距不变。
2. 二级项的标签字号、字重与选中样式不变。
3. Settings 项与 Sidebar Toggle 不变。
4. 各标签打开的界面内容不变。

# 验收

1. Sidebar 固定为六项，没有展开箭头，两个二级项常驻且无法折叠。
2. Shiori 下不再出现任何列表名，Sidebar 导航区不再出现滚动条。
3. Recent Videos 显示 `film` 图标，Recent Shioris 显示 `bookmark` 图标。
4. 二级项图标的左边缘与一级项标签的左边缘对齐，图标与标签的间距和一级项一致。
5. 打开任一 Shiori 列表的二级界面时，Sidebar 的 Shiori 保持选中。
6. 选中 Recent Videos 或 Recent Shioris 时，Recent 不高亮，与本需求前一致。
7. `--size-app-sidebar-item-chevron` 不再出现在设计系统与代码中。
8. Light 与 Dark 两个主题分别核对以上各项。
9. 本次改动不新增任何自动化端到端或单元用例的失败。