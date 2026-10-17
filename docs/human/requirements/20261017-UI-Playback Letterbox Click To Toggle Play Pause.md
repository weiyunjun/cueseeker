# 版本

main

# 关联设计

- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Interaction Rules.md`

# 需求描述

1. **问题背景**：
   - 当前单击切换播放/暂停的手势 `.onTapGesture` 仅挂载在 `PlaybackView.swift` 的视频渲染视图上，并在 `PlaybackVideoStage.swift` 中被约束在按视频宽高比 `aspectFitFrame` 计算出的 `playbackSurface` 画面矩形内，底层全窗口 `Color.black` 背景未绑定点击事件；同时 `PlaybackChromeView.swift` 的底栏容器 `chromeSurface` 将顶部 `--padding-player-progress-top: 16px` 留白也包含在 `.contentShape(Rectangle())` 内整块拦截了点击。
   - 这导致当窗口比例与视频比例不一致时，点击视频画面上下方的黑边（Letterbox）或左右两侧的黑边（Pillarbox）无法触发播放/暂停。

2. **播放舞台单击播放/暂停热区规则**：
   - **水平范围**：覆盖整个播放窗口宽度（`100%`），即视频画面本身及左右黑边（Pillarbox）均响应单击播放/暂停。
   - **垂直范围**：
     - **当 Player UI 显示时**：
       - **上边界**：顶栏下沿（即顶部 `--height-app-topbar: 54px` 以下）。顶栏 `54px` 区域属于窗口顶栏（用于内部按钮交互、拖拽移动窗口及双击缩放窗口），点击顶栏不触发播放/暂停。
       - **下边界**：**底栏进度条交互热区（`--height-player-progress-hit-area: 18px`）的上沿**。即从顶栏下沿（`54px`）一直到底栏进度条热区上沿（距窗口底边 `82px`）之间的整个区域（包含视频画面、上下左右黑边、以及底栏中位于进度条热区上方的 `--padding-player-progress-top: 16px` 顶部内边距区域），单击均触发播放/暂停。
       - **进度条热区上沿至窗口最底边（高 `82px`）**：属于底栏控制区（`18px` 进度条热区行、`52px` 底部控制按钮行及 `12px` 底部内边距），点击该区域（含进度条左右内边距及按钮之间的空白）不触发画面播放/暂停。
     - **当 Player UI 隐藏时**：
       - 全窗口舞台区域（`100% × 100%`，包含视频画面与上下左右全部黑边）单击均触发播放/暂停；**遵循 `UI Interaction Rules.md` §10.3–10.4，纯点击不唤醒 Player UI，也不重置隐藏计时**。
   - **更高层界面与菜单模态屏蔽保持不变**：
     - 遵循 `UI Interaction Rules.md` §1–§3：当播放页开启了 Player Speed Menu、Player More Menu（及其二级子菜单）时，左键在菜单外点击仅关闭菜单，不传给下层舞台；当 Playback Overlay（Current / Playlist / Editing Collage）、Command Panel 或窗口内对话框（含任务界面）打开时，下层播放舞台被屏蔽，点击不触发视频播放/暂停。

3. **设计文档同步**：
   - 待改动验收通过后，同步更新 `UI Layouts - Playback.md` 与 `UI Interaction Rules.md` 中关于播放页画面点击区域的描述。

# 验收标准

1. 在播放页（Player UI 显示状态下），单击视频画面、画面上方的黑边（顶栏 `54px` 以下）、画面下方的黑边（直至底栏进度条热区上沿）、以及画面左右两侧的黑边，均能正常切换视频播放/暂停。
2. 单击顶栏 `54px` 区域或底栏进度条热区及以下区域，不会误触视频播放/暂停。
3. Player UI 隐藏状态下（鼠标未发生移动），单击窗口任意画面或黑边位置均可正常切换播放/暂停，且不会唤醒 Player UI 或指针。