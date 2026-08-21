# Playback Cue Timeline Sequence Removal And Metadata Ordinal

## Human-owned document

- `docs/human/requirements/20260821-UI-Playback Cue Timeline Sequence Removal And Metadata Ordinal.md`

## Problem

四个复用同一个 Reel 的界面（Playback Current、Playback Cue Playlist、Editing Collage、
Command Panel Search）在时间轴左侧渲染一列 24px Semibold 的序号，占据
`位数 × 16px + 24px` 的水平空间。它视觉噪音强，而且让正文列宽随数据集序号位数变化；
同时 12px 的圆点相对 24px 正文偏大。

## Change

### 时间轴

删除时间轴的序号元素，行内首个元素改为标记本身。`PlaybackCueTimelineRowLayout` 不再
携带序号矩形，`leadingAccessoryWidth` 只剩「标记宽 + `--spacing-6`」，序号绘制、序号列
宽推导、序号字体以及 `--width-playback-cue-sequence-digit` 一并移除。适配器协议里只为
序号列宽存在的 `sequenceTotalCount` 同时删除。

圆点尺寸由 `--spacing-3: 12px` 改为 `--spacing-2: 8px`。圆心对齐与圆点—连接线间距不需要
额外处理：标记纵坐标由圆心反推，连接线端点由圆点边缘加 `--spacing-2` 反推，两个约束随
尺寸自动成立。Collage 的 Checkbox 标记不变。

释放出的水平空间归字幕正文，内容列总宽仍为 `--width-subtitle-focus-content-max`，正文
列宽从此与序号位数无关。

关键文件：
- `Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`

### 元信息序号

`PlaybackCueMetadata` 增加可选的 0-based `ordinal`，渲染为 1-based 的 `#N`；元信息行的
锚点由「Display Title + Time Range」扩为「Ordinal + Display Title + Time Range」，三段
之间沿用既有 Item Gap `--spacing-3`，不新增 Token。宽度不足时先保留序号与 Time Range，
由 Display Title 吸收剩余宽度。

序号来自列表项自身的位置：`PlaybackPlaylistItem.cueResult()` 把 `ordinal` 一起带进
metadata。Cue Playlist 与 Command Panel Search 共用这一条路径，不按界面分支。Current 与
Editing Collage 走的是 `PlaybackSubtitleFocusCueReelAdapter`，不传 `ordinal`，因此不显示
序号。

关键文件：
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueResult.swift`
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackPlaylistSource.swift`

### Footer 对齐

Footer 与 Reel 原本就共用「内容最大宽度居中 + `--spacing-8` 内缩」，两者左边缘在数学上
相等。序号列移除后行首元素变成圆点，因此 `{N} cues` 自动落在圆点左边缘，无需改动 Footer
布局代码，只需在验证中锁定这条不变量。Command Panel Search 的 Footer 使用面板自身的
内缩，不在本需求范围内，保持现状。

## Verification

- `swift build`、`swift test`：`--filter` 覆盖 Reel、Timeline、Collage、Cue Result、
  Virtual Reel 共 36 个用例全部通过。整包 `CueSeekerAppTests` 的失败项与改动前基线同类
  （窗口/计时相关的既有不稳定用例，两次运行失败集合不同），没有新增失败。
- 用例调整：`PlaybackSubtitleFocusLayoutTests` 的序号断言替换为「行首即标记、标记宽等于
  `dotSize`、标记左边缘等于行左边缘、连接线居中于标记且两端各留 `--spacing-2`」，并新增
  一个栅格用例断言圆点墨迹中心等于标记中心；`PlaybackPlaylistReelAdapterTests` 与
  `PlaybackSubtitleFocusKeyboardActionTests` 移除 `sequenceTotalCount` 断言。
- Debug E2E（`--cueseeker-debug-e2e`，`capture` 出图后逐像素测量，缩放为 2）：
  - Current（1445pt 窗口）：左侧无数字；圆点 16px = **8pt**；圆点左边缘与 `644 cues`
    左边缘同为 **242.5pt**，等于 `(1445 − 960) / 2`。
  - Editing Collage：左侧无数字；Checkbox 保持 24pt；Checkbox 左边缘与 `644 cues`
    左边缘同为 **754.5pt**。
  - Cue Playlist（Shiori 列表 Resume 进入播放后切到 Playlist 页）：左侧无数字；
    元信息行为 `#114  葬送的芙莉莲 - 20  10:05 - 10:07`，起点 **274.5pt**，等于
    行左边缘 242.5 + 圆点 8 + `--spacing-6` 24；三段之间的墨迹间距约 13.5pt，与
    `--spacing-3: 12px` 的盒间距一致；圆点 8pt，`396 cues` 左边缘 242.5pt。

## Outcome

符合预期。

## 自动化缺口

Command Panel Search 需要按反引号键打开，而 Debug E2E 控制器的 `keyPress` 只支持字母、
数字、`enter`、`escape`、`tab`、`space` 和方向键，没有反引号，因此这一屏无法自动到达。
本次它只由单元测试覆盖：它与 Cue Playlist 共用同一个 Cue Result Reel、同一个适配器和
同一条 metadata 路径，Cue Playlist 的真机结果可作为等价证据，但不是这一屏本身的截图。
如果需要把这一屏纳入自动化，需要先扩展 `keyPress` 的按键集合。
