# 版本

main

# 关联设计

- docs/human/design/UI Design System.md
- docs/human/requirements/20261009-Feature-Workbench Invalidation.md

# 需求描述

1. **现状问题**：
   - **Bug 1（Library 起播后 Command Panel 不刷新）**：从 Library 入口进入播放，看了一集后切换到下一集，在播放页呼出 Command Panel 进入 Recent Videos，列表没有刷新，仍显示旧记录。
   - **Bug 2（Recent 页面右键修改状态不刷新）**：在 Recent 页面右键卡片点击“标记为已看”或“标记为未看”，卡片状态不发生改变，必须切到其他 Tab 再切回才生效。
   - **Bug 3（Recent 起播后切集 Command Panel 不刷新）**：从 Recent 入口进入播放，切换到下一集后呼出 Command Panel 进入 Recent Videos，列表未更新为下一集。

2. **行为规范**：
   - **区分变更类型**：“界面冻结（Hold）”仅针对后台被动发生的数据突变（文件夹添加/移除/重建索引）；用户主动发起的业务操作（修改观看状态、起播、切集）必须即时响应并刷新界面，严禁拦截。
   - **Command Panel 页面更新**：呼出 Command Panel 并进入 Recent Videos 时，必须按最新数据库数据更新列表，确保展示当前最新的播放记录与剧集进度。

# 验收标准

1. **Library 起播与切集**：从 Library 打开视频播放并切至下一集，呼出 Command Panel 进入 Recent Videos，正确展示最新一集的播放记录。
2. **Recent 页面右键状态**：在 Recent 页面右键卡片修改观看状态（已看/未看），当前界面的卡片状态立即更新，无需切页。
3. **Recent 起播与切集**：从 Recent 页面打开视频播放并切至下一集，呼出 Command Panel 进入 Recent Videos，正确展示最新一集的播放记录。