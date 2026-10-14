# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

1. **全局输入框 Tokens 与报错预留规则**：
   - 修改现有 Tokens：`--height-field` 改为 `30px`（作用于 `Text Field`、`Password Field`、`Number Field`、`Shortcut Field`）；`--radius-field` 改为 `6px`、`--padding-field-x` 改为 `10px`（作用于上述单行输入框及 `Text Area`；`--radius-table-cell-hover` 保持独立的 `8px`）。
   - 新增 Token：`--width-form-label: 72px`，用于水平双列表单左侧 Label 列的固定宽度。
   - **红字报错（`Validation Message`）预留规则**：Dialog 对话框内的校验输入框下方（间距 `--spacing-1: 4px`）恒定预留 `1` 行红字高度，红字左边缘与所属输入框左边缘对齐；Settings 设置页内的输入框平时不预留红字高度（`Reserved Lines: 0`），仅在报错时动态展开行。

2. **WebDav Folder 对话框**：
   - 表单改为「左 Label + 右 Input」水平双列布局：左侧 Label 列宽 `--width-form-label`（`72px`，左对齐），Label 与右侧输入框水平间距 `--spacing-3`（`12px`），行间距 `--spacing-3`（`12px`）。
   - `Name` 改为选填并带占位提示（未填写时默认取 `Address` URL 路径最后一级目录名作为显示名称，根路径回退为 Host）；`Address`、`Username`、`Password` 必填且无占位提示。
   - 取消报错 `Toast`：当参数缺失、URL 格式非法或连接/鉴权失败无法进入 Index 流程时，统一在最下方 `Password` 输入框正下方显示单行红字报错（恒定预留 `1` 行红字高度，左边缘与密码输入框左边缘对齐）。

3. **Rename 对话框**：
   - 改为「左 Label（`--width-form-label: 72px`，左对齐）+ 右内容/输入框」水平双列布局，水平间距与行间距均为 `--spacing-3`（`12px`）。
   - `Current Name` 保持多行自然折行完整显示（不截断），左侧 Label 与右侧首行文字顶部对齐；`New Name` 输入框下方恒定预留 `1` 行红字高度（左边缘与输入框左边缘对齐）。

4. **Excerpt List Editor 对话框**：
   - 保留左封面、右侧上下堆叠表单的布局。
   - 右侧 `Description`（`Text Area`）容器底边下探至与左侧封面下方说明文字（`Support Text`）第 1 行底边对齐，使 `Text Area` 下方恒定预留的 `1` 行红字空间与左侧说明文字第 2 行底边齐平。

5. **Export to Anki 对话框**：
   - 底部 `File Name` 与 `Location` 区域中的 `Location` 由静态路径文本改为可编辑的单行 `Text Field`（允许用户直接输入路径），输入框右侧（间距 `--spacing-2: 8px`）放置文件夹选择按钮（`Icon Button / Default`）。
   - `File Name` 与 `Location` 输入框下方均恒定预留 `1` 行红字高度（左边缘与输入框左边缘对齐），路径为空、不存在或不可写时在 `Location` 下方显示红字报错。

6. **Settings 输入行与快捷键还原按钮**：
   - `Shortcut Field` 与 `Number Field` 应用新的 `--height-field`（`30px`）、`--radius-field`（`6px`）、`--padding-field-x`（`10px`），平时不预留底部红字空间。
   - `Settings / Shortcuts` 每行 `Shortcut Field` 右侧的 `Restore Default` 按钮复用 `Icon Button / Dialog Close` 尺寸规格（按钮宽高 `--size-dialog-close-button: 24px`，图标大小 `--size-dialog-close-icon: 16px`，圆角 `--radius-control: 8px`）；当前为默认键位时隐藏不显示，仅在可恢复默认时显示。

7. **设计文档同步**：
   - 待全部改动验收通过后，再将上述 Tokens 与规则同步更新至 `UI Design System.md`。

# 验收标准

1. 全局单行输入框高度为 `30px`，单行与多行输入框圆角为 `6px`、左右内边距为 `10px`，聚焦前后文本与占位符位置稳定不偏移。
2. `WebDav Folder` 对话框为左 Label（`72px`）右 Input 布局；`Name` 选填带占位提示且留空时自动取 URL 末级目录名，其余 3 项无占位提示；校验或连接失败时在 `Password` 下方左对齐显示红字报错且不弹 Toast，弹窗高度无跳动。
3. `Rename` 对话框为左 Label（`72px`）右内容布局，`Current Name` 超长时多行完整换行显示，`New Name` 下方预留 1 行红字空间且左对齐输入框。
4. `Excerpt List Editor` 的 `Description` 文本框底边对齐左侧说明文字第 1 行底边，下方预留 1 行红字空间与左侧第 2 行底边齐平。
5. `Export to Anki` 的 `Location` 可直接输入路径或通过右侧文件夹按钮选择，且 `File Name` 与 `Location` 下方均预留 1 行红字空间并正确校验报错。
6. `Settings / Shortcuts` 的 `Restore Default` 按钮尺寸缩小为 `24×24px`（`16px` 图标），默认键位时不显示、修改后才显示；设置页输入框平时不预留红字行，按键冲突时动态展开红字。