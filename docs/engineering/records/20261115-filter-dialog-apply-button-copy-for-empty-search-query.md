# 空搜索词时搜索筛选对话框右下角主按钮文案工程实现记录

- 对应需求单：`docs/human/requirements/20261115-UI-Filter Dialog Apply Button Copy For Empty Search Query.md`
- 分支 / 起始提交：`main`（变更前：`2b0ea71`，需求单提交后：`baab146`）

## 修改摘要

1. **新增空搜索词筛选应用文案三语词条**
   - `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
   - `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
   - `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
   - 在三语文件中新增 `filter_dialog.apply_filters.one` 与 `filter_dialog.apply_filters.other`：
     - 英文：`Apply 1 filter` / `Apply %d filters`（`0` 与 `>= 2` 统一为 `Apply 0 filters` / `Apply N filters`）
     - 简体中文：`应用 1 个筛选条件` / `应用 %d 个筛选条件`
     - 繁体中文：`套用 1 個篩選條件` / `套用 %d 個篩選條件`
   - 通过 `L(_:_:)`（`String(format:)` 无分组符默认 locale）渲染连续阿拉伯数字，不带千分位逗号。

2. **共用筛选对话框空搜索词主按钮文案与交互边界**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`：
     - 在 `CueFacetFilterDialogSession.Source` 新增 `primaryActionTitle(totalCount:selectedFilterCount:isQueryEmpty:)`：仅当来源为 `.search` 且 `isQueryEmpty == true` 时返回 `Apply 0 filters` / `Apply 1 filter` / `Apply N filters`（及简/繁对应文案）；其余情况（非空搜索词的 `.search` 与全场景 `.excerpt`）保持 `Calculating` / `Show 1 result` / `Show N results` / `Show 1 excerpt` / `Show N excerpts` 原逻辑不变。
     - 在 `CueFacetFilterDialog` 新增默认参数 `isQueryEmpty: Bool = false`，从当前 `sections.reduce(0) { $0 + $1.selectedCount }` 实时计算五个分组已勾选胶囊总数（与工具栏筛选按钮右侧计数徽章 `selectedOptionCount` 口径完全一致），在 `footer` 中将该数量传入 `primaryActionTitle`，并保持空搜索词下主按钮始终不显示 `Spinner` 且处于可点击状态。
     - `SearchFacetFilterDialog` 传入 `isQueryEmpty: searchState.isQueryEmpty`（继续复用 `search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`），既覆盖 Workbench Search 也覆盖 Command Panel 二级搜索结果页共用的搜索筛选对话框；`ExcerptFacetFilterDialog` 保持 `isQueryEmpty` 默认为 `false`（且 `.excerpt` 来源不受空搜索词分支影响）。
     - `CueFacetFilterDialog` 既有的 `.cueSeekerAppLanguageChanged` 监听会在对话框打开期间切换语言时立即重算按钮文案；`Reset`、`Cancel`、无障碍目标 `.filterShow` 启用判断与激活确认生效路径均保持不变。

3. **边界确认与纯逻辑单元测试**
   - 严守最小充分设计：直接在现有词条文件与 `CueFacetFilterPanel.swift` 原位最小修改，未新建独立框架、通用引擎、管理类或中间模型；未改动 `docs/human/design/` 文档；正式代码未添加任何测试专用属性或后门。
   - `apps/macos-native/Tests/CueSeekerAppTests/SettingsStoreSearchTests.swift`：新增纯逻辑测试 `filterDialogPrimaryActionTitleCoversEmptySearchTrilingualCountsAndPreservesNonEmptyAndExcerpt` 与 `filterDialogEmptyAndWhitespaceSearchQueriesStayApplyReadyWithMatchingSelectedCount`，覆盖三语 `0 / 1 / 2 / 1234` 连续数字文案、空字符串/纯空白搜索词、非空搜索词及 Excerpt 回归路径，以及五个分组已勾选数之和与 `selectedOptionCount` 一致性（含归零重置）。未构造假窗口或模拟键鼠交互。

## 编译与单元测试验证

以下验证均在最后一次代码与测试修改后执行通过：

1. **编译验证**：
   - 执行 `swift build --package-path apps/macos-native`
   - 结果：`Build complete! (0.34s)`，0 错误。
2. **定向无窗口纯逻辑测试（严格 `--filter` 过滤，零窗口弹出）**：
   - 执行 `swift test --package-path apps/macos-native --filter "filterDialog|filterTrigger|searchFacetPersistence|settingsStore|WorkbenchAccessibilityStep2Tests|eachLanguageResolvesItsOwnLocalizationBundle|everyBundledLanguageDefinesTheSameKeys|singularCountKeysDoNotContainUnresolvedFormatPlaceholders"`
   - 结果：Swift Testing 执行 `42` 项全部通过（0 失败，包含新增 2 项及既有搜索筛选、设置持久化、多语言键对齐与无障碍目标纯逻辑测试）。
3. **端到端验收**：
   - 空白/空搜索词实时联动、弹窗打开期间切换语言刷新、工具栏徽章同步、Command Panel 二级搜索结果页及 Excerpt 详情页实机界面表现留待用户验收。
