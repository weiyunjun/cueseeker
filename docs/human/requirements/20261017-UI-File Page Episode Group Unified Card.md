# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **新增单集分组顶栏背景色 Token（`UI Tokens.md`）**：
   - 新增 `--color-file-group-header-bg`：Light `#F8F9FB`；Dark `rgba(255,255,255,0.04)`。

2. **File 页面单集文件分组改为合一卡片结构（`L-04.5 File Page Layout` & `L-04.6 File Card Layout`）**：
   - 取消原有的「上方独立 `Display Title` + 外层深灰底容器（`--color-settings-group-bg`）+ 内部独立带边框卡片」的双层套娃结构。
   - 每个 `Episode File Group` 作为一张合一圆角卡片容器：背景 `--color-table-bg`、边框 `--color-border-control`（线宽 `--border-width-control`）、圆角 `--radius-settings-group`（`10px`）、容器内边距 `0px` 并做圆角裁剪。
   - 卡片顶部内嵌标题栏（高度 `--height-control: 36px`，水平内边距 `--spacing-4: 16px`，背景 `--color-file-group-header-bg`），左对齐展示 `Display Title`（维持 `14px` Medium `--color-text-muted` 样式不变，右侧不显示数量统计），标题栏底部为与卡片容器等宽的 `1px` `--color-border-divider` 分隔线。
   - 视频文件行与字幕文件行在合一卡片内上下紧贴排列，不再各自绘制独立外边框、圆角或外间距；行与行之间使用与卡片容器等宽（左右 `0` 内缩）的 `1px` `--color-border-divider` 分隔线；单行默认背景透明，Hover 背景为 `--color-row-hover`。

# 验收标准

1. `--color-file-group-header-bg` 在 Light 下为 `#F8F9FB`，在 Dark 下为 `rgba(255,255,255,0.04)`。
2. File 二级与三级界面的单集文件分组呈现为「顶栏 `Display Title` + 视频行 + 字幕行」合一卡片，无外层灰框套内层卡片的双重边框。
3. 顶栏底部分隔线以及视频行与字幕行之间的分隔线均与卡片容器等宽（无左右内缩），单行 Hover 时高亮区域与上下分割线及卡片边缘严丝合缝。
4. 顶栏仅左侧显示 `Display Title`（`14px` Medium `--color-text-muted`），右上角不显示视频或字幕数量。