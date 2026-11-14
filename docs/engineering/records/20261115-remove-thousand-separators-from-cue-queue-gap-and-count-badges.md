# 移除台词队列控制栏间隔时间与计数徽章千分位逗号工程实现记录

- 对应需求单：`docs/human/requirements/20261115-UI-Remove Thousand Separators From Cue Queue Gap And Count Badges.md`
- 分支 / 起始提交：`main`（`4cd0d06`）

## 修改摘要

1. **移除播放页台词队列控制栏间隔时间千分位逗号（`C-12.7 Player Cue Queue Control Bar`）**
   - `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackCueQueueControlBar.swift`：在 `PlaybackCueQueueGapStepper.body` 中先将间隔数值构造为纯 `String` 文本 `gapText = "\(gapMilliseconds) ms"`，并将 `Text` 与 `.accessibilityValue` 改为直接接收该 `String` 变量，避免 SwiftUI 将整数字面量插值按 `LocalizedStringKey` 隐式附加本地化千分位逗号（`1,000 ms` / `10,000 ms` 恢复为连续阿拉伯数字 `1000 ms` / `10000 ms`）。现有尺寸与样式 Token（包括 `cueQueueGapValueWidth`）保持不变。
2. **移除计数胶囊徽章千分位逗号（`C-08.3 Information Badge` / `Task Count Badge`）**
   - `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`：将 `TaskCountBadge` 中的 `Text("\(count)")` 改为 `Text(String(count))`（与筛选项计数 `CueFacetFilterChip` 保持一致），统一覆盖主窗口与播放页顶栏任务入口按钮、工具栏筛选按钮以及筛选弹窗分组标题右侧紧凑徽章，使 `>= 1000` 的计数值展示为连续阿拉伯数字（如 `1000`）。现有尺寸与样式 Token 保持不变。
3. **边界确认**
   - 未新建任何独立模块、通用格式化工具或中间模型；未改动不会达到 `1000` 的播放页音量百分比控件；未新增或修改任何 UI Token；未改动 `docs/human/design/` 文档与任何正式代码测试后门。

## 编译与单元测试验证

以下验证均在最后一次代码修改后执行通过：

1. **编译验证**：
   - 执行 `swift build --package-path apps/macos-native`
   - 结果：编译通过（`Build complete!`）。
2. **定向无窗口纯逻辑测试（防弹窗与防抢焦点过滤）**：
   - 执行 `swift test --package-path apps/macos-native --filter "SettingsStorePlaybackTests|TaskQueueStoreTests|WorkbenchControlMetricsTests|PlaybackSegmentCompletionTests"`
   - 结果：Swift Testing 执行 93 项全部通过（0 失败，无窗口弹出）。
3. **端到端验收**：
   - 视觉样式与交互留待人类在播放页与主窗口场景中完成实测验收。
