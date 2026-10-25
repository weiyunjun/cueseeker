# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/playback/Playback Core.md`

# 需求描述

1. **新增与复用 UI Tokens（严禁硬编码）**：
   - 新增尺寸 Token `--width-player-progress-thumbnail: 160px`（`1.3 尺寸 -> Size`，进度条关键帧缩略图固定宽度）。
   - 新增动效 Token `--delay-player-progress-thumbnail-debounce: 30ms`（`1.6 动效 -> Interaction Motion`，跨关键帧移动时的缩略图获取防抖时长）。
   - 复用间距 Token `--spacing-1`（`4px`）与圆角 Token `--radius-library-cover`（`8px`），不修改任何现有 Token 数值。

2. **组件与位置布局（`C-12.3`、`C-12.4`、`L-07.2`、`L-07.3`）**：
   - 在播放页进度条有有效视频时长且处于悬停（`Hover`）或按住拖拽（`Dragging`）状态时，在进度条悬浮时间胶囊（`C-12.4 Player Progress Time Capsule`）正上方显示目标时间点对应的视频关键帧缩略图。
   - **垂直间距**：缩略图底边与时间胶囊顶边的间距为 `--spacing-1`（`4px`），与时间胶囊底边到进度条热区顶边的 `--spacing-1`（`4px`）间距一致。
   - **水平跟随与独立贴边**：缩略图与时间胶囊均以当前指示位置为中心，`0 ms` 实时跟随移动，且各自按自身宽度在进度条轨道左右两端点内独立贴边限位。
   - **层级与点击穿透**：缩略图不接受鼠标点击（`Hit Testing: None`），且与时间胶囊一样位于左下角台词队列控制栏（`C-12.7 Player Cue Queue Control Bar`）之上，移至进度条左端时不被遮挡。

3. **尺寸、比例与外观样式**：
   - **固定宽度与自适应比例**：缩略图宽度固定为 `--width-player-progress-thumbnail`（`160px`），高度按当前播放视频的实际宽高比动态计算（不固定 16:9）；输出像素按当前屏幕缩放倍率对应缩放。
   - **纯圆角外观**：采用 `--radius-library-cover`（`8px`）圆角裁剪，无边框、无阴影、无占位底框。

4. **实时按需获取、关键帧判重与防抖更新**：
   - 加载视频时不预缓存全片缩略图，仅在悬停或拖拽进度条时实时按需获取当前播放视频的关键帧画面；切换播放视频或关闭播放页时立即清理旧视频缩略图状态。
   - **首次显示**：鼠标刚移入进度条时，下方时间胶囊立即显示，同时首张关键帧免防抖立即获取；首张画面就绪前不显示空占位框，就绪后直接显示（若极端情况下获取失败则仅显示时间胶囊）。
   - **关键帧判重与防抖**：鼠标在进度条上移动或拖拽时，先判断当前位置所属的关键帧是否发生变化——若仍在同一关键帧区间内，则保持当前画面不变、不重复发起获取、也不重置正在进行的防抖计时；仅当跨入新的关键帧区间时，经过 `--delay-player-progress-thumbnail-debounce`（`30ms`）防抖后获取新关键帧画面。
   - **无过渡直接替换**：切换到新关键帧期间，在新画面就绪前保持显示上一张缩略图，新画面就绪后 `0 ms` 直接替换（无淡入淡出或位移动画）；鼠标移出进度条且未处于拖拽状态时，缩略图与时间胶囊同步立即隐藏。

5. **设计文档一致性约束**：
   - 严禁硬编码或私自特殊实现，所有视觉与交互均须体现在 UI 设计文档体系中；待实际 UI 验收定稿后同步更新 `docs/human/design/ui/` 下对应文档。

# 验收标准

1. 在播放页悬停或按住拖拽进度条时，时间胶囊正上方 `--spacing-1`（`4px`）处显示对应位置的关键帧缩略图，`--radius-library-cover`（`8px`）圆角、无边框无阴影，宽度固定为 `--width-player-progress-thumbnail`（`160px`）且高度符合当前视频实际宽高比。
2. 鼠标移至进度条最左端或最右端时，缩略图与下方时间胶囊各自在进度条左右边界独立贴边停住；在台词队列播放模式下移至最左端时，缩略图与时间胶囊正常浮于左下角台词队列控制栏上方。
3. 鼠标在进度条上快速滑动或小幅微移时，时间胶囊与缩略图水平位置实时跟手无粘滞；在同一关键帧区间内微移不重复闪烁或重置防抖，跨关键帧满 `--delay-player-progress-thumbnail-debounce`（`30ms`）后快速更新画面且切换干脆无重影，移出进度条后立即消失。