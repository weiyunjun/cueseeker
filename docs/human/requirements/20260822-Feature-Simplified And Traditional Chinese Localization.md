# 版本

main

# 需求描述

1. CueSeeker 增加界面语言支持，支持 English、简体中文、繁體中文三种界面语言。CueSeeker 的中文产品名为「字幕求索」。

2. 设置窗口新增「语言」分类，图标使用地球图标，在设置分类列表中位于「搜索」之下、「Deep Link」之上。分类内含一个下拉选择框，选项自上而下为：跟随系统、English、简体中文、繁體中文。默认值为「跟随系统」。跟随系统时按系统偏好语言匹配，匹配不到时回落 English。

3. 语言选项名称按惯例以各自语言书写，在三种界面语言下显示一致；只有「跟随系统」随当前界面语言变化。

4. 切换语言即时生效，不需要重启。菜单栏、顶栏、侧栏与当前页面必须同步更新。

5. 本需求覆盖：菜单栏、顶栏与侧栏、空状态与信息页、表格（列头 / 工具条 / 行状态 / 行右键菜单）、筛选面板、媒体库与封面编辑、Shiori、Toast、Data 页、播放全部界面、设置各分类、导出、运行状态与错误提示。

6. 本需求不覆盖：诊断探针与端到端调试界面、日志文本、HTML 原型、Windows 端。这些保持英文。设置「开发者选项」分类的内部条目在本需求范围内，一并翻译。

7. 以下内容保持英文不翻译：Shiori、Anki、Deep Link、ffmpeg、SQLite、WAL、SHM、FTS、fts5vocab、JSONL、E2E；以及写入 Anki 导出数据的名称 `CueSeeker Media Recall`、`CueSeeker::`、`Audio`、`Image`、`Text`、`Card 1`、`Default`。翻译这些名称会破坏已有牌组的兼容性。

8. 底层抛出的技术错误文本（下表中的 `{reason}`、`{error}` 占位内容）本期不翻译，保持英文原样。

9. `Copy Deep Link(s)` 的英文原文一并改为 `Copy Deep Links`，使三种语言表达一致。

10. 中文没有单复数。英文保留现有单复数两条文案，中文两条译文相同，不引入复数规则文件。

11. 同一术语必须全局一致，以下方「术语基准」为准。

# 术语基准

| English | 简体中文 | 繁體中文 |
|---|---|---|
| CueSeeker | 字幕求索 | 字幕求索 |
| Shiori | Shiori | Shiori |
| Anki | Anki | Anki |
| Deep Link | Deep Link | Deep Link |
| Cue | 台词 | 台詞 |
| Cue Group | 台词组 | 台詞組 |
| Collage | 长截图 | 長截圖 |
| Library | 媒体库 | 媒體庫 |
| Database | 数据库 | 資料庫 |
| Search | 搜索 | 搜尋 |
| Playback | 播放 | 播放 |
| Settings | 设置 | 設定 |
| Folder | 文件夹 | 資料夾 |
| File | 文件 | 檔案 |
| Video | 视频 | 影片 |
| Bookmark | 书签 | 書籤 |
| Save | 保存 | 儲存 |
| Export | 导出 | 匯出 |
| Fullscreen | 全屏 | 全螢幕 |
| Copy | 复制 | 拷貝 |

系统菜单栏的「编辑」菜单沿用 macOS 官方译法，简体使用「拷贝 / 粘贴」；应用界面内的 Copy 一律使用「复制」。

# 文案对照

## 菜单栏

| English | 简体中文 | 繁體中文 |
|---|---|---|
| CueSeeker | 字幕求索 | 字幕求索 |
| Settings... | 设置… | 設定⋯ |
| Quit CueSeeker | 退出字幕求索 | 結束字幕求索 |
| Edit | 编辑 | 編輯 |
| Undo | 撤销 | 還原 |
| Redo | 重做 | 重做 |
| Cut | 剪切 | 剪下 |
| Copy | 拷贝 | 拷貝 |
| Paste | 粘贴 | 貼上 |
| Delete | 删除 | 刪除 |
| Select All | 全选 | 全選 |
| Window | 窗口 | 視窗 |
| Minimize | 最小化 | 縮到最小 |
| Zoom | 缩放 | 縮放 |
| Bring All to Front | 前置全部窗口 | 將所有視窗移至最前 |

## 顶栏 / 侧栏 / 标题栏

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Back | 返回 | 返回 |
| Hide Sidebar | 隐藏边栏 | 隱藏側邊欄 |
| Show Sidebar | 显示边栏 | 顯示側邊欄 |
| Collapse | 折叠 | 收合 |
| Expand | 展开 | 展開 |
| Library | 媒体库 | 媒體庫 |
| Shiori | Shiori | Shiori |
| Recent | 最近 | 最近 |
| Data | 数据 | 資料 |
| Search | 搜索 | 搜尋 |
| Recent Videos | 最近视频 | 最近影片 |
| Recent Shioris | 最近 Shiori | 最近 Shiori |
| Settings | 设置 | 設定 |
| Maximize | 最大化 | 最大化 |
| Minimize | 最小化 | 縮到最小 |
| Activate | 激活 | 啟用 |

## 空状态与信息页

| English | 简体中文 | 繁體中文 |
|---|---|---|
| No Search Query | 未输入搜索词 | 未輸入搜尋字詞 |
| Searching | 搜索中 | 搜尋中 |
| Search Failed | 搜索失败 | 搜尋失敗 |
| No Results | 没有结果 | 沒有結果 |
| No Library | 媒体库为空 | 媒體庫為空 |
| Loading Library | 正在加载媒体库 | 正在載入媒體庫 |
| Library Failed | 媒体库加载失败 | 媒體庫載入失敗 |
| No Videos | 没有视频 | 沒有影片 |
| No Shiori | 没有 Shiori | 沒有 Shiori |
| Type a query in the topbar Search field to start searching. | 在顶栏搜索框中输入内容即可开始搜索。 | 在頂列搜尋欄位中輸入內容即可開始搜尋。 |
| Looking through indexed subtitle text. | 正在检索已索引的字幕文本。 | 正在檢索已索引的字幕文字。 |
| No indexed subtitle entries matched this query. | 没有已索引的字幕条目匹配该搜索词。 | 沒有已索引的字幕項目符合此搜尋字詞。 |
| Add subtitle folders in CueSeeker > Settings..., then reindex. | 请在“字幕求索 > 设置…”中添加字幕文件夹，然后重新索引。 | 請在「字幕求索 > 設定⋯」中加入字幕資料夾，然後重新索引。 |
| Reading indexed videos. | 正在读取已索引的视频。 | 正在讀取已索引的影片。 |
| Reindex subtitle folders to populate Library videos. | 重新索引字幕文件夹以填充媒体库视频。 | 重新索引字幕資料夾以填入媒體庫影片。 |
| Save subtitles from playback to collect Shiori. | 在播放时保存字幕即可收集 Shiori。 | 在播放時儲存字幕即可收集 Shiori。 |
| Save cues from playback to collect Shiori. | 在播放时保存台词即可收集 Shiori。 | 在播放時儲存台詞即可收集 Shiori。 |
| Enter a search term to show cues. | 输入搜索词以显示台词。 | 輸入搜尋字詞以顯示台詞。 |
| No indexed content. | 没有已索引的内容。 | 沒有已索引的內容。 |
| No episodes yet. | 还没有剧集。 | 尚無單集。 |
| No recent watching yet. | 还没有最近观看。 | 尚無最近觀看。 |
| No recent Shioris yet. | 还没有最近的 Shiori。 | 尚無最近的 Shiori。 |
| No library videos yet. | 还没有媒体库视频。 | 尚無媒體庫影片。 |

## 表格：列头、工具条、行状态

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Date Added | 添加日期 | 加入日期 |
| Name | 名称 | 名稱 |
| Display Title | 显示标题 | 顯示標題 |
| Time Range | 时间范围 | 時間範圍 |
| Cues | 台词数 | 台詞數 |
| Language | 语言 | 語言 |
| Sort Ascending | 升序排序 | 遞增排序 |
| Sort Descending | 降序排序 | 遞減排序 |
| Filter | 筛选 | 篩選 |
| Select | 选择 | 選取 |
| Exit Select | 退出选择 | 結束選取 |
| Anki | Anki | Anki |
| Copy Deep Links | 复制 Deep Links | 拷貝 Deep Links |
| Copy Table | 复制表格 | 拷貝表格 |
| Search cues by name, lyrics, or keywords... | 按名称、台词或关键词搜索… | 依名稱、台詞或關鍵字搜尋⋯ |
| 1 result | 1 条结果 | 1 筆結果 |
| {n} results | {n} 条结果 | {n} 筆結果 |
| {n} selected | 已选 {n} 项 | 已選取 {n} 項 |
| Play | 播放 | 播放 |
| Copy | 复制 | 拷貝 |
| Content Changed | 内容已变更 | 內容已變更 |
| Unavailable | 不可用 | 無法使用 |
| Previous | 变更前 | 變更前 |
| Current | 当前 | 目前 |
| This cue changed after reindexing. | 该台词在重新索引后发生了变化。 | 此台詞在重新索引後已變更。 |
| The library source is currently unavailable. | 媒体库来源当前不可用。 | 媒體庫來源目前無法使用。 |
| The video file is missing. The subtitle file is still available. | 视频文件缺失，字幕文件仍然可用。 | 影片檔案遺失，字幕檔案仍可使用。 |
| The subtitle file is missing or could not be reconnected. | 字幕文件缺失或无法重新连接。 | 字幕檔案遺失或無法重新連接。 |
| This cue could not be found in the current subtitle file. | 在当前字幕文件中找不到该台词。 | 在目前的字幕檔案中找不到此台詞。 |

## 行右键菜单

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Play | 播放 | 播放 |
| Open Subtitle Folder | 打开字幕文件夹 | 打開字幕資料夾 |
| Copy Cue Text | 复制台词文本 | 拷貝台詞文字 |
| Copy Deep Link | 复制 Deep Link | 拷貝 Deep Link |
| Copy Cue Group Text | 复制台词组文本 | 拷貝台詞組文字 |
| Copy Time Range | 复制时间范围 | 拷貝時間範圍 |
| Move to ... | 移动到… | 移動至⋯ |
| Duplicate to ... | 复制到… | 複製至⋯ |
| Remove Shiori | 移除 Shiori | 移除 Shiori |

## 筛选面板

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Duration | 时长 | 時間長度 |
| Character | 字符数 | 字元數 |
| Language | 语言 | 語言 |
| Watch Status | 观看状态 | 觀看狀態 |
| Calculating | 计算中 | 計算中 |
| <1s | <1 秒 | <1 秒 |
| 1–2.999s | 1–2.999 秒 | 1–2.999 秒 |
| 3–4.999s | 3–4.999 秒 | 3–4.999 秒 |
| ≥5s | ≥5 秒 | ≥5 秒 |
| 1–10 / 11–20 / 21–30 / 31+ | 保持原样 | 保持原样 |
| English | 英语 | 英語 |
| Japanese | 日语 | 日語 |
| Chinese | 中文 | 中文 |
| Simplified Chinese | 简体中文 | 簡體中文 |
| Traditional Chinese | 繁体中文 | 繁體中文 |
| Unknown | 未知 | 未知 |
| Finished | 已看完 | 已看完 |
| Watching | 观看中 | 觀看中 |
| Unwatched | 未观看 | 未觀看 |
| Selected | 已选中 | 已選取 |
| Not selected | 未选中 | 未選取 |

## 媒体库

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Library | 媒体库 | 媒體庫 |
| Add Content | 添加内容 | 加入內容 |
| Play | 播放 | 播放 |
| Resume | 继续播放 | 繼續播放 |
| Resume {n} / {total} | 继续 {n} / {total} | 繼續 {n} / {total} |
| Open Folder | 打开文件夹 | 打開資料夾 |
| Change Cover | 更换封面 | 更換封面 |
| Mark as Finished | 标记为已看完 | 標示為已看完 |
| Mark as Unwatched | 标记为未观看 | 標示為未觀看 |
| Mark as Watching | 标记为观看中 | 標示為觀看中 |
| Mark All as Finished | 全部标记为已看完 | 全部標示為已看完 |
| Mark All as Unwatched | 全部标记为未观看 | 全部標示為未觀看 |
| Mark All as Watching | 全部标记为观看中 | 全部標示為觀看中 |
| 1 episode | 1 集 | 1 集 |
| {n} episodes | {n} 集 | {n} 集 |
| Episode {n} | 第 {n} 集 | 第 {n} 集 |
| Playing {n} | 正在播放第 {n} 集 | 正在播放第 {n} 集 |
| {a} Folders · {b} Videos · {c} Subtitles | {a} 个文件夹 · {b} 个视频 · {c} 个字幕 | {a} 個資料夾 · {b} 部影片 · {c} 個字幕 |
| {a} videos {b} subtitles | {a} 个视频 {b} 个字幕 | {a} 部影片 {b} 個字幕 |
| Recent Videos | 最近视频 | 最近影片 |
| Recent Shioris | 最近 Shiori | 最近 Shiori |
| Recent | 最近 | 最近 |
| Covers | 封面 | 封面 |
| Edit Cover | 编辑封面 | 編輯封面 |
| Choose Image | 选择图片 | 選擇圖片 |
| Choose Cover Image | 选择封面图片 | 選擇封面圖片 |
| Support: JPG, JPEG, PNG, and GIF no more than 20 MB. | 支持 JPG、JPEG、PNG 和 GIF，且不超过 20 MB。 | 支援 JPG、JPEG、PNG 與 GIF，且不超過 20 MB。 |
| Cover crop editor | 封面裁剪编辑器 | 封面裁切編輯器 |
| Cancel | 取消 | 取消 |
| Save | 保存 | 儲存 |

## Shiori

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Shiori | Shiori | Shiori |
| {a} Lists · {b} Cues | {a} 个列表 · {b} 条台词 | {a} 個列表 · {b} 條台詞 |
| {n} Cues | {n} 条台词 | {n} 條台詞 |
| {n} shioris | {n} 个 Shiori | {n} 個 Shiori |
| {n} videos | {n} 个视频 | {n} 部影片 |
| New List | 新建列表 | 新增列表 |
| Edit List | 编辑列表 | 編輯列表 |
| Delete List | 删除列表 | 刪除列表 |
| Create | 创建 | 建立 |
| Save | 保存 | 儲存 |
| Cancel | 取消 | 取消 |
| Delete | 删除 | 刪除 |
| Remove | 移除 | 移除 |
| List Name | 列表名称 | 列表名稱 |
| Enter a list name | 输入列表名称 | 輸入列表名稱 |
| Description | 描述 | 描述 |
| Add a description (optional) | 添加描述（可选） | 加入描述（選填） |
| Enter a list name. | 请输入列表名称。 | 請輸入列表名稱。 |
| List name must be 30 characters or fewer. | 列表名称不能超过 30 个字符。 | 列表名稱不能超過 30 個字元。 |
| Description must be 100 characters or fewer. | 描述不能超过 100 个字符。 | 描述不能超過 100 個字元。 |
| A list with this name already exists. | 已存在同名列表。 | 已有同名的列表。 |
| The list “{name}” and its Shiori entries will be deleted. The original subtitle and video files will not be deleted. | 列表“{name}”及其中的 Shiori 条目将被删除。原始字幕和视频文件不会被删除。 | 列表「{name}」及其中的 Shiori 項目將被刪除。原始字幕與影片檔案不會被刪除。 |
| Remove Shiori | 移除 Shiori | 移除 Shiori |
| This cue will be removed from your Shiori. The original subtitle and video files will not be deleted. | 该台词将从你的 Shiori 中移除。原始字幕和视频文件不会被删除。 | 此台詞將從你的 Shiori 中移除。原始字幕與影片檔案不會被刪除。 |

## Toast

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Moved to “{list}” | 已移动到“{list}” | 已移動至「{list}」 |
| Duplicated to “{list}” | 已复制到“{list}” | 已複製至「{list}」 |
| The list is no longer available | 该列表已不存在 | 此列表已不存在 |
| Couldn’t move Shiori. Try again | 无法移动 Shiori，请重试 | 無法移動 Shiori，請重試 |
| Couldn’t duplicate Shiori. Try again | 无法复制 Shiori，请重试 | 無法複製 Shiori，請重試 |
| Shiori already exists in “{list}” | “{list}”中已存在该 Shiori | 「{list}」中已有此 Shiori |

## Data 页

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Data | 数据 | 資料 |
| Toggle | 展开/折叠 | 展開/收合 |
| Expanded | 已展开 | 已展開 |
| Collapsed | 已折叠 | 已收合 |

## 播放：控制条与窗口按钮

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Play | 播放 | 播放 |
| Pause | 暂停 | 暫停 |
| Previous video | 上一个视频 | 上一部影片 |
| Next video | 下一个视频 | 下一部影片 |
| Repeat | 循环 | 循環 |
| Copy screenshot | 复制截图 | 拷貝截圖 |
| Subtitles | 字幕 | 字幕 |
| Playback speed | 播放速度 | 播放速度 |
| Fullscreen | 全屏 | 全螢幕 |
| Mute | 静音 | 靜音 |
| Close video and return to results | 关闭视频并返回结果 | 關閉影片並返回結果 |
| Minimize playback | 最小化播放 | 縮小播放 |
| No video selected | 未选择视频 | 未選擇影片 |

## 播放：HUD 提示

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Cue Text Copied | 已复制台词 | 已拷貝台詞 |
| Selected Text Copied | 已复制选中文本 | 已拷貝選取文字 |
| Screenshot Copied | 已复制截图 | 已拷貝截圖 |
| Deep Link Copied | 已复制 Deep Link | 已拷貝 Deep Link |
| Copy Failed | 复制失败 | 拷貝失敗 |
| No Subtitle | 无字幕 | 沒有字幕 |
| Auto Pause | 自动暂停 | 自動暫停 |
| Repeat | 循环 | 循環 |
| Shiori Saved | 已保存 Shiori | 已儲存 Shiori |
| Shiori Already Saved | Shiori 已存在 | Shiori 已存在 |
| Shiori Removed | 已移除 Shiori | 已移除 Shiori |
| Previous Result | 上一条结果 | 上一筆結果 |
| Next Result | 下一条结果 | 下一筆結果 |
| No Result | 没有结果 | 沒有結果 |
| Previous Library Video | 上一个媒体库视频 | 上一部媒體庫影片 |
| Next Library Video | 下一个媒体库视频 | 下一部媒體庫影片 |
| No Library Video | 没有媒体库视频 | 沒有媒體庫影片 |
| Previous Bookmark | 上一个书签 | 上一個書籤 |
| Next Bookmark | 下一个书签 | 下一個書籤 |
| No Bookmark | 没有书签 | 沒有書籤 |
| Enter Fullscreen | 进入全屏 | 進入全螢幕 |
| Exit Fullscreen | 退出全屏 | 結束全螢幕 |
| Subtitles On | 字幕已开 | 字幕已開 |
| Subtitles Off | 字幕已关 | 字幕已關 |
| Muted | 已静音 | 已靜音 |

## 播放：字幕聚焦层、长截图、命令面板

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Copy Selected Text | 复制选中文本 | 拷貝選取文字 |
| Search Selected Text | 搜索选中文本 | 搜尋選取文字 |
| Collage | 长截图 | 長截圖 |
| Exit | 退出 | 結束 |
| Editing Collage | 正在编辑长截图 | 正在編輯長截圖 |
| Collage Preview | 长截图预览 | 長截圖預覽 |
| Copy Collage | 复制长截图 | 拷貝長截圖 |
| Export Collage | 导出长截图 | 匯出長截圖 |
| Select | 选择 | 選取 |
| Play | 播放 | 播放 |
| Current | 当前 | 目前 |
| Playlist | 播放列表 | 播放列表 |
| Search | 搜索 | 搜尋 |
| Library | 媒体库 | 媒體庫 |
| Shiori | Shiori | Shiori |
| {n} cues | {n} 条台词 | {n} 條台詞 |
| {n} results | {n} 条结果 | {n} 筆結果 |
| (Showing first {n} results) | （仅显示前 {n} 条结果） | （僅顯示前 {n} 筆結果） |
| Navigate | 导航 | 瀏覽 |
| Open | 打开 | 打開 |
| Back | 返回 | 返回 |
| Recent Videos | 最近视频 | 最近影片 |
| Recent Shioris | 最近 Shiori | 最近 Shiori |

## 设置：分类名

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Library | 媒体库 | 媒體庫 |
| Play | 播放 | 播放 |
| Appearance | 外观 | 外觀 |
| Search | 搜索 | 搜尋 |
| Language | 语言 | 語言 |
| Deep Link | Deep Link | Deep Link |
| Decode | 解码 | 解碼 |
| Maintenance | 维护 | 維護 |
| Developer | 开发者选项 | 開發者選項 |

## 设置：语言（新增）

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Choose the language used by CueSeeker. | 选择字幕求索使用的语言。 | 選擇字幕求索使用的語言。 |
| Language | 语言 | 語言 |
| Follow System | 跟随系统 | 跟隨系統 |
| English | English | English |
| Simplified Chinese | 简体中文 | 简体中文 |
| Traditional Chinese | 繁體中文 | 繁體中文 |

## 设置：媒体库

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Manage subtitle folders used for indexing and search. | 管理用于索引和搜索的字幕文件夹。 | 管理用於索引與搜尋的字幕資料夾。 |
| Add Folder | 添加文件夹 | 加入資料夾 |
| Index Now | 立即索引 | 立即索引 |
| Choose Subtitle Folder | 选择字幕文件夹 | 選擇字幕資料夾 |
| No Subtitle Folders | 没有字幕文件夹 | 沒有字幕資料夾 |
| Choose a local folder containing subtitle files. | 选择一个包含字幕文件的本地文件夹。 | 選擇一個包含字幕檔案的本機資料夾。 |
| Remove | 移除 | 移除 |
| Cancel | 取消 | 取消 |
| Remove Folder? | 移除文件夹？ | 移除資料夾？ |
| Remove “{name}” from CueSeeker? This will not delete local files. | 要从字幕求索中移除“{name}”吗？这不会删除本地文件。 | 要從字幕求索中移除「{name}」嗎？這不會刪除本機檔案。 |
| Database: {path} | 数据库：{path} | 資料庫：{path} |
| Removing {name}… | 正在移除 {name}… | 正在移除 {name}⋯ |
| Removed {name} | 已移除 {name} | 已移除 {name} |
| Indexing {name}... | 正在索引 {name}… | 正在索引 {name}⋯ |
| Indexing folder {i} of {n}: {name}... | 正在索引第 {i}/{n} 个文件夹：{name}… | 正在索引第 {i}/{n} 個資料夾：{name}⋯ |
| Indexed {name} | 已索引 {name} | 已索引 {name} |
| Indexed {n} folder(s) | 已索引 {n} 个文件夹 | 已索引 {n} 個資料夾 |
| Failed to index {name} | 索引 {name} 失败 | 索引 {name} 失敗 |
| {n} file(s) failed. First: {reason} | {n} 个文件失败。首个：{reason} | {n} 個檔案失敗。第一個：{reason} |
| {n} scanned | 已扫描 {n} | 已掃描 {n} |
| {n} indexed files | 已索引 {n} 个文件 | 已索引 {n} 個檔案 |
| {n} entries | {n} 个条目 | {n} 個項目 |
| {n} unchanged | {n} 个未变更 | {n} 個未變更 |
| {n} missing videos | {n} 个缺失视频 | {n} 部遺失影片 |
| {n} unreadable | {n} 个无法读取 | {n} 個無法讀取 |

## 设置：播放 / 外观 / 搜索 / Deep Link / 解码

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Auto Pause After a Cue Finishes | 台词结束后自动暂停 | 台詞結束後自動暫停 |
| Auto Switch to Next Cues in Playlist | 自动切换到播放列表中的下一条台词 | 自動切換至播放列表中的下一條台詞 |
| Auto Switch Gap | 自动切换间隔 | 自動切換間隔 |
| Choose how CueSeeker follows light and dark mode. | 选择字幕求索如何跟随浅色和深色模式。 | 選擇字幕求索如何跟隨淺色與深色模式。 |
| Appearance Mode | 外观模式 | 外觀模式 |
| Auto follows the current macOS system appearance. | “自动”会跟随当前 macOS 系统外观。 | 「自動」會跟隨目前的 macOS 系統外觀。 |
| Light | 浅色 | 淺色 |
| Dark | 深色 | 深色 |
| Auto | 自动 | 自動 |
| Choose how cues are presented in Search. | 选择台词在搜索中的呈现方式。 | 選擇台詞在搜尋中的呈現方式。 |
| Show Cue Group | 显示台词组 | 顯示台詞組 |
| Prefill with Focused Cue | 用聚焦台词预填 | 以聚焦台詞預先填入 |
| Automatically fill the Command Panel with the focused cue when opened from Playback Overlay. | 从播放覆盖层打开命令面板时，自动填入当前聚焦的台词。 | 從播放覆蓋層開啟指令面板時，自動填入目前聚焦的台詞。 |
| Choose how CueSeeker handles Deep Links. | 选择字幕求索如何处理 Deep Links。 | 選擇字幕求索如何處理 Deep Links。 |
| Play First Search Result | 播放第一条搜索结果 | 播放第一筆搜尋結果 |
| Automatically play the first result from the complete first search page. | 自动播放完整首页搜索结果中的第一条。 | 自動播放完整第一頁搜尋結果中的第一筆。 |
| Choose the video decode mode used by playback. | 选择播放使用的视频解码模式。 | 選擇播放使用的影片解碼模式。 |
| Decoder | 解码器 | 解碼器 |
| Applies to newly opened playback sessions. | 对新打开的播放会话生效。 | 對新開啟的播放工作階段生效。 |
| hardware | 硬件解码 | 硬體解碼 |
| software | 软件解码 | 軟體解碼 |
| auto | 自动 | 自動 |

解码器下拉当前直接显示内部值 `hardware` / `software` / `auto`，本需求要求改为显示上表中的名称。

## 设置：维护

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Review local database storage and reclaim unused space. | 查看本地数据库存储并回收未使用空间。 | 檢視本機資料庫儲存空間並回收未使用空間。 |
| Database Size | 数据库大小 | 資料庫大小 |
| Used Estimate | 已用估算 | 已用估計 |
| Reclaimable Space | 可回收空间 | 可回收空間 |
| WAL Size | WAL 大小 | WAL 大小 |
| SHM Size | SHM 大小 | SHM 大小 |
| Compaction recommended | 建议进行压缩 | 建議進行壓縮 |
| Database storage is within the maintenance threshold | 数据库存储在维护阈值以内 | 資料庫儲存空間在維護門檻以內 |
| Storage stats unavailable | 无法获取存储统计 | 無法取得儲存空間統計 |
| Refresh | 刷新 | 重新整理 |
| Compact Database | 压缩数据库 | 壓縮資料庫 |
| Compact Database? | 压缩数据库？ | 壓縮資料庫？ |
| Compact | 压缩 | 壓縮 |
| CueSeeker will reclaim unused SQLite space. Search and indexing are paused while compaction runs. | 字幕求索将回收未使用的 SQLite 空间。压缩期间搜索和索引会暂停。 | 字幕求索將回收未使用的 SQLite 空間。壓縮期間搜尋與索引會暫停。 |
| Loading storage stats... | 正在加载存储统计… | 正在載入儲存空間統計⋯ |
| Compacting database... | 正在压缩数据库… | 正在壓縮資料庫⋯ |
| Reclaimed {size} | 已回收 {size} | 已回收 {size} |
| Not enough free disk space | 磁盘可用空间不足 | 磁碟可用空間不足 |

## 设置：开发者选项

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Configure local diagnostics used during development. | 配置开发期间使用的本地诊断功能。 | 設定開發期間使用的本機診斷功能。 |
| Search E2E JSON Logs | 搜索 E2E JSON 日志 | 搜尋 E2E JSON 日誌 |
| Record each Search run as JSONL under logs/search-e2e/. | 将每次搜索运行记录为 logs/search-e2e/ 下的 JSONL 文件。 | 將每次搜尋執行記錄為 logs/search-e2e/ 下的 JSONL 檔案。 |
| FTS Vocabulary Diagnostics | FTS 词表诊断 | FTS 詞表診斷 |
| Enable fts5vocab diagnostics for local developer tools. | 为本地开发者工具启用 fts5vocab 诊断。 | 為本機開發者工具啟用 fts5vocab 診斷。 |
| FTS Vocabulary Data | FTS 词表数据 | FTS 詞表資料 |
| Refresh | 刷新 | 重新整理 |
| Terms | 词条 | 詞條 |
| Doc refs | 文档引用 | 文件引用 |
| Occurrences | 出现次数 | 出現次數 |
| Query Terms | 查询词条 | 查詢詞條 |
| Query Terms: {query} | 查询词条：{query} | 查詢詞條：{query} |
| Most Frequent Terms | 高频词条 | 高頻詞條 |
| No query terms. | 没有查询词条。 | 沒有查詢詞條。 |
| No vocabulary data. | 没有词表数据。 | 沒有詞表資料。 |
| No data loaded. | 未加载数据。 | 未載入資料。 |
| Loading vocabulary data... | 正在加载词表数据… | 正在載入詞表資料⋯ |
| Disabled | 已禁用 | 已停用 |
| Updated {time} | 更新于 {time} | 更新於 {time} |
| docs {n} | 文档 {n} | 文件 {n} |
| occ {n} | 出现 {n} | 出現 {n} |

## 导出

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Export Anki Package | 导出 Anki 包 | 匯出 Anki 套件 |
| Anki Export | Anki 导出 | Anki 匯出 |
| Export group to Anki | 将该组导出到 Anki | 將此群組匯出至 Anki |
| Export Screenshot | 导出截图 | 匯出截圖 |
| Export Screenshots | 导出截图 | 匯出截圖 |
| Export Collage | 导出长截图 | 匯出長截圖 |
| No Anki export items. | 没有可导出的 Anki 条目。 | 沒有可匯出的 Anki 項目。 |
| ffmpeg was not found. | 未找到 ffmpeg。 | 找不到 ffmpeg。 |
| Could not create Anki database: {msg} | 无法创建 Anki 数据库：{msg} | 無法建立 Anki 資料庫：{msg} |
| Could not execute Anki database SQL: {msg} | 无法执行 Anki 数据库 SQL：{msg} | 無法執行 Anki 資料庫 SQL：{msg} |
| Could not prepare Anki database SQL: {msg} | 无法准备 Anki 数据库 SQL：{msg} | 無法準備 Anki 資料庫 SQL：{msg} |
| Could not bind Anki database SQL: {msg} | 无法绑定 Anki 数据库 SQL：{msg} | 無法綁定 Anki 資料庫 SQL：{msg} |
| Could not write Anki database SQL: {msg} | 无法写入 Anki 数据库 SQL：{msg} | 無法寫入 Anki 資料庫 SQL：{msg} |
| {exe} exited with status {n}. | {exe} 退出，状态码 {n}。 | {exe} 結束，狀態碼 {n}。 |

## 运行状态与错误提示

| English | 简体中文 | 繁體中文 |
|---|---|---|
| Indexing is running | 正在索引 | 正在索引 |
| Folder removal is running | 正在移除文件夹 | 正在移除資料夾 |
| Database compaction is running | 正在压缩数据库 | 正在壓縮資料庫 |
| Search is running | 正在搜索 | 正在搜尋 |
| Search diagnostics are loading | 正在加载搜索诊断 | 正在載入搜尋診斷 |
| Library is loading | 正在加载媒体库 | 正在載入媒體庫 |
| Complete Library is loading | 正在加载完整媒体库 | 正在載入完整媒體庫 |
| Database is not initialized | 数据库尚未初始化 | 資料庫尚未初始化 |
| Folder detail is unavailable | 无法获取文件夹详情 | 無法取得資料夾詳細資訊 |
| Video metadata failed for {n} file(s). First: {reason} | {n} 个文件的视频元数据处理失败。首个：{reason} | {n} 個檔案的影片中繼資料處理失敗。第一個：{reason} |
| Video metadata refresh failed: {error} | 视频元数据刷新失败：{error} | 影片中繼資料重新整理失敗：{error} |
| Automatic cover generation failed for {a} cover(s) and {b} display rendition(s). | 自动生成封面失败：{a} 个封面、{b} 个显示版本。 | 自動產生封面失敗：{a} 個封面、{b} 個顯示版本。 |
| Automatic cover generation failed: {error} | 自动生成封面失败：{error} | 自動產生封面失敗：{error} |
| Library presentation refresh failed: {error} | 媒体库展示刷新失败：{error} | 媒體庫呈現重新整理失敗：{error} |
| Failed to remove folder index: {error} | 移除文件夹索引失败：{error} | 移除資料夾索引失敗：{error} |

# 文档同步

本地化落地后，`docs/human/design/Toast Usage Registry.md` 与 `docs/human/design/UI Design System.md` 中记录的英文文案会与界面显示的中文产生分歧。由人类维护者决定是否同步、以哪种语言为准，并更新提交这两份文档。