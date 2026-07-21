# 版本
main

# 需求描述
1. 新增修改封面图功能。在视频卡片（Recent，Library一级界面，Library二级界面）的右键菜单中，新增Change Cover的菜单。
2. 点击Change Cover的菜单，弹出系统的文件选择界面，可以选择JPEG JPG PNG GIF四种格式的，体积小于等于20MB的图片（这里以通用的20MB计算，不要用macOS的20MB），其中GIF只读取第一帧。
3. 不符合要求的文件，变灰，不可以选择。
4. 只保存裁剪后的最终封面，分辨率512 × 288，JPEG Quality 0.90，写入 Covers/User/Display/v1/。
5. 保存成功后，刷新对应封面区域（不要刷新整个界面）。
6. Index封面和用户上传图片独立，并保证不会互相覆盖。
7. 新封面保存并切换成功后，删除旧用户封面文件并清除旧内存缓存；失败时保留旧封面，Index封面始终保留。
8. UI改动见# UI文档改动。

# UI文档改动

### 1. 增加 Primary Button

修改前

```markdown
#### Neutral Button

- 用途：执行保存、取消、导出等普通命令。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--font-weight-control`、`--color-text-primary`。
- Leading Icon 可选，图文间距使用 `--spacing-2`。
- 状态：Default、Hover、Disabled。

#### Inline Add Button
```

修改后

```markdown
#### Neutral Button

- 用途：执行保存、取消、导出等普通命令。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--font-weight-control`、`--color-text-primary`。
- Leading Icon 可选，图文间距使用 `--spacing-2`。
- 状态：Default、Hover、Disabled。

#### Primary Button

- 用途：执行当前界面的主要确认操作。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-primary-button-bg`、`--color-primary-button-bg-hover`、`--color-primary-button-text`、`--color-bg-disabled`、`--color-text-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--font-weight-control`。
- 状态：Default、Hover、Disabled。

#### Inline Add Button
```

### 2. Library Card Context Menu 增加 Change Cover

修改前

```markdown
- Recent 和 Library Folder 在卡片交互区域触发。
- Library Episode 只在 Cover Region 触发。
- Workbench 中的 Menu Item 由所属 Card Layout 定义。
```

修改后

```markdown
- Recent 和 Library Folder 在卡片交互区域触发。
- Library Episode 只在 Cover Region 触发。
- 所有 Library Card Context Menu 均包含 `Change Cover`。
- `Change Cover` 打开 Finder；选择图片后打开 Edit Cover Dialog。
- Workbench 中的其他 Menu Item 由所属 Card Layout 定义。
```

### 3. 增加 Library Cover Crop Editor

修改前

```markdown
- 本组件不定义点击动作，交互由所属卡片决定。

#### Library Cover Progress Overlay
```

修改后

```markdown
- 本组件不定义点击动作，交互由所属卡片决定。

#### Library Cover Crop Editor

- 用途：调整图片的封面裁剪区域。
- 裁剪区域固定使用 `--aspect-library-cover`。
- 初始裁剪框为图片范围内最大的 `--aspect-library-cover` 区域。
- 裁剪框显示四个角柄和四个边柄；拖动任一缩放柄时保持固定比例。
- 拖动裁剪框内部移动完整裁剪区域。
- 裁剪框不得超出图片范围，并具有最小尺寸。
- 裁剪框外显示遮罩。

#### Library Cover Progress Overlay
```

### 4. 增加 Edit Cover Dialog Layout

修改前

```markdown
### 4.4 Dialogs 与 Popovers

#### Confirmation Dialog Layout
```

修改后

```markdown
### 4.4 Dialogs 与 Popovers

#### Edit Cover Dialog Layout

- 从上到下包括：
  1. Title
  2. Library Cover Crop Editor
  3. Hint
  4. Actions
- Title：`Edit Cover`。
- Hint：`Support: JPG, JPEG, PNG, and GIF no more than 20 MB.`
- Actions：
  - Neutral Button：`Cancel`
  - Primary Button：`Done`

#### Confirmation Dialog Layout
```
