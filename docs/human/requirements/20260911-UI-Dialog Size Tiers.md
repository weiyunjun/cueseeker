# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Dialog、Dialogs 各 Layout、Text Area、Scrollbar）

# 需求描述

## 1. 范围

Confirmation、Edit Cover、Rename、Shiori List Editor、任务界面五个对话框。

## 2. 宽度档位

1. 新增四档对话框宽度，所有对话框的宽度只引用其中一档：

| 档位 | Token |
| --- | --- |
| small | `--width-dialog-small`：`360px` |
| medium | `--width-dialog-medium`：`480px` |
| large | `--width-dialog-large`：`600px`（暂无对话框使用） |
| x-large | `--width-dialog-x-large`：`720px` |

2. 各对话框的档位与高度：

| 对话框 | 宽度 | 高度 |
| --- | --- | --- |
| Confirmation | small | 随内容 |
| Edit Cover | small | 随内容 |
| Rename | medium | 随内容 |
| Shiori List Editor | x-large；窗口较窄时 small（见第 5 节） | 随内容 |
| 任务界面 | x-large | `--height-task-panel`：`500px` |

3. 删除不再使用的 token：`--width-task-panel`、`--height-task-panel-header`、`--width-edit-cover-dialog`、`--height-edit-cover-dialog`、`--width-shiori-list-editor-cover`、`--width-dialog-form-region`、`--height-form-text-area`。

## 3. 随窗口自适应

1. 对话框与窗口四边至少相距 `--spacing-6`。
2. 对话框宽度超过窗口宽度减两侧 `--spacing-6` 时取该值，内容随之变窄。
3. 对话框高度超过窗口高度减上下 `--spacing-6` 时取该值：Header 与 Footer 不动，其间的内容滚动。滚动区左右延伸到容器边缘；滚动条按 Scrollbar 规范浮在内容之上、不预留位置，不遮挡内容。

## 4. 容器统一

1. 五个对话框的背景统一为 `--color-bg-surface`。
2. 对话框不画自身描边，容器边缘只由 Dialog 的 Outline 与 Edge Highlight 构成；去掉 Confirmation 与任务界面自带的描边。
3. 任务界面不再自带背景、阴影与描边，与其它对话框一样使用 Dialog Container。

## 5. 各对话框布局

### Edit Cover

1. 封面为内容宽度的 16:9；选图后 Cover Crop Editor 位于同一区域。
2. 结构不变：Header、封面、Support Text、Footer。

### Rename

1. Current Name 与 New Name Field 占满内容宽度。

### Shiori List Editor

1. 窗口宽度不小于 `--width-dialog-x-large` 加两侧 `--spacing-6`（即 `768px`）时：x-large，左右两栏。
2. 窗口宽度小于该值时：small，上下单栏，依次为封面区（封面与 Support Text）、Name Field、Description Field；封面区与表单相距 `--spacing-6`。
3. 两种排版的封面尺寸相同：宽为 `--width-dialog-small` 减两侧 `--inset-dialog`，高按 `--aspect-library-cover`。两栏时表单列宽为剩余宽度。
4. Description 输入框的高度按两栏时"底边与封面底边对齐"计算，单栏沿用同一高度；Name Field 高度不变。

### 任务界面

1. 结构：
   1. Header：Title `Task`、Close Button
   2. Tabs：`Current`、`Completed`、`Incomplete`，位于 Title 下方，水平居中
   3. Task Card List
2. 四边视觉边距为 `--inset-dialog`，与其它对话框一致。
3. Title 与 Tabs、Tabs 与 Task Card List 之间相距 `--spacing-4`。
4. Task Card List 的滚动区左右与底部延伸到容器边缘；卡片与左右边缘相距 `--inset-dialog`，滚到底时最后一张卡片与底边相距 `--inset-dialog`。

## 6. 保持不变

1. 对话框的位置、压暗、圆角、阴影、Outline、Edge Highlight、动画、叠加、关闭按钮位置与 `--inset-dialog` 不变。
2. 各对话框的文案、字段、校验、按钮与键盘行为不变。
3. 任务卡片的内容与样式、Tabs 的切换行为不变。

# 验收

1. 窗口足够大时：Confirmation 与 Edit Cover 宽 360，Rename 宽 480，Shiori List Editor 宽 720，任务界面 720 × 500。
2. Edit Cover 的封面为 312 × 175.5，下方没有多余空白。
3. Shiori List Editor 在窗口宽 ≥ 768 时：两栏，封面 312 × 175.5，表单列宽 336，Description 输入框高 58.5，底边与封面底边对齐。
4. Shiori List Editor 在窗口宽 < 768 时：单栏，宽 360，封面与 Description 输入框的尺寸与两栏时相同。
5. 任务界面：Title `Task` 与关闭按钮在第一行，Tabs 在 Title 下方居中；四边视觉边距 24；列表滚到底时最后一张卡片距底边 24。
6. 窗口缩到最小：Rename 与任务界面变窄，两侧各留 24；Shiori List Editor 为单栏，窗口高度不足时 Title 与按钮不动、中间滚动，滚动条不遮挡内容。
7. 五个对话框背景同色，边缘没有额外的内描边。
8. Light 与 Dark 两个主题分别核对以上各项。
9. 本次改动不新增任何自动化端到端或单元用例的失败。