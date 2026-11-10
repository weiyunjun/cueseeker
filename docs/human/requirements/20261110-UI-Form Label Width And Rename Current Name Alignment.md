# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **水平双列表单左侧 Label 列宽度调整（`UI Tokens.md` & `UI Design Rules.md`）**：
   - 将 `--width-form-label` 由 `72px` 修改为 `96px`，使对话框内水平双列表单左侧标签（如 `Rename` 对话框的 `Current Name`）留出足够宽度，保持单行完整显示不换行。

2. **`L-06.3 Rename Dialog Layout` 当前名称文本左对齐规则（`UI Layouts - Workbench.md`）**：
   - `Current Name` 右侧的当前名文字增加左内边距 `--padding-field-x`（`10px`），使其文字起点与下方 `New Name` 输入框内的文本左边缘对齐（而非与输入框外边框左对齐）；名称超长多行自然折行时，各行左边缘保持对齐。

# 验收标准

1. 对话框水平双列表单左侧 Label 列宽度为 `96px`（`--width-form-label`），英文环境下 `Rename` 对话框的 `Current Name` 标签单行完整显示、不发生换行。
2. `Rename` 对话框中 `Current Name` 右侧的名称文字左边缘与下方 `New Name` 输入框内的文本左边缘严格对齐（向右缩进 `--padding-field-x: 10px`），超长折行时各行左边缘保持一致对齐。