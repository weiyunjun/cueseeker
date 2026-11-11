# 说明

1. 本文档由人类维护，记录全界面空状态与边界失效态（`C-09.2 Empty State`）双色调图标的视觉内容：制作规格、尺寸与灰阶层次、图标名录与使用位置。
2. 图标在各位置的尺寸与颜色由 `/docs/human/design/ui/UI Tokens.md` 及 `/docs/human/design/ui/UI Components - Domain.md` 中 `C-09.2 Empty State` 的 token 决定。

# 1. 制作规格

- 画布：256×256
- 风格：无外边框同色系双色调（Duotone）大图标，通过同色系不同透明度区分前后层次：
  - 操作引导图标（`search-hint`、`collage-hint`、`excerpt-hint`、`folder-hint`）：基准色取系统强调色（`macOS accent color`）
  - 其余 9 枚空状态与失效态图标：基准色取次要弱化文本中性灰 `--color-text-muted`（Light `#717171`；Dark `#979797`）
- 线端与拐角：内部线条、`✕` 号、托盘凹槽折线与 `?` 号均采用圆线端、圆拐角
- 镂空叠加：右下角叠加的放大镜与圆环 `?` 角标，均先以圆形（及放大镜手柄）镂空遮罩裁切底层图形，再绘制角标内底与前景描边，透出所在表面的真实背景色

# 2. 尺寸与配色层次

## 2.1 尺寸

| 尺寸 | Token | 适用范围 |
| --- | --- | --- |
| 68px | `--size-empty-state-icon` | 全界面 `C-09.2 Empty State` 顶部居中图标 |

## 2.2 操作引导强调色层次（`search-hint`、`collage-hint`、`excerpt-hint`、`folder-hint`）

| 层次 | Token | 颜色与透明度 | 适用部位 |
| --- | --- | --- | --- |
| 放大镜镜面 | `--color-empty-icon-magnifier-fill` | `macOS accent color` Alpha `0.22` | `search-hint` 右下角放大镜镜面填充 |
| 主体卡片底板 | `--color-empty-icon-search-card` | `macOS accent color` Alpha `0.30` | `search-hint` 圆角卡片底板、`collage-hint` 左下前景相框底板 |
| 文件夹前盖主体 | `--color-card-icon-accent-base` | `macOS accent color` Alpha `0.32` | `folder-hint` 圆角矩形前盖主体 |
| 后景叠层 / 书签底板 | `--color-empty-icon-collage-back` | `macOS accent color` Alpha `0.52` | `collage-hint` 右上后景叠层圆角框、`excerpt-hint` 单层圆角燕尾书签底板 |
| 文件夹后盖顶签 | `--color-card-icon-accent-folder-tab` | `macOS accent color` Alpha `0.52` | `folder-hint` 左上后盖顶签 |
| 次要前景层 | `--color-empty-icon-search-line` | `macOS accent color` Alpha `0.58` | `search-hint` 卡片内部 5 段水平文本线、`collage-hint` 左上太阳圆点 |
| 核心前景层 | `--color-card-icon-accent-foreground` | `macOS accent color`（`100%`） | `search-hint` 放大镜外圈与手柄、`collage-hint` 底部双峰山脉剪影 |

## 2.3 空状态与失效态灰阶层次（其余 9 枚图标）

| 层次 | Token | 颜色与透明度 | 适用部位 |
| --- | --- | --- | --- |
| 镂空角标内底 | `--color-empty-icon-badge-fill` | `--color-text-muted` Alpha `0.24` | `search-no-results` 放大镜镜面填充、右下角圆环 `?` 内部填充 |
| 主体背景层 | `--color-empty-icon-base` | `--color-text-muted` Alpha `0.32` | `search-no-results` 卡片底板、文件夹前盖主体、视频框底板、字幕框底板、任务托盘底板 |
| 中景过渡层 | `--color-empty-icon-mid` | `--color-text-muted` Alpha `0.52` | 文件夹左上后盖顶签、摘录单层圆角燕尾书签底板 |
| 核心前景层 | `--color-empty-icon-foreground` | `--color-text-muted`（`100%`） | `search-no-results` 左上 `✕` 号与放大镜外圈手柄、视频播放三角、字幕两排横条、任务托盘凹槽分割线、圆环 `?` 外圈与问号 |

# 3. 图标名录

## 3.1 搜索与列表空状态

| 图标 | 造型结构 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `search-hint` | 强调色圆角卡片底板（`search-card`）+ 5 段水平文本线（`search-line`）+ 右下镂空放大镜（镜面 `magnifier-fill`，外圈与手柄 `accent-foreground`） | 搜索提示（未输入搜索词） | Search Page（未输入搜索词） |
| `collage-hint` | 右上后景叠层圆角框（`collage-back`，被前景框带间隙镂空裁切）+ 左下前景相框底板（`search-card`）+ 左上太阳圆点（`search-line`）+ 底部双峰山脉剪影（`accent-foreground`） | 长截图提示（未勾选任何字幕） | Playback Overlay / Collage（未勾选任何字幕） |
| `excerpt-hint` | 强调色单层圆角燕尾书签底板（`collage-back`） | 摘录集创建引导（已有文件夹且无任何摘录集） | Excerpt List Overview（已有已入库文件夹且无任何摘录集） |
| `folder-hint` | 强调色左上后盖顶签（`accent-folder-tab`）+ 圆角矩形前盖主体（`accent-base`） | 文件夹添加与前往引导（无任何已入库文件夹） | File Page / Level 1（无根文件夹空状态）；Search Page、Library Overview、Excerpt List Overview（无摘录集）、Recent Page / Videos 与 Excerpt Lists、Command Panel Secondary / Recent Videos 与 Recent Excerpt Lists（无任何已入库文件夹且当前列表为空） |
| `search-no-results` | 圆角卡片底板（`base`）+ 左上圆头 `✕` 号（`foreground`）+ 右下镂空放大镜（镜面 `badge-fill`，外圈与手柄 `foreground`） | 搜索或筛选无结果 | Search Page（搜索或筛选无结果）；Library Overview（搜索无结果）；Excerpt List Overview（搜索无结果）；Excerpt List Detail（搜索或筛选无结果）；Command Panel Secondary / Search Results（搜索或筛选无结果） |
| `video` | 圆角矩形视频框底板（`base`）+ 居中实心圆角播放三角（`foreground`） | 暂无视频内容 | Recent Page / Videos（已有已入库文件夹但为空）；Library Overview（已有已入库文件夹但为空）；Library Folder Detail（文件夹内无剧集）；Command Panel Secondary / Recent Videos（已有已入库文件夹但为空） |
| `excerpt` | 单层圆角燕尾书签底板（`mid`） | 暂无摘录内容 | Recent Page / Excerpts（已有已入库文件夹且无任何摘录集）；Excerpt List Detail（列表无有效摘录）；Command Panel Secondary / Recent Excerpt Lists（已有已入库文件夹且无任何摘录集） |
| `folder` | 左上后盖顶签（`mid`）+ 圆角矩形前盖主体（`base`） | 目录为空 | File Page / Level 2（根文件夹内无已入库内容）；WebDAV / SMB / FTP / NFS Folder Dialog Step 2（子目录为空） |
| `task-tray` | 圆角矩形托盘底板（`base`）+ 中下部内凹折线分割线（`foreground`） | 暂无任务 | Task Panel / Current（无进行中任务）；Task Panel / Completed（无已完成任务）；Task Panel / Incomplete（无未完成任务） |

## 3.2 边界失效与加载失败状态

| 图标 | 造型结构 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `folder-question` | `folder` + 右下镂空圆环 `?` 角标（内底 `badge-fill`，外圈与问号 `foreground`） | 文件夹已不在库中或子目录加载失败 | File Page / Level 2、Level 3（所属根文件夹已不在媒体库中）；File Page / Level 3（子文件夹因内容清空重新索引而失效变空）；WebDAV / SMB / FTP / NFS Folder Dialog Step 2（子目录加载失败） |
| `video-question` | `video` + 右下镂空圆环 `?` 角标（内底 `badge-fill`，外圈与问号 `foreground`） | 视频所属文件夹或视频播放列表已失效 | Library Folder Detail（所属文件夹已不在媒体库中或加载失败）；Playback Overlay / Playlist（Video Playlist 全部视频已不在媒体库中） |
| `excerpt-question` | `excerpt` + 右下镂空圆环 `?` 角标（略微右移保留燕尾缺口；内底 `badge-fill`，外圈与问号 `foreground`） | 摘录列表已不在库中 | Excerpt List Detail（当前摘录列表已不在媒体库中） |
| `subtitle-question` | 圆角矩形字幕框底板（`base`）+ 两排圆头实心字幕横条（`foreground`）+ 右下镂空圆环 `?` 角标（内底 `badge-fill`，外圈与问号 `foreground`） | 当前字幕或字幕播放列表已失效 | Playback Overlay / Current（当前字幕已不在媒体库中）；Playback Overlay / Playlist（Subtitle Playlist 全部条目已不在媒体库中） |