# 版本

main

# 关联设计

- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/playback/Controller.md`
- `docs/human/design/playback/Command Panel.md`

# 需求描述

1. **补齐无需异步预热封面的页面切换完成日志，消除起点状态残留**：
   - 在主界面（`Workbench`）、字幕聚焦遮罩（`Playback Overlay`）及快捷命令面板（`Command Panel`）中，当切换到无需异步预热封面的页面（如 `Search`、`File`、摘录二级详情、字幕遮罩 `Current` / `Collage` / `Playlist`、命令面板 `Search Results` 等）或首屏封面已全部命中内存缓存的页面时，必须正常输出对应的导航完成耗时日志，不得漏记；
   - 消除因前一次导航未结算而残留的起点状态，避免后续关闭遮罩或面板时输出起点与终点错乱（如 `closed -> closed`）的异常完成日志。

2. **修正播放页底栏弹出菜单的埋点时序，消除跨次残留的虚假超长耗时**：
   - 在播放页底栏点击「更多（`...`）」「字幕」「倍速」等弹出菜单时，必须在菜单打开结算前准确记录本次点击与尺寸测量的开始时间，完整统计当次菜单从点击触发、尺寸测量到首帧上屏的真实耗时；
   - 菜单已打开后的布局重算或菜单关闭后，不得在全局状态中残留未消费的菜单触发时间戳，避免下一次打开任意菜单时错误套用数秒至数十秒前的旧时间戳而产生虚假慢菜单日志。

3. **排除主线程空闲休眠唤醒阶段的误报卡顿**：
   - 主线程卡顿监控在统计事件循环阶段耗时时，凡是从休眠等待阶段（`beforeWaiting`）唤醒进入下一阶段的耗时（包括 `beforeWaiting -> afterWaiting` 与 `beforeWaiting -> entry` 等空闲等待路径），均视为正常的空闲休眠时间并予以排除，不得将用户静置未操作期间的休眠时长误报为主线程卡顿。

# 验收标准

1. **页面切换完成日志零漏报、零错乱**：在 Debug 构建下切换主界面无封面页（如 `Search`、`File`、摘录二级详情）、首屏封面已缓存的封面页、打开/切换/关闭字幕聚焦遮罩各标签、以及打开/切换/关闭快捷命令面板各页面时，每次切换均能准确输出对应的 `navigation completed` / `transition completed` 日志，且不再出现 `from=closed to=closed` 等起点污染记录。
2. **播放页菜单打开耗时真实准确**：在播放页反复打开「更多」「字幕」「倍速」菜单（含静置数秒至数十秒后再次打开另一个菜单），每次输出的 `Menu open completed` 耗时均反映当次点击的真实毫秒级耗时，不再出现 0ms 漏算或数秒至数十秒的跨次残留耗时。
3. **静置唤醒不再误报主线程卡顿**：在任意界面或弹窗打开后静置数秒至数十秒不操作、随后再次移动鼠标或按键唤醒时，调试日志不再输出 `phase=beforeWaiting->entry` 等将休眠时长计入的虚假主线程卡顿告警；真正发生在主线程工作阶段的 `≥ 32ms` 阻塞仍正常捕获。