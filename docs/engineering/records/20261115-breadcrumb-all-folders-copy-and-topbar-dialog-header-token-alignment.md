# 面包屑 All Folders 文案统一、设计 Token 收口与 Task 面板头部视觉边界对齐工程实现记录

- 对应需求单：`docs/human/requirements/20261115-UI-Breadcrumb All Folders Copy And Topbar Dialog Header Token Alignment.md`
- 分支 / 起始提交：`main`（变更前：`6f0d262`，需求单提交后：`5d4dcf4`）

## 修改摘要

1. **`All Folders` 多语言文案统一与孤儿代码清理（`L-04.5`）**
   - `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`：移除 `file.all_folders.one` / `file.all_folders.other` 单复数拆分词条，统一合并为单一词条 `file.all_folders`（英文 `All Folders`、简中 `全部文件夹`、繁中 `全部資料夾`）。
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`、`apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+WorkbenchAccessibility.swift`：移除 `FileBreadcrumbResolver.allFoldersTitle` 及 `folderCount`/`singularRootTitle`/`pluralRootTitle` 分支参数，将 `rootFoldersHeaderRow`、`breadcrumbNodes` 与无障碍节点/点击跳转解析统一为单一 `L("file.all_folders")`，同步删除已无用途的 `folders` 局部变量。

2. **面包屑与 `File` 一级标题样式收口（`C-05.6` / `L-04.5` / `L-06.4`）**
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`：清理共用 `BreadcrumbLink` 的 `@State isHovered` 与 `.onPointerHover` 悬停追踪状态，固定 link 文字颜色为 `WorkbenchRedesignColors.textSecondary`（`--color-text-secondary`），保持无障碍焦点环、点击跳转与整条禁选/跨区起选规则不变。
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`、`apps/macos-native/Sources/CueSeekerApp/Library/RemoteFolderDialogSharedViews.swift`：将 `File` 一级 `All Folders` 标题、二/三级面包屑末级当前节点及远程目录浏览第 2 步面包屑末级当前节点的字重从 `.semibold` 统一为 `WorkbenchControlMetrics.redesignFontWeightControl`（`--font-weight-control: 500`）。

3. **设计 Tokens 补齐与局部硬编码清理（`UI Tokens` / `C-05.4` / `C-05.5` / `C-10.1` / `L-01.2` / `L-03.1` / `L-07.1` / `L-08.2`）**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControlMetrics.swift`：补齐并导出全局标签页与弹窗标题 Tokens：`redesignFontWeightTab`（`--font-weight-tab: 600`）、`redesignTabIndicatorWidth`（`--width-tab-indicator: 24px`）、`redesignTabIndicatorHeight`（`--height-tab-indicator: 2px`）、`redesignTabMotionEasing`（`--easing-tab-motion: cubic-bezier(0.22, 1, 0.36, 1)`）、`redesignFontWeightDialogTitle` / `redesignNSFontWeightDialogTitle`（`--font-weight-dialog-title: 600`）；让 `redesignDialogTitleCapTopInset` 直接引用 `redesignNSFontWeightDialogTitle`；删除临时常量 `redesignAppTopbarContentHorizontalPadding`，将 `redesignAppTopbarContentTrailingPadding` 收口为 `redesignSpacing6 + redesignWorkbenchPageScrollbarChannel`。
   - `apps/macos-native/Sources/CueSeekerApp/Workbench/AppTopbarLayout.swift`：将工作台顶栏展开态左侧内边距引用收口至 `WorkbenchControlMetrics.redesignSpacing6`。
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogHeader.swift`：`WorkbenchDialogHeader` 标题字重引用 `WorkbenchControlMetrics.redesignFontWeightDialogTitle`。
   - `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`：`PlaybackOverlayMetrics` 改为直接委托 `WorkbenchControlMetrics` 中的标签页 Tokens，消除共用 `WorkbenchTabs` 链路的局部字面量与动画曲线硬编码；`PlaybackChromeMetrics.topbarHorizontalPadding` 与 `windowControlsReturnGap` 消除临时注释与耦合别名，对齐 `WorkbenchControlMetrics.redesignSpacing4`（`16px`），与 `--padding-player-topbar-x` / `--gap-player-window-controls-return` 一致。

4. **`Task` 面板头部对齐 `24px` 视觉边界（`C-10.1` / `L-06.9`）**
   - `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`：移除 `headerRow` 末尾强制拉伸行高的 `.frame(height: WorkbenchControlMetrics.redesignSegmentedControlHeight)` 及行内未补偿 `WorkbenchIconButton`，改为外层容器统一挂载 `.workbenchDialogCloseButton(closesOnEscape: confirmation.session == nil && tasks.detailTaskID == nil)`，为 `WorkbenchAdaptiveHeaderBar` 补上 `.fixedSize(horizontal: false, vertical: true)` 使其纵向按标题自然行高收缩（避免在 `500px` 高度 `VStack` 中与下方列表区平分纵向高度），并在 `trailing` 槽位以非交互无障碍隐藏的 `Color.clear.frame(width: WorkbenchControlMetrics.redesignDialogCloseGlyphInk, height: 1)` 保留右上角关闭字形墨迹宽度避让；左上角 `Task` 标题改用 `redesignFontWeightDialogTitle` 并保持截断 Tooltip、中间 `WorkbenchTabs` 垂直居中/水平居中/窄宽 `--spacing-3` 避让、`Esc` 屏蔽条件与无障碍遍历顺序不变。

5. **边界确认与同步测试断言**
   - 严守最小充分设计：在现有文件中原位修改，未新建任何独立模块、通用引擎、管理层或冗余模型；未改动 `docs/human/` 下任何设计文档；正式代码未引入任何测试后门。
   - 仅同步更新受影响的两个纯逻辑测试文件：`apps/macos-native/Tests/CueSeekerAppTests/FileRouteNavigationTests.swift`（适配单一 `All Folders` 与简化签名）、`apps/macos-native/Tests/CueSeekerAppTests/WorkbenchControlMetricsTests.swift`（替换已删 `redesignAppTopbarContentHorizontalPadding` 断言并校验新增 Tokens 与 `PlaybackChromeMetrics`）。

## 编译与单元测试验证

以下验证均在最后一次代码与测试断言修改后执行通过：

1. **编译验证**：
   - 执行 `swift build --package-path apps/macos-native`
   - 结果：`Build complete! (0.32s)`，0 错误。
2. **定向无窗口纯逻辑测试（严格 `--filter` 过滤，零窗口弹出）**：
   - 执行 `swift test --package-path apps/macos-native --filter "FileRouteNavigationTests|WorkbenchControlMetricsTests|WorkbenchLayoutStateTests|WorkbenchAccessibilityStep2Tests|everyBundledLanguageDefinesTheSameKeys|singularCountKeysDoNotContainUnresolvedFormatPlaceholders"`
   - 结果：Swift Testing 执行 `50` 项全部通过（0 失败，包含 `FileRouteNavigationTests`、`WorkbenchControlMetricsTests`、`WorkbenchLayoutStateTests`、`WorkbenchAccessibilityStep2Tests` 全部用例及多语言键对齐检查）。（注：未改动且历史存在无关陈旧断言的 `AppLocalizationTests.simplifiedAndTraditionalChineseRefinedTranslationsMatchSpecification` 在先前包含全套 `AppLocalizationTests` 的运行中于 `en["file_detail.associated_video"]` 失败，不属于本次修改范围。）
3. **端到端验收**：
   - 面包屑 Hover/字重、`All Folders` 标题、顶栏边距及 `Task` 面板四边 `24px` 视觉边界、`Tabs` 居中避让、Tooltip 与 `Esc` / 无障碍遍历表现均留待用户在实际运行界面中完成实测验收。
