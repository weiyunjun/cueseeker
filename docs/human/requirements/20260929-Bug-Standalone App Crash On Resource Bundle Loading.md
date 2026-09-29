# 版本

main

# 需求目标

修复打包后的 macOS 独立应用（`CueSeeker.app`）在迁移至其他设备或独立运行时，因无法加载资源包（`CueSeekerNative_CueSeekerApp.bundle`）导致的启动闪退问题。

# 需求

1. **支持标准 App 资源寻址**：
   - 应用加载内置资源包（语言包及图标）时，优先从 `.app` 包内的标准资源目录（`Contents/Resources/`）加载。
   - 保持本地开发环境（Xcode / `swift run` / 测试）下的资源路径兼容。
2. **消除硬编码路径导致的崩溃**：
   - 避免直接调用 SwiftPM 为可执行目标生成的硬编码兜底访问逻辑，确保独立打包部署时不会因寻址失败而触发 `fatalError`。

# 验收

1. 成功执行 `./scripts/package_macos_app.sh` 打包生成 `CueSeeker.app`并通过 bundle 校验。
2. 将 `CueSeeker.app` 复制到没有源码和构建缓存的独立机器上，启动应用能正常打开主界面，不发生闪退。
3. 应用内的多语言本地化文本与 SVG 图标正常渲染。
4. 不为本需求新增自动化 E2E 能力，通过已有打包校验与人工启动验收。