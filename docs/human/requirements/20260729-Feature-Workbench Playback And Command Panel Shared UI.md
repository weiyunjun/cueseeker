# 版本
main

# 需求描述

## 所有本次涉及的界面
Workbench Search界面
Workbench Recent界面的Recent Videos部分
Workbench Recent界面的Recent Shioris部分
Workbench Recent Videos界面
Workbench Recent Shioris界面
Workbench Library一级界面
Workbench Library二级界面
Workbench Shiori一级界面
Workbench Shiori二级界面
Playback Current界面
Playback Cue Playlist界面
Playback Video Playlist界面
Command Panel Search界面
Command Panel Recent Videos界面
Command Panel Recent Shioris界面

## 需要处理的界面关系
1. Workbench Search界面和Workbench Shiori二级界面，在搜索上仍然有很多不一致的地方。后者要按下回车才可以搜索，可以搜索Display Title，不显示搜索结果数量等。现在需要以前者为基准，Shiori 复用 Workbench Search 的输入即搜索机制和匹配范围，只匹配 Primary Cue，不匹配 Display Title，并显示结果数量。另外后者的Tags功能，前端后端都要砍掉。
2. Workbench Library一级界面和Workbench Shiori一级界面，前者应该加上类似后者的数据统计以及添加内容的功能。数据统计包括文件夹数（文件夹数为当前 Library 一级界面展示的内容文件夹数），视频数，字幕数，添加内容则是打开Settings - Library界面。这样二者的界面可以大部分复用，只是卡片上后者多一个描述内容，具体功能和内容上有区别。
3. Workbench Library二级界面和Playback Video Playlist界面，要大部分复用，只是细节交互（默认选中）有不同。
4. Playback Current界面和Playback Cue Playlist界面，大部分复用。取消左侧封面图。修改所有界面的Cue Group的字幕位置：主字幕位于上方，Cue Group字幕位于下方。Playback Cue Playlist界面不再在左侧显示序号。2个界面的所有字幕统一在上方显示信息行：前者是Display Title + Time Range，后者加入播放队列位置：[x/y] + Display Title + Time Range。例如：Ave Mujica - 01 21:33 - 21:40，[5/100] BanG Dream! - 12 17:10 - 17:20。每项信息分别使用独立Badge。选中和非选中字幕均使用Playback专用的中性灰色Badge配色，不再使用蓝色。非选中Badge的背景色需要比当前更深；选中Badge的背景色需要比非选中Badge更深，文字颜色也需要比非选中Badge文字更深。Dark Appearance按照相同的视觉层级关系使用对应配色。Badge不复用Watch Status Badge组件、Token或状态语义。如果开启了CueGroup，只有Playback Cue Playlist界面的所有字幕需要在下方显示Cue Group字幕，Playback Current界面的所有字幕都不需要在下方显示Cue Group字幕。
5. Workbench Recent界面的Recent Videos部分、Workbench Recent Videos界面和Command Panel Recent Videos界面复用相同的视频卡片组件，Command Panel Recent Videos界面改为视频卡片排版。Command Panel Recent Videos支持上下左右四个方向键，按照当前自适应卡片网格的实际视觉位置移动到对应方向最近的卡片；到达边界时不移动、不循环，Enter打开选中卡片，选中卡片始终滚动到可见区域。
6. Workbench Recent界面的Recent Shioris部分和Command Panel Recent Shioris界面，复用。
7. Command Panel Search界面，删除左侧封面图，这个版本复用前面已经修改过的Playback Cue Playlist界面的大部分内容，不必和Command Panel一级界面那种选单操作一致：布局，操作，默认选中第一条结果字幕，所有字幕显示信息行，所有字幕显示Cue Group（如果开启）。Command Panel Search界面保持现在的50条限制。

# 修改步骤

## 1. 删除 Shiori Tags
删除 Shiori Tags 的界面、交互、状态、Core API、数据库结构及相关测试，通过数据库迁移清除已有 Tag 数据。

## 2. 统一 Workbench Search 与 Shiori 搜索
Shiori 改为与 Search 相同的自动搜索、匹配范围和结果数量展示；统一 Workbench 中 Primary Cue 与 Cue Group 的上下顺序。

## 3. 统一 Library 界面
Library 一级与 Shiori 一级复用 Overview 和卡片结构，为 Library 增加文件夹、视频、字幕统计及 Add Content；固化 Library 二级与 Playback Video Playlist 的共享布局，并保留各自选择差异。

## 4. 统一 Recent 界面
Workbench Recent 预览、完整二级页和 Command Panel 复用相同的 Recent Videos、Recent Shioris 组件；Command Panel Recent Videos 改为视频卡片布局，并支持符合自适应网格实际视觉方向的上下左右键导航。方向键选择对应方向最近的卡片，边界不循环，Enter打开选中卡片，选中卡片始终滚动到可见区域。

## 5. 统一 Playback Current 与 Cue Playlist
建立共享 Cue 展示结构，删除左侧封面和 Playlist 序号；增加独立 Badge 的信息行，统一 Cue Group 位于 Primary Cue 下方，并保留 Current 不显示 Cue Group 的规则。
Playback Current 使用 Display Title、Time Range 两个独立 Badge；Playback Cue Playlist 使用 [x/y]、Display Title、Time Range 三个独立 Badge。

## 6. 统一 Command Panel Search
复用 Playback Cue Playlist 的布局与操作，删除左侧封面，增加相同的信息 Badge 和 Cue Group 展示，同时保留最多 50 条预览及打开后使用完整 Playlist 的行为。

## 7. 统一字幕 Badge
Playback Current、Playback Cue Playlist和Command Panel Search的所有字幕持续显示各自的信息Badge。选中和非选中字幕显示相同的Badge内容和数量，并分别使用Playback专用的中性灰色配色，不再使用蓝色。非选中Badge的背景色需要比当前更深；选中Badge的背景色和文字颜色需要比非选中Badge更深。Dark Appearance按照相同的视觉层级关系使用对应配色。选择变化只改变Badge配色，不改变Badge内容、数量或字幕高度。

## 8. 全界面回归与冗余清理
完整验收本需求涉及的全部界面，确认共享组件、选择状态、键盘操作、滚动、播放和返回行为一致，并删除本次改动替代掉的重复实现。

# UI文档改动

- Core Tokens：
  - 增加 Playback Cue Information Badge 的固定高度 Token：`23px`。
  - 增加 Selected 与 Unselected Badge 的独立中性灰色配色 Token。
  - 删除 Playback Playlist 独立序号区域相关的颜色和宽度 Token。

- Shiori Tags：
  - 删除 Shiori Tag、Tag Composer Field、Tag Popover、Tags Column 及相关交互规则。
  - Chip / Tag 仅保留只读 Language Tag 语义。
  - 更新表格文字选择、Cursor、Context Menu 和 Row Action 规则，移除 Shiori Tag 相关内容。

- Workbench Search 与 Shiori：
  - Search 与 Shiori 复用相同的 Search Box、输入即搜索和 Result Count Text。
  - Query 只匹配 Primary Cue，不匹配 Display Title 或 Additional Cues。
  - Enter 不用于提交搜索。
  - Primary Cue 位于上方，Additional Cues 位于下方。
  - Shiori Table 删除 Tags Column。

- Library 与 Shiori Overview：
  - 增加共享的 Library / Shiori Overview Layout、Adaptive Media Card Grid 和 Card Structure。
  - Library 一级显示 Folder、Video、Subtitle 统计。
  - Library 增加 `Add Content`，打开 Settings 的 Library 分类。
  - Library Folder Card 与 Shiori List Card 共享结构，Shiori List Card 额外显示 Description。
  - Workbench Library Folder Detail 与 Playback 视频型 Playlist 复用 Library Episode Grid 和 Card Layout，仅保留选择行为差异。

- Recent：
  - Workbench Recent 预览、完整二级页和 Command Panel 复用相同的 Recent Videos Card Grid 与 Recent Shiori Resume Row List。
  - Workbench Recent Videos 不建立持久选择，也不支持键盘导航。
  - Command Panel Recent Videos 使用视频卡片布局，支持符合实际 Grid 位置的上下左右键导航。
  - 方向键到达边界时不循环，Selected Card 始终滚动到可见区域。

- Playback Current 与 Cue Playlist：
  - 删除 Current 和字幕型 Playlist 左侧的 Context Region、Library Cover 和视频识别区域。
  - 删除 Cue Playlist 独立 Sequence Number 区域。
  - Primary Cue 位于上方，Cue Group 位于下方。
  - Current 始终不显示 Cue Group。
  - Current 每条 Cue 显示 Display Title、Time Range 两个独立 Badge。
  - Cue Playlist 每条 Result 显示 `[x/y]`、Display Title、Time Range 三个独立 Badge。
  - Selected 和 Unselected 显示相同的 Badge 内容、数量和固定高度，仅配色不同。
  - Badge 使用 Playback 专用中性灰色，不复用 Watch Status Badge 或其 Token。
  - Selection 变化不改变 Cue 或 Result 的 Natural Height 和 Reel Geometry。

- Command Panel Search：
  - 删除左侧 Context Region、Library Cover 和独立 Result Row。
  - 复用 Playback Cue Result Reel 的布局、选择、滚动和键盘操作。
  - 默认选择第一条 Result。
  - 每条 Result 显示信息 Badge，并在 Show Cue Group 开启时于 Primary Cue 下方显示 Cue Group。
  - 保留最多 `50` 条结果预览。
  - `[x/y]` 使用完整搜索结果数量；Enter 使用完整结果集合建立 Playlist。
