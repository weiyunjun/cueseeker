# 版本

main

# 关联设计

- `docs/human/design/Data.md`（Index 流程第 1–8 节）
- `docs/human/design/UI Design System.md`（Buttons、Menus、Inputs、Toast、Dialogs、File Page Layout）
- `docs/human/design/UI Application Rules.md`（界面层级、菜单模态、焦点、指针）
- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md`（根目录分组、Index 进度）

# 需求描述

## 1. File 界面 Add Folder 下拉菜单

1. File 一级界面的 `Add Folder` 按钮改为下拉菜单触发器（`Button / Neutral`，Leading Icon 保持 `folder-plus`，文案保持 `Add Folder`）。
2. 点击按钮在挂靠位置弹出下拉菜单（`Menu / Dropdown Menu`），菜单打开期间按钮处于 `Open` 状态，定位、高亮、键盘导航、点击外部关闭及下层冻结完全遵循现有菜单规范与菜单模态规则。
3. 菜单包含 2 个 `Action Menu Item` 选项，打开时默认高亮首项：
   1. `Local Folder`：Leading Icon 为 Phosphor `folder`。点击后关闭菜单并打开系统文件夹选择面板，后续添加流程与改动前一致。
   2. `WebDav Folder`：Leading Icon 为 Phosphor `cloud`。点击后关闭菜单并打开 `WebDav Folder` 对话框。
4. 存在 Index 类任务或数据库压缩进行中时，`Add Folder` 按钮保持 `Disabled`，不弹出菜单。

## 2. WebDav Folder 对话框

1. 在主窗口对话框层（`Dialog`）内绘制，标题为 `WebDav Folder`，右上角为关闭按钮（`Icon Button / Dialog Close`），宽度为 `--width-dialog-medium`，四边内边距为 `--inset-dialog`。打开时不自动聚焦任何输入框。
2. 表单区单列占满内容宽度，自上而下依次排列 4 个单行输入框（`Text Field`）：
   1. `Name`：自定义显示名称（明文输入）。
   2. `Address`：WebDAV 目录地址（明文输入，支持 `http://` 与 `https://`）。
   3. `Username`：WebDAV 用户名（明文输入）。
   4. `Password`：WebDAV 密码（密文掩码输入）。
3. 4 个输入框均不展示行内 Error 边框，也不预留底部报错文字行；输入框之间的垂直间距为 `--spacing-4`。`Tab` 与 `Shift-Tab` 仅在这 4 个输入框之间移动焦点。
4. 底部操作区右对齐 `Cancel`（`Button / Neutral`）与 `Add`（`Button / Primary`），间距为 `--spacing-2`。
5. 点击 `Add` 时执行参数检查与 WebDAV 连通性验证（按下回车键不触发 `Add`）：
   1. **校验规则**：检查 `Name`、`Address`、`Username`、`Password` 均已填写且 `Address` 为合法的 `http/https` URL，并向目标 WebDAV 目录发起一次 `PROPFIND` 请求验证目录存在、可访问且凭据有效。
   2. **等待状态**：验证返回前，`Add` 按钮文字保持 `Add` 不变，按钮内左侧展示 `Spinner` 且按钮为 `Disabled`（不响应点击）；4 个输入框均为 `Disabled`；`Cancel` 按钮、右上角关闭按钮与 `Esc` 键保持可用，触发时立即取消当前验证请求并关闭对话框。
   3. **失败处理**：参数缺失、地址格式非法、网络不可达、鉴权失败或目标非目录时，对话框保持打开，恢复 4 个输入框与 `Add` 按钮为可用状态（移除 `Spinner`），并通过居中 `Toast`（带 `warning` 图标）提示具体失败原因。
   4. **成功处理**：验证通过后立即关闭对话框，保存该 WebDAV 根目录配置与凭据，并创建 `Add Folder` 任务进入后台索引队列。
6. `Toast` 显示层级高于 `Dialog` 层（点击仍穿透），确保对话框打开期间触发的报错 `Toast` 正常浮现在对话框上方。

## 3. WebDAV 资料库索引流程

1. **永久身份与根目录分组**：
   1. WebDAV 根目录以规范化后的完整 URL 作为路径身份，与本地文件夹共用同一套资料库身份模型（`LibraryID`、`VideoID`、`SubtitleID`、`CueID`、`ExcerptID`）。
   2. 同一 WebDAV 服务下存在路径包含关系的根目录，遵循与本地文件夹相同的分组与最外层代表目录规则。
2. **Index 四阶段行为与权重**：
   1. 保持 `Scanning files`（20%）、`Indexing subtitles`（40%）、`Reading video info`（20%）、`Generating covers`（20%）四个阶段、权重及任务取消/中断回滚规则不变。
   2. **阶段 1（`Scanning files`）**：通过 WebDAV `PROPFIND` 递归获取目录树下全部视频与字幕文件的路径、文件大小与修改时间戳，按 `Data.md` 第 1、2 节规则完成同目录视频与字幕匹配及新旧文件变更检测。遍历中途发生网络错误或中断时，按 `Data.md` 扫描失败规则立即取消本次 Index 并保留 Index 前状态。
   3. **阶段 2（`Indexing subtitles`）**：对新增或发生变化的字幕文件，从 WebDAV 下载字幕内容并保存至本地缓存目录，随后按 `Data.md` 第 3、4 节规则完成字幕解析、语言分析与核心数据发布。Search、Excerpt、ASS 渲染等后续读取字幕内容的环节直接访问本地缓存的字幕文件。
   4. **阶段 3（`Reading video info`）**：按 `Data.md` 第 5 节规则，对新增或发生变化的 WebDAV 视频流式读取容器头部信息（时长、分辨率、帧率、编码格式、音轨列表），单文件读取失败只跳过该文件。
   5. **阶段 4（`Generating covers`）**：按第 4 节调整后的封面获取流程生成自动封面，并在完成后更新 Library 展示数据与 `Display Title`。

## 4. Index 阶段封面获取流程调整与并发控制

适用于本地文件夹与 WebDAV 文件夹的自动封面生成阶段（`Data.md` 第 6 节）：

1. **保持不变的封面规则**：
   1. 自动封面的触发与失败回退规则（Fallback 封面重试、用户自定义封面不修改、新视频失败用 Fallback、旧视频失败保留原自动封面）保持不变。
   2. 5 个候选采样时间点（视频时长的 `20%`、`30%`、`40%`、`50%`、`60%`）、`320×180` 评分分辨率、画面质量与直方图相似度选优算法、以及同时产出全分辨率 Master 封面与 Display 缩略图的规格保持不变。
2. **单视频单次打开与内存选帧（替代单视频 6 次独立进程打开）**：
   1. 废除原“每个采样点分别启动独立 `ffmpeg` 进程打开视频抽小图、选出最佳时间点后再第 6 次启动进程重新打开视频抽大图”的流程。
   2. **每个待生成封面的视频在整个封面生成过程中仅打开一次媒体源**，建立单次媒体会话并复用已解析的容器流信息与索引表。
   3. 在同一次媒体会话内，按时间顺序依次 Seek 到 `20%`、`30%`、`40%`、`50%`、`60%` 五个采样点解码视频帧：每次解码出一帧后，既缩放到 `320×180` 计算质量分与直方图，同时在内存中暂存该候选帧图像数据。
   4. 5 个采样点全部完成评分与跨帧相似度计算后，**直接将内存中得分最高的候选帧编码输出为全分辨率 Master 封面与 Display 缩略图**，不再发起第 6 次视频打开与 Seek。单视频处理完毕后立即释放内存中的候选帧数据。
3. **队列并发控制**：
   1. 封面生成继续在独立的后台低优先级任务组中执行，不阻塞 Search、页面加载与已有封面显示。
   2. **分级并发上限**：
      - 本地文件夹：`Generating covers` 最大并发视频数保持为当前设备活跃 CPU 核心数。
      - WebDAV 文件夹：`Reading video info` 并发视频数固定为 `1`；`Generating covers` 最大并发视频数限制为 `2`（单视频内部 5 个采样点在同一连接上串行执行），确保同一时刻对远端 WebDAV / 网盘的活跃视频连接数不超过 2 个，避免高频并发请求触发网盘风控，同时依靠“单视频单次打开”保证索引耗时不显著增加。

## 5. WebDAV 302 重定向、流式播放与各界面表现

1. **302 重定向与鉴权隔离（含 AList 挂载网盘场景）**：
   1. 访问 WebDAV 视频资源（包括 `Reading video info`、`Generating covers`、视频播放、时间轴关键帧预览、截图/拼图导出及 Anki 音频导出）时，同时支持标准 WebDAV 直连响应（`200/206`）与 `302` 重定向响应。
   2. 当 WebDAV 服务端返回 `302` 重定向至外部存储/网盘直链时，仅对 WebDAV 服务端请求携带 Basic Auth 鉴权头；跟随 `302` 访问跨域目标直链时不携带 WebDAV 的 `Authorization` 头，防止网盘 CDN 拒绝请求。
2. **File 界面展示与操作**：
   1. 一级界面（Roots）：WebDAV 根目录卡片的 Title 显示添加时填写的 `Name`，Subtitle 显示填写的 `Address`，左侧图标与本地文件夹一致，均为 `folder`。
   2. 二级（Subfolders）与三级（Files）界面：按需直查展示子目录、视频与字幕文件及大小，支持 `Get Info` 查看详情。
   3. 支持对 WebDAV 根目录执行 `Remove`（确认后通过 `Remove Folder` 任务清理数据库记录、本地缓存的字幕与封面以及保存的凭据）与 `Index Now`。
   4. WebDAV 根目录及其下属子目录、文件在本版本中不支持 App 内重命名，对应菜单中的 `Rename Folder` 与 `Rename Files` 置为 `Disabled`。
3. **其它界面**：
   1. 索引完成后，WebDAV 视频与字幕在 Library、Recent、Search、Excerpt、Filter、Playback Overlay、Command Panel、播放页流式播放/Seek、截图/拼图与 Anki 导出中的表现与本地文件夹一致。
4. **设计文档同步**：
   1. 本需求验收通过后，再将 UI 改动同步更新至 `UI Design System.md` 与 `UI Application Rules.md`。

# 验收标准

1. 点击 File 一级界面的 `Add Folder` 按钮弹出下拉菜单，包含 `Local Folder`（`folder` 图标）与 `WebDav Folder`（`cloud` 图标），按钮 `Open` 状态、默认首项高亮、方向键/回车/Esc 与外部点击关闭符合菜单模态规范。
2. 点击 `Local Folder` 正常打开系统文件夹选择面板并添加本地目录；点击 `WebDav Folder` 正常弹出 `WebDav Folder` 对话框。
3. `WebDav Folder` 对话框标题、宽度、无报错预留行的输入框间距（`--spacing-4`）、`Password` 密文掩码输入及打开时不自动聚焦符合规范。
4. 点击 `Add` 等待期间：`Add` 按钮文案不变、左侧显示 Spinner 且禁用，4 个输入框禁用；点击 `Cancel`、右上角关闭按钮或按 `Esc` 可立即取消并关闭对话框。
5. 输入为空、URL 非法、地址不可达或账号密码错误时点击 `Add`：对话框保持打开，恢复可输入状态，并在对话框上方弹出居中 `Toast` 提示。
6. 输入有效的 AList WebDAV 参数（如挂载 115 网盘且 WebDAV 策略为 `302`）点击 `Add`：验证通过后对话框立即关闭，后台 `Add Folder` 任务依次完成扫描、字幕缓存与解析、视频信息读取、封面生成（并发受控且单视频仅打开一次完成 5 点采样选帧），不触发网盘风控且全流程耗时正常。
7. 索引完成后：File 一级界面显示用户填写的 `Name`、`Address` 与 `folder` 图标，二三级界面下钻与 `Get Info` 正常；Library 与 Recent 中视频封面展示正常；从 Search、Library、Recent 或 Excerpt 点击视频均可正常流式播放与 Seek，无卡死现象。
8. 移除 WebDAV 根目录后，相关数据库记录与本地缓存文件被正确清理。
9. 真实 AList + 115 环境的端到端表现由所有者人工验收；WebDAV 协议解析、302 鉴权隔离、单视频单次打开封面采样、队列并发控制及 UI 状态流转由自动化测试覆盖且全部通过。