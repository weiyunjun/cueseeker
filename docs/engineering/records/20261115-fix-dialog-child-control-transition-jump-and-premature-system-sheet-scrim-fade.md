# 修复对话框进出场子控件跳动与系统文件面板 Scrim 提前淡出工程实现记录

- Date: 2026-11-15
- Related Requirement: `docs/human/requirements/20261115-UI-Fix Dialog Child Control Transition Jump And Premature System Sheet Scrim Fade.md`
- Related Design: `docs/human/design/ui/UI Tokens.md`、`docs/human/design/ui/UI Components - Domain.md`、`docs/human/design/ui/UI Interaction Rules.md`
- Branch / Baseline: `main`（初版需求提交 `6ba187a` -> 初版实现 `9170329` -> 需求单更新 `73ebd69`）
- Scope: `CueSeekerApp`, `CueSeekerAppTests`

## Changes Made

1. **恢复单一 `Animatable` 对话框过渡修饰器，消除过渡中途子控件刷新跳位与错层（`WorkbenchDialogLayer.swift`，提交于 `9170329` 并在本次保持不变）**：
   - 在 `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift` 的 `WorkbenchDialogMotion` 中新增 `TransitionFrame` 与纯计算方法 `transitionFrame(progress:isEntering:reducesMotion:)`：
     - 常规模式（`reducesMotion == false`）：按线性的 `progress`（入场 `0 -> 1`、退场 `1 -> 0`）结合 `UnitBezier.value(at:)` 与 `WorkbenchDialogMotion` Token 同步计算当帧整张弹窗的 `opacity` 与 `offsetY`——入场使用 `enterEasing`（`0.27s`）计算位移、`fadeInDuration`（`0.12s`）与 `fadeInEasing` 计算淡入；退场使用 `elapsed = 1 - clampedProgress` 配合 `exitEasing`（`0.27s`）计算位移、`fadeOutDuration`（`0.22s`）与 `fadeOutEasing` 计算淡出。
     - 减弱动态效果模式（同时兼顾传入参数与 `@Environment(\.accessibilityReduceMotion)`）：保持 `offsetY = 0`，仅按 `progress` 做原位纯透明度过渡（`0.18s`）。
   - 将 `AnyTransition.workbenchDialog` 恢复为单一 `Animatable` 进度修饰器 `WorkbenchDialogMotionEffect`（`progress: Double`、`isEntering: Bool`、`reducesMotion: Bool` + `@Environment(\.accessibilityReduceMotion)`），不额外在 `AnyTransition` 上叠加非线性 `.animation(...)`，完全由外层 `WorkbenchDialogLayer` 的 `dialogTransactionAnimation` 线性驱动，保留 `DebugInteractionLatencyProbe.recordDialogAnimationFrame` 调用；移除不再使用的 `enterAnimation` / `exitAnimation` / `fadeInAnimation` / `fadeOutAnimation` 及旧布尔修饰器 `WorkbenchDialogSlideModifier`。
   - 保留 `WorkbenchDialogChrome` 上常驻的 `.compositingGroup()` 及各 `NSView` 已有的 `wantsLayer = true`，确保动画起止最后一帧不闪动。

2. **彻底移除系统面板期间隐藏/切换自绘 Scrim 的冗余状态，消除打开与收起阶段明暗闪烁（本次依据 `73ebd69` 需求更新按减法简化）**：
   - 经实机验收 `9170329`，由于 `NSOpenPanel` 运行在独立系统进程服务，`windowWillBeginSheet` 触发时远端面板尚未渲染遮罩，而取消收起时系统动画完成后才回调 `completionHandler` / `windowDidEndSheet`，导致“退让/恢复”切换在打开与收起两端均出现“先亮后暗”闪烁。
   - `WorkbenchDialogLayer.swift`：移除 `@Environment(\.isSystemSheetAttached)`、`WorkbenchDialogMotion.showsScrim(hasOpenDialogs:isSystemSheetAttached:)` 及对应判断分支与过时注释，改为仅由 `hasOpenDialogs`（`!dialogIDs.isEmpty`）唯一驱动自绘 `dialogScrim` 显隐；有对话框打开期间自绘 Scrim 全程常驻，系统面板滑入与收起时由系统原生遮罩自然叠加与淡出。
   - `InterfaceLayerRegistry.swift`：移除 `isSystemSheetAttached`、`setSystemSheetAttached(_:)`、`IsSystemSheetAttachedKey`、`EnvironmentValues.isSystemSheetAttached` 与 `InterfaceLayerCoverageBridge` 对应环境注入。
   - `AppDelegate.swift` 与 `CueSeekerMainWindow.swift`：移除 `windowWillBeginSheet`、`windowDidEndSheet`、`updateSystemSheetAttachment` 及已无读取方的 `CueSeekerWindow.interfaceLayers` 属性与赋值。
   - `AppWindowControls.swift`：移除 `SystemSheetPresentation.releaseScrimOnCompletion` 及对 `interfaceLayers` / `window.sheets.count` 的读取，保留极简 `present(window, completionHandler)` 转发。

3. **更新纯逻辑单元测试（`WorkbenchDialogLayerTests.swift`）**：
   - 保留对话框层打开/关闭状态、曲线参数、外沿裁切与 `dialogTransitionFrameComputesSynchronizedOpacityAndOffset` 纯逻辑测试；移除已废弃的 `showsScrim` 断言、`systemSheetCompletionRestoresScrimEarlyAndPreservesDialogLayerState` 用例及辅助函数 `isSystemSheetAttached` 参数。未构建假窗口或模拟键鼠交互，未在正式代码中添加测试后门。

## Verification

以下验证均在最后一次代码与测试修改后执行通过：

1. **编译验证**：
   - `swift build --package-path apps/macos-native`：`Build complete! (13.97s)`，修改文件零警告、零错误。
2. **定向无窗口纯逻辑测试（严格 `--filter` 过滤，零窗口弹出）**：
   - `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchDialogLayerTests|InterfaceLayerFreezeTests|WorkbenchDialogFitTests"`
   - 结果：Swift Testing（`InterfaceLayerFreezeTests`、`WorkbenchDialogFitTests`、`WorkbenchDialogLayerTests`）`13` 项全部通过（0 失败）。
3. **端到端验收**：
   - 各对话框底部按钮与右上角 `✕` 关闭无跳动、进出场中途鼠标悬停/自动聚焦无错层已于 `9170329` 验收通过；本次在已打开对话框之上打开及取消/确认系统文件选择框（`Edit Cover`、`Export to Anki`）与系统警告框的连续遮罩表现，以及无对话框时 `File` 页添加本地文件夹表现，留待用户在实机界面完成验收；验收通过后再同步更新 `docs/human/design/` 文档。
