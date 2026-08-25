# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽、菜单模态、指针）
- `docs/human/design/UI Design System.md`（Media Card、Menu、Menu Item）

# 需求描述

## 1. 目标

卡片的 Hover 与 Selected 目前由卡片自身与外部各持一半，无法保证同一时刻
只有一处生效。本需求将两者合并为单一的「当前项」，并收敛到唯一所有者。

## 2. 适用卡片

视频卡片：Workbench Library 一级的文件夹卡片；Workbench Library 二级、
Workbench Recent 一级的 Recent Videos、Workbench Recent Videos、
Playback Overlay Playlist、Command Panel Recent Videos 的单个视频卡片。

Shiori 卡片：Workbench Recent 一级与 Command Panel 的 Recent Shioris；
Workbench Shiori 一级的卡片。

表格行与 Cover Summary 不在本需求范围内。

## 3. 当前项

1. Hover 与 Selected 合并为单一的当前项状态，视觉沿用各界面现有的卡片
   高亮表现。
2. 作用域为整个界面。同一界面内所有卡片共用一个当前项，任何时刻最多一张
   卡片处于当前项。Workbench Recent 一级的 Recent Videos 与 Recent
   Shioris 共用同一个当前项。
3. 判定区域沿用现有 Media Card 的交互区域，不变。

## 4. 鼠标

1. 真实的鼠标移动落在卡片判定区域内时，当前项移到该卡片。
2. 右键点击卡片判定区域时，当前项移到该卡片。
3. 左键点击卡片判定区域时，当前项移到该卡片；但该次点击若被用于关闭
   已打开的菜单，则不改变当前项。
4. 滚动、布局变化、界面出现等非真实鼠标移动的情形不改变当前项。

## 5. 键盘

1. 方向键改变当前项，仅适用于 Playback 界面的卡片。
2. Workbench 界面的卡片不接受方向键。
3. 键盘的任何操作都不隐藏鼠标指针。

## 6. Workbench 与 Playback 的差异

1. Workbench 界面进入时没有当前项；Playback 界面进入时默认以第一张卡片
   为当前项。
2. Workbench 界面允许没有当前项：鼠标移出卡片判定区域后当前项清除。
3. Playback 界面任何时刻都有且仅有一个当前项：鼠标移到卡片之外时当前项
   保持不动。
4. Playback Overlay 在 Current、Playlist、Collage Editor 之间切换时，
   Playlist 的当前项在同一 Session 内保留。

## 7. 指针可见性

1. 键盘操作不再隐藏鼠标指针。
2. 播放页空闲三秒隐藏指针的行为保留。
3. 指针是否可见不再作为卡片当前项能否改变的条件。

## 8. 菜单打开期间的通用规则

适用于全部菜单。

1. 不响应菜单之外的鼠标 Hover、拖拽与滚轮。
2. 上下左右四个方向键与 Enter 归菜单，菜单之外不响应其效果。
3. 菜单之外的 App 界面的左键按下，以及焦点在 App 上时的 Esc，优先响应
   为关闭菜单。
4. 菜单所属的界面关闭，或切换为其它界面时，菜单关闭。

## 9. 菜单的特殊规则

1. 倍速菜单不适用第 8 节第 2 条中的左右键，左右键照常传给播放页。
2. 倍速菜单在切换到上一个/下一个结果、打开 Command Panel、打开 Playback
   Overlay 时关闭。判定依据是这三个事件本身，不是触发它们的按键或手柄
   键位。
3. Playback Overlay 与 Command Panel Search Result 的选中文字菜单关闭时，
   同时清除被选中的文字。

## 10. 样式约束

1. 不新增、不修改、不替换任何颜色、尺寸、圆角与间距 Token。
2. 各界面沿用现有的卡片高亮表现，本需求只改变该表现挂在哪一个状态上。
3. 禁止为单个界面增加私有实现。

## 11. 设计文档同步

本需求验收通过后，再将第 3 至 9 节的规则补入关联设计文档。

# 验收

1. 同一界面内任何时刻最多一张卡片处于当前项，Playback 界面恒为一张。
   本条人工验收。
2. Workbench Library 一级左键点击卡片进入二级界面后，没有任何卡片处于
   当前项。
3. Command Panel 左键点击 Recent Videos 进入后，第一张卡片为当前项。
4. Workbench Library 一级右键卡片后该卡片为当前项；随后左键点击菜单之外，
   菜单关闭且当前项不变。
5. Workbench 界面鼠标移出卡片后没有当前项；Playback 界面鼠标移出卡片后
   当前项不变。
6. Playback 界面方向键可移动当前项；Workbench 界面方向键不改变当前项。
7. 任何键盘操作后鼠标指针仍然可见；播放页空闲三秒后指针仍然隐藏。
8. 各菜单打开期间，菜单之外的 Hover、拖拽、滚轮、四个方向键与 Enter 均
   不生效；倍速菜单打开期间左右键仍作用于播放页。
9. 倍速菜单在切换上一个/下一个结果、打开 Command Panel、打开 Playback
   Overlay 时关闭。
10. 选中文字菜单关闭后，被选中的文字一并消失。
11. 现有自动化端到端与单元用例全部通过。