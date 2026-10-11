# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 顶栏视觉与边距对齐
1. **Workbench 顶栏右侧边距**：
   - 右侧按钮（Task、Settings）的右边距调整为：左侧返回按钮边距（24px）+ 滚动条通道宽度（16px）= **40px**。
   - 视觉上使得最右侧的设置按钮与下方内容区右侧边缘在垂直方向上对齐。
2. **Playback 与 Playback Overlay 顶栏高度统一**：
   - 顶栏高度统一调整为与 Workbench 顶栏一致的 **54px**（规范既有 `--height-app-topbar` 为 54px）。
   - 顶栏内部的返回按钮、标题、Segmented Control 及右侧按钮在 54px 高度内保持垂直居中。
3. **Playback 与 Playback Overlay 顶栏右侧边距**：
   - 右侧按钮区域的右边距统一调整为 **40px**，在位置上与 Workbench 顶栏保持一致。
4. **红绿灯按钮位置保持不变**：
   - 原生窗口控制按钮（红绿灯）的垂直与水平坐标保持不变，不随顶栏高度调整而改变位置。

## 2. Segmented Control 样式与布局调整
1. **样式统一**：
   - Segmented Control 组件样式统一采用与 `Settings -> General -> Appearance Mode` 一致的圆角边框底座与高亮选中块样式。
2. **三处界面布局调整**：
   - **Workbench - Recent 界面**：
     - 顶栏左侧保留“Recent”（最近）页面标题。
     - 分段控制器移至顶栏并在内容区（除去侧边栏后的主区域）水平、垂直居中；选项文字精简为 `Videos` / `Excerpt Lists`（中文：`视频` / `摘录集`）。
     - 移除原内容区滚动流上方的旧 Tab 组件。
   - **Playback Overlay 界面**：
     - 顶栏居中 Tab 替换为 Segmented Control，在 54px 顶栏中垂直、水平居中；选项为 `Current` / `Playlist`（中文：`当前` / `播放列表`）。
   - **Task 弹窗界面**：
     - 顶部整合成单行通栏布局：左侧为“Task”（任务）标题，中间水平居中放置 Segmented Control，选项为 `Current` / `Completed` / `Incomplete`（中文：`进行中` / `已完成` / `未完成`），右侧为关闭“✕”按钮。

# 验收标准

1. **Workbench 顶栏**：最右侧设置按钮与下方内容区右侧边缘垂直对齐。
2. **Playback 顶栏与 Overlay 顶栏**：高度均为 54px，按钮与标题垂直居中；右侧按钮边距与 Workbench 一致；红绿灯位置完全不变。
3. **Recent 界面**：顶栏左侧保留标题，内容区中间居中展示 Videos / Excerpt Lists 分段控制，选项切换正常工作。
4. **Playback Overlay 界面**：顶栏居中展示 Current / Playlist 分段控制，样式与设置项一致。
5. **Task 面板**：顶部标题、Segmented Control 与关闭按钮同排居中展示，分段控制水平居中。