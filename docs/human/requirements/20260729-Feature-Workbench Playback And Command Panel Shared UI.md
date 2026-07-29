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
4. Playback Current界面和Playback Cue Playlist界面，大部分复用。取消左侧封面图。修改所有界面的Cue Group的字幕位置：主字幕位于上方，Cue Group字幕位于下方。Playback Cue Playlist界面不再在左侧显示序号。2个界面统一在选中字幕上方加信息行：前者是Display Title + Time Range，后者加入播放队列位置：[x/y] + Display Title + Time Range。例如：Ave Mujica - 01 21:33 - 21:40，[5/100] BanG Dream! - 12 17:10 - 17:20。分别使用badge的样式。非选中字幕不需要在上方加信息行。如果开启了Cue Group，只有Playback Cue Playlist界面的所有字幕需要在下方显示Cue Group字幕，Playback Current界面的所有字幕都不需要在下方显示Cue Group字幕。
5. Workbench Recent界面的Recent Videos部分和Workbench Recent Videos界面和Command Panel Recent Videos界面，复用，尤其是Command Panel Recent Videos界面，要改为视频卡片的排版。
6. Workbench Recent界面的Recent Shioris部分和Command Panel Recent Shioris界面，复用。
7. Command Panel Search界面，删除左侧封面图，这个版本复用前面已经修改过的Playback Cue Playlist界面的大部分内容，不必和Command Panel一级界面那种选单操作一致：布局，操作，默认选中第一条结果字幕，选中字幕显示信息行，所有字幕显示Cue Group（如果开启）。Command Panel Search界面保持现在的50条限制。

# 修改步骤

## 1. 删除 Shiori Tags
删除 Shiori Tags 的界面、交互、状态、Core API、数据库结构及相关测试，通过数据库迁移清除已有 Tag 数据。

## 2. 统一 Workbench Search 与 Shiori 搜索
Shiori 改为与 Search 相同的自动搜索、匹配范围和结果数量展示；统一 Workbench 中 Primary Cue 与 Cue Group 的上下顺序。

## 3. 统一 Library 界面
Library 一级与 Shiori 一级复用 Overview 和卡片结构，为 Library 增加文件夹、视频、字幕统计及 Add Content；固化 Library 二级与 Playback Video Playlist 的共享布局，并保留各自选择差异。

## 4. 统一 Recent 界面
Workbench Recent 预览、完整二级页和 Command Panel 复用相同的 Recent Videos、Recent Shioris 组件；Command Panel Recent Videos 改为视频卡片布局。

## 5. 统一 Playback Current 与 Cue Playlist
建立共享 Cue 展示结构，删除左侧封面和 Playlist 序号；增加独立 Badge 的信息行，统一 Cue Group 位于 Primary Cue 下方，并保留 Current 不显示 Cue Group 的规则。
Playback Current 使用 Display Title、Time Range 两个独立 Badge；Playback Cue Playlist 使用 [x/y]、Display Title、Time Range 三个独立 Badge。

## 6. 统一 Command Panel Search
复用 Playback Cue Playlist 的布局与操作，删除左侧封面，增加相同的信息 Badge 和 Cue Group 展示，同时保留最多 50 条预览及打开后使用完整 Playlist 的行为。

## 7. 全界面回归与冗余清理
完整验收本需求涉及的全部界面，确认共享组件、选择状态、键盘操作、滚动、播放和返回行为一致，并删除本次改动替代掉的重复实现。