# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Selection Controls、Settings Category Layout）

# 需求描述

## 1. 范围

设置界面的两处分段选择控件：

1. Appearance 的 Appearance Mode：Light、Dark、Auto。
2. Decode 的 Decoder：Hardware、Software、Auto。

## 2. 改动

1. 新增组件 Segmented Control，归入 Selection Controls，用于在少量互斥选项中选择一个值；Settings Category Layout 的组件清单加入它。
2. 两处控件统一使用 Segmented Control。
3. Segmented Control 的尺寸、字体与颜色全部引用 token：

| 部位 | Token |
| --- | --- |
| 控件高度 | 新增 `--height-segmented-control`：`32px` |
| 内边距 | 新增 `--padding-segmented-control`：`3px` |
| 选项间距 | 新增 `--gap-segmented-control`：`2px` |
| 选项宽度 | 各选项等宽：最长选项文字的宽度加两侧各一个 `--padding-control-x` |
| 圆角 | `--radius-control` |
| 选中块圆角 | `--radius-control` 减 `--padding-segmented-control` |
| 选项文字 | 字号新增 `--font-size-segmented-control`：`12px`；字重 `--font-weight-control` |
| 背景 | `--color-bg-surface` |
| 边框 | `--color-border-control`，宽度 `--border-width-control` |
| 未选中 | 文字 `--color-text-primary`，无背景 |
| 选中背景 | 新增 `--color-segmented-control-selected-bg`：macOS accent color |
| 选中文字 | 新增 `--color-segmented-control-selected-content`：Light `#FFFFFF`；Dark `#FFFFFF` |

4. 状态只有 Unselected 与 Selected，无 Hover。

## 3. 保持不变

1. 两处控件的选项、文案与所在行的布局不变。
2. 选择的保存与生效时机不变。
3. 无障碍朗读的名称与选中状态不变。

# 验收

1. 两处控件外观一致。
2. 选项文字字号、控件高度与改动前相同。
3. 各选项等宽，最长的选项文字两侧各留一个 `--padding-control-x`。
4. 点击选项后立即成为选中项，设置照常生效。
5. Light 与 Dark 两个主题分别核对以上各项。
6. 本次改动不新增任何自动化端到端或单元用例的失败。