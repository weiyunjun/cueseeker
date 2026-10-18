# 版本

main

# 关联设计

- `docs/human/design/data/Data.md`
- `docs/human/design/data/Cue Parsing.md`

# 需求描述

1. **字幕脱离有效视频配对时统一清理活跃数据并转入 Tombstone**：
   - 当目录中的视频文件被删除而只保留字幕文件（例如原有 `1.mp4` + `1.srt`，删除 `1.mp4` 只留 `1.srt`）并执行 Index 时，因该字幕已不再构成有效的「视频 + 字幕」匹配关系，必须与字幕被删除时采取统一的退库处理：
     - 将该字幕及其未被 Excerpt List 收藏的台词彻底移出活跃数据；若该文件夹下已无任何有效配对，同步清理该空文件夹及其封面记录；
     - 将该字幕下已被 Excerpt List 收藏的台词转入 Tombstone，在 Excerpt List 中显示为变灰不可用状态（视频缺失但字幕文件仍在磁盘上时，状态提示保持为「视频文件缺失，字幕文件仍然可用」，右键菜单仍支持打开字幕所在文件夹）。

2. **同路径字幕重新配对入库时统一从 Tombstone 匹配并恢复 Excerpt 可用状态**：
   - 无论是因视频被删、字幕文件被删、文件夹被移除，还是因编辑字幕删掉单句台词而进入 Tombstone 的 Excerpt 收藏台词，当后续同一路径下的「视频 + 字幕」重新构成有效配对并执行 Index 时，统一按单句字幕变化检测规则（完全匹配或唯一一处变化匹配）与该字幕路径下的 Tombstone 台词进行身份比对：
     - 比对成功的台词直接继承原 `CueID` 并离开 Tombstone，Excerpt List 中对应的收藏记录自动恢复为正常可播放状态。

# 验收标准

1. 目录中存在 `1.mp4` 与 `1.srt`，完成 Index 后将 `1.srt` 中的台词收藏到 Excerpt List：
   - 删除磁盘上的 `1.mp4`（保留 `1.srt`）并执行 Index，该字幕与视频从 Search、Library、Recent、File 界面彻底移除，Excerpt List 中该收藏台词进入 Tombstone 并变灰不可用；
   - 将 `1.mp4` 放回原目录并再次执行 Index，Excerpt List 中该收藏台词恢复为正常可用状态。
2. 在上述场景中，删除磁盘上的 `1.srt`（或同时删除 `1.mp4` 与 `1.srt`）并执行 Index，Excerpt List 中该收藏台词进入 Tombstone 并变灰不可用；随后将文件放回原路径并再次执行 Index，Excerpt List 中该收藏台词同样恢复为正常可用状态。
3. 编辑 `1.srt` 删掉某句已收藏台词并执行 Index，该台词在 Excerpt List 中变灰不可用；随后将该句台词重新加回 `1.srt` 并执行 Index，该台词在 Excerpt List 中恢复为正常可用状态。