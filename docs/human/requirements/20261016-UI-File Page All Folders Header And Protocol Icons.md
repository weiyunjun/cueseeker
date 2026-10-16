# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **移除面包屑按下视觉效果（`C-05.6 Breadcrumb`）**：
   - 移除面包屑可点击节点的按下变暗效果；按住鼠标左键期间保持既有 `Hover` 外观不变，松开时触发层级跳转，并遵循菜单模态下的悬停屏蔽规则。

2. **统一 `All Folder` / `All Folders` 标题与面包屑首节点（`L-04.5 File Page Layout`）**：
   - File 一级界面取消按 `Local Folder`、`WebDav Folder` 分组展示，所有根文件夹合并为单一列表。
   - 一级界面列表正上方标题（原 `Local Folder` 位置）与二、三级界面面包屑最左侧根节点统一显示 `All Folder`（根文件夹数量为 `1` 时）或 `All Folders`（根文件夹数量 `> 1` 时；简中：`全部文件夹`，繁中：`全部資料夾`），确保从二、三级界面返回或切换层级时最左侧文字内容与位置保持稳定。

3. **新增协议文件夹图标（`L-04.6 File Card Layout` & `Icon Registry.md`）**：
   - 本地文件夹维持现有 `folder` 图标不变。
   - 新增 `WebDav`、`SMB`、`FTP`、`NFS` 协议文件夹图标（文件夹图形微上移，下方居中标注对应协议字样；当前启用 `WebDav`，`SMB`、`FTP`、`NFS` 作为预留图标）。
   - File 一级界面的 WebDAV 根文件夹卡片、二级界面的 WebDAV 子文件夹卡片，以及 `Add Folder` 下拉菜单中的 `WebDav Folder` 选项统一使用新的 `WebDav` 文件夹图标。

4. **WebDAV 地址粘贴即解码与友好中文显示**：
   - 当用户将带有百分号转写（Percent-Encoding）的链接粘贴进 `WebDav Folder` 弹窗的 `Address` 输入框时，输入框内瞬间自动还原为可读的中文与原始符号显示。
   - WebDAV 文件夹地址在保存及 File 界面展示时统一显示解码后的可读文本（同时兼容已添加的存量 WebDAV 文件夹）。

5. **设计文档同步**：
   - 待全部改动验收通过后，再将最终 UI 与图标规则同步更新至 `docs/human/design/ui/` 下对应文档。

# 验收标准

1. 面包屑可点击节点 Hover 变色正常，按住鼠标左键期间无变暗或透明度变化，菜单打开期间不响应悬停。
2. File 一级界面不再区分 `Local Folder` 与 `WebDav Folder` 分组，顶部标题及二、三级面包屑最左侧节点均根据根目录数量正确显示 `All Folder` 或 `All Folders`（含中英文切换），层级切换时最左侧文字位置稳定。
3. 新增 `WebDav`、`SMB`、`FTP`、`NFS` 文件夹图标；WebDAV 一级根目录卡片、二级子目录卡片及 `Add Folder` 菜单中的 `WebDav Folder` 项均正确显示新的 `WebDav` 文件夹图标，本地文件夹仍显示默认 `folder` 图标。
4. 在 `WebDav Folder` 弹窗的 `Address` 输入框粘贴转写链接时立即还原为中文与可读符号；File 界面中的新旧 WebDAV 根目录与子目录地址均显示为解码后的友好文本。