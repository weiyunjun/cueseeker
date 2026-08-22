# Localize Shiori And The Toasts

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

覆盖需求里的 Shiori 与 Toast 两节：列表总览的汇总与新建按钮、卡片上的台词数角标、
右键菜单的编辑与删除、删除确认弹窗、列表编辑弹窗的标题与主按钮、两个表单字段与占位、
四条校验提示，以及六条 Shiori 相关 Toast。

`Shiori` 本身按术语基准保持原文不译。

### 常量会冻结文案

三条 Toast 原本是 `static let` 常量，只在首次访问时求值。直接放本地化调用会把文案冻结在
首次访问时的语言上，因此改为计算属性，每次取用都按当前语言求值。这与搜索外壳的列定义是
同一类问题。

关键文件：
- `Sources/CueSeekerApp/Shared/Toast.swift`
- `Sources/CueSeekerApp/Shiori/ShioriListOverviewView.swift`
- `Sources/CueSeekerApp/Shiori/ShioriListEditor.swift`
- `Sources/CueSeekerApp/Search/Shiori/ShioriCardGroupView.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- Shiori、Toast、本地化相关共 79 个用例：仅
  `showCueGroupInvalidationIsScopedToMountedShiori` 失败，是改动前就存在的既有失败。
- Debug E2E 真机验证：繁體中文下进入 Shiori 总览，汇总为「5 個列表 · 678 條台詞」，
  按钮为「新增列表」，卡片角标为「28 條台詞」等，页标题按术语保持 `Shiori`。
  验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 未能真机验证的部分

列表编辑弹窗、删除确认弹窗与六条 Toast 需要交互才会出现，本次没有逐个截图。它们都是
按需创建的浮层或每次调用时构造的请求，不存在文案缓存问题；Toast 的常量缓存风险已在本次
一并消除。
