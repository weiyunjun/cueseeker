# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
  - `Components / 2.7 Scrollbars`
  - `Components / 2.11 Media / Cover Summary`
  - `Layouts / 3.1 App Shell / App Sidebar Layout`
  - `Layouts / 3.4 Library / Library Folder Detail Layout`
  - `Layouts / 3.5 Search and Shiori / Shiori List Detail Layout`

# 关联需求

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
- `docs/human/requirements/20260813-Feature-Library Detail Shared Cover Summary.md`
- `docs/human/requirements/20260813-Feature-Shiori Detail Adaptive Cover Summary.md`

# 替代范围

本需求替代两份 `20260813` 需求中 Cover Summary 的固定高度与单一形态规则。
封面裁剪、遮罩、文字层级等规则在窄档形态下继续沿用。

# 需求目标

1. 统一页面左右内边距与纵向 Scrollbar 的占位口径。
2. Library 与 Shiori 二级页的 Cover Summary 改为宽窄双形态。

# 需求

## 一、页面内边距与 Scrollbar 通道

1. Workbench 页面横向构成：左内边距、页面内容、右内边距，右内边距之外再留一条纵向
   Scrollbar 通道。
2. 左右内边距取值相同，均为 `32`。
3. Scrollbar 通道宽度 `16`，由 Scrollbar 尺寸与其边距推导，Scrollbar 在通道内居中。
4. 通道恒定占位，与纵向 Scrollbar 当前是否显示无关。
5. 页面内容最小宽度规则不变；内边距与通道都计入页面内容。

## 二、侧边栏自动收起阈值

1. 阈值改为「页面内容最小宽度 + 侧边栏宽度」，由 Token 推导，不得写死。
2. 收起后不自动展开。
3. 该规则适用于全部 Workbench 页面。

## 三、表格横向滚动范围

1. 表格文档宽度、横向 Scrollbar 轨道、表头绘制区必须使用同一个内容盒口径。
2. 表格横向滚动到最右时，最后一列右边缘与内容盒右边缘对齐，不得残留够不到的空白。

## 四、Cover Summary 双形态

### 共用

1. Cover Summary 宽度与本页其余内容一致。
2. 按 Cover Summary 可用宽度在两种形态间切换，切换宽度由 Token 推导，
   等于「封面默认宽度 + 图文间距 + 文字区最小宽度」。
3. 不重新生成封面，不修改封面文件。

### 分栏形态（可用宽度不小于切换宽度）

4. 封面在左，固定 `16:9`，默认尺寸 `320 × 180`，圆角使用封面圆角 Token。
5. 文字区在右，与封面间距 `24`，最小宽度 `320`，吃满剩余宽度，不设上限。
6. 标题与封面顶部对齐，Resume / Play 按钮与封面底部对齐。
7. 无背景、无遮罩。标题使用主文字色，描述与元数据使用次级文字色，
   Light / Dark 分别适配。
8. Resume / Play 使用 `Button / Primary`。

### 铺底形态（可用宽度小于切换宽度）

9. 沿用现有封面铺底、Aspect Fill、Center Crop、左向右衰减遮罩与白色文字规则。
10. 高度固定为 `225`，宽度自适应；封面按 Aspect Fill 居中裁剪填满该高度，
    最窄宽度下不裁剪，宽度越大上下裁剪越多。
11. 文字与按钮的显示区域高度与分栏形态相同，上内边距 `35`、下内边距 `10`，
    左内边距沿用现有值；标题在上，Resume / Play 按钮在左下角。

## 五、设计系统约束

1. 实现必须复用设计系统 Token 与共享组件，禁止页面内硬编码数值、私有样式或
   Appearance 特判。
2. 验收通过后再更新 `UI Design System.md`：Scrollbar 通道与页面左右内边距、
   侧边栏自动收起阈值、Cover Summary 两种形态的结构 / 尺寸 / 切换宽度 /
   文字与按钮样式；同步 Cover Summary、Scrollbar、App Sidebar Layout、
   Library Folder Detail Layout、Shiori List Detail Layout 条目；
   废弃仅服务于旧单一形态的 Token。

# 范围

不包含：

1. 封面生成、裁剪编辑与持久化数据。
2. 表格列宽权重与列最小宽度本身。
3. Scrollbar 外观与自动隐藏行为。
4. 窗口最小宽度、高度与全屏行为。
5. Library / Shiori 一级页面。

# 验收标准

1. 各宽度下页面左右内边距视觉相等，纵向 Scrollbar 不压在内边距上。
2. 纵向 Scrollbar 出现或消失时，页面内容不发生横向位移。
3. 窗口变窄到侧边栏自动收起的瞬间，收起前后都不出现页面级横向滚动。
4. 逐渐缩小窗口宽度时，Cover Summary 的形态变化单调，不出现
   「分栏 → 铺底 → 分栏」的回跳。
5. 分栏形态下标题与封面顶部齐平、按钮与封面底部齐平；宽窗口下 Cover Summary
   与下方剧集网格 / 表格等宽。
6. 铺底形态在任意宽度下高度恒为 `225`，封面居中裁剪填满、不拉伸、不留白；
   切换形态前后文字与按钮区域的高度一致，整块高度只在 `180` 与 `225` 之间
   变化一次，不随宽度连续变化。
7. 表格横向滚动到最右时，右侧没有够不到的空白。
8. Light 与 Dark 下分栏形态文字可读；铺底形态两种模式视觉一致。
9. 所有新增视觉与布局值都以 Token 形式集中定义，没有散落在页面实现里。
10. 最终视觉与交互由项目 Owner 在真实 Debug 客户端验收。