# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Toast Usage Registry.md`

# 需求描述

1. **File 界面状态指示器图标精简与点击打开任务详情（`L-04.5 File Page Layout`、`C-08.5 Status Indicator`）**：
   - **移除闲置态左侧图标**：File 界面顶部操作栏右侧的状态指示器在闲置状态（`Last Updated: yy-MM-dd HH:mm` 与 `Last Updated: --`）下，移除文字左侧的 `arrow-clockwise` 图标，仅展示纯文本；进行中（`Spinner`）、已完成（`check-circle`）、失败（`warning`）三种临时状态的左侧图标保持不变。
   - **可点击交互与 Hover / 指针样式**：
     - **从未执行过索引（`Last Updated: --`）**：保持纯静态文本展示，无 Hover 效果、鼠标保持默认箭头样式、点击不响应。
     - **其余所有状态（闲置态 `Last Updated: yy-MM-dd HH:mm`、进行中、已完成、失败）**：仅状态文字区域作为可交互热区（临时状态左侧图标不参与交互），纳入主窗口 `Grab`（手型抓手）指针白名单，严格遵守全局指针与 Hover 同步、弹窗/菜单打开复位及滚动 `300ms` 防抖规则。
     - **Hover 视觉反馈**：鼠标悬停在可点击的状态文字上时，文字颜色保持当前状态色不变，文字底部显示与当前文字同色的下划线（线宽 `--width-interactive-text-underline` `1px`，距文字基线偏移 `--offset-interactive-text-underline` `2px`）：
       - 闲置态与进行中：`--color-text-secondary` 文字与同色下划线。
       - 已完成：`--color-success-text` 文字与同色下划线。
       - 失败：`--color-danger-text` 文字与同色下划线。
   - **点击目标任务映射（对应 `Index All`、`Index`、`Add Folder`、`Remove Folder` 四类任务，不含重命名）**：
     - 点击后直接独立弹出对应任务的「任务详情（`Task Info`）」弹窗（不打开下层任务面板，关闭详情弹窗后直接回到 File 界面）：
       - **进行中**：打开当前正在执行的该条任务的详情弹窗。
       - **已完成 / 失败**：打开刚刚结束并产生该完成或失败提示的该条任务的详情弹窗。
       - **闲置态（`Last Updated: yy-MM-dd HH:mm`）**：打开产生该更新时间的那条最近已完成任务的详情弹窗。
     - **任务记录已删除时的 Toast 拦截**：若对应任务记录已在任务面板中被删除，点击状态文字时不打开详情弹窗，居中弹出 `warning` 图标、持续 `3 秒` 的 Toast（Scenario ID：`task.detail.record_not_found`）：
       - 英文：`Task record no longer exists`
       - 简体中文：`任务记录已不存在`
       - 繁体中文：`任務記錄已不存在`

2. **任务卡片与 File 卡片支持右键弹出上下文菜单（`L-04.6 File Card Layout`、`L-06.10 Task Card Layout`、`C-04.1 Menu`）**：
   - **适用范围**：
     - **File 界面卡片**：一级根文件夹卡片、二级子文件夹卡片、二/三级单集分组内的视频文件行与字幕文件行（单集分组顶部的剧集名称标题栏不响应右键）。
     - **任务面板卡片**：`Current`、`Completed`、`Incomplete` 三个标签页下的全部任务卡片。
   - **菜单内容与交互规范**：
     - 在卡片任意可视区域右键按下时，立即在鼠标右键落点处弹出菜单（下方空间不足时朝上展开）；菜单项内容、可用/禁用状态、点击动作以及菜单打开期间任务状态变更的保持与拦截规则，均与左键点击该卡片右侧 `...`（`dots-three`）按钮完全一致。
     - **挂靠高亮与 `Open` 状态区分**：
       - 通过左键点击 `...` 按钮打开菜单时，菜单挂靠在该按钮上，卡片保持 Hover 背景且 `...` 按钮处于 `Open` 状态（底色 `--color-row-selected`）。
       - 通过右键点击卡片打开菜单时，菜单挂靠在右键落点，菜单打开期间所属卡片保持 Hover 背景（`--color-row-hover`），但 `...` 按钮不进入 `Open` 状态（File 卡片的 `...` 按钮随卡片 Hover 显示为默认透明底色）。
       - 当已有菜单打开时，右键点击同一列表的另一张卡片或同一卡片的其他位置，立即关闭原菜单、解除原卡片冻结并重算 Hover，同时在新落点弹出新菜单。

# 验收标准

1. File 界面闲置状态下 `Last Updated: yy-MM-dd HH:mm` 与 `Last Updated: --` 左侧不再显示旋转箭头圆圈图标；进行中、已完成、失败三种临时状态仍保留左侧对应图标。
2. 初次未索引显示 `Last Updated: --` 时，鼠标移入无下划线、指针保持默认箭头、点击无反应；其余状态下鼠标移入状态文字时显示与当前文字同色（次要灰 / 成功绿 / 报错红）的 `1px` 下划线且指针变为 `Grab` 手型（临时状态的左侧图标无下划线且保持默认箭头）。
3. 在进行中、已完成、失败及 `Last Updated: yy-MM-dd HH:mm` 状态下点击状态文字，均能直接打开对应任务的 `Task Info` 详情弹窗，同时指针立即恢复默认箭头；若该条任务记录已被删除，点击后弹出 `warning` Toast「任务记录已不存在 / Task record no longer exists / 任務記錄已不存在」（持续 3 秒）。
4. 在 File 界面各级文件夹卡片、视频/字幕文件行以及任务面板三个标签页的任务卡片上右键点击，均能在鼠标落点处弹出与点击右侧 `...` 按钮内容和功能完全一致的菜单；右键菜单打开期间卡片保持 Hover 高亮且 `...` 按钮不呈 `Open` 深色底块，在卡片间连续右键可正常切换菜单。