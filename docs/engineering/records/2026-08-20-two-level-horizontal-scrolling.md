# Two-Level Horizontal Scrolling

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 滚动条归属第 1、4 条；页面内容最小宽度整节。

## Change

### 一个滚动容器，两条按轴分工的 Scrollbar

表格的 `NSScrollView` 现在被两个 Overlay 分轴使用：页面那条只画纵向、铺满整个页面；
表格那条只画横向、横向对齐表格宽度。`TableScrollbarOverlayView` 因此新增：

- `visibleAxes`：只绘制/命中自己负责的轴；
- `bottomReserve` / `trailingReserve`：交叉方向让出一条 Scrollbar 的位置。

两条 Scrollbar 交叉处的避让，原本由单个双轴 Overlay 内部处理，现在由
`WorkbenchPageScrollbar` 在两个 Overlay 之间同步，口径仍是
`TableScrollbarPrimitiveMetrics` 的厚度加间距。绘制、Token、命中区没有第二套实现。

### 页面级最小宽度扩到含表格的页面

`SchemaWorkbenchSearchShell` 在页面层套一层只管横向的滚动容器，内容宽度取「可用宽度
与 App 最小窗口宽度取大」。因为窗口最小宽度就是该值，收起 sidebar 时永远触发不到；
只有窄窗口展开 sidebar 才会出现页面级横向滚动。

页面那条纵向 Scrollbar 放在这层容器外面，保持贴页面右侧；表格那条横向 Scrollbar 放在
容器内部，随页面一起横向移动，并在页面级滚动条出现时上移一条 Scrollbar 的高度。

关键文件：
- `Sources/CueSeekerApp/Shared/TableScrollbarPrimitive.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchPageScrollbar.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`

## Verification

- `swift build`、`swift test`：失败项与改动前基线一致，没有新增失败。
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift`：
  - 两个 Overlay 各自只报一个轴，表格视图树内不再有 Scrollbar；
  - 纵向铺满页面、横向等于表格宽度；两者互相让出交叉位置；
  - 可用宽度大于页面最小宽度时，表格那条贴页面底部；
  - 可用宽度小于页面最小宽度时，页面内容停在最小宽度、出现页面级横向轴，
    表格那条让出一条 Scrollbar 的高度。
- Debug E2E：
  - Search 480pt、sidebar 收起：工具栏与 Filter 面板自适应重排，只有表格那条横向
    Scrollbar，贴页面底部；
  - Search 480pt、sidebar 展开：页面内容停在最小宽度，页面底部与其上方各出现一条
    横向 Scrollbar；
  - Shiori 二级页 600pt：封面与工具栏按可用宽度自适应，不再跟随表格；表格那条横向
    Scrollbar 贴页面底部；1445pt 下布局无变化。

## Outcome

符合预期。行 Hover / 选中高亮、行分隔线、表头分隔线与选择模式复选框位置待项目
Owner 在真机上确认。
