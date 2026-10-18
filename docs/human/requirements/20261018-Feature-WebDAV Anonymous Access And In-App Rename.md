# 版本

main

# 关联设计

- `docs/human/design/data/Data.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **支持 WebDAV 匿名访问（`L-06.4 WebDav Folder Dialog Layout`）**：
   - `WebDav Folder` 对话框中的 `Username` 与 `Password` 由必填改为选填（保持无占位提示），允许留空以匿名方式访问支持免密的 WebDAV 目录。
   - 点击 `Add` 时仅校验 `Address` 为合法的 `http/https` 地址并直接发起连接验证；若服务端要求认证或凭据无效，仍按现有规则在 `Password` 输入框下方显示鉴权失败红字提示。

2. **开放 WebDAV 文件夹与文件的 App 内重命名（`L-04.6 File Card Layout`、`L-06.3 Rename Dialog Layout`）**：
   - 在 `File` 一级界面（WebDAV 根目录卡片）、二级界面（WebDAV 子文件夹卡片）及三级界面（WebDAV 视频与字幕文件卡片）中，开放 WebDAV 条目的 `Rename Folder` 与 `Rename Files` 菜单项，其可用状态与本地文件夹/文件完全一致。
   - WebDAV 文件夹与单集配对文件的重命名遵循与本地一致的校验、原地替换刷新及任务队列规则：
     - **改名前校验**：仅校验远端源文件夹或当前这组已知配对文件是否存在，以及同一父路径下目标名称是否已存在。
     - **改名成功**：远端完成改名后，同步更新媒体库路径、本地已缓存的字幕及 WebDAV 根目录配置（对 WebDAV 根目录执行 `Rename Folder` 时，其显示名称与目录地址同步更新为新文件夹名与新地址），各界面原地替换为新名称与新路径，无需重新索引。
     - **改名失败（如匿名/只读账号无修改权限、服务端不支持或网络中断）**：自动还原本次任务中已改名的远端文件，保持原有数据不变，并将任务归入 `Task` 界面的 `Incomplete` 列表展示失败报错。

# 验收标准

1. 在 `WebDav Folder` 对话框中仅填写有效的免密 WebDAV `Address`（`Username` 与 `Password` 留空）点击 `Add`，可正常通过验证并完成索引；若目标目录不允许匿名访问，则在 `Password` 下方显示鉴权失败红字报错。
2. `File` 一、二、三级界面中 WebDAV 根目录、子文件夹及视频/字幕文件的 `Rename Folder`、`Rename Files` 菜单项正常可用。
3. 当 WebDAV 账号（含具备写权限的匿名用户）拥有改名权限时，在 `File` 各级界面执行 `Rename Folder` 或 `Rename Files` 可正常完成远端改名，各界面标题与路径立即原地更新，改名后播放、字幕显示、搜索与摘录均正常且无需重新索引。
4. 当 WebDAV 账号无改名权限或远端拒绝改名时，任务转入 `Task` 界面的 `Incomplete` 列表并显示失败原因，已改名的文件被还原，原有媒体库数据与状态不受影响。