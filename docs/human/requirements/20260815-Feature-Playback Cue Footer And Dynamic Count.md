# 版本

main

# 需求描述

1. Playback Overlay Current、Playback Overlay Cue Playlist、Collage 和 Command Panel Search 统一使用现有 Command Panel Search Footer 的设计语言。Raycast 仅作为 Return Key 图标参考，不作为 Footer 视觉基准。

2. Footer 位于字幕时间轴区域底部，不得相对整个 App 窗口定位或遮挡字幕。Collage 的 Footer 位于右侧字幕选择区域底部。

3. Footer 左侧显示：
   - Current、Cue Playlist、Collage：`{N} cues`
   - Command Panel Search：`{N} results`
   - Command Panel Search 超过 50 条或仍有更多结果时：`{N} results (Showing first 50 results)`

4. `N` 表示完整数据集总数，不表示当前可见 Cue 数量或 Command Panel 的 50 条预览数量。

5. 搜索总数沿用旧版总数 Badge 的增量刷新规则：
   - 搜索过程中持续更新，搜索完成后显示最终总数。
   - 搜索未完成时播放结果，不得停止该搜索任务的结果补全。
   - 随后打开 Cue Playlist，无论 Playlist 已经打开还是稍后打开，都必须继续显示同一搜索任务的最新总数。
   - 新搜索不得更新已经由旧搜索建立的 Playlist。

6. 总数更新不得重置当前选择、播放位置或滚动位置。

7. Footer 右侧提示：
   - Current、Cue Playlist、Command Panel Search：`Navigate`、上方向键、下方向键、`Play`、Return Key。
   - Collage：`Navigate`、上方向键、下方向键、`Select`、Return Key。

8. Return Key 使用与 Raycast 主流表示一致的原生 `return` 图标，不使用文本字符 `↩`。

9. Footer 和 Keycap 必须使用共享组件及 UI Design System Token，禁止按界面硬编码或增加特殊样式。

10. Command Panel Root、Recent 页面及非 Cue Playlist 不在本需求范围内。

11. 实际视觉验收完成后，再由人工将最终组件、Token 和布局规则更新至 `UI Design System.md`。