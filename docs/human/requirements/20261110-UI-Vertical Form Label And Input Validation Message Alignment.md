# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **纵向表单上方 Label 与输入框内文本左对齐规则（`UI Components - Controls.md` & `UI Layouts - Workbench.md`）**：
   - 纵向排布的 `Text Field`（`C-01.1`）与 `Text Area`（`C-01.2`）上方 Label（如 `Edit List` / `New Excerpt List` 对话框中的 `List Name`、`Description`）增加左内边距 `--padding-field-x`（`10px`），使其左边缘与下方输入框内的文本左边缘对齐（而非与输入框外边框左对齐）。

2. **输入框下方红色报错提示（`Validation Message`）与框内内容左对齐规则（`UI Design Rules.md`、`UI Components - Controls.md` & `UI Layouts - Workbench.md`）**：
   - 对话框内所有输入框（`Edit List` / `New Excerpt List` 的 `List Name` 与 `Description`、`Rename` 的 `New Name`、`WebDAV` / `SMB` / `FTP` / `NFS Folder` 最下方输入框、`Export to Anki` 的 `File Name` 与 `Location`）下方的 `Validation Message` 增加左内边距 `--padding-field-x`（`10px`），使其左边缘与所属输入框内的文本左边缘对齐。
   - `Settings -> Shortcuts` 中 `Shortcut Field`（`C-01.5`）下方的 `Validation Message` 起点同样与框内按键内容左边缘对齐（距输入框左外边框 `--padding-field-x: 10px`），文案较长时仍向功能名称一侧延伸。

# 验收标准

1. `Edit List` / `New Excerpt List` 对话框中 `List Name` 与 `Description` 小标题左边缘与下方各自输入框内的文本左边缘严格对齐（向右缩进 `--padding-field-x: 10px`）。
2. 所有对话框输入框（`Edit List` / `New Excerpt List`、`Rename`、`WebDAV` / `SMB` / `FTP` / `NFS Folder`、`Export to Anki`）下方的红色报错文字左边缘均与所属输入框内的文本左边缘严格对齐（向右缩进 `--padding-field-x: 10px`）。
3. `Settings -> Shortcuts` 快捷键冲突红色报错文字在短文案时左边缘与框内按键胶囊左边缘对齐（距快捷键框左外边框 `10px`），长文案时向左侧功能名称方向延伸。