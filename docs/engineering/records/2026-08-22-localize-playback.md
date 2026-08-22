# Localize Playback

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

覆盖需求里播放的三节：控制条与窗口按钮、二十余条 HUD 提示、字幕聚焦层与长截图与命令
面板。`Collage` 按术语基准统一译作「长截图 / 長截圖」。

字幕聚焦层的数据源标签（当前 / 播放列表 / 搜索 / 媒体库 / Shiori）与侧栏共用同一批文案键，
避免同一个词在两处出现不同译法。

播放页面里长期存在的几个视图——控制条、底部计数、聚焦层覆盖、命令面板、长截图预览、
剧集覆盖层——都观察语言存储，语言变化时各自重新求值。HUD 提示是每次触发时构造的瞬时
消息，不存在缓存问题。

关键文件：
- `Sources/CueSeekerApp/Playback/PlaybackViewModel.swift`
- `Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift`
- `Sources/CueSeekerApp/Playback/TopBar/LiquidGlassWindowControlButton.swift`
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueFooter.swift`

### 测试托管点需要补注入

`PlaybackSubtitleFocusOverlay` 在三处测试里被单独托管渲染，不经过 App 外壳，因此它一旦
观察语言存储就必须在这些托管点补上注入，否则渲染时会崩。测试目标里加了一个构造临时语言
存储的辅助函数供这三处使用。

## Verification

- `swift build --product CueSeeker` 通过。
- 播放聚焦、失效范围、本地化相关共 145 个用例：仅两个改动前就存在的失败
  （`shioriTableStartsAtTopAfterPanelRemount`、`showCueGroupInvalidationIsScopedToMountedShiori`）。
- Debug E2E 真机验证：简体中文下进入媒体库并打开一个剧集文件夹，汇总为
  「13 个视频 13 个字幕」，按钮为「继续播放」；点开集数后视频正常播放。
  验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 未能真机验证的部分

播放控制条在无鼠标移动时会自动隐藏，而 Debug E2E 只有点击和滚动，没有单纯的移动指针
命令，因此截不到控制条、HUD 提示、命令面板和长截图编辑这几屏。它们本次只有编译与单元
层面的覆盖，取文案走的是与其它界面相同的入口。要把这几屏纳入自动化，需要先给 E2E 增加
移动指针的能力。
