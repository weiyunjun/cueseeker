# 版本

main

# 关联设计

- `docs/human/design/Playback Edge Cases.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/UI Design System.md`
- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md`

# 需求描述

## 1. 范围

Add Folder、Index、Remove Folder 导致内容离开数据库后，Command Panel、Library 一级与二级、Recent、File、Excerpt 一级界面的交互行为与失效处理。

## 2. 核心规则

1. **界面冻结（Hold）**：
   - 数据库变更发生时，当前正处于的界面（Command Panel、Recent、Library 二级、File 视图、Excerpt 二级）保持当前内容，不主动刷新、不关闭、不强退。
   - 在同一个模块内部切换视图（Recent 内的 Recent Videos ↔ Recent Excerpt Lists），维持冻结状态，不触发刷新。
2. **离开又返回触发刷新**：
   - 离开当前界面（关闭浮层再打开、跨 Sidebar Tab 切换再切回、从二级返回一级、Command Panel 返回根页或重新搜索），按最新数据库拉取并渲染最新数据。
3. **未刷新操作拦截**：
   - 在冻结界面点击已失效条目尝试播放或执行操作，一律拦截，并在当前上下文弹出对应失效提示。

## 3. 各界面具体行为

### 3.1 父子层级与实体失效（File、Library、Excerpt）

1. 当文件夹或摘录集被移出数据库：
   - 用户处于其子级视图并通过返回按钮或面包屑回退到该父级时；
   - 或用户在尚未刷新的一级界面点击该失效卡片进入二级时：
2. **面包屑与导航**：保持目标路径名称（例如 `Home > 影视`），不突变跳级。
3. **主内容区域展示**：
   - **严禁渲染常规详情骨架**（不显示封面图、标题、描述、表格等）。
   - **仅在顶栏下方展示纯净提示文字**：
     - File / Library：`该文件夹已不在媒体库中`（`This folder is no longer in the library.`）
     - Excerpt：`该列表已不在媒体库中`（`This list is no longer in the library.`）
4. **再次返回**：在上述失效提示下再次返回上一级时，上一级界面根据最新数据库渲染，该失效卡片已被彻底移除。

### 3.2 Recent 界面

1. 停留中以及在 Recent Videos 与 Recent Excerpt Lists 之间切换时保持冻结。
2. 离开 Recent 模块（切换至其他 Sidebar Tab 或进入播放页）再切回时，重新拉取并剔除失效卡片。
3. 点击失效卡片尝试播放，拦截操作并弹出提示。

### 3.3 Command Panel 界面

1. 停留中保持冻结。
2. 返回根页、关闭后重新呼出、或重新搜索时按最新数据库更新。
3. 选中失效项触发播放，拦截并提示 `This item is no longer in the library`。

# 验收

由所有者使用以下指令启动进行人工 E2E 验收：
`cd /Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native && CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker`

1. **File 面包屑回退失效提示**：移除某目录后，从三级文件列表回退至该目录，面包屑保留路径，内容区不渲染卡片，仅在顶栏下方显示提示文字；再次点击 Home 回退，该目录从根目录列表中消失。
2. **Library / Excerpt 二级失效提示**：移除文件夹或摘录集后，进入或处于其二级界面，不渲染封面、描述、表格等骨架，仅在顶栏下方显示提示文字；返回上一级后该项彻底消失。
3. **Recent 冻结与切 Tab 刷新**：库变更时，在 Recent Videos 与 Recent Excerpt Lists 间切换不刷新；切换 Sidebar Tab 再返回后，失效卡片被剔除。
4. **Command Panel 刷新与拦截**：库变更后返回根页或重新打开，展示最新数据；点击失效项播放被拦截并提示。
5. **单元与集成测试**：由 AI 负责补充和跑通相关单元测试与 Coordinator 状态集成测试，不新增自动化 E2E 测试。