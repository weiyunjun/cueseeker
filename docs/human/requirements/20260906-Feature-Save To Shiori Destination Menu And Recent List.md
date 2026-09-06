# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Shortcut Action Button、Menu、Shiori Destination Submenu、Playback Footer Layout）
- `docs/human/design/UI Application Rules.md`（菜单模态、Hover 与选中）
- `docs/human/design/Toast Usage Registry.md`（Shiori 相关）

# 需求描述

## 1. 目标

页脚出现 `Save to Shiori` `S` 的界面，不再直接存入第一个列表，改为弹出目标列表菜单由用户选择。同时引入「最近保存 Shiori List」，作为三处 Save to Shiori 菜单的默认高亮项。

## 2. 生效范围

1. 触发方式：按 `S`，或点击页脚的 `Save to Shiori` 按钮，两者行为完全一致。
2. 生效界面：Playback Overlay 与 Command Panel 中页脚带 `Save to Shiori` `S` 的界面。
3. Workbench Search 表格行菜单的 `Save to Shiori ...` 结构与行为不变，仅适用本需求第 5 节的默认高亮。

## 3. 菜单

1. 内容与顺序沿用现有 Shiori Destination Submenu：全部 Shiori 列表按创建时间正序，末尾为分隔线与 `New List`，不排除任何列表。
2. 挂靠页脚的 `Save to Shiori` 按钮，方向、高度、最大高度与滚动条沿用现有菜单通用规则。
3. 菜单打开期间，`Save to Shiori` 按钮进入 Open 外观，与其 Hover 外观完全相同，按钮内的 Keycap 一并切换到 Hover。

## 4. 菜单打开期间的输入

1. 四个方向键、回车与 Esc 归菜单，沿用菜单模态既有规则。
2. `C` 与 `X` 照常执行 Copy Cue Text 与 Copy Deep Link，执行后菜单保持打开，不作额外屏蔽。
3. 再次按 `S` 或再次点击 `Save to Shiori` 按钮关闭菜单。
4. 滚动处理为整窗口禁止，与除视频播放倍速菜单外的其它菜单一致。

## 5. 默认高亮

1. 最近保存 Shiori List 存在时，菜单打开默认高亮该列表；不存在时默认高亮第一项。
2. 该规则适用于三处 `Save to Shiori` 菜单，不适用于 `Move to ...` 与 `Duplicate to ...`。

## 6. 最近保存 Shiori List

1. 定义：通过 Search、Playback Overlay、Command Panel 三处的 `Save to Shiori` 保存成功的那个列表。
2. 只记录列表本身，不记录名称；列表改名不影响，菜单显示新名称，默认高亮不变。
3. 目标列表已含同一 Cue 而未写入时不算保存成功，不更新该记录。
4. `Move to ...` 与 `Duplicate to ...` 不更新该记录。
5. 选择 `New List` 并保存成功后，记录为新建的那个列表。
6. 该记录跨 App 重启保留。
7. 打开菜单时发现记录的列表已不存在，则清除该记录并按第一项高亮，直到下一次保存成功重新记录；删除后新建的同名列表不视为同一个列表。
8. 所有列表都不存在时，菜单只有 `New List`，不存在默认高亮的列表。

## 7. 选择后的行为

1. 选择某个列表或选择 `New List`，菜单都立即关闭，三处一致。
2. `New List` 沿用 `20260829-UI-Shiori FIFO Ordering And New List Destination.md` 第 3 节：打开新建列表界面，取消则不写入，创建成功后立即以新列表为目标执行本次保存，新列表无论成败都保留，创建后停留在当前界面。
3. 写入语义沿用现有保存规则：目标列表已存在同一 CueID 时不重复写入；新收藏排在目标列表表格最下方。
4. 当前字幕本身已是某个列表中的收藏时，照常打开菜单，允许保存到其它列表；取消现有的直接提示「已保存」而不弹出菜单的行为。

## 8. 提示

1. Search 行菜单的保存结果沿用现有 Toast，位置与持续时间不变。
2. Playback Overlay 与 Command Panel 的保存结果改用播放页反馈，这两处不出 Toast。容器沿用现有的播放页反馈，图标为实心书签，四种结果一致；持续时间维持现有的 1 秒，时长调整留待后续需求。
3. 四种结果都带目标列表名：保存成功、目标列表已含同一 Cue、保存失败、目标列表已不存在。
4. 「目标列表已不存在」使用菜单打开时快照中的列表名。
5. 保存失败与目标列表已不存在两条文案补上列表名，Toast 与播放页反馈共用同一句话：

| 用途 | English | 简体 | 繁体 |
| --- | --- | --- | --- |
| 保存失败 | Couldn’t save to “{list}”. Try again | 无法保存到“{list}”，请重试 | 無法儲存至「{list}」，請重試 |
| 目标列表已不存在 | “{list}” is no longer available | “{list}”已不存在 | 「{list}」已不存在 |

6. 保存成功与目标列表已含同一 Cue 沿用现有文案，不作改动。

## 9. 作废条款

1. 作废 `20260829-UI-Shiori FIFO Ordering And New List Destination.md` 第 1.4 条中「从播放页收藏字幕时的默认目标列表为第一个列表」。
2. 作废 `20260902-Feature-Search Row Menu Save To Shiori.md` 第 8.4 条「本次不改动播放页与 Command Panel 的 Save to Shiori」。

## 10. 实现约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. 菜单复用现有菜单外壳、定位、模态、高亮与滚动条实现，禁止新建一套菜单基础设施。

## 11. 设计文档同步

本需求验收通过后再更新设计文档：

1. `UI Design System.md` 的 Shortcut Action Button 增加 Open 状态，背景与 Hover 相同，Keycap 一并切换到 Hover。
2. `UI Design System.md` 的 Menu / States / Open 补充：由 `Save to Shiori` 打开时默认高亮最近保存的列表，没有则高亮首项。
3. `UI Design System.md` 的 Shiori Destination Submenu 补充：该结构也可由页脚的 `Save to Shiori` 按钮直接弹出。
4. `UI Design System.md` 的 Playback Footer Layout 注明 `Save to Shiori` `S` 打开目标列表菜单，不直接保存。
5. `UI Application Rules.md` 菜单模态第 6 条表格增加 `Save to Shiori 菜单`，滚动为整窗口禁止。
6. `Toast Usage Registry.md` 的 `shiori.save.failed` 与 `shiori.destination.unavailable` 文案改为带列表名。
7. `UI Design System.md` 的 Playback Feedback 补充：Playback Overlay 与 Command Panel 的 Shiori 保存结果由它呈现，图标为实心书签。

# 验收

1. Playback Current、Playback Playlist 的字幕列表、Command Panel Search Results 中，按 `S` 与点击按钮都弹出目标列表菜单，不再直接保存。
2. 菜单为全部列表按创建时间正序，末尾分隔线加 `New List`；列表多时菜单自身可滚动。
3. 菜单打开期间按钮为 Open 外观，与 Hover 完全一致。
4. 菜单打开期间：方向键、回车、Esc 归菜单；`C`、`X` 照常生效且菜单不关闭；再按 `S` 或再点按钮关闭菜单；指针在菜单外滚动时窗口内任何内容都不滚动。
5. 首次使用时默认高亮第一项；保存成功后再次打开，默认高亮上次保存的列表。
6. 在 Search 行菜单保存成功后，Playback Overlay 与 Command Panel 的菜单默认高亮同一个列表，反之亦然。
7. 重命名最近保存的列表后，菜单显示新名称，默认高亮仍在该列表。
8. 删除最近保存的列表后再打开菜单，默认高亮回到第一项；随后新建同名列表不会被重新认作最近保存。
9. 重启 App 后默认高亮仍为上次保存成功的列表。
10. 目标列表已含同一 Cue 时出现已存在提示且带列表名，默认高亮不变。
11. Search 行菜单的结果为 Toast；Playback Overlay 与 Command Panel 的结果为播放页反馈，图标为实心书签，这两处画面上不出现 Toast。
12. 四种结果都显示目标列表名；删除目标列表后立即在已打开的菜单里选中它，提示显示菜单打开时的那个名字。
13. 选择列表或选择 `New List` 后菜单立即关闭；`New List` 取消则无任何写入，创建成功则保存进新列表并成为最近保存。
14. 从 Shiori 进入播放、当前字幕已是收藏时，按 `S` 照常弹出菜单。
15. 三种语言分别核对；Light 与 Dark 两个主题分别核对。
16. 现有自动化端到端与单元用例全部通过。