# 版本

main

# 关联设计

- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/workbench/Search and Filter.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **统一工作台 Search 界面搜索框文字与全局当前搜索词**：
   - 工作台 Search 界面顶部的搜索输入框不再单独暂存历史草稿，始终与全局当前生效的搜索词保持同步。
   - 在任意界面（含从 Recent、Library、Excerpt 或 File 进入的播放页）通过 Command Panel 搜索、播放页选中台词搜索或外部链接（URL Scheme）触发正式搜索后，切回工作台 Search 界面时，顶部搜索输入框展示的关键词必须与当前生效的搜索结果、筛选统计及排序状态一致。

# 验收标准

1. 在工作台 Search 界面输入关键词 `hello` 等待出结果后，切换到 Recent（或 Library / Excerpt）界面并播放视频，在播放页打开 Command Panel 搜索新关键词 `world`（无论是否进一步修改 Filter 或 Sort），关闭播放页并切回 Search 界面：顶部搜索框显示为 `world`，且与筛选角标、筛选弹窗统计、排序状态及下方字幕表格结果完全一致。
2. 在工作台 Search 界面输入、修改或清空搜索词，切往其他工作台页面或进入播放页（未触发新搜索）后再返回 Search 界面时，顶部搜索框文字与下方结果保持原状不变。