# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon Button、Sidebar Toggle、Background）
- `docs/human/design/UI Application Rules.md`（菜单模态、Hover 与选中、按下、尺寸过渡）

# 需求描述

## 1. 范围

本需求的「纯图标按钮」指以下按钮：

1. Icon Button / Default：顶栏 Back、顶栏任务入口、筛选按钮、Dialog 关闭按钮（Confirmation、Change Cover、Edit List）、任务面板关闭按钮、任务卡片的移除与删除按钮。
2. Icon Button / Inline Clear：搜索框清除按钮。
3. Sidebar Toggle。
4. Command Panel 二级页的 Back。

不在范围内：播放器 chrome 的全部图标按钮（Player Circle Button、Player Capsule Button、播放页与 Playback Overlay 的返回按钮），它们保留各自现有的 Hover 与配色；搜索框放大镜、Sidebar Item 图标、带文字按钮的前置图标等非按钮图标。

本需求取代 `docs/human/requirements/20260901-UI-Icon Button Color Weight And Hover Removal.md` 的第 5 节与第 6 节。该需求的颜色、字重、尺寸各节继续有效。

## 2. Hover

1. 全部纯图标按钮恢复 Hover：指针悬停时按钮盒出现 `--color-bg-hover` 背景。
2. 背景的形状与尺寸沿用该按钮已有的按钮盒与圆角，不新增尺寸或圆角 token。
3. 图标颜色、图标尺寸、字重在 Hover 时不变。
4. Disabled 不出现 Hover。

## 3. Open 态

1. 筛选按钮与顶栏任务入口在其菜单或面板打开期间，背景与 Hover 相同，为 `--color-bg-hover`；图标保持 `--color-text-secondary`。
2. accent 底与白色图标的 Open 外观取消。`--color-icon-button-open-bg` 与 `--color-icon-button-open-content` 在本需求后无使用者，退役。

## 4. 保持不变

1. Focused 焦点环的颜色、宽度与偏移不变；Command Panel 二级页 Back 继续不参与键盘聚焦。
2. 按住不改变外观的规则不变。
3. 指针为箭头不变。
4. 菜单打开期间菜单之外不出现 Hover 的规则不变：挂靠菜单的按钮保持 Open 外观，其它纯图标按钮在菜单打开期间不因指针而变化。
5. 尺寸过渡期间，Back 与 Sidebar Toggle 的外观保持进入过渡之前的样子，过渡的开始与结束在它们身上不可见。
6. 全部图标按钮的动作、快捷键与可用性判定不变。
7. 范围外按钮的外观不变。

# 验收

1. 指针悬停在顶栏 Back、顶栏任务入口、筛选按钮、Dialog 与任务面板关闭按钮、任务卡片移除与删除按钮、搜索框清除按钮、Sidebar Toggle、Command Panel 二级页 Back 上时，按钮盒出现灰色背景；移开后消失。
2. 灰色与菜单项、Toolbar Button 的 Hover 底色一致。
3. 筛选按钮打开筛选菜单、任务入口打开任务面板期间，按钮底色与 Hover 完全相同，不再出现 accent 底与白色图标。
4. 筛选菜单打开期间，把指针移到其它纯图标按钮上不出现任何灰底。
5. 禁用状态的纯图标按钮悬停时无灰底。
6. 搜索框清除按钮的灰底是圆形，Dialog 关闭按钮的灰底与其按钮盒同尺寸。
7. `--color-icon-button-open-bg` 与 `--color-icon-button-open-content` 在设计系统与代码中均无残留。
8. Light 与 Dark 两个主题分别核对以上各项。
9. 本次改动不新增任何自动化端到端或单元用例的失败。