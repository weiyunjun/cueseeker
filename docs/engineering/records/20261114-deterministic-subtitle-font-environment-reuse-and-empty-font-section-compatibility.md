# 2026-11-14 工程实现记录：确定性 ASS 字幕字体环境复用与空 `[Fonts]` 占位段兼容

- **关联需求**：`docs/human/requirements/20261114-Engineering-Deterministic Subtitle Font Environment Reuse And Empty Font Section Compatibility.md`
- **需求提交**：`3ddc931`
- **目标分支**：`main`

## 1. 变更摘要

1. **串行化 ASS 字幕渲染 worker 的释放与新建（`SourceFaithfulASSSubtitleOverlayView.swift`）**：
   - 每个 `SourceFaithfulASSSubtitleOverlayView` 实例持有一条共享串行 `DispatchQueue`（`workerQueue`），在初始化及每次 `replaceRendererWorker()` 时将其注入新创建的 `SourceFaithfulASSRendererWorker(queue: workerQueue)`。
   - 保留每次 `replaceRendererWorker()` 生成新 `SourceFaithfulASSRendererWorker` 实例的语义（保持 `rendererWorkerIdentityForTesting` 断言不变），并在构造新 worker 前同步调用 `previousWorker.invalidate()` 排入 `previousWorker.clearState()`；已失效 worker 在队列任务入口立即跳过加载与渲染，使旧会话 `session?.close()` 归还池化引擎严格先于新会话借用，消除跨集切轨或连续快切时的并发竞态冷建。

2. **系统字库变更联动失效池化引擎（`SFXASSRenderer.h/.m`、`ASSFontAliasResolver.swift`）**：
   - 在 `SFXASSRenderer` 新增 `+ (void)invalidateFontEnvironmentPool;` 并在全局引擎池中引入世代号 `gSFXASSEnginePoolGeneration`。失效时递增世代号、销毁池内全部空闲 `(ASS_Library *, ASS_Renderer *)` 实例并重置 `gSFXASSHasCompletedWarmup = NO`。
   - `SFXASSRendererSession` 在借用池化引擎时记录借出世代 `_enginePoolGeneration`，归还时仅当世代与当前 `gSFXASSEnginePoolGeneration` 一致且池未满才放回复用；已过期会话维持本次正常渲染并在关闭时直接销毁旧世代引擎而不污染新池；并发预热与非预热创建同样校对捕获世代后再写回完成标记与池。
   - 提取共享辅助 `SFXApplyASSRendererFrameSize`，统一 `SFXCreateASSEngineContext`、`SFXCheckoutASSEngineContext`（复用池化实例）与 `updateFrameWidth:frameHeight:` 的 `Int32` 正数边界钳制。
   - 在 `ASSFontAliasResolver` 中区分共享实例 `ASSFontAliasResolver.shared`（开启 `invalidatesSharedRendererPool`）与隔离测试实例 `ASSFontAliasResolver(observeSystemFontChanges:)`（关闭 `invalidatesSharedRendererPool`），使运行期收到 `kCTFontManagerRegisteredFontsChangedNotification` 或共享环境刷新时联动调用 `SFXASSRenderer.invalidateFontEnvironmentPool()`，同时避免隔离单测误清全局引擎池，并以 `environmentGeneration` 防止扫描期间并发刷新通知覆盖待刷新标志。

3. **整文件回退路径兼容空 `[Fonts]` 占位段（`SFXASSRenderer.m`）**：
   - 重写 `SFXBytesContainEmbeddedFontsSection`，对齐 `ASSEventOffsetIndex` 的段解析口径：支持跳过 UTF-8 BOM，进入 `[Fonts]` 段并在遇到后续 `[...]` 段标题时退出；仅当 `[Fonts]` 段内出现至少一行去除首尾空白后非空且不以 `;` 或 `!:` 开头的实际内嵌字体数据行时才返回 `YES`；空 `[Fonts]` 占位段（含仅空白行或注释行）返回 `NO`，正常复用共享池。

4. **自动化回归测试补充与断言收紧**：
   - 将 `PlaybackVerticalSyncAndIndexedASSTests.swift` 中跨集复用测试 `engineCountAfterEp2 <= 2` 收紧为严格的 `PlaybackPlayer.assEngineInitializationCountForTesting == 1`（含手动切轨与切回第 1 集校验）。
   - 新增连续 5 集快速无等待 `player.open(...)` 跳切复用测试、无索引整文件回退路径空 `[Fonts]` 占位段与非空内嵌字体隔离（不污染原池）测试，以及系统字库变更通知下旧会话平滑渲染销毁并准确 `+1` 重建新世代池、后续跨集持续复用测试。
   - 在 `CASSRenderingProbeTests.swift` 新增空 `[Fonts]` 占位段解析、内嵌字体隔离与 `SFXASSRenderer.invalidateFontEnvironmentPool()` 世代退役直接单测。

## 2. 涉及文件

- `apps/macos-native/Sources/CueSeekerPlayback/SourceFaithfulASSSubtitleOverlayView.swift`
- `apps/macos-native/Sources/CASSRendering/include/SFXASSRenderer.h`
- `apps/macos-native/Sources/CASSRendering/SFXASSRenderer.m`
- `apps/macos-native/Sources/CueSeekerPlayback/ASSFontAliasResolver.swift`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/PlaybackVerticalSyncAndIndexedASSTests.swift`
- `apps/macos-native/Tests/CASSRenderingTests/CASSRenderingProbeTests.swift`

## 3. 验证结果

- `swift build --package-path apps/macos-native` — Build complete! (0 failures)
- `swift test --package-path apps/macos-native --no-parallel --filter "CueSeekerPlaybackTests|CASSRenderingTests|PlaybackRequestTests|PlaybackVerticalSyncAndIndexedASSTests"` — 执行并通过 141 个测试（`CASSRenderingProbeTests` 10 个 XCTest + `CueSeekerPlaybackTests` 131 个 Swift Testing，含 `PlaybackRequestTests` 与 `PlaybackVerticalSyncAndIndexedASSTests`），0 失败，0 跳过。
