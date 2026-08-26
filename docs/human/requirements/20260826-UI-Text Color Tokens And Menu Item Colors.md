# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Text、Buttons、Menus、Tables、Text Decoration）

# 需求描述

## 1. 文字色 Token 重定义

文字色三档的跨度不合理：最深一档过深，表格早已不用；中间缺一档。重新定义：

- `--color-text-primary`：Light `#404040`；Dark `#D4D4D4`
- `--color-text-secondary`：Light `#535761`；Dark `#BABABF`
- `--color-text-muted`：不变
- `--color-text-placeholder`：不变

原 `--color-text-primary` 的取值 `#0F172A` / `#F4F4F5` 退役，不再作为任何文字色使用。它在时间徽章底色、弹层阴影等非文字用途中的使用不受影响。

## 2. 文字色语义指派

`--color-text-secondary` 用于：

1. Table Header Cell 的标签。
2. Menu Item 的文字、前置图标、勾选标记与子菜单指示箭头，Destructive Menu Item 除外。
3. Button / Neutral 的标签与图标。
4. Toolbar Button 的 Action、Panel Trigger、Mode Toggle 三个变体的标签与图标。

`--color-text-muted` 用于 Selection Action Overlay 的已选数量文字。

其余引用 `--color-text-primary` 的位置保持引用不变，随取值一并变浅，包括表格主字幕、输入框已输入的正文、页面标题、Section Title、对话框标题、Toast、卡片与列表标题。

## 3. Table Cell 文字色更正

设计系统中 Table Cell 的 Text 与 Interactive Text 都记为 `--color-text-primary`，与实现不符。按实现更正：

- Text：`--color-text-muted`
- Interactive Text：`--color-text-primary`

Table Header Cell 缺少 Label Color 条目，补充为 `--color-text-secondary`。

## 4. Menu Item 图标颜色统一

Menu Item 的 Default 状态只规定了 Label Color，没有规定前置槽与后置槽的图标颜色，实现中子菜单指示箭头用了 `--color-icon-default`，比文字浅两档。补充规定：前置图标、勾选标记与子菜单指示箭头与 Label 同色。

## 5. Destructive Menu Item 落地

设计系统已定义 Destructive Menu Item，实现中从未落地，「移除 Shiori」与普通菜单项外观相同。按已有定义实现：文字与图标使用 `--color-danger-text`，高亮背景使用 `--color-danger-bg-hover`，禁用态沿用 Menu Item 的禁用规定。

## 6. 「复制到…」图标缺失

该菜单项配置的图标名 `copy` 不是有效的系统符号，界面上画出空白占位。本次先改为与「移动到…」相同的箭头图标。

## 7. 表格可播放文字的 Hover 反馈

可播放字幕文本在 Hover 时不改变文字颜色，只增加下划线，指针维持手型。下划线颜色与所在文字自身的颜色一致：主字幕的下划线用主字幕的颜色，台词组附加行的下划线用附加行的颜色。

现有实现按「是否为最后一段」决定下划线颜色，导致主字幕与附加行的下划线颜色恰好相反，本次一并纠正。

## 8. 死代码清理

表格通用单元格绘制函数中的 `isHovered` 与 `underline` 两个参数没有任何调用方传值，它们控制的单元格 Hover 背景与下划线从未生效。本次连同参数与对应分支一并移除。

## 9. 不变项

1. `--color-text-muted`、`--color-text-placeholder`、`--color-text-disabled` 的取值不变。
2. 复选框继续使用 `--color-bg-checkbox-checked` 等自有 token，不改为引用文字色 token。
3. 所有字号与字重不变。
4. Icon Button 与 Search Field 搜索图标等图标类取值不变。
5. Menu Title 与 Menu Section Header 不单独指定颜色，随 token 取值变化，靠字重区分层级。
6. 播放页的 `--color-player-text-*` 体系不受影响。
7. 表格行的 Hover 背景、勾选、右键菜单与播放、复制入口不变。
8. 输入框已输入的正文暂不拆分独立 token。

# 验收

1. 表格的主字幕、表头、表格内非主字幕三档颜色由深到浅依次拉开，可分辨。
2. 菜单项的文字、前置图标、勾选标记与子菜单箭头颜色完全一致。
3. 「复制到…」显示箭头图标，与「移动到…」一致。
4. 「移除 Shiori」的文字与图标为危险色，高亮时背景为危险色底。
5. Hover 可播放字幕时文字颜色不变，只出现下划线，指针为手型；显示台词组时，主字幕与附加行的下划线颜色各自与其文字一致。
6. 批量选择时底部按钮为 `--color-text-secondary`，已选数量为 `--color-text-muted`。
7. `#0F172A` 与 `#F4F4F5` 不再作为文字色出现在设计系统与代码中。
8. Light 与 Dark 两个主题分别核对以上各项。
9. 现有自动化端到端与单元用例全部通过。