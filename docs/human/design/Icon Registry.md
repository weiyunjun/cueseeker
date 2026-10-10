# 说明
1. 本文档由人类维护，记录界面图标的视觉内容：制作规格、尺寸与线宽、图标名录。图标来自 Phosphor（MIT）。
2. 图标在各位置的尺寸与颜色由 /docs/human/design/UI Design System.md 中对应组件的 token 决定；没有对应 token 的位置，在名录中直接注明尺寸。

# 1. 制作规格

- 画布：256×256
- 绘制：按中心线描边，保留描边，不做轮廓化
- 线宽：母版为 16，显示时的线宽见「尺寸与线宽」
- 线端与拐角：圆线端、圆拐角
- 实心圆点：半径 4 的圆，加同宽描边，随线宽变化
- Fill：实心状态变体，不含线条，不参与线宽表
- 自制图标遵循同一规格；本身即实心的自制图标以填充加同宽描边绘制，随线宽变化

# 2. 尺寸与线宽

尺寸指图标方框，Phosphor 图形位于方框中部约四分之三。表中未列出的尺寸不得使用。需要偏离线宽表的图标在此单列，目前没有。

| 尺寸 | 线宽 |
| --- | --- |
| 12px | 1.15px |
| 14px | 1.15px |
| 16px | 1.20px |
| 18px | 1.30px |
| 20px | 1.30px |
| 21px | 1.35px |
| 23px | 1.40px |
| 31px | 1.50px |
| 42px | 1.90px |
| 47px | 2.10px |
| 57px | 2.50px |

# 3. 图标名录

字重：Regular 为描边图标，线宽按尺寸取值；Fill 为实心状态变体；实心为没有描边字重的实心图标。

## 3.1 结构与导航

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `caret-left` | Regular | 后退、返回、快退 | App Topbar / Back；Player Topbar、Playback Topbar / Return Action；Playback Feedback（快退） |
| `caret-right` | Regular | 前进、展开、快进 | App Topbar / Forward；Submenu Trigger / Submenu Indicator；Library File Tree 折叠态；Playback Feedback（快进）；File Page / Breadcrumb 分隔符，12px |
| `caret-down` | Regular | 已展开 | Library File Tree 展开态 |
| `sidebar-simple` | Regular | 折叠、展开 Sidebar | Sidebar Toggle |
| `arrow-left` | Regular | 返回上一级 | Command Panel Secondary / Back Action |
| `arrow-right` | Regular | 送往列表 | 表格行菜单 / Save to Excerpt List、Move to ...、Duplicate to ... |
| `x` | Regular | 关闭、清除、移除 | Icon Button / Inline Clear；Icon Button / Dialog Close；Task Card / Remove Action |
| `check` | Regular | 已选 | Radio Menu Item |
| `magnifying-glass` | Regular | 搜索 | Search Field；Sidebar Item / Search；Command Panel Root / Search Action；Playback Overlay 选中文字菜单 / Search Selected Text |
| `funnel` | Regular | 筛选 | Search / Excerpt Toolbar / Filter Trigger |
| `arrow-elbow-down-left` | Regular | 回车键 | Keycap / `Return`，16px |

## 3.2 页面与入口

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `squares-four` | Regular | Library | Sidebar Item / Library |
| `folder` | Regular | 文件夹 | Sidebar Item / File；表格行菜单 / Open Subtitle Folder；Library 卡片菜单 / Open Folder；Library File Tree / Root Path、Object Folder；Export to Anki Dialog / Location；File Page 空状态，47px |
| `bookmark-simple` | Regular | Excerpt | Sidebar Item / Excerpt；Command Panel Root / Recent Excerpt Lists；表格行菜单 / Remove Excerpt；Playback Feedback（移出 Excerpt）；Excerpt List 封面占位，57px |
| `bookmark-simple` | Fill | 已存入 Excerpt | Playback Feedback（Save to Excerpt List） |
| `clock` | Regular | 最近、时长 | Sidebar Item / Recent；Filter Menu / Duration |
| `gear` | Regular | 设置 | Settings Entry |
| `tray` | Regular | 任务 | Task Entry |

## 3.3 文件与索引

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `folder-plus` | Regular | 添加文件夹 | File Page / Add Folder |
| `arrow-clockwise` | Regular | 重新索引、刷新 | File Page / Index Now、闲置状态；Settings / Maintenance、Developer 刷新 |
| `minus-circle` | Regular | 移除 | File Page / Root Folder Row / Remove |
| `minus-circle` | Fill | 半选 | Checkbox / Indeterminate |
| `stack` | Regular | 剧集 | Library File Tree / Display Title |
| `video` | Regular | 视频 | Library File Tree / Video；Command Panel Root / Recent Videos；Library 封面占位，57px |
| `subtitles` | Regular | 字幕 | Library File Tree / Subtitle；播放控制条 / 字幕；Playback Feedback（字幕开关）；Settings / Subtitle |

## 3.4 状态与提示

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `warning` | Regular | 警告、失败 | File Page / Index Status（失败）；Settings / Maintenance（失败）；Player Error Banner（视频加载失败、字幕加载失败、播放器其它错误、播放或打开不在数据库中的项）；Playback Feedback（无字幕、不在数据库中）；Toast（台词不在媒体库中） |
| `warning-circle` | Regular | 建议压缩数据库 | Settings / Maintenance |
| `check-circle` | Regular | 成功、已看完 | File Page / Index Status（成功）；Settings / Maintenance（成功）；Library 卡片菜单 / Mark as Finished |
| `check-circle` | Fill | 已选 | Checkbox / Checked |
| `circle` | Regular | 未看、未选 | Library 卡片菜单 / Mark as Unwatched；Checkbox / Unchecked |
| `play-circle` | Regular | 在看 | Library 卡片菜单 / Mark as Watching |
| `clock-counter-clockwise` | Regular | 字幕内容已变更 | Cue State Indicator / Content Changed，18px |
| `question` | Regular | 条目不可用 | Cue State Indicator / Unavailable，18px |

## 3.5 编辑与操作

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `pencil-simple` | Regular | 重命名、编辑封面 | Library File Tree 菜单 / Rename Folder、Rename Files；Cover / Editor Action |
| `note-pencil` | Regular | 编辑 | Excerpt List 卡片菜单 / Edit List |
| `plus` | Regular | 新建、添加 | Excerpt List Overview / New List |
| `list-checks` | Regular | 选择模式 | 预留，暂无使用位置 |
| `dots-six-vertical` | Regular | 拖拽手柄 | Export to Anki Dialog / Card Item Handle，12px |
| `sign-out` | Regular | 退出选择 | Search / Excerpt Toolbar / Exit Selection |
| `images-square` | Regular | 截图组 | Playback Topbar / Collage Action |
| `trash` | Regular | 删除 | Excerpt List 卡片菜单 / Delete List；Task Card / Delete Action |
| `copy` | Regular | 复制 | 表格行菜单 / Copy Cue Text、Copy Cue Group Text、Copy Time Range；Collage Editor / Copy；Playback Overlay 选中文字菜单 / Copy Selected Text |
| `export` | Regular | 导出、更换封面 | Collage Editor / Export；Library 卡片菜单 / Change Cover |
| `link-simple` | Regular | 链接 | 表格行菜单 / Copy Deep Link；Anki 卡片 / Deep Link，20px |
| `info` | Regular | 简介、详情 | File Page 卡片菜单 / Get Info |
| `anki-star` | 实心 | Anki | 预留，暂无使用位置 |

## 3.6 播放控制

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `play` | Fill | 播放 | 播放控制条 / 播放暂停；Cover Summary / Resume or Play；表格行菜单 / Play；Settings / Play；Playback Feedback |
| `pause` | Fill | 暂停 | 播放控制条 / 播放暂停；Playback Feedback（暂停、自动暂停） |
| `skip-back` | Fill | 上一个 | 播放控制条 / 上一个 |
| `skip-forward` | Fill | 下一个 | 播放控制条 / 下一个 |
| `repeat` | Regular | 循环 | 播放控制条 / 循环；Playback Feedback |
| `camera` | Regular | 截图 | 播放控制条 / 截图；Playback Feedback（截图已复制） |
| `speedometer` | Regular | 倍速 | Playback Feedback（倍速） |
| `corners-out` | Regular | 进入全屏 | 播放控制条 / 全屏 |
| `corners-in` | Regular | 退出全屏 | 播放控制条 / 全屏 |
| `dots-three-vertical` | Regular | 更多 | 播放控制条 / More |
| `speaker-x` | Regular | 静音 | Player Volume Control；Playback Feedback |
| `speaker-low` | Regular | 音量降低 | Playback Feedback |
| `speaker-high` | Regular | 有声、音量升高 | Player Volume Control；Playback Feedback |

## 3.7 筛选与设置

| 图标 | 字重 | 含义 | 使用位置 |
| --- | --- | --- | --- |
| `text-aa` | Regular | 字符数 | Filter Menu / Character |
| `globe` | Regular | 语言 | Filter Menu / Language |
| `eye` | Regular | 观看状态 | Filter Menu / Watch Status |
| `gear-fine` | Regular | 通用 | Settings / General |
| `hard-drives` | Regular | 维护 | Settings / Maintenance |
| `hammer` | Regular | 开发者 | Settings / Developer |
| `file-arrow-down` | Regular | 压缩数据库 | Settings / Maintenance / Compact |
| `keyboard` | Regular | 快捷键 | Settings / Shortcuts |
| `arrow-counter-clockwise` | Regular | 恢复默认 | Settings / Shortcuts / Restore Default；Settings / Subtitle / Restore Defaults |