# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Settings Window Layout、Settings Sidebar Layout、Settings Category Layout、Section Title、Number Field、Checkbox / Form Checkbox、Segmented Control、Button / Neutral）
- `docs/human/design/Icon Registry.md`

# 需求描述

## 1. 范围

1. 设置窗口新增 Subtitle 分类，位于 Shortcuts 之下，图标为 `subtitles`。本版本只提供 SRT 字幕的样式与位置设置。
2. 设置作用于 SRT 的播放画面、Current Frame Screenshot（P 键）、Subtitle Screenshot、Collage 预览与导出。
3. ASS 字幕不受本页设置影响，继续按源脚本渲染。
4. 修改设置后立即生效：正在播放的字幕立即重新排版，Collage 预览中已生成的截图组重新生成；已导出的文件不变。
5. 设置在重启 App 后保留。

## 2. 页面

1. 自上而下：Page Title `Subtitle`；Section Title `Text`、`Border`、`Shadow`、`Position` 及各自设置项；页底 Restore Defaults 按钮。
2. 每行为设置项名称与控件。名称一列取全页最长名称的宽度，控件与该列相隔 `--spacing-6`。
3. Font 显示当前字体名称与 Choose… 按钮，Choose… 打开系统字体面板。
4. 颜色使用系统原生颜色控件，点击打开系统颜色面板，可设置不透明度。
5. 数值输入可含小数；超出允许范围时取最近的边界值。
6. Restore Defaults 将本页全部设置恢复为默认值；全部为默认值时不可用。
7. 设置窗口最小宽度提高到本页所有行都能完整显示。
8. 简体中文与繁体中文文案随现有本地化补齐。

## 3. 设置项

| 分组 | 设置项 | 控件 | 取值 |
| --- | --- | --- | --- |
| Text | Font | 字体名称 + Choose… | 系统字体 |
| Text | Size | Number Field | > 0 |
| Text | Style | Form Checkbox：Bold、Italic | |
| Text | Color | 颜色 | |
| Text | Letter Spacing | Number Field | 可为负 |
| Text | Line Spacing | Number Field | ≥ 0 |
| Border | Type | Segmented Control：Outline / Opaque Box / Background Box | |
| Border | Outline Color | 颜色 | |
| Border | Outline Width | Number Field | ≥ 0 |
| Border | Background Color | 颜色 | |
| Border | Blur | Number Field | ≥ 0 |
| Shadow | Shadow Color | 颜色 | |
| Shadow | Shadow Offset | Number Field | ≥ 0 |
| Position | Horizontal | Segmented Control：Left / Center / Right | |
| Position | Margin X | Number Field | ≥ 0 |
| Position | Vertical | Segmented Control：Top / Center / Bottom | |
| Position | Margin Y | Number Field | ≥ 0 |

默认值在 App 内验收后补入本需求。

## 4. Border Type

| Type | 效果 | 置灰的设置项 |
| --- | --- | --- |
| Outline | 文字描边加阴影 | Background Color |
| Opaque Box | 每行文字各一个底框，颜色为 Background Color；阴影为底框的阴影 | Outline Color、Outline Width |
| Background Box | 整条字幕一个背景框，颜色为 Background Color；文字描边照常 | Shadow Color、Shadow Offset |

底框与文字的间距为固定值，不提供设置。

## 5. 数值含义

1. Size、Letter Spacing、Line Spacing、Outline Width、Blur、Shadow Offset、Margin X、Margin Y 以画面高度 720 为基准，随画面高度等比缩放。
2. 画面高度：播放时为视频实际显示区域的高度；截图与 Collage 为输出帧的像素高度。
3. Size 与 ASS、mpv 同口径：数值为整行高度，不是 macOS 字号。换字体后视觉大小随字体变化，不做补偿。
4. Line Spacing 为在字体自然行高之上额外增加的距离。

## 6. 渲染规则

1. 字体没有斜体或粗体字形时，人工斜切或加粗；SRT 行内 `<i>`、`<b>` 标签使用同一规则。
2. 阴影固定向右下偏移。
3. Blur 模糊边缘：有描边时模糊描边，没有描边时模糊文字本身；阴影随之模糊。
4. Horizontal：Left、Right 分别距画面左右边缘 Margin X，Center 水平居中；多行文字按同一方式对齐。
5. Vertical：Top 距画面顶边 Margin Y，Bottom 距画面底边 Margin Y，Center 位于画面垂直中央。
6. 多条字幕同时出现时，Bottom 与 Center 向上堆叠，Top 向下堆叠。