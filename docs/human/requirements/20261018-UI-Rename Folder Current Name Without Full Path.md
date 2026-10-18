# 版本

main

# 关联设计

- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **Rename Folder 对话框 Current Name 显示规则调整（`L-06.3 Rename Dialog Layout`）**：
   - 在 `File` 界面（含一级根目录卡片与二级子文件夹卡片）打开 `Rename Folder` 对话框时，`Current Name` 仅展示当前文件夹名称本身（不带前置父级路径），与下方 `New Name` 输入框的默认初始值一致。
   - `Rename Files` 对话框的 `Current Name` 保持显示视频与字幕去掉扩展名后的公共名不变；多行自然折行、表单对齐与重命名校验规则均保持不变。

# 验收标准

1. 在 `File` 界面一级根目录卡片与二级子文件夹卡片打开 `Rename Folder` 对话框，`Current Name` 均仅显示文件夹名称，不包含完整路径（如 `/Volumes/Seagate/影视/Ave Mujica` 仅显示 `Ave Mujica`）。
2. `Rename Files` 对话框展示及重命名功能正常，不受影响。