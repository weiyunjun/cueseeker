# 版本

main

# 关联设计

无。本需求不改变任何用户可见行为。

# 需求描述

1. 现状：以下分支在代码中定义，但运行时永远无法到达，其图标与文案不会出现在界面上。
2. Playback Overlay 模块图标：模块切换只渲染文字标签，模块枚举的图标属性在全仓库没有任何读取点。移除该属性及其 Current、Playlist、Search、Library、Shiori 五个分支的图标定义。
3. 空状态的搜索类状态：空状态组件只在 Search 页的 Library 面板构造，只使用无媒体库、加载中、加载失败、没有视频四个状态。移除从不构造的搜索未输入、搜索中、搜索失败、搜索无结果、Shiori 为空五个状态及其标题、说明文案与图标。
4. Sidebar 的 library 分支：Sidebar 只呈现 Search、Recent、Library、File、Shiori 五项，其中 Library 由 testLibrary 分支承担。移除从不被激活的 library 分支。
5. 只移除上述不可达分支，不改动任何仍在渲染的界面、文案与图标。移除后失去引用的本地化条目一并移除。
6. 不删除任何文件。

# 验收

1. 构建通过，无新增告警。
2. Sidebar 五项、Search 页 Library 面板四个空状态、Playback Overlay 模块切换的外观与行为与改动前完全一致。
3. 视觉人工验收。不为本需求新增 E2E 能力。