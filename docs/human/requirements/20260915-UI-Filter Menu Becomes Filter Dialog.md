# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Dialog、Filter Menu、Filter Option Menu Item、Checkbox / Filter Checkbox、Menu Title、Menu Section Header、Progress Indicator、Search / Excerpt Toolbar Layout、Dialogs）
- `docs/human/design/UI Application Rules.md`（界面层级、焦点）

# 背景

后续会加入文件等更复杂的筛选，菜单已不够用，筛选改为对话框。

# 需求描述

## 1. 范围

Search 与 Excerpt 二级界面的筛选按钮，两个界面共用同一实现。

## 2. 对话框

1. 点击筛选按钮打开 Filter 对话框，取代 Filter Menu；对话框打开期间筛选按钮为 Open 状态。
2. 宽度为 `--width-dialog-x-large`，其余遵循 Dialog 规范：标题 `Filter`、右上角关闭按钮、四边等宽、窗口不足时变窄、内容过高时中间滚动。
3. Esc 与关闭按钮等同 Cancel；回车等同 Show。

## 3. 结构

1. 从上到下为 Duration、Character、Language、Watch Status 四组，组名沿用现有图标。
2. 每组的选项为胶囊按钮，显示选项名与数字；一行可放多个，按宽度自动换行。
3. 底部左侧为计算状态（见第 6 节），右侧为 Cancel 与 Show。Show 在 Search 为 `Show N results`，在 Excerpt 为 `Show N excerpts`；N 为 1 时为 `Show 1 result`、`Show 1 excerpt`。

## 4. 胶囊按钮

1. 选中：文字与数字为 macOS accent color，背景为 `--color-library-media-card-hover-bg`，边框为 macOS accent color。
2. 数字为 0 的选项仍可点击，显示 0。
3. 胶囊按钮不获得焦点。
4. 所有尺寸、间距与颜色只引用 Design System 的 token，不硬编码，不为单个界面私自实现。

## 5. 勾选与生效

1. 点击胶囊只切换对话框内的勾选并更新数字，表格不变。
2. 点击 Show：勾选与表格当前使用的不同时，按新勾选更新表格并关闭对话框；相同时只关闭。
3. Cancel 放弃对话框内的改动；每次打开都从表格当前的勾选开始。
4. 数字的计算语义不变：每组的数字忽略本组的勾选，叠加其他三组。

## 6. 计算中

1. 数字未知的胶囊，数字位置显示静止的灰色圆角小块，不转圈；已知的数字照常显示。
2. 总数未知时，Show 的文字为 `Show results` 或 `Show excerpts`，按钮仍可点击。
3. 有未知数字时，底部左侧显示 Progress Indicator 与 `Calculating`；全部数字已知后消失。
4. 在对话框内改勾选：计数已全部完成时，数字与总数立即由已有结果得出；未完成时不发起搜索，新勾选下的数字显示灰色小块，当前搜索的计数完成后补上。
5. 计数未完成时点击 Show，按新勾选重新搜索并更新表格。

## 7. 替代

1. 本需求替代 `20260826-UI-Filter Menu Replaces Filter Panel.md` 中「勾选即时生效、菜单保持打开」。
2. 本需求替代 `20260914-Feature-Search Filter-First Execution And Ordered First Page.md` 第 4 节中「计算期间修改勾选直接开始新的搜索」，仅限对话框内的勾选；点击 Show 之后仍按该需求执行。

## 8. 设计文档同步

验收通过后更新 `UI Design System.md` 与 `UI Application Rules.md`：新增胶囊按钮组件与 Filter Dialog Layout，删除 Filter Menu 及仅被它使用的组件，Toolbar 状态改为对话框打开，界面层级的对话框清单加入 Filter。

# 验收

1. Search 与 Excerpt 二级界面点击筛选按钮打开 Filter 对话框，宽度、标题、关闭按钮、四边间距符合 Dialog 规范；Esc 与关闭按钮等同 Cancel，回车等同 Show。
2. 四组从上到下排列，胶囊按宽度自动换行；选中外观符合第 4 节。
3. 点击胶囊时数字变化、表格不变；Show 在勾选有变化时更新表格，无变化时只关闭；Cancel 后再次打开为表格当前的勾选。
4. 搜索高频词后立即打开对话框：未知数字为灰色小块，底部左侧显示 spinner 与 Calculating，Show 可点击；计数完成后数字同时出现，按钮显示总数，spinner 消失。
5. 计数完成前在对话框内改勾选不刷新表格，计数完成后数字补上；点击 Show 后表格按新勾选更新。
6. 现有自动化端到端与单元用例全部通过。