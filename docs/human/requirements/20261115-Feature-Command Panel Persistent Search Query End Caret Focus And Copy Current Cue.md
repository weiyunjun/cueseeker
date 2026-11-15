# 版本

main

# 关联设计

- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/workbench/Search and Filter.md`
- `docs/human/design/workbench/Settings and Localization.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **搜索框输入在应用运行期间跨界面持久共享**：
   - 本次应用运行期间，`Command Panel` 搜索框与 `Workbench` 的 `Search` 页面搜索框始终共享并保留同一份搜索词（退出并重启应用后恢复初始空状态）。
   - 关闭再重新打开 `Command Panel`、从 `Command Panel` 二级界面返回一级界面、切换播放视频、或在播放相关界面与 `Workbench` 之间往返，两处搜索框内容始终一致；在任一处输入、修改或清空，另一处同步生效。打开 `Command Panel` 一级界面时若已有保留搜索词，直接展示对应 `Search <搜索词>` 行及精确结果数统计。

2. **`Workbench` 与 `Command Panel` 搜索框默认聚焦光标置于末尾**：
   - 进入 `Workbench` 的 `Search` 一级页面，以及打开 `Command Panel` 一级界面（含从二级界面返回一级界面、或通过无障碍聚焦搜索框）时，搜索框自动进入输入状态；若框内已有文字，**不再默认全选，而是将输入光标置于最后一个字后面**（文本超长时自动滚至末尾可见）。
   - `Rename` 重命名弹窗的新名称输入框不属于搜索框，维持原有的自动聚焦并全选旧名称行为不变。

3. **`Command Panel` 一级界面新增 `Copy Current Cue` 选项与底栏动作联动（禁止硬编码与私自特殊实现）**：
   - **排列位置与显隐条件**：在 `Command Panel` 一级界面选项列表中，于 `Search <搜索词>` 下方（有搜索词时）、`Recent Videos` 上方新增 `Copy Current Cue` 选项（英文：`Copy Current Cue`；简体中文：`复制当前台词`；繁体中文：`拷貝目前台詞`）。当前存在可用台词时展示该项；当视频无可用字幕或极端边界下（如媒体库文件夹移除后字幕已不在库中）无法取得台词时，不显示该项。
   - **视觉样式**：完全复用 `Command Panel` 一级界面既有选项行规范——左侧使用 `copy` 复制图标，标题与其余选项使用相同的主文字字号、字重与颜色，标题右侧紧接单行展示当前台词内容（换行转为空格，超出宽度尾部省略，字号、字重与次级文字色同 `Search` 行右侧的搜索词展示）。
   - **当前台词判定与冻结规则**：从 `Playback Overlay` 唤出 `Command Panel` 时，在 `Current`、台词 `Playlist`、`Collage` 下取当前聚焦台词，在剧集卡片 `Video Playlist` 下取当前视频默认台词；从普通视频播放界面直接唤出 `Command Panel` 时，按与进入 `Playback Overlay` 相同的默认台词规则判定（当前时间点命中的激活台词；无激活台词时取最近的前一条台词；位于首条台词之前时取首条台词，关闭画面字幕显示时同样生效）。面板打开期间保持已取到的台词稳定显示。
   - **底栏按钮联动与触发表现**：遵循 `Command Panel` 首页默认选中第 1 项与方向键/手柄导航、无障碍遍历规则。当选中项停在 `Copy Current Cue` 上时，右下角底栏动作按钮文案动态切换为 `Copy` + `Return`（英文：`Copy`；简体中文：`复制`；繁体中文：`拷貝`），选中其余选项时恢复 `Open` + `Return`。鼠标点击该项、选中该项按 `Return` / 手柄 `✕`、点击右下角 `Copy` 按钮或通过无障碍激活时，将当前台词文本复制到系统剪贴板，右下角弹出既有的台词已复制轻提示，`Command Panel` 保持打开且输入焦点保留在顶部搜索框（可直接配合键盘 `⌘V` 或手柄 `△` 将台词粘贴至搜索框光标后方）。

4. **移除设置页自动预填开关**：
   - 从 `Settings -> General -> Search` 分组中移除原有的自动预填聚焦台词开关（该分组仅保留 `Show Cue Group`），同步移除该设置项的无障碍遍历节点；现有键盘快捷键配置与手柄键位映射保持不变。

5. **设计文档同步安排**：
   - 关联产品与 UI 设计文档待本次改动验收完成后再统一提交更新。

# 验收标准

1. **跨界面搜索词持久化验收**：在 `Workbench` 的 `Search` 页输入关键词后进入视频播放并打开 `Command Panel`，搜索框保留该关键词且下方显示 `Search <关键词>` 与结果数；在 `Command Panel` 一级界面修改或清空关键词后按 `Esc` 关闭，再次打开 `Command Panel`、切换视频再打开、或返回 `Workbench` 的 `Search` 页，搜索框与结果均保持最新状态；重启应用后恢复空搜索框。
2. **搜索框聚焦末尾光标验收**：搜索框已有文字时，进入 `Workbench` 的 `Search` 页、打开 `Command Panel` 一级界面、从 `Command Panel` 二级界面返回一级界面、或通过无障碍聚焦搜索框，均处于输入状态且光标停在最后一个字后面、不全选文字；打开 `Rename` 弹窗仍自动全选旧名称。
3. **`Copy Current Cue` 选项、底栏联动与键位配合验收**：从普通视频播放页（含隐藏字幕状态）及 `Playback Overlay` 各子模块打开 `Command Panel` 一级界面，`Copy Current Cue` 准确显示在 `Search` 下方、`Recent Videos` 上方并展示对应当前台词预览（无字幕或台词已从库中移除时不显示该行）；选中该行时右下角显示 `Copy Return`，选中其他行显示 `Open Return`；通过鼠标、键盘 `Return`、底栏按钮、手柄 `✕` 或无障碍触发后，台词成功复制到剪贴板并弹出复制成功轻提示，面板保持打开，紧接着按 `⌘V` 或手柄 `△` 可直接粘贴到搜索框光标后方；简、繁、英三语实时切换准确。
4. **设置页清理验收**：`Settings -> General -> Search` 分组中不再显示自动预填开关，仅保留 `Show Cue Group`，设置页无障碍遍历顺序正常无残留。