# 版本

main

# 关联设计

- `docs/human/design/Data.md`（永久身份与路径分离 补充说明 7、8；本需求取代补充说明 7 中“正在播放的视频被移出库时停止播放”，设计文档在验收后更新）
- `docs/human/design/Cue Parsing.md`（Tombstone）
- `docs/human/design/UI Design System.md`（Playback Feedback、Player Error Banner、Empty State、Playback Overlay、Command Panel）
- `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing Database Records.md`
- `docs/human/requirements/20260919-Engineering-Debug Remove Folder Delay For Acceptance.md`

# 需求描述

## 1. 范围

Add Folder、Index、Remove Folder 改变数据库后，播放页、Playback Overlay 与 Command Panel 的行为。本地文件无法加载仍按 20260921 需求单处理；播放只按文件绝对路径读取文件，两者互不影响。

## 2. 有效项

1. 字幕项（Current 中的字幕、Subtitle Playlist、Command Panel Search Results、Excerpt）：Cue 仍在数据库中且不在 Tombstone，所属字幕与视频仍在库中，即为有效。与 Excerpt 现有的有效判定一致。
2. 视频项（Video Playlist、Recent Videos）：视频仍在库中，即为有效。
3. 无效项视为不在数据库中，与本地文件是否存在无关。

## 3. 播放页

1. 当前视频不在数据库中时继续播放，不退出播放页。此后不保存该视频的观看进度、播放历史、Default Audio Track 与 Default Subtitle。
2. 当前项无效时，上一个、下一个、Auto Switch 与 Library 视频播完后自动播放下一个，均跳到列表中第一个有效项。
3. 没有有效项时，播放页中央显示 Playback Feedback，持续 1 秒，文案按来源为 `No Available Results`、`No Available Excerpts`、`No Available Videos`。
4. 打开 Playback Overlay 时按数据库显示：Current 在当前字幕不在数据库中时显示提示 `This subtitle is no longer in the library.`；Playlist 只显示有效项，没有有效项时显示提示 `No items in this playlist are in the library.`

## 4. Playback Overlay 与 Command Panel

1. 数据库变化时，已打开的 Playback Overlay（Current、Playlist、Collage）与 Command Panel 当前页面（Recent Videos、Recent Excerpt Lists、Search Results）保持变化前的内容，不刷新、不关闭。
2. Playback Overlay 内在 Current、Playlist、Collage 之间切换时保持该内容。以下情况后按数据库重新显示：关闭 Playback Overlay 后再打开；Command Panel 返回根页后再进入、关闭后再打开、重新搜索。
3. 播放或打开无效项（Current 中选择字幕播放、Playlist 与 Command Panel 中播放或打开）：不执行，本地文件存在也同样拦截。Player Error Banner 在视频与字幕两行之下新增一行 `This item is no longer in the library`，显示 5 秒，再次出现时替换并重新计时。
4. 对无效项执行 Save to Excerpt List、Copy Deep Link：不执行，播放页中央显示 Playback Feedback，持续 1 秒，警告图标，文案 `Not in Library`。
5. Copy Cue Text，Collage 的勾选、复制与导出照常可用。
6. 在 Command Panel 的 Recent Excerpt Lists 中打开一个没有有效项的列表：按 3.3 处理，文案 `No Available Excerpts`。
7. 操作被拦截时，Playback Overlay 与 Command Panel 保持打开。

## 5. 测试延迟

1. Debug 构建读取环境变量 `CUESEEKER_DEBUG_TASK_DELAY_SECONDS`，值为秒数。设置后，Add Folder、Index、Remove Folder 开始时先等待该秒数，等待期间任务处于执行中。
2. 取消 Add Folder、启动时清理中断的 Add Folder 不等待。
3. 未设置或值不是正数时不等待；Release 构建不读取该变量。
4. 取代 `CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS`，长期保留。

## 6. 保持不变

1. Workbench 不能打开无效的 Excerpt，Excerpt Playlist 不包含无效项。
2. 当前项有效时，上一个、下一个与 Auto Switch 的行为不变。

# 验收

以 `CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker` 启动：

1. 播放中 Remove 或 Index 使当前视频离开数据库：继续播放，不退回 Workbench。
2. 接第 1 条，上一个、下一个、Auto Switch、播完自动播放下一个：跳到第一个有效项；没有有效项时中央提示 1 秒。
3. 接第 1 条，打开 Playback Overlay：Current 显示已移除提示；Playlist 只显示有效项，没有时显示提示。
4. Playback Overlay 打开时 Remove 或 Index：Current、Playlist、Collage 保持原内容；播放无效项时左上角出现报错且 Overlay 不关闭；Save to Excerpt List 与 Copy Deep Link 出现中央提示；Copy Cue Text 与 Collage 照常可用；关闭再打开后按数据库显示。
5. Command Panel 打开时同第 4 条；返回根页再进入、重新打开或重新搜索后按数据库显示。
6. Index 使正在播放的 Excerpt 进入 Tombstone：按第 2 至 4 条的无效项处理。
7. 设置延迟变量后，Add Folder、Index、Remove Folder 保持执行中约 15 秒；未设置时不等待。
8. 自动化测试覆盖有效项判定与第一个有效项的选择；不新增自动化失败，不为本需求新增 E2E 能力，其余人工验收。