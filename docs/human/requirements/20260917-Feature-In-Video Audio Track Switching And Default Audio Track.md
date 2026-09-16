# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Menus / Menu、Submenu、Menu Item；Data Display / Tag；Player Controls；Player Bottom Control Bar Layout）
- `docs/human/design/UI Application Rules.md`（菜单模态；Player UI 与指针显隐）
- `docs/human/design/Data.md`（Index流程 / 更新视频元数据；永久身份与路径分离）

# 需求描述

## 1. 范围

1. 播放页可以切换当前视频的音频源，并为该视频设置默认音频源。
2. 默认音频源作用于播放与 Anki 导出。

## 2. Index

1. 更新视频元数据时，同时记录视频内的音轨列表：顺序、语言、标题、编码、声道数。
2. 已 Index 的视频缺少音轨列表时，按数据缺失处理，下次 Index 补齐。

## 3. 默认音频源与当前音频源

1. 默认音频源记录“第几条音轨”，绑定 VideoID 并持久化；未设置时为第 1 条。Index 不修改它。
2. 打开视频时，当前音频源取默认音频源。
3. 播放中切换音频源只影响本次播放，不保存；切换后播放或暂停状态与进度不变。
4. Anki 导出的音频使用该视频的默认音频源。
5. 播放或 Anki 导出时，要读取的音轨在文件中不存在，改用第 1 条音轨。

## 4. More 按钮

1. 播放页底栏最右侧新增 More 按钮，图标为 dots-three-vertical；原全屏按钮及其左侧按钮整体左移一位。
2. 点击弹出 More 菜单，作为低频操作的通用入口；菜单打开期间按钮保持 Open 外观。
3. More 按钮与 More 菜单的菜单项属于可点击控件。

## 5. More 菜单

1. 外观沿用 Player Speed Menu，行为遵守通用 Menu、Submenu 与菜单模态规则。
2. 一级菜单两项：Audio Track（音频源）、Default Audio Track（默认音频源），均为 Submenu Trigger。
3. 视频没有音轨时，两项为 Disabled。
4. 一级菜单与两个二级菜单打开时高亮首项。
5. 二级菜单按顺序列出 Index 记录的音轨，单选；点击任一项后一级与二级菜单一起关闭，点击已勾选项只关闭菜单。

## 6. 二级菜单项

1. 从左到右为勾选区、名称区、标签区。
2. 名称格式为 `#序号 语言, 标题, 编码, 声道`，用英文逗号分隔，缺少的部分省略；语言名跟随界面语言，声道写作 `2ch`、`6ch`。例如 `#1 日语, opus, 2ch`、`#2 Japanese, Commentary, aac, 2ch`。
3. 名称完整显示，超出宽度时换行；二级菜单宽度固定，不为滚动条预留宽度，出现滚动条时按通用 Menu 规则加宽。
4. Audio Track：勾选当前音频源；默认音频源所在项显示 Default（默认）标签。
5. Default Audio Track：勾选默认音频源；当前音频源所在项显示 Current（当前）标签。
6. 勾选与标签按实际生效的音轨显示；记录的音轨不存在时显示在第 1 条。
7. 标签沿用 Tag 的形状，颜色使用 Player Chrome 已有颜色。

# 验收

1. 中文界面下，示例视频 `[Darkness] Fate Stay Night - S01E01` Index 后，两个二级菜单依次列出 `#1 日语, opus, 2ch`、`#2 英语, opus, 2ch`、`#3 法语, opus, 2ch`，打开时默认音频源与当前音频源均为第 1 条。
2. 切换音频源后，立即听到对应音轨，进度与播放或暂停状态不变；重新打开该视频时，播放默认音频源。
3. 设置默认音频源后，重启 App 仍然生效；Anki 导出的音频使用默认音频源。
4. 记录的音轨在文件中不存在时，播放与 Anki 导出使用第 1 条，菜单勾选显示在第 1 条。
5. 界面与音频由人工在 App 内验收；本次改动不新增任何自动化端到端或单元用例的失败。