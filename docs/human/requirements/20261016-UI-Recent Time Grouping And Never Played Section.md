# 版本

main

# 关联设计

- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **Recent 与 Command Panel 时间分组**：
   - Workbench 的 `Recent`（`Videos` 与 `Excerpt Lists`）及播放页 `Command Panel` 的 `Recent Videos`、`Recent Excerpt Lists` 统一按最后播放时间划分为 5 个分组：`今天`、`昨天`、`最近 7 天`、`更早`、`从未播放`（繁中：`今天 / 昨天 / 最近 7 天 / 更早 / 從未播放`；英文：`Today / Yesterday / Last 7 Days / Earlier / Never Played`）。
   - 时间按本地自然日凌晨 `00:00`（$T_0$）切分：`今天`（$t \ge T_0$）、`昨天`（$T_0 - 1\text{d} \le t < T_0$）、`最近 7 天`（$T_0 - 6\text{d} \le t < T_0 - 1\text{d}$）、`更早`（$t < T_0 - 6\text{d}$）；数据库无播放记录的归入 `从未播放`。
   - 仅展示非空分组，空分组不显示标题。

2. **「从未播放」分组数据规则**：
   - **Videos**：文件夹在数据库中无任何播放记录时归入 `从未播放`，默认展示该文件夹的 `EP01`，组内按文件夹名称升序排列。
   - **Excerpt Lists**：从未播放过（`recent_played_at` 为空）且包含有效摘录的列表归入 `从未播放`，组内按创建时间正序排列，打开时默认从第 1 条有效字幕开始播放。

3. **分组标题样式与间距**：
   - 分组标题使用 `C-08.7 Section Title`（`--font-size-section-title: 18px`，`Semibold`，`--color-text-primary`），独占一行、左对齐（与未 Hover 时的卡片封面左边缘齐平），纯静态文本，不可点击、无 Hover 效果。
   - 标题容器与下方卡片网格间距为 `--spacing-5`（`20px`），相邻两个分组容器间距为 `--spacing-5`（`20px`），使未 Hover 时标题与上下卡片内容的视觉间距统一为 `32px`。

# 验收标准

1. Workbench `Recent` 与 `Command Panel` 二级页（`Recent Videos` / `Recent Excerpt Lists`）均按 5 个分组正确归类展示，空分组不显示标题，支持多语言切换。
2. 无播放记录的视频文件夹在 `从未播放` 下默认展示 `EP01`；未播放过的有效摘录集在 `从未播放` 下正常展示并可从首条有效字幕点播。
3. 分组标题为纯文字无交互效果，左边缘与卡片封面左边缘齐平，标题与上下卡片内容的视觉间距均为 `32px`，Command Panel 内方向键跨分组导航正常。