# Localize The Tables, Search Shell And Filter Panel

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

覆盖需求里的表格、行右键菜单、筛选面板三节，以及搜索外壳自身的文案：列头、排序菜单、
行内播放与复制、行状态提示、九项行右键菜单、四组筛选条件、结果计数、搜索框占位、
筛选与选取按钮、选中态工具条、Shiori 表格的空状态与移除确认。

按需求第 9 条，`Copy Deep Link(s)` 的英文原文同时改为 `Copy Deep Links`。

### 列头是画进原生视图的，但已有失效通道

表格列头不是 SwiftUI 文字，而是由原生视图绘制、并缓存在协调器里。好在列头文字本来就是
从 SwiftUI 侧传进去的输入，协调器已经在比较新旧列头并在变化时重绘表头。因此这里只需要
在传入前本地化，再让传入方观察语言存储即可，不需要新增任何失效机制。

相对地，行状态提示、排序菜单、行右键菜单、行内悬浮按钮都是按需创建的 SwiftUI 浮层，
每次打开都会重新取文案，本身不存在缓存问题。

### 一处必须从常量改成计算属性

搜索外壳的列定义原本是 `static let`，只会在首次访问时求值并永久缓存。如果直接把本地化
调用放进去，列头会被冻结在首次访问时的语言上。因此改为计算属性，每次读取都按当前语言
求值。

关键文件：
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `Sources/CueSeekerApp/TableSandbox/SubtitleTableRow.swift`
- `Sources/CueSeekerApp/TableSandbox/SubtitleTableRowActionMenu.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- 整包 `swift test`（1017 个用例）：失败集合与基线同类，都是既有的环境相关不稳定用例。
- Debug E2E 真机验证：英文状态下进入搜索页，再在设置里切到繁體中文，不重启直接截图。
  页标题变为「搜尋」，搜索框占位、「篩選 / 選取」按钮、四组筛选（時間長度 / 字元數 /
  語言 / 觀看狀態）连同各自选项全部实时更新；**由原生视图绘制的列头也实时变为
  「台詞數 / 顯示標題 / 時間範圍」**，这是本次最需要确认的一点，说明列头的既有失效通道
  在语言变化时同样成立。验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 顺带发现的一个既有测试隔离问题

`sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` 在某一次整包
运行中失败，但单独运行、与本地化用例一起运行、以及随后的两次整包运行都通过。

原因不在本次改动：`AppCoordinator` 注册默认值时写入的是**进程级的注册域**，注册域会被
同进程内任何一个 `UserDefaults` 实例读到，包括该用例临时创建的随机套件。于是只要有别的
用例先构造过 `AppCoordinator`，这个随机套件里 `workbenchPanelMode` 就已经有值，而被测的
迁移逻辑只在键不存在时才写入，断言随之失败。是否触发取决于并行调度顺序。

这属于测试隔离缺陷，不在本需求范围内，未做修改。
