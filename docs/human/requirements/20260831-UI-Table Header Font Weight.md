# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Table Header Cell）

# 关联需求

- `docs/human/requirements/20260830-UI-Neutral Text Ramp And Table Text Hierarchy.md`

# 需求描述

## 1. 列头字重

表格列头文字由 Regular 改为 Medium。上一单把列头降为 Regular 后，列头与内容列之间失去区分，层级不足。

字号与颜色不变，仍为 `--font-size-table-header` 与 `--color-text-muted`。所有列头一致，不因列而异。

## 2. 不变项

1. 表格内容各列字重不变：目标字幕 Medium，其余全部 Regular。
2. 列头的字号、颜色、高度、内边距、对齐与各状态不变。
3. Selection 变体的复选框列头不受影响。
4. 菜单、按钮、卡片等其它界面的字重不变。

# 验收

1. 列头字重为 Medium，视觉上重于 Display Title、Time Range 与 Date Added。
2. 各列头之间的字号、字重、颜色完全一致。
3. 表格内容除目标字幕外仍为 Regular。
4. Light 与 Dark 两个主题分别核对。
5. 现有自动化端到端与单元用例全部通过。
