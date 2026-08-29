# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Menu、Menu Item、Menu Divider、Height、Padding、Radius）

# 需求描述

## 1. 目标

菜单沿用了按钮与表格行的控件密度，且菜单容器与菜单项的内边距逐层叠加，导致菜单项过高、内容过度内缩、子菜单箭头右侧过松。按列表密度重排菜单的间距与圆角，并改写滚动条的宽度规则。适用于全部菜单。

## 2. 间距与尺寸

| Token | 现值 | 新值 |
| --- | --- | --- |
| `--padding-menu` | `12px` | `6px` |
| `--padding-menu-item` | `12px 16px` | `10px` |
| `--height-action-menu-item` | `40px` | `32px` |
| `--height-select-menu-item` | `40px` | `32px` |
| `--radius-menu` | `16px` | `12px` |
| `--radius-action-menu-item` | `8px` | `6px` |
| `--radius-select-menu-item` | `8px` | `6px` |

1. `--padding-menu-item` 只保留左右分量，纵向分量退役。菜单项高度由文字行高 20px 与上下各 6px 推导得到，不再与按钮、输入框、表格行共用同一高度。
2. 菜单项圆角等于菜单圆角减菜单内边距。这是一条规则，任一方改动时另一方跟随。
3. `--padding-menu` 不再由滚动条尺寸推导，两者相互独立。
4. 菜单边缘到菜单项前置图标的距离等于 `--padding-menu` 与 `--padding-menu-item` 之和。

## 3. 后置图标的光学补偿

1. 菜单项后置槽为图标（子菜单指示箭头）时，该侧内边距为 `--padding-menu-item` 减 2px。后置槽为文字（快捷键、计数）时不补偿。
2. 子菜单指示箭头的图标框按图形实际宽度裁紧，不保留左右透明边距。

## 4. 分隔线

Menu Divider 横贯菜单，左右各外扩一个 `--padding-menu`，两端与菜单内边框相接，不再随菜单项内边距缩进。

## 5. 滚动条宽度规则

改写现有「滚动条出现与否都不改变菜单宽度」的规定，并取代 `20260826-UI-Filter Menu Replaces Filter Panel.md` 验收第 8 条：

1. 滚动条出现时菜单加宽，菜单项的可用宽度不变。
2. 无滚动条时，菜单项右边缘到菜单边缘的距离为 `--padding-menu`。
3. 有滚动条时，菜单项右边缘到滚动条左边缘的距离同样为 `--padding-menu`。
4. 滚动条到菜单边缘的距离由新增 token `--gap-menu-scrollbar-outer` 表达，取 `6px`，上下同此值。
5. 菜单加宽量为 `--scrollbar-size` 与 `--gap-menu-scrollbar-outer` 之和。
6. 滚动条不与菜单项、分隔线重叠。

## 6. 不变项

1. 全部颜色、字号、字重不变。
2. `--max-height-menu` 与 `--scrollbar-size` 不变。
3. 菜单项前置图标与文字之间的间距仍为 `--spacing-2`。
4. 播放页倍速菜单自有的 `--height-player-speed-menu-item` 等 token 不在本次范围内。
5. 菜单的挂靠、模态、高亮、键盘导航行为不变。

## 7. 样式约束

禁止硬编码，全部视觉值必须由 Design System 的 token 或组件规则表达；禁止为单个菜单增加私有实现。

## 8. 设计文档同步

本需求验收通过后再更新 `UI Design System.md`：更新上表各 token 取值，新增 `--gap-menu-scrollbar-outer`，Menu Item 增加后置图标侧内边距的补偿规定，Menu Divider 补齐尺寸规定，Menu 的 Vertical Scrollbar 改写 Placement 一条。

# 验收

1. 菜单边缘到前置图标的距离为 16px；菜单项高度为 32px。
2. 菜单圆角 12px、菜单项高亮圆角 6px，高亮块四角与菜单内边框的间隙均匀。
3. 子菜单指示箭头到菜单边缘的距离，视觉上不比前置图标到菜单边缘的距离更松。
4. 分隔线两端与菜单内边框相接。
5. Filter 菜单出现滚动条时菜单加宽，菜单项右边缘到滚动条左边缘的距离与无滚动条时的右内边距相同。
6. 行右键菜单、筛选菜单、列头菜单、卡片右键菜单、Shiori 目标子菜单外观一致。
7. Light 与 Dark 两个主题分别核对。
8. 现有自动化端到端与单元用例全部通过。