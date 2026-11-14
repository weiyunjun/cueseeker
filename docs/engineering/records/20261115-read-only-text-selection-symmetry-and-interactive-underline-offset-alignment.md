# 只读静态文本选区上下对称与可点击悬停下划线偏移对齐工程实现记录

- 对应需求单：`docs/human/requirements/20261115-UI-Read-Only Text Selection Symmetry And Interactive Underline Offset Alignment.md`
- 分支 / 起始提交：`main`（变更前：`1495dc9`，需求单提交后：`6cf2f76`）

## 修改摘要

1. **设计常量补齐与固定行高显式接入**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControlMetrics.swift`：补齐 `--line-height-status-indicator: 20px`（`redesignLineHeightStatusIndicator`）。
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchStatusIndicator.swift`：为状态提示文传入 `lineHeight: WorkbenchControlMetrics.redesignLineHeightStatusIndicator`（整体控件高度保持 `36px`）。
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogHeader.swift`：为详情弹窗标题（`WorkbenchDetailHeaderRow`）传入 `lineHeight: WorkbenchControlMetrics.redesignDetailFileTitleLineHeight`。

2. **播放页字幕流选区对称、相邻平分衔接与裁剪修复**
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackVisualLineStackLayout.swift`：新增 `selectionRects(forUTF16Range:in:)` 并在 `drawSelection(forUTF16Range:in:clipRect:)` 中复用每行已计算的 `visibleCenterY` 与 `nominalLineHeight` 生成上下 1:1 对称选区；仅当相邻两行同时处于选中状态且上下边界重叠时，在重叠/缝隙中点（`(prev.maxY + curr.minY) / 2`）平分衔接。同时为 `PlaybackSubtitleFocusNativeTextLayout.draw` 传入包含 `--padding-subtitle-focus-cue-y` 的外层裁剪框。
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueResult.swift`：在 `drawPreparedPlan` 中将选区裁剪框扩展到包含顶部/底部 `--padding-subtitle-focus-cue-y` 的完整台词区域（有下方 metadata 时止步于 `metadataRect.minY`），避免裁掉首尾行选区上下留白。

3. **工作台与表格固定行高视觉居中与非固定行高选区**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSelectableText.swift`：移除静态拉丁字体固定 `.baselineOffset`，改为遍历当前视觉行实际 `CTRun` 字体度量（`fontMidYOffset = (max(runFont.ascender) + min(runFont.descender)) / 2` 与 `max(-runFont.underlinePosition)`）：
     - 固定 `lineHeight` 文本按每视觉行统一 `deltaY` 在各自 `Line Height` 内垂直居中（避免按字形墨迹边界动态平移导致的基线跳动），选区高取完整 `lineHeight` 对称展开。
     - 未指定 `lineHeight`（`lineHeight == nil`）的普通静态可选文本保持 `WorkbenchSelectableTextSizingLayout` 外层尺寸测算、字形绘制位置与 TextKit 原生选区矩形（`enumerateEnclosingRects`）完全一致，避免含下延/高亮标点字符时选区顶部被削平贴字。
   - `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableTextLayout.swift`、`SubtitleTableCueGeometry.swift`、`SubtitleTableCoordinator+Drawing.swift`、`SubtitleTableCoordinator+SelectionAndInput.swift`、`SubtitleTableCoordinator+Testing.swift`：移除静态 `.baselineOffset`，统一按当前视觉行实际 `CTRun` 字体度量中点（`(maxAscender + minDescender) / 2`）在固定行高（正文 `20px`、主台词 `24px`、附加台词 `20px`）内垂直居中，同字体不同字符组合（下延字母 / 纯标点 / 纯数字）基线零跳动；表格表头以每列可见字体中心（`firstLineCenterYOffset`）对齐 `cellRect.midY`（消除 `ceil` 行高舍入误差），复用 `SubtitleTableText.cellLineHeight`（`20px`）生成顶底严格水平对齐的对称选区，并将表头 `clipRect` 高度放宽至足以完整容纳 `20px` 对称选区而不溢出单元格。

4. **全应用 4 处 Grab 悬停下划线偏移统一**
   - `WorkbenchSelectableTextNSView.underlineRects` 去除错误重复扣减的 `- baselineOffset`，与 `SubtitleTextLayout.underlineRects` 统一基于实际绘制基线（`lineFragmentRect.minY + originalBaselineY + deltaY`）加上当前视觉行各 `CTRun` 最低默认下划线位置（`max(-runFont.underlinePosition)`）及 `--offset-interactive-text-underline`（`2px`）绘制 `1px` 像素对齐下划线。

5. **边界确认与同步测试断言**
   - 严守奥卡姆剃刀原则：未新建任何独立排版框架、度量引擎文件、中间模型或自定义表头视图，未改动 `docs/human/design/`，正式代码未引入任何测试专用属性或探针。
   - 在 `SubtitleTextLayoutDecorationTests.swift` 补充同字体角色跨字符形状一致选区/下划线测试与表头多列选区 `minY` / 高度严格一致测试；同步更新了 `WorkbenchSelectableTextTests.swift`、`SubtitleTextLayoutTests.swift`、`SubtitleTextLayoutDecorationTests.swift`、`SubtitleTableCueGeometryTests.swift` 中因移除静态 `.baselineOffset` 而失效的旧断言。

## 编译与单元测试验证

1. **减法修正后最终编译与定向无窗口纯逻辑测试验证（基于 `f28cc51` 修正并最后一次修改代码后执行）**：
   - 执行 `swift build --package-path apps/macos-native`：编译通过（`Build complete! (6.76s)`）。
   - 执行 `swift test --package-path apps/macos-native --filter SubtitleTextLayout --filter SubtitleTableCueGeometry --filter WorkbenchSelectableText --filter PlaybackVisualLineStackLayout`：`49` 项全部通过（0 失败）。
2. **端到端验收**：
   - 视觉居中、中英混排、同字体跨字符基线稳定性、表头选区水平对齐、播放字幕流选区边界以及 4 处 `Grab` 悬停下划线表现均留待用户在实际运行界面中验收。
