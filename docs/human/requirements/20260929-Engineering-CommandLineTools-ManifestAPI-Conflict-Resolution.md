# 版本

main

# 需求目标

解决新机器环境迁移后，因系统 Command Line Tools 残留旧版（Swift 5.10）私有接口导致的 Package.swift manifest 链接失败问题，恢复 `scripts/package_macos_app.sh` 的正常打包能力。

# 需求

1. **清理系统级废弃接口**：
   - 手动清理 `/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/` 下残留的 `*.private.swiftinterface` 文件。
2. **清理本地模块构建缓存**：
   - 清理 `.build/clang-module-cache`，防止旧模块污染。
3. **适配 Xcode 16 编译器语言模式**：
   - 在 `Package.swift` 中显式声明 `swiftLanguageModes: [.v5]`，确保在 Xcode 16 / Swift 6 工具链下保持 Swift 5 语言模式，避免触发全量严格并发编译错误。
   - 修复 `PlaybackStore` 与 `PlaybackSubtitleFocusSessionStore` 构造函数跨 Actor 默认参数，显式标注 `@MainActor`，满足 Swift 6 编译器规范。
   - 保持 macOS 13+ 最低系统兼容性要求不变。
4. **恢复打包验证**：
   - 验证 `scripts/package_macos_app.sh` 在新机器上能够无报错顺利完成编译、链接与打包。

# 验收

1. 宿主机上手动执行私有接口与缓存清理。
2. `Package.swift` 指定 Swift 5 语言模式并完成跨 Actor 构造函数标记，无 Swift 6 严格并发阻断报错。
3. 运行 `scripts/package_macos_app.sh --output /Applications/CueSeeker.app` 退出码为 0，成功生成应用。
4. 当前无需新增自动化 E2E 测试能力。