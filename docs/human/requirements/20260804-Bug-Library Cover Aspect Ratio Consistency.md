# 版本
main

# 关联设计
- `docs/human/design/UI.md`
  - `--aspect-library-cover`
  - `Library Cover`
  - 所有复用 Library Cover 的 Layout

# 需求描述
1. 当前部分界面中的封面高度不一致。同一列表或 Grid 中，个别封面会受到图片自身尺寸或宽高比影响而被纵向撑高。例如 Library 一级界面中的“新世纪福音战士”封面明显高于同一行的其他封面；Library Folder Detail 中也存在相同问题。
2. 本需求修复现有实现与 UI 规则不一致的问题，不改变当前设计。所有 Library Cover 的展示容器必须遵循 `--aspect-library-cover: 16 / 9`。
3. No Cover、Shiori Default 和 Loaded 三种状态必须使用相同的容器几何规则。图片自身的像素尺寸、原始宽高比、加载状态或缓存结果不得改变封面容器的宽高比和所在 Layout 的排列。
4. 同一界面、同一种 Layout、相同可用宽度下的封面必须等宽、等高并保持上下边缘对齐。自适应布局改变封面宽度时，高度必须按 `--aspect-library-cover` 同步计算。
5. 图片继续填满封面容器并保持自身比例裁切，不得拉伸、补边，也不得通过改变容器高度展示完整原图。
6. Library Cover Progress Overlay、Library Cover Badge、Hover、Pressed、点击区域和 Context Menu 区域必须继续以最终的 16:9 Cover Region 为边界。
7. 禁止针对特定视频、封面文件、图片尺寸或单个界面增加特殊判断。所有相关界面必须复用统一的 Library Cover 几何规则。
8. 本需求只修正 UI 展示和布局，不重新生成封面文件，不修改用户封面裁剪结果，不迁移持久化数据。

# 覆盖范围
至少检查以下所有复用 Library Cover 的界面：

1. Workbench Library 一级界面的 Library Folder Card。
2. Workbench Library Folder Detail 的 Library Episode。
3. Workbench Recent 一级界面和 Recent Videos 二级界面的 Recent Watching Card。
4. Workbench Shiori 一级界面的 Shiori List Card。
5. Recent Shioris 使用的 Shiori List Cover。
6. Playback 视频型 Playlist。
7. Command Panel Recent Videos 和 Recent Shioris。
8. Edit Cover Dialog 和 Shiori List Editor Dialog 中的封面预览。

# 验收标准
1. Library 一级界面中，“新世纪福音战士”与同一 Grid 中的其他封面高度一致，排列不存在明显错位。
2. Library Folder Detail 中的所有 Episode Cover 使用所属 Layout 定义的统一尺寸和 16:9 比例。
3. 使用横向、纵向、方形及不同像素尺寸的源图片验证时，封面容器始终保持 16:9；图片只在容器内部等比裁切。
4. No Cover、Shiori Default 和 Loaded 状态之间切换时，封面尺寸和周围布局不发生跳变。
5. 调整窗口宽度后，自适应 Grid 可以重新排列和缩放，但同一 Layout 内的封面仍保持统一的 16:9 比例和一致高度。
6. Progress Overlay、Badge、圆角、Hover、Pressed、左键、右键和 Context Menu 行为不回归。
7. 所有覆盖范围内的界面均通过检查，不得只修复截图所示的单个入口。