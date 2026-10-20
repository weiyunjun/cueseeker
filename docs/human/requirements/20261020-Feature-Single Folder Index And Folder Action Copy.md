# 版本

main

# 关联设计

- `docs/human/design/data/Data.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/workbench/Library and File.md`

# 需求描述

1. **File 页面顶部全量索引按钮文案调整（`L-04.5 File Page Layout`）**：
   - File 页面左上角（`Add Folder` 右侧）的全量索引按钮文案由 `Index Now`（`立即索引`）改为 **`Index All`**（简：`索引全部` / 繁：`索引全部`），图标（`arrow-clockwise`）与全量索引功能保持不变。

2. **File 页面文件夹卡片菜单项调整与单文件夹索引入口（`L-04.6 File Card Layout`）**：
   - **一级根文件夹卡片 `...` 弹出菜单**：自上而下依次为：
     1. **`Rename This Folder`**（简：`重命名此文件夹` / 繁：`重新命名此資料夾`，Neutral，图标 `pencil-simple`）
     2. **`Index This Folder`**（简：`索引此文件夹` / 繁：`索引此資料夾`，Neutral，图标 `arrow-clockwise`）
     3. **`Remove This Folder`**（简：`移除此文件夹` / 繁：`移除此資料夾`，Destructive，图标 `minus-circle`）
   - **二级子文件夹卡片 `...` 弹出菜单**：菜单项文案同步由 `Rename Folder` 改为 **`Rename This Folder`**（简：`重命名此文件夹` / 繁：`重新命名此資料夾`）。
   - **禁用条件**：存在正在执行的资料库任务或数据库压缩进行中时，`Index This Folder` 与其余操作按钮一致为 `Disabled`。

3. **单文件夹索引行为与状态栏、任务面板展示（`L-04.5`、`L-06.10 Task Card Layout`）**：
   - **所见即所得索引范围**：点击某张根文件夹卡片的 `Index This Folder` 时，仅对该卡片对应的文件夹执行扫描、字幕解析、视频匹配、视频信息读取与封面生成，并仅增删改该文件夹路径范围内的数据；若该文件夹位于另一个已添加的父级根文件夹之下，入库数据仍归属最外层父级资料库，但不扫描父级目录下的其它子文件夹。
   - **File 页面状态指示器**：单文件夹索引进行中显示 `Indexing [Folder]`（`正在索引: [Folder]`），完成后显示 `Indexed [Folder]`（`已完成索引: [Folder]`）并更新最后更新时间，失败显示 `Index Failed: [Folder]`（`索引失败: [Folder]`）；点击顶部 `Index All` 保持显示 `Indexing All Folders` / `Indexed All Folders`。
   - **Task（任务）面板卡片标题**：
     - 全量索引（`Index All`）：卡片标题由 `Index` 改为 **`Index All`**（简：`索引全部` / 繁：`索引全部`）。
     - 单文件夹索引（`Index This Folder`）：卡片标题显示为 **`Index: [Folder]`**（简：`索引：[Folder]` / 繁：`索引：[Folder]`）。
   - 任务进度四阶段展示、执行中取消规则及完成后各页面的按需刷新规则均与现有索引任务保持一致。

# 验收标准

1. File 页面顶部全量索引按钮显示为 `Index All`（`索引全部` / `索引全部`）。
2. File 一级根文件夹卡片 `...` 菜单自上而下依次为 `Rename This Folder`、`Index This Folder`、`Remove This Folder`；二级子文件夹卡片 `...` 菜单为 `Rename This Folder`；任务或数据库压缩进行中时菜单项禁用。
3. 点击 `Index This Folder` 仅扫描并更新所选根文件夹自身范围内的数据（含存在父子包含关系的根文件夹场景），File 顶部状态栏正确展示 `Indexing [Folder]`、`Indexed [Folder]` 或 `Index Failed: [Folder]`。
4. Task 面板中，全量索引任务卡片标题显示为 `Index All`（`索引全部`），单文件夹索引任务卡片标题显示为 `Index: [Folder]`（`索引：[Folder]`），进度与取消行为正常。