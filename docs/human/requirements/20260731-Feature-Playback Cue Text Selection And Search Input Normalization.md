
# 版本
main

# 需求描述
1. 给Playback Overlay Current，Playback Overlay Cue Playlist，Command Panel Search界面的字幕引进新的交互，可以用按下鼠标左键拖拽划词，松开时在右边弹出菜单：Copy Selected Text，Search Selected Text。前者用Copy图标，后者用放大镜图标。菜单锚定选区文本顺序最后一个字符的尾缘，不使用鼠标松开位置。
2. 点击Copy Selected Text，成功后，弹出提示：Selected Text Copied。
3. 点击Search Selected Text，会打开Command Panel并搜索该词汇。如果Command Panel已经打开，也是如此。
4. 可以选择非焦点字幕，但是不允许跨字幕选取，不允许跨行选取（即多行字幕内部的换行符）。注意，即使字幕本身就是多行的，也不允许跨行选取。
5. 归一化搜索内容：如果输入的内容包含换行内容，要将换行转为空格。避免搜索框出现多行输入。对所有搜索框都有效，目前包括Workbench Search界面，Shiori二级界面，Command Panel界面。

# 注意事项
1. 鼠标划词，弹出菜单等，不兼容Collage模式，该模式专注处理图片。

# 修改流程
1. 实现Playback Overlay Current、Playback Overlay Cue Playlist、Command Panel Search字幕的单行文字选择，不兼容Collage模式。
2. 实现选区菜单及Copy Selected Text、Search Selected Text操作。
3. 统一Workbench Search、Shiori二级界面和Command Panel的搜索内容归一化。
4. 完成自动化测试，并由人工完成视觉和交互验收；验收通过后，将最终稳定结果同步到UI.md。