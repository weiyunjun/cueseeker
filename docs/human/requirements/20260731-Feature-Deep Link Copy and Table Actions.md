# 版本
main

# 需求描述
1. Settings - URL Scheme，标题及内容，所有相关文字改为Deep Link。
2. 在Search界面的表格，Shiori二级界面的表格行的右键菜单中，Copy Cue Text下面新增：Copy Deep Link。功能和Playback Overlay界面的X功能一致（只复制Primary Cue的Deep Link链接，不复制Cue Group的）。该按钮图标，用当前Settings - URL Scheme的链接图标。
3. Search界面的表格，Shiori二级界面的表格行的右键菜单，目前已有的3个包含Copy的按钮，图标用Select状态下的Copy Table的图标。
4. 在Search界面的表格，Shiori二级界面的Select状态下，移除Screenshot按钮和Collage按钮。并且需要移除只在表格界面下的这2个功能的相关代码，但不要影响视频内的截图或Collage功能。
5. 在Search界面的表格，Shiori二级界面的Select状态下，新增Copy Deep Link(s)按钮，图标用Select状态下的Copy Table的图标。功能是复制所有选中行Deep Link链接，每行一个。修改后的按钮顺序：Anki，Copy Deep Link(s)，Copy Table。
6. 在Playback Overlay界面和Command Panel界面，X快捷键的复制Deep Link链接的提示文字改为：Deep Link Copied。C快捷键的复制Cue Text的提示文字改为：Cue Text Copied。

# UI文档改动

1. 更新 `docs/human/design/UI.md` 的 Deep Link 图标定义：
   - `Copy Cue Text`、`Copy Cue Group Text`、`Copy Time Range`、`Copy Table`、`Copy Deep Link(s)` 使用 `doc.on.doc`。
   - Settings `Deep Link` 与行菜单 `Copy Deep Link` 使用 `link`。
2. 增加 Settings Deep Link Layout，明确 Sidebar Category、Page Title、Page Description 及 `Play First Search Result` 的用户可见文案。
3. Search 和 Shiori 的 Selection Action Overlay 调整为：Anki、Copy Deep Link(s)、Copy Table。
4. 明确 `Copy Deep Link(s)` 按当前表格顺序复制所有已选行的 Primary Cue Deep Link，每行一个。
5. 明确表格 Selection Action Overlay 不显示 Screenshot 或 Collage，不影响 Playback 内对应功能。
6. Search / Context 和 Shiori Row Action Menu 在 `Copy Cue Text` 后增加 `Copy Deep Link`。
7. 明确 `Copy Deep Link` 只复制 Primary Cue，使用 Markdown Deep Link 格式并只发布 Plain Text。
8. 明确 Unavailable Shiori 的 `Copy Deep Link` 为 Disabled。
9. Playback Overlay 与 Command Panel 的复制反馈更新为 `Deep Link Copied` 和 `Cue Text Copied`。
10. Command Panel 中用户可见的 `URL Scheme` 术语更新为 `Deep Link`。