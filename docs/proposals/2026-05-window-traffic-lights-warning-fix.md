# Walkthrough - NSWindow Traffic Lights Subview Warning Fix

我们成功解决了 macOS 启动和窗口重绘时在控制台中输出 `NSWindow warning: adding an unknown subview: <CueSeekerApp.WindowButtonsProxyView>` 的警告。

## 问题原因

在旧版实现中，为了重新定位交通灯按钮（Traffic Lights）并在切换至视频播放页时完全控制它们的显示/隐藏，代码将原生交通灯按钮 reparent 到了自定义的 `WindowButtonsProxyView` 中，然后通过 `themeFrame.addSubview(proxy)`（即系统的 `NSThemeFrame`）来渲染。
在现代 macOS 操作系统中，向系统的窗口主题框 `NSThemeFrame` 添加自定义子视图会触发 AppKit 的安全审查警告 `NSWindow warning: adding an unknown subview`。

## 解决方案

1. **修改挂载父视图 (Super View)**:
   - 将 `WindowButtonsProxyView` 的父视图从 `window.contentView?.superview` (`NSThemeFrame`) 修改为 `window.contentView` (即主 `NSHostingView` 容器)。
2. **安全层级管理**:
   - 在每次 `adjustTrafficLights()` 被调用时，如果 proxy 视图不在 `contentView` 层级中，我们会自动将其重新加入 `contentView`，保证了在 SwiftUI 频繁刷新时，自定义交通灯容器能够始终保持在最前端且能正确接收点击。
3. **消除警告**:
   - 由于 `window.contentView` 是由我们自行管理并设为 `.fullSizeContentView` 的普通视图层级，向其添加自定义子视图是 AppKit 官方完全支持且合规的做法，从而彻底消除了 `NSThemeFrame` 的 subview 警告。

---

## 影响代码文件

### `CueSeekerApp`

#### [MODIFY] [AppDelegate.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift)
- 将 `themeFrame.addSubview(proxy)` 替换为 `contentView.addSubview(proxy)`，并调整了相应的布局与定位计算。

---

## 验证结果

- **编译**: `swift build` 编译成功，耗时仅 2.12s。
- **单元测试**: 运行 `swift test` 验证，全部 **136 个测试用例通过**。
- **启动与警告**: 本地运行无任何 `NSWindow warning: adding an unknown subview` 控制台报错，启动体验更佳。
