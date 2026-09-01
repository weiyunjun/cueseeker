# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon Button、Sidebar Toggle、Sidebar Item、Dialog、Command Panel Secondary Layout、Icon、Text、Background）

# 需求描述

## 1. 范围

本需求的「纯图标按钮」指以下按钮：

1. Icon Button / Default：Dialog 关闭按钮（Confirmation、Change Cover、Edit List）、任务面板关闭按钮、任务卡片的移除与删除按钮、筛选按钮、顶栏 Back、顶栏任务入口。
2. Icon Button / Inline Clear：搜索框清除按钮。
3. Icon Button / Row Action：当前无实例，规格随组件一并调整。
4. Sidebar Toggle。
5. Sidebar 项的展开箭头。
6. Command Panel 二级页的 Back。

不在范围内：播放器 chrome 的全部图标按钮（Player Circle Button、Player Capsule Button、Player Window Control Button），它们继续使用 `--color-player-*` 体系；搜索框放大镜、Sidebar Item 图标、带文字按钮的前置图标、Library 文件树图标等非按钮图标。

## 2. 颜色

1. 全部纯图标按钮的 Default 图标色由 `--color-icon-default` 改为 `--color-text-secondary`。Sidebar 展开箭头由 `--color-icon-muted` 一并改为 `--color-text-secondary`。
2. 全部纯图标按钮的 Disabled 图标色改为 `--color-text-disabled`。Icon Button 原 `--color-icon-disabled` 与 Inline Clear 原 `--color-icon-muted` 均由该 token 取代。
3. `--color-icon-default`、`--color-icon-muted`、`--color-icon-disabled` 保留，仍由范围外的图标使用。

## 3. 字重

1. 新增 token `--weight-control-icon`，取值 `medium`。
2. 全部纯图标按钮的图标字重改用该 token。原取值 Semibold、Bold、Medium 三种写法退役。

## 4. 尺寸

1. 新增 token `--size-dialog-close-icon`，取值 `14px`。Dialog 的 Close Button 图标尺寸改用该 token，取代原先继承的 `--size-control-icon`。任务面板的关闭按钮同属 Dialog，一并适用。
2. 新增 token `--size-app-sidebar-item-chevron`，取值 `10px`，记录 Sidebar 展开箭头图标的现有尺寸，外观不变。
3. Command Panel 二级页 Back 的按钮盒由 48×48 改为 `--size-icon-button`，圆角改为 `--radius-control`。
4. 其余纯图标按钮的图标尺寸与按钮盒尺寸不变。

## 5. Hover

1. 全部纯图标按钮删除 Hover 状态，指针悬停时不出现任何背景、颜色或尺寸变化。
2. Command Panel 二级页 Back 的常驻 `--color-bg-hover` 底色一并删除，该按钮在所有状态下均无背景。
3. `--color-bg-active-clear-hover` 随之无使用者，退役。
4. `--color-bg-hover` 保留，仍由菜单项与带文字的按钮使用。

## 6. Open 态

保留现状：筛选按钮与顶栏任务入口在其面板打开时，背景为 `--color-icon-button-open-bg`，图标为 `--color-icon-button-open-content`。

## 7. 保持不变

1. Focused 焦点环的颜色、宽度与偏移不变；Command Panel 二级页 Back 继续不参与键盘聚焦。
2. 按下不改变外观的规则不变。
3. 指针为箭头不变。
4. 全部图标按钮的动作、快捷键与可用性判定不变。
5. Sidebar 的结构、层级与展开收起行为不变。
6. 范围外图标的颜色、字重与尺寸不变。

# 验收

1. 全部纯图标按钮的图标色与 `--color-text-secondary` 一致，不再有蓝色倾向；禁用态与 `--color-text-disabled` 一致。
2. 全部纯图标按钮的图标字重一致，较本需求前整体变细，其中搜索框清除按钮变细最明显。
3. Dialog 与任务面板关闭按钮的字形明显小于筛选按钮，按钮盒尺寸不变。
4. Command Panel 二级页 Back 与其他纯图标按钮同尺寸，且无任何背景。
5. 以上按钮在指针悬停时无任何视觉变化。
6. 筛选按钮与任务入口在面板打开时仍为 accent 底加白色图标。
7. 搜索框放大镜、Sidebar Item 图标与播放器 chrome 图标的外观与本需求前一致。
8. `--color-bg-active-clear-hover` 不再出现在设计系统与代码中。
9. Light 与 Dark 两个主题分别核对以上各项。
10. 本次改动不新增任何自动化端到端或单元用例的失败。