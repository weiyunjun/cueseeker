# 版本

main

# 关联设计

- `docs/human/design/data/Data.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **`File` 界面 `Add Folder` 下拉菜单**：
   - 在 `Add Folder` 下拉菜单中新增 `FTP Folder`（图标 `folder-ftp`）与 `NFS Folder`（图标 `folder-nfs`）选项，依次位于 `SMB Folder` 下方。
   - 点击对应选项关闭菜单并打开 `FTP Folder` 或 `NFS Folder` 两步式对话框。

2. **`FTP Folder` 与 `NFS Folder` 两步式对话框**：
   - 两步式布局、尺寸、间距、等待态、报错展示位置及返回/关闭清空规则与 `WebDav Folder`、`SMB Folder` 对话框保持一致。
   - **第一步：连接信息输入与检测**：
     - **`FTP Folder`（标题 `FTP Folder`）**：
       - 表单自上而下依次为 `Address`、`Port`、`Username`、`Password` 四项：
         - `Address`（必填）：支持填写局域网友好名称/主机名或 IP 地址，也可直接携带目录路径。粘贴百分号编码内容时即时还原为可读字符；未带 `ftp://` 前缀时点击 `Connect` 自动补全 `ftp://` 解析，不修改输入框内容。
         - `Port`（必填）：打开弹窗时默认预填 `21`，支持修改。
         - `Username` 与 `Password`（选填）：留空时以匿名方式连接，填写时使用账号密码鉴权；仅在最下方 `Password` 输入框下恒定预留 1 行红字报错空间。
     - **`NFS Folder`（标题 `NFS Folder`）**：
       - 表单仅包含 `Address`（必填）一项，在其下方恒定预留 1 行红字报错空间：
         - 支持填写局域网友好名称/主机名或 IP 地址，也可直接携带导出目录及子目录路径（同时兼容 `192.168.1.100/volume1/video` 与带冒号的 `192.168.1.100:/volume1/video` 写法）。粘贴百分号编码内容时即时还原为可读字符；未带 `nfs://` 前缀时点击 `Connect` 自动补全 `nfs://` 解析，不修改输入框内容。
         - 自动兼容 NFSv3 与 NFSv4 协议。
     - 点击 `Connect` 发起连接验证并读取初始目录列表：检测期间输入框与 `Connect` 按钮均为 `Disabled` 且 `Connect` 按钮内左侧显示旋转 `Spinner`；成功加载初始列表前的任何错误（地址或端口非法、网络不可达、鉴权或权限失败、目标不存在或非目录等）均停留在第一步并在最下方输入框下显示红字报错。
   - **第二步：目录浏览、多选与添加入队**：
     - 面包屑导航、单行卡片列表（文件夹分别使用 `folder-ftp` / `folder-nfs` 图标 + 名称 + 右侧 `caret-right` 箭头，视频与字幕文件使用 `video` / `subtitles` 图标 + 名称）、单击多选（已选中项无 Hover 效果）、双击进入下一级、切换层级或点击 `Back` 自动清空已选项、以及点击 `Back` 保留第一步已填内容的规则均与 `WebDav Folder`、`SMB Folder` 一致。
     - **顶层浏览与 `Add` 按钮规则**：
       - **`FTP Folder`**：进入第二步后，未选中任何子文件夹点击 `Add` 直接添加当前所在目录自身（含 FTP 顶层根目录）；选中 1 个或多个子文件夹点击 `Add` 按列表从上到下顺序拆分为独立的「添加文件夹」任务依次入队执行。
       - **`NFS Folder`**：当第一步仅填写主机地址（未指定导出路径）时，进入第二步后面包屑起点显示主机名，列表展示该主机下的顶层导出目录，停留在这一最顶层且未选中任何导出目录时 `Add` 按钮保持 `Disabled`，单击选中 1 个或多个导出目录后 `Add` 按钮变为可用；当已处于某个导出目录或子目录内部时，未选中子文件夹点击 `Add` 直接添加当前所在目录本身，选中 1 个或多个子文件夹则按列表从上到下顺序拆分为独立的「添加文件夹」任务依次入队执行。

3. **FTP 与 NFS 文件夹索引、管理与全界面表现**：
   - **资料库身份与索引流程**：分别以规范化后的完整 `ftp://` 与 `nfs://` 路径作为身份，与本地、WebDAV 及 SMB 文件夹共用同一套资料库身份、包含分组与索引规则。
   - **`File` 界面展示与操作**：
     - 一级根目录卡片与二级子文件夹卡片分别使用 `folder-ftp`、`folder-nfs` 图标，显示解码后的可读路径。
     - 二、三级界面按需展示子文件夹、视频与字幕文件及大小，支持 `Get Info`、`Index Now`、`Remove`（同步清理数据库记录、本地缓存的字幕与封面及已保存的凭据）以及 App 内 `Rename Folder` 与 `Rename Files`（含校验、原地更新与失败自动回滚）。
   - **其它界面**：索引完成后，FTP 与 NFS 视频与字幕在 `Library`、`Recent`、`Search`、`Excerpt`、`Filter`、`Playback Overlay`、`Command Panel`、播放页流式播放与 Seek、截图/拼图及 Anki 导出中的表现与本地、WebDAV 及 SMB 文件夹一致。

# 验收标准

1. `Add Folder` 菜单包含 `FTP Folder`（`folder-ftp` 图标）与 `NFS Folder`（`folder-nfs` 图标），点击可打开对应两步式弹窗。
2. `FTP Folder` 第一步包含 `Address`、`Port`（默认预填 `21`）、`Username`、`Password` 四项，支持自动补全 `ftp://`、粘贴解码、留空匿名或账号密码连接；`NFS Folder` 第一步仅包含 `Address` 一项，支持自动补全 `nfs://`、兼容 `IP:/路径` 与 `IP/路径` 写法、自动兼容 NFSv3 与 NFSv4；进入第二步前的报错均在最下方输入框下显示红字提示。
3. 第二步目录浏览中，`FTP Folder` 支持在任意层级（含顶层根目录）直接添加当前目录或所选子文件夹；`NFS Folder` 在主机顶层导出目录列表未选中任何项时 `Add` 为 `Disabled`，选中导出目录或进入具体导出目录内部后可正常添加当前目录或所选子文件夹。
4. 索引完成后，`File` 一、二级界面文件夹分别显示 `folder-ftp`、`folder-nfs` 图标；支持 `Get Info`、`Index Now`、`Remove` 以及文件夹与配对文件的 App 内原地重命名（无权限或失败时自动回滚并转入 `Incomplete`）。
5. 从各界面均可正常流式播放与 Seek FTP 及 NFS 视频，封面生成、字幕显示、截图/拼图及 Anki 导出均正常工作。