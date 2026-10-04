# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 纯图标按钮 Open 状态背景色与图标样式
1. **统一引入浅 Accent 激活底色**：
   - 当按钮挂靠的面板/弹窗/窗口处于打开状态，或按钮控制的模式开启时（Open 态），按钮背景色使用半透明 Accent 浅底（不再使用原有与 Hover 相同的灰色/白透明底）。
   - 工作台环境：使用 `--color-bg-active`。
   - 播放器环境：使用播放器浅 Accent 半透明底（恒定暗色，不随系统 Light/Dark 切换）。
2. **图标颜色保持恒定**：
   - 图标自身颜色在 Open 态下保持原有颜色不变（Light 下保持深色/次级文字色，Dark 与播放器下保持浅色/纯白色），不跟随变色。
3. **覆盖范围**：
   - Workbench 界面顶栏右侧按钮（Task Entry、Settings Entry）。
   - Search 界面与 Excerpt 二级界面的工具栏按钮（Filter 筛选、Select 选中模式）。
   - Playback 界面与 Playback Overlay 界面顶栏右侧按钮（Task Entry、Settings Entry）。

## 2. 数字角标视觉样式调整
1. **背景色与文字色**：
   - 包含数字的角标，背景色统一由原本的灰色（`--color-text-muted`）调整为 **macOS Accent Color** 实心强调色。
   - 角标内部文字统一为白色（`--color-icon-on-dark`）。
   - **禁用态弱化呈现**：当按钮处于禁用状态（如进入 Select 模式时 Filter 按钮被禁用），角标底色调整为 **macOS Accent Color 半透明底（Alpha 0.35）**，内部文字保持白色，既表达按钮当前不可交互，又保留已生效筛选条件的语义识别度。
2. **形态与尺寸**：
   - 单数字为正圆形；两位及以上数字为半圆两端胶囊形。
3. **覆盖范围**：
   - Filter 按钮与 Task 按钮内的数字角标。
   - 筛选弹窗（Filter Dialog）各分类标题右侧的选中数量角标（使用 compact 尺寸）。

# 验收标准

1. **Open 状态明确识别**：
   - Filter 弹窗打开、Task 抽屉展开、Settings 窗口打开、进入 Select 模式时，对应按钮背景均呈现浅 Accent 底色，与未激活按钮及灰色 Hover 态有明显区分。
   - 图标自身文字/图形颜色在开启前后保持一致。
2. **数字角标高对比度与统一性**：
   - 搜索栏筛选条件数、顶栏 Task 任务数、筛选弹窗分类右侧数字均呈现 Accent 实心底 + 白字。
   - 在 Light、Dark 及播放器暗色视频背景下均清晰醒目、无色彩遮挡。
   - 进入 Select 模式时，禁用的 Filter 按钮上的数字角标呈现半透明 Accent 底（Alpha 0.35）+ 白字，无纯灰底割裂感。
3. **各场景对齐**：
   - Workbench、Search/Excerpt、Playback、Filter Dialog 四处涉及的按钮与角标表现一致。