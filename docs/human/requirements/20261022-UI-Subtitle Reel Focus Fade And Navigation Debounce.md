# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **Subtitle Focus Motion 动效 Tokens 新增与调整**：
   - 修改 `--duration-subtitle-focus-scroll`：由 `0.22s` 调整为 `0.40s`。
   - 新增 `--duration-subtitle-focus-fade-out`：`0.26s`（开始导航时原聚焦字幕褪为未选中颜色的淡出时长）。
   - 新增 `--delay-subtitle-focus-fade-in`：`0.18s`（导航防抖等待阈值）。
   - 新增 `--duration-subtitle-focus-fade-in`：`0.22s`（停止导航满防抖阈值后，目标聚焦字幕过渡为选中颜色的淡入时长）。
   - 新增 `--easing-subtitle-focus-fade`：`cubic-bezier(0.37, 0, 0.63, 1)`（焦点字幕颜色淡出与淡入的缓入缓出曲线；位置滚动继续使用 `--easing-subtitle-focus-scroll`：`cubic-bezier(0.22, 1, 0.36, 1)`）。

2. **字幕流（Playback Cue Reel）导航防抖与焦点淡入淡出表现**：
   - **适用范围**：所有使用字幕流的场景（Playback Overlay 的 `Current`、`Playlist`、`Collage Editor` 以及 `Command Panel` 的字幕搜索结果）。
   - **开始导航（淡出）**：通过键盘/手柄方向导航、滚轮/触控板滚动、拖拽右侧滚动条、点击非当前焦点字幕或点击 Collage 预览截图组使焦点字幕位置发生改变时，原已聚焦（或正处于半途淡入状态）的字幕立即从当前颜色进度开始，在 `--duration-subtitle-focus-fade-out`（`0.26s`）内按 `--easing-subtitle-focus-fade` 平滑过渡为 `Unselected` 颜色。
   - **持续导航（防抖保持全暗）**：自最后一次导航位置变化起未满 `--delay-subtitle-focus-fade-in`（`0.18s`）期间，每次新的导航输入或滚动位置变化均重置防抖计时，所有字幕保持 `Unselected` 颜色（已处于淡出途中的字幕继续完成淡出）。
   - **停止导航（淡入）**：当导航位置停止变化满 `--delay-subtitle-focus-fade-in`（`0.18s`）后（含按住滚动条停顿未松开鼠标的情形），当前停靠在焦点锚点的目标字幕在 `--duration-subtitle-focus-fade-in`（`0.22s`）内按 `--easing-subtitle-focus-fade` 从 `Unselected` 颜色平滑过渡为 `Selected` 颜色。
   - **多层文字同频过渡**：单条字幕内的主台词（Primary Cue）、次要台词组（Cue Group，如有）与底部元数据（Playback Cue Metadata，如有）按同一过渡进度各自在 `Unselected` 与 `Selected` 颜色之间同步插值；Collage Editor 左侧的勾选框与时间轴连接线保持原有样式不变。

3. **初始状态、边界与快捷键响应规则**：
   - **初始呈现**：界面首次打开、切换标签页或搜索结果加载完成时，默认聚焦的字幕直接显示为 `Selected` 颜色，不播放淡入过渡。
   - **首尾边界**：已处于首条继续向上导航或已处于末条继续向下导航时，因焦点字幕未发生改变，保持当前 `Selected` 颜色不变，不触发淡出。
   - **快捷键即时生效**：防抖与淡入过渡仅作用于视觉颜色表现，逻辑选中项始终实时更新为最新目标字幕；在防抖或淡入尚未完成时按下回车播放、收藏、复制或勾选等操作，立即对当前目标字幕生效。

# 验收标准

1. **单步导航**：在字幕流中单次按下方向键或单步拨动滚轮切换字幕时，列表以 `0.40s` 平滑滚动到目标字幕；原焦点字幕在 `0.26s` 内柔和淡出为暗色，目标字幕在 `0.18s` 防抖后启动 `0.22s` 淡入，在滚动落位的同时顺滑亮起（主台词、次台词与底部编号/剧集/时间同步渐变）。
2. **连续导航与防抖**：快速连按或长按方向键、连续拨动滚轮/触控板或快速拖动滚动条期间，列表平滑滚动且途经的所有字幕均保持未选中暗色，不出现逐行闪烁；停止操作（或按住滚动条停住不动）满 `0.18s` 后，当前中心字幕才平滑淡入变亮。
3. **半途打断与边界**：当目标字幕正在淡入途中（尚未完全变亮）再次触发导航时，该字幕直接从当前亮度平滑折返淡出，无跳变闪烁；在第一条按 `↑` 或最后一条按 `↓` 时，焦点字幕保持亮色不闪烁；导航滚动或防抖期间按下快捷键（如回车、`S`、`C`、`X`），立即对最新目标字幕执行对应操作。