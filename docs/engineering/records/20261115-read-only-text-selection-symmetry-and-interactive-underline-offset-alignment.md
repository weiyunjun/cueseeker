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

3. **工作台与表格固定行高视觉居中与非固定行高对称选区**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSelectableText.swift`：移除静态拉丁字体固定 `.baselineOffset`，引入 `CoreText` 逐行测量实际渲染字形（含截断省略号 `…`）可见中心与 `CTRun` 下划线偏移：
     - 固定 `lineHeight` 文本按每视觉行统一 `deltaY` 在各自 `Line Height` 内视觉居中，保持同行中英文基线一致，选区高取完整 `lineHeight` 对称展开。
     - 未指定 `lineHeight`（`lineHeight == nil`）的普通静态可选文本保持 `WorkbenchSelectableTextSizingLayout` 外层尺寸测算与字形绘制位置完全不变（确保弹窗 `24px` 顶留白与双行卡片 `68px` 高度零偏移），仅将选区矩形调整为围绕可见字形中心上下对称并限制在可用行界与视图边界内，消除底边被 `bounds` 不对称裁切。
   - `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableTextLayout.swift`、`SubtitleTableCueGeometry.swift`、`SubtitleTableCoordinator+Drawing.swift`、`SubtitleTableCoordinator+SelectionAndInput.swift`、`SubtitleTableCoordinator+Testing.swift`：移除静态 `.baselineOffset`，统一按逐视觉行可见字形边界在固定行高（正文 `20px`、主台词 `24px`、附加台词 `20px`）内垂直居中；表格表头选区复用 `SubtitleTableText.cellLineHeight`（`20px`）围绕表头可见字形中心上下对称绘制，并将表头 `clipRect` 高度放宽至足以完整容纳 `20px` 对称选区而不溢出单元格。

4. **全应用 4 处 Grab 悬停下划线偏移统一**
   - `WorkbenchSelectableTextNSView.underlineRects` 去除错误重复扣减的 `- baselineOffset`，与 `SubtitleTextLayout.underlineRects` 统一基于实际绘制基线（`lineFragmentRect.minY + originalBaselineY + deltaY`）加上当前视觉行各 `CTRun` 最低默认下划线位置（`max(-runFont.underlinePosition)`）及 `--offset-interactive-text-underline`（`2px`）绘制 `1px` 像素对齐下划线。

5. **边界确认与同步测试断言**
   - 严守奥卡姆剃刀原则：未新建任何独立排版框架、度量引擎文件、中间模型或自定义表头视图，未改动 `docs/human/design/`，正式代码未引入任何测试专用属性或探针。
   - 仅因固定 `.baselineOffset` 移除导致 4 处既有旧几何单元测试断言失效，已做最小化同步更新：`WorkbenchSelectableTextTests.swift`、`SubtitleTextLayoutTests.swift`、`SubtitleTextLayoutDecorationTests.swift`、`SubtitleTableCueGeometryTests.swift`。

## 编译与单元测试验证

1. **定向排版/选区/表格测试验证（最后一次代码修改后执行）**：
   - 执行 `swift test --package-path apps/macos-native --filter "SubtitleTextLayout|SubtitleTableCueGeometry|WorkbenchControlMetrics|WorkbenchSelectableTextTests|SubtitleTableVirtualRowTests"`：183 项全部通过（0 失败）。
   - 执行 `swift test --package-path apps/macos-native --filter "PlaybackVisualLineStack|PlaybackCueResult|SubtitleTableExternalTextSelectionTests|SettingsAndDialogsStaticTextSelectionTests"`：33 项全部通过（0 失败）。
2. **全量无弹窗过滤回归说明**：
   - 运行 `swift test --package-path apps/macos-native --skip DebugE2EControllerTests --skip WorkbenchInputControlsTests --skip PointerHoverGateTests --skip CueGroupRefreshScopeIntegrationTests --skip PlaybackPageFocusIsolationTests` 共执行 1695 项测试；其中 63 项失败均位于与本次文本排版/选区/下划线改动无关的现有模块测试（如本地化文案 `AppLocalizationTests`、播放焦点模块列表 `PlaybackSubtitleFocusLayoutTests`、Native 播放时序与媒体测试、Tooltip 测试等），本次受影响的全部文本排版、选区、表格与下划线相关测试套件 0 失败。
3. **端到端验收**：
   - 视觉居中、中英混排、纯大写/数字对称选区、播放字幕流选区边界以及 4 处 `Grab` 悬停下划线表现均留待用户在实际运行界面中验收。
