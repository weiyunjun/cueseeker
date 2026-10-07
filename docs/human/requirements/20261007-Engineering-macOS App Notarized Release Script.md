# 版本

main

# 需求目标

提供一键式 macOS 官方公证发布脚本 `scripts/release_macos_app.sh`，将打包、Developer ID 签名、苹果公证（Notarization）、票据装订（Staple）及分发 ZIP 生成串联为单指令自动化流程。

# 需求

1. **一键发布流程串联**：
   - 新增 `scripts/release_macos_app.sh` 脚本。
   - 调用已有的 `scripts/package_macos_app.sh` 完成底层编译与应用包构建。
   - 自动将应用包压缩为临时 ZIP 并提交至苹果公证服务（`xcrun notarytool submit --wait`）。
   - 公证通过后自动执行 `xcrun stapler staple` 装订公证票据至 `.app`。
   - 产出包含公证票据的最终分发文件 `CueSeeker.zip`。

2. **凭据安全与零硬编码**：
   - 签名身份与公证 Profile 通过参数或环境变量动态读取（如 `CUESEEKER_SIGNING_IDENTITY`、`CUESEEKER_NOTARY_PROFILE`）。
   - 脚本内严禁硬编码任何个人姓名、Team ID、私钥文件路径或凭证信息，符合开源安全标准。
   - 未指定凭据时输出清晰的使用说明并退出。

# 验收

1. 执行 `scripts/release_macos_app.sh` 可一键完成“编译 ➔ 签名 ➔ 公证 ➔ 装订 ➔ 压缩分发”。
2. 输出的 `.app` 通过 Gatekeeper 校验（`spctl --assess` 状态为 accepted）。
3. 产出的 `CueSeeker.zip` 可直接在任意其他 Mac 上解压并双击运行，无安全拦截。
4. 脚本本身不含任何个人敏感信息，可安全随仓库开源。