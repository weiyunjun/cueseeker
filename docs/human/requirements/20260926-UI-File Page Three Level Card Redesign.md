# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

# 需求描述

## 1. 结构与层级架构
1. **融合 Index 与 Edit**：移除 File 页面顶部的 Index / Edit 标签，整合成统一的卡片流转界面。
2. **三级界面架构（数据库可视化）**：
   - **一级界面（Root 根目录列表）**：展示已入库根目录卡片。顶部保留说明文案、`[Add Folder]` 与 `[Index Now]` 操作按钮；保留状态区与无目录时的空状态引导。点击卡片下钻二级界面。
   - **二级界面（Subfolder 目录列表）**：展示所选根目录下所有已索引的子文件夹卡片。若根目录下直接存有音视频/字幕文件，以独立卡片展示。卡片后缀支持多语言：
     - English: `[Folder Name] (Direct Content)`
     - 简体中文: `[文件夹名]（根目录直属内容）`
     - 繁体中文: `[資料夾名]（根目錄直屬內容）`
     点击卡片下钻三级界面。
   - **三级界面（Files 文件流）**：按分组顺序从上到下展示所选文件夹内的音视频文件与字幕文件卡片，无需 Display Title 分组标题行。
3. **顶栏导航**：
   - 顶栏标题恒定为 `File`，不随层级变化。
   - 顶栏 `<`（后退）与 `>`（前进）按钮响应三级界面的下钻与返回。

## 2. 卡片布局与视觉规范
1. **卡片容器**：
   - 宽度自适应内容区域。
   - 内边距：四周等距 16px（`--spacing-4`）。
   - 圆角：8px（`--radius-control`）。
   - 边框：1px（`--border-width-control`，`--color-border-control`）。
   - 背景色：`--color-settings-group-bg`（Dark `#26262A`，Light `#F6F7F9`）。
   - 卡片垂直间距：12px（`--spacing-3`），去除卡片间的分割横线。
2. **对齐法则**：
   - 左侧图标、中间双行文本、右侧操作按钮统一**垂直居中对齐**。
   - 设计基准以两行文本各占 1 行对齐；所有文本强制完整展示、允许折行，多行时卡片沿垂直中心对称展开。
3. **左侧图标**：
   - 尺寸：31×31px（`--size-task-card-icon`，线宽 1.50px），颜色为 `--color-text-secondary`。
   - 映射：文件夹为 `folder`，视频为 `video`，字幕为 `subtitles`。
   - 图标与文本列间距：16px（`--spacing-4`）。

## 3. 各级内容与操作规则
1. **一级界面**：
   - Line 1：文件夹名称（14px 500 Medium，`--color-text-primary`）。
   - Line 2：完整绝对路径（12px 400 Regular，`--color-text-muted`）。
   - 右侧操作按钮：`[Rename]` 与 `[Remove]`（破坏性样式），按钮之间间距 8px（`--spacing-2`）。
2. **二级界面**：
   - Line 1：子文件夹名称（14px 500 Medium，`--color-text-primary`）。
   - Line 2：完整绝对路径（12px 400 Regular，`--color-text-muted`）。
   - 右侧操作按钮：`[Rename]`。
3. **三级界面**：
   - Line 1：完整文件名（含后缀，14px 500 Medium，`--color-text-primary`）。
   - Line 2：文件大小（12px 400 Regular，`--color-text-muted`）。
     - 数据来源：直接读取数据库中已索引的 `file_size`。
     - 进位与格式：以 1024 进位，展示为 B / KB / MB / GB，保留 2 位小数（如 `1.43 GB`、`102.35 KB`）。
   - 交互规则：卡片本身仅作信息展示，点击不触发视频播放。
   - 右侧操作按钮：`[Rename]`，触发原有音视频与字幕整组同步改名。
4. **异常空状态与多语言文案**：
   - 若三级界面内容被移出库或为空时，展示空状态文案：
     - English: `No items in this folder are in the library.`
     - 简体中文: `此文件夹中没有仍在媒体库中的项目。`
     - 繁体中文: `此資料夾中沒有仍在媒體庫中的項目。`

# 验收

1. **界面结构与路由**：
   - File 顶部 Index/Edit 标签已移除，顶栏标题恒为 `File`。
   - 点击一级卡片下钻二级子目录，点击二级卡片下钻三级文件流；顶栏 `<` 和 `>` 历史导航按钮可精确流转各级。
2. **卡片布局与文本对齐**：
   - 卡片内边距（16px）、圆角（8px）、间距（12px）、底色（`--color-settings-group-bg`）与左侧图标（31×31px，folder/video/subtitles）严格符合规范，无横向分割线。
   - 左侧图标、中间文本与右侧按钮垂直居中对齐；长路径与长文件名强制完整换行展示，不出现省略截断。
3. **文件大小展示**：
   - 三级界面直接基于数据库 `file_size` 渲染，以 1024 进位并保留 2 位小数展示（如 `1.43 GB`、`102.35 KB`），无磁盘 I/O 阻塞。
4. **改名与删除操作**：
   - 一级界面的 `[Rename]` 与 `[Remove]`、二级/三级界面的 `[Rename]` 按钮均能正常唤起弹窗；三级改名保持整组（视频与同名字幕）同步改名。
5. **空状态与多语言验证**：
   - 以 `CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker` 启动：在三级界面打开期间，后台若将该目录内容移出库，三级界面能正确刷新展示空状态文案（验证 English、简体中文、繁体中文三套语言切换）。
6. **测试分工**：
   - 视觉与端到端交互由所有者人工验收。
   - 路由状态历史压栈/出栈、1024 进位格式化逻辑、数据库字段提取映射等由自动化单元测试覆盖。