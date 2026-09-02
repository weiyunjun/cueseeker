# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Menu、Submenu、Menu Item、Search / Shiori Table Layout）
- `docs/human/design/UI Application Rules.md`（界面层级、菜单模态、Hover 与选中、按下、指针）
- `docs/human/design/Toast Usage Registry.md`（Shiori 相关）

# 需求描述

## 1. 目标

Workbench Search 表格的行右键菜单增加 `Save to Shiori ...`，通过二级菜单选择目标 Shiori 列表，直接收藏该行的主 Cue。同时纠正 Shiori 被译为「栞」的既有缺陷。

## 2. 菜单项

1. 位置在 `Open Subtitle Folder` 之下，与 `Play`、`Open Subtitle Folder` 同一分组；其后的分隔线与复制类项目位置不变。
2. Leading Icon 与 `Move to ...`、`Duplicate to ...` 相同，为右箭头。
3. 文案为 `Save to Shiori ...`，带省略号，与另外两个二级菜单触发项一致。
4. 只出现在 Search 表格；Shiori 表格的右键菜单不变。
5. 行失效或身份无法确认时该项禁用，禁用条件与 `Move to ...`、`Duplicate to ...` 一致。
6. 作用对象为右键点中的那一行，不跟随多选；Select Mode 下不弹出行右键菜单的现有行为不变。

## 3. 二级菜单

1. 使用现有的 Shiori Destination Submenu：全部 Shiori 列表依次排列，末尾为分隔线与 `New List`。
2. 列表顺序按创建时间正序，与 Shiori 一级界面卡片顺序一致。
3. 与 `Move to ...`、`Duplicate to ...` 不同，此处不排除任何列表，Search 没有当前列表的概念。
4. 展开、收起、Safe Area、键盘方向键等交互沿用现有二级菜单通用规则，不作任何改动。
5. `New List` 的行为沿用 `20260829-UI-Shiori FIFO Ordering And New List Destination.md` 第 3 节：菜单一并关闭并打开新建列表界面；取消则不写入；创建成功后立即以新列表为目标执行本次保存；新列表无论成败都保留；创建后停留在当前界面。

## 4. 写入语义

1. 保存该行的主 Cue，不保存 Cue Group 中的其余字幕。
2. 目标列表已存在同一 CueID 时不重复写入。
3. 新收藏按收藏时间排在目标列表表格最下方，沿用现有正序规则。
4. Search 表格不显示是否已收藏的任何标记。

## 5. 提示

| 场景 | 处理 |
| --- | --- |
| 保存成功 | 新增场景 `shiori.save.succeeded`，文案 `Saved to “{List Name}”` |
| 非目标消失原因导致保存失败 | 新增场景 `shiori.save.failed`，文案 `Couldn’t save Shiori. Try again` |
| 目标列表已含同一 CueID | 复用现有场景 `shiori.destination.cue.already_exists` |
| 执行时目标列表已不存在 | 复用现有场景 `shiori.destination.unavailable` |

两个新增场景的持续时间 5 秒、出现位置 App Center、动画 Default，与现有 Shiori 场景一致。

## 6. 文案

| 用途 | English | 简体 | 繁体 |
| --- | --- | --- | --- |
| 行菜单项 | Save to Shiori ... | 保存到 Shiori… | 儲存到 Shiori⋯ |
| 保存成功 Toast | Saved to “{list}” | 已保存到“{list}” | 已儲存至「{list}」 |
| 保存失败 Toast | Couldn’t save Shiori. Try again | 无法保存 Shiori，请重试 | 無法儲存 Shiori，請重試 |

## 7. 纠正 Shiori 误译

1. `20260822-Feature-Simplified And Traditional Chinese Localization.md` 第 7 条规定 Shiori 保持英文不翻译，播放页页脚的 `Save to Shiori` 实现为「保存到栞 / 儲存到栞」，违反该规定。
2. 简体改为「保存到 Shiori」，繁体改为「儲存到 Shiori」。
3. 界面行为、键位与位置不变，仅改文案。

## 8. 实现约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. 二级菜单复用现有的 Shiori Destination Submenu 实现，禁止为 Search 单独实现一份。
3. 本次不改动 Search 的 Selection Action Overlay，不新增批量保存。
4. 本次不改动播放页与 Command Panel 的 `Save to Shiori`（存入第一个列表、无二级菜单）行为。

## 9. 设计文档同步

本需求验收通过后再更新设计文档：

1. `UI Design System.md` 的 Menu / Context Menu 变体下新增行右键菜单的项目清单，分别写明 Search 与 Shiori 两个表格的菜单项、顺序与分组。
2. `UI Design System.md` 的 Shiori Destination Submenu 补充：是否排除当前列表由触发项决定，Search 的 `Save to Shiori ...` 不排除任何列表。
3. `UI Design System.md` 的 Playback Footer Layout 中「栞数」改为「Shiori 数」。
4. `Toast Usage Registry.md` 新增上述两条场景。

# 验收

1. Search 表格右键菜单从上到下为 Play、Open Subtitle Folder、Save to Shiori ...、分隔线、复制类项目；Shiori 表格菜单不变。
2. `Save to Shiori ...` 的图标为右箭头，文案带省略号。
3. 二级菜单显示全部 Shiori 列表，按创建时间正序，末尾为分隔线加 New List；只有一个列表时也不排除它。
4. 二级菜单的展开、收起、Safe Area 与键盘方向键行为与 `Move to ...` 完全一致。
5. 选择列表后该行主 Cue 出现在目标列表表格最下方，出现 `Saved to “{list}”` 提示。
6. 重复保存同一行到同一列表时不新增记录，出现已存在提示。
7. 选择 New List 创建成功后，该行被保存进新列表并出现成功提示；取消则无任何写入。
8. 失效行的 `Save to Shiori ...` 为禁用。
9. Cue Group 展开时只保存主 Cue，不保存整组。
10. 播放页页脚与三处界面不再出现「栞」字。
11. 三种语言分别核对；Light 与 Dark 两个主题分别核对。
12. 现有自动化端到端与单元用例全部通过。