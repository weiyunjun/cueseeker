# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/requirements/20260812-Feature-Shiori Detail Cover Summary.md`

# 替代范围

本需求替代原需求中封面摘要组件的分离、重合及 Light / Dark Mode 规则；其余滚动、工具栏、表格和 Scrollbar 规则保持不变。

# 需求目标

Shiori 二级界面的 Cover Summary 改为全宽自适应封面背景，并采用方案 B 的左侧文字保护渐变。

# UI 要求

1. Cover Summary 宽度与工具栏、表格内容区域一致，高度继续使用设计系统 Token。
2. 封面保持原始比例并使用 Aspect Fill、Center Crop；窗口宽度变化时实时重新布局和裁剪。
3. 禁止拉伸、补边、扩图、镜像、重绘或修改封面文件。
4. 使用方案 B：左侧文字区域覆盖深色遮罩，并从左向右平滑衰减至完全透明；不使用全图固定遮罩或模糊。
5. Cover Summary 内部在 Light Mode 与 Dark Mode 使用同一套视觉规则，不单独适配。
6. 文字区域宽度跟随组件宽度变化：
   - 最小宽度：`448pt`
   - 最大宽度：`720pt`
   - 首选宽度：组件可用宽度的 `50%`
   - 不得超出组件扣除内边距后的可用宽度。
7. 内容保持左对齐，依次显示标题、描述和 Resume / Play 按钮。
8. 描述使用次级文字颜色，最多显示两行，超出部分截断。
9. 保留 Resume、Play 和 Disabled 状态。

# 设计系统约束

1. 实现前必须在 `UI Design System.md` 中定义：
   - 文字区域最小、最大及首选宽度 Token。
   - 遮罩颜色、方向、透明度和渐变位置 Token。
   - Cover Summary 的图片裁剪、响应式布局及文字层级规则。
2. 同步更新 `Cover Summary` 组件和 `Shiori List Detail Layout` 定义。
3. 实现必须复用设计系统 Token 和共享组件，禁止页面内硬编码数值、私有渐变或 Appearance 特判。

# 范围

1. 仅修改 Shiori 二级界面。
2. 不修改其他页面的 Cover 组件。
3. 不重新生成封面，不修改持久化数据。

# 验收标准

1. 调整窗口宽度时，Cover Summary 与表格保持等宽，背景图连续自适应裁剪且不变形。
2. 在普通比例及约 `5:1` 的极端比例下均无留白、补图或横向拉伸。
3. 使用现有五张真实封面检查时，文字保持可读，右侧图片亮度得到保留。
4. 描述始终最多两行。
5. Light Mode 与 Dark Mode 的 Cover Summary 视觉一致。
6. 所有新增视觉和布局值均能在 `UI Design System.md` 中找到对应定义。