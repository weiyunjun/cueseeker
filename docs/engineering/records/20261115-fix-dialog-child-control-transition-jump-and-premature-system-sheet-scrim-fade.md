# 修复对话框进出场子控件跳动与系统文件面板 Scrim 提前淡出工程实现记录

- Date: 2026-11-15
- Related Requirement: `docs/human/requirements/20261115-UI-Fix Dialog Child Control Transition Jump And Premature System Sheet Scrim Fade.md`
- Related Design: `docs/human/design/ui/UI Tokens.md`、`docs/human/design/ui/UI Components - Domain.md`、`docs/human/design/ui/UI Interaction Rules.md`
- Branch / Baseline: `main`（需求单已由人工提交于 `6ba187a`）
- Scope: `CueSeekerApp`, `CueSeekerAppTests`

## Changes Made

1. **恢复单一 `Animatable` 对话框过渡修饰器，消除过渡中途子控件刷新跳位与错层（`WorkbenchDialogLayer.swift`）**：
   - 在 `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift` 的 `WorkbenchDialogMotion` 中新增 `TransitionFrame` 与纯计算方法 `transitionFrame(progress:isEntering:reducesMotion:)`：
     - 常规模式（`reducesMotion == false`）：按线性的 `progress`（入场 `0 -> 1`、退场 `1 -> 0`）结合 `UnitBezier.value(at:)` 与 `WorkbenchDialogMotion` Token 同步计算当帧整张弹窗的 `opacity` 与 `offsetY`——入场使用 `enterEasing`（`0.27s`）计算位移、`fadeInDuration`（`0.12s`）与 `fadeInEasing` 计算淡入；退场使用 `elapsed = 1 - clampedProgress` 配合 `exitEasing`（`0.27s`）计算位移、`fadeOutDuration`（`0.22s`）与 `fadeOutEasing` 计算淡出。
     - 减弱动态效果模式（同时兼顾传入参数与 `@Environment(\.accessibilityReduceMotion)`）：保持 `offsetY = 0`，仅按 `progress` 做原位纯透明度过渡（`0.18s`）。
   - 将 `AnyTransition.workbenchDialog` 恢复为单一 `Animatable` 进度修饰器 `WorkbenchDialogMotionEffect`（`progress: Double`、`isEntering: Bool`、`reducesMotion: Bool` + `@Environment(\.accessibilityReduceMotion)`），不额外在 `AnyTransition` 上叠加非线性 `.animation(...)`，完全由外层 `WorkbenchDialogLayer` 的 `dialogTransactionAnimation` 线性驱动，保留 `DebugInteractionLatencyProbe.recordDialogAnimationFrame` 调用；移除不再使用的 `enterAnimation` / `exitAnimation` / `fadeInAnimation` / `fadeOutAnimation` 及旧布尔修饰器 `WorkbenchDialogSlideModifier`。
   - 保留 `WorkbenchDialogChrome` 上常驻的 `.compositingGroup()` 及各 `NSView` 已有的 `wantsLayer = true`，确保动画起止最后一帧不闪动。

2. **移除系统文件面板与警告框挂载前提前淡出 Scrim 的调用（`AppWindowControls.swift`）**：
   - 在 `apps/macos-native/Sources/CueSeekerApp/Shared/AppWindowControls.swift` 的 `SystemSheetPresentation.presentSheetModal` 中移除调用 `present(window)` 之前提前执行的 `layers?.setSystemSheetAttached(true)`。
   - 改为完全交由主窗口既有的 `AppDelegate.windowWillBeginSheet` 在系统面板真正开始挂载时切换 `isSystemSheetAttached = true`，同时保留 `completionHandler` 中的 `releaseScrimOnCompletion` 逻辑，维持系统面板开始收起时自绘 Scrim 立即同步淡入。

3. **补充纯逻辑单元测试（`WorkbenchDialogLayerTests.swift`）**：
   - 在 `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchDialogLayerTests.swift` 新增 `dialogTransitionFrameComputesSynchronizedOpacityAndOffset`，验证常规模式下入场/退场起止点、淡入/淡出中点与淡出提前归零阶段的位置及透明度计算，以及减弱动态效果模式与越界 `progress` 钳制逻辑。未构建假窗口或模拟键鼠交互，未在正式代码中添加测试后门。

## Verification

以下验证均在最后一次代码与测试修改后执行通过：

1. **编译验证**：
   - `swift build --package-path apps/macos-native`：`Build complete! (0.30s)`（及前一轮完整编译 `13.91s`），修改文件零警告、零错误。
2. **定向无窗口纯逻辑测试（严格 `--filter` 过滤，零窗口弹出）**：
   - `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchDialogLayerTests|DebugInteractionLatencyProbeTests|WorkbenchDialogFitTests|InterfaceLayerFreezeTests"`
   - 结果：XCTest `DebugInteractionLatencyProbeTests` `7` 项全部通过（0 失败）；Swift Testing（`InterfaceLayerFreezeTests`、`WorkbenchDialogFitTests`、`WorkbenchDialogLayerTests`）`14` 项全部通过（0 失败）。
3. **端到端验收**：
   - 各对话框底部按钮与右上角 `✕` 关闭无跳动、进出场中途鼠标悬停/自动聚焦无错层、冷启动首次打开系统文件面板及收起期间 Scrim 连续压暗表现，交由用户在实机界面完成验收。
