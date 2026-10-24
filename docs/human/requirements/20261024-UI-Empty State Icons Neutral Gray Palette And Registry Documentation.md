# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/Empty State Icon Registry.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`

# 需求描述

1. **空状态双色调图标（`C-09.2 Empty State`）配色分层与灰阶调整（方案 C）**：
   - **搜索初始引导图标（`search-hint`）保留系统强调色**：搜索页未输入搜索词时（`输入搜索词以显示台词。`）属于正向输入引导而非「无数据/异常」，保留原系统强调色（Accent Color）双色调方案（卡片底板 `--color-empty-icon-search-card` `30%`、5 段文本线 `--color-empty-icon-search-line` `58%`、放大镜镜面 `--color-empty-icon-magnifier-fill` `22%`、放大镜外圈与手柄 `--color-card-icon-accent-foreground` `100%`）。
   - **其余 9 枚「无数据 / 失效」空状态图标整体切换为中性灰色系（方案 C）**：将 `search-no-results`、`video`、`excerpt`、`folder`、`folder-question`、`video-question`、`excerpt-question`、`subtitle-question`、`task-tray` 共 9 枚图标（覆盖其余 21 个空状态与边界失效场景）的基准色从系统强调色替换为**次要弱化文本中性灰（`--color-text-muted`：浅色模式 `#717171`，深色模式 `#979797`）**，避免空白占位图标抢夺界面核心交互元素的注意力（文件页卡片、远程目录浏览卡片、任务面板卡片 `36×36px` 及详情弹窗顶部 `40×40px` 双色调图标继续保留系统强调色不变）。
   - **中性灰透明度比例（方案 C）**：
     - **镂空角标内底（`--color-empty-icon-badge-fill`）**：`--color-text-muted` 透明度 `24%`（用于 `search-no-results` 放大镜镜面填充、右下角圆环 `?` 内部填充）。
     - **主体背景层（`--color-empty-icon-base`）**：`--color-text-muted` 透明度 `32%`（用于 `search-no-results` 卡片底板、文件夹前盖主体、视频框底板、字幕框底板、任务托盘底板）。
     - **中景过渡层（`--color-empty-icon-mid`）**：`--color-text-muted` 透明度 `52%`（用于文件夹后盖顶签、摘录单层圆角燕尾书签底板）。
     - **核心前景层（`--color-empty-icon-foreground`）**：`100%` `--color-text-muted`（用于 `search-no-results` 左上 `✕` 号与放大镜外圈手柄、视频播放三角、字幕两排横条、任务托盘凹槽分割线、圆环 `?` 外圈与问号）。

2. **新增空状态图标注册表文档并同步更新 UI 设计文档**：
   - 参考 `Icon Registry.md` 的结构，在 `docs/human/design/ui/` 下新建 `Empty State Icon Registry.md`，统一记录 10 枚 `68px` 空状态双色调图标的制作规格、尺寸与配色层次、造型结构、含义及在全界面 22 个空状态与边界失效场景中的使用位置。
   - 同步更新 `UI Index.md`、`UI Tokens.md` 与 `UI Components - Domain.md` 中的关联条目与颜色 Token。

# 验收标准

1. 搜索页未输入搜索词时的 `search-hint` 图标按系统强调色双色调（`30%` / `58%` / `22%` / `100%`）渲染；其余 21 个空状态与边界失效场景中的 9 枚 `68×68px` 空状态图标均按方案 C（基于浅色 `#717171` / 深色 `#979797` 的 `24%` / `32%` / `52%` / `100%` 中性灰阶层次）准确渲染。
2. 文件页卡片、远程目录浏览卡片、任务面板卡片（`36×36px`）及文件/文件夹/任务详情弹窗顶部图标（`40×40px`）保持系统强调色双色调样式不变。
3. `Empty State Icon Registry.md` 及关联 UI 设计文档与实际视觉表现完全一致。