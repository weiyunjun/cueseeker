# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Menus / Player More Menu、Audio Track Submenu；Data Display / Tag）
- `docs/human/design/Data.md`（视频与字幕匹配规则流程；永久身份与路径分离）
- `docs/human/requirements/20260917-Feature-In-Video Audio Track Switching And Default Audio Track.md`
- `docs/human/requirements/20260917-Bug-Audio Track Not Reset On Same Video Open And More Menu Width And Bounds.md`

# 需求描述

## 1. 范围

1. 视频匹配多条字幕时，播放页可以切换当前字幕，并为该视频设置默认字幕。

## 2. 字幕排序

1. 去掉最后 1 级后缀名后，与去掉最后 1 级后缀名的视频名称完全一样的字幕排在最前；有多条时 ass 在 srt 之前。是否完全一样，按视频与字幕匹配规则判断。
2. 其余字幕按文件名的 Finder 排序排列：不区分大小写，数字按数值比较。例如 a.sc.ass、a.tc.ass、a.jp.ass、a.en.ass 排列为 a.en.ass、a.jp.ass、a.sc.ass、a.tc.ass。

## 3. 默认字幕与当前字幕

1. 默认字幕记录 SubtitleID，绑定 VideoID 并持久化；未设置时为排序第一条。App 内改名后保留，Index 不修改它。
2. 记录的字幕不再匹配该视频时，使用排序第一条。
3. 从以下入口打开视频时，当前字幕取默认字幕，打开的是正在播放的同一视频时也一样：Library、Recent Videos（Workbench 与 Command Panel）、Playlist 为 Videos 时的上一个与下一个、Playback Overlay 中 Videos Playlist 的卡片。
4. 搜索、Excerpt、Deep Link 等已确定字幕的入口，仍加载该入口的字幕。
5. 播放中切换当前字幕只影响本次播放，不保存；切换后进度、播放或暂停状态与 Playlist 不变。Repeat 不改变当前字幕。
6. 画面字幕、Playback Overlay 的 Current 与 Collage Editor、Repeat、保存到 Excerpt List 都使用当前字幕。

## 4. More 菜单

1. 一级菜单依次为 Audio Track、Subtitle（字幕）、Default Audio Track、Default Subtitle（默认字幕），均为 Submenu Trigger；视频只有一条字幕时两个字幕项同样可用。
2. 两个字幕二级菜单按第 2 节的顺序列出该视频的字幕，单选；外观、宽度、展开方向、显示范围与交互沿用音轨二级菜单。
3. 菜单项名称只显示字幕文件名最后最多 2 级后缀名，只有 1 级时显示 1 级。例如 a.sc.ass 显示为 .sc.ass，a.srt 显示为 .srt。
4. Subtitle：勾选当前字幕；默认字幕所在项显示 Default（默认）标签。
5. Default Subtitle：勾选默认字幕；当前字幕所在项显示 Current（当前）标签。

# 验收

1. 视频 a.mp4 匹配 a.srt、a.ass、a.sc.ass、a.tc.ass、a.jp.ass、a.en.ass 时，两个字幕二级菜单依次为 .ass、.srt、.en.ass、.jp.ass、.sc.ass、.tc.ass；未设置默认字幕时，从 Library 打开加载 a.ass。
2. 切换当前字幕后，画面字幕、Current 与 Collage Editor 立即改为所选字幕，进度、播放或暂停状态与 Playlist 不变；按 Repeat 后当前字幕不变。
3. 从第 3 节第 3 条的入口打开视频时加载默认字幕，修改过当前字幕的同一视频也一样；从搜索结果或 Excerpt 打开时，加载该条目所属的字幕。
4. 设置默认字幕后，重启 App 与 App 内改名后仍然生效；该字幕文件删除并 Index 后，使用排序第一条。
5. 界面由人工在 App 内验收；本次改动不新增任何自动化端到端用例或单元用例的失败。