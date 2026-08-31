# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Tabs、Tab、Library Overview Layout、Library Folder Detail Layout、Data Tree Layout）
- `docs/human/design/UI Application Rules.md`（Hover 与选中、指针）

# 需求描述

## 1. 目标

Library 一级与二级界面各增加一个 Video / File 分段控件，File 承接原 Data 界面的文件树；Data 界面删除。

## 2. 分段控件

1. 一级界面：位于 `xx Folders yy Videos zz Subtitles` 摘要行下方，左对齐。
2. 二级界面：位于封面组件下方，左对齐。
3. 样式与 Playback Overlay 顶部的 Current / Playlist 完全一致，复用同一个 Tabs / Tab 组件。
4. 选项为 Video 与 File 两项，两个界面均默认选中 Video。
5. 摘要行、Add Folder 按钮、二级封面组件不随分段切换变化，两个分段下都照常显示。

## 3. Video

内容与交互即现有的视频卡片界面，不做改动。

## 4. File

1. 一级界面：与原 Data 界面的内容和交互完全相同，包括界面样式、标签文本、默认展开层级（根路径展开、文件夹折叠）、点击文件夹展开收起、行 Hover 规则与分隔线。
2. 二级界面：样式与交互同上，但只显示该文件夹自身的子树，不显示其上层的根路径行；该文件夹自身一行默认展开，其下的条目默认折叠。
3. 已知边缘情况：直接添加的、其下没有子文件夹的目录，其显示维持现状，本次不调整。

## 5. 生命周期

1. 文件树在 File 首次被选中时才读取；默认停留在 Video 时不读取。
2. 文件树与文件夹卡片共用同一份数据版本，库内容变化后再次显示 File 时重新读取。
3. 二级界面的 File 不单独读取数据，取用同一棵树中该文件夹的子树。
4. 分段选中项与展开状态都不跨界面保留：一级与二级各自独立，进入二级再返回一级时一级回到 Video；离开 Library 页再返回时回到 Video 与默认展开状态。

## 6. Data 界面删除

1. 删除 Data 页面及其边栏入口。
2. 文件树的数据来源保留，供 Library 的 File 使用。

## 7. 样式约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. 分段控件与文件树为一级、二级共用的一份实现，禁止按界面分别实现。

## 8. 设计文档同步

本需求验收通过后再更新设计文档：Library Overview Layout 与 Library Folder Detail Layout 的结构中加入 Tabs；新增 Library File Tree Layout，承接原 Data Tree Layout 的样式与交互，并补充二级只显示自身文件夹且默认展开的规则；删除 Data Tree Layout 与 Data 的边栏入口描述；Tab 的颜色 token 由 `--color-playback-module-sidebar-selected` / `--color-playback-module-sidebar-unselected` 改为中性命名，取值不变。

# 验收

1. 一级摘要行下方、二级封面组件下方各有一个左对齐的 Video / File 分段控件，外观与 Current / Playlist 一致。
2. 两个界面默认选中 Video，Video 下的内容与改动前一致。
3. 一级的 File 与原 Data 界面的样式、标签、默认展开层级、点击展开收起、Hover 与分隔线一致。
4. 二级的 File 只显示该文件夹自身的子树，自身一行默认展开，其下条目默认折叠，不出现根路径行。
5. 停留在 Video 时不读取文件树；首次切到 File 才读取；库内容变化后再次显示 File 能看到更新。
6. 一级切到 File 后进入二级，二级为 Video；返回一级，一级为 Video；离开 Library 页再返回，两处均为 Video 且展开状态为默认。
7. 边栏不再有 Data 入口，Data 页面不可达。
8. Light 与 Dark 两个主题分别核对。
9. 现有自动化端到端与单元用例全部通过。