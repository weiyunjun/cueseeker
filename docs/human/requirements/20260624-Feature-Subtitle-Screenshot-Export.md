# 版本
main

# 需求描述
1. 在Search和Shiori界面，增加单字幕截图导出功能和多字幕截图导出功能。
2. 当checkbox有任何一行选中时，会在Anki按钮右侧出现这2个按钮，分别是Screenshot和Collage。
3. 单字幕截图导出功能：如果只有一个字幕选中，点击按钮后弹出保存界面，默认名称是{Display Title}-{Start Time}-{End Time}.png。如果有多个字幕选择，点击按钮后弹出保存界面，会建立一个文件夹，名称是CueSeeker-yyyy-MM-dd hh.mm。里面的图片默认名称是{Display Title}-{Start Time}-{End Time}.png。
4. 多字幕截图导出功能：当且仅当所有选中字幕，来自同一个视频，且数量小于等于50时，该按钮才会显示Default样式，否则显示disabled样式。当可以点击时，点击按钮后弹出保存界面，默认名称是{Display Title}-{Start Time}-{End Time}-{字幕数量}.png。
5. {Start Time}和{End Time}的格式是：hh:mm:ss，如果小时为0，则不显示。例如01:15:32，15:18。
6. {Display Title}格式是字符串，{字幕数量}格式是正整数。

# 注意事项
1. 截图选择的是时间戳中间位置的截图，例如某字幕是05:00-05:06的，那么会选择05:03的截图。
2. 目前单张截图是默认带字幕的，暂时不提供不带字幕的选项。
3. 多张截图是强制带字幕的，不然就没意义了，后续不太可能提供不带字幕的选项。