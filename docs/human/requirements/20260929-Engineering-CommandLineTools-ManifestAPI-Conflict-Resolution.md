# 版本

main

# 需求目标

解决新机器环境迁移后，因系统 Command Line Tools 残留旧版（Swift 5.10）私有接口导致的 Package.swift manifest 链接失败问题，恢复 `scripts/package_macos_app.sh` 的正常打包能力。

# 需求

1. **清理系统级废弃接口**：
   - 手动清理 `/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/` 下残留的 `*.private.swiftinterface` 文件。
2. **清理本地模块构建缓存**：
   - 清理 `.build/clang-module-cache`，防止旧模块污染。
3. **恢复打包验证**：
   - 验证 `scripts/package_macos_app.sh` 在新机器上能够无报错顺利完成编译、链接与打包。

# 验收

1. 宿主机上手动执行私有接口与缓存清理。
2. 运行 `scripts/package_macos_app.sh --output /Applications/CueSeeker.app` 退出码为 0，成功生成应用。
3. 当前无需新增自动化 E2E 测试能力。