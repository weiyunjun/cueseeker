# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Selection Action Overlay、Selection Action Overlay Layout、Search / Excerpt Toolbar Layout、Checkbox、Icon Button）

# 需求描述

## 1. 目标

窗口较窄时进入 Select Mode，页面会被 Selection Action Overlay 撑宽，把搜索框、筛选与 Select 按钮挤出窗口。本需求修正这一问题，并调整 Overlay 的排版、计数文案与 Select 的可用条件。Search 页与 Excerpt List 详情页同样适用。

## 2. Overlay 排版

1. Selected Count 在上，Action Slots 在下，上下排列，内容左对齐。
2. Overlay 宽度由内容决定，但不超过表格可见宽度；页面宽度不受 Overlay 影响。
3. 宽度不足时 Action Slots 换行排列，按钮文字不截断。
4. Selected Count 与 Action Slots 之间、Action Slots 换行后的行与行之间，间距均为 `--spacing-2`。

## 3. 计数文案

1. 改为「已选取 xx / yy 行」：xx 为已选行数，yy 为当前结果中可选取的行数。
2. 简体 `已选取 %d / %d 行`，繁体 `已選取 %d / %d 行`，英文 `%d / %d rows selected`。

## 4. 失效行

1. 失效行不可选取：其 Table Selection Checkbox 使用 Disabled 状态，点击该行不改变勾选。
2. 表头全选只选取可选行；表头的全选与部分选中状态按可选行计算。
3. Shift 区间选中跳过失效行。

## 5. Select 可用性

1. 当前结果中没有可选行时（0 行，或 Excerpt List 全部为失效行），Select Mode Action 为 Disabled。

## 6. 不变的部分

1. Overlay 的锚点、表面、内距、操作项、快捷键与行为保持现状。
2. Select Mode 下搜索框与筛选禁用、结果重新加载时自动退出 Select Mode、结果计算中 Select 禁用，保持现状。

## 7. 设计文档同步

验收通过后更新 `UI Design System.md` 中上述相关章节。

# 验收

1. 窗口为最小宽度时，在 Search 页与 Excerpt List 详情页进入 Select Mode，页面宽度不变，搜索框、筛选与 Select 按钮仍在窗口内。
2. Overlay 计数在上、按钮在下；宽度不足时按钮换行，文字完整不截断。
3. 勾选、取消与全选时，计数中的 xx 随之变化，yy 等于当前结果中可选取的行数。
4. 含失效行的 Excerpt List 中，失效行的勾选框为禁用外观，点击不被勾选，全选与 Shift 区间选中都不包含失效行。
5. 搜索结果为 0 行时 Select 禁用；Excerpt List 全部为失效行时 Select 禁用。
6. 简体、繁体、英文各核对一遍，全部不溢出、不截断。
7. 现有自动化端到端与单元用例全部通过。