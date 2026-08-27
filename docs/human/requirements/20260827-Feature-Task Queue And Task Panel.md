# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Dialog、Confirmation Dialog、Icon Button、Watch Status Badge、Tabs / Tab、App Topbar Layout、Playback Topbar Layout）
- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽、菜单模态）

# 需求描述

## 1. 目标

用户发起的耗时任务进入统一队列，并提供可视化的任务界面查看进度、取消任务与查看历史记录。当前唯一的任务类型是导出 Anki。

## 2. 任务与队列

1. 一个任务等于用户单次发起的一条命令，例如一次选择 100 条字幕导出为一个 apkg。
2. 同一时刻只执行一个任务，其余按发起顺序排队。
3. 现有两处导出入口（Search 表格与 Shiori 表格的 Selection Action Overlay）不变；导出目的地仍在点击 Anki 时通过系统保存面板选择，选定后任务立即入队。
4. 队列不跨重启续跑。

## 3. 入口按钮

1. 位置为 Workbench 的 App Topbar 右端。播放页不在本需求范围内。
2. 样式与筛选按钮一致：Icon Button，无边框，默认透明背景，Hover 灰底；任务界面打开期间为 Open 状态，accent 背景、白色前景。
3. 左键点击打开任务界面；右键无功能。
4. 左键遵循菜单通用规则：已有菜单打开时，这次点击只关闭菜单，不打开任务界面。
5. 按钮右下角显示剩余任务数量，即进行中与队列中之和。1 位数为圆形，2 位及以上为胶囊形，背景为 accent color，文字为白色；数量为 0 时不显示。

## 4. 任务界面

1. 按 Dialog 呈现：整窗口压暗、popover 背景、边框、阴影，模态屏蔽下层输入。
2. Header 行中间为 segment control，包含 Current、Completed、Incomplete，沿用 Playback Overlay 的 Current / Playlist 标签样式。
3. Header 行右端为 `-` 按钮，占据 Dialog 关闭按钮的位置。
4. 关闭方式只有 `-` 按钮与 Esc；点击界面之外不关闭。
5. 关闭时有收缩回入口按钮的动画。
6. 标签选择不持久化，每次打开都停在 Current。
7. 三个标签下的任务都按先发起的排在前面。
8. 进度更新时只刷新对应卡片的进度部分，不重建整个任务界面。

## 5. Current 卡片

自上而下五行：

1. 状态徽标、任务名称、`x` 按钮。徽标为 In Progress（蓝）与 Queued（灰），沿用 Watch Status Badge 的外观规则。任务名称当前只有 Export to Anki。
2. apkg 文件名。
3. 导出的文件夹地址。
4. 进行中显示导出进度，例如 `10 / 100 cards exported`；队列中显示卡片总数，例如 `80 cards`。
5. 进度条，只有进行中的任务才有；灰底，进度部分为 accent color。

## 6. Completed 卡片

自上而下四行：

1. 任务名称、垃圾桶按钮。
2. apkg 文件名。
3. 导出的文件夹地址。
4. 左对齐显示卡片数量，例如 `100 cards`；右对齐显示完成时间，日期格式与 Shiori 表格的 Date Added 一致。

## 7. Incomplete 卡片

自上而下五行：

1. 任务名称、垃圾桶按钮。
2. apkg 文件名。
3. 导出的文件夹地址。
4. 左对齐显示卡片数量；右对齐显示移入本标签的时间，日期格式同上。
5. 错误信息，红色文字。

## 8. 取消与删除

1. Current 卡片的 `x`、Completed 与 Incomplete 卡片的垃圾桶，都先弹出二次确认。
2. Current 的确认标题为 Remove Task；Completed 与 Incomplete 的确认标题为 Delete Record。
3. Current 的任务确认后移入 Incomplete，错误信息为 `Cancelled by user`。取消进行中的任务时立即终止其正在运行的子进程，不等待当前卡片导出完毕。
4. Completed 与 Incomplete 的记录确认后永久删除。

## 9. 中断处理

1. 任务执行期间 App 发生异常或被退出，进行中与队列中的任务全部进入 Incomplete。
2. 因退出或强制结束导致的中断，错误信息为 `Interrupted before the task finished`。

## 10. 持久化

1. 三个标签的内容跨重启保留。进行中与队列中的任务同样落盘，以便下次启动时按第 9 节转入 Incomplete。
2. 记录数量不设上限。

## 11. 样式约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. 禁止为单个界面增加私有实现。

## 12. 设计文档同步

本需求验收通过后再更新设计文档：UI Application Rules 的界面层级新增任务界面一层，位于工作台页面之上、对话框之下；UI Design System 新增任务状态徽标、任务卡片、数量徽标、确定进度的进度条与任务界面布局，App Topbar Layout 增加尾部功能区。

# 验收

1. 所有 Workbench 页面的 App Topbar 右端都出现该按钮，样式与筛选按钮一致，打开任务界面时为 accent 背景白色前景。
2. 有菜单打开时点击该按钮只关闭菜单，不打开任务界面。
3. 数量徽标随进行中与队列中的总数变化，1 位为圆形、2 位以上为胶囊形，为 0 时不显示。
4. 连续发起多个导出时，只有第一个执行，其余为 Queued，按发起顺序排列。
5. Current 卡片五行内容与进度文案正确；进度条只出现在进行中的任务上。
6. 任务界面为模态：下层不响应指针与键盘，点击界面之外不关闭，`-` 与 Esc 可关闭并播放收缩动画。
7. 每次打开都停在 Current 标签。
8. 三种卡片的删除或取消都先弹出二次确认，标题分别为 Remove Task 与 Delete Record。
9. 取消进行中的任务后立即停止，并出现在 Incomplete，错误信息为 `Cancelled by user`。
10. 导出失败的任务出现在 Incomplete 并显示红色错误信息。
11. 任务执行期间退出 App，重新启动后原进行中与队列中的任务都出现在 Incomplete，错误信息为 `Interrupted before the task finished`。
12. Completed 与 Incomplete 的记录跨重启保留，删除后不再出现。
13. 进度跳动期间任务界面其余部分不重建。
14. 现有自动化端到端与单元用例全部通过。