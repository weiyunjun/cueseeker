# 版本

main

# 关联设计

- `docs/human/design/ui/Toast Usage Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **翻译错误与占位符显示修正**：
   - **表格表头**：Search 与 Excerpt 数据表格的 `Cues` 列表头，简/繁中文由「台词数 / 台詞數」修正为「台词 / 台詞」。
   - **单数统计文案**：Library 总览页的 `1 folder` 修正为「1 个文件夹 / 1 個資料夾」；Excerpt 总览页与卡片的 `1 list`、`1 cue`、`%d cues` 分别修正为「1 个摘录集 / 1 個摘錄集」、「1 条台词 / 1 條台詞」、「%d 条台词 / %d 條台詞」，消除数量为 1 时界面直接显示 `%d` 的问题并统一台词与摘录集术语。
   - **媒体库拦截提示**：`Cue Not in Library`、`Cues Not in Library`、`Folder Not in Library` 的繁体中文由「台詞不在資料庫中」、「檔案夾不在資料庫中」统一修正为「台詞不在媒體庫中」、「資料夾不在媒體庫中」。
   - **播放器音轨菜单**：播放器更多菜单中的 `Audio Track` 与 `Default Audio Track`，简/繁中文由「音频源 / 音訊來源」、「默认音频源 / 預設音訊來源」修正为「音轨 / 音軌」、「默认音轨 / 預設音軌」。
   - **快进 / 快退 HUD**：播放画面中央快进与快退提示在简/繁中文下本地化为「+ {N}秒 / - {N}秒」（英文保持 `+ {N}s / - {N}s`）。

2. **术语、量词与标点规范统一**：
   - **摘录集术语**：Excerpt 总览页的 `%d lists` 统一为「%d 个摘录集 / %d 個摘錄集」；Excerpt 详情页空状态 `This list is no longer in the library.` 统一为「该摘录集已不在媒体库中。 / 該摘錄集已不在媒體庫中。」。
   - **搜索结果与视频量词**：播放 HUD 中的 `Already at First Result`、`Already at Last Result` 简体中文统一使用量词「条」（「已经是第一条结果」、「已经是最后一条结果」）；播放器底栏上一部/下一部视频按钮 Tooltip（`Previous Video`、`Already at first video`、`Next Video`、`Already at last video`）繁体中文统一使用量词「部」（「上一部影片」、「已經是第一部影片」、「下一部影片」、「已經是最後一部影片」）。
   - **时长与文件名字段**：筛选弹窗与文件详情弹窗中的 `Duration` 繁体中文统一为「時長」；导出到 Anki 弹窗与任务详情弹窗中的 `File Name` 简体中文统一为「文件名」。
   - **任务状态名称**：任务面板卡片与任务详情弹窗中的 `In Progress` 统一为「进行中 / 進行中」，`Queued` 统一为「排队中 / 排隊中」。
   - **复制提示与单复数**：`Cue Text Copied`（Toast 与播放 HUD）补齐为「已复制台词文本 / 已拷貝台詞文字」；批量复制提示 `Deep Links Copied` 统一为「已复制 Deep Links / 已拷貝 Deep Links」。
   - **退出动作繁体用词**：`Exit`、`Exit Collage`、`Exit Fullscreen` 的繁体中文统一使用「退出」（「退出」、「退出長截圖」、「退出全螢幕」），与「退出選取」保持一致。
   - **文件详情关联分组**：字幕详情弹窗中展示配对视频的分组标题在简/繁中文下显示为「关联视频 / 關聯影片」（英文显示为 `Associated Video` 或保持与视频详情 `关联字幕 / 關聯字幕` 对称）。
   - **空状态与细节规范**：`No recent watching yet.` 修正为「还没有最近观看的视频。 / 尚無最近觀看的影片。」；`Return to Workbench` 精简为「返回工作台 / 返回工作台」；File 页面顶部状态栏中的中文冒号统一为全角「：」（无空格）；添加文件夹菜单与弹窗标题中的 `WebDav Folder` 统一为标准大写 `WebDAV Folder`（「WebDAV 文件夹 / WebDAV 資料夾」）；繁体中文 `正在編輯長截圖…` 的省略号统一为居中「⋯」（「正在編輯長截圖⋯」）。

# 验收标准

1. 在简体中文与繁体中文下，Search 与 Excerpt 表格第一列表头显示为「台词 / 台詞」；当 Library 仅有 1 个文件夹、Excerpt 仅有 1 个摘录集或 1 条台词时，统计与卡片徽章均正常显示数字 `1`（「1 个文件夹」、「1 个摘录集」、「1 条台词」），不再出现 `%d`。
2. 播放界面快进/快退 HUD 在简/繁中文下显示「+ {N}秒 / - {N}秒」，更多菜单显示「音轨 / 音軌」与「默认音轨 / 預設音軌」，各处 Toast、HUD、Tooltip、弹窗及状态栏的术语、量词与标点在英/简/繁三语下完全一致且切换语言实时生效。