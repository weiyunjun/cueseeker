# 版本

main

# 关联设计

- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **Recent 与 Command Panel 时间尺度调整（`L-03.1 Recent Layout` & `L-09.2 Command Panel Secondary Layout`）**：
   - Workbench 的 `Recent`（`Videos` 与 `Excerpt Lists`）及播放页 `Command Panel` 的 `Recent Videos`、`Recent Excerpt Lists` 移除原有的 `Today` 与 `Yesterday` 分组，统一调整为 4 个时间分组：
     - **英文**：`Last 7 Days`、`Last 30 Days`、`Earlier`、`Never Played`
     - **简体中文**：`最近 7 天`、`最近 30 天`、`更早`、`从未播放`
     - **繁体中文**：`最近 7 天`、`最近 30 天`、`更早`、`從未播放`
   - 按本地自然日凌晨 `00:00`（$T_0$）切分：`Last 7 Days`（$t \ge T_0 - 6\text{d}$）、`Last 30 Days`（$T_0 - 29\text{d} \le t < T_0 - 6\text{d}$）、`Earlier`（$t < T_0 - 29\text{d}$）；无播放记录的归入 `Never Played`。
   - 仅展示非空分组；组内排序、`Never Played` 收录规则、分组标题样式与间距均保持不变。

# 验收标准

1. Workbench `Recent` 与 `Command Panel` 二级页（`Recent Videos` / `Recent Excerpt Lists`）均按 `Last 7 Days`、`Last 30 Days`、`Earlier`、`Never Played` 4 个分组正确归类展示，空分组不显示标题。
2. 英文、简体中文、繁体中文下的分组标题文案正确对应。