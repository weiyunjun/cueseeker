# 版本
main

# 需求描述

数据库中的主要对象都有自己的永久 ID：

```text
LibraryID
 ├── VideoID
 ├── SubtitleID
 │    └── CueID
 │          └── ShioriID
```

LibraryID：用户添加的资料库文件夹。
VideoID：视频文件（例如1.mkv），观看状态和进度属于它。
SubtitleID：字幕文件（例如1.ass）。
CueID：对于SRT字幕而言是一条字幕的ID，对于ASS字幕而言是一条Event的ID。注意此处与CueGroup区分开来。
ShioriID：收藏记录。

## 补充说明
1. 资料库保存当前绝对路径，视频和字幕保存相对于资料库的路径。
2. 观看状态、播放进度、播放历史引用 `VideoID`。字幕事件引用 `SubtitleID`。Shiori 引用 `CueID`。标签引用 `ShioriID`。字幕与视频的匹配关系保存 `SubtitleID + VideoID`。