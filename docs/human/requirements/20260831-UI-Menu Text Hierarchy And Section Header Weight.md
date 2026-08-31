# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Text、Typography、Menus）

# 需求描述

## 1. 问题

菜单的文字层级把颜色和字重朝同一个方向编码了两次：标题既最深又最粗，而真正要读、要点的菜单项文字停在第二档。菜单项文字为 `--color-text-secondary`，白底对比度 9.0:1，比 macOS 系统菜单（约 15.1:1）与主流前端框架（约 15.5:1）整整浅一档，整体发灰。

分节标题的 Label 为 Semibold，前置图标落在系统符号默认的 Regular，两者粗细对不上。设计系统 `Menu Section Header / Leading Icon` 只写了 Size 与 Color，漏记 Font Weight，实现因此走了默认值。

## 2. 菜单文字指派

菜单文字改为两个颜色档 × 两个字重的四角色矩阵：

| 元素 | Color | Font Weight |
| --- | --- | --- |
| Menu Title | `--color-text-primary` | Semibold |
| Menu Section Header（Label 与 Leading Icon） | `--color-text-secondary` | Medium |
| Menu Item 文字与图标 | `--color-text-primary` | Regular |
| Filter Option Menu Item 文字 | `--color-text-primary` | Regular |
| Filter Option Menu Item 的计数与 calculating 提示 | `--color-text-secondary` | Regular |

其中四处为变更：

1. Menu Item 的文字、前置图标、勾选标记与子菜单指示箭头由 `--color-text-secondary` 改为 `--color-text-primary`。
2. Filter Option Menu Item 的选项文字由 `--color-text-secondary` 改为 `--color-text-primary`。
3. Menu Section Header 的 Label 字重由 Semibold 改为 Medium；Leading Icon 的字重明确为 Medium，与 Label 一致。
4. Filter Option Menu Item 的计数与 calculating 提示由 `--color-text-muted` 改为 `--color-text-secondary`。

Menu Title 的颜色与字重不变，本表记录规格。

## 3. 设计系统条目补记

1. `Menu Section Header / Leading Icon` 缺少 Font Weight 条目，补充为 Medium，并明确与 Label 同字重。
2. `Menu Section Header / Label` 的 Font Weight 由 Semibold 改为 Medium。
3. `Menu Item / States / Default` 的 Label Color 与 Icon Color 由 `--color-text-secondary` 改为 `--color-text-primary`。
4. `Filter Option Menu Item` 的 Label Color 改为 `--color-text-primary`，Trailing Slot 的 Color 改为 `--color-text-secondary`。

## 4. 不变项

1. `--color-text-primary`、`--color-text-secondary`、`--color-text-muted` 的取值不变，不新增文字色 token。`--color-text-muted` 本次退出菜单，保留在 token 表中供其它位置使用。
2. Destructive Menu Item 继续使用 `--color-danger-text` 与 `--color-danger-bg-hover`，不受本次指派影响。
3. Menu Item 的 Disabled 态继续使用 `--color-text-disabled` 与 `--color-icon-disabled`。
4. 所有字号、行高、图标尺寸、间距、圆角、背景与高亮不变。普通菜单项图标 14pt 与分节标题图标 16pt 的字号差异本次不处理。
5. 播放页倍速菜单使用 `--color-player-text-*` 体系，不在本次范围内。
6. 菜单的打开、高亮、模态、滚动与关闭行为不变。

# 验收

1. 菜单项文字明显变深，与 macOS 系统菜单的深浅接近，不再发灰。
2. 菜单项的文字、前置图标、勾选标记与子菜单箭头颜色完全一致。
3. 筛选菜单四级层级为：标题最深最粗、选项同样深但为 Regular、分节标题浅一档且略粗、计数浅一档且为 Regular。
4. 分节标题的图标与文字粗细一致，不再一细一粗。
5. 表格、按钮、工具栏、表单等菜单以外的文字颜色不变。
6. 「移除 Shiori」仍为危险色，禁用项仍为禁用色。
7. Light 与 Dark 两个主题分别核对以上各项。
8. 本次改动不新增任何自动化端到端或单元用例的失败。