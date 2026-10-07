# 版本

main

# 需求目标

提供一键式 macOS 官方公证发布脚本 `scripts/release_macos_app.sh`，将打包、Developer ID 签名、DMG 制作、苹果公证（Notarization）、票据装订（Staple）及分发 DMG 生成串联为单指令自动化流程。

# 需求

1. **一键发布流程串联**：
   - 新增 `scripts/release_macos_app.sh` 脚本。
   - 调用已有的 `scripts/package_macos_app.sh` 完成底层编译与应用包构建。
   - 使用系统内置 `hdiutil` 组装包含 `CueSeeker.app` 与 `/Applications` 快捷替身的 DMG 映像并签名。
   - 提交 DMG 至苹果公证服务（`xcrun notarytool submit --wait`）。
   - 公证通过后执行 `xcrun stapler staple` 将公证票据装订至 DMG。
   - 产出包含公证票据的最终分发文件 `CueSeeker.dmg`。

2. **凭据安全与零硬编码**：
   - 签名身份与公证 Profile 通过参数或环境变量动态读取（如 `CUESEEKER_SIGNING_IDENTITY`、`CUESEEKER_NOTARY_PROFILE`）。
   - 脚本内严禁硬编码任何个人姓名、Team ID、私钥文件路径或凭证信息，符合开源安全标准。
   - 未指定凭据时输出清晰的使用说明并退出。

# 验收

1. 执行 `scripts/release_macos_app.sh` 可一键完成“编译 ➔ 签名 ➔ DMG制作 ➔ 公证 ➔ 装订”。
2. 输出的 `.dmg` 通过 Gatekeeper 与 stapler 校验（`spctl --assess` 状态为 accepted，`stapler validate` 成功）。
3. 产出的 `CueSeeker.dmg` 可直接在任意其他 Mac 上挂载并拖拽安装运行，无安全拦截。
4. 脚本本身不含任何个人敏感信息，可安全随仓库开源。