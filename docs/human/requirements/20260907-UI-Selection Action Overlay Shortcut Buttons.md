# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Selection Action Overlay、Selection Action Overlay Layout、Shortcut Action Button、Keycap、Button / Neutral）
- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽、菜单模态、按下）

# 需求描述

## 1. 范围

Workbench Search 表格与 Shiori 二级界面表格的 Selection Action Overlay，两者一致。

## 2. 布局改为单行

1. 计数在左，四个动作按钮在右，两组之间间距 `--spacing-4`，同一行居中对齐。
2. 不做两端对齐，容器宽度由内容决定。原来的上下两行结构与 Row Gap 退役。
3. 计数文字额外左内缩 `--spacing-3`，与按钮自带的透明内边距对齐，使容器左右视觉留白一致。
4. 容器的位置、底色、描边、圆角、投影与内边距不变。

## 3. 计数文案

1. 英文复数改为 `%d rows selected`，简体改为 `已选取 %d 行`，繁体改为 `已選取 %d 行`。
2. 英文单数另配一条文案 `1 row selected`，中文不区分单复数。

## 4. 动作按钮改为文字 + 键帽

四个按钮从 Button / Neutral 改为 Shortcut Action Button，与 Playback Overlay 底部风格一致，不共用实现。

1. 从左到右依次为：`Export to Anki` 键位 `A`、`Copy Deep Links` 键位 `D`、`Copy Table` 键位 `T`、`Exit` 键位 `Esc`。
2. `Export to Anki` 为新文案，简繁英三套；其余三条文案复用现有。
3. 键帽显示字母，`Esc` 写字母不用符号。
4. 不再显示图标与描边。只有 Default 与 Hover 两态，没有按下态、Disabled 与 Open。Hover 时按钮底色出现，其内部键帽同时加深一档。
5. 按钮间距 `--spacing-2`，按钮内边距 `--spacing-3` / `--spacing-2`，文字与键帽间距 `--spacing-2`。键帽尺寸沿用现有取值。
6. 标签与键帽文字沿用 `--color-text-muted`。
7. 选中行数为 0 时四个按钮照常可点、不置灰，点击后不发生任何事。
8. 指针在按钮上为箭头，不使用手型。

## 5. 快捷键

1. 四个按钮的点击与对应按键走同一条路径，效果完全一致。
2. 只有 Select 状态下、且主窗口是当前窗口时才响应。设置窗口等主窗口之外的窗口打开并获得焦点时，按键一律不生效。
3. Workbench 页面被更高层界面覆盖期间不响应。
4. 菜单打开期间不响应；`Esc` 归菜单，先关菜单而不是退出 Select 状态。
5. 有可编辑文本处于聚焦状态时不响应，字母照常输入。
6. 表格现有的 Tab、Space、方向键行为不变。

## 6. 变体按底色改名

Shortcut Action Button 与 Keycap 的两个变体原按界面命名，现按所在底色命名。

1. `Playback Overlay` 改为 `Overlay Surface`，对应底色 `--color-subtitle-focus-overlay-bg`。
2. `Command Panel` 改为 `Popover Surface`，对应底色 `--color-bg-popover`；Command Panel 与 Selection Action Overlay 共用该变体。
3. 六个配色 token 随之改名，颜色数值不变。
4. Shortcut Action Button 的 Sizes 留在 Shared 不动，仍为 `--spacing-2` / `--spacing-1`。内边距不随底色走：只有 Selection Action Overlay 的按钮改用 `--spacing-3` / `--spacing-2`，写在它自己的组件里。

## 7. 不变项

1. 四个动作的功能行为不变，本次只改外观、布局与新增键盘入口。
2. Overlay 随 Select 状态显隐、只屏蔽自身覆盖区域的规则不变。
3. Playback Overlay 与 Command Panel 的外观不变，改名不改颜色数值。
4. 表格的行外观、Shift 区间选中、列宽、排序与滚动行为不变。

## 8. 文档

本次改动稳定并验收后，更新 `docs/human/design/UI Design System.md`：改写 Selection Action Overlay 与 Selection Action Overlay Layout 的结构、布局与间距；把 Shortcut Action Button 与 Keycap 的两个变体名与六个 token 名改为按底色命名；更新 Icon Button 的 Surface Hover 表。

# 验收

1. 进入 Select 状态，Overlay 单行显示，左侧为计数，右侧依次为 Export to Anki A、Copy Deep Links D、Copy Table T、Exit Esc。
2. 未选中任何行时显示 `0 rows selected`，选中一行显示 `1 row selected`，选中多行显示 `3 rows selected`；简繁两种语言分别核对。
3. 逐个点击四个按钮，效果与按 A、D、T、Esc 完全一致；Esc 退出 Select 状态，与工具栏 Select 按钮关闭时一致。
4. 0 选中时四个按钮不呈 Disabled 外观，点击后不发生任何事。
5. Hover 任一按钮，按钮底色出现且其键帽同时加深；按住鼠标不改变外观。
6. 打开设置窗口后按 A、D、T、Esc，Overlay 无反应。
7. 打开 Command Panel 或任一对话框后按这四个键，Overlay 无反应。
8. 表格行右键菜单打开时按 Esc，只关闭菜单，Select 状态保留。
9. 搜索框聚焦时按 A、D、T，字母进入输入框，不触发动作。
10. 表格的 Tab、Space、方向键行为与改动前一致。
11. Search 与 Shiori 两个表格分别核对以上各项。
12. Light 与 Dark 两个主题分别核对第 1、5 项。
13. Playback Overlay 与 Command Panel 底部的外观与改动前一致。
14. 现有自动化端到端与单元用例全部通过。