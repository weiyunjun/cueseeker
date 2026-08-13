# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/requirements/20260813-Feature-Shiori Detail Adaptive Cover Summary.md`
- `docs/human/requirements/20260812-Feature-Shiori Detail Cover Summary.md`

# 需求目标

将 Shiori 二级界面现有 Cover Summary 改为通用共享组件，并接入 Library 文件夹二级界面。

# 共享组件

1. 统一负责背景封面、响应式裁剪、渐变、内容布局和 Resume / Play 按钮。
2. 支持：
   - Shiori：标题、最多两行描述、操作按钮。
   - Library：标题、数量、文件夹路径、操作按钮。
3. 两个页面复用同一视觉规则和设计 Token，禁止页面内私有实现或新增硬编码。

# Library 二级界面

1. Cover Summary 依次显示：
   - 文件夹标题。
   - `xx videos yy subtitles`。
   - 当前文件夹完整路径。
   - Resume 或 Play 按钮。
2. 视频和字幕数量仅统计当前文件夹，并与下方 Episode Grid 使用同一当前可用数据范围。
3. 使用当前文件夹封面，保持 Aspect Fill、Center Crop，不修改封面文件。
4. Cover Summary 与 Episode Grid 使用相同水平边界，并位于现有单一页面滚动区域内。

# Resume / Play

1. 当前文件夹存在对应 Recent Videos 项时显示 Resume，行为与在 Recent Videos 中点击该项一致。
2. 当前 Shiori List 存在对应 Recent Shioris 项时显示 Resume，行为与在 Recent Shioris 中点击该项一致。
3. 不存在对应 Recent 项时显示 Play，并从当前内容顺序的第一项开始播放。
4. 没有可播放内容时按钮 Disabled。
5. 不修改 Recent Videos 和 Recent Shioris 现有的生成、排序、有效性及回退规则。

# 范围

1. 不修改 Recent 页面 UI。
2. 不修改播放历史或 Shiori 最近播放记录的持久化结构。
3. 不修改 Episode Grid、字幕表格、封面文件或封面生成逻辑。
4. `UI Design System.md` 在视觉验收完成后更新并提交，记录最终共享组件变体和 Library 布局。

# 验收标准

1. Library 与 Shiori 二级界面复用同一个 Cover Summary 组件。
2. Library 标题、数量、路径和按钮分行正确显示。
3. Resume / Play 的显示和播放目标符合对应 Recent 数据。
4. Library 数量只包含当前文件夹内容。
5. Light / Dark Mode、窗口缩放和页面滚动无视觉或行为回归。
6. 新增视觉与布局值不存在页面内硬编码。