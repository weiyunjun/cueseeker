# Engineering Record: UI Redesign - Column Header Menu & Sortable Header Cell (Section 2.15 & 2.18)

## 1. 覆盖范围
本记录详细说明在 `test-search-2` 的表格控件中，重构并实现以下两项 UI Redesign 设计：
- **Section 2.15 Column Header Menu** (列头弹出菜单)
- **Section 2.18 Sortable Header Cell** (可排序表头单元格)

---

## 2. 核心设计决策与折中

### 2.1 排序逻辑与边界
根据 UI Redesign 界面的纯视觉定义，点击 Column Header Menu 里的 **Sort Ascending** 或 **Sort Descending** 操作时：
- 只会驱动表头中的排序指示图标 (`chevron.up.chevron.down`、`arrow.up` 或 `arrow.down`) 进行状态改变。
- 排序状态在工程内仅更新 UI 指示状态，**不触发数据库底层行的物理重新排序**，避免修改开销且符合本次纯 UI/UX 改造范围的要求。

### 2.2 资源与图标映射
- **`eye-off` 映射**：Redesign 需求文档中的 `eye-off` 图标，在 macOS 的 SF Symbol 体系下被映射并使用 `eye.slash` 进行渲染。
- **字重沿用**：需求文档中只定义了表头的字号大小 (`--font-size-table: 14px`)，但并未对字重进行指定。开发中**沿用了 AppKit 现有的 `.semibold` 字重**以确保整体视觉力量感，而非生硬引入新的外部字重 token。

### 2.3 Focus Ring 视觉裁切防范
- 每一个 `NSHostingView` 被注入到 `SubtitleVirtualTableHeaderView` 时，都会在 AppKit 层显式配置：
  ```swift
  host.wantsLayer = true
  host.layer?.masksToBounds = false
  ```
- 这是为了防止 3px 外扩的 Focus Ring 被 hosting view 裁剪。
- *注：此做法对 host 独立有效。但若外层 container 具有 `masksToBounds = true` 属性，边界处依然存在微调可能性。此项需要进行人工视觉验收。*

### 2.4 2.16 Row Action Menu 兼容性迁移
- 为支持多类 SwiftUI 弹层（Row Action Menu 以及 Column Header Menu）的复用，`Coordinator` 的 `menuHost` 承载类型由 `NSHostingView<RowActionMenu>` 泛型迁移为了 `NSHostingView<AnyView>`。
- 针对 2.16 Row Action Menu 引入了统一设置 helper：`setMenuHost(RowActionMenu(...), in: container)`。
- Row Action Menu 的具体视觉和逻辑行为**未发生任何变更**，保持高内聚低耦合。

---

## 3. 详细代码实现细节

### 3.1 宽度自适应表头 Cell
- 交互表头单元格采用 `HStack` 靠左，并在其内包裹交互 `Button`。使用 `GeometryReader` 动态测量按钮内容的真实宽度，而非填充整列宽度。
- 只有这个自适应宽度的 Button 表面承载 hover背景色 (`bgHover`)、Pointer 光标与 Focus 环，使得悬浮状态完美契合文字和图标长度。

### 3.2 Pointer 指针与生命周期保护
- 表头 Cell 和 `WorkbenchPopoverRow` (菜单项) 都在 redesign 下启用了 `NSCursor.pointingHand`。
- 添加了 `@State private var hasPushedCursor = false`，当视图 `onDisappear`、或者 `isEnabled` 转换为 false 失去交互时，无条件执行 `NSCursor.pop()` 清理，坚决防止光标栈泄漏导致全局指针异常。

### 3.3 宿主渲染主动刷新机制
- SwiftUI 的 NSHostingView 渲染常因为 AppKit 的 layout 驱动机制存在微小延迟。
- 在 `Coordinator` 内提供 `refreshHeaderHosts()` 入口，在排序切换、菜单打开/关闭、以及 `isEnabled` 切换时同步调用，以确保视觉效果实时呈现。

---

## 4. 影响的模块与源文件
- `Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift` (新增度量 Token，更新 `WorkbenchPopoverRow` 光标逻辑)
- `Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift` (重构表头、状态管理、显示/关闭菜单机制，新增 Header Cell / Menu Views)
