# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`
- `docs/human/requirements/20260926-UI-File Page Three Level Card Redesign.md`

# 需求描述

## 1. 结构与层级架构

1. **移除顶部冗余说明**：
   - 彻底移除 File 页面顶部原有的大段说明文本块（如 "Click a folder to view subfolders and files..."），释放垂直视觉空间，保持卡片流的克制纯粹。

2. **Breadcrumb（面包屑导航）组件**：
   - **布局位置**：位于 File 页面内容区最顶排（Row 1），与下方卡片列表左边缘基准严格对齐。
   - **三级固定架构**：
     - Level 1：`Home`（多语言本地化：en 为 `Home`，zh-Hans 为 `首页`，zh-Hant 为 `首頁`）
     - Level 2：`Home` > `[Indexed Path]`（例如 `Home` > `影视`）
     - Level 3：`Home` > `[Indexed Path]` > `[Folder]`（例如 `Home` > `影视` > `Ave Mujica`；若为根目录直属内容，展示完整后缀如 `Home` > `影视` > `影视（根目录直属内容）`）
     - 到达 Folder 层级后即为文件实体列表，不再支持更深层级下钻。
   - **Sidebar 切换响应规范**：
     - 当位于 File 二级或三级界面时，点击 Sidebar 其它标签（如 Search、Library），再点击 File 标签，统一打开 File 一级界面（Home）。
     - 当已位于 File 界面（一级、二级或三级）时，点击 Sidebar 的 File 标签不响应，行为与 Library 和 Excerpt 一致。
   - **失效/空目录下的面包屑稳定性**：
     - **顶方面包屑文案始终保持路径稳定**：无论该文件夹下的文件是否存在、部分失效或全部移出媒体库，顶部的 Breadcrumb 始终严格维持当前所进入的层级实体名称（如 `Home > 影视 > Ave Mujica`），禁止在面包屑中展示异常状态或提示文案。
     - 异常与空状态（如部分/全部文件失效或无入库内容）统一通过主内容区域的空状态组件进行提示。
   - **视觉规范与 Tokens**：
     - **未激活项（可点击链接）**：字号 14px（`--font-size-body`），字重 500 Medium（`--font-weight-control`），文本颜色 `--color-text-secondary`（浅色 `#494949` / 深色 `#B9B9B9`）。Hover 态变为 `--color-text-primary`。点击可直接回退到对应层级。
     - **当前激活项（最后一项，不可点击）**：字号 14px（`--font-size-body`），字重 600 Semibold，文本颜色 `--color-text-primary`（浅色 `#1F1F1F` / 深色 `#E4E4E4`）。
     - **分隔符**：Phosphor 轮廓图标 `caretRight`，尺寸 12px，线宽 1.15px（严格遵循 `Icon Registry.md` 计算标准），颜色 `--color-text-muted`（浅色 `#717171` / 深色 `#979797`）。
     - 元素间距：`--spacing-2`（8px）。

## 2. 状态区与操作按钮展示规则（仅限一级界面展示）

1. **展示范围约束**：
   - 状态指示行与右侧操作按钮组**仅在 Level 1（Home）一级首页展示**。
   - 进入 Level 2（Indexed Path）或 Level 3（Folder）后，整行隐藏，页面仅保留顶排面包屑与纯净的卡片/文件列表。

2. **Row 2 布局与尺寸对齐**：
   - 高度：`--height-control`（40px），与右侧按钮高度严格保持 1:1，垂直居中对齐。
   - 左右两端对齐：左侧为状态指示器，中间弹性占位，右侧为操作按钮组；外边缘与下方卡片对齐。

3. **左侧极简状态指示器（Status Indicator）**：
   - **极简文字**：移除所有冗长流水进度，详细耗时与任务进度统一由 Task 界面承载，File 界面仅展示当前操作核心状态（包含 Add Folder、Remove、Index Now 等所有数据库操作）。
   - **字重与排版规范**：字号 14px，字重 500 Medium（`--font-weight-control`），与右侧按钮文字字重完全一致，保证左右视觉重心平衡。
    - **4 种状态映射**：
      1. **已完成（Completed）**：
         - 图标：Phosphor 轮廓 `checkCircle`（18px，线宽 1.30px），颜色 `--color-success-text`。
         - 文案：单目录添加/索引完成展示 `Indexed [Folder]`（多语言：`已完成索引: [Folder]` / `已完成索引: [Folder]`）；全量索引完成展示 `Indexed All Folders`（多语言：`已完成全部索引` / `已完成全部索引`）；移除目录完成展示 `Removed [Folder]`（多语言：`已移除: [Folder]` / `已移除: [Folder]`），颜色 `--color-success-text`（浅色 `#047857` / 深色 `#6EE7B7`）。完成后同步更新数据库最后操作时间戳。
      2. **进行中（In Progress）**：
         - 图标：原生控件 `WorkbenchSpinner`（Filter Calculating 按钮同款，尺寸 18px），颜色 `--color-text-secondary`。
         - 文案：单目录添加/索引中展示 `Indexing [Folder]`（多语言：`正在索引: [Folder]` / `正在索引: [Folder]`）；全量索引中展示 `Indexing All Folders`（多语言：`正在索引全部文件夹` / `正在索引全部資料夾`）；移除目录进行中展示 `Removing [Folder]`（多语言：`正在移除: [Folder]` / `正在移除: [Folder]`），颜色 `--color-text-secondary`（浅色 `#494949` / 深色 `#B9B9B9`）。
      3. **失败（Failed）**：
         - 图标：Phosphor 三角警告轮廓 `warning`（18px，线宽 1.30px），颜色 `--color-danger-text`。
         - 文案：索引失败展示 `Index Failed: [Folder]`（多语言：`索引失败: [Folder]` / `索引失敗: [Folder]`）；移除失败展示 `Removal Failed: [Folder]`（多语言：`移除失败: [Folder]` / `移除失敗: [Folder]`），颜色 `--color-danger-text`（浅色 `#B42318` / 深色 `#FCA5A5`）。
      4. **闲置（Idle）**：
         - 触发场景：离开首页切换到其它页面切回，或当前无进行中的数据库任务。
         - 图标：Phosphor 轮廓 `arrowClockwise`（18px，线宽 1.30px），颜色 `--color-text-secondary`。
         - 文案：有数据库操作记录时展示 `Last Updated: yy-MM-dd HH:mm`（多语言：`上次更新: yy-MM-dd HH:mm` / `上次更新: yy-MM-dd HH:mm`）；首次打开且从未操作过展示 `Last Updated: --`（多语言：`上次更新: --` / `上次更新: --`），颜色 `--color-text-secondary`。

4. **右侧操作按钮组**：
   - `[Add Folder]`：图标 `folderPlus`（18px，线宽 1.30px），Neutral 按钮规范。
   - `[Index Now]`：图标 `arrowClockwise`（18px，线宽 1.30px），Neutral 按钮规范。
   - 按钮规范：高 `--height-control`（40px），圆角 `--radius-control`（8px），横向内边距 `--padding-control-x`（14px），边框 `--color-border-control`，背景色 `--color-control-fill`，文本 14px 500 Medium `--color-text-secondary`，按钮间距 `--spacing-2`（8px）。

## 3. 三级卡片与操作按钮规范

1. **一级界面（Root 根目录列表）**：
   - Line 1：根文件夹名称（14px，500 Medium，`--color-text-primary`）。
   - Line 2：完整绝对路径，保留根路径前置斜杠（如 `/Volumes/Seagate/影视`，12px，400 Regular，`--color-text-muted`）。
   - 右侧操作按钮：`[Rename Folder]`（Neutral，图标 `pencilSimple`，18px 1.30px）与 `[Remove]`（Destructive，图标 `minusCircle`，18px 1.30px）。

2. **二级界面（Indexed Path 子目录列表）**：
   - Line 1：子文件夹名称；若为根目录直属媒体文件，展示 `[Folder Name] (Direct Content)`（14px，500 Medium，`--color-text-primary`）。
   - Line 2：完整绝对路径（12px，400 Regular，`--color-text-muted`）。
   - 右侧操作按钮：`[Rename Folder]`（Neutral，图标 `pencilSimple`）。

3. **三级界面（Folder 文件列表）**：
   - Line 1：完整文件名含扩展名（14px，500 Medium，`--color-text-primary`）。
   - Line 2：文件大小（以 1024 进位并保留 2 位小数，如 `1.43 GB`，12px，400 Regular，`--color-text-muted`）。
   - 右侧操作按钮：`[Rename Files]`（Neutral，图标 `pencilSimple`）。

4. **异常与空状态处理**：
   - **展示时机约束**：当且仅当确实没有任何可以展示的内容时才展示空状态提示组件（`WorkbenchEmptyHint`）。异步加载期间展示居中 `WorkbenchSpinner`，不得提前展示空状态。
   - 若某子目录下的文件全部失效、丢失或被移出媒体库，页面主内容区域展示：
     - 英文：`No items in this folder are in the library.`
     - 简体中文：`此文件夹中没有仍在媒体库中的项目。`
     - 繁体中文：`此資料夾中沒有仍在媒體庫中的項目。`
   - 文本样式：14px，400 Regular，`--color-text-muted`。此时顶部 Breadcrumb 仍稳定显示当前目录名称。

## 4. 全量设计 Tokens 引用清单

| 分类 | Token 标识符 | 数值 / 规范 | 浅色模式值 (Light) | 深色模式值 (Dark) | 适用组件与场景 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **背景色** | `--color-bg-surface` | 标准窗口表面 | `#FFFFFF` | `#1C1C1F` | File 主页面底色 |
| **背景色** | `--color-bg-dialog` | 弹窗/卡片底色 | `#FFFFFF` | `#2F2F34` | File 卡片背景 |
| **背景色** | `--color-control-fill` | 控件背景 | `#FFFFFF` | `rgba(255, 255, 255, 0.08)` | 按钮背景 |
| **边框色** | `--color-border-control` | 控件/卡片边框 | `#E5E7EB` | `#4A4A52` | 卡片边框、按钮边框 |
| **边框色** | `--color-border-divider` | 分割线 | `#E5E7EB` | `rgba(255, 255, 255, 0.10)` | 顶栏下边框 |
| **文本色** | `--color-text-primary` | 主要文字 | `#1F1F1F` | `#E4E4E4` | 面包屑激活项、卡片标题 (Line 1) |
| **文本色** | `--color-text-secondary` | 次要文字 | `#494949` | `#B9B9B9` | 面包屑链接项、Neutral 按钮文字、进行中/闲置状态文字与图标 |
| **文本色** | `--color-text-muted` | 弱化/次级信息 | `#717171` | `#979797` | 卡片路径 (Line 2)、文件大小、空状态提示、面包屑分隔符 |
| **状态色** | `--color-success-text` | 成功状态文本 | `#047857` | `#6EE7B7` | 索引完成状态文字与图标 |
| **状态色** | `--color-danger-text` | 危险/错误状态文本 | `#B42318` | `#FCA5A5` | 索引失败状态文字与图标、`[Remove]` 按钮文字与图标 |
| **字体字号** | `--font-size-body` | 14px | 14px | 14px | 面包屑文字、状态文字、按钮 Label、卡片标题 |
| **字体字号** | `--font-size-caption` | 12px | 12px | 12px | 卡片副标题（路径、文件大小） |
| **字体字重** | `--font-weight-control` | 500 Medium | 500 Medium | 500 Medium | 按钮 Label、状态文字、面包屑链接、卡片标题 |
| **字体字重** | `Regular` | 400 Regular | 400 Regular | 400 Regular | 卡片副标题路径、文件大小、空状态文案 |
| **字体字重** | `Semibold` | 600 Semibold | 600 Semibold | 600 Semibold | 面包屑当前激活项 |
| **尺寸规格** | `--height-control` | 40px | 40px | 40px | 按钮高度、Row 2 状态指示行对齐高度 |
| **尺寸规格** | `--radius-control` | 8px | 8px | 8px | 卡片圆角、按钮圆角 |
| **尺寸规格** | `--padding-control-x` | 14px | 14px | 14px | 按钮横向内边距 |
| **尺寸规格** | `--size-task-card-icon` | 31px | 31px (线宽 1.50px) | 31px (线宽 1.50px) | 卡片左侧图标（folder, video, subtitles） |
| **尺寸规格** | `--size-button-icon` | 18px | 18px (线宽 1.30px) | 18px (线宽 1.30px) | 按钮图标、状态图标（checkCircle, warning 等） |
| **间距规格** | `--spacing-1` | 4px | 4px | 4px | 卡片内部 Line 1 与 Line 2 间距 |
| **间距规格** | `--spacing-2` | 8px | 8px | 8px | 面包屑元素间距、按钮组内部间距、状态图文间距 |
| **间距规格** | `--spacing-3` | 12px | 12px | 12px | 卡片与卡片之间的垂直间距 |
| **间距规格** | `--spacing-4` | 16px | 16px | 16px | 卡片内边距、页面主区域垂直流间距 |

# 验收

1. **页面头部与面包屑**：
   - 顶部原说明文本块已完全移除。
   - 面包屑位于最顶排，与卡片左边缘对齐；Level 1 根节点支持多语言（`Home` / `首页` / `首頁`）；直属内容在 Level 3 保持完整后缀（`Home > 影视 > 影视（根目录直属内容）`）；未激活项为 14px 500 `--color-text-secondary`，激活项为 14px 600 `--color-text-primary`，分隔符为 12px `caretRight`。
   - 点击面包屑各节点能正确跳转回对应层级。
   - **Sidebar 切换行为**：二级或三级界面切到其他 Sidebar 标签再切回 File 时，回到 Level 1（Home）；已在 File 界面再次点击 Sidebar 的 File 标签不响应。
   - **空目录与失效验证**：当文件夹下的文件全部失效或移出媒体库时，顶部面包屑文案保持稳定的实际目录名（如 `Home > 影视 > Ave Mujica`），不显示任何异常文案；异步加载期间展示 `WorkbenchSpinner`，当且仅当确实无内容展示时下方才展示空状态文案。

2. **状态行与操作按钮（Level 1 独占性）**：
   - 状态指示行与右侧 `[Add Folder]`、`[Index Now]` 按钮**仅在一级（Home）展示**；下钻到二级、三级时整行彻底隐藏。
   - 极简状态文字验证：
     - 已完成：绿色 `checkCircle` + 绿色 `Indexed [Folder]`、`Indexed All Folders` 或 `Removed [Folder]`。
     - 进行中：次要色 `WorkbenchSpinner` + 次要色 `Indexing [Folder]`、`Indexing All Folders` 或 `Removing [Folder]`。
     - 失败：红色三角警告 `warning` + 红色 `Index Failed: [Folder]` 或 `Removal Failed: [Folder]`。
     - 闲置生命周期：离开一级界面（进入二三级或切去其它标签）再切回时，若当前无任务正在进行，统一恢复展示次要色 `arrowClockwise` + `Last Updated: yy-MM-dd HH:mm`；初次未操作展示 `Last Updated: --`。
   - 状态文字字重与右侧按钮文字字重均为 500 Medium，高度均为 40px，视觉完全对称平衡。

3. **三级卡片规范**：
   - 一级卡片展示目录名与完整路径（以 `/` 开头），操作按钮为 `[Rename Folder]`（Neutral，`pencilSimple`）与 `[Remove]`（Destructive，`minusCircle`）。
   - 二级卡片展示子目录名与完整路径，操作按钮为 `[Rename Folder]`。
   - 三级卡片展示完整文件名与以 1024 进位计算的文件大小，操作按钮为 `[Rename Files]`。
   - 卡片底色在暗色模式下为 `--color-bg-dialog`（`#2F2F34`），边框为 1px `--color-border-control`。

4. **测试分工**：
   - 面包屑各级压栈/出栈流转、状态行显隐条件、空状态判断逻辑由自动化单元测试覆盖。
   - 视觉样式、字重对齐与深浅色模式切换由所有者人工验收。