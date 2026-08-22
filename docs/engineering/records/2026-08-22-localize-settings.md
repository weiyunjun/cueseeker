# Localize The Settings Window

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

覆盖需求里设置窗口的全部分类：九个分类名，以及媒体库、播放、外观、搜索、Deep Link、
解码、维护、开发者选项各自的说明、字段、按钮、确认弹窗与状态提示。按需求第 6 条修订后的
范围，开发者选项的内部条目这次一并翻译。

`Deep Link` 按术语基准保持原文不译。

### 解码器显示名放在界面层

解码模式此前直接显示内部取值（`hardware` / `software` / `auto`）。这三个名字属于界面表达，
不属于播放模块的产品语义，因此显示名的映射写在设置界面里，播放模块保持只暴露原始模式，
不引入对界面文案的依赖。

### 索引进度改为格式串

媒体库分类里的索引进度、结果统计、移除确认都带数字或路径，改用带位置参数的格式串，中英文
语序不同也能各自成立。

关键文件：
- `Sources/CueSeekerApp/Settings/SettingsView.swift`
- `Sources/CueSeekerApp/Settings/SettingsLibraryCategory.swift`
- `Sources/CueSeekerApp/Settings/SettingsDecodeCategory.swift`
- `Sources/CueSeekerApp/Settings/SettingsMaintenanceCategory.swift`
- `Sources/CueSeekerApp/Settings/SettingsDeveloperCategory.swift`
- `Sources/CueSeekerApp/App/AppTypes.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- 设置、本地化、失效范围相关共 43 个用例：仅两个改动前就存在的失败。
- Debug E2E 真机验证：简体中文下打开设置窗口，九个分类名全部为中文（Deep Link 按术语
  保持原文）；媒体库分类的标题、说明、两个按钮、数据库路径与已添加文件夹的移除按钮均为
  中文；维护分类的五项存储指标、状态说明与两个按钮均为中文。
  截图核对时发现维护分类底部的数据库路径一行仍是英文前缀，已在本次一并修掉。
  验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 未能真机验证的部分

播放、外观、搜索、Deep Link、解码、开发者选项六个分类没有逐个截图；它们与已验证的两个
分类结构相同，取文案走同一个入口。各类确认弹窗需要交互才会出现，同样没有截图。
