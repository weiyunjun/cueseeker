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
   - 在 `Add Folder` 下拉菜单中新增 `SMB Folder` 选项（Leading Icon 使用 `folder-smb`），位于 `WebDav Folder` 下方。
   - 点击 `SMB Folder` 关闭菜单并打开 `SMB Folder` 对话框。

2. **`SMB Folder` 两步式对话框**：
   - 弹窗标题为 `SMB Folder`，两步式布局、尺寸、间距、等待态、报错展示位置及返回/关闭清空规则与 `WebDav Folder` 对话框保持一致。
   - **第一步：连接信息输入与检测**：
     - 表单区采用左 Label、右输入框的水平双列布局，自上而下依次为 `Address`、`Port`、`Username`、`Password` 四项：
       - `Address`（必填）：支持填写局域网友好名称/主机名或 IP 地址，也可直接携带共享文件夹及子目录路径。粘贴百分号编码内容时即时还原为可读字符；未带 `smb://` 前缀时点击 `Connect` 自动补全 `smb://` 解析，不修改输入框内容。
       - `Port`（必填）：打开弹窗时默认预填 `445`，支持修改。
       - `Username` 与 `Password`（选填）：留空时以匿名（Guest）方式连接，填写时使用账号密码鉴权；仅在最下方 `Password` 输入框下恒定预留 1 行红字报错空间。
     - 点击 `Connect` 发起连接验证并读取初始目录列表：检测期间 4 个输入框与 `Connect` 按钮均为 `Disabled` 且 `Connect` 按钮内左侧显示旋转 `Spinner`；成功加载初始列表前的任何错误（地址或端口非法、网络不可达、鉴权失败、目标不存在或非目录等）均停留在第一步并在 `Password` 下方显示红字报错。
   - **第二步：目录浏览、多选与添加入队**：
     - 面包屑导航、单行卡片列表（文件夹使用 `folder-smb` 图标 + 名称 + 右侧 `caret-right` 箭头，视频与字幕文件使用 `video` / `subtitles` 图标 + 名称）、单击多选（已选中项无 Hover 效果）、双击进入下一级、切换层级或点击 `Back` 自动清空已选项、以及点击 `Back` 保留第一步已填内容（含 `Port`）的规则均与 `WebDav Folder` 一致。
     - **顶层共享文件夹浏览与 `Add` 按钮规则**：
       - 当第一步仅填写主机地址（未指定共享文件夹路径）时，进入第二步后主面包屑起点显示主机名，列表展示该主机下的顶层共享文件夹；停留在这一最顶层且未选中任何共享文件夹时，`Add` 按钮保持 `Disabled`，单击选中 1 个或多个共享文件夹后 `Add` 按钮变为可用。
       - 当已处于某个共享文件夹或子目录内部时：未选中任何子文件夹点击 `Add` 直接添加当前所在目录本身；选中 1 个或多个子文件夹点击 `Add` 按列表从上到下顺序拆分为独立的「添加文件夹」任务依次入队执行。

3. **SMB 文件夹索引、管理与全界面表现**：
   - **资料库身份与索引流程**：SMB 根目录以规范化后的完整 `smb://` 路径作为身份，与本地及 WebDAV 文件夹共用同一套资料库身份与包含分组规则；索引四阶段、字幕本地缓存、单视频单次打开 5 点采样生成封面及远程并发限制（`Reading video info` 并发 `1`、`Generating covers` 最大并发 `2`）与 WebDAV 文件夹一致。
   - **`File` 界面展示与操作**：
     - 一级根目录卡片与二级子文件夹卡片图标均为 `folder-smb`，显示解码后的可读路径。
     - 二、三级界面按需展示子文件夹、视频与字幕文件及大小，支持 `Get Info`、`Index Now`、`Remove`（同步清理数据库记录、本地缓存的字幕与封面及保存的凭据）以及 App 内 `Rename Folder` 与 `Rename Files`（含校验、原地更新与失败自动回滚）。
   - **其它界面**：索引完成后，SMB 视频与字幕在 `Library`、`Recent`、`Search`、`Excerpt`、`Filter`、`Playback Overlay`、`Command Panel`、播放页流式播放与 Seek、截图/拼图及 Anki 导出中的表现与本地及 WebDAV 文件夹一致。

# 验收标准

1. `Add Folder` 菜单包含 `SMB Folder`（`folder-smb` 图标），点击可正常打开 `SMB Folder` 两步式弹窗。
2. 第一步包含 `Address`、`Port`（默认预填 `445`）、`Username`、`Password` 四项；`Address` 支持主机名或 IP、自动补全 `smb://` 前缀及粘贴解码；支持填写账号密码或留空匿名连接；进入第二步前的报错均在 `Password` 下方显示红字提示。
3. 第一步仅输入主机地址连接成功后，第二步面包屑以主机名为起点并列出顶层共享文件夹；停留在最顶层且未选中共享文件夹时 `Add` 按钮为 `Disabled`，选中 1 个或多个共享文件夹后 `Add` 可用；双击进入共享文件夹内部后，未选中子文件夹可直接添加当前目录，选中多个子文件夹则按显示顺序拆分为多个独立任务入队执行。
4. 索引完成后，`File` 一、二级界面文件夹均显示 `folder-smb` 图标；支持 `Get Info`、`Index Now`、`Remove` 以及文件夹与配对文件的 App 内原地重命名（无权限或失败时自动回滚并转入 `Incomplete`）。
5. 从各界面均可正常流式播放与 Seek SMB 视频，封面生成、字幕显示、截图/拼图及 Anki 导出均正常工作。