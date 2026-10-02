# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 卡片底色与 Hover 悬浮效果
1. File 页面一级、二级、三级所有卡片的常态底色统一调整为 `--color-table-bg`（Light: `#FFFFFF` / Dark: `#26262A`）。
2. 卡片 Hover 底色统一为 `--color-row-hover`（Light: `#F9FAFB` / Dark: `#2E2E33`）。
3. 卡片边框在 Hover 时保持不变（`--color-border-control`）。

## 2. 卡片右侧操作替换为 dots-three 纯图标按钮
1. 移除各级卡片右侧的原独立操作按钮，统一替换为单个横向三点 `dots-three` 纯图标按钮（尺寸 32×32px，圆角 8px，图标 21px）。
2. 按钮 Hover 底色使用 `--color-row-selected`（Light: `#F3F4F6` / Dark: `#36363C`），比卡片底色深一级。
3. 菜单打开期间按钮保持 Open 常亮外观。
4. 任务执行中（`isFolderOperationBlocked`）时，按钮为 Disabled，禁止唤起菜单。
5. 按钮布局与对齐：基准态（68px 卡片）下垂直居中（上下边距各 18px，右边距 16px）；多行文本撑开卡片时保持距顶 18px 不变，不向下沉居中。

## 3. 卡片弹出菜单内容与交互
1. 菜单项内容：
   - 一级卡片：`Rename Folder`（Neutral）+ `Remove`（Destructive 警告项）。
   - 二级卡片：`Rename Folder`（Neutral）。
   - 三级卡片：`Rename Files`（Neutral）。
2. 交互与模态规范：
   - 菜单挂靠在 `dots-three` 按钮上，优先朝下展开，空间不足时朝上展开。
   - 菜单紧凑包裹内容，不预留滚动条。
   - 菜单打开时取消全局焦点与文字选中，全局禁止滚动。
   - 支持键盘方向键切换高亮、Enter 执行高亮项并关闭、Esc 退出；外部左键点击关闭菜单且不穿透。

# 验收

1. **卡片 Hover 反馈**：Light 和 Dark 模式下鼠标悬停卡片均平滑展示对应浅灰底，边框保持稳定。
2. **dots-three 按钮表现**：按钮尺寸 32×32px，基准态垂直居中（上下边距各 18px），多行态保持顶距 18px；悬停与菜单打开时底色（`rowSelected`）比卡片 Hover 底色明显深一级；任务阻塞时置灰禁用。
3. **菜单功能与样式**：一级卡片菜单正确展示 Neutral 重命名与标红警告级 `Remove`，点击分别唤起改名弹窗与移除确认弹窗；二、三级展示对应重命名项。
4. **菜单交互模态**：键盘上下与回车可操作；外部点击关闭且不误触底层；打开时窗口禁止滚动；无多余滚动条空白。