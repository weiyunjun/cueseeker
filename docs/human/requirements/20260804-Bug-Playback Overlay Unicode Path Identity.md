# 版本
main

# 需求描述

## 1. 问题

包含 Unicode 规范等价字符的已入库视频和字幕可以正常播放并显示字幕，但按下 Enter 后无法进入 Playback Overlay。

例如：

- 预组合形式：`ゼ`（U+30BC）
- 分解形式：`セ`（U+30BB）+ `゙`（U+3099）

两种形式视觉相同且指向同一个文件，但 SQLite 对未经统一处理的路径执行精确比较时会认为它们不同，导致 Playback Overlay 无法读取已经存在的 Cue 数据。

## 2. 数据身份规则

1. Playback Overlay 查询已入库数据时，必须使用永久 `SubtitleID`，不得使用字幕路径作为数据库身份键。
2. Library、Search、Shiori、Recent 以及其他播放入口必须将当前播放字幕对应的 `SubtitleID` 传递到 Playback 状态。
3. Playback Overlay 的初始 Cue、完整 Cue Batch 以及后续相关数据库查询必须通过 `SubtitleID` 读取。
4. 字幕路径只用于定位和读取外部字幕文件，不得用于判断数据库中的字幕身份。
5. 对文件路径执行 URL 标准化或 Unicode 规范化后得到的字符串，不得反向替代已经确定的 `SubtitleID`。

## 3. Unicode 与语言范围

1. 修复不得针对日语、`ゼ` 或任何具体字符进行特判。
2. 修复必须与语言无关，并覆盖所有因 Unicode NFC/NFD 规范等价形式不同而产生的路径表示差异。
3. 不得将大小写、全角与半角、简体与繁体或其他非规范等价字符自动视为相同字符。
4. 文件名匹配规则继续遵守 `docs/human/design/Data.md`，本需求不修改视频与字幕匹配算法。

## 4. 现有数据保护

1. 必须保留现有 `LibraryID`、`VideoID`、`SubtitleID`、`CueID` 和 `ShioriID`。
2. 必须保留现有观看状态、播放进度、播放历史、Shiori、标签及 Cue 关联关系。
3. 不得通过删除数据库、重新分配永久 ID 或清空用户数据解决问题。
4. 本需求不修改 Cue 解析、Cue Group 或 ASS 变化检测规则。
5. 如果实现过程中发现现有播放数据无法提供对应的 `SubtitleID`，必须停止并报告，不得回退到规范化后的路径精确查询作为长期身份方案。

# 验收标准

1. 以下已入库文件播放时可以正常按 Enter 进入 Playback Overlay：

   - `/Volumes/Samsung/影视/新世纪福音战士/14 ゼーレ、魂の座 (H264 1440x1080 AAC[5.1ch／2ch]).mkv`
   - `/Volumes/Samsung/影视/新世纪福音战士/14 ゼーレ、魂の座 (H264 1440x1080 AAC[5.1ch／2ch]).ass`

2. Playback Overlay 能读取该字幕现有的全部有效 Cue，并正确定位当前或最近的 Cue。
3. 分别使用日语浊点、拉丁组合重音和韩文分解字符构造 NFC/NFD 路径测试，结果必须一致。
4. 普通 ASCII 文件名以及不包含组合字符的现有媒体播放和 Playback Overlay 行为保持不变。
5. Library、Search、Shiori 和 Recent 播放入口均通过相同的 `SubtitleID` 身份链路进入 Playback Overlay。
6. 视频播放、ASS 字幕渲染、视频与字幕匹配、Search、Shiori 和观看进度不得发生回归。