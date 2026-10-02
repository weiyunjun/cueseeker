# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Toast Usage Registry.md`

# 需求描述

## 1. Task 卡片底色与 Hover 悬浮效果
1. Task 卡片的常态底色统一调整为 `--color-table-bg`（Light: `#FFFFFF` / Dark: `#26262A`）。
2. 卡片 Hover 底色统一为 `--color-row-hover`（Light: `#F9FAFB` / Dark: `#2E2E33`）。
3. 卡片边框在 Hover 时保持不变（`--color-border-control`）。

## 2. 卡片右侧操作与 dots-three 纯图标按钮
1. 在 Task 卡片右侧添加单个横向三点 `dots-three` 纯图标按钮（尺寸 32×32px，圆角 8px，图标 21px）。
2. 按钮布局与对齐：基准态（68px 卡片）下垂直居中（上下边距各 18px，右边距 16px）；第 3 行（进度条/错误信息）展开时保持距顶 18px 不变，不向下沉居中。
3. 按钮 Hover 底色使用 `--color-row-selected`（Light: `#F3F4F6` / Dark: `#36363C`），菜单打开期间保持 Open 常亮。
4. 按钮可用性：按钮恒定处于可用状态（Enabled），不因后台任务或卡片状态被禁用，由内部菜单项体现可用性。
5. File 卡片联动修正：移除 File 卡片 `dots-three` 按钮在任务阻塞期间的禁用逻辑，保持按钮恒定可用，改为由菜单项置灰。

## 3. 卡片弹出菜单内容与二次确认
1. 菜单项内容：
   - Current 卡片：`Cancel Task`（Destructive 警告项，图标 `minus-circle`）。正在运行的重命名与移除文件夹任务不可取消，菜单项置灰禁用（Disabled）。
   - Completed / Incomplete 历史卡片：`Delete Record`（Destructive 警告项，图标 `trash`）。
2. 二次确认弹窗：
   - 点击可用菜单项关闭菜单，并弹出二次确认弹窗（Confirmation Dialog）：
     - 取消任务弹窗：确认后任务中止并移至 Incomplete。
     - 删除记录弹窗：确认后从数据库完全移除记录。
3. 交互与模态规范：
   - 菜单挂靠在 `dots-three` 按钮上，优先朝下展开，空间不足时朝上展开，紧凑包裹无多余滚动条。
   - 菜单打开时取消全局焦点与文字选中，全局禁止滚动；支持键盘方向键、Enter 执行、Esc 退出；外部左键点击关闭菜单且不穿透。

## 4. 菜单打开期间状态变更拦截
1. 菜单打开后展示静态快照，不随底层卡片或队列变动实时更新。
2. 敏感操作执行校验：
   - Current 任务在菜单打开期间由进行中变为已完成或已终止（`In Progress → Completed/Incomplete`），用户点击 `Cancel Task` 时予以拦截：不弹出确认弹窗，弹出 Toast 警示。
   - Toast 规范：持续 3 秒，图标 `warning`，文案“任务状态已经改变”（英文：`Task status has changed`），无句号。
   - `Queued → In Progress` 状态流转不视为失效，正常允许调起确认弹窗。

# 验收

1. **卡片 Hover 与底色**：Light 和 Dark 模式下鼠标悬停 Task 卡片平滑展示浅灰底（`rowHover`），Dark 模式下底色与阶梯表现正常，边框稳定。
2. **dots-three 按钮表现**：按钮尺寸 32×32px，基准态垂直居中（上下边距各 18px），第 3 行展开时保持距顶 18px；悬停与打开底色为 `rowSelected`；按钮恒定可点。
3. **菜单功能与确认弹窗**：Current 卡片点击 `Cancel Task` 唤起移除任务确认弹窗，确认后移至 Incomplete；不可取消的进行中任务该项置灰；History 卡片点击 `Delete Record` 唤起删除记录确认弹窗，确认后记录被移除。
4. **状态变更拦截**：Current 任务在菜单打开期间已结束时，点击取消被拦截并弹出 Toast 报错（“任务状态已经改变”）。
5. **File 卡片联动**：File 卡片在有任务进行中时，`dots-three` 按钮保持可点，点开后重命名和移除选项置灰。