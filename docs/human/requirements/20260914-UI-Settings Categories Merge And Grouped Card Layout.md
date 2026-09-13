# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Settings Window Layout、Settings Sidebar Layout、Settings Category Layout、Settings Shortcuts Layout、Settings Subtitle Layout、Shortcut Field）
- `docs/human/design/Icon Registry.md`
- 示意图：https://claude.ai/code/artifact/33e5bf1d-7e00-42ac-9262-f17fc4a739f5

# 需求描述

## 1. 分类

1. 设置窗口侧栏由 10 个分类合并为 6 个，自上而下：

| 分类 | 图标 | 包含 |
| --- | --- | --- |
| 通用 | `gear-fine` | 外观、搜索、语言、Deep Link |
| 播放 | `play`（Fill） | 播放、解码 |
| 快捷键 | `keyboard` | 快捷键 |
| 字幕 | `subtitles` | 字幕 |
| 维护 | `hard-drives` | 维护 |
| 开发者选项 | `hammer` | 开发者选项 |

2. 打开设置窗口时选中通用。
3. 新增"通用"文案，简体中文、繁体中文与英文随现有本地化补齐。

## 2. 窗口

1. 默认尺寸为 `--width-settings-window` × `--height-settings-window`。宽度不可小于默认宽度；高度可缩小到 `--min-height-settings-window`，内容超出时纵向滚动。
2. 红绿灯保持系统默认位置。侧栏第一项与页面标题的顶部都位于窗口顶部向下 `--height-settings-titlebar` 处。
3. 内容区左侧留 `--spacing-6`；右侧留 `--spacing-6`，外加恒定预留的 `--width-page-scrollbar-channel`；底部留 `--spacing-6`。
4. 卡片宽度跟随窗口，不设上限。

## 3. 页面结构

1. 每页自上而下为页面标题与若干分组。每个分组由分组标题、可选的分组说明与卡片组成。
2. 合并前的分类名作为分组标题；没有原标题的分组也使用原分类名。合并前各分类页顶部的说明改为对应分组的说明。
3. 卡片内每行名称靠左、控件靠右，说明位于名称下方，行与行之间有分隔线。
4. 快捷键页与字幕页的 Section Title 改为分组标题。字幕页的恢复默认位于最后一张卡片下方，靠右。
5. 各页分组：

| 分类 | 分组与行 |
| --- | --- |
| 通用 | 外观：外观模式；搜索：显示台词组、用聚焦台词预填；语言：语言；Deep Link：播放第一条搜索结果 |
| 播放 | 播放：台词结束后自动暂停、自动切换到播放列表中的下一条台词、自动切换间隔；解码：解码器 |
| 快捷键 | 快捷键：打开命令面板；播放、播放覆盖层与命令面板：各自原有功能 |
| 字幕 | 文字、边框、阴影、位置：各自原有设置项 |
| 维护 | 维护：数据库大小、已用估算、可回收空间、WAL 大小、SHM 大小；维护状态，以及刷新与压缩数据库按钮；数据库路径 |
| 开发者选项 | 开发者选项：搜索 E2E JSON 日志、FTS 词表诊断；FTS 词表数据：状态与刷新按钮，启用后的词表数据位于同一卡片内 |

6. 维护页：统计数值位于控件位置；维护状态与按钮在同一行，按钮靠右。
7. 开发者选项页的词表数据内部排版不变，去掉其自带底色。
8. 快捷键冲突或按下不可用的键时，提示显示在 Shortcut Field 下方，该行随之变高；没有提示时不预留提示行。

## 4. Token

| 部位 | Token |
| --- | --- |
| 窗口默认宽度与最小宽度 | 新增 `--width-settings-window`：`880px` |
| 窗口默认高度 | 新增 `--height-settings-window`：`640px` |
| 窗口最小高度 | 新增 `--min-height-settings-window`：`420px` |
| 侧栏宽度 | 新增 `--width-settings-sidebar`：`184px` |
| 顶部留白 | 新增 `--height-settings-titlebar`：`36px` |
| 侧栏内边距 | 水平 `--padding-app-sidebar-x`；底部 `--padding-app-sidebar-y` |
| 侧栏项间距 | `--spacing-1` |
| 页面标题 | `--font-size-page-title`，`--font-weight-page-title`，`--color-text-primary` |
| 页面标题与第一个分组 | `--spacing-4` |
| 分组之间 | `--spacing-6` |
| 分组标题 | `--font-size-body`，Semibold，`--color-text-primary`；水平缩进 `--spacing-4` |
| 分组说明 | `--font-size-caption`，`--color-text-muted`；与分组标题间距 `--spacing-1` |
| 分组标题与卡片 | `--spacing-2` |
| 卡片背景 | 新增 `--color-settings-group-bg`：Light `#F6F7F9`；Dark `#202024` |
| 卡片边框与行分隔线 | `--color-border-divider`，宽度 `--border-width-control` |
| 卡片圆角 | 新增 `--radius-settings-group`：`10px` |
| 行最小高度 | 新增 `--min-height-settings-row`：`52px` |
| 行内边距 | 水平 `--spacing-4`；垂直新增 `--padding-settings-row-y`：`6px` |
| 行分隔线内缩 | 左右各 `--spacing-4` |
| 行名称 | `--font-size-body`，Regular，`--color-text-primary` |
| 行说明 | `--font-size-caption`，`--color-text-muted`；与名称间距 `--spacing-1` |
| 名称与控件最小间距 | `--spacing-4` |
| 语言下拉框宽度 | 新增 `--width-settings-popup`：`180px` |
| Number Field 宽度 | `--width-settings-number-field` |
| 维护统计数值 | `--font-size-body`，`--color-text-secondary`，等宽数字 |
| 维护状态 | 文字 `--font-size-body`；图标 `--size-button-icon`，与文字间距 `--spacing-2` |
| 维护状态颜色 | 正常 `--color-text-secondary`；完成 `--color-success-text`；失败 `--color-danger-text` |
| 建议压缩颜色 | 新增 `--color-warning-text`：Light `#B45309`；Dark `#FCD34D` |
| 数据库路径 | `--font-size-caption`，`--color-text-muted`，单行，中间省略 |
| 同一行内按钮之间 | `--spacing-2` |
| 字体名称与"选择…" | `--spacing-3` |
| 粗体与斜体 | `--spacing-6` |
| 最后一张卡片与恢复默认 | `--spacing-6` |

## 5. 保持不变

1. 各设置项的取值、文案、保存与生效时机不变。
2. 各控件组件自身的外观不变。
3. 无障碍朗读的名称与状态不变。

# 验收

1. 侧栏为 6 个分类，顺序与图标同第 1 节；打开设置窗口时选中通用。
2. 各页结构与示意图一致。
3. 窗口默认尺寸为 880 × 640；宽度不能缩小到默认宽度以下；高度可缩小到 420，内容纵向滚动。
4. 拉宽窗口时卡片随之变宽。
5. 快捷键冲突时，提示显示在该行输入框下方，该行变高；冲突解除后恢复原高。
6. 第 4 节涉及的数值全部引用 token，没有硬编码。
7. Light 与 Dark 两个主题分别核对。
8. 本次改动不新增任何自动化端到端或单元用例的失败。